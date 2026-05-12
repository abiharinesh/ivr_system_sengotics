import { Logger } from '@nestjs/common'

/**
 * Pluggable HTML -> PDF renderer.
 *
 * Default behaviour:
 *  - If puppeteer is installed (peer dependency), launch it and produce a PDF.
 *  - Otherwise, return null. Callers should still write the HTML version so
 *    the document is reviewable in a browser; PDF promotion can happen later
 *    via a dedicated worker.
 *
 * On serverless deployments add `puppeteer-core` + `@sparticuz/chromium` and
 * adapt `loadPuppeteer()` accordingly.
 */
const logger = new Logger('TenderPdfRenderer')
let cachedBrowserPromise: Promise<any> | null = null

async function loadPuppeteer(): Promise<any | null> {
    try {
        // Use Function() to dodge static type-resolution if the package isn't installed.
        const mod = await (new Function('m', 'return import(m)'))('puppeteer').catch(() => null)
        if (mod) return mod.default ?? mod
    } catch (_e) { /* fall through */ }
    try {
        const mod = await (new Function('m', 'return import(m)'))('puppeteer-core').catch(() => null)
        if (mod) return mod.default ?? mod
    } catch (_e) { /* fall through */ }
    return null
}

async function getBrowser(): Promise<any | null> {
    if (cachedBrowserPromise) return cachedBrowserPromise
    cachedBrowserPromise = (async () => {
        const puppeteer = await loadPuppeteer()
        if (!puppeteer) return null
        try {
            return await puppeteer.launch({
                headless: true,
                args: ['--no-sandbox', '--disable-setuid-sandbox'],
            })
        } catch (err: any) {
            logger.warn(`Puppeteer launch failed: ${err?.message ?? err}`)
            cachedBrowserPromise = null
            return null
        }
    })()
    return cachedBrowserPromise
}

export async function renderHtmlToPdfBuffer(html: string): Promise<Buffer | null> {
    const browser = await getBrowser()
    if (!browser) return null
    let page: any | null = null
    try {
        page = await browser.newPage()
        await page.setContent(html, { waitUntil: 'networkidle0', timeout: 20000 })
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
            try { await page.close() } catch (_) {}
        }
    }
}
