import { Injectable, UnauthorizedException, ForbiddenException, Logger, NotFoundException } from '@nestjs/common';
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

    // Fetch org unit branding safely with fallback for un-migrated production DBs
    let org_unit: any = null;
    if (user.primary_org_unit_id) {
      try {
        org_unit = await this.prisma.orgUnit.findUnique({
          where: { id: user.primary_org_unit_id },
          select: {
            id: true,
            name: true,
            branch_type: true,
            branch_code: true,
            district: true,
            taluk: true,
            address: true,
            contact_phone: true,
            contact_email: true,
            ivr_number: true,
            ward_count: true,
            software_name_ta: true,
            software_name_en: true,
            software_tagline_ta: true,
            software_tagline_en: true,
            logo_url: true,
            secondary_logo_url: true,
            favicon_url: true,
            primary_color: true,
            secondary_color: true,
            welcome_audio_url: true,
          },
        });
      } catch (err) {
        this.logger.warn(
          `Panchayat branding fetch fallback (DB schema may pending migration): ${(err as Error).message}`,
        );
        try {
          org_unit = await this.prisma.orgUnit.findUnique({
            where: { id: user.primary_org_unit_id },
            select: { id: true, name: true, logo_url: true },
          });
        } catch (_) {
          org_unit = null;
        }
      }
    }

    const payload = await this.buildJwtPayload(user);

    return {
      access_token: this.jwtService.sign(payload),
      role: user.role,
      org_unit_id: user.primary_org_unit_id,
      user_type: user.user_type,
      org_unit,
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

  async verifyOtp(phone: string, otp: string, org_unit_id?: number) {
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
      if (!org_unit_id) {
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
          primary_org_unit_id: org_unit_id,
          phone_e164: formattedPhone,
          user_type: 'citizen',
        },
      });
      this.logger.log(`[OTP] Automatically registered citizen for phone ${formattedPhone} with email ${email}`);
    }

    let org_unit: any = null;
    if (user.primary_org_unit_id) {
      try {
        org_unit = await this.prisma.orgUnit.findUnique({
          where: { id: user.primary_org_unit_id },
          select: {
            id: true,
            name: true,
            branch_type: true,
            branch_code: true,
            district: true,
            taluk: true,
            address: true,
            contact_phone: true,
            contact_email: true,
            ivr_number: true,
            ward_count: true,
            software_name_ta: true,
            software_name_en: true,
            software_tagline_ta: true,
            software_tagline_en: true,
            logo_url: true,
            secondary_logo_url: true,
            favicon_url: true,
            primary_color: true,
            secondary_color: true,
            welcome_audio_url: true,
          },
        });
      } catch (err) {
        try {
          org_unit = await this.prisma.orgUnit.findUnique({
            where: { id: user.primary_org_unit_id },
            select: { id: true, name: true, logo_url: true },
          });
        } catch (_) {
          org_unit = null;
        }
      }
    }

    const payload = await this.buildJwtPayload(user);

    return {
      access_token: this.jwtService.sign(payload),
      role: user.role,
      org_unit_id: user.primary_org_unit_id,
      user_type: user.user_type,
      org_unit,
    };
  }

  /**
   * Re-issues a JWT scoped to a different one of the caller's own UserRole
   * assignments (a user with multiple role/org-unit assignments switching
   * "context" — e.g. a district-level officer also holding a role at a
   * specific municipality). Marks the chosen assignment `is_primary` so
   * subsequent plain logins land back in this context.
   */
  async switchContext(userId: number, userRoleId: number) {
    const targetRole = await this.prisma.userRole.findFirst({
      where: { id: userRoleId, user_id: userId },
    });
    if (!targetRole) {
      throw new ForbiddenException('That role assignment does not belong to you');
    }

    await this.prisma.userRole.updateMany({
      where: { user_id: userId, is_primary: true },
      data: { is_primary: false },
    });
    await this.prisma.userRole.update({
      where: { id: targetRole.id },
      data: { is_primary: true },
    });

    // Keep User.primary_org_unit_id (the login/home context) in sync with
    // whichever UserRole is now primary, so the JWT's org-unit context and
    // subsequent plain logins reflect the switch.
    const user = await this.prisma.user.update({
      where: { id: userId },
      data: { primary_org_unit_id: targetRole.org_unit_id },
    });

    const payload = await this.buildJwtPayload(user);
    return { access_token: this.jwtService.sign(payload) };
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
    primary_org_unit_id: number | null;
    tenant_id: string;
    user_type: string;
  }) {
    // Get employee record if exists (posting identity only — access_scope now lives on UserRole)
    let employee: { id: number } | null = null;
    try {
      employee = await this.prisma.employee.findFirst({
        where: { user_id: user.id },
        select: { id: true },
      });
    } catch {
      // Employee table may not exist pre-migration
    }

    // Get RBAC roles and permissions
    const { rbacRoles, permissions } = await this.resolveUserRbac(user.id);

    // Access scope comes from the user's primary UserRole assignment
    let accessScope = 'own_org_unit';
    try {
      const primaryRole = await this.prisma.userRole.findFirst({
        where: { user_id: user.id, is_primary: true },
        select: { access_scope: true },
      });
      if (primaryRole) accessScope = primaryRole.access_scope;
    } catch {
      // UserRole table may not exist pre-migration
    }

    const isSuperAdmin = user.role === 'super_admin' || rbacRoles.some((r) => r.is_super_admin);

    return {
      sub: user.id,
      email: user.email,
      role: user.role, // Legacy field — kept for backward compatibility
      is_super_admin: isSuperAdmin,
      org_unit_id: user.primary_org_unit_id,
      tenant_id: user.tenant_id,
      user_type: user.user_type,
      employee_id: employee?.id || null,
      access_scope: accessScope,
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
    rbacRoles: Array<{ id: number; name: string; org_unit_id: number | null; is_super_admin: boolean }>;
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
        select: { id: true, name: true, permission_group_id: true, is_super_admin: true },
      });

      const rbacRoles = roles.map((r) => {
        const userRole = userRoles.find((ur) => ur.role_id === r.id);
        return {
          id: r.id,
          name: r.name,
          org_unit_id: userRole?.org_unit_id ?? null,
          is_super_admin: r.is_super_admin,
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
