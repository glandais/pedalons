import { useMemo } from 'react'
import type { TrackDto, WeatherLegDto } from '@/api/dto'
import { mapCheckpoints } from '@/lib/weatherOnRoute'
import { useBadgeLayout, type BadgeItem, type BadgeLayout } from './useBadgeLayout'
import { WeatherCheckpointMarkers } from './WeatherCheckpointMarkers'

export interface WeatherLegOnMap {
  id: string
  name?: string
  tracks: Pick<TrackDto, 'line'>[]
  leg: WeatherLegDto
  timezone?: string
}

interface WeatherLegsMarkersProps {
  legs: readonly WeatherLegOnMap[]
  /** The one badge open over the whole map, if any. */
  open: { id: string; index: number } | null
  onOpenChange: (id: string, index: number | null) => void
}

interface LegItem extends BadgeItem<string> {
  legId: string
  index: number
}

/**
 * The forecast's points of several legs on one map (ledgers WEB-118, WEB-142): one room for all of
 * them, so that a badge gives way to the start of another trace as it does to one of its own.
 * Rendered inside the map.
 */
export function WeatherLegsMarkers({ legs, open, onOpenChange }: WeatherLegsMarkersProps) {
  const placed = useMemo(
    () =>
      legs.flatMap((leg) =>
        mapCheckpoints(leg.tracks, leg.leg.checkpoints).map((marker): LegItem => ({
          key: `${leg.id}/${marker.checkpoint.index}`,
          legId: leg.id,
          index: marker.checkpoint.index,
          longitude: marker.longitude,
          latitude: marker.latitude,
          rank: marker.rank,
        }))
      ),
    [legs]
  )
  // The open badge stays, whatever the zoom makes of its neighbours
  const openId = open?.id
  const openIndex = open?.index
  const items = useMemo(
    () =>
      placed.map((item) =>
        item.legId === openId && item.index === openIndex ? { ...item, rank: null } : item
      ),
    [placed, openId, openIndex]
  )
  const layout = useBadgeLayout(items)
  const perLeg = useMemo(() => {
    if (!layout) return undefined
    const result = new Map<string, Map<number, readonly [number, number]>>()
    for (const item of items) {
      const shift = layout.get(item.key)
      if (!shift) continue
      if (!result.has(item.legId)) result.set(item.legId, new Map())
      result.get(item.legId)?.set(item.index, shift)
    }
    return result
  }, [items, layout])

  return (
    <>
      {legs.map((leg) => (
        <WeatherCheckpointMarkers
          key={`weather-${leg.id}`}
          tracks={leg.tracks}
          leg={leg.leg}
          timezone={leg.timezone}
          context={leg.name}
          layout={perLeg ? (perLeg.get(leg.id) ?? NOTHING) : undefined}
          openIndex={open?.id === leg.id ? open.index : null}
          onOpenChange={(index) => onOpenChange(leg.id, index)}
        />
      ))}
    </>
  )
}

const NOTHING: BadgeLayout<number> = new Map()
