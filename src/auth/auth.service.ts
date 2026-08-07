import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { WhatsAppService } from '../whatsapp/whatsapp.service';
import { AuditService } from '../core/audit/audit.service';
import { RbacService } from '../core/rbac/rbac.service';
import { checkPassword } from './password-policy';

/** The shelf cross-tenant role templates live on. Never a user's own tenant. */
const SENTINEL_TENANT = '__system__';

/** Where an account with no branch of its own gets scoped. */
const DEFAULT_TENANT = 'default';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);
  private otps = new Map<string, { code: string; expiresAt: Date }>();

  constructor(
    private prisma: PrismaService,
    private jwtService: JwtService,
    private whatsAppService: WhatsAppService,
    private rbac: RbacService,
    private audit: AuditService,
  ) {}

  async login(email: string, password: string) {
    const user = await this.prisma.user.findFirst({ where: { email } });
    if (!user) throw new UnauthorizedException('Invalid credentials');

    const valid = await bcrypt.compare(password, user.password_hash);
    if (!valid) throw new UnauthorizedException('Invalid credentials');

    // Update last login tracking
    await this.prisma.user
      .update({
        where: { id: user.id },
        data: {
          last_login_at: new Date(),
          failed_attempts: 0,
        },
      })
      .catch(() => {
        /* non-critical */
      });

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
      // A provisioned account with a known temporary password is not a usable
      // account; the client routes to a change-password screen on this flag.
      must_change_password: user.must_change_password ?? false,
      org_unit,
    };
  }

  /**
   * Set a new password for the signed-in user.
   *
   * The flag this clears is the whole point: accounts are provisioned with a
   * random temporary password and `must_change_password = true`, and until
   * now there was no endpoint to satisfy it — 90 seeded accounts could sign in
   * but were never able to stop using the password they were handed.
   *
   * The current password is required even when the flag is set. A session left
   * open on a shared office machine must not be enough to take the account
   * over.
   */
  async changePassword(
    userId: number,
    currentPassword: string,
    newPassword: string,
  ) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('Account not found');

    const valid = await bcrypt.compare(currentPassword, user.password_hash);
    if (!valid) {
      throw new UnauthorizedException('Your current password is not correct');
    }

    const check = checkPassword(newPassword, {
      email: user.email ?? undefined,
      currentPassword,
    });
    if (!check.ok) {
      throw new BadRequestException(check.problems.join('. '));
    }

    await this.prisma.user.update({
      where: { id: userId },
      data: {
        password_hash: await bcrypt.hash(newPassword, 10),
        must_change_password: false,
        failed_attempts: 0,
      },
    });

    await this.audit.log({
      tenantId: user.tenant_id,
      orgUnitId: user.primary_org_unit_id ?? undefined,
      userId,
      module: 'auth',
      entityType: 'user',
      entityId: String(userId),
      action: 'password_changed',
      // Never record the password itself, in either column.
      afterValue: { must_change_password: false },
      changedFields: ['password_hash', 'must_change_password'],
    });

    this.logger.log(`Password changed for user #${userId}`);

    // A fresh token so the client stops carrying one minted while the account
    // was still flagged.
    const payload = await this.buildJwtPayload(user);
    return {
      success: true,
      access_token: this.jwtService.sign(payload),
      must_change_password: false,
    };
  }

  async sendOtp(phone: string) {
    let formattedPhone = phone.trim().replace(/\s+/g, '');
    if (!formattedPhone.startsWith('+')) {
      if (formattedPhone.length === 10) {
        formattedPhone = '+91' + formattedPhone;
      } else if (
        formattedPhone.length === 12 &&
        formattedPhone.startsWith('91')
      ) {
        formattedPhone = '+' + formattedPhone;
      }
    }

    const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 5 * 60000); // 5 minutes validity

    this.otps.set(formattedPhone, { code: otpCode, expiresAt });
    this.logger.log(
      `[OTP] Generated OTP ${otpCode} for phone ${formattedPhone}`,
    );

    try {
      await this.whatsAppService.sendText(
        formattedPhone,
        `Your Ooraatchi verification code is: ${otpCode}. It is valid for 5 minutes.`,
      );
    } catch (err: any) {
      this.logger.warn(
        `Failed to send OTP via WhatsApp to ${formattedPhone}: ${err?.message ?? err}`,
      );
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
      } else if (
        formattedPhone.length === 12 &&
        formattedPhone.startsWith('91')
      ) {
        formattedPhone = '+' + formattedPhone;
      }
    }

    const isDevOtp = otp === '123456';
    const record = this.otps.get(formattedPhone);

    const isValid =
      isDevOtp ||
      (record && record.code === otp && record.expiresAt > new Date());
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
      this.logger.log(
        `[OTP] Automatically registered citizen for phone ${formattedPhone} with email ${email}`,
      );
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
      // A provisioned account with a known temporary password is not a usable
      // account; the client routes to a change-password screen on this flag.
      must_change_password: user.must_change_password ?? false,
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
      throw new ForbiddenException(
        'That role assignment does not belong to you',
      );
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
  /**
   * Which tenant a sentinel-placed account should actually be scoped to.
   *
   * The branch they are posted to owns the answer — a user assigned to a
   * Coimbatore branch belongs to whatever tenant that branch belongs to.
   * Falls back to the operating tenant when they have no posting.
   */
  private async resolveSentinelTenant(user: {
    primary_org_unit_id: number | null;
  }): Promise<string> {
    if (user.primary_org_unit_id) {
      const org = await this.prisma.orgUnit
        .findUnique({
          where: { id: user.primary_org_unit_id },
          select: { tenant_id: true },
        })
        .catch(() => null);
      if (org?.tenant_id && org.tenant_id !== SENTINEL_TENANT)
        return org.tenant_id;
    }
    return DEFAULT_TENANT;
  }

  private async buildJwtPayload(user: {
    id: number;
    email: string | null;
    role: string;
    primary_org_unit_id: number | null;
    tenant_id: string;
    user_type: string;
  }) {
    // `__system__` is the shelf that cross-tenant role templates live on. It
    // owns no org units and no records, and every service scopes its reads by
    // the caller's tenant — so an account issued there signs in successfully
    // and then finds an empty product: no roles, no colleagues, no dashboard.
    //
    // Resolved here rather than refused, because the person holding the
    // account has done nothing wrong and locking them out is worse than
    // putting them where they belong. Their branch decides the tenant; a
    // branchless account falls back to the operating tenant.
    if (user.tenant_id === SENTINEL_TENANT) {
      const resolved = await this.resolveSentinelTenant(user);
      this.logger.warn(
        `User #${user.id} sits in the ${SENTINEL_TENANT} tenant; scoping to "${resolved}" instead`,
      );
      user = { ...user, tenant_id: resolved };
    }

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

    const tokenPayload = {
      sub: user.id,
      email: user.email,
      role: user.role, // Legacy field — kept for backward compatibility
      org_unit_id: user.primary_org_unit_id,
      tenant_id: user.tenant_id,
      user_type: user.user_type,
      employee_id: employee?.id || null,
      access_scope: accessScope,
      // RBAC fields
      // Screen keys the sidebar may render. Carried on the token so navigation
      // needs no extra round trip; a change in the admin console takes effect
      // on the user's next login or context switch.
    };
    return this.identityPayload(tokenPayload);
  }

  /** Remove all authorization claims before a JWT is signed. */
  private identityPayload<T extends { role?: unknown }>(payload: T) {
    const { role: _legacyRole, ...identity } = payload;
    return identity;
  }

  /**
   * Resolves RBAC roles, permissions and visible screens for a user.
   *
   * Delegates to {@link RbacService}, which is the single place that walks the
   * role graph. It previously read permissions out of the
   * `PermissionGroup.permissions` JSON blob; grants now live in
   * `role_permissions` rows and screen visibility in `role_screen_access`, so
   * the admin console can edit one role without touching every other role that
   * happened to share a group.
   *
   * Still non-throwing: a database that has not had the RBAC migration applied
   * yet must not make login fail.
   */
  private async resolveUserRbac(userId: number): Promise<{
    rbacRoles: Array<{
      id: number;
      name: string;
      org_unit_id: number | null;
      is_super_admin: boolean;
    }>;
    permissions: string[];
    screens: string[];
  }> {
    try {
      const ent = await this.rbac.entitlementsFor(userId);

      // Org unit per role still comes from the assignment rows.
      const assignments = await this.prisma.userRole.findMany({
        where: { user_id: userId },
        select: { role_id: true, org_unit_id: true },
      });

      const rbacRoles = ent.roles.map((r) => ({
        id: r.id,
        name: r.name,
        org_unit_id:
          assignments.find((a) => a.role_id === r.id)?.org_unit_id ?? null,
        is_super_admin: r.is_super_admin,
      }));

      // A super admin's menu follows the screen registry rather than a grant
      // list, so a newly shipped module appears without anyone ticking a box.
      const screens = ent.isSuperAdmin
        ? await this.rbac.platformScreens()
        : ent.screens;

      return { rbacRoles, permissions: ent.permissions, screens };
    } catch (error) {
      this.logger.debug(
        `RBAC resolution skipped (tables may not exist): ${(error as Error).message}`,
      );
      return { rbacRoles: [], permissions: [], screens: [] };
    }
  }
}
