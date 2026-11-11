import { useSyncExternalStore } from 'react'
import { parseISO } from 'date-fns'
import { formatInTimeZone } from 'date-fns-tz'
import { fr } from 'date-fns/locale/fr'
import { enUS } from 'date-fns/locale/en-US'
import type { Locale } from 'date-fns'
import type { TFunction } from 'i18next'
import { useTranslation } from 'react-i18next'
import i18n from '../i18n'
import { useAuthStore, selectUser } from '../store/authStore'

// Deterministic value used when a visitor's real timezone truly cannot be known: an anonymous SSR
// render, or a signed-in user who never set one. Arbitrary but must be stable, since it's what the
// server commits to in the markup.
const SERVER_FALLBACK_TIMEZONE = 'UTC'

// The browser's zone, delivered as an external store so the *hydration* render still reads
// `SERVER_FALLBACK_TIMEZONE` (`getServerSnapshot`) and React re-renders with the real zone right
// after — the same post-hydration correction `hydrateAnonymousPreferences` performs for
// unitSystem/theme/language.
//
// Returning the browser's zone directly during hydration is the trap this replaces: the text
// differs from the server's, and `suppressHydrationWarning` does not *patch* a mismatched text
// node, it only silences the warning — so the server's UTC text stayed on screen until some
// unrelated re-render, and every SSR-rendered date read an hour or two off for any visitor without
// a `timezone` preference.
const subscribeToNothing = () => () => {}
const getBrowserTimezone = () => Intl.DateTimeFormat().resolvedOptions().timeZone
const getServerTimezone = () => SERVER_FALLBACK_TIMEZONE
const isClientSnapshot = () => true
const isServerSnapshot = () => false

/**
 * The timezone to render dates/times in, and whether it's a guess rather than the visitor's own
 * confirmed preference. `useAuthStore` already resolves the current user per-request server-side
 * (via `getSSRAuth()`) and reactively client-side, so no dedicated store/module-load seeding is
 * needed here the way `theme`/`language` required.
 */
export function useEffectiveTimezone(): {
  timezone: string
  isGuessed: boolean
  /**
   * The zone is the server's placeholder (`UTC`), not the reader's: an anonymous SSR render or the
   * hydration render of a reader without a preference. Nothing may be said *about the reader's own
   * clock* then — the « heure de Paris (06:00 chez vous) » mention of a rendezvous waits for the
   * post-hydration render (docs/LEDGER_*.md API-60).
   */
  isPlaceholder: boolean
} {
  const user = useAuthStore(selectUser)
  const browserTimezone = useSyncExternalStore(
    subscribeToNothing,
    getBrowserTimezone,
    getServerTimezone
  )
  const hydrated = useSyncExternalStore(subscribeToNothing, isClientSnapshot, isServerSnapshot)
  if (user?.timezone) return { timezone: user.timezone, isGuessed: false, isPlaceholder: false }
  return { timezone: browserTimezone, isGuessed: true, isPlaceholder: !hydrated }
}

// Locale map for quick access
const locales: Record<string, Locale> = {
  fr: fr,
  en: enUS,
}

/**
 * Get date-fns locale for the given language code
 */
function getLocale(language: string): Locale {
  return locales[language] || enUS
}

/**
 * Convert various date inputs to Date object
 * Handles null/undefined gracefully
 */
function toDate(date: Date | string | null | undefined): Date | null {
  if (!date) return null
  if (date instanceof Date) return date
  try {
    return parseISO(date)
  } catch {
    return null
  }
}

/**
 * The time of day in the language's clock: « 18:30 » (fr), « 6:30 PM » (en). English puts a narrow
 * no-break space (U+202F) before the meridiem, as CLDR — and so the app's `intl` — writes it:
 * « 6:30 » and « PM » never split, and both clients read the same (contracts/format-cases.json).
 */
function clockTime(dateObj: Date, timeZone: string, language: string): string {
  return formatInTimeZone(dateObj, timeZone, 'p', { locale: getLocale(language) }).replace(
    / (AM|PM)$/,
    '\u202f$1'
  )
}

