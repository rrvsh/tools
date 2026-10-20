import { AsciiGenerator } from "/static/vendor/ts-ascii-engine/index.js";

const MAX_DIMENSION = 300;
const RENDER_DELAY_MS = 100;

const dom = {
  imageInput: document.querySelector("#ascii-image"),
  imageName: document.querySelector("#ascii-image-name"),
  widthInput: document.querySelector("#ascii-width"),
  heightInput: document.querySelector("#ascii-height"),
  charsetInput: document.querySelector("#ascii-charset"),
  fitInput: document.querySelector("#ascii-fit"),
  guidesInput: document.querySelector("#ascii-guides"),
  error: document.querySelector("#ascii-error"),
  status: document.querySelector("#ascii-status"),
  output: document.querySelector("#ascii-output"),
  copyButton: document.querySelector("#ascii-copy"),
  downloadButton: document.querySelector("#ascii-download"),
};

let sourceImage = null;
let sourceImageUrl = null;
let sourceFileName = "ascii-art";
let outputText = "";
let outputWidth = 0;
let outputHeight = 0;
let renderTimer = null;
let imageLoadToken = 0;

function showError(message) {
  dom.error.textContent = message;
  dom.error.hidden = false;
}

function clearError() {
  dom.error.textContent = "";
  dom.error.hidden = true;
}

function updatePreview() {
  if (!outputText) {
    dom.output.textContent = "";
    return;
  }

  if (!dom.guidesInput.checked) {
    dom.output.textContent = outputText;
    return;
  }

  const rowNumberWidth = String(outputHeight).length;
  let tensRuler = "";
  for (let start = 1; start <= outputWidth; start += 10) {
    const segmentLength = Math.min(10, outputWidth - start + 1);
    const end = start + segmentLength - 1;
    tensRuler += segmentLength === 10
      ? String(end).padStart(segmentLength)
      : " ".repeat(segmentLength);
  }
  const onesRuler = Array.from(
    { length: outputWidth },
    (_, index) => String((index + 1) % 10),
  ).join("");
  const gutter = " ".repeat(rowNumberWidth);
  const guidedRows = outputText
    .split("\n")
    .map((row, index) => `${String(index + 1).padStart(rowNumberWidth)} │ ${row}`);

  dom.output.textContent = [
    `${gutter} │ ${tensRuler}`,
    `${gutter} │ ${onesRuler}`,
    ...guidedRows,
  ].join("\n");
}

function renderAscii() {
  if (!sourceImage) {
    return;
  }

  const width = dom.widthInput.valueAsNumber;
  const height = dom.heightInput.valueAsNumber;
  const charset = dom.charsetInput.value;

  if (!Number.isInteger(width) || width < 1 || width > MAX_DIMENSION) {
    showError(`Width must be a whole number from 1 to ${MAX_DIMENSION}.`);
    return;
  }

  if (!Number.isInteger(height) || height < 1 || height > MAX_DIMENSION) {
    showError(`Height must be a whole number from 1 to ${MAX_DIMENSION}.`);
    return;
  }

  if (charset.length < 2) {
    showError("Choose at least two characters.");
    return;
  }

  if (/\r|\n/.test(charset)) {
    showError("The character set cannot contain line breaks.");
    return;
  }

  if ([...charset].some((character) => character.length !== 1)) {
    showError("Use single-unit characters in the character set.");
    return;
  }

  clearError();

  try {
    const canvas = document.createElement("canvas");
    canvas.width = width;
    canvas.height = height;

    const context = canvas.getContext("2d", {
      alpha: false,
      willReadFrequently: true,
    });

    if (!context) {
      throw new Error("Your browser could not create the image canvas.");
    }

    context.fillStyle = "white";
    context.fillRect(0, 0, width, height);
    context.imageSmoothingEnabled = true;
    context.imageSmoothingQuality = "high";

    const sourceWidth = sourceImage.naturalWidth;
    const sourceHeight = sourceImage.naturalHeight;
    const fit = dom.fitInput.value;

    if (fit === "stretch") {
      context.drawImage(sourceImage, 0, 0, width, height);
    } else {
      const scale = fit === "fit"
        ? Math.min(width / sourceWidth, height / sourceHeight)
        : Math.max(width / sourceWidth, height / sourceHeight);
      const drawnWidth = sourceWidth * scale;
      const drawnHeight = sourceHeight * scale;
      const x = (width - drawnWidth) / 2;
      const y = (height - drawnHeight) / 2;

      context.drawImage(sourceImage, x, y, drawnWidth, drawnHeight);
    }

    const generator = new AsciiGenerator({
      charset,
      width,
      aspectRatio: 1,
      colored: false,
      optimized: true,
    });
    const result = generator.convertImage(canvas);
    const rows = result.text.split("\n");

    if (rows.length !== height || rows.some((row) => row.length !== width)) {
      throw new Error("The converter returned an unexpected canvas size.");
    }

    outputText = result.text;
    outputWidth = width;
    outputHeight = height;
    updatePreview();
    dom.output.setAttribute(
      "aria-label",
      `Generated ASCII art, ${width} columns by ${height} rows.`,
    );
    dom.copyButton.disabled = false;
    dom.downloadButton.disabled = false;
    dom.status.textContent = `Generated ${width} × ${height} characters.`;
  } catch (error) {
    const message = error instanceof Error ? error.message : "The image could not be converted.";
    showError(message);
  }
}

