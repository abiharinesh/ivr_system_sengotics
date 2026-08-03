import {
  checkWeights,
  classifyFill,
  clampPct,
  clearanceUrgency,
  needsClearance,
  pinColour,
  routeProgress,
  WEIGHT_TOLERANCE_KG,
} from './bin-fill';

describe('clampPct', () => {
  it('holds a percentage inside 0–100', () => {
    expect(clampPct(-20)).toBe(0);
    expect(clampPct(140)).toBe(100);
    expect(clampPct(63)).toBe(63);
  });

  it('rounds fractional readings', () => {
    expect(clampPct(62.4)).toBe(62);
    expect(clampPct(62.6)).toBe(63);
  });

  it('treats junk as empty rather than throwing', () => {
    expect(clampPct(NaN)).toBe(0);
    expect(clampPct(Infinity)).toBe(0);
  });
});

describe('classifyFill', () => {
  it('places each band at its lower bound', () => {
    expect(classifyFill(0)).toBe('EMPTY');
    expect(classifyFill(10)).toBe('LOW');
    expect(classifyFill(40)).toBe('MEDIUM');
    expect(classifyFill(75)).toBe('HIGH');
    expect(classifyFill(100)).toBe('OVERFLOWING');
  });

  it('stays in the lower band one point below each boundary', () => {
    expect(classifyFill(9)).toBe('EMPTY');
    expect(classifyFill(39)).toBe('LOW');
    expect(classifyFill(74)).toBe('MEDIUM');
    expect(classifyFill(99)).toBe('HIGH');
  });

  it('clamps an over-100 reading to OVERFLOWING rather than falling through', () => {
    expect(classifyFill(250)).toBe('OVERFLOWING');
  });

  it('treats a negative reading as empty', () => {
    expect(classifyFill(-5)).toBe('EMPTY');
  });
});

describe('pinColour', () => {
  it('maps the five bands onto three map colours', () => {
    expect(pinColour('EMPTY')).toBe('green');
    expect(pinColour('LOW')).toBe('green');
    expect(pinColour('MEDIUM')).toBe('yellow');
    expect(pinColour('HIGH')).toBe('red');
    expect(pinColour('OVERFLOWING')).toBe('red');
  });

  it('turns red exactly where clearance becomes necessary', () => {
    for (const level of ['EMPTY', 'LOW', 'MEDIUM', 'HIGH', 'OVERFLOWING'] as const) {
      expect(pinColour(level) === 'red').toBe(needsClearance(level));
    }
  });
});

describe('needsClearance / clearanceUrgency', () => {
  it('only flags HIGH and OVERFLOWING', () => {
    expect(needsClearance('MEDIUM')).toBe(false);
    expect(needsClearance('HIGH')).toBe(true);
    expect(needsClearance('OVERFLOWING')).toBe(true);
  });

  it('separates an overflowing bin from a merely full one', () => {
    expect(clearanceUrgency('HIGH')).toBe('high');
    expect(clearanceUrgency('OVERFLOWING')).toBe('critical');
  });
});

describe('routeProgress', () => {
  it('reports a partly-driven round', () => {
    const p = routeProgress(12, 20);
    expect(p.percent).toBe(60);
    expect(p.band).toBe('on_track');
  });

  it('calls a round complete only when every stop is settled', () => {
    expect(routeProgress(19, 20).band).toBe('on_track');
    expect(routeProgress(20, 20).band).toBe('complete');
  });

  it('marks an untouched round not started', () => {
    expect(routeProgress(0, 20).band).toBe('not_started');
  });

  it('flags a round below halfway as behind', () => {
    expect(routeProgress(9, 20).band).toBe('behind');
    expect(routeProgress(10, 20).band).toBe('on_track');
  });

  it('reports an empty route as 0%, never 100%', () => {
    const p = routeProgress(0, 0);
    expect(p.percent).toBe(0);
    expect(p.band).toBe('not_started');
  });

  it('cannot exceed the stop count', () => {
    const p = routeProgress(50, 20);
    expect(p.completed).toBe(20);
    expect(p.percent).toBe(100);
  });

  it('ignores negative input', () => {
    expect(routeProgress(-5, 20).completed).toBe(0);
    expect(routeProgress(5, -20).total).toBe(0);
  });
});

describe('checkWeights', () => {
  it('reconciles when wet and dry account for the total', () => {
    const w = checkWeights(1000, 600, 400)!;
    expect(w.unaccounted).toBe(0);
    expect(w.reconciles).toBe(true);
  });

  it('tolerates weighbridge rounding', () => {
    const w = checkWeights(1000, 600, 400 - WEIGHT_TOLERANCE_KG)!;
    expect(w.reconciles).toBe(true);
  });

  it('flags a segregation log that does not add up', () => {
    const w = checkWeights(1000, 300, 200)!;
    expect(w.unaccounted).toBe(500);
    expect(w.reconciles).toBe(false);
  });

  it('flags segregated weight exceeding the total', () => {
    const w = checkWeights(500, 400, 300)!;
    expect(w.unaccounted).toBe(-200);
    expect(w.reconciles).toBe(false);
  });

  it('returns null when there is nothing to reconcile', () => {
    expect(checkWeights(null, null, null)).toBeNull();
    expect(checkWeights(1000, null, null)).toBeNull();
  });

  it('works when only one fraction was weighed', () => {
    const w = checkWeights(1000, 1000, null)!;
    expect(w.reconciles).toBe(true);
  });
});