/**
 * The long date of each language, without the weekday. Not date-fns's `PPP`, whose English writes
 * an ordinal (« June 15th, 2025 ») the app's `intl` (`yMMMMd`) does not. Kept in code rather than
 * in the catalogue: it must hold where a test mocks `react-i18next`.
 */
const LONG_DATE_PATTERNS: Record<string, string> = { fr: 'd MMMM yyyy', en: 'MMMM d, yyyy' }

/**
 * Format full date, without the weekday: « 15 juin 2025 » (fr) / « June 15, 2025 » (en).
 */
export function formatDate(
  date: Date | string | null | undefined,
  language: string = 'fr',
  timeZone: string = SERVER_FALLBACK_TIMEZONE
): string {
  const dateObj = toDate(date)
  if (!dateObj) return ''

  return formatInTimeZone(dateObj, timeZone, LONG_DATE_PATTERNS[language] ?? 'MMMM d, yyyy', {
    locale: getLocale(language),
  })
}

/**
 * The month and the year, inside a sentence: « mars 2024 » (fr), « March 2024 » (en) — « Membre
 * depuis mars 2024 » (docs/plans/2026-11-10-etat-des-lieux-affichage/maquettes/KIT.md §9).
 */
export function formatMonthYear(
  date: Date | string | null | undefined,
  language: string = 'fr',
  timeZone: string = SERVER_FALLBACK_TIMEZONE
): string {
  const dateObj = toDate(date)
  if (!dateObj) return ''
  return formatInTimeZone(dateObj, timeZone, 'MMMM yyyy', { locale: getLocale(language) })
}

/**
 * Format date + time in the departure's one format, never relative: « sam. 12 avr. · 09:00 », the
 * year only outside the current one (« sam. 10 avr. 2027 · 09:00 »), « Sat, Apr 12 · 9:00 AM » in
 * English (docs/BRANDING.md §8.3, docs/LEDGER_*.md WEB-138). A timestamp (an expiry, a last
 * report) reads like a rendezvous: the site has one long date-and-time format.
 */
export function formatDateTime(
  date: Date | string | null | undefined,
  language: string = 'fr',
  timeZone: string = SERVER_FALLBACK_TIMEZONE,
  now: Date = new Date(),
  t: TFunction = i18n.getFixedT(language)
): string {
  return formatDeparture(date, language, timeZone, t, { now, relative: false })
}

/**
 * Format with a date-fns pattern ("EEE", "d", "MMM", "HH:mm"…) in the given language and timezone:
 * the pieces of a date a layout draws separately (the day box of a calendar row).
 */
export function formatPattern(
  date: Date | string | null | undefined,
  pattern: string,
  language: string = 'fr',
  timeZone: string = SERVER_FALLBACK_TIMEZONE
): string {
  const dateObj = toDate(date)
  if (!dateObj) return ''
  return formatInTimeZone(dateObj, timeZone, pattern, { locale: getLocale(language) })
}

/**
 * Format the time of day alone: "09:00" (fr) / "9:00 AM" (en) — the passages of a ride, the hour
 * a forecast was fetched.
 */
export function formatTime(
  date: Date | string | null | undefined,
  language: string = 'fr',
  timeZone: string = SERVER_FALLBACK_TIMEZONE
): string {
  const dateObj = toDate(date)
  if (!dateObj) return ''

  return clockTime(dateObj, timeZone, language)
}

/**
 * Whether `date` falls on the same calendar day as `now`, on the wall clock of `timeZone` — the
 * test that picks a bare hour (« à 18:00 ») over a full date for a recent moment.
 */
export function isSameDay(
  date: Date | string | null | undefined,
  timeZone: string = SERVER_FALLBACK_TIMEZONE,
  now: Date = new Date()
): boolean {
  const dateObj = toDate(date)
  if (!dateObj) return false
  return (
    formatInTimeZone(dateObj, timeZone, 'yyyy-MM-dd') ===
    formatInTimeZone(now, timeZone, 'yyyy-MM-dd')
  )
}

