import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class WaterSupplyService {
  constructor(private readonly prisma: PrismaService) {}

  async findPipelines(panchayatId: number) {
    return this.prisma.waterPipeline.findMany({
      where: { panchayat_id: panchayatId },
      include: { complaints: true },
    });
  }

  async findTanks(panchayatId: number) {
    return this.prisma.waterTankBorewell.findMany({
      where: { panchayat_id: panchayatId },
      include: { complaints: true },
    });
  }

  async findValves(panchayatId: number) {
    return this.prisma.waterValve.findMany({
      where: { panchayat_id: panchayatId },
    });
  }

  async findFlowLogs(panchayatId: number) {
    return this.prisma.waterFlowLog.findMany({
      where: {
        OR: [
          { pipeline: { panchayat_id: panchayatId } },
          { tank: { panchayat_id: panchayatId } },
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
                panchayat_id: pipeline.panchayat_id,
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
}
