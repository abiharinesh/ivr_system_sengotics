import { Type } from 'class-transformer';
import {
  IsArray,
  IsBoolean,
  IsEmail,
  IsEnum,
  IsInt,
  IsISO8601,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

export const TRADE_CATEGORIES = [
  'eatery',
  'provision_store',
  'workshop',
  'godown',
  'clinic',
  'salon',
  'bakery',
  'laundry',
  'timber_depot',
  'other',
] as const;

export const OWNERSHIP_TYPES = [
  'PROPRIETOR',
  'PARTNERSHIP',
  'PRIVATE_LIMITED',
  'PUBLIC_LIMITED',
  'SOCIETY',
  'TRUST',
  'COOPERATIVE',
] as const;

export const INSPECTION_TYPES = [
  'pre_licence',
  'annual',
  'complaint_driven',
  're_inspection',
] as const;

const PHONE = /^(\+91)?[6-9]\d{9}$/;
const GST = /^\d{2}[A-Z]{5}\d{4}[A-Z]\d[A-Z\d][A-Z]$/;

export class CreateTradeLicenceDto {
  @IsOptional()
  @IsInt()
  @Type(() => Number)
  org_unit_id?: number;

  // ── Trade ──
  @IsString()
  @MinLength(2)
  @MaxLength(160)
  trade_name: string;

  @IsEnum(TRADE_CATEGORIES as unknown as string[], {
    message: `trade_category must be one of: ${TRADE_CATEGORIES.join(', ')}`,
  })
  trade_category: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  trade_sub_category?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  description?: string;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(10000)
  @Type(() => Number)
  motive_power_hp?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(10000)
  @Type(() => Number)
  worker_count?: number;

  @IsOptional()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d-([01]\d|2[0-3]):[0-5]\d$/, {
    message: 'operating_hours must look like "06:00-22:00"',
  })
  operating_hours?: string;

  // ── Applicant ──
  @IsString()
  @MinLength(3)
  @MaxLength(120)
  owner_name: string;

  @IsOptional()
  @IsEnum(OWNERSHIP_TYPES as unknown as string[])
  ownership_type?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  signatory_name?: string;

  @IsOptional()
  @Matches(PHONE, { message: 'owner_phone must be a valid Indian mobile number' })
  owner_phone?: string;

  @IsOptional()
  @IsEmail()
  owner_email?: string;

  @IsOptional()
  @IsString()
  @MaxLength(400)
  owner_address?: string;

  /** Full 12 digits accepted; only the last 4 are persisted. */
  @IsOptional()
  @Matches(/^\d{12}$/, { message: 'owner_aadhaar must be 12 digits' })
  owner_aadhaar?: string;

  // ── Premises ──
  @IsOptional()
  @IsString()
  @MaxLength(40)
  door_number?: string;

  @IsOptional()
  @IsString()
  @MaxLength(160)
  street_name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  ward_number?: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  survey_number?: string;

  @IsNumber()
  @IsPositive()
  @Type(() => Number)
  area_sqft: number;

  @IsOptional()
  @IsBoolean()
  is_rented?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  landlord_name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  rent_agreement_ref?: string;

  @IsOptional()
  @IsNumber()
  @Min(-90)
  @Max(90)
  @Type(() => Number)
  latitude?: number;

  @IsOptional()
  @IsNumber()
  @Min(-180)
  @Max(180)
  @Type(() => Number)
  longitude?: number;

  // ── Statutory references held by the trade ──
  @IsOptional()
  @Matches(/^\d{14}$/, { message: 'fssai_number must be 14 digits' })
  fssai_number?: string;

  @IsOptional()
  @IsISO8601()
  fssai_expiry?: string;

  @IsOptional()
  @Matches(GST, { message: 'gst_number is not a valid GSTIN' })
  gst_number?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  fire_noc_ref?: string;

  @IsOptional()
  @IsISO8601()
  fire_noc_expiry?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  pollution_consent_ref?: string;

  @IsOptional()
  @IsISO8601()
  pollution_consent_expiry?: string;
}

