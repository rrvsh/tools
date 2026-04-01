const DB_NAME = "epub-reader";
const DB_VERSION = 1;
const BOOKS_STORE = "books";
const PROGRESS_STORE = "progress";

let db = null;
let currentBookId = null;
let routeToken = 0;
let activeBook = null;
let activeRendition = null;
let saveCfiTimer = null;

const dom = {
  fileInput: document.querySelector("#epub-file-input"),
  bookList: document.querySelector("#book-list"),
  readerOverlay: document.querySelector("#reader-overlay"),
  readerView: document.querySelector("#reader-view"),
  readerContainer: document.querySelector("#reader-container"),
  bookmarksPanel: document.querySelector("#bookmarks-panel"),
  bookmarkList: document.querySelector("#bookmark-list"),
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
  const nextHash = bookId
    ? cfi
      ? `#${bookId}/cfi=${encodeCfi(cfi)}`
      : `#${bookId}`
    : "";

  if (window.location.hash === nextHash) {
    return;
  }

  window.location.hash = nextHash;
}

function replaceHash(bookId, cfi = "") {
  if (!bookId) {
    window.history.replaceState(null, "", window.location.pathname);
    return;
  }

  if (cfi) {
    window.history.replaceState(
      null,
      "",
      `${window.location.pathname}#${bookId}/cfi=${encodeCfi(cfi)}`,
    );
    return;
  }

  window.history.replaceState(null, "", `${window.location.pathname}#${bookId}`);
}

