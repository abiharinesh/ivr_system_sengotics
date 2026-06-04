import { BadRequestException } from '@nestjs/common';

/** Tender lifecycle states (spec §4). */
export const TENDER_STATUSES = [
  'draft',
  'published',
  'quotations_closed',
  'vendor_selected',
  'field_verification',
  'closed',
] as const;

export type TenderStatus = (typeof TENDER_STATUSES)[number];

const TRANSITIONS: Record<TenderStatus, TenderStatus[]> = {
  draft: ['published'],
  published: ['quotations_closed', 'draft'],
  quotations_closed: ['vendor_selected', 'published'],
  vendor_selected: ['field_verification'],
  field_verification: ['closed', 'field_verification'],
  closed: [],
};

export function assertTransition(from: string, to: TenderStatus): void {
  if (!TENDER_STATUSES.includes(from as TenderStatus)) {
    throw new BadRequestException(`Unknown tender status "${from}"`);
  }
  const allowed = TRANSITIONS[from as TenderStatus];
  if (!allowed.includes(to)) {
    throw new BadRequestException(
      `Cannot move tender from "${from}" to "${to}"`,
    );
  }
}

export const QUOTATION_ACCESS_MODES = [
  'invited_only',
  'open_with_phone',
] as const;
export type QuotationAccessMode = (typeof QUOTATION_ACCESS_MODES)[number];

export function validateAccessMode(mode: string): QuotationAccessMode {
  if (!QUOTATION_ACCESS_MODES.includes(mode as QuotationAccessMode)) {
    throw new BadRequestException(
      `quotation_access_mode must be one of: ${QUOTATION_ACCESS_MODES.join(', ')}`,
    );
  }
  return mode as QuotationAccessMode;
}

export const DOCUMENT_TEMPLATE_IDS = [
  'rfq',
  'quotation',
  'comparative',
  'work_order',
  'so_proceedings',
  'form19',
] as const;
export type DocumentTemplateId = (typeof DOCUMENT_TEMPLATE_IDS)[number];

export function validateTemplateId(id: string): DocumentTemplateId {
  if (!DOCUMENT_TEMPLATE_IDS.includes(id as DocumentTemplateId)) {
    throw new BadRequestException(
      `template id must be one of: ${DOCUMENT_TEMPLATE_IDS.join(', ')}`,
    );
  }
  return id as DocumentTemplateId;
}
