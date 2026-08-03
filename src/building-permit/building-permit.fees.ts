/**
 * Fee computation for building permit applications.
 *
 * Kept as a pure function, separate from the service, so the arithmetic can be
 * unit-tested without a database and so a council can be shown exactly how a
 * figure was reached when an applicant disputes it.
 *
 * ⚠ The rates below are PLACEHOLDER DEFAULTS. Building permit fees are fixed by
 * each local body's council resolution under the TN Town and Country Planning
 * Act and differ between corporations, municipalities and town panchayats.
 * Before go-live for a client these must be replaced with that body's gazetted
 * schedule — ideally by moving `FEE_RATES` into master data (`SystemSettings`
 * or a `fee_schedules` table) so revisions don't need a deploy.
 */

export type ConstructionType =
  | 'residential'
  | 'commercial'
  | 'industrial'
  | 'institutional'
  | 'mixed';

export interface FeeRate {
  /** ₹ per sqm of built-up area, charged at scrutiny. */
  scrutiny_per_sqm: number;
  /** ₹ per sqm of built-up area, charged on the permit itself. */
  permit_per_sqm: number;
  /** ₹ per sqm of plot area, the development charge. */
  development_per_sqm: number;
}

export const FEE_RATES: Record<ConstructionType, FeeRate> = {
  residential: { scrutiny_per_sqm: 10, permit_per_sqm: 30, development_per_sqm: 15 },
  commercial: { scrutiny_per_sqm: 25, permit_per_sqm: 90, development_per_sqm: 45 },
  industrial: { scrutiny_per_sqm: 20, permit_per_sqm: 75, development_per_sqm: 40 },
  institutional: { scrutiny_per_sqm: 15, permit_per_sqm: 45, development_per_sqm: 25 },
  mixed: { scrutiny_per_sqm: 20, permit_per_sqm: 60, development_per_sqm: 30 },
};

/** Minimum scrutiny fee, so trivially small applications still cover handling. */
export const MIN_SCRUTINY_FEE = 500;

/**
 * Floors above this count attract a surcharge on the permit fee — high-rise
 * proposals need structural scrutiny the base rate doesn't cover.
 */
export const HIGH_RISE_FLOOR_THRESHOLD = 3;
export const HIGH_RISE_SURCHARGE_PCT = 20;

/**
 * Alterations and extensions are charged at a reduced permit rate, since the
 * plan review covers only the changed portion.
 */
export const WORK_NATURE_MULTIPLIER: Record<string, number> = {
  new: 1,
  reconstruction: 1,
  extension: 0.6,
  alteration: 0.4,
};

export interface FeeInput {
  construction_type: string;
  work_nature?: string;
  built_up_area_sqm: number;
  plot_area_sqm: number;
  floors_proposed?: number;
}

export interface FeeBreakdown {
  scrutiny_fee: number;
  permit_fee: number;
  development_fee: number;
  total_fee: number;
}

/** Round to whole rupees — councils do not bill paise on permit fees. */
const rupees = (n: number): number => Math.round(n);

/**
 * Compute the fee breakdown for a proposal. Unknown construction types fall
 * back to `residential` rather than throwing, so a permit is never blocked by
 * a stale dropdown value; the caller validates the enum separately.
 */
export function computePermitFees(input: FeeInput): FeeBreakdown {
  const rate =
    FEE_RATES[input.construction_type as ConstructionType] ?? FEE_RATES.residential;

  const builtUp = Math.max(0, input.built_up_area_sqm ?? 0);
  const plot = Math.max(0, input.plot_area_sqm ?? 0);
  const floors = Math.max(1, input.floors_proposed ?? 1);
  const natureMultiplier = WORK_NATURE_MULTIPLIER[input.work_nature ?? 'new'] ?? 1;

  const scrutiny = Math.max(MIN_SCRUTINY_FEE, builtUp * rate.scrutiny_per_sqm);

  let permit = builtUp * rate.permit_per_sqm * natureMultiplier;
  if (floors > HIGH_RISE_FLOOR_THRESHOLD) {
    permit *= 1 + HIGH_RISE_SURCHARGE_PCT / 100;
  }

  const development = plot * rate.development_per_sqm * natureMultiplier;

  const scrutiny_fee = rupees(scrutiny);
  const permit_fee = rupees(permit);
  const development_fee = rupees(development);

  return {
    scrutiny_fee,
    permit_fee,
    development_fee,
    total_fee: scrutiny_fee + permit_fee + development_fee,
  };
}
