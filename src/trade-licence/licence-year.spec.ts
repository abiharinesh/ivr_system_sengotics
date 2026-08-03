import {
  assessRenewal,
  CATEGORY_RATES,
  computeLicenceFee,
  daysBetween,
  financialYearEnd,
  financialYearOf,
  financialYearStart,
  LATE_GRACE_DAYS,
  LATE_SECOND_BAND_DAYS,
  nextFinancialYear,
  PENALTY_PCT,
  quartersRemaining,
  requiresAnnualInspection,
} from './licence-year';

const utc = (iso: string) => new Date(`${iso}T00:00:00.000Z`);

describe('financial year helpers', () => {
  it('puts April onwards in the year that starts then', () => {
    expect(financialYearOf(utc('2026-04-01'))).toBe('2026-27');
    expect(financialYearOf(utc('2026-08-02'))).toBe('2026-27');
    expect(financialYearOf(utc('2026-12-31'))).toBe('2026-27');
  });

  it('puts January to March in the year that started the previous April', () => {
    expect(financialYearOf(utc('2027-01-15'))).toBe('2026-27');
    expect(financialYearOf(utc('2027-03-31'))).toBe('2026-27');
  });

  it('rolls over on 1 April', () => {
    expect(financialYearOf(utc('2027-03-31'))).toBe('2026-27');
    expect(financialYearOf(utc('2027-04-01'))).toBe('2027-28');
  });

  it('bounds the year at 1 April and 31 March', () => {
    expect(financialYearStart('2026-27').toISOString().slice(0, 10)).toBe(
      '2026-04-01',
    );
    expect(financialYearEnd('2026-27').toISOString().slice(0, 10)).toBe(
      '2027-03-31',
    );
  });

  it('advances to the next year label', () => {
    expect(nextFinancialYear('2026-27')).toBe('2027-28');
    expect(nextFinancialYear('2029-30')).toBe('2030-31');
  });
});

describe('quartersRemaining', () => {
  it('gives a full year to a licence granted on 1 April', () => {
    expect(quartersRemaining(utc('2026-04-01'), '2026-27')).toBe(4);
  });

  it('drops a quarter per elapsed quarter', () => {
    expect(quartersRemaining(utc('2026-05-15'), '2026-27')).toBe(4); // Q1
    expect(quartersRemaining(utc('2026-08-02'), '2026-27')).toBe(3); // Q2
    expect(quartersRemaining(utc('2026-11-20'), '2026-27')).toBe(2); // Q3
    expect(quartersRemaining(utc('2027-02-10'), '2026-27')).toBe(1); // Q4
  });

  it('never charges less than one quarter inside the year', () => {
    expect(quartersRemaining(utc('2027-03-31'), '2026-27')).toBe(1);
  });

  it('returns zero past the year end', () => {
    expect(quartersRemaining(utc('2027-04-02'), '2026-27')).toBe(0);
  });
});

describe('daysBetween', () => {
  it('ignores the time of day', () => {
    expect(
      daysBetween(
        new Date('2027-03-31T23:00:00.000Z'),
        new Date('2027-04-01T01:00:00.000Z'),
      ),
    ).toBe(1);
  });
});

describe('assessRenewal', () => {
  const expiry = utc('2027-03-31');

  it('treats a renewal before expiry as on time', () => {
    const a = assessRenewal(expiry, utc('2027-03-15'));
    expect(a.band).toBe('ontime');
    expect(a.daysLate).toBe(0);
    expect(a.requiresFreshApplication).toBe(false);
  });

  it('treats renewal on the expiry date itself as on time', () => {
    expect(assessRenewal(expiry, expiry).band).toBe('ontime');
  });

  it('enters the first late band the day after expiry', () => {
    const a = assessRenewal(expiry, utc('2027-04-01'));
    expect(a.daysLate).toBe(1);
    expect(a.band).toBe('late_30');
    expect(a.penaltyPct).toBe(PENALTY_PCT.late_30);
  });

  it('stays in the first band through the grace window', () => {
    const a = assessRenewal(
      expiry,
      new Date(expiry.getTime() + LATE_GRACE_DAYS * 86_400_000),
    );
    expect(a.daysLate).toBe(LATE_GRACE_DAYS);
    expect(a.band).toBe('late_30');
  });

  it('escalates past the grace window', () => {
    const a = assessRenewal(
      expiry,
      new Date(expiry.getTime() + (LATE_GRACE_DAYS + 1) * 86_400_000),
    );
    expect(a.band).toBe('late_90');
  });

  it('is still renewable at exactly ninety days', () => {
    const a = assessRenewal(
      expiry,
      new Date(expiry.getTime() + LATE_SECOND_BAND_DAYS * 86_400_000),
    );
    expect(a.band).toBe('late_90');
    expect(a.requiresFreshApplication).toBe(false);
  });

  it('lapses beyond ninety days and demands a fresh application', () => {
    const a = assessRenewal(
      expiry,
      new Date(expiry.getTime() + (LATE_SECOND_BAND_DAYS + 1) * 86_400_000),
    );
    expect(a.band).toBe('lapsed');
    expect(a.requiresFreshApplication).toBe(true);
    expect(a.reason).toMatch(/fresh application/i);
  });
});

