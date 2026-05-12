import { Injectable } from '@nestjs/common'
import { PrismaService } from '../prisma/prisma.service'

@Injectable()
export class TenderAuditService {
    constructor(private readonly prisma: PrismaService) {}

    /** Append a single audit entry; non-throwing (best-effort). */
    async record(args: {
        tenderId: number
        actorUserId?: number | null
        event: string
        payload?: Record<string, unknown> | null
    }): Promise<void> {
        try {
            await this.prisma.tenderAuditLog.create({
                data: {
                    tender_id: args.tenderId,
                    actor_user_id: args.actorUserId ?? null,
                    event: args.event,
                    payload: (args.payload ?? null) as any,
                },
            })
        } catch (_err) {
            // Audit failures must not break the operation.
        }
    }

    list(tenderId: number) {
        return this.prisma.tenderAuditLog.findMany({
            where: { tender_id: tenderId },
            orderBy: { created_at: 'desc' },
            take: 200,
            include: { actor: { select: { id: true, email: true } } },
        })
    }
}
