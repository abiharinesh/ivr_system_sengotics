/**
 * Milestone date engine — pure functions, no DB access.
 * Rules are stored in `Tender.milestone_rules` (Json) and resolved on read.
 */

export type MilestoneSource =
    | 'anchor'
    | 'work_order_date'
    | 'work_completed_at'
    | `milestone:${string}`

export interface MilestoneRule {
    /** Stable key, e.g. "quotation_deadline". */
    id: string
    /** Human-readable label (Tamil/English). */
    label?: string
    /** What date this offset is relative to. */
    source: MilestoneSource
    /** Days to add (negative = before). */
    offset_days: number
    /** Optional: clamp to next business day (Mon–Sat by Indian convention). */
    business_days?: boolean
}

export interface MilestoneAnchors {
    anchor?: Date | null
    work_order_date?: Date | null
    work_completed_at?: Date | null
}

export interface MilestoneResolution {
    /** Resolved milestone id -> ISO 8601 date string (or null when source missing). */
    dates: Record<string, string | null>
    /** Soft validation findings. */
    conflicts: Array<{ id: string; reason: string }>
}

/** Default rule set — matches the Sundaramoorthy worked-example cadence. */
export const DEFAULT_MILESTONE_RULES: MilestoneRule[] = [
    { id: 'quotation_deadline',   label: 'Quotation deadline',     source: 'anchor',            offset_days: 1 },
    { id: 'comparative_due',      label: 'Comparative statement',  source: 'anchor',            offset_days: 4 },
    { id: 'award_date',           label: 'Award date',             source: 'milestone:comparative_due', offset_days: 0 },
    { id: 'completion_deadline',  label: 'Completion deadline',    source: 'milestone:award_date',      offset_days: 3 },
    { id: 'so_proceedings_target',label: 'SO proceedings target',  source: 'work_completed_at', offset_days: 14 },
    { id: 'voucher_target',       label: 'Voucher target',         source: 'milestone:so_proceedings_target', offset_days: 7 },
]

function addDaysIso(base: Date, days: number, businessDays?: boolean): string {
    const d = new Date(base.getTime())
    d.setUTCDate(d.getUTCDate() + days)
    if (businessDays) {
        // Roll forward off Sundays only (panchayat offices typically work Mon–Sat).
        while (d.getUTCDay() === 0) {
            d.setUTCDate(d.getUTCDate() + 1)
        }
    }
    return d.toISOString().slice(0, 10)
}

/**
 * Resolve a list of milestone rules into ISO date strings.
 * - Rules referencing other milestones are resolved iteratively (max 8 passes).
 * - Cycles or unresolved sources surface in `conflicts[]` with `dates[id] = null`.
 */
export function resolveMilestones(
    rules: MilestoneRule[] | null | undefined,
    anchors: MilestoneAnchors
): MilestoneResolution {
    const dates: Record<string, string | null> = {}
    const conflicts: Array<{ id: string; reason: string }> = []
    if (!rules || rules.length === 0) return { dates, conflicts }

    const ruleById = new Map<string, MilestoneRule>()
    for (const r of rules) {
        if (ruleById.has(r.id)) {
            conflicts.push({ id: r.id, reason: 'duplicate rule id' })
        }
        ruleById.set(r.id, r)
        dates[r.id] = null
    }

    const baseFor = (src: MilestoneSource): Date | null | undefined => {
        if (src === 'anchor') return anchors.anchor ?? null
        if (src === 'work_order_date') return anchors.work_order_date ?? null
        if (src === 'work_completed_at') return anchors.work_completed_at ?? null
        if (src.startsWith('milestone:')) {
            const refId = src.slice('milestone:'.length)
            const iso = dates[refId]
            if (iso == null) return undefined
            return new Date(`${iso}T00:00:00.000Z`)
        }
        return null
    }

    // Iterative resolution: keep retrying until no progress or all done.
    for (let pass = 0; pass < 8; pass++) {
        let changed = false
        for (const r of rules) {
            if (dates[r.id] != null) continue
            const base = baseFor(r.source)
            if (base === null) {
                dates[r.id] = null
                continue
            }
            if (base === undefined) continue
            dates[r.id] = addDaysIso(base, r.offset_days || 0, r.business_days)
            changed = true
        }
        if (!changed) break
    }

    for (const r of rules) {
        if (dates[r.id] == null && r.source !== 'work_completed_at' && r.source !== 'work_order_date' && r.source !== 'anchor') {
            // Likely a cycle or missing referenced milestone.
            const refId = typeof r.source === 'string' && r.source.startsWith('milestone:')
                ? r.source.slice('milestone:'.length)
                : '(unknown)'
            conflicts.push({ id: r.id, reason: `unresolved (depends on ${refId})` })
        }
    }
    return { dates, conflicts }
}
