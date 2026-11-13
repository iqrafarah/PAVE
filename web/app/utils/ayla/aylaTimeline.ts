import { AYLA_TODAY, AYLA_YESTERDAY } from './aylaMessages';

// Times in the chat, as on the iPhone (PAVECore AylaTimeline, AylaConversationSection and AylaChatRow.when).

export type ChatSectionKind = 'pinned' | 'today' | 'yesterday' | 'lastWeek' | 'lastMonth' | 'earlier';

/** A pause this long between two messages shows the time again, as in Messages. */
export const TIMELINE_PAUSE_MS = 15 * 60 * 1000;
const MS_PER_DAY = 24 * 60 * 60 * 1000;
const DAYS_IN_WEEK = 7;
const DAYS_IN_LAST_WEEK_SECTION = 7;
const DAYS_IN_LAST_MONTH_SECTION = 30;
const LOCALE = 'nl-NL';

const TIME_FORMAT = new Intl.DateTimeFormat(LOCALE, { hour: '2-digit', minute: '2-digit', hourCycle: 'h23' });
const WEEKDAY_FORMAT = new Intl.DateTimeFormat(LOCALE, { weekday: 'long' });
const DAY_FORMAT = new Intl.DateTimeFormat(LOCALE, { day: 'numeric', month: 'short' });
const DAY_WITH_YEAR_FORMAT = new Intl.DateTimeFormat(LOCALE, { day: 'numeric', month: 'short', year: 'numeric' });

/** A date from the database, or null when there is none or it cannot be read. */
export function readChatDate(value: string | null | undefined) {
  if (!value) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

function startOfDay(date: Date) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

/** Calendar days from `date` to `now`: 0 today, 1 yesterday. Rounded, so a day with a clock change still counts as one. */
function daysAgo(date: Date, now: Date) {
  return Math.round((startOfDay(now).getTime() - startOfDay(date).getTime()) / MS_PER_DAY);
}

function formatTime(date: Date) {
  return TIME_FORMAT.format(date);
}

function formatWeekday(date: Date) {
  const weekday = WEEKDAY_FORMAT.format(date);
  return weekday.charAt(0).toLocaleUpperCase(LOCALE) + weekday.slice(1);
}

/** "3 nov", or "3 nov 2025" in another year. */
function formatDay(date: Date, now: Date) {
  const isSameYear = date.getFullYear() === now.getFullYear();
  const format = isSameYear ? DAY_FORMAT : DAY_WITH_YEAR_FORMAT;
  return format.format(date).replaceAll('.', '');
}

/** Whether a message at `date` gets a time above it: the first one, and any after a pause of 15 minutes or more. */
export function showsTimeBefore(date: Date | null, previous: Date | null) {
  if (!date) return false;
  if (!previous) return true;
  return date.getTime() - previous.getTime() >= TIMELINE_PAUSE_MS;
}

/** "Vandaag 14:02", "Gisteren 09:15", "Maandag 18:40" within a week, else "3 nov 14:02" (with the year in another year). */
export function getTimelineLabel(date: Date, now = new Date()) {
  const time = formatTime(date);
  const days = daysAgo(date, now);
  if (days === 0) return `${AYLA_TODAY} ${time}`;
  if (days === 1) return `${AYLA_YESTERDAY} ${time}`;
  if (days < DAYS_IN_WEEK) return `${formatWeekday(date)} ${time}`;
  return `${formatDay(date, now)} ${time}`;
}

/** When a chat was last used, in its row: the time today and yesterday, the weekday this week, otherwise the date. */
export function getChatRowTime(date: Date, now = new Date()) {
  const days = daysAgo(date, now);
  if (days <= 1) return formatTime(date);
  if (days < DAYS_IN_WEEK) return formatWeekday(date);
  return formatDay(date, now);
}

/** The group a chat that is not pinned belongs in, by the calendar days since it was last used. */
export function getChatSectionKind(date: Date, now = new Date()): ChatSectionKind {
  const days = daysAgo(date, now);
  if (days <= 0) return 'today';
  if (days === 1) return 'yesterday';
  if (days <= DAYS_IN_LAST_WEEK_SECTION) return 'lastWeek';
  if (days <= DAYS_IN_LAST_MONTH_SECTION) return 'lastMonth';
  return 'earlier';
}
