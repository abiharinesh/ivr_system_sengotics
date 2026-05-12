import { normalizePhoneE164 } from './phone.util'

describe('normalizePhoneE164', () => {
    it('accepts a bare 10-digit Indian mobile', () => {
        expect(normalizePhoneE164('9876543210')).toBe('+919876543210')
    })

    it('accepts a leading-zero 11-digit number', () => {
        expect(normalizePhoneE164('09876543210')).toBe('+919876543210')
    })

    it('accepts a 91-prefixed 12-digit number', () => {
        expect(normalizePhoneE164('919876543210')).toBe('+919876543210')
    })

    it('accepts spaced and dashed formats', () => {
        expect(normalizePhoneE164('+91 98765-43210')).toBe('+919876543210')
        expect(normalizePhoneE164('98765 43210')).toBe('+919876543210')
    })

    it('rejects empty input', () => {
        expect(() => normalizePhoneE164('')).toThrow()
        expect(() => normalizePhoneE164(null as unknown as string)).toThrow()
    })

    it('rejects landline-style first digit', () => {
        expect(() => normalizePhoneE164('1234567890')).toThrow()
    })

    it('rejects too short / too long', () => {
        expect(() => normalizePhoneE164('123')).toThrow()
        expect(() => normalizePhoneE164('98765432101234')).toThrow()
    })
})
