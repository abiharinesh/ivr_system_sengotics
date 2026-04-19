import { Controller, Post, Get, Param, Query, Body, ParseIntPipe, UseInterceptors, UploadedFile } from '@nestjs/common'
import { FileInterceptor } from '@nestjs/platform-express'
import type { UploadedImageFile } from '@app/shared'
import { QuotationServiceService } from './quotation-service.service'

const IMAGE_LIMIT = 12 * 1024 * 1024

@Controller('quotations')
export class QuotationServiceController {
    constructor(private readonly service: QuotationServiceService) {}

    @Post('submit/:token')
    @UseInterceptors(FileInterceptor('document', { limits: { fileSize: IMAGE_LIMIT } }))
    submitQuotation(
        @Param('token') token: string,
        @UploadedFile() document: UploadedImageFile,
        @Body() body: {
            company_name: string
            contact_person: string
            mobile_number: string
            quantity: number | string
            price_per_light: number | string
            installation_cost?: number | string
            delivery_days: number | string
            warranty_months: number | string
            seller_rating?: number | string
            experience_years?: number | string
            notes?: string
            vendor_user_id?: number | string
        }
    ) {
        return this.service.submitQuotationByToken(token, {
            vendor_user_id: body.vendor_user_id ? Number(body.vendor_user_id) : undefined,
            company_name: body.company_name,
            contact_person: body.contact_person,
            mobile_number: body.mobile_number,
            quantity: Number(body.quantity),
            price_per_light: Number(body.price_per_light),
            installation_cost: body.installation_cost == null ? 0 : Number(body.installation_cost),
            delivery_days: Number(body.delivery_days),
            warranty_months: Number(body.warranty_months),
            seller_rating: body.seller_rating == null ? 3 : Number(body.seller_rating),
            experience_years: body.experience_years == null ? 1 : Number(body.experience_years),
            notes: body.notes,
            document,
        })
    }

    @Get('leaderboard')
    leaderboard(
        @Query('panchayat_id', ParseIntPipe) pid: number,
        @Query('tender_id', ParseIntPipe) tenderId: number,
    ) {
        return this.service.getQuotationLeaderboard(pid, tenderId)
    }
}
