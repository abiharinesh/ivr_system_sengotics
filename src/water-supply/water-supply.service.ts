import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class WaterSupplyService {
  constructor(private readonly prisma: PrismaService) {}

  async findPipelines(orgUnitId: number) {
    return this.prisma.waterPipeline.findMany({
      where: { org_unit_id: orgUnitId },
      include: { complaints: true },
    });
  }

  async createPipeline(dto: {
    name?: string;
    org_unit_id: number;
    path_geojson: any;
    diameter_mm?: number;
    material?: string;
    status?: string;
  }) {
    return this.prisma.waterPipeline.create({
      data: {
        name: dto.name,
        org_unit_id: dto.org_unit_id,
        path_geojson: dto.path_geojson,
        diameter_mm: dto.diameter_mm,
        material: dto.material,
        status: dto.status || 'active',
      },
    });
  }

  async findTanks(orgUnitId: number) {
    return this.prisma.waterTankBorewell.findMany({
      where: { org_unit_id: orgUnitId },
      include: { complaints: true },
    });
  }

  async findValves(orgUnitId: number) {
    return this.prisma.waterValve.findMany({
      where: { org_unit_id: orgUnitId },
    });
  }

  async findFlowLogs(orgUnitId: number) {
    return this.prisma.waterFlowLog.findMany({
      where: {
        OR: [
          { pipeline: { org_unit_id: orgUnitId } },
          { tank: { org_unit_id: orgUnitId } },
        ],
      },
      include: {
        pipeline: true,
        tank: true,
      },
      orderBy: { logged_at: 'desc' },
      take: 100,
    });
  }

  async createFlowLog(dto: {
    pipeline_id?: number;
    tank_id?: number;
    flow_rate_lps: number;
    pressure_bar: number;
  }) {
    // Serialize BigInt safely or just store it
    const log = await this.prisma.waterFlowLog.create({
      data: {
        pipeline_id: dto.pipeline_id,
        tank_id: dto.tank_id,
        flow_rate_lps: dto.flow_rate_lps,
        pressure_bar: dto.pressure_bar,
      },
    });

    // Check if pressure is extremely low, suggesting a leak
    if (dto.pressure_bar < 1.5) {
      if (dto.pipeline_id) {
        await this.prisma.waterPipeline.update({
          where: { id: dto.pipeline_id },
          data: { status: 'leak_alert' },
        });

        const pipeline = await this.prisma.waterPipeline.findUnique({
          where: { id: dto.pipeline_id },
        });

        if (pipeline) {
          const exists = await this.prisma.complaint.findFirst({
            where: {
              pipeline_id: dto.pipeline_id,
              status: 'pending',
              complaint_type: 'water_leak',
            },
          });

          if (!exists) {
            await this.prisma.complaint.create({
              data: {
                org_unit_id: pipeline.org_unit_id,
                pipeline_id: dto.pipeline_id,
                complaint_type: 'water_leak',
                description: `AUTOMATED IoT ALERT: Water pressure dropped to ${dto.pressure_bar} bar at pipeline segment "${pipeline.name || 'Segment ' + pipeline.id}". Possible leak detected.`,
                urgency_level: 'High',
                status: 'pending',
              },
            });
          }
        }
      } else if (dto.tank_id) {
        await this.prisma.waterTankBorewell.update({
          where: { id: dto.tank_id },
          data: { status: 'critical' },
        });
      }
    }

    return log;
  }

  async simulateLeak(pipelineId: number) {
    const pipeline = await this.prisma.waterPipeline.findUnique({
      where: { id: pipelineId },
    });
    if (!pipeline) {
      throw new NotFoundException(`Pipeline #${pipelineId} not found`);
    }

    await this.prisma.waterPipeline.update({
      where: { id: pipelineId },
      data: { status: 'leak_alert' },
    });

    await this.createFlowLog({
      pipeline_id: pipelineId,
      flow_rate_lps: 8.5,
      pressure_bar: 0.8,
    });

    return {
      success: true,
      message: `Leak simulated on pipeline #${pipelineId}`,
    };
  }

  async findCapturedAssets() {
    return this.prisma.capturedAsset.findMany({
      orderBy: { submitted_at: 'desc' },
    });
  }

  async createCapturedAsset(dto: {
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
  }) {
    return this.prisma.capturedAsset.create({
      data: {
        type: dto.type,
        material: dto.material,
        diameter_mm: dto.diameter_mm,
        latitude: dto.latitude,
        longitude: dto.longitude,
        photo_url: dto.photo_url,
        agent_name: dto.agent_name,
        device_model: dto.device_model,
        altitude: dto.altitude,
        precision: dto.precision,
        status: 'pending_approval',
      },
    });
  }

  async approveCapturedAsset(id: number, comment: string) {
    const asset = await this.prisma.capturedAsset.findUnique({
      where: { id },
    });
    if (!asset) {
      throw new NotFoundException(`Captured asset #${id} not found`);
    }

    const updated = await this.prisma.capturedAsset.update({
      where: { id },
      data: {
        status: 'approved',
        comment,
      },
    });

    if (asset.type === 'main_pipeline') {
      const panchayat = await this.prisma.orgUnit.findFirst();
      const orgUnitId = panchayat ? panchayat.id : 1;

      const pathGeojson = {
        type: 'LineString',
        coordinates: [
          [asset.longitude - 0.001, asset.latitude - 0.001],
          [asset.longitude, asset.latitude],
          [asset.longitude + 0.001, asset.latitude + 0.001],
        ],
      };

      await this.prisma.waterPipeline.create({
        data: {
          name: `${asset.material} Main Line (${asset.diameter_mm}mm)`,
          org_unit_id: orgUnitId,
          diameter_mm: asset.diameter_mm,
          material: asset.material,
          status: 'active',
          path_geojson: pathGeojson,
        },
      });
    }

    return updated;
  }

  async rejectCapturedAsset(id: number, comment: string) {
    const asset = await this.prisma.capturedAsset.findUnique({
      where: { id },
    });
    if (!asset) {
      throw new NotFoundException(`Captured asset #${id} not found`);
    }

    return this.prisma.capturedAsset.update({
      where: { id },
      data: {
        status: 'rejected',
        comment,
      },
    });
  }

  async deletePipeline(id: number) {
    const pipeline = await this.prisma.waterPipeline.findUnique({
      where: { id },
    });
    if (!pipeline) {
      throw new NotFoundException(`Pipeline #${id} not found`);
    }

    // Delete related complaints first
    await this.prisma.complaint.deleteMany({
      where: { pipeline_id: id },
    });

    // Delete related flow logs
    await this.prisma.waterFlowLog.deleteMany({
      where: { pipeline_id: id },
    });

    return this.prisma.waterPipeline.delete({
      where: { id },
    });
  }

  async updatePipeline(
    id: number,
    dto: {
      name?: string;
      path_geojson?: any;
      diameter_mm?: number;
      material?: string;
      status?: string;
    },
  ) {
    const pipeline = await this.prisma.waterPipeline.findUnique({
      where: { id },
    });
    if (!pipeline) {
      throw new NotFoundException(`Pipeline #${id} not found`);
    }

    return this.prisma.waterPipeline.update({
      where: { id },
      data: {
        ...(dto.name !== undefined && { name: dto.name }),
        ...(dto.path_geojson !== undefined && { path_geojson: dto.path_geojson }),
        ...(dto.diameter_mm !== undefined && { diameter_mm: dto.diameter_mm }),
        ...(dto.material !== undefined && { material: dto.material }),
        ...(dto.status !== undefined && { status: dto.status }),
      },
    });
  }

  async toggleValve(id: number, status: string) {
    const valve = await this.prisma.waterValve.findUnique({
      where: { id },
    });
    if (!valve) {
      throw new NotFoundException(`Valve #${id} not found`);
    }

    return this.prisma.waterValve.update({
      where: { id },
      data: { status },
    });
  }
}

