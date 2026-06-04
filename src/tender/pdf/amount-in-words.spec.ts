import { rupeesInWordsEn, rupeesInWordsTa } from './amount-in-words';

describe('rupeesInWordsEn', () => {
  it('handles zero', () => {
    expect(rupeesInWordsEn(0)).toBe('Zero rupees only');
  });

  it('handles the Sundaramoorthy fixture amount', () => {
    // 6500 -> "Six thousand five hundred rupees only"
    expect(rupeesInWordsEn(6500).toLowerCase()).toContain(
      'six thousand five hundred',
    );
    expect(rupeesInWordsEn(6500).toLowerCase()).toContain('rupees only');
  });

  it('handles lakhs', () => {
    expect(rupeesInWordsEn(125000).toLowerCase()).toContain(
      'one lakh twenty-five thousand',
    );
  });

  it('handles crores', () => {
    expect(rupeesInWordsEn(15000000).toLowerCase()).toContain(
      'one crore fifty lakh',
    );
  });
});

describe('rupeesInWordsTa', () => {
  it('handles zero', () => {
    expect(rupeesInWordsTa(0)).toContain('ரூபாய்');
  });

  it('produces Tamil text containing numerals + currency word', () => {
    const w = rupeesInWordsTa(6500);
    expect(w).toContain('ஆறு');
    expect(w).toContain('ஆயிரம்');
    expect(w).toContain('ரூபாய்');
    expect(w).toContain('மட்டும்');
  });
});
