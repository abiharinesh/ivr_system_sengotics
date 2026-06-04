import { BadRequestException } from '@nestjs/common';
import { DOCUMENT_TEMPLATE_IDS, DocumentTemplateId } from '../tender-status';
import { sanitizeTemplateDefaults } from './overlay-sanitize';

export const DOCUMENT_TEMPLATE_DEFAULTS_KEY = 'document_template_defaults';

export type TextAlign = 'left' | 'center' | 'right' | 'justify';
export type SignatureAlign = TextAlign | 'space-between';

export interface TemplateLayoutConfig {
  page?: { paddingPx?: number; maxWidthPx?: number };
  header?: { align?: TextAlign };
  body?: { align?: TextAlign };
  table?: {
    headerAlign?: TextAlign;
    bodyAlign?: TextAlign;
    numberAlign?: 'left' | 'right';
  };
  signatures?: { align?: SignatureAlign };
  typography?: { baseFontPt?: number; titleFontPt?: number };
  branding?: {
    showGeneratedFooter?: boolean;
    customFooterTextTa?: string;
    customFooterTextEn?: string;
  };
  defaults?: Record<string, unknown>;
}

export type TemplateSettingsMap = Partial<
  Record<DocumentTemplateId, TemplateLayoutConfig>
>;

const BUILTIN_DEFAULT: TemplateLayoutConfig = {
  page: { paddingPx: 24, maxWidthPx: 720 },
  header: { align: 'center' },
  body: { align: 'left' },
  table: { headerAlign: 'left', bodyAlign: 'left', numberAlign: 'right' },
  signatures: { align: 'center' },
  typography: { baseFontPt: 10, titleFontPt: 18 },
  branding: { showGeneratedFooter: true },
};

export function builtinDefaultFor(
  templateId: DocumentTemplateId,
): TemplateLayoutConfig {
  return deepMergeConfig(BUILTIN_DEFAULT, {});
}

export function builtinDefaultsMap(): Record<
  DocumentTemplateId,
  TemplateLayoutConfig
> {
  const out = {} as Record<DocumentTemplateId, TemplateLayoutConfig>;
  for (const id of DOCUMENT_TEMPLATE_IDS) {
    out[id] = builtinDefaultFor(id);
  }
  return out;
}

function isPlainObject(v: unknown): v is Record<string, unknown> {
  return v != null && typeof v === 'object' && !Array.isArray(v);
}

export function deepMergeConfig(
  ...parts: (TemplateLayoutConfig | null | undefined)[]
): TemplateLayoutConfig {
  const result: TemplateLayoutConfig = {};
  for (const part of parts) {
    if (!part || !isPlainObject(part)) continue;
    for (const [key, value] of Object.entries(part)) {
      if (key === 'defaults' && isPlainObject(value)) {
        result.defaults = { ...(result.defaults ?? {}), ...value };
        continue;
      }
      if (
        isPlainObject(value) &&
        isPlainObject((result as Record<string, unknown>)[key])
      ) {
        (result as Record<string, unknown>)[key] = {
          ...((result as Record<string, unknown>)[key] as object),
          ...value,
        };
      } else if (value !== undefined) {
        (result as Record<string, unknown>)[key] = value;
      }
    }
  }
  return result;
}

export function mergeFieldOverrides(
  ...parts: (Record<string, unknown> | null | undefined)[]
): Record<string, unknown> {
  const result: Record<string, unknown> = {};
  for (const part of parts) {
    if (!part || !isPlainObject(part)) continue;
    for (const [k, v] of Object.entries(part)) {
      if (
        k === '__canvas_layers' &&
        Array.isArray(v) &&
        Array.isArray(result.__canvas_layers)
      ) {
        result.__canvas_layers = v;
      } else if (k === 'fabric_scene' && v && typeof v === 'object') {
        result.fabric_scene = v;
      } else if (k === 'overlay_svg' && typeof v === 'string') {
        result.overlay_svg = v;
      } else {
        result[k] = v;
      }
    }
  }
  return result;
}

