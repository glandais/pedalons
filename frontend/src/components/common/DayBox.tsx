import { Box, Text } from '@mantine/core'
import { useTranslation } from 'react-i18next'
import { formatPattern as formatInZone, useFormattedDate } from '@/utils/dateFormat'
import { isSupportedZone } from '@/utils/zoneLabel'

/** The soft background of the box: indigo for a ride, turquoise for a trip (docs/BRANDING.md §7.8). */
export type DayBoxTone = 'primary' | 'teal'

/**
 * The day box, flat (docs/BRANDING.md §7.8, ledger `BRAND-8`): « sam. / 10 / oct. » — the short
 * day in 600 and the tone's text colour, the day's number in 700 and the text colour, the short
 * month in 500. Shared by the dashboard's « Mes prochaines », the agenda's « Lignes » view and the
 * departure block of a detail page (`size="lg"`).
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
}: {
  date: string
  zone?: string
  tone?: DayBoxTone
  size?: 'md' | 'lg'
}) {
  const { i18n } = useTranslation()
  const reader = useFormattedDate()
  const formatPattern = (value: string, pattern: string) =>
    isSupportedZone(zone)
      ? formatInZone(value, pattern, i18n.language, zone)
      : reader.formatPattern(value, pattern)
  const width = size === 'lg' ? 68 : 60
  const toneColor = `var(--mantine-color-${tone}-light-color)`
  return (
    <Box
      w={width}
      py={8}
      ta="center"
      data-testid="day-box"
      style={{
        flex: `0 0 ${width}px`,
        borderRadius: 'var(--mantine-radius-md)',
        background: `var(--mantine-color-${tone}-light)`,
      }}
    >
      <Text fz={size === 'lg' ? 13 : 12} fw={600} c={toneColor} lh={1.3} suppressHydrationWarning>
        {formatPattern(date, 'EEE')}
      </Text>
      <Text
        fz={size === 'lg' ? 28 : 22}
        fw={700}
        lh={1.1}
        c="var(--mantine-color-text)"
        suppressHydrationWarning
      >
        {formatPattern(date, 'd')}
      </Text>
      <Text fz={size === 'lg' ? 13 : 12} fw={500} c={toneColor} lh={1.3} suppressHydrationWarning>
        {formatPattern(date, 'MMM')}
      </Text>
    </Box>
  )
}
