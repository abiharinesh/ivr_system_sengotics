import { DEFAULT_MILESTONE_RULES, resolveMilestones } from './milestone.util'

describe('resolveMilestones', () => {
    it('returns empty result when no rules', () => {
        const r = resolveMilestones([], { anchor: new Date('2026-03-12') })
        expect(r.dates).toEqual({})
        expect(r.conflicts).toEqual([])
    })

    it('resolves the Sundaramoorthy worked-example cadence', () => {
        // Anchor 12/03/26, work_completed_at 29/03/26. (UTC)
        const r = resolveMilestones(DEFAULT_MILESTONE_RULES, {
            anchor: new Date('2026-03-12T00:00:00Z'),
            work_completed_at: new Date('2026-03-29T00:00:00Z'),
        })
        expect(r.dates.quotation_deadline).toBe('2026-03-13')
        expect(r.dates.comparative_due).toBe('2026-03-16')
        expect(r.dates.award_date).toBe('2026-03-16')
        expect(r.dates.completion_deadline).toBe('2026-03-19')
        expect(r.dates.so_proceedings_target).toBe('2026-04-12')
        expect(r.dates.voucher_target).toBe('2026-04-19')
    })

    it('leaves dependent milestones null when source is missing', () => {
        const r = resolveMilestones(DEFAULT_MILESTONE_RULES, {
            anchor: new Date('2026-03-12T00:00:00Z'),
            // work_completed_at intentionally omitted
        })
        expect(r.dates.quotation_deadline).toBe('2026-03-13')
        expect(r.dates.so_proceedings_target).toBeNull()
        expect(r.dates.voucher_target).toBeNull()
    })

    it('detects unresolved milestone references as conflicts', () => {
        const r = resolveMilestones(
            [
                { id: 'a', source: 'milestone:b', offset_days: 1 },
                { id: 'c', source: 'milestone:does_not_exist', offset_days: 1 },
            ],
            { anchor: new Date('2026-01-01T00:00:00Z') }
        )
        expect(r.dates.a).toBeNull()
        expect(r.conflicts.length).toBeGreaterThanOrEqual(1)
    })
})
