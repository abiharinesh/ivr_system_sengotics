import { ExceptionFilter, Catch, ArgumentsHost, HttpException, Logger } from '@nestjs/common'
import type { Response } from 'express'

/**
 * IVR-specific exception filter.
 * Exotel expects a valid XML response even on error — we NEVER let it see a raw error.
 * All exceptions are logged and swallowed with an empty <Response> 200 XML.
 */
@Catch()
export class IvrExceptionFilter implements ExceptionFilter {
    private readonly logger = new Logger(IvrExceptionFilter.name)

    catch(exception: unknown, host: ArgumentsHost) {
        const ctx = host.switchToHttp()
        const res = ctx.getResponse<Response>()
        const req = ctx.getRequest()

        // Extract a meaningful message from different error types
        let message: string
        let stack: string | undefined

        if (exception instanceof HttpException) {
            message = exception.message
            stack = exception.stack
        } else if (exception instanceof Error) {
            message = exception.message
            stack = exception.stack
        } else {
            message = String(exception)
        }

        this.logger.error(
            `IVR request failed [${req.method} ${req.url}]: ${message}`,
            stack
        )

        // Always return valid XML 200 to Exotel — never let it see an error
        const xml = `<?xml version="1.0" encoding="UTF-8"?><Response></Response>`
        res.status(200).type('application/xml').send(xml)
    }
}
