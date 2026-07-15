import { Injectable, Logger, OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { parseLatLongFromText } from './field-coord.util';

export interface OverlayOcrResult {
  lat: number | null;
  lng: number | null;
  rawText: string;
  address: string | null;
  skipped: boolean;
}

type TesseractWorker = {
  recognize(image: Buffer): Promise<{ data: { text?: string } }>;
  terminate(): Promise<any>;
};

@Injectable()
export class FieldOverlayOcrService implements OnModuleDestroy {
  private readonly logger = new Logger(FieldOverlayOcrService.name);
  private workerPromise: Promise<TesseractWorker | null> | null = null;

  constructor(private readonly config: ConfigService) {}

  private isEnabled(): boolean {
    const flag = this.config.get<string>('FIELD_OCR_ENABLED');
    if (flag === 'false' || flag === '0') return false;
    return true;
  }

  private loadSharp(): ((input: Buffer) => any) | null {
    try {
      // eslint-disable-next-line @typescript-eslint/no-require-imports
      return require('sharp');
    } catch {
      return null;
    }
  }

  private async getWorker(): Promise<TesseractWorker | null> {
    if (this.workerPromise === null) {
      this.workerPromise = (async () => {
        try {
          const { createWorker } =
            require('tesseract.js') as typeof import('tesseract.js');
          return await createWorker('eng');
        } catch (err: unknown) {
          this.logger.warn(
            `Tesseract.js unavailable (run npm install tesseract.js): ${err instanceof Error ? err.message : err}`,
          );
          return null;
        }
      })();
    }
    return this.workerPromise;
  }

  async onModuleDestroy() {
    if (!this.workerPromise) return;
    try {
      const worker = await this.workerPromise;
      if (worker?.terminate) await worker.terminate();
    } catch (err: unknown) {
      this.logger.warn(
        `Failed to terminate OCR worker: ${err instanceof Error ? err.message : err}`,
      );
    }
    this.workerPromise = null;
  }

  /** Best-effort ASCII scan of JPEG buffer (fallback when OCR libs missing). */
  private scanBufferAscii(buffer: Buffer): string {
    return buffer.toString('latin1').replace(/[^\x20-\x7E\n\r\t]/g, ' ');
  }

  /** Crop bottom overlay strip and run Tesseract; never throws. */
  async extractOverlayCoords(imageBuffer: Buffer): Promise<OverlayOcrResult> {
    const empty: OverlayOcrResult = {
      lat: null,
      lng: null,
      rawText: '',
      address: null,
      skipped: true,
    };
    if (!this.isEnabled() || !imageBuffer?.length) return empty;

    const googleApiKey = this.config.get<string>('GOOGLE_VISION_API_KEY');
    if (googleApiKey) {
      try {
        this.logger.log('Running Google Cloud Vision OCR...');
        const base64Image = imageBuffer.toString('base64');
        const response = await fetch(
          `https://vision.googleapis.com/v1/images:annotate?key=${googleApiKey}`,
          {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              requests: [
                {
                  image: {
                    content: base64Image,
                  },
                  features: [
                    {
                      type: 'TEXT_DETECTION',
                    },
                  ],
                },
              ],
            }),
          },
        );

        if (!response.ok) {
          throw new Error(
            `Google Vision API responded with status ${response.status}`,
          );
        }

        const data: any = await response.json();
        const textAnnotations = data.responses?.[0]?.textAnnotations;
        if (textAnnotations && textAnnotations.length > 0) {
          const rawText = textAnnotations[0].description;
          const { lat, lng } = parseLatLongFromText(rawText);
          const address = this.extractAddressLine(rawText);
          return { lat, lng, rawText, address, skipped: false };
        }
      } catch (err: unknown) {
        this.logger.error(
          `Google Cloud Vision OCR failed: ${err instanceof Error ? err.message : err}`,
        );
        // Fall back to local Tesseract/ASCII if Google fails
      }
    }

    // On Vercel, skip the heavy Tesseract.js + sharp pipeline — it takes 30-60s
    // and causes 504 timeouts. The fast ASCII buffer scan extracts GPS coords
    // from GPS Map Camera overlay text embedded in the JPEG.
    if (process.env.VERCEL) {
      const rawText = this.scanBufferAscii(imageBuffer);
      const { lat, lng } = parseLatLongFromText(rawText);
      const address = lat != null ? this.extractAddressLine(rawText) : null;
      return { lat, lng, rawText, address, skipped: false };
    }

    const sharp = this.loadSharp();
    const worker = await this.getWorker();

    if (!sharp || !worker?.recognize) {
      const rawText = this.scanBufferAscii(imageBuffer);
      const { lat, lng } = parseLatLongFromText(rawText);
      if (lat != null && lng != null) {
        return { lat, lng, rawText, address: null, skipped: false };
      }
      return { ...empty, skipped: !sharp && !worker, rawText };
    }

    try {
      const meta = await sharp(imageBuffer).metadata();
      const height = meta.height ?? 0;
      const width = meta.width ?? 0;
      if (height < 40 || width < 40) return empty;

      const cropTop = Math.floor(height * 0.65);
      const cropHeight = height - cropTop;
      const cropped = await sharp(imageBuffer)
        .extract({ left: 0, top: cropTop, width, height: cropHeight })
        .grayscale()
        .normalize()
        .png()
        .toBuffer();

      const { data } = await worker.recognize(cropped);
      const rawText = (data.text ?? '').trim();
      if (!rawText) return { ...empty, skipped: false, rawText: '' };

      const { lat, lng } = parseLatLongFromText(rawText);
      const address = this.extractAddressLine(rawText);

      return { lat, lng, rawText, address, skipped: false };
    } catch (err: unknown) {
      this.logger.warn(
        `Overlay OCR failed: ${err instanceof Error ? err.message : err}`,
      );
      const rawText = this.scanBufferAscii(imageBuffer);
      const { lat, lng } = parseLatLongFromText(rawText);
      if (lat != null && lng != null) {
        return { lat, lng, rawText, address: null, skipped: false };
      }
      return empty;
    }
  }

  private extractAddressLine(text: string): string | null {
    const lines = text
      .split(/\r?\n/)
      .map((l) => l.trim())
      .filter(Boolean);
    for (const line of lines) {
      if (/^lat\s/i.test(line) || /^long\s/i.test(line)) continue;
      if (/^\d{1,2}:\d{2}/.test(line)) continue;
      if (/gps map camera/i.test(line)) continue;
      if (line.length > 12 && /,/.test(line)) return line;
    }
    return null;
  }
}
