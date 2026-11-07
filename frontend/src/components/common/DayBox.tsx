import { Box, Text } from '@mantine/core'
import { useTranslation } from 'react-i18next'
import { formatPattern as formatInZone, useFormattedDate } from '@/utils/dateFormat'
import { isSupportedZone } from '@/utils/zoneLabel'

/** The soft background of the box: indigo for a ride, turquoise for a trip (docs/BRANDING.md §7.8). */
export type DayBoxTone = 'primary' | 'teal'

/**
 * The text shade of a posed box, on its white whatever the colour scheme: the `light-color` of the
 * dark scheme is a pale shade meant for a dark page, 2–3:1 on white. primary-8 is 5.6:1 on white,
 * teal-9 5.3:1.
 */
const POSED_TONE_COLOR: Record<DayBoxTone, string> = {
  primary: 'var(--mantine-color-primary-8)',
  teal: 'var(--mantine-color-teal-9)',
}

/**
 * The day box (docs/BRANDING.md §7.8, ledger `BRAND-8`): « sam. / 10 / oct. » — the short day in
 * 600 and the tone's text colour, the day's number in 700 and the text colour, the short month in
 * 500. Flat (the tone's soft background) in a list, the agenda and the departure block of a detail
 * page (`size="lg"`); posed (white, `sm` shadow, the same in both schemes) on the picture of a card
 * (docs/LEDGER_*.md WEB-138).
 *
 * `zone`: the day of a rendezvous, in its entity's zone, so the box and the time printed next to it
 * describe the same local day (docs/LEDGER_*.md API-60). Without it, or in a zone the browser's
 * `Intl` lacks, the reader's zone.
 */
export function DayBox({
  date,
  zone,
  tone = 'primary',
  size = 'md',
  variant = 'flat',
}: {
  date: string
  zone?: string
  tone?: DayBoxTone
  size?: 'md' | 'lg'
  variant?: 'flat' | 'posed'
}) {
  const { i18n } = useTranslation()
  const reader = useFormattedDate()
  const formatPattern = (value: string, pattern: string) =>
    isSupportedZone(zone)
      ? formatInZone(value, pattern, i18n.language, zone)
      : reader.formatPattern(value, pattern)
  const width = size === 'lg' ? 68 : 60
  const posed = variant === 'posed'
  const toneColor = posed ? POSED_TONE_COLOR[tone] : `var(--mantine-color-${tone}-light-color)`
  const numberColor = posed ? 'var(--mantine-color-gray-9)' : 'var(--mantine-color-text)'
  return (
    <Box
      w={width}
      py={8}
      ta="center"
      data-testid="day-box"
      data-variant={variant}
      style={{
        flex: `0 0 ${width}px`,
        borderRadius: 'var(--mantine-radius-md)',
        background: posed ? 'var(--mantine-color-white)' : `var(--mantine-color-${tone}-light)`,
        boxShadow: posed ? 'var(--mantine-shadow-sm)' : undefined,
      }}
    >
      <Text fz={size === 'lg' ? 13 : 12} fw={600} c={toneColor} lh={1.3} suppressHydrationWarning>
        {formatPattern(date, 'EEE')}
      </Text>
      <Text fz={size === 'lg' ? 28 : 22} fw={700} lh={1.1} c={numberColor} suppressHydrationWarning>
        {formatPattern(date, 'd')}
      </Text>
      <Text fz={size === 'lg' ? 13 : 12} fw={500} c={toneColor} lh={1.3} suppressHydrationWarning>
        {formatPattern(date, 'MMM')}
      </Text>
    </Box>
  )
}
