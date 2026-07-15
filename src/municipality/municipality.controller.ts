import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Req,
  UseGuards,
  BadRequestException,
} from '@nestjs/common';
import { MunicipalityService, MunicipalityFeature } from './municipality.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

interface AuthenticatedRequest {
  user: {
    id: number;
    email: string;
    role: string;
    panchayat_id: number | null;
    tenant_id: string;
    user_type: string;
    employee_id: number | null;
    access_scope: string;
  };
}

const VALID_FEATURES: MunicipalityFeature[] = [
  'solid_waste_mgmt',
  'drainage_mgmt',
  'road_mgmt',
  'parks_mgmt',
  'public_health',
  'building_permit',
  'birth_death_reg',
  'vehicle_fleet_mgmt',
  'cemetery_mgmt',
  'encroachment_mgmt',
];

@UseGuards(JwtAuthGuard)
@Controller('api/municipality')
export class MunicipalityController {
  constructor(private readonly service: MunicipalityService) {}

  @Post(':featureKey/records')
  recordTransaction(
    @Req() req: AuthenticatedRequest,
    @Param('featureKey') featureKey: string,
    @Body() body: any,
  ) {
    const branchId = req.user.panchayat_id;
    if (!branchId) {
      throw new BadRequestException('Your user context has no branch associated');
    }

    const feature = featureKey as MunicipalityFeature;
    if (!VALID_FEATURES.includes(feature)) {
      throw new BadRequestException(`Invalid municipality feature key: ${featureKey}`);
    }

    if (!body || Object.keys(body).length === 0) {
      throw new BadRequestException('Record details data is required');
    }

    return this.service.recordTransaction(
      req.user.tenant_id,
      branchId,
      feature,
      req.user.id,
      body,
    );
  }

  @Get(':featureKey/records')
  getTransactions(
    @Req() req: AuthenticatedRequest,
    @Param('featureKey') featureKey: string,
  ) {
    const branchId = req.user.panchayat_id;
    if (!branchId) {
      throw new BadRequestException('Your user context has no branch associated');
    }

    const feature = featureKey as MunicipalityFeature;
    if (!VALID_FEATURES.includes(feature)) {
      throw new BadRequestException(`Invalid municipality feature key: ${featureKey}`);
    }

    return this.service.getTransactions(req.user.tenant_id, branchId, feature);
  }
}
