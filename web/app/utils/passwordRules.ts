export const MIN_PASSWORD_LENGTH = 12;

const UPPERCASE_LETTER = /[A-Z]/;
const LOWERCASE_LETTER = /[a-z]/;
const DIGIT = /\d/;
const SYMBOL = /[^A-Za-z0-9]/;

export interface PasswordRule {
  label: string;
  isMet: boolean;
}

export function getPasswordRules(password: string): PasswordRule[] {
  const hasUpperAndLowercase =
    UPPERCASE_LETTER.test(password) && LOWERCASE_LETTER.test(password);
  const hasDigitAndSymbol = DIGIT.test(password) && SYMBOL.test(password);

  return [
    {
      label: `At least ${MIN_PASSWORD_LENGTH} characters`,
      isMet: password.length >= MIN_PASSWORD_LENGTH,
    },
    { label: 'Uppercase and lowercase letters', isMet: hasUpperAndLowercase },
    { label: 'At least one number and one symbol', isMet: hasDigitAndSymbol },
  ];
}
