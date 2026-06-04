declare module 'tesseract.js' {
  export interface RecognizeResult {
    data: { text?: string };
  }
  export interface Worker {
    recognize(image: Buffer): Promise<RecognizeResult>;
    terminate(): Promise<void>;
  }
  export function createWorker(
    lang?: string,
    ...args: unknown[]
  ): Promise<Worker>;
}

declare module 'sharp' {
  interface SharpInstance {
    metadata(): Promise<{ width?: number; height?: number }>;
    extract(region: {
      left: number;
      top: number;
      width: number;
      height: number;
    }): SharpInstance;
    grayscale(): SharpInstance;
    normalize(): SharpInstance;
    png(): SharpInstance;
    toBuffer(): Promise<Buffer>;
  }
  function sharp(input: Buffer): SharpInstance;
  export default sharp;
}