function scheduleRender() {
  if (!sourceImage) {
    return;
  }

  if (renderTimer !== null) {
    window.clearTimeout(renderTimer);
  }

  renderTimer = window.setTimeout(() => {
    renderTimer = null;
    renderAscii();
  }, RENDER_DELAY_MS);
}

dom.imageInput.addEventListener("change", async () => {
  const file = dom.imageInput.files?.[0];
  const token = ++imageLoadToken;

  if (sourceImageUrl) {
    URL.revokeObjectURL(sourceImageUrl);
    sourceImageUrl = null;
  }

  sourceImage = null;
  outputText = "";
  outputWidth = 0;
  outputHeight = 0;
  updatePreview();
  dom.output.setAttribute("aria-label", "No ASCII art generated yet.");
  dom.copyButton.disabled = true;
  dom.downloadButton.disabled = true;
  clearError();

  if (!file) {
    dom.imageName.textContent = "No image selected.";
    dom.status.textContent = "Choose an image to begin.";
    return;
  }

  const imageUrl = URL.createObjectURL(file);
  const image = new Image();
  image.src = imageUrl;
  dom.imageName.textContent = file.name;
  dom.status.textContent = "Loading image…";

  try {
    await image.decode();

    if (token !== imageLoadToken) {
      URL.revokeObjectURL(imageUrl);
      return;
    }

    sourceImageUrl = imageUrl;
    sourceImage = image;
    sourceFileName = file.name;
    renderAscii();
  } catch {
    URL.revokeObjectURL(imageUrl);
    dom.status.textContent = "No output generated.";
    showError("The selected file could not be decoded as an image.");
  }
});

for (const input of [dom.widthInput, dom.heightInput, dom.charsetInput]) {
  input.addEventListener("input", scheduleRender);
}

dom.fitInput.addEventListener("change", scheduleRender);
dom.guidesInput.addEventListener("change", updatePreview);

dom.copyButton.addEventListener("click", async () => {
  if (!outputText) {
    return;
  }

  try {
    await navigator.clipboard.writeText(outputText);
    clearError();
    dom.status.textContent = "Copied ASCII art to the clipboard.";
  } catch {
    const textarea = document.createElement("textarea");
    textarea.value = outputText;
    textarea.style.position = "fixed";
    textarea.style.opacity = "0";
    document.body.append(textarea);
    textarea.select();
    const copied = document.execCommand("copy");
    textarea.remove();

    if (!copied) {
      showError("The ASCII art could not be copied.");
      return;
    }

    clearError();
    dom.status.textContent = "Copied ASCII art to the clipboard.";
  }
});

dom.downloadButton.addEventListener("click", () => {
  if (!outputText) {
    return;
  }

  try {
    const width = dom.widthInput.valueAsNumber;
    const height = dom.heightInput.valueAsNumber;
    const baseName = sourceFileName
      .replace(/\.[^.]+$/, "")
      .replace(/[^a-zA-Z0-9._-]+/g, "-")
      .replace(/^-+|-+$/g, "") || "ascii-art";
    const blob = new Blob([outputText], { type: "text/plain;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = `${baseName}-${width}x${height}.txt`;
    document.body.append(link);
    link.click();
    link.remove();
    window.setTimeout(() => URL.revokeObjectURL(url), 1000);
    clearError();
    dom.status.textContent = "Downloaded ASCII art as a text file.";
  } catch {
    showError("The ASCII art could not be downloaded.");
  }
});

window.addEventListener("pagehide", () => {
  if (sourceImageUrl) {
    URL.revokeObjectURL(sourceImageUrl);
  }
});