function clampInt(
  n: unknown,
  min: number,
  max: number,
  fallback: number,
): number {
  const x = typeof n === 'number' ? n : Number(n);
  if (!Number.isFinite(x)) return fallback;
  return Math.min(max, Math.max(min, Math.round(x)));
}

const ALIGNMENTS: TextAlign[] = ['left', 'center', 'right', 'justify'];
const SIG_ALIGNMENTS: SignatureAlign[] = [
  'left',
  'center',
  'right',
  'justify',
  'space-between',
];

function parseAlign(
  v: unknown,
  allowed: readonly string[],
  fallback: string,
): string {
  const s = String(v ?? fallback)
    .trim()
    .toLowerCase();
  return allowed.includes(s) ? s : fallback;
}

export function sanitizeTemplateConfig(input: unknown): TemplateLayoutConfig {
  if (!isPlainObject(input)) return {};
  const out: TemplateLayoutConfig = {};
  if (isPlainObject(input.page)) {
    out.page = {
      paddingPx: clampInt(input.page.paddingPx, 0, 80, 24),
      maxWidthPx: clampInt(input.page.maxWidthPx, 400, 1200, 720),
    };
  }
  if (isPlainObject(input.header)) {
    out.header = {
      align: parseAlign(input.header.align, ALIGNMENTS, 'center') as TextAlign,
    };
  }
  if (isPlainObject(input.body)) {
    out.body = {
      align: parseAlign(input.body.align, ALIGNMENTS, 'left') as TextAlign,
    };
  }
  if (isPlainObject(input.table)) {
    out.table = {
      headerAlign: parseAlign(
        input.table.headerAlign,
        ALIGNMENTS,
        'left',
      ) as TextAlign,
      bodyAlign: parseAlign(
        input.table.bodyAlign,
        ALIGNMENTS,
        'left',
      ) as TextAlign,
      numberAlign: input.table.numberAlign === 'left' ? 'left' : 'right',
    };
  }
  if (isPlainObject(input.signatures)) {
    out.signatures = {
      align: parseAlign(
        input.signatures.align,
        SIG_ALIGNMENTS,
        'center',
      ) as SignatureAlign,
    };
  }
  if (isPlainObject(input.typography)) {
    out.typography = {
      baseFontPt: clampInt(input.typography.baseFontPt, 8, 16, 10),
      titleFontPt: clampInt(input.typography.titleFontPt, 12, 28, 18),
    };
  }
  if (isPlainObject(input.branding)) {
    out.branding = {
      showGeneratedFooter: input.branding.showGeneratedFooter !== false,
      customFooterTextTa:
        input.branding.customFooterTextTa != null
          ? String(input.branding.customFooterTextTa).slice(0, 500)
          : undefined,
      customFooterTextEn:
        input.branding.customFooterTextEn != null
          ? String(input.branding.customFooterTextEn).slice(0, 500)
          : undefined,
    };
  }
  const defaults = sanitizeTemplateDefaults(input.defaults);
  if (defaults) out.defaults = defaults;
  return out;
}

export function sanitizeSettingsMap(input: unknown): TemplateSettingsMap {
  if (!isPlainObject(input)) {
    throw new BadRequestException(
      'templates must be an object keyed by template id',
    );
  }
  const out: TemplateSettingsMap = {};
  for (const [key, value] of Object.entries(input)) {
    if (!DOCUMENT_TEMPLATE_IDS.includes(key as DocumentTemplateId)) {
      throw new BadRequestException(
        `Unknown template id "${key}". Must be one of: ${DOCUMENT_TEMPLATE_IDS.join(', ')}`,
      );
    }
    out[key as DocumentTemplateId] = sanitizeTemplateConfig(value);
  }
  return out;
}

