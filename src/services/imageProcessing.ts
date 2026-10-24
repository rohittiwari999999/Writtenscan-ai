import { ImageAdjustments } from '../types';

/**
 * Loads an image from a data URL or Blob URL into an HTMLImageElement
 */
export function loadImage(src: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.crossOrigin = 'anonymous';
    img.onload = () => resolve(img);
    img.onerror = (err) => reject(err);
    img.src = src;
  });
}

/**
 * Applies adjustments (rotation, straighten angle, brightness, contrast, filter, crop)
 * onto a Canvas and returns a new JPEG base64 Data URL.
 */
export async function processImageOnCanvas(
  sourceUrl: string,
  adjustments: ImageAdjustments
): Promise<string> {
  const img = await loadImage(sourceUrl);

  const canvas = document.createElement('canvas');
  const ctx = canvas.getContext('2d', { willReadFrequently: true });
  if (!ctx) throw new Error('Could not initialize 2D canvas context');

  // Total rotation angle in radians (90 deg increments + fine straighten angle)
  const totalDegrees = (adjustments.rotation + adjustments.straightenAngle) % 360;
  const radians = (totalDegrees * Math.PI) / 180;

  // Calculate bounding box for rotated image
  const cos = Math.abs(Math.cos(radians));
  const sin = Math.abs(Math.sin(radians));
  const origW = img.naturalWidth || img.width;
  const origH = img.naturalHeight || img.height;

  // Max dimension limit to ensure fast processing on mobile/browser
  const maxDim = 2400;
  let scale = 1;
  if (Math.max(origW, origH) > maxDim) {
    scale = maxDim / Math.max(origW, origH);
  }

  const w = origW * scale;
  const h = origH * scale;

  const rotatedW = Math.round(w * cos + h * sin);
  const rotatedH = Math.round(w * sin + h * cos);

  canvas.width = rotatedW;
  canvas.height = rotatedH;

  // Clear canvas
  ctx.fillStyle = '#ffffff';
  ctx.fillRect(0, 0, rotatedW, rotatedH);

  // Rotate around center
  ctx.save();
  ctx.translate(rotatedW / 2, rotatedH / 2);
  ctx.rotate(radians);
  ctx.drawImage(img, -w / 2, -h / 2, w, h);
  ctx.restore();

  // If cropRect is provided (in normalized 0-1 coordinates)
  let finalCanvas = canvas;
  if (
    adjustments.cropRect &&
    adjustments.cropRect.width > 0.05 &&
    adjustments.cropRect.height > 0.05
  ) {
    const cropCanvas = document.createElement('canvas');
    const cropCtx = cropCanvas.getContext('2d', { willReadFrequently: true });
    if (cropCtx) {
      const cropX = Math.max(0, Math.round(adjustments.cropRect.x * rotatedW));
      const cropY = Math.max(0, Math.round(adjustments.cropRect.y * rotatedH));
      const cropW = Math.min(rotatedW - cropX, Math.round(adjustments.cropRect.width * rotatedW));
      const cropH = Math.min(rotatedH - cropY, Math.round(adjustments.cropRect.height * rotatedH));

      cropCanvas.width = cropW;
      cropCanvas.height = cropH;
      cropCtx.drawImage(canvas, cropX, cropY, cropW, cropH, 0, 0, cropW, cropH);
      finalCanvas = cropCanvas;
    }
  }

  // Pixel manipulation for brightness, contrast, and filters
  const fCtx = finalCanvas.getContext('2d', { willReadFrequently: true });
  if (fCtx) {
    const imgData = fCtx.getImageData(0, 0, finalCanvas.width, finalCanvas.height);
    const data = imgData.data;

    const b = adjustments.brightness; // -50 to +50
    const c = adjustments.contrast; // -50 to +50
    // Contrast factor: [-50, 50] mapped to [0.5, 2.0]
    const factor = (259 * (c + 255)) / (255 * (259 - c));

    for (let i = 0; i < data.length; i += 4) {
      let red = data[i];
      let green = data[i + 1];
      let blue = data[i + 2];

      // Apply brightness & contrast
      if (b !== 0 || c !== 0) {
        red = factor * (red + b - 128) + 128;
        green = factor * (green + b - 128) + 128;
        blue = factor * (blue + b - 128) + 128;
      }

      // Filter modes
      if (adjustments.filter === 'grayscale') {
        const gray = 0.299 * red + 0.587 * green + 0.114 * blue;
        red = green = blue = gray;
      } else if (adjustments.filter === 'binarize') {
        // Document scanner adaptive threshold
        const gray = 0.299 * red + 0.587 * green + 0.114 * blue;
        const thresh = 135;
        const val = gray > thresh ? 255 : 0;
        red = green = blue = val;
      } else if (adjustments.filter === 'magic_sharp') {
        // High contrast boost for handwriting ink
        const gray = 0.299 * red + 0.587 * green + 0.114 * blue;
        const sharp = gray < 120 ? Math.max(0, gray * 0.7) : Math.min(255, gray * 1.25);
        red = green = blue = sharp;
      } else if (adjustments.filter === 'warm') {
        red = Math.min(255, red * 1.06);
        green = Math.min(255, green * 1.02);
        blue = Math.max(0, blue * 0.92);
      }

      // Clamp RGB
      data[i] = Math.max(0, Math.min(255, red));
      data[i + 1] = Math.max(0, Math.min(255, green));
      data[i + 2] = Math.max(0, Math.min(255, blue));
    }

    fCtx.putImageData(imgData, 0, 0);
  }

  return finalCanvas.toDataURL('image/jpeg', 0.92);
}

/**
 * Creates a small thumbnail data URL for document history listing
 */
export async function createThumbnail(sourceUrl: string, maxDimension = 200): Promise<string> {
  const img = await loadImage(sourceUrl);
  const canvas = document.createElement('canvas');
  const ctx = canvas.getContext('2d');
  if (!ctx) return sourceUrl;

  const w = img.naturalWidth || img.width;
  const h = img.naturalHeight || img.height;
  const scale = Math.min(maxDimension / w, maxDimension / h, 1);

  canvas.width = Math.round(w * scale);
  canvas.height = Math.round(h * scale);

  ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
  return canvas.toDataURL('image/jpeg', 0.75);
}
