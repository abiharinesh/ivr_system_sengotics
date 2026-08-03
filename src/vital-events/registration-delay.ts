/**
 * Late-registration classification under s.13 of the Registration of Births
 * and Deaths Act, 1969.
 *
 * Kept pure and separate from the service so the thresholds can be tested
 * directly and pointed at when a registrar asks why a particular file needs a
 * magistrate's order.
 *
 * The four bands are statutory, not configurable:
 *   • within 21 days  — ordinary registration, no extra sanction
 *   • 22 to 30 days   — registrar may register on payment of a late fee
 *   • 31 days to 1 yr — written permission of the prescribed authority, plus
 *                       an affidavit
 *   • beyond 1 year   — order of a magistrate of the first class
 *
 * The late fee amount itself is *not* here: it is fixed by state rules and
 * varies, so it belongs in master data alongside the other fee schedules.
 */

export const ORDINARY_WINDOW_DAYS = 21;
export const LATE_FEE_WINDOW_DAYS = 30;
export const DAYS_IN_YEAR = 365;

export type DelayBand =
  | 'ordinary'
  | 'late_fee'
  | 'authority_permission'
  | 'magistrate_order';

export interface DelayAssessment {
  delayDays: number;
  band: DelayBand;
  isLate: boolean;
  /** True when the entry cannot be registered without a reference on file. */
  requiresApprovalRef: boolean;
  /** Plain-language explanation, shown in the UI and stored in the audit log. */
  reason: string;
}

/** Whole days between two dates, ignoring clock time. */
export function daysBetween(eventDate: Date, reportedAt: Date): number {
  const startOfDay = (d: Date) =>
    Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
  const diffMs = startOfDay(reportedAt) - startOfDay(eventDate);
  return Math.floor(diffMs / (1000 * 60 * 60 * 24));
}

/**
 * Assess how late a report is. A negative delay (event dated in the future)
 * is treated as invalid by the caller, but is reported here as `ordinary` with
 * the raw figure so the error message can quote it.
 */
export function assessDelay(eventDate: Date, reportedAt: Date): DelayAssessment {
  const delayDays = daysBetween(eventDate, reportedAt);

  if (delayDays <= ORDINARY_WINDOW_DAYS) {
    return {
      delayDays,
      band: 'ordinary',
      isLate: false,
      requiresApprovalRef: false,
      reason: `Reported within the ${ORDINARY_WINDOW_DAYS}-day statutory window`,
    };
  }

  if (delayDays <= LATE_FEE_WINDOW_DAYS) {
    return {
      delayDays,
      band: 'late_fee',
      isLate: true,
      requiresApprovalRef: false,
      reason: `Reported ${delayDays} days after the event — registrable on payment of the prescribed late fee`,
    };
  }

  if (delayDays <= DAYS_IN_YEAR) {
    return {
      delayDays,
      band: 'authority_permission',
      isLate: true,
      requiresApprovalRef: true,
      reason: `Reported ${delayDays} days after the event — needs written permission of the prescribed authority and an affidavit`,
    };
  }

  return {
    delayDays,
    band: 'magistrate_order',
    isLate: true,
    requiresApprovalRef: true,
    reason: `Reported ${delayDays} days after the event — needs an order of a magistrate of the first class`,
  };
}
