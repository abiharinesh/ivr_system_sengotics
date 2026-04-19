import { Controller, All, Req, Res } from '@nestjs/common'
import type { Request, Response } from 'express'
import { proxyRequest } from '../proxy.util'

const WHATSAPP_URL = process.env.WHATSAPP_SERVICE_URL || 'http://localhost:3012'

@Controller('api/webhooks/whatsapp')
export class WhatsappRoutes {
    @All()
    async proxyRoot(@Req() req: Request, @Res() res: Response) {
        const path = req.originalUrl.replace(/^\//, '')
        return proxyRequest(WHATSAPP_URL, `/${path}`, req, res)
    }

    @All('*')
    async proxy(@Req() req: Request, @Res() res: Response) {
        const path = req.originalUrl.replace(/^\//, '')
        return proxyRequest(WHATSAPP_URL, `/${path}`, req, res)
    }
}
