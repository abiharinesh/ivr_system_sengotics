import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';

export interface CreateCommentDto {
  tenantId: string;
  entityType: string;   // "complaint", "asset", "work_order", "tender"
  entityId: number;
  userId: number;
  body: string;
  attachmentUrl?: string;
  isInternal?: boolean;  // Default: true (internal note). false = visible to citizen.
}

/**
 * Polymorphic comment system — works across complaints, assets, tenders, work orders.
 * Internal notes vs citizen-facing comments controlled by `isInternal` flag.
 */
@Injectable()
export class CommentService {
  private readonly logger = new Logger(CommentService.name);

  constructor(
    private prisma: PrismaService,
    private audit: AuditService,
  ) {}

  async create(dto: CreateCommentDto) {
    const comment = await this.prisma.comment.create({
      data: {
        tenant_id: dto.tenantId,
        entity_type: dto.entityType,
        entity_id: dto.entityId,
        user_id: dto.userId,
        body: dto.body,
        attachment_url: dto.attachmentUrl ?? null,
        is_internal: dto.isInternal ?? true,
      },
    });

    await this.audit.log({
      tenantId: dto.tenantId,
      userId: dto.userId,
      module: dto.entityType,
      entityType: 'Comment',
      entityId: comment.id.toString(),
      action: 'create',
      afterValue: { body: dto.body, entityType: dto.entityType, entityId: dto.entityId },
    });

    return comment;
  }

  async getForEntity(
    tenantId: string,
    entityType: string,
    entityId: number,
    includeInternal = true,
  ) {
    return this.prisma.comment.findMany({
      where: {
        tenant_id: tenantId,
        entity_type: entityType,
        entity_id: entityId,
        is_deleted: false,
        ...(includeInternal ? {} : { is_internal: false }),
      },
      orderBy: { created_at: 'asc' },
    });
  }

  async softDelete(tenantId: string, commentId: number) {
    return this.prisma.comment.update({
      where: { id: commentId },
      data: { is_deleted: true, deleted_at: new Date() },
    });
  }
}
