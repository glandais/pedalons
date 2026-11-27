import { Box, Text } from '@mantine/core'

interface DemoDayBoxProps {
  weekday: string
  day: number
  month: string
  /** The compact size, for the small cards. */
  small?: boolean
}

/**
 * The day box of docs/BRANDING.md §7.8 in its flat variant, with a fixed fictional date: three
 * centred lines (short day, number, short month) on the soft primary background. Fixed text, so
 * the illustration never shows a year line or goes stale.
 */
export function DemoDayBox({ weekday, day, month, small = false }: DemoDayBoxProps) {
  const width = small ? 52 : 60
  return (
    <Box
      w={width}
      py={small ? 6 : 8}
      ta="center"
      bg="var(--mantine-color-primary-light)"
      style={{ flex: `0 0 ${width}px`, borderRadius: 'var(--mantine-radius-md)' }}
    >
      <Text fz={12} fw={600} c="var(--mantine-color-primary-light-color)" lh={1.3}>
        {weekday}
      </Text>
      <Text fz={small ? 18 : 22} fw={700} lh={1.1}>
        {day}
      </Text>
      <Text fz={12} fw={500} c="var(--mantine-color-primary-light-color)" lh={1.3}>
        {month}
      </Text>
    </Box>
  )
}
