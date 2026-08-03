import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsEnum,
  IsInt,
  IsISO8601,
  IsNumber,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';

export const SEXES = ['male', 'female', 'transgender'] as const;

export const PLACE_TYPES = [
  'hospital',
  'home',
  'institution',
  'vehicle',
  'public_place',
] as const;

export const INFORMANT_RELATIONS = [
  'father',
  'mother',
  'husband',
  'wife',
  'son',
  'daughter',
  'brother',
  'sister',
  'hospital_official',
  'institution_head',
  'other',
] as const;

export const DELIVERY_TYPES = ['normal', 'caesarean', 'forceps', 'other'] as const;

export const CAUSE_CATEGORIES = [
  'natural',
  'accident',
  'suicide',
  'homicide',
  'pending_investigation',
] as const;

export const DISPOSAL_METHODS = ['burial', 'cremation', 'donation'] as const;

const PHONE = /^(\+91)?[6-9]\d{9}$/;

/** Birth particulars — Form 1. */
export class BirthDetailDto {
  /** Often blank at registration; parents have a year to supply it. */
  @IsOptional()
  @IsString()
  @MaxLength(120)
  child_name?: string;

  @IsEnum(SEXES as unknown as string[], {
    message: `sex must be one of: ${SEXES.join(', ')}`,
  })
  sex: string;

  @IsOptional()
  @IsNumber()
  @Min(0.1)
  @Max(12)
  @Type(() => Number)
  weight_kg?: number;

  @IsOptional()
  @IsEnum(DELIVERY_TYPES as unknown as string[])
  delivery_type?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  father_name?: string;

  @IsOptional()
  @Matches(/^\d{12}$/, { message: 'father_aadhaar must be 12 digits' })
  father_aadhaar?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  father_education?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  father_occupation?: string;

  @IsString()
  @MinLength(2)
  @MaxLength(120)
  mother_name: string;

  @IsOptional()
  @Matches(/^\d{12}$/, { message: 'mother_aadhaar must be 12 digits' })
  mother_aadhaar?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  mother_education?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  mother_occupation?: string;

  @IsOptional()
  @IsInt()
  @Min(10)
  @Max(70)
  @Type(() => Number)
  mother_age_at_marriage?: number;

  @IsOptional()
  @IsInt()
  @Min(10)
  @Max(70)
  @Type(() => Number)
  mother_age_at_birth?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(20)
  @Type(() => Number)
  birth_order?: number;

  @IsOptional()
  @IsString()
  @MaxLength(400)
  address_at_birth?: string;

  @IsOptional()
  @IsString()
  @MaxLength(400)
  permanent_address?: string;

  @IsOptional()
  @IsBoolean()
  is_multiple_birth?: boolean;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(10)
  @Type(() => Number)
  multiple_birth_order?: number;
}

/** Death particulars — Form 2. */
export class DeathDetailDto {
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  deceased_name: string;

  @IsEnum(SEXES as unknown as string[], {
    message: `sex must be one of: ${SEXES.join(', ')}`,
  })
  sex: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(130)
  @Type(() => Number)
  age_years?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(11)
  @Type(() => Number)
  age_months?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(30)
  @Type(() => Number)
  age_days?: number;

  @IsOptional()
  @IsISO8601()
  date_of_birth?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  father_name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  mother_name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  spouse_name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  occupation?: string;

  @IsOptional()
  @IsString()
  @MaxLength(400)
  address?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  cause_of_death?: string;

  @IsOptional()
  @IsEnum(CAUSE_CATEGORIES as unknown as string[])
  cause_category?: string;

  @IsOptional()
  @IsBoolean()
  medically_certified?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  certifying_doctor?: string;

  @IsOptional()
  @IsString()
  @MaxLength(60)
  doctor_reg_no?: string;

  @IsOptional()
  @IsEnum(DISPOSAL_METHODS as unknown as string[])
  disposal_method?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  disposal_place?: string;

  @IsOptional()
  @IsISO8601()
  disposal_date?: string;
}

export class ReportVitalEventDto {
  @IsOptional()
  @IsInt()
  @Type(() => Number)
  org_unit_id?: number;

  @IsEnum(['BIRTH', 'DEATH'], { message: 'event_type must be BIRTH or DEATH' })
  event_type: 'BIRTH' | 'DEATH';

  @IsISO8601({}, { message: 'event_date must be an ISO-8601 date' })
  event_date: string;

