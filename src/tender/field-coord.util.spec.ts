import {
  parseLatLongFromText,
  fuseCoordinates,
  matchPoleFromOcrText,
} from './field-coord.util';

describe('field-coord.util', () => {
  it('parses GPS Map Camera Lat/Long line', () => {
    const text =
      'Coimbatore\nLat 11.210516, Long 76.870462\nTuesday 26/05/2026';
    const { lat, lng } = parseLatLongFromText(text);
    expect(lat).toBeCloseTo(11.210516);
    expect(lng).toBeCloseTo(76.870462);
  });

  it('parses GPS Map Camera overlay with degree symbols and no comma', () => {
    const text =
      'Coimbatore, Tamil Nadu\nLat11.186253° Long 76.857767°\nTuesday, 26/05/2026';
    const { lat, lng } = parseLatLongFromText(text);
    expect(lat).toBeCloseTo(11.186253);
    expect(lng).toBeCloseTo(76.857767);
  });

  it('parses real OCR output from field upload', () => {
    const text =
      'GPS Map camera\nCoimbatore, Tamil Nadu, India\nLat11.186253° Long 76.857767°\nTuesday, 26/05/2026 04:49 PM';
    const { lat, lng } = parseLatLongFromText(text);
    expect(lat).toBeCloseTo(11.186253);
    expect(lng).toBeCloseTo(76.857767);
  });

  it('prefers OCR overlay when EXIF missing', () => {
    const fused = fuseCoordinates({
      exifLat: null,
      exifLng: null,
      ocrLat: 11.21,
      ocrLng: 76.87,
    });
    expect(fused.coordSource).toBe('ocr_overlay');
    expect(fused.lat).toBe(11.21);
  });

  it('matches pole number from OCR text', () => {
    const result = matchPoleFromOcrText('Pole P-47 installed', [
      { id: 1, pole_number: 'P-47', keypad_id: null },
      { id: 2, pole_number: 'P-48', keypad_id: null },
    ]);
    expect(result.confidence).toBe('single');
    expect(result.poleId).toBe(1);
  });
});
