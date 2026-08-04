import { checkPassword, PASSWORD_MIN_LENGTH } from './password-policy';

describe('checkPassword', () => {
  const good = 'Kovai#Ward42x';

  it('accepts a password meeting every rule', () => {
    const r = checkPassword(good);
    expect(r.ok).toBe(true);
    expect(r.problems).toEqual([]);
    expect(r.score).toBeGreaterThanOrEqual(3);
  });

  it('reports every failing rule at once, not the first', () => {
    // Short, no uppercase, no digit, no symbol.
    const r = checkPassword('abcdef');
    expect(r.ok).toBe(false);
    expect(r.problems.length).toBeGreaterThan(3);
  });

  describe('character classes', () => {
    it.each([
      ['no lowercase', 'KOVAI#WARD42X', 'Include a lowercase letter'],
      ['no uppercase', 'kovai#ward42x', 'Include an uppercase letter'],
      ['no digit', 'Kovai#WardXyzP', 'Include a digit'],
      ['no symbol', 'KovaiWard42xyz', 'Include a symbol'],
    ])('rejects %s', (_label, pw, expected) => {
      const r = checkPassword(pw);
      expect(r.ok).toBe(false);
      expect(r.problems).toContain(expected);
    });
  });

  describe('length', () => {
    it(`rejects anything under ${PASSWORD_MIN_LENGTH} characters`, () => {
      const r = checkPassword('Ab1#efgh'); // 8
      expect(r.problems).toContain(`Use at least ${PASSWORD_MIN_LENGTH} characters`);
    });

    it('rejects an absurdly long password rather than hashing it', () => {
      const r = checkPassword(`${'Aa1#'.repeat(40)}`);
      expect(r.problems).toContain('Use no more than 128 characters');
    });
  });

  describe('weak shapes', () => {
    it('rejects a common password even in mixed case', () => {
      expect(checkPassword('Password123').ok).toBe(false);
      expect(checkPassword('Panchayat123').ok).toBe(false);
    });

    it('scores a common password at zero however long it is', () => {
      expect(checkPassword('password123').score).toBe(0);
    });

    it('rejects a single character repeated, which passes length alone', () => {
      const r = checkPassword('aaaaaaaaaaaa');
      expect(r.ok).toBe(false);
      expect(r.problems).toContain('Do not repeat a single character');
      expect(r.score).toBe(0);
    });

    it('rejects four or more of the same character in a row', () => {
      const r = checkPassword('Koaaaavai#42x');
      expect(r.problems).toContain(
        'Avoid repeating the same character four or more times',
      );
    });

    it.each(['Kovai1234#xy', 'Kovaiqwer#12X'])(
      'rejects the keyboard or number run in %s',
      (pw) => {
        expect(checkPassword(pw).problems).toContain(
          'Avoid keyboard or number runs like 1234 or qwer',
        );
      },
    );
  });

  describe('email reuse', () => {
    // The single most common choice when a whole office is provisioned at once.
    it('rejects a password built out of the account name', () => {
      const r = checkPassword('Registrar#42x', {
        email: 'registrar.annur@example.gov.in',
      });
      expect(r.ok).toBe(false);
      expect(r.problems).toContain(
        'Do not build the password out of your email address',
      );
    });

    it('matches the local part ignoring its punctuation', () => {
      const r = checkPassword('Xregistrarannur#4A', {
        email: 'registrar.annur@example.gov.in',
      });
      expect(r.problems).toContain(
        'Do not build the password out of your email address',
      );
    });

    it('ignores a local part too short to be a real signal', () => {
      // "je" appearing inside a password says nothing.
      expect(checkPassword('Kovai#jeWard42x', { email: 'je@x.gov.in' }).ok).toBe(
        true,
      );
    });

    it('allows an unrelated password on the same account', () => {
      expect(
        checkPassword(good, { email: 'registrar.annur@example.gov.in' }).ok,
      ).toBe(true);
    });
  });

  describe('reuse of the current password', () => {
    it('refuses the password already in use', () => {
      const r = checkPassword(good, { currentPassword: good });
      expect(r.ok).toBe(false);
      expect(r.problems).toContain('Choose a password you have not used before');
    });

    it('allows a different one', () => {
      expect(checkPassword(good, { currentPassword: 'Old#Passw0rdXy' }).ok).toBe(
        true,
      );
    });
  });

  describe('score', () => {
    it('rises with length and variety', () => {
      const short = checkPassword('Kovai#42xy').score;
      const long = checkPassword('Kovai#42xyWardOffice').score;
      expect(long).toBeGreaterThan(short);
    });

    it('never exceeds 4', () => {
      expect(checkPassword('Kovai#42xyWardOfficeAnnur!9').score).toBe(4);
    });

    it('is zero for an empty password', () => {
      expect(checkPassword('').score).toBe(0);
      expect(checkPassword('').ok).toBe(false);
    });
  });

  it('does not throw on a null-ish password', () => {
    expect(() => checkPassword(undefined as unknown as string)).not.toThrow();
    expect(checkPassword(undefined as unknown as string).ok).toBe(false);
  });
});
