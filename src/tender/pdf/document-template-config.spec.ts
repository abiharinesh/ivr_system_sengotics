import {
    deepMergeConfig,
    getMergedLayout,
    mergeFieldOverrides,
    sanitizeTemplateConfig,
} from './document-template-config'

describe('document-template-config', () => {
    it('deep-merges nested layout fields', () => {
        const merged = deepMergeConfig(
            { page: { paddingPx: 24, maxWidthPx: 720 }, header: { align: 'center' } },
            { page: { paddingPx: 32 } },
        )
        expect(merged.page?.paddingPx).toBe(32)
        expect(merged.page?.maxWidthPx).toBe(720)
        expect(merged.header?.align).toBe('center')
    })

    it('merges field override defaults before document overrides', () => {
        const out = mergeFieldOverrides(
            { editor_text_en: 'Default', __canvas_layers: [] },
            { editor_text_en: 'Doc specific' },
        )
        expect(out.editor_text_en).toBe('Doc specific')
    })

    it('getMergedLayout applies global then panchayat', () => {
        const layout = getMergedLayout('rfq', { rfq: { header: { align: 'right' } } }, {
            rfq: { body: { align: 'justify' } },
        })
        expect(layout.header?.align).toBe('right')
        expect(layout.body?.align).toBe('justify')
    })

    it('sanitizeTemplateConfig clamps padding', () => {
        const c = sanitizeTemplateConfig({ page: { paddingPx: 999, maxWidthPx: 500 } })
        expect(c.page?.paddingPx).toBe(80)
        expect(c.page?.maxWidthPx).toBe(500)
    })
})
