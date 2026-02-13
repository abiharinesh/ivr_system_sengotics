import { IsString, IsOptional, IsInt } from 'class-validator'

export class IvrCallbackDto {
    @IsString()
    CallSid: string

    @IsString()
    CallFrom: string

    @IsString()
    CallTo: string

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

    @IsInt()
    @IsOptional()
    DialCallDuration?: number

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
