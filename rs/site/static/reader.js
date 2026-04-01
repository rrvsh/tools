const DB_NAME = "epub-reader";
const DB_VERSION = 1;
const BOOKS_STORE = "books";
const PROGRESS_STORE = "progress";

let db = null;
let currentBookId = null;
let routeToken = 0;

const dom = {
  fileInput: document.querySelector("#epub-file-input"),
  bookList: document.querySelector("#book-list"),
  readerOverlay: document.querySelector("#reader-overlay"),
  readerView: document.querySelector("#reader-view"),
  readerContainer: document.querySelector("#reader-container"),
  openLibraryButton: document.querySelector("#open-library"),
  addBookmarkButton: document.querySelector("#add-bookmark"),
  showBookmarksButton: document.querySelector("#show-bookmarks"),
  readingProgress: document.querySelector("#reading-progress"),
};

function openDatabase() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);

    request.onerror = () => reject(request.error);
    request.onblocked = () => reject(new Error("IndexedDB upgrade blocked by another tab."));
    request.onupgradeneeded = () => {
      const upgradeDb = request.result;

      if (!upgradeDb.objectStoreNames.contains(BOOKS_STORE)) {
        upgradeDb.createObjectStore(BOOKS_STORE, {
          keyPath: "id",
          autoIncrement: true,
        });
      }

      if (!upgradeDb.objectStoreNames.contains(PROGRESS_STORE)) {
        upgradeDb.createObjectStore(PROGRESS_STORE, {
          keyPath: "bookId",
        });
      }
    };
    request.onsuccess = () => {
      const openedDb = request.result;
      openedDb.onversionchange = () => {
        openedDb.close();
      };
      resolve(openedDb);
    };
  });
}

function escapeHtml(value) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function withStore(storeNames, mode, operation) {
  return new Promise((resolve, reject) => {
    const transaction = db.transaction(storeNames, mode);
    const stores = Array.isArray(storeNames)
      ? storeNames.map((name) => transaction.objectStore(name))
      : transaction.objectStore(storeNames);

    transaction.onerror = () => reject(transaction.error);
    transaction.onabort = () => reject(transaction.error);

    const result = operation(stores);
    transaction.oncomplete = () => resolve(result);
  });
}

