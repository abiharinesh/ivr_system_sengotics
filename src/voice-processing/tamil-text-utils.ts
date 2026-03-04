/**
 * Tamil/Tanglish text processing utilities.
 *
 * These functions clean, normalize, and canonicalize Tamil speech-to-text
 * output to maximize landmark matching accuracy.
 */

// ── Tamil Filler Words ─────────────────────────────────────────────────────────
// Common speech fillers and particles that don't carry location meaning.
// These appear in natural speech but confuse AI extraction.
const TAMIL_FILLERS = [
    // Tamil speech fillers
    'athe', 'athu', 'entha', 'antha', 'ithu', 'athanala',
    // Sentence-ending particles
    'pa', 'da', 'di', 'ya', 'la', 'ma', 'nga', 'nu', 'ne', 'le',
    'thaan', 'than', 'dhan',
    // Hesitation fillers
    'mmm', 'hmm', 'aaa', 'eee', 'um', 'uh', 'ah',
    // Common Tamil connectors that don't help matching
    'iruku', 'irukku', 'illa', 'ille', 'aana', 'aanal',
    'aprom', 'appuram', 'appo', 'ippo',
    // Very common but meaningless in landmark context
    'inga', 'ange', 'enga',  // here, there, where (too vague)
    'oru', 'onnu',           // one (article)
    'romba', 'ramba',        // very/much
    'konjam',                // a little
    'nalla', 'nallave',      // well/good
]

// ── Tanglish Canonical Mappings ────────────────────────────────────────────────
// Maps variant spellings to a single canonical form.
// Key: canonical form. Values: known variants (including the canonical itself).
const TANGLISH_CANONICAL_MAP: Record<string, string[]> = {
    // Temples / Religious
    'mariamman': ['mariyamman', 'maria man', 'maariamman', 'mariyaman', 'marriamman', 'mariam man'],
    'vinayagar': ['pillayar', 'pillaiyar', 'pilleyar', 'ganesh', 'ganapathy', 'vinayakar'],
    'murugan': ['muruga', 'murugar', 'subramani', 'subramaniya', 'murugen'],
    'kovil': ['koil', 'koyil', 'kovel', 'temple'],
    'pallivasal': ['palli vasal', 'pallivaasal', 'mosque', 'masjid', 'masjith'],
    'church': ['cherch', 'sarch', 'chirch'],

    // Landmarks
    'bus stand': ['bus stop', 'bustand', 'bus stant', 'bas stand', 'bas stop'],
    'school': ['palli', 'pallikoodam', 'palli koodam', 'skool', 'schol'],
    'hospital': ['aaspatri', 'aspathri', 'hospitl', 'aaspathiri', 'aaspitri'],
    'ration kadai': ['ration shop', 'ration store', 'rasan kadai', 'ration kade'],
    'petrol bunk': ['petrol pump', 'petrol station', 'petral bunk', 'petral pump'],
    'tea kadai': ['tea shop', 'tea stall', 'tee kadai', 'chai kadai', 'tea kade'],

    // Nature
    'aalamaram': ['aal maram', 'aal marm', 'banyan tree', 'banyan', 'ala maram', 'aalamram'],
    'kulam': ['pond', 'lake', 'kulem', 'kulm', 'kolam'],
    'thanni tank': ['water tank', 'tanni tank', 'thani tank', 'tank'],
    'maram': ['tree', 'marm', 'marem'],

    // Directional
    'pakkathula': ['pakkathla', 'pakathula', 'pakkam', 'pakkathu', 'pakkthula', 'pakam', 'pakkala'],
    'kitta': ['kitte', 'kita', 'kittha', 'kithe'],
    'ethirla': ['ethire', 'ethir', 'opposite', 'ethirile', 'ethirula'],
    'keezha': ['keezhe', 'keezh', 'kizha', 'kizhe', 'under', 'below'],
    'mela': ['meele', 'mel', 'above', 'mele'],
    'aruge': ['arugil', 'arugula', 'near'],

    // Infrastructure
    'panchayat': ['panchayathu', 'panchayath', 'panchayatu', 'panjayat', 'panjayathu'],
}

// Build a reverse map: variant → canonical
const VARIANT_TO_CANONICAL: Map<string, string> = new Map()
for (const [canonical, variants] of Object.entries(TANGLISH_CANONICAL_MAP)) {
    VARIANT_TO_CANONICAL.set(canonical.toLowerCase(), canonical.toLowerCase())
    for (const variant of variants) {
        VARIANT_TO_CANONICAL.set(variant.toLowerCase(), canonical.toLowerCase())
    }
}

/**
 * Strip Tamil filler words and hesitation sounds from a transcript.
 * Preserves meaningful words (landmarks, complaint types, directions).
 *
 * "athe... entha... Mariamman kovil kitta irukke pa... light eraiyala da"
 * → "Mariamman kovil kitta light eraiyala"
 */
export function cleanTranscript(transcript: string): string {
    if (!transcript) return ''

    let cleaned = transcript
        // Remove ellipsis and excessive dots
        .replace(/\.{2,}/g, ' ')
        // Remove standalone punctuation
        .replace(/[,;:!?]/g, ' ')
        // Normalize whitespace
        .replace(/\s+/g, ' ')
        .trim()

    // Remove filler words (word-boundary aware)
    const words = cleaned.split(' ')
    const filtered = words.filter(word => {
        const lower = word.toLowerCase().replace(/[^a-z]/g, '')
        return lower.length > 0 && !TAMIL_FILLERS.includes(lower)
    })

    return filtered.join(' ').trim()
}

/**
 * Normalize Tanglish spelling variations to canonical forms.
 * Handles multi-word phrases (e.g., "bus stand", "aal maram").
 *
 * "mariyamman koil pakathula" → "mariamman kovil pakkathula"
 * "bus stop kitte" → "bus stand kitta"
 */
export function normalizeTanglish(text: string): string {
    if (!text) return ''

    let result = text.toLowerCase().trim()

    // First pass: normalize multi-word phrases (longest match first)
    const multiWordPhrases = Object.entries(TANGLISH_CANONICAL_MAP)
        .flatMap(([canonical, variants]) =>
            variants
                .filter(v => v.includes(' '))
                .map(v => ({ variant: v.toLowerCase(), canonical: canonical.toLowerCase() }))
        )
        .sort((a, b) => b.variant.length - a.variant.length) // longest first

    for (const { variant, canonical } of multiWordPhrases) {
        if (result.includes(variant)) {
            result = result.replace(new RegExp(variant.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g'), canonical)
        }
    }

    // Second pass: normalize single words
    const words = result.split(/\s+/)
    const normalized = words.map(word => {
        const canonical = VARIANT_TO_CANONICAL.get(word)
        return canonical || word
    })

    return normalized.join(' ')
}

/**
 * Full pre-processing pipeline: clean fillers → normalize Tanglish.
 * Use this before sending to the LLM or for string matching.
 */
export function preprocessTranscript(transcript: string): string {
    const cleaned = cleanTranscript(transcript)
    return normalizeTanglish(cleaned)
}
