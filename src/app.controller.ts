import { Controller, Get, Param, Res } from '@nestjs/common';
import { AppService } from './app.service';
import { PrismaService } from './prisma/prisma.service';

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
  redirectReport(@Param('token') token: string, @Res() res: any) {
    const frontendUrl = process.env.WEB_APP_BASE_URL;
    if (!frontendUrl) {
      res.setHeader('Content-Type', 'text/html');
      return res.status(400).send(
        `<h3>Configuration Required</h3>` +
        `<p>Please set the <b>WEB_APP_BASE_URL</b> environment variable in your Vercel backend project settings ` +
        `to point to your frontend deployment domain (e.g., <code>https://your-frontend.vercel.app</code>) and redeploy.</p>`
      );
    }
    const target = frontendUrl.endsWith('/') ? frontendUrl.slice(0, -1) : frontendUrl;
    return res.redirect(`${target}/public/report/${token}`);
  }

  @Get('public/track/:token')
  redirectTrack(@Param('token') token: string, @Res() res: any) {
    const frontendUrl = process.env.WEB_APP_BASE_URL;
    if (!frontendUrl) {
      res.setHeader('Content-Type', 'text/html');
      return res.status(400).send(
        `<h3>Configuration Required</h3>` +
        `<p>Please set the <b>WEB_APP_BASE_URL</b> environment variable in your Vercel backend project settings ` +
        `to point to your frontend deployment domain (e.g., <code>https://your-frontend.vercel.app</code>) and redeploy.</p>`
      );
    }
    const target = frontendUrl.endsWith('/') ? frontendUrl.slice(0, -1) : frontendUrl;
    return res.redirect(`${target}/public/track/${token}`);
  }
}
