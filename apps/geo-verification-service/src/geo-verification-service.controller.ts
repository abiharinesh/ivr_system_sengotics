import { Controller, Post, Body } from '@nestjs/common'
import { GeoVerificationServiceService, CandidatePole, GeoVerificationInput } from './geo-verification-service.service'

@Controller('geo-verification')
export class GeoVerificationServiceController {
    constructor(private readonly service: GeoVerificationServiceService) {}

    @Post('verify')
    verify(@Body() body: { candidates: CandidatePole[]; input: GeoVerificationInput }) {
        return this.service.verifyNearestCandidate(body.candidates, body.input)
    }
}
