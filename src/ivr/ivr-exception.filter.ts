import { ExceptionFilter, Catch, ArgumentsHost, Logger } from '@nestjs/common'
import type { Response } from 'express'

@Catch()
export class IvrExceptionFilter implements ExceptionFilter {
    private readonly logger = new Logger(IvrExceptionFilter.name)

    catch(exception: unknown, host: ArgumentsHost) {
        const ctx = host.switchToHttp()
        const res = ctx.getResponse<Response>()
        const req = ctx.getRequest()

        this.logger.error(`IVR request failed [${req.method} ${req.url}]: ${exception}`)

        // Always return valid XML 200 to Exotel — never let it see an error
        const xml = `<?xml version="1.0" encoding="UTF-8"?><Response></Response>`
        res.status(200).type('text/xml').send(xml)
    }
}
