import { Controller, All, Req, Res } from '@nestjs/common'
import type { Request, Response } from 'express'
import { proxyRequest } from '../proxy.util'

const IVR_URL = process.env.IVR_SERVICE_URL || 'http://localhost:3011'

@Controller('api/ivr')
export class IvrRoutes {
    @All('*')
    async proxy(@Req() req: Request, @Res() res: Response) {
        const path = req.originalUrl.replace(/^\//, '')
        return proxyRequest(IVR_URL, `/${path}`, req, res)
    }
}
