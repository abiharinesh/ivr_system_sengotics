import {
  Controller,
  Get,
  Post,
  Param,
  Query,
  Body,
  Req,
  ParseIntPipe,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  BadRequestException,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import type { UploadedImageFile } from '../common/upload.types';
import {
  parseGeoFromBody,
  strFieldOptional,
} from '../common/multipart-geo.util';
import { PlumberService } from './plumber.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';

interface AuthReq {
  user: {
    id: number;
    email: string;
    role: string;
    org_unit_id: number | null;
  };
}

const IMAGE_LIMIT = 12 * 1024 * 1024;

/**
 * Plumber-facing endpoints.
 * Mirror of ElectricianController but scoped to `role: plumber`
 * and using `assigned_plumber_id` on complaints.
 */
@Controller('api/plumber')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('plumber')
export class PlumberController {
  constructor(private readonly plumberService: PlumberService) {}

  @Get('me')
  getMe(@Req() req: AuthReq) {
    return this.plumberService.getMe(req.user.id);
  }

  @Get('complaints')
  list(@Req() req: AuthReq, @Query('status') status?: string) {
    return this.plumberService.listComplaints(req.user.id, status);
  }

  @Get('complaints/:id')
  getOne(@Req() req: AuthReq, @Param('id', ParseIntPipe) id: number) {
    return this.plumberService.getComplaint(req.user.id, id);
  }

  @Post('complaints/:id/accept')
  accept(@Req() req: AuthReq, @Param('id', ParseIntPipe) id: number) {
    return this.plumberService.acceptComplaint(req.user.id, id);
  }

  @Post('complaints/:id/decline')
  decline(
    @Req() req: AuthReq,
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { reason?: string },
  ) {
    return this.plumberService.submitCannotAttend(
      req.user.id,
      id,
      body?.reason,
    );
  }

  @Post('complaints/:id/resolve')
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: IMAGE_LIMIT },
    }),
  )
  resolve(
    @Req() req: AuthReq,
    @Param('id', ParseIntPipe) id: number,
    @UploadedFile() file: UploadedImageFile,
    @Body() body: Record<string, unknown>,
  ) {
    if (!file?.buffer?.length) {
      throw new BadRequestException('file is required');
    }
    const geo = parseGeoFromBody(body);
    return this.plumberService.submitResolution(req.user.id, id, file, {
      ...geo,
      note: strFieldOptional(body, 'note'),
      localJobId: strFieldOptional(body, 'localJobId'),
    });
  }
}
