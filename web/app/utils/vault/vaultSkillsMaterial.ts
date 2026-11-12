// What Ayla looks at for her skill proposal besides the form (iOS VaultSkillsMaterialReader): the text of a PDF or text
// file, and a small JPEG photo of an image or of a PDF without text (a scan). Only sent when she is asked, and nothing
// of it is stored. A Word file cannot be read here and is left out.

export interface VaultSkillsMaterial {
  files: { name: string; text: string }[];
  images: { name: string; data: string }[];
}

const MAXIMUM_TEXT_LENGTH = 6000;
const MAXIMUM_IMAGES = 4;
const PHOTO_SIDE = 1024;
// A PDF with less text than this is probably a scan: Ayla gets a photo of its first page instead.
const MINIMUM_PDF_TEXT = 40;
// Enough pages to fill the text Ayla reads; a long report is not read to the end.
const MAXIMUM_PDF_PAGES = 15;
// The Edge Function refuses a photo above 1.4 million base64 characters.
const MAXIMUM_BASE64 = 1_400_000;

function isPdf(file: File) {
  return file.type === 'application/pdf' || /\.pdf$/i.test(file.name);
}

function toBase64(canvas: HTMLCanvasElement) {
  const data = canvas.toDataURL('image/jpeg', 0.7).split(',')[1] ?? '';
  return data && data.length <= MAXIMUM_BASE64 ? data : null;
}

/**
 * The text of a PDF, or a photo of its first page when it has (almost) none. The reader is only fetched when a PDF is
 * actually read, so it does not weigh on the rest of the app. A PDF that cannot be opened (a password, damage) gives
 * nothing.
 */
async function readPdf(file: File): Promise<{ text: string } | { photo: string } | null> {
  try {
    const [pdfjs, worker] = await Promise.all([import('pdfjs-dist'), import('pdfjs-dist/build/pdf.worker.min.mjs?url')]);
    pdfjs.GlobalWorkerOptions.workerSrc = worker.default;
    const task = pdfjs.getDocument({ data: await file.arrayBuffer() });
    try {
      const pdf = await task.promise;
      let text = '';
      for (let number = 1; number <= Math.min(pdf.numPages, MAXIMUM_PDF_PAGES) && text.length < MAXIMUM_TEXT_LENGTH; number += 1) {
        const content = await (await pdf.getPage(number)).getTextContent();
        text += `${content.items.map((item) => ('str' in item ? item.str : '')).join(' ')}\n`;
      }
      text = text.replace(/[ \t]+/g, ' ').trim();
      if (text.length >= MINIMUM_PDF_TEXT) return { text: text.slice(0, MAXIMUM_TEXT_LENGTH) };

      const page = await pdf.getPage(1);
      const size = page.getViewport({ scale: 1 });
      const viewport = page.getViewport({ scale: PHOTO_SIDE / Math.max(size.width, size.height) });
      const canvas = document.createElement('canvas');
      canvas.width = Math.round(viewport.width);
      canvas.height = Math.round(viewport.height);
      const context = canvas.getContext('2d');
      if (!context) return null;
      context.fillStyle = '#fff';
      context.fillRect(0, 0, canvas.width, canvas.height);
      await page.render({ canvas, canvasContext: context, viewport }).promise;
      const photo = toBase64(canvas);
      return photo ? { photo } : null;
    } finally {
      await task.destroy();
    }
  } catch {
    return null;
  }
}

function isText(file: File) {
  return file.type.startsWith('text/') || /\.(txt|md|csv)$/i.test(file.name);
}

/** The picture made smaller, as base64 JPEG; null when the browser cannot show it (HEIC, for instance). */
function photo(file: File) {
  return new Promise<string | null>((resolve) => {
    const url = URL.createObjectURL(file);
    const image = new Image();
    image.onerror = () => {
      URL.revokeObjectURL(url);
      resolve(null);
    };
    image.onload = () => {
      URL.revokeObjectURL(url);
      const scale = Math.min(1, PHOTO_SIDE / Math.max(image.naturalWidth, image.naturalHeight));
      const canvas = document.createElement('canvas');
      canvas.width = Math.max(1, Math.round(image.naturalWidth * scale));
      canvas.height = Math.max(1, Math.round(image.naturalHeight * scale));
      const context = canvas.getContext('2d');
      if (!context) return resolve(null);
      context.fillStyle = '#fff';
      context.fillRect(0, 0, canvas.width, canvas.height);
      context.drawImage(image, 0, 0, canvas.width, canvas.height);
      resolve(toBase64(canvas));
    };
    image.src = url;
  });
}

export async function readSkillsMaterial(documents: File[]): Promise<VaultSkillsMaterial> {
  const material: VaultSkillsMaterial = { files: [], images: [] };
  for (const file of documents) {
    if (isPdf(file)) {
      const read = await readPdf(file);
      if (read && 'text' in read) material.files.push({ name: file.name, text: read.text });
      else if (read && material.images.length < MAXIMUM_IMAGES) material.images.push({ name: file.name, data: read.photo });
    } else if (isText(file)) {
      const text = (await file.text().catch(() => '')).trim().slice(0, MAXIMUM_TEXT_LENGTH);
      if (text) material.files.push({ name: file.name, text });
    } else if (file.type.startsWith('image/') && material.images.length < MAXIMUM_IMAGES) {
      const data = await photo(file);
      if (data) material.images.push({ name: file.name, data });
    }
  }
  return material;
}
