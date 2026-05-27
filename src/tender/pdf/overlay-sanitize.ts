import { BadRequestException } from '@nestjs/common'

export const MAX_OVERLAY_SVG_CHARS = 500_000
export const MAX_FABRIC_SCENE_JSON_CHARS = 200_000

/** Strip scripts, event handlers, and external refs from Fabric-exported SVG. */
export function sanitizeOverlaySvg(raw: unknown): string | null {
    if (raw == null) return null
    const s = String(raw).trim()
    if (!s) return null
    if (s.length > MAX_OVERLAY_SVG_CHARS) {
        throw new BadRequestException(`overlay_svg exceeds ${MAX_OVERLAY_SVG_CHARS} characters`)
    }
    const lower = s.toLowerCase()
    if (!lower.includes('<svg')) {
        throw new BadRequestException('overlay_svg must contain an SVG root element')
    }
    if (/<script\b/i.test(s)) {
        throw new BadRequestException('overlay_svg must not contain script elements')
    }
    if (/\bon\w+\s*=/i.test(s)) {
        throw new BadRequestException('overlay_svg must not contain event handlers')
    }
    if (/(?:href|xlink:href)\s*=\s*["']https?:/i.test(s)) {
        throw new BadRequestException('overlay_svg must not contain external URLs')
    }
    return s
}

export function sanitizeFabricScene(raw: unknown): Record<string, unknown> | null {
    if (raw == null) return null
    let obj: unknown = raw
    if (typeof raw === 'string') {
        if (raw.length > MAX_FABRIC_SCENE_JSON_CHARS) {
            throw new BadRequestException(`fabric_scene exceeds ${MAX_FABRIC_SCENE_JSON_CHARS} characters`)
        }
        try {
            obj = JSON.parse(raw)
        } catch {
            throw new BadRequestException('fabric_scene must be valid JSON')
        }
    } else {
        const serialized = JSON.stringify(raw)
        if (serialized.length > MAX_FABRIC_SCENE_JSON_CHARS) {
            throw new BadRequestException(`fabric_scene exceeds ${MAX_FABRIC_SCENE_JSON_CHARS} characters`)
        }
    }
    if (obj == null || typeof obj !== 'object' || Array.isArray(obj)) {
        throw new BadRequestException('fabric_scene must be a JSON object')
    }
    return obj as Record<string, unknown>
}

export function sanitizeTemplateDefaults(raw: unknown): Record<string, unknown> | undefined {
    if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return undefined
    const input = raw as Record<string, unknown>
    const out: Record<string, unknown> = {}

    if (input.editor_text_ta != null) {
        out.editor_text_ta = String(input.editor_text_ta).slice(0, 5000)
    }
    if (input.editor_text_en != null) {
        out.editor_text_en = String(input.editor_text_en).slice(0, 5000)
    }
    if (Array.isArray(input.__canvas_layers)) {
        out.__canvas_layers = input.__canvas_layers
    }
    const fabric = sanitizeFabricScene(input.fabric_scene)
    if (fabric) out.fabric_scene = fabric
    const svg = sanitizeOverlaySvg(input.overlay_svg)
    if (svg) out.overlay_svg = svg

    return Object.keys(out).length ? out : undefined
}