  @IsOptional()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/, {
    message: 'event_time must be HH:MM in 24-hour form',
  })
  event_time?: string;

  @IsEnum(PLACE_TYPES as unknown as string[], {
    message: `place_type must be one of: ${PLACE_TYPES.join(', ')}`,
  })
  place_type: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  place_name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(400)
  place_address?: string;

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

  @IsOptional()
  @IsEnum(['HOSPITAL', 'INSTITUTION', 'DOMICILIARY', 'SELF_REPORTED'])
  reporting_source?: 'HOSPITAL' | 'INSTITUTION' | 'DOMICILIARY' | 'SELF_REPORTED';

  @IsOptional()
  @IsString()
  @MaxLength(200)
  hospital_name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(60)
  hospital_reg_no?: string;

  @IsString()
  @MinLength(2)
  @MaxLength(120)
  informant_name: string;

  @IsEnum(INFORMANT_RELATIONS as unknown as string[], {
    message: `informant_relation must be one of: ${INFORMANT_RELATIONS.join(', ')}`,
  })
  informant_relation: string;

  @IsOptional()
  @Matches(PHONE, { message: 'informant_phone must be a valid Indian mobile number' })
  informant_phone?: string;

  @IsOptional()
  @IsString()
  @MaxLength(400)
  informant_address?: string;

  @IsOptional()
  @Matches(/^\d{12}$/, { message: 'informant_aadhaar must be 12 digits' })
  informant_aadhaar?: string;

  @IsOptional()
  @ValidateNested()
  @Type(() => BirthDetailDto)
  birth?: BirthDetailDto;

  @IsOptional()
  @ValidateNested()
  @Type(() => DeathDetailDto)
  death?: DeathDetailDto;
}

/** Bulk intake from a hospital's reporting system. */
export class HospitalFeedDto {
  @IsOptional()
  @IsInt()
  @Type(() => Number)
  org_unit_id?: number;

  @IsString()
  @MinLength(2)
  @MaxLength(200)
  hospital_name: string;

  @IsOptional()
  @IsString()
  @MaxLength(60)
  hospital_reg_no?: string;

  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(200, {
    message: 'Send at most 200 events per batch so a failure is easy to isolate',
  })
  @ValidateNested({ each: true })
  @Type(() => ReportVitalEventDto)
  events: ReportVitalEventDto[];
}

export class UpdateParticularsDto {
  @IsOptional()
  @ValidateNested()
  @Type(() => BirthDetailDto)
  birth?: BirthDetailDto;

  @IsOptional()
  @ValidateNested()
  @Type(() => DeathDetailDto)
  death?: DeathDetailDto;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  place_name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(400)
  place_address?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  informant_name?: string;

  @IsOptional()
  @Matches(PHONE, { message: 'informant_phone must be a valid Indian mobile number' })
  informant_phone?: string;

  @IsOptional()
  @IsString()
  @MaxLength(400)
  informant_address?: string;
}

export class RegisterEventDto {
  /**
   * Reference to the written permission or magistrate's order authorising a
   * late entry. Required when the delay puts the report past 30 days.
   */
  @IsOptional()
  @IsString()
  @MinLength(3)
  @MaxLength(120)
  delay_approval_ref?: string;
}

export class RejectEventDto {
  @IsString()
  @MinLength(10, {
    message: 'State a reason the informant can act on',
  })
  @MaxLength(1000)
  reason: string;
}

/**
 * Correction under s.15 — the entry is already registered, so the change is
 * recorded as an amendment with a stated reason, never a silent overwrite.
 */
export class CorrectEventDto {
  @IsString()
  @MinLength(10, { message: 'A correction must record why it was made' })
  @MaxLength(1000)
  correction_note: string;

  @IsOptional()
  @ValidateNested()
  @Type(() => BirthDetailDto)
  birth?: BirthDetailDto;

  @IsOptional()
  @ValidateNested()
  @Type(() => DeathDetailDto)
  death?: DeathDetailDto;
}

export class IssueCertificateDto {
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  issued_to: string;

  @IsOptional()
  @IsString()
  @MaxLength(60)
  issued_to_relation?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  purpose?: string;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Type(() => Number)
  fee_amount?: number;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  payment_ref?: string;
}

export class CancelCertificateDto {
  @IsString()
  @MinLength(10, { message: 'Record why the certificate is being cancelled' })
  @MaxLength(500)
  reason: string;
}

export class ListVitalEventsDto {
  @IsOptional()
  @IsInt()
  @Type(() => Number)
  org_unit_id?: number;

  @IsOptional()
  @IsEnum(['BIRTH', 'DEATH'])
  event_type?: 'BIRTH' | 'DEATH';

  @IsOptional()
  @IsString()
  status?: string;

  /** Free-text across registration number, names and informant. */
  @IsOptional()
  @IsString()
  @MaxLength(80)
  q?: string;

  @IsOptional()
  @IsISO8601()
  from?: string;

  @IsOptional()
  @IsISO8601()
  to?: string;

  @IsOptional()
  @IsBoolean()
  @Type(() => Boolean)
  late_only?: boolean;

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
