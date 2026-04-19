import { Controller, All, Req, Res } from '@nestjs/common'
import type { Request, Response } from 'express'
import { proxyRequest } from '../proxy.util'

const COMPLAINT_URL = process.env.COMPLAINT_SERVICE_URL || 'http://localhost:3002'
const TENDER_URL = process.env.TENDER_SERVICE_URL || 'http://localhost:3006'
const QUOTATION_URL = process.env.QUOTATION_SERVICE_URL || 'http://localhost:3007'
const WORK_ORDER_URL = process.env.WORK_ORDER_SERVICE_URL || 'http://localhost:3008'

/**
 * Procurement routes map to multiple services:
 * - /api/procurement/complaints/* → complaint-service
 * - /api/procurement/tenders/* → tender-service
 * - /api/procurement/quotations/* → quotation-service
 * - /api/procurement/work-orders/* → work-order-service
 * - /api/procurement/public/* → various (tender/quotation/work-order public endpoints)
 */
@Controller('api/procurement')
export class ProcurementRoutes {
    @All('complaints/*')
    async complaints(@Req() req: Request, @Res() res: Response) {
        const path = req.originalUrl.replace(/^\/api\/procurement/, '')
        return proxyRequest(COMPLAINT_URL, path, req, res)
    }

    @All('tenders/*')
    async tenders(@Req() req: Request, @Res() res: Response) {
        const path = req.originalUrl.replace(/^\/api\/procurement/, '')
        return proxyRequest(TENDER_URL, path, req, res)
    }

    @All('tenders')
    async tendersRoot(@Req() req: Request, @Res() res: Response) {
        const path = req.originalUrl.replace(/^\/api\/procurement/, '')
        return proxyRequest(TENDER_URL, path, req, res)
    }

    @All('quotations/*')
    async quotations(@Req() req: Request, @Res() res: Response) {
        const path = req.originalUrl.replace(/^\/api\/procurement/, '')
        return proxyRequest(QUOTATION_URL, path, req, res)
    }

    @All('work-orders/*')
    async workOrders(@Req() req: Request, @Res() res: Response) {
        const path = req.originalUrl.replace(/^\/api\/procurement/, '')
        return proxyRequest(WORK_ORDER_URL, path, req, res)
    }

    @All('work-orders')
    async workOrdersRoot(@Req() req: Request, @Res() res: Response) {
        const path = req.originalUrl.replace(/^\/api\/procurement/, '')
        return proxyRequest(WORK_ORDER_URL, path, req, res)
    }

    @All('public/tender-form/*')
    async publicTenderForm(@Req() req: Request, @Res() res: Response) {
        const path = req.originalUrl.replace(/^\/api\/procurement\/public\/tender-form/, '/quotations/submit')
        return proxyRequest(QUOTATION_URL, path, req, res)
    }

    @All('public/work-upload/*')
    async publicWorkUpload(@Req() req: Request, @Res() res: Response) {
        const path = req.originalUrl.replace(/^\/api\/procurement\/public\/work-upload/, '/work-orders/proof')
        return proxyRequest(WORK_ORDER_URL, path, req, res)
    }

    @All('dashboard-metrics')
    async dashboard(@Req() req: Request, @Res() res: Response) {
        return proxyRequest(WORK_ORDER_URL, '/work-orders/dashboard-metrics' + (req.originalUrl.includes('?') ? '?' + req.originalUrl.split('?')[1] : ''), req, res)
    }
}
