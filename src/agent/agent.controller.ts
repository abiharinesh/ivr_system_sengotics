import {
    Controller,
    Get,
    Post,
    Param,
    Query,
    Body,
    Req,
    ParseIntPipe,
    UseGuards,
    UseInterceptors,
    UploadedFile,
    BadRequestException,
} from '@nestjs/common'
import { FileInterceptor } from '@nestjs/platform-express'
import type { UploadedImageFile } from '../common/upload.types'
import { normalizeLandmarksField, parseGeoFromBody, strFieldOptional } from '../common/multipart-geo.util'
import { AgentService } from './agent.service'
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard'
import { RolesGuard } from '../auth/guards/roles.guard'
import { Roles } from '../auth/decorators/roles.decorator'

interface AuthReq {
    user: { id: number; email: string; role: string; panchayat_id: number | null }
}

const IMAGE_LIMIT = 12 * 1024 * 1024

function requirePanchayatId(req: AuthReq): number {
    const id = req.user.panchayat_id
    if (id == null) throw new BadRequestException('Your account is not associated with any panchayat')
    return id
}

@Controller('api/agent')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('agent')
export class AgentController {
    constructor(private readonly agentService: AgentService) { }

    @Get('poles')
    listPoles(@Req() req: AuthReq, @Query('search') search?: string) {
        return this.agentService.listPoles(requirePanchayatId(req), search)
    }

    @Get('poles/:id')
    getPole(@Req() req: AuthReq, @Param('id', ParseIntPipe) id: number) {
        return this.agentService.getPole(requirePanchayatId(req), id)
    }

    @Post('poles')
    @UseInterceptors(
        FileInterceptor('file', {
            limits: { fileSize: IMAGE_LIMIT },
        })
    )
    createPoleWithOptionalImage(
        @Req() req: AuthReq,
        @UploadedFile() file: UploadedImageFile | undefined,
        @Body() body: Record<string, unknown>
    ) {
        const panchayatId = requirePanchayatId(req)
        const landmarks = normalizeLandmarksField(body)

        if (file?.buffer?.length) {
            const geo = parseGeoFromBody(body)
            return this.agentService.createPoleWithImage(
                panchayatId,
                req.user.id,
                {
                    pole_number: strFieldOptional(body, 'pole_number'),
                    keypad_id: strFieldOptional(body, 'keypad_id'),
                    landmarks: landmarks.length ? landmarks : undefined,
                },
                file,
                geo
            )
        }

        let latitude: number | undefined
        let longitude: number | undefined
        const latStr = strFieldOptional(body, 'latitude')
        const lngStr = strFieldOptional(body, 'longitude')
        if (latStr !== undefined || lngStr !== undefined) {
            latitude = latStr !== undefined ? Number(latStr) : undefined
            longitude = lngStr !== undefined ? Number(lngStr) : undefined
            if (!Number.isFinite(latitude!) || !Number.isFinite(longitude!)) {
                throw new BadRequestException('Invalid latitude or longitude')
            }
        }
        if ((latitude !== undefined) !== (longitude !== undefined)) {
            throw new BadRequestException('Provide both latitude and longitude, or neither')
        }

        return this.agentService.createPole(panchayatId, req.user.id, {
            pole_number: strFieldOptional(body, 'pole_number'),
            keypad_id: strFieldOptional(body, 'keypad_id'),
            latitude,
            longitude,
            landmarks: landmarks.length ? landmarks : undefined,
        })
    }

    @Post('poles/:id/image')
    @UseInterceptors(
        FileInterceptor('file', {
            limits: { fileSize: IMAGE_LIMIT },
        })
    )
    uploadPoleImage(
        @Req() req: AuthReq,
        @Param('id', ParseIntPipe) id: number,
        @UploadedFile() file: UploadedImageFile,
        @Body() body: Record<string, unknown>
    ) {
        if (!file?.buffer?.length) {
            throw new BadRequestException('file is required')
        }
        const geo = parseGeoFromBody(body)
        return this.agentService.attachPoleImage(requirePanchayatId(req), req.user.id, id, file, geo)
    }
}