export function parseSettingsJson(
  raw: string | null | undefined,
): TemplateSettingsMap {
  if (!raw || !raw.trim()) return {};
  try {
    const parsed = JSON.parse(raw) as unknown;
    return sanitizeSettingsMap(parsed);
  } catch (e: any) {
    if (e instanceof BadRequestException) throw e;
    throw new BadRequestException('Invalid document template settings JSON');
  }
}

export function parsePanchayatSettingsJson(raw: unknown): TemplateSettingsMap {
  if (raw == null) return {};
  if (typeof raw === 'string') return parseSettingsJson(raw);
  return sanitizeSettingsMap(raw);
}

export function getMergedLayout(
  templateId: DocumentTemplateId,
  globalMap: TemplateSettingsMap,
  panchayatMap: TemplateSettingsMap,
): TemplateLayoutConfig {
  return deepMergeConfig(
    builtinDefaultFor(templateId),
    globalMap[templateId],
    panchayatMap[templateId],
  );
}

export function layoutStyleBlock(layout: TemplateLayoutConfig): string {
  const page = layout.page ?? BUILTIN_DEFAULT.page!;
  const header = layout.header ?? BUILTIN_DEFAULT.header!;
  const body = layout.body ?? BUILTIN_DEFAULT.body!;
  const table = layout.table ?? BUILTIN_DEFAULT.table!;
  const sig = layout.signatures ?? BUILTIN_DEFAULT.signatures!;
  const typo = layout.typography ?? BUILTIN_DEFAULT.typography!;
  const padY = page.paddingPx ?? 24;
  const padX = Math.round((page.paddingPx ?? 24) * 1.17);
  const maxW = page.maxWidthPx ?? 720;
  const sigAlign =
    sig.align === 'space-between' ? 'space-between' : (sig.align ?? 'center');
  const sigTextAlign =
    sig.align === 'space-between' ? 'center' : (sig.align ?? 'center');
  return `
  :root {
    --page-padding-y: ${padY}px;
    --page-padding-x: ${padX}px;
    --page-max-width: ${maxW}px;
    --header-align: ${header.align ?? 'center'};
    --body-align: ${body.align ?? 'left'};
    --table-header-align: ${table.headerAlign ?? 'left'};
    --table-body-align: ${table.bodyAlign ?? 'left'};
    --table-number-align: ${table.numberAlign ?? 'right'};
    --sig-justify: ${sigAlign};
    --sig-text-align: ${sigTextAlign};
    --base-font-pt: ${typo.baseFontPt ?? 10}pt;
    --title-font-pt: ${typo.titleFontPt ?? 18}pt;
  }
  body { font-size: var(--base-font-pt); }
  .page { padding: var(--page-padding-y) var(--page-padding-x); max-width: var(--page-max-width); }
  .doc-body { text-align: var(--body-align); }
  h1 { font-size: var(--title-font-pt); text-align: var(--header-align); }
  h2, h3 { text-align: var(--header-align); }
  .header-block { text-align: var(--header-align); }
  table th { text-align: var(--table-header-align); }
  table td { text-align: var(--table-body-align); }
  td.amount { text-align: var(--table-number-align) !important; }
  .footer { justify-content: var(--sig-justify); }
  .footer .sig { text-align: var(--sig-text-align); }
`;
}

export const TEMPLATE_LABELS: Record<
  DocumentTemplateId,
  { ta: string; en: string }
> = {
  rfq: { ta: 'விலைப்புள்ளி கோருதல்', en: 'RFQ' },
  quotation: { ta: 'கொட்டேஷன்', en: 'Quotation' },
  comparative: { ta: 'ஒப்பு நோக்கு பட்டியல்', en: 'Comparative' },
  work_order: { ta: 'வேலை உத்தரவு', en: 'Work Order' },
  so_proceedings: { ta: 'நடவடிக்கைகள்', en: 'SO Proceedings' },
  form19: { ta: 'படிவம் 19', en: 'Form 19' },
};
