// A place where the account is signed in (iOS PAVECore/Devices/SignedInDevice.swift): one session, described from the
// browser or app that started it.

export type DeviceKind = 'iPhone' | 'iPad' | 'mac' | 'windows' | 'android' | 'linux' | 'unknown';

export interface SignedInDevice {
  id: string;
  kind: DeviceKind;
  // 'paveApp' for the PAVE app on iPhone and iPad, the name of a browser, or null when unknown.
  client: string | null;
  signedInAt: string;
  lastActiveAt: string;
  // The device this list is shown on.
  isCurrent: boolean;
}

const KIND_NAMES: Record<DeviceKind, string> = {
  iPhone: 'iPhone',
  iPad: 'iPad',
  mac: 'Mac',
  windows: 'Windows',
  android: 'Android',
  linux: 'Linux',
  unknown: 'onbekend apparaat',
};

/**
 * The PAVE app sends "PAVE-iOS/0.1 (iPhone; iOS 26.1)"; older versions only the system's "PAVE/1 CFNetwork/…".
 * Browsers are told apart by their usual names, with Edge and Opera before Chrome and Chrome before Safari.
 */
export function describeUserAgent(userAgent: string): Pick<SignedInDevice, 'kind' | 'client'> {
  if (userAgent.startsWith('PAVE-iOS/')) return { kind: userAgent.includes('iPad') ? 'iPad' : 'iPhone', client: 'paveApp' };
  if (userAgent.includes('CFNetwork')) return { kind: 'unknown', client: 'paveApp' };
  const kind: DeviceKind = userAgent.includes('iPhone')
    ? 'iPhone'
    : userAgent.includes('iPad')
      ? 'iPad'
      : userAgent.includes('Android')
        ? 'android'
        : userAgent.includes('Macintosh') || userAgent.includes('Mac OS X')
          ? 'mac'
          : userAgent.includes('Windows')
            ? 'windows'
            : userAgent.includes('Linux')
              ? 'linux'
              : 'unknown';
  const client = userAgent.includes('Edg')
    ? 'Edge'
    : userAgent.includes('OPR/')
      ? 'Opera'
      : userAgent.includes('Firefox/') || userAgent.includes('FxiOS')
        ? 'Firefox'
        : userAgent.includes('Chrome/') || userAgent.includes('CriOS')
          ? 'Chrome'
          : userAgent.includes('Safari/')
            ? 'Safari'
            : null;
  return { kind, client };
}

/** "PAVE-app op iPhone", "Safari op Mac" or "Onbekend apparaat". */
export function deviceName(device: SignedInDevice) {
  const client = device.client === 'paveApp' ? 'PAVE-app' : device.client;
  if (!client) return device.kind === 'unknown' ? 'Onbekend apparaat' : KIND_NAMES[device.kind];
  return device.kind === 'unknown' ? client : `${client} op ${KIND_NAMES[device.kind]}`;
}

export function deviceIcon(device: SignedInDevice) {
  if (device.kind === 'iPhone' || device.kind === 'android') return '/images/settings/phone.svg';
  if (device.kind === 'iPad') return '/images/settings/tablet.svg';
  if (device.kind === 'unknown') return device.client === 'paveApp' ? '/images/settings/phone.svg' : '/images/settings/unknown.svg';
  return '/images/settings/computer.svg';
}

/** "Nu actief" or "Actief 2 uur geleden". */
export function deviceActivity(device: SignedInDevice, now = Date.now()) {
  const seconds = (now - new Date(device.lastActiveAt).getTime()) / 1000;
  if (device.isCurrent || !(seconds >= 5 * 60)) return DEVICES_NOW_ACTIVE;
  const format = new Intl.RelativeTimeFormat('nl', { numeric: 'always' });
  const [amount, unit] =
    seconds < 3600
      ? ([Math.round(seconds / 60), 'minute'] as const)
      : seconds < 86_400
        ? ([Math.round(seconds / 3600), 'hour'] as const)
        : seconds < 86_400 * 30
          ? ([Math.round(seconds / 86_400), 'day'] as const)
          : ([Math.round(seconds / (86_400 * 30)), 'month'] as const);
  return `Actief ${format.format(-amount, unit)}`;
}

/** "Ingelogd op 10 nov". */
export function deviceSignedIn(device: SignedInDevice) {
  const day = new Intl.DateTimeFormat('nl-NL', { day: 'numeric', month: 'short' }).format(new Date(device.signedInAt));
  return `Ingelogd op ${day.replace('.', '')}`;
}