/** The two days a departure is named relatively (docs/BRANDING.md §8.3, ledger `BRAND-8`). */
export type RelativeDay = 'today' | 'tomorrow'

/** `yyyy-MM-dd` of the calendar day after `day` (`yyyy-MM-dd`), whatever the zone. */
function nextCalendarDay(day: string): string {
  const [year, month, date] = day.split('-').map(Number)
  return new Date(Date.UTC(year, month - 1, date + 1)).toISOString().slice(0, 10)
}

/**
 * Whether `date` falls today or tomorrow on the wall clock of `timeZone` — the departure's zone,
 * not the reader's: a Tokyo ride « demain » is tomorrow in Tokyo. `null` for any other day, past
 * days included: only these two are ever said relatively (ledger `BRAND-8`).
 */
export function relativeDay(
  date: Date | string | null | undefined,
  timeZone: string = SERVER_FALLBACK_TIMEZONE,
  now: Date = new Date()
): RelativeDay | null {
  const dateObj = toDate(date)
  if (!dateObj) return null
  const day = formatInTimeZone(dateObj, timeZone, 'yyyy-MM-dd')
  const today = formatInTimeZone(now, timeZone, 'yyyy-MM-dd')
  if (day === today) return 'today'
  if (day === nextCalendarDay(today)) return 'tomorrow'
  return null
}

/** « Aujourd'hui » / « Demain » (« Today » / « Tomorrow »), or `null` for any other day. */
export function formatRelativeDay(
  date: Date | string | null | undefined,
  timeZone: string,
  t: TFunction,
  now: Date = new Date()
): string | null {
  const relative = relativeDay(date, timeZone, now)
  if (relative === 'today') return t('dateFormats.today')
  if (relative === 'tomorrow') return t('dateFormats.tomorrow')
  return null
}

/** Whether `date` is in the current year on the wall clock of `timeZone`. */
function isCurrentYear(dateObj: Date, timeZone: string, now: Date): boolean {
  return formatInTimeZone(dateObj, timeZone, 'yyyy') === formatInTimeZone(now, timeZone, 'yyyy')
}

/**
 * The departure, in its one format (docs/BRANDING.md §8.3, ledger `BRAND-8`): « sam. 12 avr. ·
 * 09:00 », the year only outside the current one (« sam. 10 avr. 2027 · 09:00 »), « Aujourd'hui ·
 * 09:00 » and « Demain · 09:00 » for those two days. English follows the same pattern its own way
 * (« Sat, Apr 12 · 9:00 AM »). Today, tomorrow and the year are judged in `timeZone`, the
 * departure's.
 *
 * `relative: false` keeps the absolute day even today or tomorrow — for a line already carrying
 * the « Demain » pill.
 */
export function formatDeparture(
  date: Date | string | null | undefined,
  language: string,
  timeZone: string,
  t: TFunction,
  { now = new Date(), relative = true }: { now?: Date; relative?: boolean } = {}
): string {
  const dateObj = toDate(date)
  if (!dateObj) return ''
  const time = clockTime(dateObj, timeZone, language)
  const day =
    (relative ? formatRelativeDay(dateObj, timeZone, t, now) : null) ??
    formatDepartureDay(dateObj, language, timeZone, t, now)
  return t('dateFormats.dayAndTime', { day, time })
}

/**
 * The departure's day alone, abbreviated: « sam. 12 avr. », the year only outside the current one
 * (« sam. 10 avr. 2027 ») — a stage's tab, a to-do line, the ends of a trip's span. Judged in
 * `timeZone`, the departure's.
 */
export function formatDepartureDay(
  date: Date | string | null | undefined,
  language: string,
  timeZone: string,
  t: TFunction,
  now: Date = new Date()
): string {
  const dateObj = toDate(date)
  if (!dateObj) return ''
  return formatInTimeZone(
    dateObj,
    timeZone,
    isCurrentYear(dateObj, timeZone, now)
      ? t('dateFormats.departureDay')
      : t('dateFormats.departureDayWithYear'),
    { locale: getLocale(language) }
  )
}

