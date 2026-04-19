import { Controller, Post, Get, Delete, Body, Param, Query, ParseIntPipe } from '@nestjs/common'
import { TenderServiceService } from './tender-service.service'

@Controller('tenders')
export class TenderServiceController {
    constructor(private readonly service: TenderServiceService) {}

    @Post()
    create(@Body() body: {
        panchayat_id: number; user_id: number; complaint_ids: number[];
        required_quantity?: number; light_type?: string;
        work_type: string; submission_deadline: string;
    }) {
        return this.service.createTender(body.panchayat_id, body.user_id, body)
    }

    @Get()
    list(@Query('panchayat_id', ParseIntPipe) pid: number) {
        return this.service.listTenders(pid)
    }

    @Get(':id/links')
    listLinks(@Query('panchayat_id', ParseIntPipe) pid: number, @Param('id', ParseIntPipe) id: number) {
        return this.service.listTenderLinks(pid, id)
    }

    @Delete('links/:linkId')
    revokeLink(@Query('panchayat_id', ParseIntPipe) pid: number, @Param('linkId', ParseIntPipe) linkId: number) {
        return this.service.revokeInviteLink(pid, linkId)
    }

    @Get(':id/lifecycle-export')
    exportLifecycle(@Query('panchayat_id', ParseIntPipe) pid: number, @Param('id', ParseIntPipe) id: number) {
        return this.service.exportTenderLifecycle(pid, id)
    }
}
