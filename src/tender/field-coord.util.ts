const COORD_NUMBER = '([+-]?\\d+(?:\\.\\d+)?)';

/** Parse Lat/Long from GPS Map Camera overlay text. */
export function parseLatLongFromText(text: string): {
  lat: number | null;
  lng: number | null;
} {
  const normalized = text
    .replace(/°/g, ' ')
    .replace(/[\u2018\u2019\u201C\u201D]/g, "'");

  const patterns = [
    new RegExp(`Lat\\s*${COORD_NUMBER}\\s*[,\\s]*Long\\s*${COORD_NUMBER}`, 'i'),
    new RegExp(
      `latitude[:\\s]+${COORD_NUMBER}.*longitude[:\\s]+${COORD_NUMBER}`,
      'is',
    ),
    // OCR sometimes merges tokens: "Lat11.186253 Long 76.857767"
    new RegExp(`Lat${COORD_NUMBER}\\s*Long\\s*${COORD_NUMBER}`, 'i'),
  ];
  for (const re of patterns) {
    const m = normalized.match(re);
    if (m) {
      const lat = parseFloat(m[1]);
      const lng = parseFloat(m[2]);
      if (Number.isFinite(lat) && Number.isFinite(lng)) return { lat, lng };
    }
  }

  const latOnly = normalized.match(new RegExp(`Lat\\s*${COORD_NUMBER}`, 'i'));
  const lngOnly = normalized.match(new RegExp(`Long\\s*${COORD_NUMBER}`, 'i'));
  if (latOnly && lngOnly) {
    const lat = parseFloat(latOnly[1]);
    const lng = parseFloat(lngOnly[1]);
    if (Number.isFinite(lat) && Number.isFinite(lng)) return { lat, lng };
  }

  return { lat: null, lng: null };
}

export type CoordSource =
  | 'exif'
  | 'ocr_overlay'
  | 'exif_and_ocr'
  | 'manual'
  | null;

export function fuseCoordinates(args: {
  exifLat: number | null;
  exifLng: number | null;
  ocrLat: number | null;
  ocrLng: number | null;
  manualPoleId?: number | null;
}): { lat: number | null; lng: number | null; coordSource: CoordSource } {
  if (args.manualPoleId) {
    return {
      lat: args.exifLat ?? args.ocrLat,
      lng: args.exifLng ?? args.ocrLng,
      coordSource: 'manual',
    };
  }

  const hasExif = args.exifLat != null && args.exifLng != null;
  const hasOcr = args.ocrLat != null && args.ocrLng != null;

  if (hasExif && hasOcr) {
    const drift = haversineM(
      args.exifLat!,
      args.exifLng!,
      args.ocrLat!,
      args.ocrLng!,
    );
    if (drift <= 50) {
      return {
        lat: args.exifLat,
        lng: args.exifLng,
        coordSource: 'exif_and_ocr',
      };
    }
    return { lat: args.ocrLat, lng: args.ocrLng, coordSource: 'ocr_overlay' };
  }
  if (hasExif)
    return { lat: args.exifLat, lng: args.exifLng, coordSource: 'exif' };
  if (hasOcr)
    return { lat: args.ocrLat, lng: args.ocrLng, coordSource: 'ocr_overlay' };
  return { lat: null, lng: null, coordSource: null };
}

function haversineM(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number,
): number {
  const R = 6371000;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

export function normalizePoleToken(value: string): string {
  return value
    .trim()
    .toUpperCase()
    .replace(/^POLE\s*/i, '')
    .replace(/^P[-#]?\s*/i, '')
    .replace(/\s+/g, '');
}

export function matchPoleFromOcrText(
  text: string,
  candidates: Array<{
    id: number;
    pole_number: string | null;
    keypad_id: string | null;
  }>,
): {
  poleId: number | null;
  poleNumber: string | null;
  keypadId: string | null;
  confidence: 'single' | 'ambiguous' | 'unmatched' | 'skipped';
} {
  if (!text.trim() || candidates.length === 0) {
    return {
      poleId: null,
      poleNumber: null,
      keypadId: null,
      confidence: 'skipped',
    };
  }

  const upper = text.toUpperCase();
  const matches: number[] = [];

  for (const p of candidates) {
    if (p.keypad_id && upper.includes(p.keypad_id.toUpperCase())) {
      matches.push(p.id);
      continue;
    }
    if (p.pole_number) {
      const norm = normalizePoleToken(p.pole_number);
      if (norm && upper.includes(norm)) matches.push(p.id);
    }
  }

  const unique = Array.from(new Set(matches));
  if (unique.length === 1) {
    const pole = candidates.find((c) => c.id === unique[0])!;
    return {
      poleId: pole.id,
      poleNumber: pole.pole_number,
      keypadId: pole.keypad_id,
      confidence: 'single',
    };
  }
  if (unique.length > 1) {
    return {
      poleId: null,
      poleNumber: null,
      keypadId: null,
      confidence: 'ambiguous',
    };
  }
  return {
    poleId: null,
    poleNumber: null,
    keypadId: null,
    confidence: 'unmatched',
  };
}
