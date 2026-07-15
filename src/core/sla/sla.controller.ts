import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Param,
  Query,
  Req,
  ParseIntPipe,
  UseGuards,
  BadRequestException,
} from '@nestjs/common';
import { SlaService } from './sla.service';
import { JwtAuthGuard } from '../../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../../auth/guards/roles.guard';
import { Roles } from '../../auth/decorators/roles.decorator';

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

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('super_admin', 'panchayat_admin')
@Controller('api/sla/policies')
export class SlaController {
  constructor(private readonly service: SlaService) {}

  @Post()
  create(@Req() req: AuthenticatedRequest, @Body() body: any) {
    const branchId = body.branch_id ?? req.user.panchayat_id;
    return this.service.createPolicy(req.user.tenant_id, {
      ...body,
      branch_id: branchId,
    });
  }

  @Get()
  list(@Req() req: AuthenticatedRequest, @Query('branchId') branchId?: string) {
    const bid = branchId ? parseInt(branchId, 10) : undefined;
    return this.service.getPolicies(
      req.user.tenant_id,
      isNaN(bid as number) ? undefined : bid,
    );
  }

  @Put(':id')
  update(
    @Req() req: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
    @Body() body: any,
  ) {
    return this.service.updatePolicy(req.user.tenant_id, id, body);
  }

  @Delete(':id')
  remove(
    @Req() req: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.service.deletePolicy(req.user.tenant_id, id);
  }
}
