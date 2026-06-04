import { BadRequestException } from '@nestjs/common';

/**
 * Single source of truth for complaint workflow states (IVR + field ops).
 * Existing IVR statuses remain valid; field-assignment flow adds assigned → … → resolved.
 */
export const COMPLAINT_STATUSES = [
  'pending',
  'in_progress',
  'resolved',
  'manual_review',
  'rejected',
  'assigned',
  'resolved_pending_confirmation',
  'reassign_required',
] as const;

export type ComplaintStatus = (typeof COMPLAINT_STATUSES)[number];

export function validateComplaintStatus(status: string): ComplaintStatus {
  if (!COMPLAINT_STATUSES.includes(status as ComplaintStatus)) {
    throw new BadRequestException(
      `Invalid status "${status}". Must be one of: ${COMPLAINT_STATUSES.join(', ')}`,
    );
  }
  return status as ComplaintStatus;
}

export function isValidComplaintStatus(
  status: string,
): status is ComplaintStatus {
  return COMPLAINT_STATUSES.includes(status as ComplaintStatus);
}
