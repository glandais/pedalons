import { useTranslation } from 'react-i18next'
import { SegmentedControl } from '@mantine/core'

/** Every way a route's line can be coloured: the grade, the surface (WEB-100 C1b), the wind (WEB-115). */
export type ColorByOption = 'grade' | 'surface' | 'wind'

/**
 * Every mode the switch can name: a route's line modes, plus a map of several routes' default — one
 * colour per stage, on a trip's overview (« Étapes | Météo », WEB-118). Never in a `?color=`.
 */
export type LineModeOption = ColorByOption | 'stages'

const OPTION_LABEL_KEYS = {
  grade: 'routes.surface.colorBy.grade',
  surface: 'routes.surface.colorBy.surface',
  wind: 'routes.surface.colorBy.wind',
  stages: 'routes.surface.colorBy.stages',
} as const satisfies Record<LineModeOption, string>

interface ColorByControlProps<T extends LineModeOption> {
  value: T
  onChange: (value: T) => void
  /** The modes on offer, in order; with fewer than two the control draws nothing. */
  options: readonly T[]
  /** The control's test hook: the fullscreen map's toolbar names its own. */
  testId?: string
}

/**
 * The switch of what colours a route's line and profile, under its map: « Pente | Revêtement »
 * on a route sheet, « Pente | Météo » or « Pente | Revêtement | Météo » on a group's page, « Étapes |
 * Météo » on a trip's overview — which is why it stands apart from the surface summary, which shows nothing without a surface.
 */
export function ColorByControl<T extends LineModeOption>({
  value,
  onChange,
  options,
  testId = 'route-color-by',
}: ColorByControlProps<T>) {
  const { t } = useTranslation()
  if (options.length < 2) return null
  return (
    <SegmentedControl
      size="xs"
      w="fit-content"
      value={value}
      onChange={(next) => onChange(next as T)}
      // The wind colours the line alone, the profile keeps its grade (WEB-115).
      aria-label={t(
        options.includes('wind' as T)
          ? 'routes.surface.colorBy.lineLabel'
          : 'routes.surface.colorBy.label'
      )}
      data-testid={testId}
      data={options.map((option) => ({ value: option, label: t(OPTION_LABEL_KEYS[option]) }))}
    />
  )
}
