import { SUPPORT_EMAIL } from './constants';

export const LOGIN_FAILED_MESSAGE =
  "Je e-mailadres of wachtwoord klopt niet. Probeer het opnieuw of kies 'Wachtwoord vergeten?'.";
export const INVALID_EMAIL_CODE_MESSAGE =
  'Deze code klopt niet of is verlopen. Vraag een nieuwe code aan.';
export const REQUESTED_TOO_SOON_MESSAGE =
  'Je hebt net al een code aangevraagd. Wacht 60 seconden en probeer het opnieuw.';
export const RESET_REQUESTED_MESSAGE =
  'Als er een account bestaat voor dit e-mailadres, hebben we een code gestuurd.';
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
