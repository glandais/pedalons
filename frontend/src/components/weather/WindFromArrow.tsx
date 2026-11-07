import type { CSSProperties } from 'react'
import { VisuallyHidden } from '@mantine/core'
import { IconArrowUp } from '@tabler/icons-react'
import type { WindDto } from '@/api/dto'
import { mapWindRotation } from '@/lib/weatherOnRoute'
import { useWeatherLabels } from './useWeatherLabels'

interface WindFromArrowProps {
  wind: Pick<WindDto, 'direction' | 'compass'>
  /** The map's bearing, when the arrow sits on or over a rotated map. */
  bearing?: number
  size?: number
  style?: CSSProperties
}

/**
 * Where the wind blows, north up — the arrow of the map's weather badges, in place of the written
 * compass point (« SO »). Inline: it sits in a line of text, before the speed. The compass point
 * stays for screen readers, hidden, so « SO 18 km/h » is still what they hear.
 */
export function WindFromArrow({ wind, bearing = 0, size = 14, style }: WindFromArrowProps) {
  const labels = useWeatherLabels()
  const compass = labels.compass(wind.compass)
  return (
    <>
      <IconArrowUp
        size={size}
        stroke={2.5}
        aria-hidden
        data-testid="wind-from-arrow"
        style={{
          display: 'inline-block',
          flexShrink: 0,
          verticalAlign: 'middle',
          transform: `rotate(${mapWindRotation(wind.direction, bearing)}deg)`,
          ...style,
        }}
      />
      {compass && <VisuallyHidden>{compass}</VisuallyHidden>}
    </>
  )
}
