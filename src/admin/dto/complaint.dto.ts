import { IsString, IsOptional } from 'class-validator'

export class UpdateComplaintStatusDto {
    @IsString()
    status: string // pending | in_progress | resolved
}

export class AssignComplaintDto {
    @IsString()
    @IsOptional()
    assigned_to?: string
}
