import {
    Controller, Post, Get, Patch, Param, Query, Body,
    ParseIntPipe, UseInterceptors, UploadedFile, BadRequestException,
} from '@nestjs/common'
import { FileInterceptor } from '@nestjs/platform-express'
import type { UploadedImageFile } from '@app/shared'
import { parseGeoFromBody, strFieldOptional } from '@app/shared'
import { WorkOrderServiceService } from './work-order-service.service'

const IMAGE_LIMIT = 12 * 1024 * 1024

@Controller('work-orders')
export class WorkOrderServiceController {
    constructor(private readonly service: WorkOrderServiceService) {}

    @Post('award')
    award(@Body() body: {
        panchayat_id: number; tender_id: number;
        quotation_id: number; user_id: number; due_date?: string
    }) {
        return this.service.awardQuotationAndCreateWorkOrder(
            body.panchayat_id, body.tender_id,
            body.quotation_id, body.user_id, body.due_date,
        )
    }

    @Post('proof/:token')
    @UseInterceptors(FileInterceptor('file', { limits: { fileSize: IMAGE_LIMIT } }))
    submitProof(
        @Param('token') token: string,
        @UploadedFile() file: UploadedImageFile,
        @Body() body: Record<string, unknown>,
    ) {
        if (!file?.buffer?.length) throw new BadRequestException('file is required')
        const geo = parseGeoFromBody(body)
        return this.service.submitWorkProofByToken(token, file, {
            ...geo,
            submitter_name: strFieldOptional(body, 'submitter_name'),
            submitter_phone: strFieldOptional(body, 'submitter_phone'),
            note: strFieldOptional(body, 'note'),
            complaint_id: body.complaint_id != null ? Number(body.complaint_id) : undefined,
        })
    }

    @Get('proofs/review')
    reviewQueue(
        @Query('panchayat_id', ParseIntPipe) pid: number,
        @Query('status') status?: 'matched' | 'unmatched_manual_review',
    ) {
        return this.service.listWorkOrderProofsForReview(pid, status)
    }

    @Patch('proofs/:proofId/review')
    reviewProof(
        @Query('panchayat_id', ParseIntPipe) pid: number,
        @Param('proofId', ParseIntPipe) proofId: number,
        @Body() body: { approve: boolean; note?: string; user_id: number },
    ) {
        return this.service.approveProofManual(pid, proofId, body.user_id, body.approve, body.note)
    }

    @Get('dashboard-metrics')
    dashboardMetrics(@Query('panchayat_id', ParseIntPipe) pid: number) {
        return this.service.getDashboardMetrics(pid)
    }
}
