import { useTranslation } from 'react-i18next'
import { Anchor, Badge, Button, Group, Paper, Stack } from '@mantine/core'
import { IconCheck, IconMapPin, IconUsers, IconRoute } from '@tabler/icons-react'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { DayBox } from '@/components/common/DayBox'
import { DepartureLine, PublicationDepartureLine } from '@/components/common/DepartureLine'
import { Stat, TypeBadge } from '@/components/card/common'
import type { PublicationDto, RideDto, TripDto } from '@/api/dto'
import { useUnits } from '@/hooks/useUnits'
import { startFor } from '@/utils/groupStart'
import { isTrip, publicationPath } from './dashboardHelpers'
import { SendToDeviceMenu } from './SendToDeviceMenu'

/**
 * « Vos prochaines sorties »: the team's rides and trips the user is registered to, soonest first.
 * A ride's group is `registeredGroup` — the list row carries it although `groups` is empty — with
 * its name and pace. No leader here: it belongs to the ride page.
 */
export function MyUpcomingList({ publications }: { publications: PublicationDto[] }) {
  return (
    <Stack gap="sm">
      {publications.map((publication) =>
        isTrip(publication) ? (
          <TripRow key={publication.id} trip={publication} />
        ) : publication.type === 'RIDE' ? (
          <RideRow key={publication.id} ride={publication as RideDto} />
        ) : null
      )}
    </Stack>
  )
}

function RegisteredBadge() {
  const { t } = useTranslation()
  return (
    <Badge color="primary" variant="light" size="sm" leftSection={<IconCheck size={12} />}>
      {t('publications.registered')}
    </Badge>
  )
}

function RideRow({ ride }: { ride: RideDto }) {
  const { t } = useTranslation()
  const { speed } = useUnits()
  // Rendezvous in the ride's zone, the day box included (docs/LEDGER_*.md API-60). The departure
  // is the registered group's, which may not be the ride's (WEB-136).
  const group = ride.registeredGroup
  const routeSlug = group?.routeSlug ?? ride.routeSlug
  const startAt = startFor(ride, group)

  return (
    <Paper withBorder radius="md" p="md">
      <Group wrap="wrap" gap="md" align="center">
        <DayBox date={startAt} zone={ride.timezone} />
        <Stack gap={4} style={{ flex: '1 1 220px', minWidth: 0 }}>
          <Group gap="xs" wrap="wrap">
            <Anchor component={PrefetchLink} to={publicationPath(ride)} fw={600} c="inherit">
              {ride.name}
            </Anchor>
            <RegisteredBadge />
          </Group>
          <DepartureLine date={startAt} zone={ride.timezone} size="sm" />
          <Group gap="md" wrap="wrap">
            {ride.startPlace && <Stat icon={<IconMapPin size={16} />}>{ride.startPlace.name}</Stat>}
            {group && (
              <Stat icon={<IconUsers size={16} />}>
                {group.averageSpeed
                  ? t('teams.dashboard.groupPace', {
                      group: group.name,
                      pace: speed(group.averageSpeed),
                    })
                  : group.name}
              </Stat>
            )}
          </Group>
        </Stack>
        <Group gap="xs">
          {routeSlug && <SendToDeviceMenu teamSlug={ride.team.slug} routeSlug={routeSlug} />}
          <Button component={PrefetchLink} to={publicationPath(ride)} variant="light" size="xs">
            {t('home.nextRide.view')}
          </Button>
        </Group>
      </Group>
    </Paper>
  )
}

function TripRow({ trip }: { trip: TripDto }) {
  const { t } = useTranslation()
  const { distance } = useUnits()

  return (
    <Paper withBorder radius="md" p="md">
      <Group wrap="wrap" gap="md" align="center">
        <DayBox date={trip.dateTime} zone={trip.timezone} tone="teal" />
        <Stack gap={4} style={{ flex: '1 1 220px', minWidth: 0 }}>
          <Group gap="xs" wrap="wrap">
            <Anchor component={PrefetchLink} to={publicationPath(trip)} fw={600} c="inherit">
              {trip.name}
            </Anchor>
            <TypeBadge type="TRIP">{t('publicationType.trip')}</TypeBadge>
            <RegisteredBadge />
          </Group>
          {/* « ven. 16 → dim. 18 oct. », the last day in the last stage's zone (API-60). */}
          <PublicationDepartureLine publication={trip} size="sm" />
          <Group gap="md" wrap="wrap">
            <Stat icon={<IconRoute size={16} />}>
              {t('trips.card.stageCount', { count: trip.stageCount })}
            </Stat>
            {trip.totalDistance !== undefined && (
              <Stat icon={<IconRoute size={16} />}>{distance(trip.totalDistance)}</Stat>
            )}
          </Group>
        </Stack>
        <Button component={PrefetchLink} to={publicationPath(trip)} variant="light" size="xs">
          {t('teams.dashboard.myUpcoming.viewTrip')}
        </Button>
      </Group>
    </Paper>
  )
}
