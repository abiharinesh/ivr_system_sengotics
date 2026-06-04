import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  Post,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { FileInterceptor } from '@nestjs/platform-express';
import type { UploadedImageFile } from '../common/upload.types';
import { FieldVerificationService } from './field-verification.service';

const IMAGE_LIMIT = 12 * 1024 * 1024;
const ALLOWED_MIME = new Set(['image/jpeg', 'image/png', 'image/webp']);

@Controller('public/field-sessions')
export class FieldVerificationPublicController {
  constructor(private readonly service: FieldVerificationService) {}

  @Get(':token')
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  read(@Param('token') token: string) {
    return this.service.readSessionPublic(token);
  }

  @Post(':token/uploads')
  @Throttle({ default: { limit: 12, ttl: 60_000 } })
  @UseInterceptors(
    FileInterceptor('file', { limits: { fileSize: IMAGE_LIMIT } }),
  )
  upload(
    @Param('token') token: string,
    @UploadedFile() file: UploadedImageFile,
    @Body() body: Record<string, unknown>,
  ) {
    if (!file?.buffer?.length)
      throw new BadRequestException('file is required');
    if (file.mimetype && !ALLOWED_MIME.has(file.mimetype)) {
      throw new BadRequestException(`image type ${file.mimetype} not allowed`);
    }
    const manualPoleId =
      body.manual_pole_id != null ? Number(body.manual_pole_id) : null;
    if (manualPoleId !== null && !Number.isInteger(manualPoleId)) {
      throw new BadRequestException('manual_pole_id must be an integer');
    }
    const notes = typeof body.notes === 'string' ? body.notes : null;
    return this.service.submitUpload({
      token,
      image: file,
      manualPoleId,
      notes,
    });
  }
}
