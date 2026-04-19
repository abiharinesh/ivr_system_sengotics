import { Logger } from '@nestjs/common'
import type { Request, Response } from 'express'

const logger = new Logger('ProxyUtil')

/**
 * Forward an incoming gateway request to an internal microservice.
 * Handles JSON, form-data passthrough, and streaming responses.
 */
export async function proxyRequest(
    serviceBaseUrl: string,
    path: string,
    req: Request,
    res: Response,
): Promise<void> {
    const url = `${serviceBaseUrl}${path}`
    const method = req.method

    const headers: Record<string, string> = {}
    if (req.headers.authorization) headers['Authorization'] = req.headers.authorization as string
    if (req.headers['content-type']) headers['Content-Type'] = req.headers['content-type'] as string
    if (req.headers['x-hub-signature-256']) headers['x-hub-signature-256'] = req.headers['x-hub-signature-256'] as string

    let body: any = undefined
    if (['POST', 'PUT', 'PATCH', 'DELETE'].includes(method)) {
        const ct = req.headers['content-type'] || ''
        if (ct.includes('application/json')) {
            body = JSON.stringify(req.body)
        } else if (ct.includes('multipart/form-data')) {
            // For multipart, we need to pipe the raw request
            // Use the rawBody if available
            body = (req as any).rawBody ?? undefined
            if (body) {
                // Keep content-type with boundary
            } else {
                body = undefined
            }
        } else if (ct.includes('application/x-www-form-urlencoded')) {
            body = new URLSearchParams(req.body as any).toString()
        } else {
            // Raw body fallback
            body = (req as any).rawBody ?? JSON.stringify(req.body)
        }
    }

    try {
        const upstream = await fetch(url, { method, headers, body })

        // Forward status code
        res.status(upstream.status)

        // Forward content-type header
        const upstreamCt = upstream.headers.get('content-type')
        if (upstreamCt) res.set('Content-Type', upstreamCt)

        // Forward response body
        const responseText = await upstream.text()
        res.send(responseText)
    } catch (err: any) {
        logger.error(`Proxy ${method} ${url} failed: ${err?.message}`)
        res.status(502).json({ error: 'Service unavailable', detail: err?.message })
    }
}

/** Build the downstream path from the original request URL, stripping the gateway prefix. */
export function stripPrefix(originalUrl: string, prefix: string): string {
    const idx = originalUrl.indexOf(prefix)
    if (idx === -1) return originalUrl
    return originalUrl.slice(idx + prefix.length) || '/'
}
