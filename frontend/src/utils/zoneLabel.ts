import { getTimezoneOffset } from 'date-fns-tz'

/**
 * Naming a timezone for the « heure de Tokyo » mention of a rendezvous (docs/LEDGER_*.md API-60,
 * plan §7 « La mention »).
 *
 * The zone is named by the city of its IANA identifier — last segment, `_` → space — with a small
 * French table for the common cases. Deliberately not the long `Intl` name (long, absent from Dart,
 * different from one browser to another), not the abbreviation (`Intl` in French often renders
 * « UTC+2 ») and not the offset (it changes with daylight saving time). Mobile mirrors this rule,
 * so keep the two tables in step.
 *
 * French needs more than the name: « heure de Tokyo » but « heure d'Athènes », « heure du Caire »,
 * « heure des Açores ». `zoneCityOf` builds that « of » phrase, the bare name in any other
 * language: both catalogs take it (« heure {{ofCity}} », « {{ofCity}} time »), so a call passes one
 * parameter that every language uses (`i18n:lint` flags a parameter its string leaves unused).
 */

// Last IANA segment → French name. Only where French differs from the identifier; anything absent
// falls back to the segment itself (Tokyo, Berlin, New York…).
const FRENCH_CITY_NAMES: Record<string, string> = {
  // Europe
  Athens: 'Athènes',
  Brussels: 'Bruxelles',
  Bucharest: 'Bucarest',
  Copenhagen: 'Copenhague',
  Lisbon: 'Lisbonne',
  London: 'Londres',
  Moscow: 'Moscou',
  Vienna: 'Vienne',
  Warsaw: 'Varsovie',
  // Africa
  Algiers: 'Alger',
  Cairo: 'Le Caire',
  // Americas
  Mexico_City: 'Mexico',
  Montreal: 'Montréal',
  Sao_Paulo: 'São Paulo',
  // Asia
  Singapore: 'Singapour',
  // Atlantic, Indian and Pacific islands
  Azores: 'Açores',
  Canary: 'Canaries',
  Noumea: 'Nouméa',
  Reunion: 'La Réunion',
}

// `Etc/GMT-9` is UTC+9: POSIX inverts the sign. The backend returns these at sea (docs/LEDGER_*.md
// API-60, plan §4), where there is no city to name.
// The « of » phrase where elision alone gets it wrong: a name carrying a plural article, or one the
// IANA segment spells without it. `Le …` is contracted generically (« du Caire »).
const FRENCH_CITY_OF: Record<string, string> = {
  Azores: 'des Açores',
  Canary: 'des Canaries',
  Maldives: 'des Maldives',
}

// Cities whose initial h is mute: « d'Helsinki ». Any other h is treated as aspirated (« de Hong
// Kong », « de Hobart »).
const FRENCH_MUTE_H = new Set(['Helsinki', 'Honolulu', 'Ho Chi Minh'])

const ETC_GMT = /^Etc\/GMT([+-])(\d{1,2})$/
const UTC_ALIASES = new Set(['UTC', 'Etc/UTC', 'Etc/GMT', 'Etc/UCT', 'Etc/Zulu', 'GMT'])

/**
 * The city naming `timezone`, in `language` (`fr…` uses the French table, anything else the IANA
 * spelling): `Asia/Tokyo` → « Tokyo », `America/New_York` → « New York », `Europe/London` →
 * « Londres » in French. `Etc/GMT-9` → « UTC+9 », `UTC` → « UTC ».
 */
export function zoneCityName(timezone: string, language: string): string {
  if (UTC_ALIASES.has(timezone)) return 'UTC'
  const etc = ETC_GMT.exec(timezone)
  if (etc) {
    const hours = Number(etc[2])
    if (hours === 0) return 'UTC'
    return `UTC${etc[1] === '-' ? '+' : '-'}${hours}`
  }
  const segment = timezone.slice(timezone.lastIndexOf('/') + 1)
  const french = language.toLowerCase().startsWith('fr') ? FRENCH_CITY_NAMES[segment] : undefined
  return french ?? segment.replaceAll('_', ' ')
}

/**
 * Whether `timezoneA` and `timezoneB` have the same UTC offset at `instant` — the test for showing
 * the mention (plan §7): it compares offsets, not identifiers, so a reader in Brussels sees nothing
 * for a ride in Paris, while Paris and London differ. An unknown identifier never matches.
 */
export function sameOffsetAt(
  instant: Date | string | number,
  timezoneA: string,
  timezoneB: string
): boolean {
  if (timezoneA === timezoneB) return true
  const date = instant instanceof Date ? instant : new Date(instant)
  const a = getTimezoneOffset(timezoneA, date)
  const b = getTimezoneOffset(timezoneB, date)
  return !Number.isNaN(a) && !Number.isNaN(b) && a === b
}

/**
 * The « of » phrase naming `timezone`, for « heure {{ofCity}} »: in French « de Tokyo »,
 * « d'Athènes », « du Caire », « des Açores », « de La Réunion », and bare « UTC » / « UTC+9 »
 * (« heure UTC »); in any other language the city name itself, as `zoneCityName`.
 */
export function zoneCityOf(timezone: string, language: string): string {
  const city = zoneCityName(timezone, language)
  if (!language.toLowerCase().startsWith('fr')) return city
  if (city.startsWith('UTC')) return city
  const segment = timezone.slice(timezone.lastIndexOf('/') + 1)
  const fixed = FRENCH_CITY_OF[segment]
  if (fixed) return fixed
  if (city.startsWith('Le ')) return `du ${city.slice(3)}`
  if (city.startsWith('Les ')) return `des ${city.slice(4)}`
  if (/^[AEIOUYÀÂÄÉÈÊËÎÏÔÖÙÛÜŸ]/i.test(city) || FRENCH_MUTE_H.has(city)) return `d'${city}`
  return `de ${city}`
}

// Zones checked once per identifier: `Intl` is the costly part, and the answer never changes.
const zoneSupport = new Map<string, boolean>()

/**
 * Whether this runtime's `Intl` knows `timezone` (docs/LEDGER_*.md API-60). The backend validates
 * zones against the JDK's tz database, which can be ahead of a browser's ICU (`Europe/Kyiv` on an
 * older Safari, `America/Ciudad_Juarez`): formatting in an unknown zone throws, so a rendezvous in
 * one falls back to the reader's zone, without mention — the rule mobile follows.
 */
export function isSupportedZone(timezone: string | null | undefined): timezone is string {
  if (!timezone) return false
  let supported = zoneSupport.get(timezone)
  if (supported === undefined) {
    try {
      new Intl.DateTimeFormat('en', { timeZone: timezone })
      supported = true
    } catch {
      supported = false
    }
    zoneSupport.set(timezone, supported)
  }
  return supported
}

/** `timezone` when this runtime can format in it, `undefined` otherwise (see `isSupportedZone`). */
export function supportedZone(timezone: string | null | undefined): string | undefined {
  return isSupportedZone(timezone) ? timezone : undefined
}
