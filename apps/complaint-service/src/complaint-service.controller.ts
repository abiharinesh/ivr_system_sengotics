import { Controller, Get, Post, Patch, Param, Query, Body, ParseIntPipe } from '@nestjs/common'
import { ComplaintServiceService } from './complaint-service.service'

@Controller('complaints')
export class ComplaintServiceController {
    constructor(private readonly service: ComplaintServiceService) {}

    @Get()
    list(@Query('panchayat_id') pid?: string, @Query('status') status?: string) {
        const panchayatId = pid ? parseInt(pid, 10) : null
        return this.service.listComplaints(
            isNaN(panchayatId as number) ? null : panchayatId, status,
        )
    }

    @Post()
    create(@Body() body: {
        pole_id: number; panchayat_id?: number; complaint_type?: string;
        description?: string; urgency_level?: string;
        caller_language?: string; caller_emotion?: string;
    }) {
        return this.service.createComplaint(body)
    }

    @Patch(':id/status')
    updateStatus(@Param('id', ParseIntPipe) id: number, @Body() body: { status: string }) {
        return this.service.updateStatus(id, body.status)
    }

    @Patch(':id/resolve')
    resolve(@Param('id', ParseIntPipe) id: number, @Body() body: { pole_id: number }) {
        return this.service.resolveComplaint(id, body.pole_id)
    }

    @Patch(':id/assign-electrician')
    assignElectrician(
        @Param('id', ParseIntPipe) id: number,
        @Body() body: { electrician_user_id: number },
    ) {
        return this.service.assignElectrician(id, body.electrician_user_id)
    }

    @Get('clusters/tender-eligible')
    tenderEligible(@Query('panchayat_id') pid?: string) {
        const panchayatId = pid ? parseInt(pid, 10) : undefined
        return this.service.getComplaintClustersForTender(
            isNaN(panchayatId as number) ? undefined : panchayatId,
        )
    }
}
