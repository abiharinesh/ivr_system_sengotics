import {
  Controller,
  Get,
  Param,
  ParseIntPipe,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Controller('api/tenant')
export class TenantConfigController {
  constructor(private readonly prisma: PrismaService) {}

  @Get('branding/:branchId')
  async getTenantBranding(@Param('branchId', ParseIntPipe) branchId: number) {
    const branch = await this.prisma.panchayat.findUnique({
      where: { id: branchId },
      select: {
        id: true,
        name: true,
        branch_type: true,
        branch_code: true,
        logo_url: true,
        secondary_logo_url: true,
        favicon_url: true,
        software_name_ta: true,
        software_name_en: true,
        software_tagline_ta: true,
        software_tagline_en: true,
        primary_color: true,
        secondary_color: true,
        welcome_audio_url: true,
        ivr_number: true,
        contact_phone: true,
        contact_email: true,
      },
    });

    if (!branch) {
      throw new NotFoundException(`Branch #${branchId} not found`);
    }

    return branch;
  }

  @Get('branding/by-phone/:ivrNumber')
  async getTenantBrandingByPhone(@Param('ivrNumber') ivrNumber: string) {
    const branch = await this.prisma.panchayat.findFirst({
      where: { ivr_number: ivrNumber },
      select: {
        id: true,
        name: true,
        branch_type: true,
        software_name_ta: true,
        software_name_en: true,
        software_tagline_ta: true,
        software_tagline_en: true,
        logo_url: true,
        welcome_audio_url: true,
      },
    });

    if (!branch) {
      return {
        software_name_ta: 'ஊராட்சி குரல்',
        software_name_en: 'Ooratchi Kural',
        welcome_audio_url: null,
      };
    }

    return branch;
  }
}
