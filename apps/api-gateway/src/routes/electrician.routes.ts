import { Controller, All, Req, Res } from '@nestjs/common'
import type { Request, Response } from 'express'
import { proxyRequest } from '../proxy.util'

const ELECTRICIAN_URL = process.env.ELECTRICIAN_SERVICE_URL || 'http://localhost:3004'

@Controller('api/electrician')
export class ElectricianRoutes {
    @All('*')
    async proxy(@Req() req: Request, @Res() res: Response) {
        const path = req.originalUrl.replace(/^\//, '')
        return proxyRequest(ELECTRICIAN_URL, `/${path}`, req, res)
    }
}
