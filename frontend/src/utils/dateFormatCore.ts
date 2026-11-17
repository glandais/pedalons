// The pure formatters of `dateFormat.ts`: no i18n instance, no store, no React — so code that
// must not initialise i18next on import (the link-preview builders of `config/routeMeta.ts`, read
// by `routes.config.ts`) formats a date the way the pages do (docs/LEDGER_*.md WEB-139).
// `dateFormat.ts` re-exports them: import from there everywhere else.
import { parseISO } from 'date-fns'
import { formatInTimeZone } from 'date-fns-tz'
import { fr } from 'date-fns/locale/fr'
import { enUS } from 'date-fns/locale/en-US'
import type { Locale } from 'date-fns'

// Deterministic value used when a visitor's real timezone truly cannot be known: an anonymous SSR
// render, or a signed-in user who never set one. Arbitrary but must be stable, since it's what the
// server commits to in the markup.
export const SERVER_FALLBACK_TIMEZONE = 'UTC'

// Locale map for quick access
const locales: Record<string, Locale> = {
  fr: fr,
  en: enUS,
}

/**
 * Get date-fns locale for the given language code
 */
export function getLocale(language: string): Locale {
  return locales[language] || enUS
}

/**
 * Convert various date inputs to Date object
 * Handles null/undefined gracefully
 */
export function toDate(date: Date | string | null | undefined): Date | null {
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
export function clockTime(dateObj: Date, timeZone: string, language: string): string {
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
