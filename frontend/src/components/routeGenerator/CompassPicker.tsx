import { useTranslation } from 'react-i18next'
import { IconCircleDot } from '@tabler/icons-react'
import { Button, SimpleGrid, Stack, Text } from '@mantine/core'
import { CompassPoint } from '@/api/dto'
import { tRegister, type TranslationKey } from '@/lib/i18nUtils'

/** The abbreviation shown on a button, and the full name that labels it for a screen reader. */
const COMPASS: Record<CompassPoint, { short: TranslationKey; full: TranslationKey }> = {
  N: { short: tRegister('rides.weather.compass.N'), full: tRegister('routeGenerator.bearing.N') },
  NE: {
    short: tRegister('rides.weather.compass.NE'),
    full: tRegister('routeGenerator.bearing.NE'),
  },
  E: { short: tRegister('rides.weather.compass.E'), full: tRegister('routeGenerator.bearing.E') },
  SE: {
    short: tRegister('rides.weather.compass.SE'),
    full: tRegister('routeGenerator.bearing.SE'),
  },
  S: { short: tRegister('rides.weather.compass.S'), full: tRegister('routeGenerator.bearing.S') },
  SW: {
    short: tRegister('rides.weather.compass.SW'),
    full: tRegister('routeGenerator.bearing.SW'),
  },
  W: { short: tRegister('rides.weather.compass.W'), full: tRegister('routeGenerator.bearing.W') },
  NW: {
    short: tRegister('rides.weather.compass.NW'),
    full: tRegister('routeGenerator.bearing.NW'),
  },
}

/** Row by row, the centre standing for « Peu importe ». */
const GRID: (CompassPoint | null)[] = [
  CompassPoint.NW,
  CompassPoint.N,
  CompassPoint.NE,
  CompassPoint.W,
  null,
  CompassPoint.E,
  CompassPoint.SW,
  CompassPoint.S,
  CompassPoint.SE,
]

interface CompassPickerProps {
  value: CompassPoint | undefined
  onChange: (value: CompassPoint | undefined) => void
  /** The end is far from the start: the route heads for it, a bearing means nothing. */
  far?: boolean
}

/**
 * The wished direction of a loop: eight bearings around « Peu importe ». With a far end the grid is
 * disabled and shows « Peu importe » (the URL keeps the choice, it applies again if the end comes
 * closer).
 */
export function CompassPicker({ value, onChange, far = false }: CompassPickerProps) {
  const { t } = useTranslation()
  const shown = far ? undefined : value
  return (
    <Stack gap={4}>
      <SimpleGrid
        cols={3}
        spacing={4}
        maw={180}
        role="group"
        aria-label={t('routeGenerator.bearing.label')}
      >
        {GRID.map((point) => {
          const selected = point === null ? shown === undefined : shown === point
          return (
            <Button
              key={point ?? 'any'}
              size="compact-sm"
              variant={selected ? 'filled' : 'default'}
              aria-pressed={selected}
              aria-label={point === null ? t('routeGenerator.bearing.any') : t(COMPASS[point].full)}
              disabled={far}
              onClick={() => onChange(point ?? undefined)}
            >
              {point === null ? <IconCircleDot size={14} aria-hidden /> : t(COMPASS[point].short)}
            </Button>
          )
        })}
      </SimpleGrid>
      {far && (
        <Text size="xs" c="dimmed">
          {t('routeGenerator.bearing.farHint')}
        </Text>
      )}
    </Stack>
  )
}
