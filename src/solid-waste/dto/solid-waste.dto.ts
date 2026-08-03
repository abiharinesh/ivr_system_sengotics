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

export const BIN_TYPES = [
  'community',
  'litter',
  'segregated_wet',
  'segregated_dry',
  'compactor',
] as const;

export const FILL_LEVELS = [
  'EMPTY',
  'LOW',
  'MEDIUM',
  'HIGH',
  'OVERFLOWING',
] as const;

export const BIN_STATUSES = [
  'ACTIVE',
  'DAMAGED',
  'REMOVED',
  'RELOCATED',
] as const;

export const SHIFTS = ['morning', 'afternoon', 'night'] as const;

export const ATTENDANCE_STATUSES = [
  'PRESENT',
  'ABSENT',
  'LEAVE',
  'HALF_DAY',
] as const;

const PHONE = /^(\+91)?[6-9]\d{9}$/;

// ── Bins ────────────────────────────────────────────────────────────────────

export class CreateBinDto {
  @IsOptional()
  @IsInt()
  @Type(() => Number)
  org_unit_id?: number;

  @IsEnum(BIN_TYPES as unknown as string[], {
    message: `bin_type must be one of: ${BIN_TYPES.join(', ')}`,
  })
  bin_type: string;

  @IsInt()
  @Min(10)
  @Max(20000)
  @Type(() => Number)
  capacity_litres: number;

  @IsNumber()
  @Min(-90)
  @Max(90)
  @Type(() => Number)
  latitude: number;

  @IsNumber()
  @Min(-180)
  @Max(180)
  @Type(() => Number)
  longitude: number;

  @IsOptional()
  @IsInt()
  @Type(() => Number)
  zone_id?: number;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  ward_number?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  landmark?: string;

  @IsOptional()
  @IsISO8601()
  installed_at?: string;
}

export class UpdateBinDto {
  @IsOptional()
  @IsEnum(BIN_TYPES as unknown as string[])
  bin_type?: string;

  @IsOptional()
  @IsInt()
  @Min(10)
  @Max(20000)
  @Type(() => Number)
  capacity_litres?: number;

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
  @IsInt()
  @Type(() => Number)
  zone_id?: number;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  ward_number?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  landmark?: string;

  @IsOptional()
  @IsEnum(BIN_STATUSES as unknown as string[])
  status?: string;
}

/**
 * A fill-level observation. The band is derived from the percentage server-side
 * rather than accepted from the client, so the map, the SLA and the API can
 * never disagree about what "red" means.
 */
export class RecordReadingDto {
  @IsInt()
  @Min(0)
  @Max(100)
  @Type(() => Number)
  fill_pct: number;

  /** True when this reading records the bin being emptied, not just observed. */
  @IsOptional()
  @IsBoolean()
  emptied?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  remarks?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  photo_url?: string;

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

export class ListBinsDto {
  @IsOptional()
  @IsInt()
  @Type(() => Number)
  org_unit_id?: number;

  @IsOptional()
  @IsInt()
  @Type(() => Number)
  zone_id?: number;

  @IsOptional()
  @IsEnum(FILL_LEVELS as unknown as string[])
  fill_level?: string;

  @IsOptional()
  @IsEnum(BIN_STATUSES as unknown as string[])
  status?: string;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  ward_number?: string;

  /** Only bins needing clearance (HIGH or OVERFLOWING). */
  @IsOptional()
  @IsBoolean()
  @Type(() => Boolean)
  needs_clearance?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  q?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(500)
  @Type(() => Number)
  take?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Type(() => Number)
  skip?: number;
}

// ── Routes ──────────────────────────────────────────────────────────────────

export class RouteStopDto {
  @IsString()
  @MinLength(2)
  @MaxLength(200)
  label: string;

  @IsOptional()
  @IsInt()
  @Type(() => Number)
  bin_id?: number;

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
  @IsInt()
  @Min(0)
  @Max(10000)
  @Type(() => Number)
  household_count?: number;
}

export class CreateRouteDto {
  @IsOptional()
  @IsInt()
  @Type(() => Number)
  org_unit_id?: number;

  @IsString()
  @MinLength(2)
  @MaxLength(120)
  name: string;

  @IsOptional()
  @IsInt()
  @Type(() => Number)
  zone_id?: number;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  ward_number?: string;

  /** 1=Mon … 7=Sun. */
  @IsOptional()
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(7)
  @IsInt({ each: true })
  @Min(1, { each: true })
  @Max(7, { each: true })
  service_days?: number[];

  @IsOptional()
  @IsEnum(SHIFTS as unknown as string[])
  shift?: string;

  @IsOptional()
  @IsInt()
  @Type(() => Number)
  default_vehicle_asset_id?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Type(() => Number)
  household_count?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Type(() => Number)
  distance_km?: number;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(500, {
    message: 'A route with more than 500 stops should be split',
  })
  @ValidateNested({ each: true })
  @Type(() => RouteStopDto)
  stops?: RouteStopDto[];
}

export class UpdateRouteDto {
  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  name?: string;

