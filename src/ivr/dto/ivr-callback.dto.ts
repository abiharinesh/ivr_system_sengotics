import { IsString, IsOptional, IsInt } from 'class-validator'

export class IvrCallbackDto {
    @IsString()
    CallSid: string

    @IsString()
    @IsOptional()
    CallFrom?: string

    @IsString()
    @IsOptional()
    CallTo?: string

    @IsString()
    @IsOptional()
    From?: string

    @IsString()
    @IsOptional()
    To?: string

    @IsString()
    @IsOptional()
    Direction?: string

    @IsString()
    @IsOptional()
    Created?: string

    @IsString()
    @IsOptional()
    StartTime?: string

    @IsString()
    @IsOptional()
    EndTime?: string

    @IsString()
    @IsOptional()
    CallType?: string

    @IsString()
    @IsOptional()
    DialCallDuration?: string

    @IsString()
    @IsOptional()
    DialWhomNumber?: string

    @IsString()
    @IsOptional()
    flow_id?: string

    @IsString()
    @IsOptional()
    tenant_id?: string

    @IsString()
    @IsOptional()
    CurrentTime?: string

    @IsString()
    @IsOptional()
    digits?: string

    @IsString()
    @IsOptional()
    RecordingUrl?: string

    @IsString()
    @IsOptional()
    RecordingAvailableBy?: string
}
