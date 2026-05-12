/**
 * Number-to-words helpers for Indian rupees, in English and a Tamil
 * (Tanglish/Romanized + Tamil-script) form suitable for government forms.
 */

const ONES = [
    'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine',
    'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen',
    'seventeen', 'eighteen', 'nineteen',
]
const TENS = ['', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety']

function inWordsEnUnder1000(n: number): string {
    if (n === 0) return ''
    if (n < 20) return ONES[n]
    if (n < 100) {
        const t = Math.floor(n / 10)
        const o = n % 10
        return TENS[t] + (o ? '-' + ONES[o] : '')
    }
    const h = Math.floor(n / 100)
    const r = n % 100
    return ONES[h] + ' hundred' + (r ? ' ' + inWordsEnUnder1000(r) : '')
}

/** Indian-system number to English words (lakh, crore). Integer rupees only. */
export function rupeesInWordsEn(amount: number): string {
    if (!Number.isFinite(amount)) return ''
    const n = Math.round(amount)
    if (n === 0) return 'Zero rupees only'
    let num = Math.abs(n)
    const parts: string[] = []
    const crore = Math.floor(num / 10000000); num %= 10000000
    const lakh = Math.floor(num / 100000);   num %= 100000
    const thousand = Math.floor(num / 1000); num %= 1000
    const rest = num
    if (crore) parts.push(inWordsEnUnder1000(crore) + ' crore')
    if (lakh) parts.push(inWordsEnUnder1000(lakh) + ' lakh')
    if (thousand) parts.push(inWordsEnUnder1000(thousand) + ' thousand')
    if (rest) parts.push(inWordsEnUnder1000(rest))
    const sign = n < 0 ? 'minus ' : ''
    const body = parts.join(' ').replace(/\s+/g, ' ').trim()
    return (sign + body.charAt(0).toUpperCase() + body.slice(1) + ' rupees only').trim()
}

const TA_DIGITS = ['பூஜ்யம்', 'ஒன்று', 'இரண்டு', 'மூன்று', 'நான்கு', 'ஐந்து', 'ஆறு', 'ஏழு', 'எட்டு', 'ஒன்பது']
const TA_TEENS = ['பத்து', 'பதினொன்று', 'பன்னிரண்டு', 'பதிமூன்று', 'பதினான்கு', 'பதினைந்து', 'பதினாறு', 'பதினேழு', 'பதினெட்டு', 'பத்தொன்பது']
const TA_TENS = ['', '', 'இருபது', 'முப்பது', 'நாற்பது', 'ஐம்பது', 'அறுபது', 'எழுபது', 'எண்பது', 'தொண்ணூறு']

function taUnder100(n: number): string {
    if (n < 10) return TA_DIGITS[n]
    if (n < 20) return TA_TEENS[n - 10]
    const t = Math.floor(n / 10)
    const o = n % 10
    return o ? `${TA_TENS[t]} ${TA_DIGITS[o]}` : TA_TENS[t]
}

function taUnder1000(n: number): string {
    if (n < 100) return taUnder100(n)
    const h = Math.floor(n / 100)
    const r = n % 100
    const head = h === 1 ? 'நூறு' : `${TA_DIGITS[h]} நூறு`
    return r ? `${head} ${taUnder100(r)}` : head
}

/** Tamil-script approximation of rupees-in-words. Coarse but readable on forms. */
export function rupeesInWordsTa(amount: number): string {
    if (!Number.isFinite(amount)) return ''
    const n = Math.round(amount)
    if (n === 0) return 'பூஜ்யம் ரூபாய் மட்டும்'
    let num = Math.abs(n)
    const parts: string[] = []
    const crore = Math.floor(num / 10000000); num %= 10000000
    const lakh = Math.floor(num / 100000);   num %= 100000
    const thousand = Math.floor(num / 1000); num %= 1000
    const rest = num
    if (crore) parts.push(`${taUnder1000(crore)} கோடி`)
    if (lakh) parts.push(`${taUnder1000(lakh)} லட்சம்`)
    if (thousand) parts.push(`${taUnder1000(thousand)} ஆயிரம்`)
    if (rest) parts.push(taUnder1000(rest))
    return `${parts.join(' ')} ரூபாய் மட்டும்`
}