describe('computeLicenceFee', () => {
  it('sums base, area and motive power at the category rate', () => {
    const f = computeLicenceFee({
      trade_category: 'eatery',
      area_sqft: 500,
      motive_power_hp: 3,
    });

    // base 2000 + 500×4 = 2000 + 3×100 = 300
    expect(f.base_fee).toBe(2000);
    expect(f.area_fee).toBe(2000);
    expect(f.power_fee).toBe(300);
    expect(f.total_fee).toBe(4300);
  });

  it('pro-rates a first grant by remaining quarters', () => {
    const full = computeLicenceFee({
      trade_category: 'eatery',
      area_sqft: 500,
      motive_power_hp: 3,
      quarters: 4,
    });
    const quarter = computeLicenceFee({
      trade_category: 'eatery',
      area_sqft: 500,
      motive_power_hp: 3,
      quarters: 1,
    });

    expect(quarter.total_fee).toBe(Math.round(full.total_fee / 4));
    expect(quarter.quarters).toBe(1);
  });

  it('charges the penalty on the annual components only', () => {
    const f = computeLicenceFee({
      trade_category: 'provision_store',
      area_sqft: 200,
      quarters: 4,
      penaltyPct: 25,
    });

    const annual = f.base_fee + f.area_fee + f.power_fee;
    expect(f.penalty_fee).toBe(Math.round(annual * 0.25));
    expect(f.total_fee).toBe(annual + f.penalty_fee);
  });

  it('does not penalise a part year the trader was never billed for', () => {
    const f = computeLicenceFee({
      trade_category: 'eatery',
      area_sqft: 400,
      quarters: 2,
      penaltyPct: 50,
    });

    const annual = f.base_fee + f.area_fee + f.power_fee;
    // The penalty follows the pro-rated figure, not the notional full year.
    expect(f.penalty_fee).toBe(Math.round(annual * 0.5));
  });

  it('treats a trade with no motive power as zero, not missing', () => {
    const f = computeLicenceFee({
      trade_category: 'provision_store',
      area_sqft: 300,
      motive_power_hp: null,
    });
    expect(f.power_fee).toBe(0);
  });

  it('falls back to the "other" rate for an unrecognised category', () => {
    const f = computeLicenceFee({
      trade_category: 'not_a_real_trade',
      area_sqft: 100,
    });
    expect(f.base_fee).toBe(CATEGORY_RATES.other.base);
  });

  it('clamps quarters into 1–4', () => {
    expect(computeLicenceFee({ trade_category: 'eatery', area_sqft: 100, quarters: 9 }).quarters)
      .toBe(4);
    expect(computeLicenceFee({ trade_category: 'eatery', area_sqft: 100, quarters: 0 }).quarters)
      .toBe(1);
  });

  it('never produces negative fees from junk input', () => {
    const f = computeLicenceFee({
      trade_category: 'eatery',
      area_sqft: -500,
      motive_power_hp: -10,
    });
    expect(f.area_fee).toBe(0);
    expect(f.power_fee).toBe(0);
    expect(f.total_fee).toBeGreaterThanOrEqual(0);
  });
});

describe('requiresAnnualInspection', () => {
  it('flags food and hazardous trades', () => {
    expect(requiresAnnualInspection('eatery')).toBe(true);
    expect(requiresAnnualInspection('clinic')).toBe(true);
    expect(requiresAnnualInspection('timber_depot')).toBe(true);
  });

  it('does not flag low-risk retail', () => {
    expect(requiresAnnualInspection('provision_store')).toBe(false);
    expect(requiresAnnualInspection('godown')).toBe(false);
  });

  it('falls back to the default rate for an unknown category', () => {
    expect(requiresAnnualInspection('not_a_real_trade')).toBe(
      CATEGORY_RATES.other.annual_inspection,
    );
  });
});
