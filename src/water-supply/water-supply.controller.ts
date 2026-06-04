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
}
