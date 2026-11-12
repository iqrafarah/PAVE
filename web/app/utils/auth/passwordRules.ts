export const MIN_PASSWORD_LENGTH = 12;

const UPPERCASE_LETTER = /\p{Lu}/u;
const LOWERCASE_LETTER = /\p{Ll}/u;
const DIGIT = /\p{N}/u;
// Anything that is not a letter, digit or space, so a space does not count as a symbol (the same as on iOS).
const SYMBOL = /[^\p{L}\p{N}\s]/u;

export interface PasswordRule {
  label: string;
  isMet: boolean;
}

export function getPasswordRules(password: string): PasswordRule[] {
  const hasUpperAndLowercase =
    UPPERCASE_LETTER.test(password) && LOWERCASE_LETTER.test(password);

  return [
    {
      label: `Minimaal ${MIN_PASSWORD_LENGTH} tekens`,
      isMet: password.length >= MIN_PASSWORD_LENGTH,
    },
    { label: 'Hoofdletters en kleine letters', isMet: hasUpperAndLowercase },
    { label: 'Minimaal één cijfer', isMet: DIGIT.test(password) },
    { label: 'Minimaal één symbool', isMet: SYMBOL.test(password) },
  ];
}

export type PasswordFieldState = 'incomplete' | 'valid';
