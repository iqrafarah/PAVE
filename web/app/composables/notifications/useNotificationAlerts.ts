import type { PaveNotification } from '~/types/notifications';

export type AlertPermission = NotificationPermission | 'unsupported';

const ENABLED_KEY = 'pave-notification-alerts';
// "Niet nu" on the card in Meldingen: asked again after a week.
const DISMISSED_KEY = 'pave-notification-alerts-dismissed';
const DISMISS_MS = 7 * 24 * 60 * 60 * 1000;

function supportsAlerts() {
  return import.meta.client && 'Notification' in window;
}

function readEnabled() {
  try {
    return localStorage.getItem(ENABLED_KEY) === 'on';
  } catch {
    return false;
  }
}

/**
 * A small signal outside the page (iOS NotificationAlerts and Instellingen › Meldingen). On web this is a notification
 * of the browser, shown only while PAVE is not in view (another tab or window); in view the banner does it. It is asked
 * by choice, never on its own, and only carries the title and who it is about: never evidence or chat text.
 */
export function useNotificationAlerts() {
  const isEnabled = useState('pave-notification-alerts-enabled', () => false);
  const permission = useState<AlertPermission>('pave-notification-alerts-permission', () => 'default');
  const isCardDismissed = useState('pave-notification-alerts-dismissed', () => false);

  function load() {
    if (!supportsAlerts()) {
      permission.value = 'unsupported';
      return;
    }
    permission.value = Notification.permission;
    isEnabled.value = readEnabled() && permission.value === 'granted';
    try {
      isCardDismissed.value = Date.now() - Number(localStorage.getItem(DISMISSED_KEY) ?? 0) < DISMISS_MS;
    } catch {
      isCardDismissed.value = false;
    }
  }

  function keep(on: boolean) {
    try {
      localStorage.setItem(ENABLED_KEY, on ? 'on' : 'off');
    } catch {
      // Without storage it stays on for this visit only.
    }
  }

  /** Turning it on asks the browser the first time; the browser's own question only ever comes from this choice. */
  async function setEnabled(on: boolean) {
    if (!supportsAlerts()) return;
    if (on && Notification.permission === 'default') permission.value = await Notification.requestPermission();
    else permission.value = Notification.permission;
    isEnabled.value = on && permission.value === 'granted';
    keep(isEnabled.value);
  }

  function dismissCard() {
    isCardDismissed.value = true;
    try {
      localStorage.setItem(DISMISSED_KEY, String(Date.now()));
    } catch {
      // Shown again next visit.
    }
  }

  /** Clicking it brings PAVE to the front, on Meldingen with this notification open. */
  function show(notification: PaveNotification) {
    if (!isEnabled.value || !supportsAlerts() || Notification.permission !== 'granted') return;
    if (document.visibilityState === 'visible' && document.hasFocus()) return;
    try {
      const alert = new Notification(notification.title, {
        body: notificationDetail(notification) || NOTIFICATIONS_NEW,
        tag: notification.id,
        icon: '/favicon.ico',
      });
      alert.onclick = () => {
        window.focus();
        navigateTo({ path: '/meldingen', query: { melding: notification.id } });
        alert.close();
      };
    } catch {
      // Some browsers only allow notifications from a service worker; then the banner is all there is.
    }
  }

  return { isEnabled, permission, isCardDismissed, load, setEnabled, dismissCard, show };
}
