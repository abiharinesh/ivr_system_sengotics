import { Controller, Post, Body, Req, UseGuards } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { AuthService } from './auth.service';
import { LoginDto } from './dto/login.dto';
import { JwtAuthGuard } from './guards/jwt-auth.guard';

@Controller('api/auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  /** Login — rate-limited to 5 attempts per 60 seconds per IP. */
  @Post('login')
  @Throttle({ default: { limit: 5, ttl: 60000 } })
  async login(@Body() dto: LoginDto) {
    return this.authService.login(dto.email, dto.password);
  }

  @Post('send-otp')
  async sendOtp(@Body() body: { phone: string }) {
    return this.authService.sendOtp(body.phone);
  }

  @Post('verify-otp')
  async verifyOtp(@Body() body: { phone: string; otp: string; org_unit_id?: number }) {
    return this.authService.verifyOtp(body.phone, body.otp, body.org_unit_id);
  }

  /**
   * Switch the active context for a user holding multiple role/org-unit
   * assignments — reissues a JWT scoped to a different one of their own
   * UserRole rows. This is the backend counterpart to the frontend's
   * context-selector screen.
   */
  @Post('switch-context')
  @UseGuards(JwtAuthGuard)
  async switchContext(@Req() req: { user: { id: number } }, @Body() body: { user_role_id: number }) {
    return this.authService.switchContext(req.user.id, body.user_role_id);
  }
}

