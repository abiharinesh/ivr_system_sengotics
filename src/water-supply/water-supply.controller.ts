import {
  Controller,
  Get,
  Post,
  Body,
  Query,
  Param,
  ParseIntPipe,
} from '@nestjs/common';
import { WaterSupplyService } from './water-supply.service';

@Controller('api/water-supply')
export class WaterSupplyController {
  constructor(private readonly waterSupplyService: WaterSupplyService) {}

  @Get('pipelines')
  async getPipelines(@Query('panchayat_id', ParseIntPipe) panchayatId: number) {
    return this.waterSupplyService.findPipelines(panchayatId);
  }

  @Get('tanks')
  async getTanks(@Query('panchayat_id', ParseIntPipe) panchayatId: number) {
    return this.waterSupplyService.findTanks(panchayatId);
  }

  @Get('valves')
  async getValves(@Query('panchayat_id', ParseIntPipe) panchayatId: number) {
    return this.waterSupplyService.findValves(panchayatId);
  }

  @Get('flow-logs')
  async getFlowLogs(@Query('panchayat_id', ParseIntPipe) panchayatId: number) {
    const logs = await this.waterSupplyService.findFlowLogs(panchayatId);
    return logs.map((log) => ({
      ...log,
      id: Number(log.id),
    }));
  }

  @Post('flow-logs')
  async postFlowLog(
    @Body()
    body: {
      pipeline_id?: number;
      tank_id?: number;
      flow_rate_lps: number;
      pressure_bar: number;
    },
  ) {
    const log = await this.waterSupplyService.createFlowLog(body);
    return {
      ...log,
      id: Number(log.id),
    };
  }

  @Post('pipelines/:id/leak')
  async triggerLeak(@Param('id', ParseIntPipe) id: number) {
    return this.waterSupplyService.simulateLeak(id);
  }

  @Get('captured-assets')
  async getCapturedAssets() {
    return this.waterSupplyService.findCapturedAssets();
  }

  @Post('captured-assets')
  async createCapturedAsset(
    @Body()
    body: {
      type: string;
      material: string;
      diameter_mm: number;
      latitude: number;
      longitude: number;
      photo_url?: string;
      agent_name: string;
      device_model?: string;
      altitude?: number;
      precision?: number;
    },
  ) {
    return this.waterSupplyService.createCapturedAsset(body);
  }

  @Post('captured-assets/:id/approve')
  async approveCapturedAsset(
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { comment: string },
  ) {
    return this.waterSupplyService.approveCapturedAsset(id, body.comment);
  }

  @Post('captured-assets/:id/reject')
  async rejectCapturedAsset(
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { comment: string },
  ) {
    return this.waterSupplyService.rejectCapturedAsset(id, body.comment);
  }
}

