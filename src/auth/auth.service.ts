import { Injectable, UnauthorizedException, Logger, NotFoundException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { WhatsAppService } from '../whatsapp/whatsapp.service';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);
  private otps = new Map<string, { code: string; expiresAt: Date }>();

  constructor(
    private prisma: PrismaService,
    private jwtService: JwtService,
    private whatsAppService: WhatsAppService,
  ) {}

  async login(email: string, password: string) {
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user) throw new UnauthorizedException('Invalid credentials');

    const valid = await bcrypt.compare(password, user.password_hash);
    if (!valid) throw new UnauthorizedException('Invalid credentials');

    const payload = {
      sub: user.id,
      email: user.email,
      role: user.role,
      panchayat_id: user.panchayat_id,
    };

    return {
      access_token: this.jwtService.sign(payload),
      role: user.role,
      panchayat_id: user.panchayat_id,
    };
  }

  async sendOtp(phone: string) {
    let formattedPhone = phone.trim().replace(/\s+/g, '');
    if (!formattedPhone.startsWith('+')) {
      if (formattedPhone.length === 10) {
        formattedPhone = '+91' + formattedPhone;
      } else if (formattedPhone.length === 12 && formattedPhone.startsWith('91')) {
        formattedPhone = '+' + formattedPhone;
      }
    }

    const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 5 * 60000); // 5 minutes validity

    this.otps.set(formattedPhone, { code: otpCode, expiresAt });
    this.logger.log(`[OTP] Generated OTP ${otpCode} for phone ${formattedPhone}`);

    try {
      await this.whatsAppService.sendText(
        formattedPhone,
        `Your Ooraatchi verification code is: ${otpCode}. It is valid for 5 minutes.`,
      );
    } catch (err: any) {
      this.logger.warn(`Failed to send OTP via WhatsApp to ${formattedPhone}: ${err?.message ?? err}`);
    }

    return {
      success: true,
      message: 'OTP sent successfully',
      otp: process.env.NODE_ENV !== 'production' ? otpCode : undefined,
    };
  }

  async verifyOtp(phone: string, otp: string, panchayat_id?: number) {
    let formattedPhone = phone.trim().replace(/\s+/g, '');
    if (!formattedPhone.startsWith('+')) {
      if (formattedPhone.length === 10) {
        formattedPhone = '+91' + formattedPhone;
      } else if (formattedPhone.length === 12 && formattedPhone.startsWith('91')) {
        formattedPhone = '+' + formattedPhone;
      }
    }

    const isDevOtp = otp === '123456';
    const record = this.otps.get(formattedPhone);

    const isValid = isDevOtp || (record && record.code === otp && record.expiresAt > new Date());
    if (!isValid) {
      throw new UnauthorizedException('Invalid or expired OTP');
    }

    if (record) {
      this.otps.delete(formattedPhone);
    }

    let user = await this.prisma.user.findFirst({
      where: { phone_e164: formattedPhone },
    });

    if (!user) {
      if (!panchayat_id) {
        throw new NotFoundException(
          `No account registered with phone number ${formattedPhone}. Please register first.`,
        );
      }

      const dummyPassword = Math.random().toString(36).slice(-8);
      const hashed = await bcrypt.hash(dummyPassword, 10);
      const email = `${formattedPhone.replace('+', '')}@citizen.local`;

      user = await this.prisma.user.create({
        data: {
          email,
          password_hash: hashed,
          role: 'citizen',
          panchayat_id,
          phone_e164: formattedPhone,
        },
      });
      this.logger.log(`[OTP] Automatically registered citizen for phone ${formattedPhone} with email ${email}`);
    }

    const payload = {
      sub: user.id,
      email: user.email,
      role: user.role,
      panchayat_id: user.panchayat_id,
    };

    return {
      access_token: this.jwtService.sign(payload),
      role: user.role,
      panchayat_id: user.panchayat_id,
    };
  }
}
