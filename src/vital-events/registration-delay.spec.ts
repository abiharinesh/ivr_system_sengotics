import {
  assessDelay,
  daysBetween,
  DAYS_IN_YEAR,
  LATE_FEE_WINDOW_DAYS,
  ORDINARY_WINDOW_DAYS,
} from './registration-delay';

const utc = (iso: string) => new Date(`${iso}T00:00:00.000Z`);

describe('daysBetween', () => {
  it('counts whole days, ignoring the time of day', () => {
    expect(
      daysBetween(
        new Date('2026-03-01T23:50:00.000Z'),
        new Date('2026-03-02T00:10:00.000Z'),
      ),
    ).toBe(1);
  });

  it('returns zero for a same-day report', () => {
    expect(
      daysBetween(
        new Date('2026-03-01T02:00:00.000Z'),
        new Date('2026-03-01T22:00:00.000Z'),
      ),
    ).toBe(0);
  });

  it('goes negative for an event dated in the future', () => {
    expect(daysBetween(utc('2026-03-10'), utc('2026-03-01'))).toBe(-9);
  });
});

describe('assessDelay', () => {
  it('treats a same-day report as ordinary', () => {
    const a = assessDelay(utc('2026-03-01'), utc('2026-03-01'));
    expect(a.band).toBe('ordinary');
    expect(a.isLate).toBe(false);
    expect(a.requiresApprovalRef).toBe(false);
  });

  it('is still ordinary on the last day of the statutory window', () => {
    const a = assessDelay(utc('2026-03-01'), utc('2026-03-22')); // 21 days
    expect(a.delayDays).toBe(ORDINARY_WINDOW_DAYS);
    expect(a.band).toBe('ordinary');
    expect(a.isLate).toBe(false);
  });

  it('crosses into the late-fee band one day later', () => {
    const a = assessDelay(utc('2026-03-01'), utc('2026-03-23')); // 22 days
    expect(a.band).toBe('late_fee');
    expect(a.isLate).toBe(true);
    // A late fee is payable, but no external sanction is needed.
    expect(a.requiresApprovalRef).toBe(false);
  });

  it('stays in the late-fee band up to thirty days', () => {
    const a = assessDelay(utc('2026-03-01'), utc('2026-03-31')); // 30 days
    expect(a.delayDays).toBe(LATE_FEE_WINDOW_DAYS);
    expect(a.band).toBe('late_fee');
  });

  it('needs the prescribed authority beyond thirty days', () => {
    const a = assessDelay(utc('2026-03-01'), utc('2026-04-01')); // 31 days
    expect(a.band).toBe('authority_permission');
    expect(a.requiresApprovalRef).toBe(true);
    expect(a.reason).toMatch(/written permission/i);
  });

  it('still needs only the authority at exactly one year', () => {
    const a = assessDelay(utc('2026-03-01'), utc('2027-03-01')); // 365 days
    expect(a.delayDays).toBe(DAYS_IN_YEAR);
    expect(a.band).toBe('authority_permission');
  });

  it('escalates to a magistrate beyond one year', () => {
    const a = assessDelay(utc('2026-03-01'), utc('2027-03-02')); // 366 days
    expect(a.band).toBe('magistrate_order');
    expect(a.requiresApprovalRef).toBe(true);
    expect(a.reason).toMatch(/magistrate/i);
  });

  it('reports a future-dated event without throwing, so the caller can quote it', () => {
    const a = assessDelay(utc('2026-03-10'), utc('2026-03-01'));
    expect(a.delayDays).toBe(-9);
    expect(a.band).toBe('ordinary');
    expect(a.isLate).toBe(false);
  });

  it('always states a reason', () => {
    for (const days of [0, 25, 100, 500]) {
      const reported = new Date(utc('2026-03-01').getTime() + days * 86_400_000);
      expect(assessDelay(utc('2026-03-01'), reported).reason).toBeTruthy();
    }
  });
});
