import {
  Controller,
  Get,
  Post,
  Delete,
  Patch,
  Body,
  Query,
  Param,
  Req,
  ParseIntPipe,
  UseGuards,
  ForbiddenException,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { WaterSupplyService } from './water-supply.service';

interface AuthedRequest {
  user: { id: number; tenant_id: string; org_unit_id: number | null };
}

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('super_admin', 'panchayat_admin', 'municipal_engineer', 'assistant_engineer', 'junior_engineer', 'plumber', 'agent')
@Controller('api/water-supply')
export class WaterSupplyController {
  constructor(private readonly waterSupplyService: WaterSupplyService) {}

  /** Caller's org unit — captured assets are always scoped to it. */
  private scopeOf(req: AuthedRequest): { tenantId: string; orgUnitId: number } {
    if (req.user.org_unit_id == null) {
      throw new ForbiddenException(
        'Your account has no assigned org unit. Contact your administrator.',
      );
    }
    return { tenantId: req.user.tenant_id, orgUnitId: req.user.org_unit_id };
  }

  @Get('pipelines')
  async getPipelines(@Query('org_unit_id', ParseIntPipe) orgUnitId: number) {
    return this.waterSupplyService.findPipelines(orgUnitId);
  }

  @Get('tanks')
  async getTanks(@Query('org_unit_id', ParseIntPipe) orgUnitId: number) {
    return this.waterSupplyService.findTanks(orgUnitId);
  }

  @Get('valves')
  async getValves(@Query('org_unit_id', ParseIntPipe) orgUnitId: number) {
    return this.waterSupplyService.findValves(orgUnitId);
  }

  @Get('flow-logs')
  async getFlowLogs(@Query('org_unit_id', ParseIntPipe) orgUnitId: number) {
    const logs = await this.waterSupplyService.findFlowLogs(orgUnitId);
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

  @Post('pipelines')
  async createPipeline(
    @Body()
    body: {
      name?: string;
      org_unit_id: number;
      path_geojson: any;
      diameter_mm?: number;
      material?: string;
      status?: string;
    },
  ) {
    return this.waterSupplyService.createPipeline(body);
  }

  @Post('pipelines/:id/leak')
  async triggerLeak(@Param('id', ParseIntPipe) id: number) {
    return this.waterSupplyService.simulateLeak(id);
  }

  @Get('captured-assets')
  async getCapturedAssets(@Req() req: AuthedRequest) {
    const { tenantId, orgUnitId } = this.scopeOf(req);
    return this.waterSupplyService.findCapturedAssets(tenantId, orgUnitId);
  }

  @Post('captured-assets')
  async createCapturedAsset(
    @Req() req: AuthedRequest,
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
    const { tenantId, orgUnitId } = this.scopeOf(req);
    return this.waterSupplyService.createCapturedAsset({
      ...body,
      tenantId,
      orgUnitId,
      capturedBy: req.user.id,
    });
  }

  @Post('captured-assets/:id/approve')
  async approveCapturedAsset(
    @Req() req: AuthedRequest,
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { comment: string },
  ) {
    const { tenantId, orgUnitId } = this.scopeOf(req);
    return this.waterSupplyService.approveCapturedAsset(
      id,
      body.comment,
      tenantId,
      orgUnitId,
    );
  }

  @Delete('pipelines/:id')
  async deletePipeline(@Param('id', ParseIntPipe) id: number) {
    return this.waterSupplyService.deletePipeline(id);
  }

  @Patch('pipelines/:id')
  async updatePipeline(
    @Param('id', ParseIntPipe) id: number,
    @Body()
    body: {
      name?: string;
      path_geojson?: any;
      diameter_mm?: number;
      material?: string;
      status?: string;
    },
  ) {
    return this.waterSupplyService.updatePipeline(id, body);
  }

  @Patch('valves/:id/toggle')
  async toggleValve(
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { status: string },
  ) {
    return this.waterSupplyService.toggleValve(id, body.status);
  }

  @Post('captured-assets/:id/reject')
  async rejectCapturedAsset(
    @Req() req: AuthedRequest,
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { comment: string },
  ) {
    const { tenantId, orgUnitId } = this.scopeOf(req);
    return this.waterSupplyService.rejectCapturedAsset(
      id,
      body.comment,
      tenantId,
      orgUnitId,
    );
  }
}

