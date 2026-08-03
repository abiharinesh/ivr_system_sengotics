import {
  computePermitFees,
  FEE_RATES,
  HIGH_RISE_SURCHARGE_PCT,
  MIN_SCRUTINY_FEE,
  WORK_NATURE_MULTIPLIER,
} from './building-permit.fees';

describe('computePermitFees', () => {
  it('charges each component at the rate for the construction type', () => {
    const fees = computePermitFees({
      construction_type: 'residential',
      built_up_area_sqm: 200,
      plot_area_sqm: 300,
      floors_proposed: 2,
    });

    // 200 × 10 = 2000 scrutiny, 200 × 30 = 6000 permit, 300 × 15 = 4500 development
    expect(fees.scrutiny_fee).toBe(2000);
    expect(fees.permit_fee).toBe(6000);
    expect(fees.development_fee).toBe(4500);
    expect(fees.total_fee).toBe(12500);
  });

  it('applies the minimum scrutiny fee to very small proposals', () => {
    const fees = computePermitFees({
      construction_type: 'residential',
      built_up_area_sqm: 10, // 10 × 10 = 100, below the floor
      plot_area_sqm: 20,
    });

    expect(fees.scrutiny_fee).toBe(MIN_SCRUTINY_FEE);
  });

  it('charges commercial proposals more than residential ones of the same size', () => {
    const input = { built_up_area_sqm: 500, plot_area_sqm: 800, floors_proposed: 2 };
    const residential = computePermitFees({ ...input, construction_type: 'residential' });
    const commercial = computePermitFees({ ...input, construction_type: 'commercial' });

    expect(commercial.total_fee).toBeGreaterThan(residential.total_fee);
  });

  it('surcharges the permit fee once the proposal goes high-rise', () => {
    const base = {
      construction_type: 'residential',
      built_up_area_sqm: 400,
      plot_area_sqm: 400,
    };
    const threeFloors = computePermitFees({ ...base, floors_proposed: 3 });
    const fourFloors = computePermitFees({ ...base, floors_proposed: 4 });

    expect(fourFloors.permit_fee).toBe(
      Math.round(threeFloors.permit_fee * (1 + HIGH_RISE_SURCHARGE_PCT / 100)),
    );
    // The surcharge is on the permit fee only — development charge is unchanged.
    expect(fourFloors.development_fee).toBe(threeFloors.development_fee);
  });

  it('discounts alterations relative to new construction', () => {
    const base = {
      construction_type: 'commercial',
      built_up_area_sqm: 250,
      plot_area_sqm: 400,
      floors_proposed: 2,
    };
    const fresh = computePermitFees({ ...base, work_nature: 'new' });
    const alteration = computePermitFees({ ...base, work_nature: 'alteration' });

    expect(alteration.permit_fee).toBe(
      Math.round(fresh.permit_fee * WORK_NATURE_MULTIPLIER.alteration),
    );
  });

  it('falls back to residential rates for an unrecognised construction type', () => {
    const fees = computePermitFees({
      construction_type: 'not_a_real_type',
      built_up_area_sqm: 100,
      plot_area_sqm: 100,
    });

    expect(fees.permit_fee).toBe(100 * FEE_RATES.residential.permit_per_sqm);
  });

  it('does not produce negative fees from junk input', () => {
    const fees = computePermitFees({
      construction_type: 'residential',
      built_up_area_sqm: -50,
      plot_area_sqm: -50,
      floors_proposed: -2,
    });

    expect(fees.permit_fee).toBe(0);
    expect(fees.development_fee).toBe(0);
    expect(fees.scrutiny_fee).toBe(MIN_SCRUTINY_FEE);
  });
});
