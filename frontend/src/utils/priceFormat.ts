import type { TFunction } from 'i18next'
import type { AdType, RentalPeriod } from '@/api/dto'
import { normalGroupSpaces } from './unitFormat'

const currencyFormats = new Map<string, Intl.NumberFormat>()

/**
 * An amount in euros, in the language of the interface and always to the cent: « 1 200,00 € »
 * (fr), « €1,200.00 » (en) — the app's `AppFormatters.formatAmount` (docs/LEDGER_*.md WEB-167,
 * D26; cases in contracts/format-cases.json).
 */
export function formatAmount(price: number, language: string): string {
  let format = currencyFormats.get(language)
  if (!format) {
    format = new Intl.NumberFormat(language, {
      style: 'currency',
      currency: 'EUR',
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    })
    currencyFormats.set(language, format)
  }
  // « 1 200,00 € »: an ordinary no-break space between thousands, as everywhere (KIT §9).
  return normalGroupSpaces(format.format(price))
}

/**
 * The price of an ad, the site's one formatter (the card, the ad page, the dashboard): « Prix à
 * négocier » without a price — never a dash —, « 1 200,00 € » for a sale, « 15,00 € / semaine » for
 * a rental with its period.
 */
export function formatAdPrice(
  price: number | null | undefined,
  adType: AdType,
  rentalPeriod: RentalPeriod | null | undefined,
  language: string,
  t: TFunction
): string {
  if (price === undefined || price === null) return t('ads.detail.priceNegotiable')
  const amount = formatAmount(price, language)
  if (adType === 'RENTAL' && rentalPeriod) {
    const period = t(
      `ads.rentalPeriod.${rentalPeriod satisfies 'DAY' | 'WEEK' | 'MONTH'}`
    ).toLowerCase()
    return t('ads.pricePerPeriod', { price: amount, period })
  }
  return amount
}