/**
 * Fields a clerk may revise before the licence is granted. Premises identity
 * and trade category are absent — a different trade at a different address is
 * a different licence, not an edit.
 */
export class UpdateTradeLicenceDto {
  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(160)
  trade_name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  description?: string;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(10000)
  @Type(() => Number)
  motive_power_hp?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Type(() => Number)
  worker_count?: number;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  owner_name?: string;

  @IsOptional()
  @Matches(PHONE, { message: 'owner_phone must be a valid Indian mobile number' })
  owner_phone?: string;

  @IsOptional()
  @IsEmail()
  owner_email?: string;

  @IsOptional()
  @IsString()
  @MaxLength(400)
  owner_address?: string;

  @IsOptional()
  @IsNumber()
  @IsPositive()
  @Type(() => Number)
  area_sqft?: number;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  fire_noc_ref?: string;

  @IsOptional()
  @IsISO8601()
  fire_noc_expiry?: string;

  @IsOptional()
  @Matches(/^\d{14}$/, { message: 'fssai_number must be 14 digits' })
  fssai_number?: string;

  @IsOptional()
  @IsISO8601()
  fssai_expiry?: string;
}

export class ListTradeLicencesDto {
  @IsOptional()
  @IsInt()
  @Type(() => Number)
  org_unit_id?: number;

  @IsOptional()
  @IsString()
  status?: string;

  @IsOptional()
  @IsEnum(TRADE_CATEGORIES as unknown as string[])
  trade_category?: string;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  ward_number?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  q?: string;

  /** Licences expiring within this many days — the renewal board's query. */
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(365)
  @Type(() => Number)
  expiring_within_days?: number;

  /** Only licences whose validity has already run out. */
  @IsOptional()
  @IsBoolean()
  @Type(() => Boolean)
  overdue_only?: boolean;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(200)
  @Type(() => Number)
  take?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Type(() => Number)
  skip?: number;
}

export class ScheduleLicenceInspectionDto {
  @IsEnum(INSPECTION_TYPES as unknown as string[], {
    message: `inspection_type must be one of: ${INSPECTION_TYPES.join(', ')}`,
  })
  inspection_type: string;

  @IsISO8601({}, { message: 'scheduled_for must be an ISO-8601 date' })
  scheduled_for: string;

  @IsOptional()
  @IsInt()
  @Type(() => Number)
  inspector_user_id?: number;
}

export class RecordLicenceInspectionDto {
  @IsBoolean()
  is_compliant: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  findings?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  violations?: string[];

  @IsOptional()
  @IsNumber()
  @Min(-90)
  @Max(90)
  @Type(() => Number)
  latitude?: number;

  @IsOptional()
  @IsNumber()
  @Min(-180)
  @Max(180)
  @Type(() => Number)
  longitude?: number;
}

export class RecordLicencePaymentDto {
  @IsNumber()
  @IsPositive()
  @Type(() => Number)
  amount: number;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  payment_ref?: string;
}

export class ApproveLicenceDto {
  @IsOptional()
  @IsString()
  @MaxLength(500)
  remarks?: string;
}

export class RejectLicenceDto {
  @IsString()
  @MinLength(10, {
    message: 'A rejection must state a reason the applicant can act on',
  })
  @MaxLength(1000)
  reason: string;
}

/**
 * Renew for the next licence year. The year, dates and penalty are all
 * derived server-side from the current validity — a client cannot choose to
 * renew into a year of its own picking.
 */
export class RenewLicenceDto {
  @IsOptional()
  @IsString()
  @MaxLength(500)
  remarks?: string;
}

export class SuspendLicenceDto {
  @IsString()
  @MinLength(10, { message: 'Record why the licence is being suspended' })
  @MaxLength(1000)
  reason: string;
}

export class CancelLicenceDto {
  @IsString()
  @MinLength(10, { message: 'Record why the licence is being cancelled' })
  @MaxLength(1000)
  reason: string;
}

export class IssueLicenceCertificateDto {
  @IsOptional()
  @IsString()
  @MaxLength(200)
  remarks?: string;
}
