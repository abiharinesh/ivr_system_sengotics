import { Controller, Get } from '@nestjs/common';
import { AppService } from './app.service';
import { PrismaService } from './prisma/prisma.service';
import { Prisma } from '@prisma/client';

@Controller()
export class AppController {
  constructor(
    private readonly appService: AppService,
    private readonly prisma: PrismaService
  ) { }

  @Get()
  getHello(): string {
    return this.appService.getHello();
  }

  @Get('health/db')
  async checkDatabase() {
    try {
      await this.prisma.$queryRaw(Prisma.sql`SELECT 1`);
      return { status: 'ok', message: 'Database Connected' };
    } catch (error) {
      return { status: 'error', message: 'Database Connection Failed', error: error.message };
    }
  }
}
