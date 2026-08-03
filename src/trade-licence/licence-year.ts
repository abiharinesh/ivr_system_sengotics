/**
 * Licence-year and renewal-penalty arithmetic.
 *
 * The licence year runs with the Indian financial year — 1 April to 31 March —
 * whatever the grant date. A licence issued in November still expires on the
 * following 31 March, which is why validity cannot be a rolling twelve months
 * and why the first year's fee is pro-rated.
 *
 * Pure and separate from the service so a disputed expiry date or penalty can
 * be reproduced without a database.
 */

/** Financial year label for a date, e.g. 2026-08-02 → "2026-27". */
export function financialYearOf(date: Date): string {
  const year = date.getFullYear();
  const month = date.getMonth(); // 0-indexed; April = 3
  const startYear = month >= 3 ? year : year - 1;
  return `${startYear}-${(startYear + 1).toString().slice(-2)}`;
}

/** 1 April of the given financial year label. */
export function financialYearStart(label: string): Date {
  const startYear = Number(label.split('-')[0]);
  return new Date(Date.UTC(startYear, 3, 1));
}

/** 31 March closing the given financial year label. */
export function financialYearEnd(label: string): Date {
  const startYear = Number(label.split('-')[0]);
  return new Date(Date.UTC(startYear + 1, 2, 31));
}

/** The financial year following the given label. */
export function nextFinancialYear(label: string): string {
  const startYear = Number(label.split('-')[0]) + 1;
  return `${startYear}-${(startYear + 1).toString().slice(-2)}`;
}

/**
 * Completed quarters remaining in a financial year from a given date,
 * counting the quarter the date falls in as remaining.
 *
 * Used to pro-rate the first year's fee: a licence granted in Q4 is charged a
 * quarter of the annual fee, not the whole of it.
 */
export function quartersRemaining(date: Date, fyLabel: string): number {
  const start = financialYearStart(fyLabel);
  const end = financialYearEnd(fyLabel);
  if (date <= start) return 4;
  if (date > end) return 0;

  const monthsElapsed =
    (date.getUTCFullYear() - start.getUTCFullYear()) * 12 +
    (date.getUTCMonth() - start.getUTCMonth());
  const quartersElapsed = Math.floor(monthsElapsed / 3);
  return Math.max(1, 4 - quartersElapsed);
}

// ── Penalty ladder ──────────────────────────────────────────────────────────

export const LATE_GRACE_DAYS = 30;
export const LATE_SECOND_BAND_DAYS = 90;

export type PenaltyBand = 'ontime' | 'late_30' | 'late_90' | 'lapsed';

/**
 * ⚠ PLACEHOLDER DEFAULTS. The penalty is fixed by council resolution and
 * differs between bodies. Expressed as a percentage of the annual fee.
 */
export const PENALTY_PCT: Record<PenaltyBand, number> = {
  ontime: 0,
  late_30: 25,
  late_90: 50,
  lapsed: 100,
};

export interface RenewalAssessment {
  daysLate: number;
  band: PenaltyBand;
  penaltyPct: number;
  /**
   * Past this point the licence has lapsed: a fresh application is required,
   * not a renewal. The service refuses to renew when this is true.
   */
  requiresFreshApplication: boolean;
  reason: string;
}

/** Whole days between two dates, ignoring clock time. */
export function daysBetween(from: Date, to: Date): number {
  const startOfDay = (d: Date) =>
    Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
  return Math.floor((startOfDay(to) - startOfDay(from)) / 86_400_000);
}

/**
 * How late a renewal is against the expiry of the year being renewed from.
 * A renewal applied for before expiry is `ontime` with zero days late.
 */
export function assessRenewal(
  previousValidUntil: Date,
  renewedOn: Date,
): RenewalAssessment {
  const daysLate = Math.max(0, daysBetween(previousValidUntil, renewedOn));

  if (daysLate === 0) {
    return {
      daysLate: 0,
      band: 'ontime',
      penaltyPct: PENALTY_PCT.ontime,
      requiresFreshApplication: false,
      reason: 'Renewed within the licence year',
    };
  }

  if (daysLate <= LATE_GRACE_DAYS) {
    return {
      daysLate,
      band: 'late_30',
      penaltyPct: PENALTY_PCT.late_30,
      requiresFreshApplication: false,
      reason: `Renewed ${daysLate} day(s) after expiry — late fee applies`,
    };
  }

  if (daysLate <= LATE_SECOND_BAND_DAYS) {
    return {
      daysLate,
      band: 'late_90',
      penaltyPct: PENALTY_PCT.late_90,
      requiresFreshApplication: false,
      reason: `Renewed ${daysLate} day(s) after expiry — higher penalty band`,
    };
  }

  return {
    daysLate,
    band: 'lapsed',
    penaltyPct: PENALTY_PCT.lapsed,
    requiresFreshApplication: true,
    reason: `Lapsed ${daysLate} day(s) — beyond ${LATE_SECOND_BAND_DAYS} days a fresh application is required, not a renewal`,
  };
}

