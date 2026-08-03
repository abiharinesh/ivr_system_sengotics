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
  Length,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

/**
 * Request shapes for the building permit API.
 *
 * The global `ValidationPipe` runs with `whitelist: false` (Exotel webhooks
 * send variable payloads elsewhere in this app), so these DTOs validate what
 * they declare but do not strip extras — the service picks fields explicitly
 * rather than spreading the body into Prisma.
 */

export const CONSTRUCTION_TYPES = [
  'residential',
  'commercial',
  'industrial',
  'institutional',
  'mixed',
] as const;

export const WORK_NATURES = [
  'new',
  'extension',
  'alteration',
  'reconstruction',
] as const;

export const NOC_DEPARTMENTS = [
  'fire',
  'traffic',
  'electricity',
  'highways',
  'pollution',
  'airport',
  'water',
  'health',
] as const;

export const INSPECTION_TYPES = [
  'site_verification',
  'plinth_level',
  'completion',
] as const;

export class CreateBuildingPermitDto {
  @IsInt()
  @Type(() => Number)
  org_unit_id: number;

  // ── Applicant ──
  @IsString()
  @MinLength(3)
  @MaxLength(120)
  applicant_name: string;

  @IsOptional()
  @IsString()
  @Matches(/^(\+91)?[6-9]\d{9}$/, {
    message: 'applicant_phone must be a valid Indian mobile number',
  })
  applicant_phone?: string;

  @IsOptional()
  @IsEmail()
  applicant_email?: string;

  @IsOptional()
  @IsString()
  @MaxLength(400)
  applicant_address?: string;

  /** Full 12 digits accepted; only the last 4 are persisted. */
  @IsOptional()
  @IsString()
  @Matches(/^\d{12}$/, { message: 'applicant_aadhaar must be 12 digits' })
  applicant_aadhaar?: string;

  @IsOptional()
  @IsBoolean()
  is_owner?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  power_of_attorney?: string;

  // ── Site ──
  @IsString()
  @MinLength(1)
  @MaxLength(40)
  survey_number: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  subdivision_no?: string;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  ward_number?: string;

  @IsOptional()
  @IsString()
  @MaxLength(160)
  street_name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  door_number?: string;

  @IsNumber()
  @IsPositive()
  @Type(() => Number)
  plot_area_sqm: number;

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

  // ── Proposal ──
  @IsEnum(CONSTRUCTION_TYPES as unknown as string[], {
    message: `construction_type must be one of: ${CONSTRUCTION_TYPES.join(', ')}`,
  })
  construction_type: string;

  @IsOptional()
  @IsEnum(WORK_NATURES as unknown as string[], {
    message: `work_nature must be one of: ${WORK_NATURES.join(', ')}`,
  })
  work_nature?: string;

  @IsNumber()
  @IsPositive()
  @Type(() => Number)
  built_up_area_sqm: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(60)
  @Type(() => Number)
  floors_proposed?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Type(() => Number)
  height_m?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Type(() => Number)
  setback_front_m?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Type(() => Number)
  setback_rear_m?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Type(() => Number)
  setback_left_m?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Type(() => Number)
  setback_right_m?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Type(() => Number)
  estimated_cost?: number;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  architect_name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(60)
  architect_licence?: string;

  /**
   * Departments whose clearance this proposal needs. Omit to fall back to the
   * defaults for the construction type.
   */
  @IsOptional()
  @IsArray()
  @IsEnum(NOC_DEPARTMENTS as unknown as string[], { each: true })
  noc_departments?: string[];
}

/**
 * Fields an applicant or clerk may revise. Site identity (`org_unit_id`,
 * `survey_number`) is intentionally absent — a permit that moves to a
 * different plot is a different application.
 */
export class UpdateBuildingPermitDto {
  @IsOptional()
  @IsString()
  @MinLength(3)
  @MaxLength(120)
  applicant_name?: string;

  @IsOptional()
  @IsString()
  @Matches(/^(\+91)?[6-9]\d{9}$/, {
    message: 'applicant_phone must be a valid Indian mobile number',
  })
  applicant_phone?: string;

  @IsOptional()
  @IsEmail()
  applicant_email?: string;

  @IsOptional()
  @IsString()
  @MaxLength(400)
  applicant_address?: string;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  ward_number?: string;

  @IsOptional()
  @IsString()
  @MaxLength(160)
  street_name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  door_number?: string;

  @IsOptional()
  @IsNumber()
  @IsPositive()
  @Type(() => Number)
  plot_area_sqm?: number;

  @IsOptional()
  @IsEnum(CONSTRUCTION_TYPES as unknown as string[])
  construction_type?: string;

  @IsOptional()
  @IsEnum(WORK_NATURES as unknown as string[])
  work_nature?: string;

  @IsOptional()
  @IsNumber()
  @IsPositive()
  @Type(() => Number)
  built_up_area_sqm?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(60)
  @Type(() => Number)
  floors_proposed?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Type(() => Number)
  height_m?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Type(() => Number)
  setback_front_m?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Type(() => Number)
  setback_rear_m?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Type(() => Number)
  setback_left_m?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Type(() => Number)
  setback_right_m?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Type(() => Number)
  estimated_cost?: number;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  architect_name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(60)
  architect_licence?: string;
}

export class ListBuildingPermitsDto {
  @IsOptional()
  @IsInt()
  @Type(() => Number)
  org_unit_id?: number;

  @IsOptional()
  @IsString()
  status?: string;

  @IsOptional()
  @IsEnum(CONSTRUCTION_TYPES as unknown as string[])
  construction_type?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  q?: string;

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

export class UpdateNocDto {
  @IsEnum(['GRANTED', 'REJECTED', 'NOT_APPLICABLE', 'PENDING'], {
    message: 'status must be GRANTED, REJECTED, NOT_APPLICABLE or PENDING',
  })
  status: 'GRANTED' | 'REJECTED' | 'NOT_APPLICABLE' | 'PENDING';

  @IsOptional()
  @IsString()
  @MaxLength(80)
  reference_no?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  remarks?: string;
}

export class AddNocDto {
  @IsEnum(NOC_DEPARTMENTS as unknown as string[], {
    message: `department must be one of: ${NOC_DEPARTMENTS.join(', ')}`,
  })
  department: string;

  @IsOptional()
  @IsBoolean()
  is_mandatory?: boolean;
}

export class ScheduleInspectionDto {
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

export class RecordInspectionDto {
  @IsBoolean()
  is_compliant: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  findings?: string;

  @IsOptional()
  @IsNumber()
  @Min(-90)
  @Max(90)
  @Type(() => Number)
  location_lat?: number;

  @IsOptional()
  @IsNumber()
  @Min(-180)
  @Max(180)
  @Type(() => Number)
  location_lng?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Type(() => Number)
  gps_accuracy_m?: number;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  photos?: string[];
}

export class RecordPaymentDto {
  @IsNumber()
  @IsPositive()
  @Type(() => Number)
  amount: number;

  @IsOptional()
  @IsString()
  @Length(3, 80)
  payment_ref?: string;
}

export class ApprovePermitDto {
  /**
   * Statutory validity of the permit. Defaults to 36 months, the usual TN
   * building permit validity, but a council may sanction a shorter term.
   */
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(120)
  @Type(() => Number)
  validity_months?: number;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  remarks?: string;
}

export class RejectPermitDto {
  @IsString()
  @MinLength(10, {
    message: 'A rejection must state a reason the applicant can act on',
  })
  @MaxLength(1000)
  reason: string;
}
