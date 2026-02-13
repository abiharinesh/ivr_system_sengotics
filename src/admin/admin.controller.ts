import { Controller, Get, Post, Put, Delete, Patch, Body, Param, Query, ParseIntPipe } from '@nestjs/common'
import { AdminService } from './admin.service'
import { CreatePoleDto, UpdatePoleDto } from './dto/pole.dto'
import { CreatePanchayatDto, UpdatePanchayatDto } from './dto/panchayat.dto'
import { UpdateComplaintStatusDto } from './dto/complaint.dto'

@Controller('api/admin')
export class AdminController {
    constructor(private readonly adminService: AdminService) { }

    // Pole Management
    @Post('poles')
    async createPole(@Body() data: CreatePoleDto) {
        return this.adminService.createPole(data)
    }

    @Put('poles/:id')
    async updatePole(@Param('id', ParseIntPipe) id: number, @Body() data: UpdatePoleDto) {
        return this.adminService.updatePole(id, data)
    }

    @Delete('poles/:id')
    async deletePole(@Param('id', ParseIntPipe) id: number) {
        return this.adminService.deletePole(id)
    }

    @Get('poles')
    async listPoles(@Query('panchayat_id') panchayatId?: string) {
        return this.adminService.listPoles(panchayatId ? parseInt(panchayatId) : undefined)
    }

    // Panchayat Management
    @Post('panchayats')
    async createPanchayat(@Body() data: CreatePanchayatDto) {
        return this.adminService.createPanchayat(data)
    }

    @Put('panchayats/:id')
    async updatePanchayat(@Param('id', ParseIntPipe) id: number, @Body() data: UpdatePanchayatDto) {
        return this.adminService.updatePanchayat(id, data)
    }

    @Get('panchayats')
    async listPanchayats() {
        return this.adminService.listPanchayats()
    }

    // Complaint Management
    @Get('complaints')
    async listComplaints(@Query('status') status?: string, @Query('panchayat_id') panchayatId?: string) {
        return this.adminService.listComplaints(status, panchayatId ? parseInt(panchayatId) : undefined)
    }

    @Patch('complaints/:id/status')
    async updateComplaintStatus(@Param('id', ParseIntPipe) id: number, @Body() data: UpdateComplaintStatusDto) {
        return this.adminService.updateComplaintStatus(id, data)
    }

    // Dashboard Stats
    @Get('stats')
    async getStats() {
        return this.adminService.getStats()
    }
}