// ── Fees ────────────────────────────────────────────────────────────────────

export interface CategoryRate {
  /** Flat annual fee for the category, in rupees. */
  base: number;
  /** ₹ per sqft of premises floor area. */
  per_sqft: number;
  /** ₹ per horsepower of installed motive power. */
  per_hp: number;
  /** Whether this category must be inspected before every renewal. */
  annual_inspection: boolean;
}

/**
 * ⚠ PLACEHOLDER DEFAULTS — replace with the client body's gazetted schedule
 * before go-live, ideally by moving this table into master data so revisions
 * do not need a deploy.
 */
export const CATEGORY_RATES: Record<string, CategoryRate> = {
  eatery: { base: 2000, per_sqft: 4, per_hp: 100, annual_inspection: true },
  provision_store: { base: 1000, per_sqft: 2, per_hp: 50, annual_inspection: false },
  workshop: { base: 2500, per_sqft: 3, per_hp: 200, annual_inspection: true },
  godown: { base: 1500, per_sqft: 2, per_hp: 50, annual_inspection: false },
  clinic: { base: 3000, per_sqft: 4, per_hp: 100, annual_inspection: true },
  salon: { base: 1200, per_sqft: 3, per_hp: 80, annual_inspection: true },
  bakery: { base: 2200, per_sqft: 4, per_hp: 150, annual_inspection: true },
  laundry: { base: 1200, per_sqft: 3, per_hp: 120, annual_inspection: false },
  timber_depot: { base: 3000, per_sqft: 2, per_hp: 200, annual_inspection: true },
  other: { base: 1500, per_sqft: 3, per_hp: 100, annual_inspection: false },
};

export const DEFAULT_CATEGORY = 'other';

/** Round to whole rupees — councils do not bill paise on licence fees. */
const rupees = (n: number): number => Math.round(n);

export interface FeeInput {
  trade_category: string;
  area_sqft: number;
  motive_power_hp?: number | null;
  /** 1–4. Pass 4 for a full-year renewal; fewer pro-rates a first grant. */
  quarters?: number;
  penaltyPct?: number;
}

export interface FeeBreakdown {
  base_fee: number;
  area_fee: number;
  power_fee: number;
  penalty_fee: number;
  total_fee: number;
  quarters: number;
}

/**
 * Compute a licence fee. Unknown categories fall back to `other` rather than
 * throwing, so a stale dropdown value never blocks a counter transaction; the
 * caller validates the enum separately.
 *
 * The penalty is charged on the annual components only — a body does not
 * penalise a trader on a pro-rated part year they were never billed for.
 */
export function computeLicenceFee(input: FeeInput): FeeBreakdown {
  const rate = CATEGORY_RATES[input.trade_category] ?? CATEGORY_RATES[DEFAULT_CATEGORY];
  const area = Math.max(0, input.area_sqft ?? 0);
  const hp = Math.max(0, input.motive_power_hp ?? 0);
  const quarters = Math.min(4, Math.max(1, Math.trunc(input.quarters ?? 4)));
  const fraction = quarters / 4;

  const base_fee = rupees(rate.base * fraction);
  const area_fee = rupees(area * rate.per_sqft * fraction);
  const power_fee = rupees(hp * rate.per_hp * fraction);

  const annual = base_fee + area_fee + power_fee;
  const penalty_fee = rupees((annual * (input.penaltyPct ?? 0)) / 100);

  return {
    base_fee,
    area_fee,
    power_fee,
    penalty_fee,
    total_fee: annual + penalty_fee,
    quarters,
  };
}

/** Whether this category must be inspected before every renewal. */
export function requiresAnnualInspection(category: string): boolean {
  return (
    CATEGORY_RATES[category] ?? CATEGORY_RATES[DEFAULT_CATEGORY]
  ).annual_inspection;
}
