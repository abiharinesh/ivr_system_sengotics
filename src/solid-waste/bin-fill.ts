/**
 * Fill-level classification and route-progress arithmetic.
 *
 * Pure and separate from the service so the thresholds are testable on their
 * own and so the map legend, the SLA trigger and the API all agree on what
 * "red" means. A disagreement between those three is exactly the bug that
 * makes a bin dashboard untrustworthy.
 */

export type BinFillLevel =
  | 'EMPTY'
  | 'LOW'
  | 'MEDIUM'
  | 'HIGH'
  | 'OVERFLOWING';

/**
 * Lower bound of each band, in percent. A bin is in the highest band whose
 * threshold it meets or exceeds.
 *
 * These are operational rather than statutory, so a body could reasonably want
 * them configurable later; they sit here as named constants rather than magic
 * numbers so that change is a one-line move into master data.
 */
export const FILL_THRESHOLDS: { level: BinFillLevel; minPct: number }[] = [
  { level: 'OVERFLOWING', minPct: 100 },
  { level: 'HIGH', minPct: 75 },
  { level: 'MEDIUM', minPct: 40 },
  { level: 'LOW', minPct: 10 },
  { level: 'EMPTY', minPct: 0 },
];

/** What the GIS pin renders as. Three colours, because that is what a map can say at a glance. */
export type PinColour = 'green' | 'yellow' | 'red';

const PIN_BY_LEVEL: Record<BinFillLevel, PinColour> = {
  EMPTY: 'green',
  LOW: 'green',
  MEDIUM: 'yellow',
  HIGH: 'red',
  OVERFLOWING: 'red',
};

/** Clamp a reported percentage into 0–100 before anything else uses it. */
export function clampPct(pct: number): number {
  if (!Number.isFinite(pct)) return 0;
  return Math.max(0, Math.min(100, Math.round(pct)));
}

export function classifyFill(pct: number): BinFillLevel {
  const clamped = clampPct(pct);
  for (const band of FILL_THRESHOLDS) {
    if (clamped >= band.minPct) return band.level;
  }
  return 'EMPTY';
}

export function pinColour(level: BinFillLevel): PinColour {
  return PIN_BY_LEVEL[level];
}

/**
 * A bin at or past HIGH needs clearing before it becomes a public health
 * problem, and that is what starts the SLA clock.
 */
export function needsClearance(level: BinFillLevel): boolean {
  return level === 'HIGH' || level === 'OVERFLOWING';
}

/**
 * An overflowing bin is a different urgency from a merely full one, and the
 * SLA policy lookup keys on this.
 */
export function clearanceUrgency(level: BinFillLevel): 'high' | 'critical' {
  return level === 'OVERFLOWING' ? 'critical' : 'high';
}

export type ProgressBand = 'not_started' | 'behind' | 'on_track' | 'complete';

export interface RouteProgress {
  completed: number;
  total: number;
  percent: number;
  band: ProgressBand;
}

/**
 * Progress of a day's collection round.
 *
 * `behind` is deliberately generous — a crew part-way through a route at
 * mid-morning is not behind, so this reports position, not judgement, and the
 * caller decides what to escalate. A route with no stops reports 0%, never
 * 100%, because an empty route has not been driven.
 */
export function routeProgress(completed: number, total: number): RouteProgress {
  const safeTotal = Math.max(0, Math.trunc(total));
  const safeCompleted = Math.max(0, Math.min(safeTotal, Math.trunc(completed)));

  if (safeTotal === 0) {
    return { completed: 0, total: 0, percent: 0, band: 'not_started' };
  }

  const percent = Math.round((safeCompleted / safeTotal) * 100);

  let band: ProgressBand;
  if (safeCompleted === 0) {
    band = 'not_started';
  } else if (safeCompleted === safeTotal) {
    band = 'complete';
  } else if (percent < 50) {
    band = 'behind';
  } else {
    band = 'on_track';
  }

  return { completed: safeCompleted, total: safeTotal, percent, band };
}

/**
 * Weight reconciliation for a trip. Segregated wet + dry should account for
 * the total; a gap means the weighbridge slip and the segregation log
 * disagree, which a supervisor needs to see rather than have silently summed
 * away.
 */
export interface WeightCheck {
  total: number;
  segregated: number;
  unaccounted: number;
  reconciles: boolean;
}

/** Tolerance in kg — weighbridges round, and crews are not laboratories. */
export const WEIGHT_TOLERANCE_KG = 5;

export function checkWeights(
  totalKg?: number | null,
  wetKg?: number | null,
  dryKg?: number | null,
): WeightCheck | null {
  if (totalKg == null || (wetKg == null && dryKg == null)) return null;

  const total = Math.max(0, totalKg);
  const segregated = Math.max(0, wetKg ?? 0) + Math.max(0, dryKg ?? 0);
  const unaccounted = Number((total - segregated).toFixed(2));

  return {
    total,
    segregated,
    unaccounted,
    reconciles: Math.abs(unaccounted) <= WEIGHT_TOLERANCE_KG,
  };
}
