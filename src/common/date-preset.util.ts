import { BadRequestException } from '@nestjs/common';

export const DATE_PRESETS = [
  'THIS_MONTH',
  'LAST_3_MONTHS',
  'LAST_6_MONTHS',
  'LAST_12_MONTHS',
  'CUSTOM',
] as const;
export type DatePresetId = (typeof DATE_PRESETS)[number];

function startOfMonth(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), 1, 0, 0, 0, 0);
}

function endOfDay(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate(), 23, 59, 59, 999);
}

/** UTC-safe wall-clock presets in server local TZ (sufficient for admin reports). */
export function resolveDateRange(
  preset: string,
  customFrom?: string,
  customTo?: string,
): { from: Date; to: Date } {
  if (!DATE_PRESETS.includes(preset as DatePresetId)) {
    throw new BadRequestException(
      `preset must be one of: ${DATE_PRESETS.join(', ')}`,
    );
  }
  const now = new Date();

  if (preset === 'CUSTOM') {
    if (!customFrom || !customTo) {
      throw new BadRequestException(
        'CUSTOM preset requires date_from and date_to (ISO 8601)',
      );
    }
    const from = new Date(customFrom);
    const to = new Date(customTo);
    if (Number.isNaN(from.getTime()) || Number.isNaN(to.getTime())) {
      throw new BadRequestException('Invalid date_from or date_to');
    }
    return {
      from: new Date(
        from.getFullYear(),
        from.getMonth(),
        from.getDate(),
        0,
        0,
        0,
        0,
      ),
      to: endOfDay(to),
    };
  }

  const to = endOfDay(now);

  if (preset === 'THIS_MONTH') {
    return { from: startOfMonth(now), to };
  }

  const monthsBack =
    preset === 'LAST_3_MONTHS' ? 3 : preset === 'LAST_6_MONTHS' ? 6 : 12;
  const from = new Date(
    now.getFullYear(),
    now.getMonth() - monthsBack,
    1,
    0,
    0,
    0,
    0,
  );
  return { from, to };
}
