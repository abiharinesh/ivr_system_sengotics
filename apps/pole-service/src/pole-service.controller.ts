import { Controller, Get, Post, Put, Delete, Body, Param, Query, ParseIntPipe } from '@nestjs/common'
import { PoleServiceService } from './pole-service.service'

@Controller('poles')
export class PoleServiceController {
    constructor(private readonly service: PoleServiceService) {}

    @Post()
    create(@Body() body: {
        panchayat_id: number; pole_number?: string; keypad_id?: string;
        latitude?: number; longitude?: number; landmarks?: string[];
    }) {
        return this.service.create(body)
    }

    @Get()
    list(@Query('panchayat_id') pid?: string) {
        const panchayatId = pid ? parseInt(pid, 10) : undefined
        return this.service.list(isNaN(panchayatId as number) ? undefined : panchayatId)
    }

    @Put(':id')
    update(@Param('id', ParseIntPipe) id: number, @Body() body: any) {
        return this.service.update(id, body)
    }

    @Delete(':id')
    remove(@Param('id', ParseIntPipe) id: number) {
        return this.service.remove(id)
    }
}
