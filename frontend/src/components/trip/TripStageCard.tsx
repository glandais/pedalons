import { Badge, Group, Text } from '@mantine/core'
import { IconMapPin } from '@tabler/icons-react'
import type { RideWeatherSummaryDto, TripStageDto } from '@/api/dto'
import { RideWeatherSummaryLine } from '@/components/weather'
import { RideGroupRouteActions } from '@/components/ride/RideGroupRouteActions'
import { ChildCard, ChildFacts } from '@/components/publication/ChildCard'
import { DepartureLine } from '../common/DepartureLine'
import { EntityLogo } from '../common/EntityLogo'
import { paths } from '@/config/paths'

interface TripStageCardProps {
  stage: TripStageDto
  index: number
  teamSlug: string
  tripSlug: string
  onHover?: (stageId: string | null) => void
  isHighlighted?: boolean
  /** The stage's weather line, from `GET …/trips/{tripSlug}/weather` (docs/LEDGER_*.md API-76). */
  weather?: RideWeatherSummaryDto
}

/**
 * A stage in its trip's list: the shared `ChildCard` (docs/LEDGER_*.md WEB-155) — its number or
 * logo, its name linking to its page over the whole card, its departure on the right, its places,
 * pace, distance and climb, its weather line, its route's files and devices. Its description is
 * its page's, not the card's.
 */
export function TripStageCard({
  stage,
  index,
  teamSlug,
  tripSlug,
  onHover,
  isHighlighted = false,
  weather,
}: TripStageCardProps) {
  const places = [stage.startPlace, stage.endPlace]
  return (
    <ChildCard
      href={paths.stage(teamSlug, tripSlug, stage.slug)}
      name={stage.name}
      marker={
        stage.media.assets.logo ? (
          <EntityLogo logo={stage.media.assets.logo} alt={stage.name} size="md" />
        ) : (
          <Badge size="lg" variant="light" color="primary" circle style={{ flexShrink: 0 }}>
            {index + 1}
          </Badge>
        )
      }
      // « sam. 12 avr. · 09:00 » in 700, short enough not to squeeze the name (WEB-138).
      corner={<DepartureLine date={stage.dateTime} zone={stage.timezone} size="sm" withDay />}
      highlighted={isHighlighted}
      onHover={(hovering) => onHover?.(hovering ? stage.id : null)}
      meta={
        <ChildFacts
          averageSpeed={stage.averageSpeed}
          distance={stage.route?.distance}
          elevationGain={stage.route?.elevationGain}
        />
      }
      weather={weather && <RideWeatherSummaryLine summary={weather} timezone={stage.timezone} />}
      routeActions={
        stage.route && (
          <RideGroupRouteActions
            teamSlug={teamSlug}
            routeSlug={stage.route.slug}
            route={stage.route}
            withViewLink={false}
          />
        )
      }
    >
      {places.some(Boolean) && (
        <Group mt="xs" gap="md" wrap="wrap">
          {places.map(
            (place, i) =>
              place && (
                <Group key={i} gap={4} wrap="nowrap">
                  <IconMapPin
                    size={14}
                    aria-hidden
                    color={
                      i === 0 ? 'var(--mantine-color-green-text)' : 'var(--mantine-color-red-text)'
                    }
                  />
                  <Text size="sm">{place.name}</Text>
                </Group>
              )
          )}
        </Group>
      )}
    </ChildCard>
  )
}