function disableFutureControlsUntilRender() {
  dom.addBookmarkButton.disabled = false;
  dom.showBookmarksButton.disabled = false;
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

async function saveProgress(bookId, patch) {
  const existing = (await getProgressByBookId(bookId)) ?? {
    bookId,
    cfi: "",
    bookmarks: [],
  };

  const nextValue = {
    ...existing,
    ...patch,
  };

  return withStore(PROGRESS_STORE, "readwrite", (store) => requestToPromise(store.put(nextValue)));
}

function debounceSaveCfi(bookId, cfi) {
  if (!bookId || !cfi) {
    return;
  }

  if (saveCfiTimer) {
    window.clearTimeout(saveCfiTimer);
  }

  saveCfiTimer = window.setTimeout(async () => {
    await saveProgress(bookId, { cfi });
    replaceHash(bookId, cfi);
  }, 500);
}

function normalizeBookmarks(progress) {
  if (!progress || !Array.isArray(progress.bookmarks)) {
    return [];
  }

  return progress.bookmarks;
}

function computeLabelFromProgress(percentage) {
  const safe = Number.isFinite(percentage) ? Math.min(1, Math.max(0, percentage)) : 0;
  const rounded = Math.round(safe * 100);
  return `${rounded}%`;
}

async function renderBookmarksPanel(bookId) {
  const progress = await getProgressByBookId(bookId);
  const bookmarks = normalizeBookmarks(progress);

  if (!bookmarks.length) {
    dom.bookmarkList.innerHTML = "<li class=\"empty\">No bookmarks yet.</li>";
    return;
  }

  const markup = bookmarks
    .map(
      (bookmark) => `
        <li class="book-item">
          <button class="button jump-bookmark" data-jump-bookmark-id="${bookmark.id}">Go</button>
          <button class="button delete-bookmark" data-delete-bookmark-id="${bookmark.id}">Delete</button>
          <span class="book-title">${escapeHtml(bookmark.label)}</span>
          <span class="book-meta">${new Date(bookmark.createdAt).toLocaleString()}</span>
        </li>
      `,
    )
    .join("");

  dom.bookmarkList.innerHTML = markup;
}

async function addBookmarkForCurrentBook() {
  if (!activeRendition || !currentBookId) {
    return;
  }

  const location = activeRendition.currentLocation();
  const cfi = location?.start?.cfi;
  if (!cfi) {
    return;
  }

  const progress = await getProgressByBookId(currentBookId);
  const bookmarks = normalizeBookmarks(progress);
  const percentage = activeBook?.locations ? activeBook.locations.percentageFromCfi(cfi) : 0;
  const label = `Bookmark ${computeLabelFromProgress(percentage)}`;
  const bookmark = {
    id: crypto.randomUUID(),
    cfi,
    label,
    createdAt: Date.now(),
  };

  await saveProgress(currentBookId, {
    cfi,
    bookmarks: [bookmark, ...bookmarks],
  });

  await renderBookmarksPanel(currentBookId);
}

async function onBookmarkListClick(event) {
  if (!currentBookId) {
    return;
  }

  const target = event.target;
  if (!(target instanceof HTMLElement)) {
    return;
  }

  const progress = await getProgressByBookId(currentBookId);
  const bookmarks = normalizeBookmarks(progress);

  const jumpId = target.getAttribute("data-jump-bookmark-id");
  if (jumpId) {
    const bookmark = bookmarks.find((entry) => entry.id === jumpId);
    if (bookmark?.cfi && activeRendition) {
      await activeRendition.display(bookmark.cfi);
    }
    return;
  }

  const deleteId = target.getAttribute("data-delete-bookmark-id");
  if (!deleteId) {
    return;
  }

  const nextBookmarks = bookmarks.filter((entry) => entry.id !== deleteId);
  await saveProgress(currentBookId, { bookmarks: nextBookmarks });
  await renderBookmarksPanel(currentBookId);
}

function updateReadingProgress(cfi) {
  if (!activeBook?.locations || !cfi) {
    dom.readingProgress.textContent = "0%";
    return;
  }

  const percentage = activeBook.locations.percentageFromCfi(cfi);
  dom.readingProgress.textContent = computeLabelFromProgress(percentage);
}

function cleanupActiveReader() {
  if (saveCfiTimer) {
    window.clearTimeout(saveCfiTimer);
    saveCfiTimer = null;
  }

  if (activeRendition) {
    activeRendition.destroy();
    activeRendition = null;
  }

  if (activeBook) {
    activeBook.destroy();
    activeBook = null;
  }
}

async function renderBook(book, cfiFromRoute, token) {
  cleanupActiveReader();
  dom.readerContainer.textContent = "";

  const bookInstance = ePub(book.fileData);
  const rendition = bookInstance.renderTo("reader-container", {
    width: "100%",
    height: "70vh",
    flow: "scrolled-doc",
    manager: "continuous",
  });

  activeBook = bookInstance;
  activeRendition = rendition;

  rendition.themes.default({
    body: {
      background: "#050505",
      color: "#efefef",
      "font-family": "Courier New, monospace",
      "line-height": "1.6",
      margin: "0 auto",
      "max-width": "760px",
      padding: "24px 20px 60px",
    },
    a: {
      color: "#cfd8dc",
    },
  });

  await bookInstance.ready;
  if (token !== routeToken || book.id !== currentBookId) {
    return;
  }

  await bookInstance.locations.generate(1600);
  if (token !== routeToken || book.id !== currentBookId) {
    return;
  }

  const progress = await getProgressByBookId(book.id);
  const savedCfi = progress?.cfi ?? "";
  const startCfi = cfiFromRoute || savedCfi;

  if (startCfi) {
    try {
      await rendition.display(startCfi);
    } catch {
      await rendition.display();
    }
  } else {
    await rendition.display();
  }

  rendition.on("relocated", async (location) => {
    if (book.id !== currentBookId) {
      return;
    }

    const cfi = location?.start?.cfi;
    if (!cfi) {
      return;
    }

    updateReadingProgress(cfi);
    debounceSaveCfi(book.id, cfi);
  });

  const currentLocation = rendition.currentLocation();
  updateReadingProgress(currentLocation?.start?.cfi);
  await renderBookmarksPanel(book.id);
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

  dom.addBookmarkButton.addEventListener("click", async () => {
    await addBookmarkForCurrentBook();
  });

  dom.showBookmarksButton.addEventListener("click", async () => {
    dom.bookmarksPanel.hidden = !dom.bookmarksPanel.hidden;
    if (!dom.bookmarksPanel.hidden && currentBookId) {
      await renderBookmarksPanel(currentBookId);
    }
  });

  dom.bookmarkList.addEventListener("click", async (event) => {
    await onBookmarkListClick(event);
  });
}

async function applyRoute() {
  const nextToken = routeToken + 1;
  routeToken = nextToken;
  const { bookId, cfi } = parseHash();

  if (!bookId) {
    cleanupActiveReader();
    currentBookId = null;
    dom.readerOverlay.hidden = false;
    dom.readerView.hidden = true;
    dom.bookmarksPanel.hidden = true;
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
  dom.bookmarksPanel.hidden = true;

  await renderBook(book, cfi, nextToken);
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
