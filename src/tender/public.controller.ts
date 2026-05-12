import {
    BadRequestException,
    Body,
    Controller,
    Get,
    Param,
    Post,
    Req,
    UploadedFile,
    UseInterceptors,
} from '@nestjs/common'
import { Throttle } from '@nestjs/throttler'
import { FileInterceptor } from '@nestjs/platform-express'
import type { Request } from 'express'
import type { UploadedImageFile } from '../common/upload.types'
import { TenderPublicService } from './public.service'

const ATTACHMENT_LIMIT = 8 * 1024 * 1024
const ALLOWED_MIME = new Set([
    'image/jpeg', 'image/png', 'image/webp', 'application/pdf',
])

@Controller('public/tenders')
export class TenderPublicController {
    constructor(private readonly service: TenderPublicService) {}

    @Get(':token')
    @Throttle({ default: { limit: 30, ttl: 60_000 } })
    read(@Param('token') token: string) {
        return this.service.readPublic(token)
    }

    @Post(':token/quotations')
    @Throttle({ default: { limit: 5, ttl: 60_000 } })
    @UseInterceptors(
        FileInterceptor('attachment', {
            limits: { fileSize: ATTACHMENT_LIMIT },
        })
    )
    submit(
        @Param('token') token: string,
        @Req() req: Request,
        @UploadedFile() file: UploadedImageFile | undefined,
        @Body() body: Record<string, unknown>
    ) {
        if (file && file.mimetype && !ALLOWED_MIME.has(file.mimetype)) {
            throw new BadRequestException(`attachment type ${file.mimetype} not allowed`)
        }
        const ip = (req.headers['x-forwarded-for'] as string)?.split(',')[0]?.trim() || req.ip || ''
        return this.service.submitQuotation({
            token,
            body: {
                phone: typeof body.phone === 'string' ? body.phone : undefined,
                name: typeof body.name === 'string' ? body.name : undefined,
                amount: body.amount as any,
                remarks: typeof body.remarks === 'string' ? body.remarks : undefined,
            },
            ipAddress: ip,
            attachment: file?.buffer ? file : null,
        })
    }
}
