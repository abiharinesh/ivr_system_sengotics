import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

/** A folder plus its children, as the explorer's tree renders it. */
export interface FolderNode {
  id: number;
  name: string;
  document_count: number;
  children: FolderNode[];
}

/**
 * Browsing the document register.
 *
 * Separate from {@link DocumentService}, which owns writes — upload, sign,
 * soft-delete. This one only reads, so it can be granted to far more roles
 * than the write path without widening what any of them can change.
 */
@Injectable()
export class DocumentBrowserService {
  constructor(private readonly prisma: PrismaService) {}

  /** Scope every read to the caller's branch unless they are platform-wide. */
  private scope(tenantId: string, orgUnitId: number | null) {
    return {
      tenant_id: tenantId,
      is_deleted: false,
      ...(orgUnitId == null ? {} : { org_unit_id: orgUnitId }),
    };
  }

  /**
   * The folder tree, with a document count on every node.
   *
   * Built in memory from one query rather than recursively: the tree is two
   * levels deep by design and a recursive walk would be a query per folder.
   */
  async folderTree(tenantId: string, orgUnitId: number | null): Promise<FolderNode[]> {
    const folders = await this.prisma.documentFolder.findMany({
      where: {
        tenant_id: tenantId,
        ...(orgUnitId == null ? {} : { org_unit_id: orgUnitId }),
      },
      orderBy: { name: 'asc' },
      select: { id: true, name: true, parent_id: true },
    });

    const counts = await this.prisma.document.groupBy({
      by: ['folder_id'],
      where: this.scope(tenantId, orgUnitId),
      _count: { _all: true },
    });
    const countByFolder = new Map(
      counts.map((c) => [c.folder_id, c._count._all]),
    );

    const nodes = new Map<number, FolderNode>(
      folders.map((f) => [
        f.id,
        {
          id: f.id,
          name: f.name,
          document_count: countByFolder.get(f.id) ?? 0,
          children: [],
        },
      ]),
    );

    const roots: FolderNode[] = [];
    for (const f of folders) {
      const node = nodes.get(f.id)!;
      const parent = f.parent_id == null ? null : nodes.get(f.parent_id);
      if (parent) parent.children.push(node);
      else roots.push(node);
    }

    // A parent's count includes what sits in its children, or a top-level
    // folder reads as empty while holding everything one level down.
    const roll = (n: FolderNode): number => {
      const own = n.document_count;
      const kids = n.children.reduce((sum, c) => sum + roll(c), 0);
      n.document_count = own + kids;
      return n.document_count;
    };
    roots.forEach(roll);

    return roots;
  }

  async list(params: {
    tenantId: string;
    orgUnitId: number | null;
    folderId?: number;
    search?: string;
    module?: string;
    take: number;
  }) {
    const { tenantId, orgUnitId, folderId, search, module, take } = params;

    // Selecting a parent folder should show what is filed beneath it too.
    let folderIds: number[] | undefined;
    if (folderId != null) {
      const children = await this.prisma.documentFolder.findMany({
        where: { parent_id: folderId },
        select: { id: true },
      });
      folderIds = [folderId, ...children.map((c) => c.id)];
    }

    const rows = await this.prisma.document.findMany({
      where: {
        ...this.scope(tenantId, orgUnitId),
        ...(folderIds ? { folder_id: { in: folderIds } } : {}),
        ...(module ? { module } : {}),
        ...(search
          ? {
              OR: [
                { title: { contains: search, mode: 'insensitive' } },
                { file_name: { contains: search, mode: 'insensitive' } },
              ],
            }
          : {}),
      },
      orderBy: { created_at: 'desc' },
      take,
      select: {
        id: true,
        title: true,
        file_name: true,
        file_url: true,
        file_size_bytes: true,
        mime_type: true,
        version: true,
        module: true,
        entity_type: true,
        entity_id: true,
        folder_id: true,
        tags: true,
        expires_at: true,
        created_at: true,
        digital_signature: true,
      },
    });

    return rows.map((d) => ({
      ...d,
      // BigInt does not survive JSON, and a byte count fits a number fine.
      file_size_bytes:
        d.file_size_bytes == null ? null : Number(d.file_size_bytes),
      is_signed: d.digital_signature != null,
      digital_signature: undefined,
    }));
  }

  async summary(tenantId: string, orgUnitId: number | null) {
    const scope = this.scope(tenantId, orgUnitId);
    const [total, byModule, signed, expiring, size] = await Promise.all([
      this.prisma.document.count({ where: scope }),
      this.prisma.document.groupBy({
        by: ['module'],
        where: scope,
        _count: { _all: true },
      }),
      this.prisma.document.count({
        where: { ...scope, digital_signature: { not: Prisma.DbNull } },
      }),
      this.prisma.document.count({
        where: {
          ...scope,
          expires_at: {
            gte: new Date(),
            lte: new Date(Date.now() + 30 * 86400000),
          },
        },
      }),
      this.prisma.document.aggregate({
        where: scope,
        _sum: { file_size_bytes: true },
      }),
    ]);

    return {
      total,
      signed,
      expiring_in_30_days: expiring,
      total_bytes: size._sum.file_size_bytes
        ? Number(size._sum.file_size_bytes)
        : 0,
      by_module: byModule
        .map((m) => ({ module: m.module ?? 'unfiled', count: m._count._all }))
        .sort((a, b) => b.count - a.count),
    };
  }

  async one(tenantId: string, orgUnitId: number | null, id: number) {
    const doc = await this.prisma.document.findFirst({
      where: { id, ...this.scope(tenantId, orgUnitId) },
    });
    if (!doc) throw new NotFoundException(`Document #${id} not found`);
    return {
      ...doc,
      file_size_bytes:
        doc.file_size_bytes == null ? null : Number(doc.file_size_bytes),
    };
  }
}
