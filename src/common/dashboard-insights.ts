/**
 * Dashboard insight helpers (UTC Monday–Sunday weeks, resolution event logic).
 */

export type ComplaintResolutionFields = {
  id: number;
  complaint_type: string | null;
  description: string | null;
  status: string;
  created_at: Date;
  resolved_at: Date | null;
  resolution_image_captured_at: Date | null;
};

/** Monday 00:00:00.000 UTC for the week containing `d`. */
export function utcMondayWeekStart(d: Date): Date {
  const x = new Date(
    Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()),
  );
  const day = x.getUTCDay();
  const daysSinceMonday = (day + 6) % 7;
  x.setUTCDate(x.getUTCDate() - daysSinceMonday);
  x.setUTCHours(0, 0, 0, 0);
  return x;
}

export function effectiveResolutionDate(c: {
  resolved_at: Date | null;
  resolution_image_captured_at: Date | null;
  status: string;
}): Date | null {
  if (c.resolved_at) return c.resolved_at;
  if (
    (c.status === 'resolved_pending_confirmation' || c.status === 'resolved') &&
    c.resolution_image_captured_at
  ) {
    return c.resolution_image_captured_at;
  }
  return null;
}

/** Seven ints Mon..Sun for last calendar week and current calendar week (UTC). */
export function buildResolutionTrend(
  complaints: Pick<
    ComplaintResolutionFields,
    'resolved_at' | 'resolution_image_captured_at' | 'status'
  >[],
): { current_week: number[]; last_week: number[] } {
  const now = new Date();
  const currentWeekStart = utcMondayWeekStart(now);
  const lastWeekStart = new Date(currentWeekStart);
  lastWeekStart.setUTCDate(lastWeekStart.getUTCDate() - 7);
  const currentWeekEnd = new Date(currentWeekStart);
  currentWeekEnd.setUTCDate(currentWeekEnd.getUTCDate() + 7);
  const lastWeekEnd = new Date(lastWeekStart);
  lastWeekEnd.setUTCDate(lastWeekEnd.getUTCDate() + 7);

  const last_week = [0, 0, 0, 0, 0, 0, 0];
  const current_week = [0, 0, 0, 0, 0, 0, 0];

  for (const c of complaints) {
    const eff = effectiveResolutionDate(c);
    if (!eff) continue;
    const t = eff.getTime();
    if (t < lastWeekStart.getTime() || t >= currentWeekEnd.getTime()) continue;
    const dowMon0 = (eff.getUTCDay() + 6) % 7;
    if (t >= lastWeekStart.getTime() && t < lastWeekEnd.getTime()) {
      last_week[dowMon0]++;
    } else if (
      t >= currentWeekStart.getTime() &&
      t < currentWeekEnd.getTime()
    ) {
      current_week[dowMon0]++;
    }
  }

  return { current_week, last_week };
}

export type ActivityKind =
  | 'new_complaint'
  | 'resolved'
  | 'resolution_submitted';

export type ActivityRow = {
  kind: ActivityKind;
  title: string;
  subtitle: string;
  at: string;
  complaint_id: number;
};

function trunc(s: string | null | undefined, max: number): string {
  if (!s) return '';
  const t = s.trim();
  if (t.length <= max) return t;
  return `${t.slice(0, max - 1)}…`;
}

export function mergeRecentActivity(
  created: ComplaintResolutionFields[],
  resolved: ComplaintResolutionFields[],
  submitted: ComplaintResolutionFields[],
): ActivityRow[] {
  const rows: ActivityRow[] = [];

  for (const c of created) {
    const typeLabel = c.complaint_type?.trim() || 'Complaint';
    rows.push({
      kind: 'new_complaint',
      title: 'New complaint registered',
      subtitle: `#${c.id} · ${typeLabel}${c.description ? ` · ${trunc(c.description, 80)}` : ''}`,
      at: c.created_at.toISOString(),
      complaint_id: c.id,
    });
  }

  for (const c of resolved) {
    if (!c.resolved_at) continue;
    const typeLabel = c.complaint_type?.trim() || 'Complaint';
    rows.push({
      kind: 'resolved',
      title: 'Complaint resolved',
      subtitle: `#${c.id} · ${typeLabel}`,
      at: c.resolved_at.toISOString(),
      complaint_id: c.id,
    });
  }

  for (const c of submitted) {
    if (!c.resolution_image_captured_at) continue;
    const typeLabel = c.complaint_type?.trim() || 'Complaint';
    rows.push({
      kind: 'resolution_submitted',
      title: 'Resolution submitted',
      subtitle: `#${c.id} · ${typeLabel} (awaiting confirmation)`,
      at: c.resolution_image_captured_at.toISOString(),
      complaint_id: c.id,
    });
  }

  rows.sort((a, b) => new Date(b.at).getTime() - new Date(a.at).getTime());

  const seen = new Set<number>();
  const out: ActivityRow[] = [];
  for (const r of rows) {
    if (seen.has(r.complaint_id)) continue;
    seen.add(r.complaint_id);
    out.push(r);
    if (out.length >= 10) break;
  }
  return out;
}
