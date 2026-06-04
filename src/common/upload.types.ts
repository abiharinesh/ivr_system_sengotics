/** Multer file shape (avoids requiring @types/multer in all services). */
export interface UploadedImageFile {
  buffer: Buffer;
  originalname: string;
  mimetype?: string;
  size?: number;
}
