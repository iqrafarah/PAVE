export const DEVICES_TITLE = 'Ingelogde apparaten';
export const DEVICES_PATH = '/instellingen/apparaten';
export const DEVICES_INTRO = 'Hier zie je waar je met je PAVE-account bent ingelogd. Herken je een apparaat niet? Log het uit en wijzig je wachtwoord.';
export const DEVICES_THIS_DEVICE = 'Dit apparaat';
export const DEVICES_OTHER_DEVICES = 'Andere apparaten';
export const DEVICES_NO_OTHERS = 'Je bent nergens anders ingelogd.';
export const DEVICES_SIGN_OUT_ALL = 'Overal anders uitloggen';
export const DEVICES_SIGN_OUT_ALL_QUESTION = 'Uitloggen op alle andere apparaten?';
export const DEVICES_SIGN_OUT_MESSAGE = 'Op dat apparaat moet je daarna opnieuw inloggen. Is PAVE daar nu open, dan kan dat tot een uur duren.';
export const DEVICES_NOT_SET_UP_TITLE = 'Nog niet beschikbaar';
export const DEVICES_NOT_SET_UP_MESSAGE = 'Deze lijst werkt zodra PAVE er klaar voor is. Je kunt hieronder wel alvast overal anders uitloggen.';
export const DEVICES_LOAD_FAILED_TITLE = 'De lijst kon niet laden';
export const DEVICES_LOADING = 'Apparaten laden…';
export const DEVICES_RETRY = 'Opnieuw proberen';
export const DEVICES_NOW_ACTIVE = 'Nu actief';
export const DEVICES_SIGN_OUT_ON = (name: string) => `Uitloggen op ${name}`;
export const DEVICES_SIGN_OUT_QUESTION = (name: string) => `Uitloggen op ${name}?`;
export const DEVICES_ERRORS = {
  noConnection: 'Geen verbinding. Probeer het zo nog een keer.',
  notSignedIn: 'Je bent niet meer ingelogd. Log opnieuw in.',
  notAllowed: 'Dit mag alleen na je tweestapsverificatie. Log opnieuw in.',
  notSetUp: DEVICES_NOT_SET_UP_MESSAGE,
  unavailable: 'Dat lukte niet. Probeer het later nog een keer.',
} as const;
