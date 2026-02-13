import { IsString, IsNumber, IsOptional } from 'class-validator'

export class CreatePanchayatDto {
    @IsString()
    name: string

    @IsNumber()
    @IsOptional()
    center_lat?: number

    @IsNumber()
    @IsOptional()
    center_lng?: number

    @IsString()
    @IsOptional()
    ivr_number?: string
}

export class UpdatePanchayatDto {
    @IsString()
    @IsOptional()
    name?: string

    @IsNumber()
    @IsOptional()
    center_lat?: number

    @IsNumber()
    @IsOptional()
    center_lng?: number

    @IsString()
    @IsOptional()
    ivr_number?: string
}
