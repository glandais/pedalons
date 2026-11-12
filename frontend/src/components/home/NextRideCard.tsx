import { PrefetchLink } from '@/components/common/PrefetchLink'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import {
  Anchor,
  Badge,
  Box,
  Button,
  Flex,
  Group,
  Paper,
  SimpleGrid,
  Stack,
  Text,
  Title,
} from '@mantine/core'
import { IconCheck, IconUsers } from '@tabler/icons-react'
import type { RideDto } from '@/api/dto'
import { Status } from '@/api/dto'
import { useLeaveGroup } from '@/api/endpoints/rides/rides'
import { CardDayOverlay, CardImage, CardTeamLink, Stat, cardBanner } from '../card/common'
import { DepartureLine } from '../common/DepartureLine'
import { GroupPlaceLine } from '../common/GroupPlaceLine'
import { paths } from '@/config/paths'
import { invalidateRegistration } from '@/lib/registration'
import { useUnits } from '@/hooks/useUnits'
import { useResolvedColorScheme } from '@/hooks/useResolvedColorScheme'
import { registeredGroupOf, startFor } from '@/utils/groupStart'
import { isOver } from '@/utils/publicationEnd'
import { GpsMenuButton } from '@/components/route/GpsMenuButton'
import { GroupPeopleRow } from '@/components/ride/group/GroupPeopleRow'
import { useParticipantsLabel } from '@/hooks/useParticipantsLabel'
import { LeaveGroupLink } from '@/components/ride/group/LeaveGroupLink'
import { RideWeatherSummaryLine } from '../weather/RideWeatherSummaryLine'

interface NextRideCardProps {
  ride: RideDto
  /** Id of the heading, for the section that wraps the card to be labelled by it. */
  headingId?: string
}

/**
 * "Ma prochaine sortie" — the ride the user is registered for that comes next.
 *
 * Its group is `registeredGroup`, which list rows carry even though `groups` is empty there
 * (`view=COMPACT`); the route comes from that group, then from the ride, and the distance is the
 * server's `displayDistance` (API-178). No leader is
 * shown: the leader belongs to the ride page, and is never the ride's creator.
 *
 * The heading and the ride's name share one parent (the e2e `ssr-session` spec reads the card
 * through the heading), and the card itself is not a link: the feed's card is the ride's link. The
 * name is one, as everywhere else a ride's name is shown, and so is the thumbnail.
 */
