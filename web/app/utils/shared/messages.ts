import { SUPPORT_EMAIL } from './constants';

export const LOGIN_FAILED_MESSAGE =
  "Je e-mailadres of wachtwoord klopt niet. Probeer het opnieuw of kies 'Wachtwoord vergeten?'.";
export const INVALID_EMAIL_CODE_MESSAGE =
  'Deze code klopt niet of is verlopen. Vraag een nieuwe code aan.';
export const REQUESTED_TOO_SOON_MESSAGE =
  'Je hebt net al een code aangevraagd. Wacht 60 seconden en probeer het opnieuw.';
export const PASSWORDS_DIFFER_MESSAGE =
  'De wachtwoorden zijn niet hetzelfde. Vul je nieuwe wachtwoord opnieuw in.';
export const PASSWORD_RULES_NOT_MET_MESSAGE =
  'Je wachtwoord voldoet nog niet aan alle eisen.';
export const INVALID_LINK_MESSAGE = `Deze link klopt niet of is verlopen. Vraag een nieuwe link aan of neem contact op via ${SUPPORT_EMAIL}.`;
export const UNKNOWN_ERROR_MESSAGE = 'Er ging iets mis. Probeer het later opnieuw.';
export const WRONG_AUTHENTICATOR_CODE_MESSAGE =
  'Deze code klopt niet of is verlopen. Gebruik de nieuwste code uit je authenticator-app en probeer het opnieuw.';
export const TOO_MANY_ATTEMPTS_MESSAGE =
  'Je hebt te vaak geprobeerd. Wacht even en probeer het opnieuw.';
export const NO_CONNECTION_MESSAGE =
  'We konden PAVE niet bereiken. Controleer je internetverbinding en probeer het opnieuw.';
export const INSUFFICIENT_AAL_MESSAGE =
  'Bevestig eerst met een code uit je authenticator-app dat jij het bent.';
export const SAME_PASSWORD_MESSAGE =
  'Dit is je huidige wachtwoord. Kies een ander wachtwoord.';

export const AUTHENTICATOR_HEADING = 'Open je authenticator-app';
export const AUTHENTICATOR_INSTRUCTION = 'Vul de code uit de app in.';
export const AUTHENTICATOR_CODE_HINT = 'Je krijgt deze code niet per e-mail.';
export const AUTHENTICATOR_CODE_LABEL = 'Code uit je authenticator-app';
export const EMAIL_CODE_LABEL = 'Code uit je e-mail';

export const RESET_STEPS = ['E-mail', 'Code uit e-mail', 'Authenticator-code', 'Nieuw wachtwoord'];
export const RESET_STEPS_WITHOUT_AUTHENTICATOR = ['E-mail', 'Code uit e-mail', 'Nieuw wachtwoord'];

export const LOGIN_INSTRUCTION = 'Vul je e-mailadres en wachtwoord in.';
export const MFA_SETUP_INSTRUCTION = 'Volg de 3 stappen hieronder.';
export const RESET_EMAIL_INSTRUCTION = 'Vul je e-mailadres in.';
export const RESET_CODE_INSTRUCTION = 'Vul de code uit je e-mail in.';
export const NEW_PASSWORD_INSTRUCTION = 'Let op de eisen hieronder.';
export const WRONG_EMAIL_PROMPT = 'Verkeerd e-mailadres?';
export const WRONG_EMAIL_LINK = 'Terug';
export const RESEND_EMAIL_CODE_LABEL = 'Nieuwe code versturen';
export const EMAIL_CODE_RESENT_MESSAGE = 'We hebben een nieuwe code naar je e-mail gestuurd.';

export function getResetCodeSentMessage(maskedEmail: string) {
  return `Als er een account bestaat voor ${maskedEmail}, hebben we daar een code naartoe gestuurd.`;
}

export function getResendCountdownLabel(secondsLeft: number) {
  return `Nieuwe code versturen kan over ${secondsLeft} seconden`;
}

export const PASSWORD_RULES_ALL_MET_MESSAGE = 'Je wachtwoord voldoet aan alle eisen';
export const PASSWORDS_MATCH_MESSAGE = 'De wachtwoorden zijn hetzelfde.';
export const PASSWORDS_NOT_EQUAL_MESSAGE = 'De wachtwoorden zijn niet gelijk.';
export const REPEAT_PASSWORD_HINT = 'Typ je wachtwoord nog een keer. Plakken kan hier niet.';
export const CAPS_LOCK_ON_MESSAGE = 'Caps Lock staat aan';

export function getRemainingRulesMessage(remainingCount: number) {
  if (remainingCount === 0) return PASSWORD_RULES_ALL_MET_MESSAGE;
  if (remainingCount === 1) return 'Nog 1 eis te gaan';
  return `Nog ${remainingCount} eisen te gaan`;
}
