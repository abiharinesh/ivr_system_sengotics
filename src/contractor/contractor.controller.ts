import {
  Controller,
  Get,
  Post,
  Put,
  Patch,
  Delete,
  Body,
  Param,
  Query,
  Req,
  ParseIntPipe,
  UseGuards,
  BadRequestException,
} from '@nestjs/common';
import { ContractorService, CreateContractorDto, CreateWorkOrderDto } from './contractor.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';

interface AuthenticatedRequest {
  user: {
    id: number;
    email: string;
    role: string;
    org_unit_id: number | null;
    tenant_id: string;
    user_type: string;
    employee_id: number | null;
    access_scope: string;
  };
}

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('super_admin', 'panchayat_admin', 'municipal_engineer', 'assistant_engineer', 'contractor')
@Controller('api/contractors')
export class ContractorController {
  constructor(private readonly service: ContractorService) {}

  // ── Contractor Endpoints ────────────────────────────────────────────────

  @Post()
  createContractor(@Req() req: AuthenticatedRequest, @Body() dto: CreateContractorDto) {
    return this.service.createContractor(req.user.tenant_id, dto, req.user.id);
  }

  @Get()
  listContractors(@Req() req: AuthenticatedRequest) {
    return this.service.getContractors(req.user.tenant_id);
  }

  @Get(':id')
  getContractor(@Req() req: AuthenticatedRequest, @Param('id', ParseIntPipe) id: number) {
    return this.service.getContractor(req.user.tenant_id, id);
  }

  @Put(':id')
  updateContractor(
    @Req() req: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: Partial<CreateContractorDto>,
  ) {
    return this.service.updateContractor(req.user.tenant_id, id, dto, req.user.id);
  }

  @Delete(':id')
  deleteContractor(@Req() req: AuthenticatedRequest, @Param('id', ParseIntPipe) id: number) {
    return this.service.deleteContractor(req.user.tenant_id, id, req.user.id);
  }
}

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('super_admin', 'panchayat_admin')
@Controller('api/work-orders')
export class WorkOrderController {
  constructor(private readonly service: ContractorService) {}

  // ── Work Order Endpoints ────────────────────────────────────────────────

  @Post()
  createWorkOrder(@Req() req: AuthenticatedRequest, @Body() dto: CreateWorkOrderDto) {
    const orgUnitId = dto.orgUnitId ?? req.user.org_unit_id;
    if (!orgUnitId) {
      throw new BadRequestException('Branch ID is required');
    }
    return this.service.createWorkOrder(
      req.user.tenant_id,
      {
        ...dto,
        orgUnitId,
        createdBy: req.user.id,
      },
      req.user.id,
    );
  }

  @Get()
  listWorkOrders(
    @Req() req: AuthenticatedRequest,
    @Query('status') status?: string,
    @Query('contractorId') contractorId?: string,
  ) {
    const orgUnitId = req.user.org_unit_id;
    if (!orgUnitId) {
      throw new BadRequestException('Your user context has no branch associated');
    }
    const cid = contractorId ? parseInt(contractorId, 10) : undefined;

    return this.service.getWorkOrders(
      req.user.tenant_id,
      orgUnitId,
      req.user.access_scope,
      {
        status,
        contractorId: isNaN(cid as number) ? undefined : cid,
      },
    );
  }

  @Get(':id')
  getWorkOrder(@Req() req: AuthenticatedRequest, @Param('id', ParseIntPipe) id: number) {
    return this.service.getWorkOrder(req.user.tenant_id, id);
  }

  @Put(':id')
  updateWorkOrder(
    @Req() req: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: Partial<CreateWorkOrderDto>,
  ) {
    return this.service.updateWorkOrder(req.user.tenant_id, id, dto, req.user.id);
  }

  @Patch(':id/status')
  transitionStatus(
    @Req() req: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
    @Body()
    body: {
      status: 'draft' | 'issued' | 'in_progress' | 'completed' | 'verified' | 'paid';
      actualCost?: number;
      completionCertUrl?: string;
      remarks?: string;
    },
  ) {
    if (!body.status) {
      throw new BadRequestException('Status is required');
    }
    return this.service.transitionStatus(
      req.user.tenant_id,
      id,
      body.status,
      {
        actualCost: body.actualCost,
        completionCertUrl: body.completionCertUrl,
        remarks: body.remarks,
      },
      req.user.id,
    );
  }
}