export function NextRideCard({ ride, headingId }: NextRideCardProps) {
  const { t } = useTranslation()
  const { distance, elevation } = useUnits()
  // Departures are rendezvous, in the ride's zone (docs/LEDGER_*.md API-60).
  const colorScheme = useResolvedColorScheme()
  const queryClient = useQueryClient()
  const leaveMutation = useLeaveGroup()
  const participantsLabel = useParticipantsLabel()

  const group = registeredGroupOf(ride)
  // The departure that concerns the reader is their group's (docs/LEDGER_*.md WEB-136): the day
  // box, the « Demain » pill and the departure line all read it (WEB-138).
  const start = startFor(ride, group)
  // The server's distance for the reader — their group's route, else the ride's (docs/LEDGER_*.md
  // API-178, R3): the card shows it as is, and nothing when it is absent.
  const rideDistance = ride.displayDistance
  const rideElevation = ride.displayElevationGain
  const routeSlug = group?.routeSlug ?? ride.routeSlug
  const ridePath = paths.ride(ride.team.slug, ride.slug)

  // The banner, as the feed's card (docs/LEDGER_*.md WEB-167, R10): the ride's photo, else the
  // map of the reader's group's route — the ride's when it has none —, themed; else the gradient.
  const banner = cardBanner(
    {
      media: ride.media,
      thumbnailLightUrl: group?.thumbnailLightUrl ?? ride.thumbnailLightUrl,
      thumbnailDarkUrl: group?.thumbnailDarkUrl ?? ride.thumbnailDarkUrl,
      thumbnailUrl: group?.thumbnailUrl ?? ride.thumbnailUrl,
    },
    colorScheme
  )
  const thumbnailUrl = banner.kind === 'gradient' ? undefined : banner.url

  // Leaving is not confirmed: it is undone by joining again, only a deletion is (KIT §9, as the app).
  const handleLeave = () => {
    if (!ride.registeredGroupId) return
    leaveMutation.mutate(
      { teamSlug: ride.team.slug, rideSlug: ride.slug, groupId: ride.registeredGroupId },
      {
        onSuccess: () => {
          invalidateRegistration(queryClient, ride.team.slug)
          notifications.show({ message: t('rides.notifications.left'), color: 'green' })
        },
      }
    )
  }

  // Until the ride is over — after its start too — and never on a cancelled one, as on the group's
  // card: leaving and the route's « GPS » (docs/LEDGER_*.md WEB-167, R6 and R7).
  const stillRiding = ride.status !== Status.CANCELLED && !isOver(ride)

  return (
    <Paper withBorder radius="md" style={{ overflow: 'hidden' }} h="100%">
      <Flex direction={{ base: 'column', sm: 'row' }} h="100%">
        {/* The thumbnail opens the ride too; the name stays the link assistive tech reads. */}
        <Box
          component={PrefetchLink}
          to={ridePath}
          tabIndex={-1}
          aria-hidden
          display="block"
          pos="relative"
          w={{ base: '100%', sm: 260 }}
          style={{ flexShrink: 0, alignSelf: 'stretch' }}
        >
          <CardImage
            media={ride.media}
            alt={ride.name}
            type="RIDE"
            height={220}
            thumbnailUrl={thumbnailUrl}
            sizes="(min-width: 48em) 260px, 100vw"
            priority
          />
          {/* The day box posed on the picture and, today or tomorrow only, the pill — no more
              « dans 3 jours » (docs/BRANDING.md §7.1 and §8.3). */}
          <CardDayOverlay
            date={start}
            zone={ride.timezone}
            // No « Aujourd'hui » on a ride already started or cancelled (MOB-115, as the feed).
            showRelative={!ride.finished && ride.status !== Status.CANCELLED}
            extra={
              <Badge color="primary" variant="filled" leftSection={<IconCheck size={12} />}>
                {t('publications.registered')}
              </Badge>
            }
          />
        </Box>

        <Stack gap="sm" p="md" style={{ flex: 1, minWidth: 0 }}>
          {/* The heading is a direct child of the box holding the whole card body: the e2e
              specs (ssr-session, rides) read the card through the heading's parent. */}
          <Title id={headingId} order={2} size="h5" c="dimmed" tt="uppercase">
            {t('home.nextRide.title')}
          </Title>
          <Title order={3} lineClamp={2} mt={-8}>
            <Anchor component={PrefetchLink} to={ridePath} inherit c="inherit">
              {ride.name}
            </Anchor>
          </Title>

          <CardTeamLink teamSlug={ride.team.slug} teamName={ride.team.name} />

          <Stack gap={6}>
            {/* The day box sits in the thumbnail, hidden from assistive tech: the line names the
                day for them. */}
            <DepartureLine date={start} zone={ride.timezone} announceDay />
            {/* « Groupe B · Place de la Mairie » under the departure (R11). */}
            <GroupPlaceLine group={group?.name} place={ride.startPlace?.name} />
            <RideWeatherSummaryLine summary={ride.weather} timezone={ride.timezone} />
            {!group && (
              <Stat icon={<IconUsers size={16} />}>{participantsLabel(ride.participantCount)}</Stat>
            )}
          </Stack>

          {/* Who goes in the reader's group: the cluster, « 11/12 personnes », the places bar — the
              group card's row, without « Voir tout »: the card opens the ride (R5). The group is
              named on the line under the departure (R11). */}
          {group && (
            <Box maw={420}>
              <GroupPeopleRow
                participants={group.participants ?? []}
                countParticipants={group.countParticipants}
                maxParticipants={group.maxParticipants}
                full={group.full}
                leaderId={group.leader?.id}
                canSeeParticipants={!!ride.permissions.canSeeParticipants}
              />
            </Box>
          )}

          {(rideDistance !== undefined || rideElevation !== undefined) && (
            <SimpleGrid cols={2} spacing="sm" maw={360}>
              {rideDistance !== undefined && (
                <Paper bg="var(--mantine-color-default-hover)" radius="md" p="xs">
                  <Text size="xs" c="dimmed">
                    {t('home.nextRide.distance')}
                  </Text>
                  <Text fw={700}>{distance(rideDistance)}</Text>
                </Paper>
              )}
              {rideElevation !== undefined && (
                <Paper bg="var(--mantine-color-default-hover)" radius="md" p="xs">
                  <Text size="xs" c="dimmed">
                    {t('home.nextRide.elevation')}
                  </Text>
                  <Text fw={700}>{elevation(rideElevation)}</Text>
                </Paper>
              )}
            </SimpleGrid>
          )}

          <Stack gap={4} mt="auto" align="flex-start">
            <Group gap="xs">
              <Button component={PrefetchLink} to={ridePath}>
                {t('home.nextRide.view')}
              </Button>
              {/* « GPS »: the device, GPX and FIT, read from the route when the menu opens — the
                  row carries only its slug (R7). */}
              {routeSlug && stillRiding && (
                <GpsMenuButton
                  teamSlug={ride.team.slug}
                  routeSlug={routeSlug}
                  size="sm"
                  subtitle={group ? `${group.name} · ${ride.name}` : ride.name}
                />
              )}
            </Group>
            {ride.registeredGroupId && stillRiding && (
              <LeaveGroupLink
                onLeave={handleLeave}
                pending={leaveMutation.isPending}
                label={t('home.nextRide.leave')}
              />
            )}
          </Stack>
        </Stack>
      </Flex>
    </Paper>
  )
}
