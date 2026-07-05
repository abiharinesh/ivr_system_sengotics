import { Controller, Get, Param, Res } from '@nestjs/common';
import { AppService } from './app.service';
import { PrismaService } from './prisma/prisma.service';
import type { Response } from 'express';

@Controller()
export class AppController {
  constructor(
    private readonly appService: AppService,
    private readonly prisma: PrismaService,
  ) {}

  @Get()
  getHello(): string {
    return this.appService.getHello();
  }

  @Get('health/db')
  async checkDatabase() {
    try {
      await this.prisma.getPool().query('SELECT 1');
      return { status: 'ok', message: 'Database Connected' };
    } catch (error) {
      return {
        status: 'error',
        message: 'Database Connection Failed',
        error: error.message,
      };
    }
  }

  @Get('public/report/:token')
  redirectPublicReport(@Param('token') token: string, @Res() res: Response) {
    const webAppUrl = process.env.WEB_APP_BASE_URL || 'http://localhost:8080';
    return res.redirect(`${webAppUrl}/public/report/${token}`);
  }

  @Get('public/track/:token')
  redirectComplaintTracking(@Param('token') token: string, @Res() res: Response) {
    const webAppUrl = process.env.WEB_APP_BASE_URL || 'http://localhost:8080';
    return res.redirect(`${webAppUrl}/public/track/${token}`);
  }
}
