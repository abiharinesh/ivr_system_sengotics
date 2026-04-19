import { Controller, All, Req, Res } from '@nestjs/common'
import type { Request, Response } from 'express'
import { proxyRequest } from '../proxy.util'

const ADMIN_URL = process.env.ADMIN_SERVICE_URL || 'http://localhost:3005'

@Controller('api/superadmin')
export class SuperAdminRoutes {
    @All('*')
    async proxy(@Req() req: Request, @Res() res: Response) {
        const path = req.originalUrl.replace(/^\//, '')
        return proxyRequest(ADMIN_URL, `/${path}`, req, res)
    }
}
