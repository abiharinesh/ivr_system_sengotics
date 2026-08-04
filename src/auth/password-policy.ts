/**
 * What counts as an acceptable password.
 *
 * Pure and dependency-free so the rules are testable on their own and so the
 * same wording reaches the user from the API and from the client's live
 * strength meter — a form that accepts a password the server then rejects is
 * worse than no meter at all.
 */

/** Passwords seen often enough in Indian government deployments to matter. */
const COMMON = new Set([
  'password', 'password1', 'password123', 'passw0rd',
  'admin', 'admin123', 'administrator',
  '12345678', '123456789', '1234567890', 'qwerty123',
  'welcome', 'welcome1', 'welcome123',
  'india123', 'chennai123', 'tamilnadu', 'tamilnadu123',
  'letmein', 'iloveyou', 'abcd1234', 'test1234',
  'ooraatchi', 'ooraatchi123', 'panchayat', 'panchayat123',
  'municipality', 'commissioner',
]);

export interface PasswordCheck {
  ok: boolean;
  /** 0–4. Drives the client's strength bar. */
  score: number;
  /** Every rule the password fails, so the user can fix them in one pass. */
  problems: string[];
}

export const PASSWORD_MIN_LENGTH = 10;

/**
 * Grade a candidate password.
 *
 * [email] is used to reject passwords built out of the account name, which is
 * the single most common choice when a whole office is provisioned at once.
 */
export function checkPassword(
  password: string,
  opts: { email?: string; currentPassword?: string } = {},
): PasswordCheck {
  const problems: string[] = [];
  const pw = password ?? '';

  if (pw.length < PASSWORD_MIN_LENGTH) {
    problems.push(`Use at least ${PASSWORD_MIN_LENGTH} characters`);
  }
  if (pw.length > 128) {
    problems.push('Use no more than 128 characters');
  }
  if (!/[a-z]/.test(pw)) problems.push('Include a lowercase letter');
  if (!/[A-Z]/.test(pw)) problems.push('Include an uppercase letter');
  if (!/[0-9]/.test(pw)) problems.push('Include a digit');
  if (!/[^A-Za-z0-9]/.test(pw)) problems.push('Include a symbol');

  const lower = pw.toLowerCase();

  if (COMMON.has(lower)) {
    problems.push('That password is too common to be safe');
  }

  // "aaaaaaaaaa" clears every character-class rule above on its own.
  if (/^(.)\1+$/.test(pw) && pw.length > 0) {
    problems.push('Do not repeat a single character');
  }
  if (/(.)\1{3,}/.test(pw)) {
    problems.push('Avoid repeating the same character four or more times');
  }
  if (/(0123|1234|2345|3456|4567|5678|6789|abcd|qwer|asdf)/i.test(pw)) {
    problems.push('Avoid keyboard or number runs like 1234 or qwer');
  }

  const localPart = opts.email?.split('@')[0]?.toLowerCase() ?? '';
  if (localPart.length >= 4) {
    // Check the whole local part *and* each of its segments. An address like
    // "registrar.annur@…" makes both "registrarannur" and "registrar" obvious
    // choices, and the segment is the one people actually pick. Segments
    // shorter than four characters ("je", "ae") are too common as substrings
    // to mean anything.
    const candidates = [
      localPart.replace(/[^a-z0-9]/g, ''),
      ...localPart.split(/[^a-z0-9]+/),
    ].filter((s) => s.length >= 4);

    if (candidates.some((s) => lower.includes(s))) {
      problems.push('Do not build the password out of your email address');
    }
  }

  if (opts.currentPassword && pw === opts.currentPassword) {
    problems.push('Choose a password you have not used before');
  }

  // Score is about resilience, not about rule compliance, so it is computed
  // from what the password actually contains rather than from `problems`.
  let score = 0;
  if (pw.length >= PASSWORD_MIN_LENGTH) score++;
  if (pw.length >= 14) score++;
  const classes = [/[a-z]/, /[A-Z]/, /[0-9]/, /[^A-Za-z0-9]/].filter((r) =>
    r.test(pw),
  ).length;
  if (classes >= 3) score++;
  if (classes === 4) score++;
  if (COMMON.has(lower) || /^(.)\1+$/.test(pw)) score = 0;

  return {
    ok: problems.length === 0,
    score: Math.min(4, score),
    problems,
  };
}
