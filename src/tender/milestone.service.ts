import { Injectable, NotFoundException } from '@nestjs/common'
import { PrismaService } from '../prisma/prisma.service'
import {
    DEFAULT_MILESTONE_RULES,
    MilestoneAnchors,
    MilestoneRule,
    resolveMilestones,
    MilestoneResolution,
} from '../common/milestone.util'

@Injectable()
export class MilestoneService {
    constructor(private readonly prisma: PrismaService) {}

    /** Resolve milestone dates for a tender using its stored rules + anchors. */
    async resolveForTender(tenderId: number): Promise<MilestoneResolution & { rules: MilestoneRule[] }> {
        const tender = await this.prisma.tender.findUnique({ where: { id: tenderId } })
        if (!tender) throw new NotFoundException(`Tender #${tenderId} not found`)

        const rules: MilestoneRule[] = Array.isArray(tender.milestone_rules)
            ? (tender.milestone_rules as unknown as MilestoneRule[])
            : DEFAULT_MILESTONE_RULES

        const anchors: MilestoneAnchors = {
            anchor: tender.anchor_date,
            work_order_date: tender.work_order_date,
            work_completed_at: tender.work_completed_at,
        }
        return { ...resolveMilestones(rules, anchors), rules }
    }
}
