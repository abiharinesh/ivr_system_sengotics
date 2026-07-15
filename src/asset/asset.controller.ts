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
  UseInterceptors,
  UploadedFile,
  BadRequestException,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { AssetService, CreateAssetDto } from './asset.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';

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
@Roles('panchayat_admin', 'super_admin')
@Controller('api/assets')
export class AssetController {
  constructor(private readonly service: AssetService) {}

  @Post()
  create(@Req() req: AuthenticatedRequest, @Body() dto: CreateAssetDto) {
    const branchId = dto.branchId ?? req.user.panchayat_id;
    if (!branchId) {
      throw new BadRequestException('Branch ID is required');
    }
    return this.service.create(
      {
        ...dto,
        tenantId: req.user.tenant_id,
        branchId,
      },
      req.user.id,
    );
  }

  @Get()
  list(
    @Req() req: AuthenticatedRequest,
    @Query('type') type?: string,
    @Query('zoneId') zoneId?: string,
    @Query('search') search?: string,
    @Query('take') take?: string,
    @Query('skip') skip?: string,
  ) {
    const branchId = req.user.panchayat_id;
    if (!branchId) {
      throw new BadRequestException('Your account has no branch context');
    }
    const t = take ? parseInt(take, 10) : undefined;
    const s = skip ? parseInt(skip, 10) : undefined;

    return this.service.list(
      req.user.tenant_id,
      branchId,
      req.user.access_scope,
      {
        type,
        zoneId: zoneId ? parseInt(zoneId, 10) : undefined,
        search,
        take: isNaN(t as number) ? undefined : t,
        skip: isNaN(s as number) ? undefined : s,
      },
    );
  }

  @Get(':id')
  findOne(@Req() req: AuthenticatedRequest, @Param('id', ParseIntPipe) id: number) {
    return this.service.findOne(req.user.tenant_id, id);
  }

  @Put(':id')
  update(
    @Req() req: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: Partial<CreateAssetDto>,
  ) {
    return this.service.update(req.user.tenant_id, id, dto, req.user.id);
  }

  @Delete(':id')
  remove(@Req() req: AuthenticatedRequest, @Param('id', ParseIntPipe) id: number) {
    return this.service.softDelete(req.user.tenant_id, id, req.user.id);
  }

  @Post(':id/images')
  @UseInterceptors(FileInterceptor('file'))
  uploadImage(
    @Req() req: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
    @UploadedFile() file: any,
    @Body('type') type: 'installation' | 'current' | 'damage' | 'repair',
    @Body('caption') caption?: string,
  ) {
    if (!file) {
      throw new BadRequestException('File is required');
    }
    if (!['installation', 'current', 'damage', 'repair'].includes(type)) {
      throw new BadRequestException(`Invalid image type: ${type}`);
    }
    return this.service.uploadImage(
      req.user.tenant_id,
      id,
      file,
      type,
      caption,
      req.user.id,
    );
  }
}
