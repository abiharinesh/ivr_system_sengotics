import { Logger } from '@nestjs/common'

/**
 * Pluggable HTML -> PDF renderer.
 *
 * - Local / Docker: full `puppeteer` + downloaded Chrome (see scripts or
 *   `npx puppeteer browsers install chrome` if .npmrc skips download).
 * - Vercel serverless: `puppeteer-core` + `@sparticuz/chromium`.
 */
const logger = new Logger('TenderPdfRenderer')
let cachedBrowserPromise: Promise<any> | null = null
const gotenbergBaseUrl = (process.env.GOTENBERG_URL ?? '').trim().replace(/\/+$/, '')

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

async function renderWithGotenberg(html: string): Promise<Buffer | null> {
    if (!gotenbergBaseUrl) return null
    const FormCtor: any = (globalThis as any).FormData
    const BlobCtor: any = (globalThis as any).Blob
    if (!FormCtor || !BlobCtor || typeof fetch !== 'function') {
        logger.warn('Gotenberg configured, but FormData/Blob/fetch are unavailable in this runtime')
        return null
    }
    const controller = new AbortController()
    const timeoutMs = Number(process.env.GOTENBERG_TIMEOUT_MS ?? 45_000)
    const timeout = setTimeout(() => controller.abort(), Number.isFinite(timeoutMs) ? timeoutMs : 45_000)
    try {
        const form = new FormCtor()
        form.append('files', new BlobCtor([html], { type: 'text/html' }), 'index.html')
        form.append('printBackground', 'true')
        form.append('marginTop', '0.79')
        form.append('marginBottom', '0.79')
        form.append('marginLeft', '0.59')
        form.append('marginRight', '0.59')
        const res = await fetch(`${gotenbergBaseUrl}/forms/chromium/convert/html`, {
            method: 'POST',
            body: form,
            signal: controller.signal,
        })
        if (!res.ok) {
            logger.warn(`Gotenberg render failed: HTTP ${res.status}`)
            return null
        }
        const bytes = await res.arrayBuffer()
        return Buffer.from(bytes)
    } catch (err: any) {
        logger.warn(`Gotenberg render failed: ${err?.message ?? err}`)
        return null
    } finally {
        clearTimeout(timeout)
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
