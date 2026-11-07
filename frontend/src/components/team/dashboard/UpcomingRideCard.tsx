import { useTranslation } from 'react-i18next'
import { Anchor, Badge, Button, Group, Paper, Progress, Stack, Text } from '@mantine/core'
import {
  IconCheck,
  IconMessageCircle,
  IconMountain,
  IconRoute,
  IconRouteOff,
  IconStack2,
} from '@tabler/icons-react'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { Stat, SurfaceBadge } from '@/components/card/common'
import type { RideDto, RideGroupSummaryDto } from '@/api/dto'
import { useUnits } from '@/hooks/useUnits'
import { useRendezvousFormat } from '@/hooks/useRendezvousFormat'
import { ZoneMentionIcon } from '@/components/common/Rendezvous'
import { groupLeavesAtOwnTime, startFor } from '@/utils/groupStart'
import { publicationEditPath, publicationPath, rideHasNoRoute } from './dashboardHelpers'

interface UpcomingRideCardProps {
  ride: RideDto
  /** Team ADMIN or ORGANIZER: adds « Modifier ». */
  canManage: boolean
}

/**
 * A card of « Sorties à venir »: the ride's metrics (from its route, or else its first routed
 * group — `RideDto.distance`), then one line per group with its fill. Registration happens on the
 * ride page, where the groups can be compared: « S'inscrire » leads there.
 */
export function UpcomingRideCard({ ride, canManage }: UpcomingRideCardProps) {
  const { t } = useTranslation()
  const { distance, elevation } = useUnits()
  // The departure, a rendezvous in the ride's zone (docs/LEDGER_*.md API-60).
  const departure = useRendezvousFormat(ride.timezone)
  const ridePath = publicationPath(ride)
  const groups = [...ride.groupSummaries].sort((a, b) => a.sortOrder - b.sortOrder)
  // The departure that concerns the reader (docs/LEDGER_*.md WEB-136): their group's when they
  // joined one, else the ride's. The group lines are read against it.
  const start = startFor(ride)

  return (
    <Paper withBorder radius="md" p="md" data-testid="dashboard-ride-card">
      <Stack gap="sm" h="100%">
        <Group gap="xs" wrap="wrap">
          {ride.surfaceType && (
            <SurfaceBadge surface={ride.surfaceType}>
              {t(
                `routes.surfaceType.${ride.surfaceType satisfies 'ROAD' | 'GRAVEL' | 'MTB' | 'MIXED'}`
              )}
            </SurfaceBadge>
          )}
          {ride.registered && (
            <Badge color="primary" variant="light" size="sm" leftSection={<IconCheck size={12} />}>
              {t('publications.registered')}
            </Badge>
          )}
        </Group>

        <div>
          <Anchor component={PrefetchLink} to={ridePath} fw={600} c="inherit" lineClamp={2}>
            {ride.name}
          </Anchor>
          <Text size="sm" c="dimmed" suppressHydrationWarning={departure.isGuessedText}>
            {departure.formatPattern(start, 'EEE d MMM')} · {departure.formatTime(start)}
            <ZoneMentionIcon
              mention={departure.mention(start)}
              isGuessed={departure.isGuessedTimezone}
            />
          </Text>
        </div>

        <Group gap="md" wrap="wrap">
          {ride.distance !== undefined && (
            <Stat icon={<IconRoute size={16} />}>{distance(ride.distance)}</Stat>
          )}
          {ride.elevationGain !== undefined && (
            <Stat icon={<IconMountain size={16} />}>{elevation(ride.elevationGain)}</Stat>
          )}
          <Stat icon={<IconStack2 size={16} />}>
            {t('groups.groupCount', { count: groups.length || ride.groupCount })}
          </Stat>
          {ride.commentCount !== undefined && (
            <Stat icon={<IconMessageCircle size={16} />}>
              {t('comments.count', { count: ride.commentCount })}
            </Stat>
          )}
        </Group>

        {groups.length > 0 && (
          <Stack gap={8}>
            {groups.map((group) => (
              <GroupFill
                key={group.id}
                group={group}
                timezone={ride.timezone}
                headerStart={start}
                mine={ride.registered && group.id === ride.registeredGroupId}
              />
            ))}
          </Stack>
        )}

        {rideHasNoRoute(ride) && (
          <Group gap={6} wrap="nowrap">
            <IconRouteOff size={16} color="var(--mantine-color-dimmed)" />
            <Text size="sm" c="dimmed">
              {t('teams.dashboard.ride.noRoute')}
            </Text>
          </Group>
        )}

        <Group gap="xs" mt="auto">
          <Button
            component={PrefetchLink}
            to={ridePath}
            size="xs"
            variant={ride.registered ? 'light' : 'filled'}
          >
            {ride.registered ? t('home.nextRide.view') : t('teams.dashboard.ride.register')}
          </Button>
          {canManage && (
            <Button
              component={PrefetchLink}
              to={publicationEditPath(ride)}
              size="xs"
              variant="default"
            >
              {t('teams.dashboard.ride.edit')}
            </Button>
          )}
        </Group>
      </Stack>
    </Paper>
  )
}

/**
 * One group: a check on the reader's own, name, pace, its departure when it differs from the one
 * in the card's header (WEB-136; the header carries the zone mention), and how full it is —
 * « Complet », « 11 / 16 », or a count when uncapped.
 */
function GroupFill({
  group,
  timezone,
  headerStart,
  mine,
}: {
  group: RideGroupSummaryDto
  timezone: string
  /** The departure the card's header gives: the reader's group's, else the ride's. */
  headerStart: string
  /** Whether the reader joined this group. */
  mine: boolean
}) {
  const { t } = useTranslation()
  const { speed } = useUnits()
  const departure = useRendezvousFormat(timezone)
  const max = group.maxParticipants
  const ownTime = groupLeavesAtOwnTime(group.startAt, headerStart)

  return (
    <Stack gap={2}>
      <Group justify="space-between" gap="xs" wrap="nowrap">
        <Text size="sm" fw={500} truncate>
          {mine ? (
            <IconCheck
              size={14}
              aria-label={t('publications.registered')}
              role="img"
              color="var(--mantine-color-primary-filled)"
              style={{ verticalAlign: 'middle', marginInlineEnd: 4 }}
            />
          ) : null}
          {group.name}
          {group.averageSpeed ? (
            <Text span size="sm" c="dimmed">
              {' '}
              {speed(group.averageSpeed)}
            </Text>
          ) : null}
          {ownTime ? (
            <Text span size="sm" c="dimmed" suppressHydrationWarning={departure.isGuessedText}>
              {' · '}
              {t('teams.dashboard.ride.groupStart', { time: departure.formatTime(group.startAt) })}
            </Text>
          ) : null}
        </Text>
        {group.full ? (
          <Badge color="danger" variant="light" size="sm">
            {t('rides.detail.groups.full')}
          </Badge>
        ) : (
          <Text size="sm" c="dimmed" style={{ whiteSpace: 'nowrap' }}>
            {max
              ? t('teams.dashboard.ride.fill', { current: group.countParticipants, max })
              : t('teams.dashboard.ride.registeredCount', { count: group.countParticipants })}
          </Text>
        )}
      </Group>
      {max ? (
        <Progress
          value={Math.min(100, (group.countParticipants / max) * 100)}
          color={group.full ? 'danger' : 'primary'}
          size="sm"
          aria-label={t('teams.dashboard.ride.fill', { current: group.countParticipants, max })}
        />
      ) : null}
    </Stack>
  )
}
