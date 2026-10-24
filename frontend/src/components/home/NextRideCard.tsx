import { useState } from 'react'
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
  Menu,
  Paper,
  SimpleGrid,
  Stack,
  Text,
  Title,
} from '@mantine/core'
import {
  IconCalendar,
  IconCheck,
  IconDeviceWatch,
  IconMapPin,
  IconUsers,
} from '@tabler/icons-react'
import type { GpsServiceType, RideDto } from '@/api/dto'
import { useLeaveGroup } from '@/api/endpoints/rides/rides'
import { CardImage, CardTeamLink, Stat } from '../card/common'
import { ConfirmDialog } from '../common/ConfirmDialog'
import { paths } from '@/config/paths'
import { invalidateRideRegistration } from '@/lib/rideRegistration'
import { useUnits } from '@/hooks/useUnits'
import { useGpsConnections } from '@/hooks/useGpsConnections'
import { useResolvedColorScheme } from '@/hooks/useResolvedColorScheme'
import { useFormattedDate } from '@/utils/dateFormat'
import { Rendezvous } from '../common/Rendezvous'
import { useRendezvousFormat } from '@/hooks/useRendezvousFormat'
import { groupLeavesAtOwnTime } from '@/utils/groupStart'
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
 * (`view=COMPACT`); metrics and the route come from that group, then from the ride. No leader is
 * shown: the leader belongs to the ride page, and is never the ride's creator.
 *
 * The heading and the ride's name share one parent (the e2e `ssr-session` spec reads the card
 * through the heading), and the card itself is not a link: the feed's card is the ride's link. The
 * name is one, as everywhere else a ride's name is shown, and so is the thumbnail.
 */
export function NextRideCard({ ride, headingId }: NextRideCardProps) {
  const { t } = useTranslation()
  const { distance, elevation } = useUnits()
  const { formatRelative } = useFormattedDate()
  // Departures are rendezvous, in the ride's zone (docs/LEDGER_*.md API-60).
  const departure = useRendezvousFormat(ride.timezone)
  const colorScheme = useResolvedColorScheme()
  const queryClient = useQueryClient()
  const leaveMutation = useLeaveGroup()
  const { connectedServices, uploadRoute, isUploading } = useGpsConnections()
  const [showLeaveConfirm, setShowLeaveConfirm] = useState(false)

  const group =
    ride.registeredGroup ?? ride.groups?.find((g) => g.id === ride.registeredGroupId) ?? undefined
  const rideDistance = group?.distance
  const rideElevation = group?.elevationGain
  const routeSlug = group?.routeSlug ?? ride.routeSlug
  const ridePath = paths.ride(ride.team.slug, ride.slug)

  // The map of the group's route first, then the ride's own picture; themed when possible.
  const thumbnailUrl =
    (colorScheme === 'dark'
      ? (group?.thumbnailDarkUrl ?? ride.thumbnailDarkUrl)
      : (group?.thumbnailLightUrl ?? ride.thumbnailLightUrl)) ??
    group?.thumbnailUrl ??
    ride.thumbnailUrl

  const handleLeave = () => {
    if (!ride.registeredGroupId) return
    leaveMutation.mutate(
      { teamSlug: ride.team.slug, rideSlug: ride.slug, groupId: ride.registeredGroupId },
      {
        onSuccess: () => {
          invalidateRideRegistration(queryClient, ride.team.slug)
          notifications.show({ message: t('rides.notifications.left'), color: 'green' })
          setShowLeaveConfirm(false)
        },
      }
    )
  }

  const participants = group
    ? group.maxParticipants
      ? t('rides.detail.groups.participants', {
          current: group.countParticipants,
          count: group.maxParticipants,
        })
      : t('rides.detail.groups.participantsNoMax', { count: group.countParticipants })
    : t('rides.detail.groups.participantsNoMax', { count: ride.participantCount })

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
          <Group pos="absolute" top={12} left={12} gap={6}>
            <Badge color="gray" variant="white" leftSection={<IconCalendar size={12} />}>
              {/* Read off the clock: server and client may render it a few seconds apart. */}
              <span suppressHydrationWarning>{formatRelative(ride.dateTime)}</span>
            </Badge>
            <Badge color="primary" variant="filled" leftSection={<IconCheck size={12} />}>
              {t('publications.registered')}
            </Badge>
          </Group>
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
            <Stat icon={<IconCalendar size={16} />}>
              <Rendezvous date={ride.dateTime} zone={ride.timezone} variant="detail" />
            </Stat>
            {ride.startPlace && <Stat icon={<IconMapPin size={16} />}>{ride.startPlace.name}</Stat>}
            <RideWeatherSummaryLine summary={ride.weather} timezone={ride.timezone} />
            <Stat icon={<IconUsers size={16} />}>
              {group
                ? t('home.nextRide.groupParticipants', {
                    group: groupLeavesAtOwnTime(group.startAt, ride.dateTime)
                      ? t('home.nextRide.groupAndTime', {
                          group: group.name,
                          time: departure.formatTime(group.startAt),
                        })
                      : group.name,
                    participants,
                  })
                : participants}
            </Stat>
          </Stack>

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

          <Group gap="xs" mt="auto">
            <Button component={PrefetchLink} to={ridePath}>
              {t('home.nextRide.view')}
            </Button>
            {routeSlug && connectedServices.length > 0 && (
              <Menu shadow="md" width={200}>
                <Menu.Target>
                  <Button
                    variant="default"
                    loading={isUploading}
                    leftSection={<IconDeviceWatch size={16} />}
                  >
                    {t('routes.detail.sendToDevice')}
                  </Button>
                </Menu.Target>
                <Menu.Dropdown>
                  {connectedServices.map((service) => (
                    <Menu.Item
                      key={service.serviceType}
                      onClick={() =>
                        uploadRoute({
                          serviceType: service.serviceType,
                          teamSlug: ride.team.slug,
                          routeSlug,
                        })
                      }
                    >
                      {t(
                        `gps.services.${service.serviceType.toLowerCase() as Lowercase<GpsServiceType>}`
                      )}
                    </Menu.Item>
                  ))}
                </Menu.Dropdown>
              </Menu>
            )}
            {ride.registeredGroupId && (
              <Button variant="subtle" color="gray" onClick={() => setShowLeaveConfirm(true)}>
                {t('home.nextRide.leave')}
              </Button>
            )}
          </Group>
        </Stack>
      </Flex>

      <ConfirmDialog
        isOpen={showLeaveConfirm}
        onClose={() => setShowLeaveConfirm(false)}
        onConfirm={handleLeave}
        title={t('home.nextRide.leaveConfirm.title')}
        message={t('home.nextRide.leaveConfirm.message', { name: ride.name })}
        confirmText={t('home.nextRide.leave')}
        variant="warning"
        isLoading={leaveMutation.isPending}
      />
    </Paper>
  )
}
