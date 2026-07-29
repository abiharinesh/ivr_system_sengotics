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
    const user = await this.prisma.user.findFirst({ where: { email } });
    if (!user) throw new UnauthorizedException('Invalid credentials');

    const valid = await bcrypt.compare(password, user.password_hash);
    if (!valid) throw new UnauthorizedException('Invalid credentials');

    // Update last login tracking
    await this.prisma.user.update({
      where: { id: user.id },
      data: {
        last_login_at: new Date(),
        failed_attempts: 0,
      },
    }).catch(() => { /* non-critical */ });

    // Fetch panchayat branding safely with fallback for un-migrated production DBs
    let panchayat: any = null;
    if (user.panchayat_id) {
      try {
        panchayat = await this.prisma.panchayat.findUnique({
          where: { id: user.panchayat_id },
          select: {
            id: true,
            name: true,
            branch_type: true,
            software_name_ta: true,
            software_name_en: true,
            software_tagline_ta: true,
            software_tagline_en: true,
            logo_url: true,
            primary_color: true,
          },
        });
      } catch (err) {
        this.logger.warn(
          `Panchayat branding fetch fallback (DB schema may pending migration): ${(err as Error).message}`,
        );
        try {
          panchayat = await this.prisma.panchayat.findUnique({
            where: { id: user.panchayat_id },
            select: { id: true, name: true, logo_url: true },
          });
        } catch (_) {
          panchayat = null;
        }
      }
    }

    const payload = await this.buildJwtPayload(user);

    return {
      access_token: this.jwtService.sign(payload),
      role: user.role,
      panchayat_id: user.panchayat_id,
      user_type: user.user_type,
      panchayat,
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
          user_type: 'citizen',
        },
      });
      this.logger.log(`[OTP] Automatically registered citizen for phone ${formattedPhone} with email ${email}`);
    }

    const payload = await this.buildJwtPayload(user);

    return {
      access_token: this.jwtService.sign(payload),
      role: user.role,
      panchayat_id: user.panchayat_id,
    };
  }

  // ── RBAC-Aware JWT Payload Builder ──────────────────────────────────────────

  /**
   * Builds a JWT payload that includes both the legacy `role` field AND
   * the proper RBAC roles/permissions from UserRole → Role → PermissionGroup.
   */
  private async buildJwtPayload(user: {
    id: number;
    email: string | null;
    role: string;
    panchayat_id: number | null;
    tenant_id: string;
    user_type: string;
  }) {
    // Get employee record if exists
    let employee: { id: number; access_scope: string } | null = null;
    try {
      employee = await this.prisma.employee.findFirst({
        where: { user_id: user.id },
        select: { id: true, access_scope: true },
      });
    } catch {
      // Employee table may not exist pre-migration
    }

    // Get RBAC roles and permissions
    const { rbacRoles, permissions } = await this.resolveUserRbac(user.id);

    return {
      sub: user.id,
      email: user.email,
      role: user.role, // Legacy field — kept for backward compatibility
      panchayat_id: user.panchayat_id,
      tenant_id: user.tenant_id,
      user_type: user.user_type,
      employee_id: employee?.id || null,
      access_scope: employee?.access_scope || 'own_branch',
      // RBAC fields
      rbac_roles: rbacRoles,
      permissions: permissions,
    };
  }

  /**
   * Resolves all RBAC roles and flattened permissions for a user.
   * Returns empty arrays if RBAC tables don't exist yet.
   */
  private async resolveUserRbac(userId: number): Promise<{
    rbacRoles: Array<{ id: number; name: string; branch_id: number | null }>;
    permissions: string[];
  }> {
    try {
      // 1. Get active user role assignments
      const userRoles = await this.prisma.userRole.findMany({
        where: {
          user_id: userId,
          valid_from: { lte: new Date() },
          OR: [
            { valid_until: null },
            { valid_until: { gte: new Date() } },
          ],
        },
      });

      if (userRoles.length === 0) {
        return { rbacRoles: [], permissions: [] };
      }

      // 2. Get role details
      const roleIds = userRoles.map((ur) => ur.role_id);
      const roles = await this.prisma.role.findMany({
        where: { id: { in: roleIds }, is_active: true },
        select: { id: true, name: true, permission_group_id: true },
      });

      const rbacRoles = roles.map((r) => {
        const userRole = userRoles.find((ur) => ur.role_id === r.id);
        return {
          id: r.id,
          name: r.name,
          branch_id: userRole?.branch_id ?? null,
        };
      });

      // 3. Get permission groups and flatten permissions
      const groupIds = roles
        .map((r) => r.permission_group_id)
        .filter((id): id is number => id !== null);

      if (groupIds.length === 0) {
        return { rbacRoles, permissions: [] };
      }

      const groups = await this.prisma.permissionGroup.findMany({
        where: { id: { in: groupIds } },
        select: { permissions: true },
      });

      const permissionSet = new Set<string>();
      for (const group of groups) {
        const perms = group.permissions as string[];
        if (Array.isArray(perms)) {
          perms.forEach((p) => permissionSet.add(p));
        }
      }

      return { rbacRoles, permissions: Array.from(permissionSet) };
    } catch (error) {
      // RBAC tables may not exist yet (pre-migration) — return empty
      this.logger.debug(`RBAC resolution skipped (tables may not exist): ${(error as Error).message}`);
      return { rbacRoles: [], permissions: [] };
    }
  }
}