  @IsOptional()
  @IsInt()
  @Type(() => Number)
  zone_id?: number;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  ward_number?: string;

  @IsOptional()
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(7)
  @IsInt({ each: true })
  @Min(1, { each: true })
  @Max(7, { each: true })
  service_days?: number[];

  @IsOptional()
  @IsEnum(SHIFTS as unknown as string[])
  shift?: string;

  @IsOptional()
  @IsInt()
  @Type(() => Number)
  default_vehicle_asset_id?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Type(() => Number)
  household_count?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Type(() => Number)
  distance_km?: number;

  @IsOptional()
  @IsBoolean()
  is_active?: boolean;
}

/** Wholesale replacement of a route's stops, in the order supplied. */
export class ReplaceStopsDto {
  @IsArray()
  @ArrayMaxSize(500)
  @ValidateNested({ each: true })
  @Type(() => RouteStopDto)
  stops: RouteStopDto[];
}

// ── Trips ───────────────────────────────────────────────────────────────────

export class StartTripDto {
  @IsInt()
  @Type(() => Number)
  route_id: number;

  @IsOptional()
  @IsISO8601()
  trip_date?: string;

  @IsOptional()
  @IsEnum(SHIFTS as unknown as string[])
  shift?: string;

  @IsOptional()
  @IsInt()
  @Type(() => Number)
  vehicle_asset_id?: number;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  vehicle_number?: string;

  @IsOptional()
  @IsInt()
  @Type(() => Number)
  driver_user_id?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(40)
  @Type(() => Number)
  crew_size?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Type(() => Number)
  odometer_start_km?: number;
}

export class CompleteStopDto {
  @IsOptional()
  @IsBoolean()
  skipped?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  skip_reason?: string;

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
  @IsNumber()
  @Min(0)
  @Type(() => Number)
  gps_accuracy_m?: number;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  photo_url?: string;

  /**
   * Fill level of this stop's bin at the time of collection, if it has one.
   * Recording it here saves the crew a second action for the commonest case.
   */
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100)
  @Type(() => Number)
  bin_fill_pct?: number;
}

export class CloseTripDto {
  @IsOptional()
  @IsNumber()
  @Min(0)
  @Type(() => Number)
  waste_collected_kg?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Type(() => Number)
  segregated_wet_kg?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Type(() => Number)
  segregated_dry_kg?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Type(() => Number)
  odometer_end_km?: number;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  remarks?: string;
}

export class AbandonTripDto {
  @IsString()
  @MinLength(10, { message: 'Record why the round was abandoned' })
  @MaxLength(500)
  reason: string;
}

export class ListTripsDto {
  @IsOptional()
  @IsInt()
  @Type(() => Number)
  org_unit_id?: number;

  @IsOptional()
  @IsInt()
  @Type(() => Number)
  route_id?: number;

  @IsOptional()
  @IsEnum(['PLANNED', 'IN_PROGRESS', 'COMPLETED', 'ABANDONED'])
  status?: string;

  @IsOptional()
  @IsISO8601()
  from?: string;

  @IsOptional()
  @IsISO8601()
  to?: string;

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

// ── Attendance ──────────────────────────────────────────────────────────────

export class MarkAttendanceDto {
  @IsOptional()
  @IsInt()
  @Type(() => Number)
  org_unit_id?: number;

  @IsOptional()
  @IsInt()
  @Type(() => Number)
  employee_id?: number;

  @IsString()
  @MinLength(2)
  @MaxLength(120)
  worker_name: string;

  @IsOptional()
  @Matches(PHONE, { message: 'worker_phone must be a valid Indian mobile number' })
  worker_phone?: string;

  @IsOptional()
  @IsBoolean()
  is_contract?: boolean;

  @IsOptional()
  @IsISO8601()
  attendance_date?: string;

  @IsOptional()
  @IsEnum(SHIFTS as unknown as string[])
  shift?: string;

  @IsEnum(ATTENDANCE_STATUSES as unknown as string[], {
    message: `status must be one of: ${ATTENDANCE_STATUSES.join(', ')}`,
  })
  status: string;

  @IsOptional()
  @IsInt()
  @Type(() => Number)
  route_id?: number;

  @IsOptional()
  @IsNumber()
  @Min(-90)
  @Max(90)
  @Type(() => Number)
  check_in_lat?: number;

  @IsOptional()
  @IsNumber()
  @Min(-180)
  @Max(180)
  @Type(() => Number)
  check_in_lng?: number;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  remarks?: string;
}

export class ListAttendanceDto {
  @IsOptional()
  @IsInt()
  @Type(() => Number)
  org_unit_id?: number;

  @IsOptional()
  @IsISO8601()
  date?: string;

  @IsOptional()
  @IsEnum(SHIFTS as unknown as string[])
  shift?: string;

  @IsOptional()
  @IsInt()
  @Type(() => Number)
  route_id?: number;
}
