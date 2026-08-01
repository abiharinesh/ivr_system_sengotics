import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Req,
  ParseIntPipe,
  UseGuards,
  BadRequestException,
} from '@nestjs/common';
import { FormService, CreateTemplateDto } from './form.service';
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
@Roles('super_admin', 'panchayat_admin')
@Controller('api/forms')
export class FormController {
  constructor(private readonly service: FormService) {}

  @Post('templates')
  createTemplate(@Req() req: AuthenticatedRequest, @Body() dto: CreateTemplateDto) {
    return this.service.createTemplate(req.user.tenant_id, dto);
  }

  @Get('templates')
  listTemplates(@Req() req: AuthenticatedRequest) {
    return this.service.getTemplates(req.user.tenant_id);
  }

  @Get('templates/:id')
  getTemplate(@Req() req: AuthenticatedRequest, @Param('id', ParseIntPipe) id: number) {
    return this.service.getTemplate(req.user.tenant_id, id);
  }

  @Post('templates/:id/submissions')
  submitForm(
    @Req() req: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
    @Body()
    body: {
      data: Record<string, any>;
      entity_type?: string;
      entity_id?: number;
    },
  ) {
    const orgUnitId = req.user.org_unit_id;
    if (!orgUnitId) {
      throw new BadRequestException('Your user context has no branch associated');
    }
    if (!body.data) {
      throw new BadRequestException('Submission data is required');
    }
    return this.service.submitForm(
      req.user.tenant_id,
      orgUnitId,
      id,
      req.user.id,
      body.data,
      body.entity_type,
      body.entity_id,
    );
  }
}
