import { Controller, All, Req, Res } from '@nestjs/common'
import type { Request, Response } from 'express'
import { proxyRequest } from '../proxy.util'

const AUTH_URL = process.env.AUTH_SERVICE_URL || 'http://localhost:3001'

@Controller('api/auth')
export class AuthRoutes {
    @All('*')
    async proxy(@Req() req: Request, @Res() res: Response) {
        const path = req.originalUrl.replace(/^\/api\/auth/, '') || '/'
        return proxyRequest(AUTH_URL, path, req, res)
    }
}
