import { Controller, Post, Body, Get, Query, Req, UseGuards } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { AuthService } from './auth.service';
import { ChangePasswordDto } from './dto/change-password.dto';
import { LoginDto } from './dto/login.dto';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { checkPassword, PASSWORD_MIN_LENGTH } from './password-policy';

@Controller('api/auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  /** Login — rate-limited to 5 attempts per 60 seconds per IP. */
  @Post('login')
  @Throttle({ default: { limit: 5, ttl: 60000 } })
  async login(@Body() dto: LoginDto) {
    return this.authService.login(dto.email, dto.password);
  }

  /**
   * Set a new password. Rate-limited because it takes the current password,
   * which makes it a place to guess one.
   */
  @Post('change-password')
  @UseGuards(JwtAuthGuard)
  @Throttle({ default: { limit: 5, ttl: 60000 } })
  async changePassword(
    @Req() req: { user: { id: number } },
    @Body() dto: ChangePasswordDto,
  ) {
    return this.authService.changePassword(
      req.user.id,
      dto.current_password,
      dto.new_password,
    );
  }

  /**
   * GET /api/auth/password-policy?candidate=…
   *
   * The rules, and optionally a grade for one candidate. The client's strength
   * meter reads this rather than reimplementing the policy, so the form can
   * never accept something the server would refuse.
   */
  @Get('password-policy')
  passwordPolicy(@Query('candidate') candidate?: string) {
    return {
      min_length: PASSWORD_MIN_LENGTH,
      requirements: [
        `At least ${PASSWORD_MIN_LENGTH} characters`,
        'An uppercase and a lowercase letter',
        'A digit',
        'A symbol',
        'Not a common password or your email address',
      ],
      check: candidate == null ? null : checkPassword(candidate),
    };
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

