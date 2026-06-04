import {
  assertTransition,
  validateAccessMode,
  validateTemplateId,
} from './tender-status';

describe('tender status machine', () => {
  it('allows draft -> published', () => {
    expect(() => assertTransition('draft', 'published')).not.toThrow();
  });

  it('forbids draft -> closed', () => {
    expect(() => assertTransition('draft', 'closed')).toThrow();
  });

  it('forbids unknown source state', () => {
    expect(() => assertTransition('unknown', 'draft' as any)).toThrow();
  });

  it('walks the canonical happy path', () => {
    expect(() => assertTransition('draft', 'published')).not.toThrow();
    expect(() =>
      assertTransition('published', 'quotations_closed'),
    ).not.toThrow();
    expect(() =>
      assertTransition('quotations_closed', 'vendor_selected'),
    ).not.toThrow();
    expect(() =>
      assertTransition('vendor_selected', 'field_verification'),
    ).not.toThrow();
    expect(() =>
      assertTransition('field_verification', 'closed'),
    ).not.toThrow();
  });
});

describe('validateAccessMode', () => {
  it('accepts both modes', () => {
    expect(validateAccessMode('invited_only')).toBe('invited_only');
    expect(validateAccessMode('open_with_phone')).toBe('open_with_phone');
  });

  it('rejects garbage', () => {
    expect(() => validateAccessMode('public')).toThrow();
  });
});

describe('validateTemplateId', () => {
  it('accepts the six known templates', () => {
    const ids = [
      'rfq',
      'quotation',
      'comparative',
      'work_order',
      'so_proceedings',
      'form19',
    ];
    for (const id of ids) {
      expect(validateTemplateId(id)).toBe(id);
    }
  });

  it('rejects unknown templates', () => {
    expect(() => validateTemplateId('invoice')).toThrow();
  });
});
