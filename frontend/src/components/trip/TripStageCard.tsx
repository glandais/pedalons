import { Badge, Box, Group, Text } from '@mantine/core'
import { IconMapPin } from '@tabler/icons-react'
import type { RideWeatherSummaryDto, TripStageDto } from '@/api/dto'
import { RideWeatherSummaryLine } from '@/components/weather'
import { GpsMenuButton } from '@/components/route/GpsMenuButton'
import { ChildCard, ChildFacts } from '@/components/publication/ChildCard'
import { DepartureLine } from '../common/DepartureLine'
import { EntityLogo } from '../common/EntityLogo'
import { paths } from '@/config/paths'
import { stageIsOver } from '@/utils/publicationEnd'

interface TripStageCardProps {
  stage: TripStageDto
  index: number
  teamSlug: string
  tripSlug: string
  onHover?: (stageId: string | null) => void
  isHighlighted?: boolean
  /** The stage's weather line, from `GET …/trips/{tripSlug}/weather` (docs/LEDGER_*.md API-76). */
  weather?: RideWeatherSummaryDto
  /**
   * The reader takes part in the trip, and it is not cancelled: the stage's « GPS » button, until
   * the stage is over (docs/LEDGER_*.md WEB-167, R7). Anyone else exports from the route's page.
   */
  riding?: boolean
  /**
   * The colour of the stage's trace on the trip's map (`routeColorsById` over the map's items, the
   * ride page's rule), recalled by a short bar after its name as in the app (KIT §8 « la couleur
   * est sur chaque carte d'étape », docs/LEDGER_*.md WEB-167 R10); absent when it rides no route.
   */
  trackColor?: string
}

/**
 * A stage in its trip's list: the shared `ChildCard` (docs/LEDGER_*.md WEB-155) — its number or
 * logo, its name linking to its page over the whole card, its departure on the right, its places,
 * pace, distance and climb, its weather line, and — to a reader who rides it — its route's « GPS »
 * button. Its description is its page's, not the card's.
 */
export function TripStageCard({
  stage,
  index,
  teamSlug,
  tripSlug,
  onHover,
  isHighlighted = false,
  weather,
  riding = false,
  trackColor,
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
      nameTrailing={
        trackColor && (
          <Box
            data-testid="stage-track-color"
            aria-hidden
            w={14}
            h={4}
            ml={6}
            style={{ flexShrink: 0, borderRadius: 2, backgroundColor: trackColor }}
          />
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
        riding &&
        stage.route &&
        !stageIsOver(stage) && (
          <GpsMenuButton
            teamSlug={teamSlug}
            routeSlug={stage.route.slug}
            route={stage.route}
            subtitle={stage.name}
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