/**
 * The departure's day in full, without its time: « samedi 12 avril », the year only outside the
 * current one (« samedi 10 avril 2027 ») — the second line of the departure block (§7.8).
 */
export function formatLongDay(
  date: Date | string | null | undefined,
  language: string,
  timeZone: string,
  t: TFunction,
  now: Date = new Date()
): string {
  const dateObj = toDate(date)
  if (!dateObj) return ''
  return formatInTimeZone(
    dateObj,
    timeZone,
    isCurrentYear(dateObj, timeZone, now)
      ? t('dateFormats.longDay')
      : t('dateFormats.longDayWithYear'),
    { locale: getLocale(language) }
  )
}

/** Beyond, a relative date disorients more than it informs: the date is written instead. */
const RELATIVE_ABSOLUTE_THRESHOLD_DAYS = 7

/**
 * A moment relative to now, the app's way (docs/plans/2026-11-10-etat-des-lieux-affichage/maquettes/KIT.md
 * §9, docs/LEDGER_*.md WEB-167): « à l'instant » under a minute, then « il y a 5 minutes », « il y a
 * 2 heures », « il y a 3 jours » — whole units, never « environ » — and, beyond 7 days, the date
 * (« 3 novembre 2026 », in `timeZone`). The future reads « dans 2 heures ». Same cut-offs as
 * `RelativeTime.between` in the app (`mobile/lib/core/utils/formatters.dart`).
 */
export function formatRelative(
  date: Date | string | null | undefined,
  language: string,
  timeZone: string,
  t: TFunction,
  now: Date = new Date()
): string {
  const dateObj = toDate(date)
  if (!dateObj) return ''

  const delta = now.getTime() - dateObj.getTime()
  const past = delta >= 0
  const seconds = Math.floor(Math.abs(delta) / 1000)
  const minutes = Math.floor(seconds / 60)
  const hours = Math.floor(minutes / 60)
  const days = Math.floor(hours / 24)
  if (seconds < 60) return t('dateFormats.relative.now')
  if (minutes < 60) {
    return past
      ? t('dateFormats.relative.minutesAgo', { count: minutes })
      : t('dateFormats.relative.inMinutes', { count: minutes })
  }
  if (hours < 24) {
    return past
      ? t('dateFormats.relative.hoursAgo', { count: hours })
      : t('dateFormats.relative.inHours', { count: hours })
  }
  if (days <= RELATIVE_ABSOLUTE_THRESHOLD_DAYS) {
    return past
      ? t('dateFormats.relative.daysAgo', { count: days })
      : t('dateFormats.relative.inDays', { count: days })
  }
  return formatDate(dateObj, language, timeZone)
}

/**
 * React hook that provides date formatting functions auto-synced with i18n language and the
 * visitor's effective timezone (see `useEffectiveTimezone`).
 */
export function useFormattedDate() {
  const { t, i18n } = useTranslation()
  const language = i18n.language
  const { timezone, isGuessed } = useEffectiveTimezone()

  return {
    formatDeparture: (date: Date | string | null | undefined) =>
      formatDeparture(date, language, timezone, t),
    formatDepartureDay: (date: Date | string | null | undefined) =>
      formatDepartureDay(date, language, timezone, t),
    formatRelativeDay: (date: Date | string | null | undefined) =>
      formatRelativeDay(date, timezone, t),
    formatDate: (date: Date | string | null | undefined) => formatDate(date, language, timezone),
    formatMonthYear: (date: Date | string | null | undefined) =>
      formatMonthYear(date, language, timezone),
    formatDateTime: (date: Date | string | null | undefined) =>
      formatDateTime(date, language, timezone, new Date(), t),
    formatTime: (date: Date | string | null | undefined) => formatTime(date, language, timezone),
    formatRelative: (date: Date | string | null | undefined) =>
      formatRelative(date, language, timezone, t),
    formatPattern: (date: Date | string | null | undefined, pattern: string) =>
      formatPattern(date, pattern, language, timezone),
    isToday: (date: Date | string | null | undefined) => isSameDay(date, timezone),
    isGuessedTimezone: isGuessed,
  }
}
