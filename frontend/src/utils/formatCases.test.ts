import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { beforeAll, describe, expect, it } from 'vitest'
import type { TFunction } from 'i18next'
import { createServerI18n } from '@/i18n'
import type { RentalPeriod, UnitSystem } from '@/api/dto'
import { formatDateTime, formatMonthYear, formatRelative } from './dateFormat'
import { formatAdPrice } from './priceFormat'
import { formatTripSpan } from './publicationTiming'
import { distanceText, elevationText, formatGrade, formatPercent, speedText } from './unitFormat'

/**
 * The cases shared with the app (`contracts/format-cases.json`, see `contracts/format-cases.md`):
 * the same value, language and units must read the same on the site and in the app
 * (docs/LEDGER_*.md WEB-167, MOB-139). The app reads the same file in
 * `mobile/test/core/utils/format_cases_test.dart`.
 */
interface FormatCase {
  kind: string
  input: unknown
  locale: 'fr' | 'en'
  units: 'metric' | 'imperial'
  now?: string
  expected: string
}

const cases: FormatCase[] = JSON.parse(
  // Vitest runs from frontend/ (jsdom: `import.meta.url` is not a file URL).
  readFileSync(resolve(process.cwd(), '../contracts/format-cases.json'), 'utf8')
)

const t: Record<string, TFunction> = {}
beforeAll(async () => {
  t.fr = (await createServerI18n('fr')).t
  t.en = (await createServerI18n('en')).t
})

type Dated = { date: string; zone: string }

function render(c: FormatCase): string {
  const units: UnitSystem = c.units === 'imperial' ? 'IMPERIAL' : 'METRIC'
  const now = c.now ? new Date(c.now) : new Date()
  const lang = c.locale
  switch (c.kind) {
    case 'distance':
      return distanceText(c.input as number, units, lang)
    case 'elevation':
      return elevationText(c.input as number, units, lang)
    case 'speed':
      return speedText(c.input as number, units, lang)
    case 'percent':
      return formatPercent(c.input as number, lang)
    case 'grade':
      return formatGrade(c.input as number, lang)
    case 'price': {
      const { price, rentalPeriod } = c.input as { price: number | null; rentalPeriod?: string }
      return formatAdPrice(
        price,
        rentalPeriod ? 'RENTAL' : 'SALE',
        rentalPeriod as RentalPeriod | undefined,
        lang,
        t[lang]
      )
    }
    case 'shortDateTime': {
      const { date, zone } = c.input as Dated
      return formatDateTime(date, lang, zone, now, t[lang])
    }
    case 'tripSpan': {
      const { start, end, zone } = c.input as { start: string; end: string; zone: string }
      return formatTripSpan(start, end, lang, t[lang], zone, zone, now)
    }
    case 'relative': {
      const { date, zone } = c.input as Dated
      return formatRelative(date, lang, zone, t[lang], now)
    }
    case 'memberSince': {
      const { date, zone } = c.input as Dated
      return t[lang]('teams.detail.members.since', { date: formatMonthYear(date, lang, zone) })
    }
    default:
      throw new Error(`Unknown kind ${c.kind}`)
  }
}

// Spaces made visible, so a plain space where a no-break one belongs fails legibly.
const visible = (s: string) => s.replace(/ /g, '⍽').replace(/ /g, '·n·')

describe('contracts/format-cases.json', () => {
  it.each(cases.map((c) => [`${c.kind} ${JSON.stringify(c.input)} [${c.locale}, ${c.units}]`, c]))(
    '%s',
    (_, c) => {
      expect(visible(render(c as FormatCase))).toBe(visible((c as FormatCase).expected))
    }
  )
})