function requestToPromise(request) {
  return new Promise((resolve, reject) => {
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

async function listBooks() {
  return withStore(BOOKS_STORE, "readonly", (store) => requestToPromise(store.getAll()));
}

async function getBookById(bookId) {
  return withStore(BOOKS_STORE, "readonly", (store) => requestToPromise(store.get(bookId)));
}

async function saveBook(record) {
  return withStore(BOOKS_STORE, "readwrite", (store) => requestToPromise(store.add(record)));
}

async function getProgressByBookId(bookId) {
  return withStore(PROGRESS_STORE, "readonly", (store) => requestToPromise(store.get(bookId)));
}

async function deleteBookAndProgress(bookId) {
  return withStore([BOOKS_STORE, PROGRESS_STORE], "readwrite", ([booksStore, progressStore]) => {
    booksStore.delete(bookId);
    progressStore.delete(bookId);
  });
}

function encodeCfi(cfi) {
  return encodeURIComponent(cfi);
}

function decodeCfi(cfi) {
  try {
    return decodeURIComponent(cfi);
  } catch {
    return "";
  }
}

function parseHash() {
  const value = window.location.hash.replace(/^#/, "").trim();

  if (!value) {
    return { bookId: null, cfi: "" };
  }

  const [idPart, cfiPart] = value.split("/cfi=");
  const parsedId = Number.parseInt(idPart, 10);

  if (!Number.isInteger(parsedId) || parsedId <= 0) {
    return { bookId: null, cfi: "" };
  }

  return {
    bookId: parsedId,
    cfi: cfiPart ? decodeCfi(cfiPart) : "",
  };
}

function setHash(bookId, cfi = "") {
  if (!bookId) {
    window.location.hash = "";
    return;
  }

  if (cfi) {
    window.location.hash = `#${bookId}/cfi=${encodeCfi(cfi)}`;
    return;
  }

  window.location.hash = `#${bookId}`;
}

function disableFutureControlsUntilRender() {
  dom.addBookmarkButton.disabled = true;
  dom.showBookmarksButton.disabled = true;
}

function showError(message) {
  dom.readerContainer.textContent = "";
  const errorNode = document.createElement("p");
  errorNode.className = "reader-error";
  errorNode.textContent = message;
  dom.readerContainer.append(errorNode);
}

function renderOpenBookPlaceholder(book, progress) {
  const progressLabel = progress?.cfi
    ? "Saved reading position is available."
    : "No saved reading position yet.";

  dom.readerContainer.innerHTML = `
    <div class="reader-placeholder">
      <h2>${escapeHtml(book.title)}</h2>
      <p><small>${escapeHtml(book.author)}</small></p>
      <p>Reader engine initializes in the next commit. This confirms routing and storage are working.</p>
      <p>${progressLabel}</p>
    </div>
  `;
}

function renderBookList(books, progressByBookId) {
  if (!books.length) {
    dom.bookList.innerHTML = "<li class=\"empty\">No books yet. Import one to begin.</li>";
    return;
  }

  const items = books
    .map((book) => {
      const progress = progressByBookId.get(book.id);
      const progressText = progress?.cfi ? "resume available" : "new";

      return `
        <li class="book-item" data-book-id="${book.id}">
          <button class="button open-book" data-open-book-id="${book.id}">Open</button>
          <button class="button delete-book" data-delete-book-id="${book.id}">Delete</button>
          <span class="book-title">${escapeHtml(book.title)}</span>
          <span class="book-meta">${escapeHtml(book.author)} - ${progressText}</span>
        </li>
      `;
    })
    .join("");

  dom.bookList.innerHTML = items;
}

async function refreshLibrary() {
  const books = await listBooks();
  const progressByBookId = new Map();

  await Promise.all(
    books.map(async (book) => {
      const progress = await getProgressByBookId(book.id);
      progressByBookId.set(book.id, progress);
    }),
  );

  renderBookList(books, progressByBookId);
}

async function onBookDelete(bookId) {
  await deleteBookAndProgress(bookId);

  if (currentBookId === bookId) {
    currentBookId = null;
    setHash(null);
  }

  await refreshLibrary();
}

async function onBookImport(files) {
  const supportedFiles = [...files].filter(
    (file) => file.name.toLowerCase().endsWith(".epub") || file.type === "application/epub+zip",
  );

  if (!supportedFiles.length) {
    showError("No valid EPUB files selected.");
    return;
  }

  for (const file of supportedFiles) {
    const data = await file.arrayBuffer();
    if (data.byteLength === 0) {
      continue;
    }

    const fallbackTitle = file.name.replace(/\.epub$/iu, "") || "Untitled";
    await saveBook({
      title: fallbackTitle,
      author: "Unknown author",
      fileName: file.name,
      fileData: data,
      createdAt: Date.now(),
    });
  }

  dom.fileInput.value = "";
  await refreshLibrary();
}

function bindLibraryActions() {
  dom.fileInput.addEventListener("change", async (event) => {
    const files = event.target.files;
    if (!files || !files.length) {
      return;
    }

    try {
      await onBookImport(files);
    } catch {
      showError("Failed to import book(s). Please try again.");
    }
  });

  dom.bookList.addEventListener("click", async (event) => {
    const target = event.target;
    if (!(target instanceof HTMLElement)) {
      return;
    }

    const openId = target.getAttribute("data-open-book-id");
    if (openId) {
      setHash(Number.parseInt(openId, 10));
      return;
    }

    const deleteId = target.getAttribute("data-delete-book-id");
    if (!deleteId) {
      return;
    }

    try {
      await onBookDelete(Number.parseInt(deleteId, 10));
    } catch {
      showError("Failed to delete book.");
    }
  });

  dom.openLibraryButton.addEventListener("click", () => {
    setHash(null);
  });
}

async function applyRoute() {
  const nextToken = routeToken + 1;
  routeToken = nextToken;
  const { bookId } = parseHash();

  if (!bookId) {
    currentBookId = null;
    dom.readerOverlay.hidden = false;
    dom.readerView.hidden = true;
    return;
  }

  const book = await getBookById(bookId);
  if (routeToken !== nextToken) {
    return;
  }

  if (!book) {
    setHash(null);
    return;
  }

  currentBookId = book.id;
  dom.readerOverlay.hidden = true;
  dom.readerView.hidden = false;
  dom.readingProgress.textContent = "0%";

  const progress = await getProgressByBookId(book.id);
  if (routeToken !== nextToken) {
    return;
  }

  renderOpenBookPlaceholder(book, progress);
}

async function bootstrap() {
  disableFutureControlsUntilRender();

  try {
    db = await openDatabase();
  } catch {
    showError("Unable to open browser storage. Check privacy settings and retry.");
    return;
  }

  bindLibraryActions();
  await refreshLibrary();
  await applyRoute();

  window.addEventListener("hashchange", async () => {
    await applyRoute();
  });
}

void bootstrap();
