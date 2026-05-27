import { Logger } from '@nestjs/common'
import * as https from 'https'
import * as http from 'http'
import FormData from 'form-data'

/**
 * Pluggable HTML -> PDF renderer.
 *
 * - Local / Docker: full `puppeteer` + downloaded Chrome (see scripts or
 *   `npx puppeteer browsers install chrome` if .npmrc skips download).
 * - Vercel serverless: Gotenberg (external service) via `form-data` npm pkg.
 */
const logger = new Logger('TenderPdfRenderer')
let cachedBrowserPromise: Promise<any> | null = null

// Read lazily so that the env var set on Vercel is always picked up at call time.
function getGotenbergBaseUrl(): string {
    return (process.env.GOTENBERG_URL ?? '').trim().replace(/\/+$/, '')
}

function isVercelRuntime(): boolean {
    return Boolean(process.env.VERCEL) || process.env.AWS_LAMBDA_FUNCTION_NAME != null
}

async function dynamicImport(moduleId: string): Promise<any | null> {
    try {
        const mod = await (new Function('m', 'return import(m)'))(moduleId)
        return mod?.default ?? mod ?? null
    } catch {
        return null
    }
}

async function loadPuppeteer(): Promise<any | null> {
    if (isVercelRuntime()) {
        return dynamicImport('puppeteer-core')
    }
    const full = await dynamicImport('puppeteer')
    if (full) return full
    return dynamicImport('puppeteer-core')
}

/**
 * Send an HTML string to Gotenberg using Node's native http/https + form-data npm package.
 * This avoids relying on browser globals (FormData, Blob, fetch) that may not
 * be available in all Node.js versions on Vercel serverless.
 */
function postToGotenberg(url: string, form: FormData, timeoutMs: number): Promise<Buffer> {
    return new Promise((resolve, reject) => {
        const parsed = new URL(url)
        const transport = parsed.protocol === 'https:' ? https : http
        const headers = form.getHeaders()

        const req = transport.request(
            {
                hostname: parsed.hostname,
                port: parsed.port || (parsed.protocol === 'https:' ? 443 : 80),
                path: parsed.pathname + parsed.search,
                method: 'POST',
                headers,
            },
            (res) => {
                const chunks: Buffer[] = []
                res.on('data', (chunk: Buffer) => chunks.push(chunk))
                res.on('end', () => {
                    const body = Buffer.concat(chunks)
                    if (res.statusCode && res.statusCode >= 200 && res.statusCode < 300) {
                        resolve(body)
                    } else {
                        reject(new Error(`Gotenberg HTTP ${res.statusCode}: ${body.toString('utf8').slice(0, 300)}`))
                    }
                })
                res.on('error', reject)
            }
        )

        req.setTimeout(timeoutMs, () => {
            req.destroy(new Error(`Gotenberg request timed out after ${timeoutMs}ms`))
        })

        req.on('error', reject)
        form.pipe(req)
    })
}

async function renderWithGotenberg(html: string): Promise<Buffer | null> {
    const gotenbergBaseUrl = getGotenbergBaseUrl()
    if (!gotenbergBaseUrl) {
        logger.warn('GOTENBERG_URL is not set — skipping Gotenberg PDF render')
        return null
    }
    const timeoutMs = Number(process.env.GOTENBERG_TIMEOUT_MS ?? 45_000)
    const endpoint = `${gotenbergBaseUrl}/forms/chromium/convert/html`
    logger.log(`Sending PDF render request to Gotenberg: ${endpoint}`)
    try {
        const form = new FormData()
        form.append('files', Buffer.from(html, 'utf8'), {
            filename: 'index.html',
            contentType: 'text/html',
        })
        form.append('printBackground', 'true')
        form.append('marginTop', '0.79')
        form.append('marginBottom', '0.79')
        form.append('marginLeft', '0.59')
        form.append('marginRight', '0.59')
        const pdfBuf = await postToGotenberg(endpoint, form, Number.isFinite(timeoutMs) ? timeoutMs : 45_000)
        logger.log('Gotenberg PDF render succeeded')
        return pdfBuf
    } catch (err: any) {
        logger.warn(`Gotenberg render failed: ${err?.message ?? err}`)
        return null
    }
}

async function launchBrowser(): Promise<any | null> {
    const puppeteer = await loadPuppeteer()
    if (!puppeteer) return null

    const baseArgs = ['--no-sandbox', '--disable-setuid-sandbox', '--disable-gpu']

    if (isVercelRuntime()) {
        const chromium = await dynamicImport('@sparticuz/chromium')
        if (!chromium) {
            logger.warn('@sparticuz/chromium not installed; PDF generation unavailable on Vercel')
            return null
        }
        try {
            const executablePath = await chromium.executablePath()
            return await puppeteer.launch({
                args: [...(chromium.args ?? []), ...baseArgs],
                defaultViewport: chromium.defaultViewport ?? { width: 1280, height: 720 },
                executablePath,
                headless: chromium.headless ?? true,
            })
        } catch (err: any) {
            logger.warn(`Vercel Chromium launch failed: ${err?.message ?? err}`)
            return null
        }
    }

    try {
        return await puppeteer.launch({
            headless: true,
            args: baseArgs,
            timeout: 120_000,
        })
    } catch (err: any) {
        logger.warn(`Puppeteer launch failed: ${err?.message ?? err}`)
        return null
    }
}

async function getBrowser(): Promise<any | null> {
    if (cachedBrowserPromise) return cachedBrowserPromise
    cachedBrowserPromise = launchBrowser().then((browser) => {
        if (!browser) cachedBrowserPromise = null
        return browser
    })
    return cachedBrowserPromise
}

export async function renderHtmlToPdfBuffer(html: string): Promise<Buffer | null> {
    const gotenbergPdf = await renderWithGotenberg(html)
    if (gotenbergPdf) return gotenbergPdf

    const browser = await getBrowser()
    if (!browser) return null
    let page: any | null = null
    try {
        page = await browser.newPage()
        await page.setContent(html, { waitUntil: 'domcontentloaded', timeout: 30_000 })
        const pdf = await page.pdf({
            format: 'A4',
            printBackground: true,
            margin: { top: '20mm', bottom: '20mm', left: '15mm', right: '15mm' },
        })
        return Buffer.from(pdf)
    } catch (err: any) {
        logger.warn(`Puppeteer render failed: ${err?.message ?? err}`)
        return null
    } finally {
        if (page) {
            try {
                await page.close()
            } catch (_) {
                /* ignore */
            }
        }
    }
}
