import { Controller, All, Req, Res } from '@nestjs/common'
import type { Request, Response } from 'express'
import { proxyRequest } from '../proxy.util'

const AGENT_URL = process.env.AGENT_SERVICE_URL || 'http://localhost:3010'

@Controller('api/agent')
export class AgentRoutes {
    @All('*')
    async proxy(@Req() req: Request, @Res() res: Response) {
        const path = req.originalUrl.replace(/^\//, '')
        return proxyRequest(AGENT_URL, `/${path}`, req, res)
    }
}
