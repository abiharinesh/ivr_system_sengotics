import { IsString, IsNumber, IsOptional } from 'class-validator'

export class CreatePoleDto {
    @IsString()
    pole_number: string

    @IsNumber()
    latitude: number

    @IsNumber()
    longitude: number

    @IsNumber()
    @IsOptional()
    panchayat_id?: number
}

export class UpdatePoleDto {
    @IsString()
    @IsOptional()
    pole_number?: string

    @IsNumber()
    @IsOptional()
    latitude?: number

    @IsNumber()
    @IsOptional()
    longitude?: number

    @IsNumber()
    @IsOptional()
    panchayat_id?: number
}
