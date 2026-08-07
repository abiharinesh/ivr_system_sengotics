import {
  Injectable,
  BadRequestException,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../core/audit/audit.service';
import { PermissionCacheService } from '../core/rbac/permission-cache.service';

export interface CreateStaffDto {
  email: string;
  password?: string;
  phone_e164?: string;
  role_id: number;
  org_unit_id: number;
  department_id?: number;
  access_scope?: string;
}

export interface UpdateStaffDto {
  email?: string;
  phone_e164?: string;
  role_id?: number;
  org_unit_id?: number;
  department_id?: number;
  access_scope?: string;
  is_active?: boolean;
}

@Injectable()
export class TenantUserService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly cache: PermissionCacheService,
  ) {}

  async createStaff(
    tenantId: string,
    actorUserId: number,
    dto: CreateStaffDto,
  ) {
    if (!dto.email && !dto.phone_e164) {
      throw new BadRequestException('Email or phone number is required');
    }

    const role = await this.prisma.role.findFirst({
      where: { id: dto.role_id, tenant_id: tenantId },
    });
    if (!role) {
      throw new NotFoundException(
        `Role with ID ${dto.role_id} not found for tenant "${tenantId}"`,
      );
    }

    const orgUnit = await this.prisma.orgUnit.findFirst({
      where: { id: dto.org_unit_id, tenant_id: tenantId },
    });
    if (!orgUnit) {
      throw new NotFoundException(
        `OrgUnit/Branch with ID ${dto.org_unit_id} not found for tenant "${tenantId}"`,
      );
    }

    if (dto.department_id != null) {
      const department = await this.prisma.department.findFirst({
        where: { id: dto.department_id, tenant_id: tenantId },
      });
      if (!department) {
        throw new NotFoundException(
          `Department with ID ${dto.department_id} not found for tenant "${tenantId}"`,
        );
      }
    }

    const rawPassword = dto.password || 'TempPassword@123';
    const passwordHash = await bcrypt.hash(rawPassword, 10);

    const user = await this.prisma.$transaction(async (tx) => {
      const newUser = await tx.user.create({
        data: {
          tenant_id: tenantId,
          email: dto.email ? dto.email.trim().toLowerCase() : null,
          phone_e164: dto.phone_e164 ? dto.phone_e164.trim() : null,
          password_hash: passwordHash,
          role: role.name,
          primary_org_unit_id: dto.org_unit_id,
          user_type: 'employee',
          must_change_password: true,
          is_active: true,
          is_verified: true,
        },
      });

      await tx.userRole.create({
        data: {
          user_id: newUser.id,
          role_id: role.id,
          tenant_id: tenantId,
          org_unit_id: dto.org_unit_id,
          department_id: dto.department_id ?? null,
          access_scope: dto.access_scope ?? 'own_org_unit',
          is_primary: true,
          granted_by: actorUserId,
        },
      });

      return newUser;
    });

    await this.audit.log({
      tenantId,
      orgUnitId: dto.org_unit_id,
      actorUserId,
      action: 'staff.create',
      newValue: { userId: user.id, email: user.email, role: role.name },
    });

    return {
      id: user.id,
      email: user.email,
      phone_e164: user.phone_e164,
      role: role.name,
      org_unit_id: user.primary_org_unit_id,
      must_change_password: user.must_change_password,
      is_active: user.is_active,
    };
  }

  async listStaff(
    tenantId: string,
    query?: { org_unit_id?: number; department_id?: number; search?: string },
  ) {
    const whereClause: any = {
      tenant_id: tenantId,
      is_deleted: false,
    };

    if (query?.org_unit_id) {
      whereClause.primary_org_unit_id = Number(query.org_unit_id);
    }

    if (query?.department_id) {
      whereClause.user_roles = {
        some: { department_id: Number(query.department_id) },
      };
    }

    if (query?.search) {
      const search = query.search.trim();
      whereClause.OR = [
        { email: { contains: search, mode: 'insensitive' } },
        { phone_e164: { contains: search, mode: 'insensitive' } },
      ];
    }

    const users = await this.prisma.user.findMany({
      where: whereClause,
      select: {
        id: true,
        email: true,
        phone_e164: true,
        role: true,
        is_active: true,
        user_type: true,
        must_change_password: true,
        created_at: true,
        primary_org_unit: {
          select: { id: true, name: true, branch_type: true },
        },
        user_roles: {
          select: {
            id: true,
            org_unit_id: true,
            department_id: true,
            access_scope: true,
            role: { select: { id: true, name: true, display_name: true } },
            department: { select: { id: true, name: true, code: true } },
          },
        },
      },
      orderBy: { created_at: 'desc' },
    });

    return users;
  }

  async getStaff(tenantId: string, userId: number) {
    const user = await this.prisma.user.findFirst({
      where: { id: userId, tenant_id: tenantId, is_deleted: false },
      select: {
        id: true,
        tenant_id: true,
        email: true,
        phone_e164: true,
        role: true,
        is_active: true,
        must_change_password: true,
        created_at: true,
        updated_at: true,
        primary_org_unit: {
          select: { id: true, name: true, branch_type: true },
        },
        user_roles: {
          select: {
            id: true,
            org_unit_id: true,
            department_id: true,
            access_scope: true,
            is_primary: true,
            role: { select: { id: true, name: true, display_name: true } },
            department: { select: { id: true, name: true, code: true } },
          },
        },
        employee: true,
      },
    });

    if (!user) {
      throw new NotFoundException(
        `Staff user with ID ${userId} not found in tenant "${tenantId}"`,
      );
    }

    return user;
  }

  async updateStaff(
    tenantId: string,
    userId: number,
    actorUserId: number,
    dto: UpdateStaffDto,
  ) {
    const existing = await this.getStaff(tenantId, userId);

    if (dto.role_id != null) {
      const role = await this.prisma.role.findFirst({
        where: { id: dto.role_id, tenant_id: tenantId },
      });
      if (!role)
        throw new NotFoundException(
          `Role with ID ${dto.role_id} not found for tenant "${tenantId}"`,
        );
    }
    if (dto.org_unit_id != null) {
      const orgUnit = await this.prisma.orgUnit.findFirst({
        where: { id: dto.org_unit_id, tenant_id: tenantId },
      });
      if (!orgUnit)
        throw new NotFoundException(
          `OrgUnit/Branch with ID ${dto.org_unit_id} not found for tenant "${tenantId}"`,
        );
    }
    if (dto.department_id != null) {
      const department = await this.prisma.department.findFirst({
        where: { id: dto.department_id, tenant_id: tenantId },
      });
      if (!department)
        throw new NotFoundException(
          `Department with ID ${dto.department_id} not found for tenant "${tenantId}"`,
        );
    }

    const updatedUser = await this.prisma.$transaction(async (tx) => {
      const user = await tx.user.update({
        where: { id: userId },
        data: {
          email:
            dto.email !== undefined
              ? dto.email.trim().toLowerCase()
              : undefined,
          phone_e164:
            dto.phone_e164 !== undefined ? dto.phone_e164.trim() : undefined,
          is_active: dto.is_active !== undefined ? dto.is_active : undefined,
          primary_org_unit_id:
            dto.org_unit_id !== undefined ? dto.org_unit_id : undefined,
        },
      });

      if (dto.role_id || dto.org_unit_id || dto.department_id) {
        if (dto.role_id) {
          const role = await tx.role.findFirst({
            where: { id: dto.role_id, tenant_id: tenantId },
          });
          if (role) {
            await tx.user.update({
              where: { id: userId },
              data: { role: role.name },
            });
          }
        }

        const primaryRole = existing.user_roles.find((ur) => ur.is_primary);
        if (primaryRole) {
          await tx.userRole.update({
            where: { id: primaryRole.id },
            data: {
              role_id: dto.role_id ?? primaryRole.role.id,
              org_unit_id: dto.org_unit_id ?? primaryRole.org_unit_id,
              department_id:
                dto.department_id !== undefined
                  ? dto.department_id
                  : primaryRole.department_id,
              access_scope: dto.access_scope ?? primaryRole.access_scope,
            },
          });
        }
      }

      return user;
    });

    this.cache.invalidateUser(userId);

    await this.audit.log({
      tenantId,
      actorUserId,
      action: 'staff.update',
      oldValue: { email: existing.email, is_active: existing.is_active },
      newValue: { email: updatedUser.email, is_active: updatedUser.is_active },
    });

    return this.getStaff(tenantId, userId);
  }

  async deactivateStaff(tenantId: string, userId: number, actorUserId: number) {
    await this.getStaff(tenantId, userId);

    const user = await this.prisma.user.update({
      where: { id: userId },
      data: { is_active: false },
    });

    this.cache.invalidateUser(userId);

    await this.audit.log({
      tenantId,
      actorUserId,
      action: 'staff.deactivate',
      newValue: { userId, is_active: false },
    });

    return { success: true, id: userId, is_active: false };
  }

  async softDeleteStaff(tenantId: string, userId: number, actorUserId: number) {
    await this.getStaff(tenantId, userId);

    await this.prisma.user.update({
      where: { id: userId },
      data: {
        is_active: false,
        is_deleted: true,
        deleted_at: new Date(),
        deleted_by: actorUserId,
      },
    });

    this.cache.invalidateUser(userId);

    await this.audit.log({
      tenantId,
      actorUserId,
      action: 'staff.delete',
      newValue: { userId, is_deleted: true },
    });

    return { success: true, id: userId };
  }
}
