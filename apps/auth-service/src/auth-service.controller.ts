import { Controller, Post, Body } from '@nestjs/common'
import { Throttle } from '@nestjs/throttler'
import { LoginDto } from '@app/shared'
import { AuthServiceService } from './auth-service.service'

@Controller('auth')
export class AuthServiceController {
    constructor(private readonly authService: AuthServiceService) {}

    @Post('login')
    async login(@Body() dto: LoginDto) {
        return this.authService.login(dto.email, dto.password)
    }
}
