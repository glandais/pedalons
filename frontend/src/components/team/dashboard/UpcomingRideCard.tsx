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
import { RegisteredBadge, Stat, StateBadge, SurfaceBadge } from '@/components/card/common'
import { cardState } from '@/utils/cardState'
import type { RideDto, RideGroupSummaryDto } from '@/api/dto'
import { useUnits } from '@/hooks/useUnits'
import { useRendezvousFormat } from '@/hooks/useRendezvousFormat'
import { DepartureLine } from '@/components/common/DepartureLine'
import { someGroupLeavesAtOwnTime, startFor } from '@/utils/groupStart'
import { publicationEditPath, publicationPath, rideHasNoRoute } from './dashboardHelpers'

interface UpcomingRideCardProps {
  /** « Modifier » when its `permissions.canEdit` says so (docs/LEDGER_*.md WEB-166). */
  ride: RideDto
}

/**
 * A card of « Sorties à venir »: the ride's metrics (from its route, or else its first routed
 * group — `RideDto.distance`), then one line per group with its fill. Registration happens on the
 * ride page, where the groups can be compared: « S'inscrire » leads there — or a disabled
 * « Complet » when every group is full and the reader is in none.
 */
export function UpcomingRideCard({ ride }: UpcomingRideCardProps) {
  const { t } = useTranslation()
  const { distance, elevation } = useUnits()
  const ridePath = publicationPath(ride)
  const groups = [...ride.groupSummaries].sort((a, b) => a.sortOrder - b.sortOrder)
  // The departure that concerns the reader (docs/LEDGER_*.md WEB-136): their group's when they
  // joined one, else the ride's. The group lines are read against it.
  const start = startFor(ride)
  // Not registered and every group full: there is no « S'inscrire » to offer.
  const allFull = !ride.registered && groups.length > 0 && groups.every((group) => group.full)

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
          {/* The cards' order (docs/LEDGER_*.md WEB-167, R1): one state, then « J'y vais ». */}
          <StateBadge
            state={cardState({
              status: ride.status,
              start: ride.dateTime,
              end: ride.endDateTime,
            })}
          />
          {ride.registered && <RegisteredBadge />}
        </Group>

        <div>
          <Anchor component={PrefetchLink} to={ridePath} fw={600} c="inherit" lineClamp={2}>
            {ride.name}
          </Anchor>
          {/* No day box here: the line names the day, « sam. 12 avr. · 09:00 » (WEB-138). */}
          <DepartureLine date={start} zone={ride.timezone} size="sm" withDay />
        </div>

        <Group gap="md" wrap="wrap">
          {ride.distance !== undefined && (
            <Stat icon={<IconRoute size={16} />}>{distance(ride.distance)}</Stat>
          )}
          {ride.elevationGain !== undefined && (
            <Stat icon={<IconMountain size={16} />}>{elevation(ride.elevationGain)}</Stat>
          )}
          {/* No counter at zero (R4): « 0 groupe », « 0 commentaire » tell nothing. */}
          {(groups.length || ride.groupCount) > 0 && (
            <Stat icon={<IconStack2 size={16} />}>
              {t('groups.groupCount', { count: groups.length || ride.groupCount })}
            </Stat>
          )}
          {!!ride.commentCount && (
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
                showStartTime={someGroupLeavesAtOwnTime(groups, start)}
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
          {allFull ? (
            // Nowhere left to join: « Complet », not an « S'inscrire » that leads to full groups
            // (docs/LEDGER_*.md WEB-167 N4).
            <Button size="xs" variant="filled" disabled data-testid="dashboard-ride-full">
              {t('rides.detail.groups.full')}
            </Button>
          ) : (
            <Button
              component={PrefetchLink}
              to={ridePath}
              size="xs"
              variant={ride.registered ? 'light' : 'filled'}
            >
              {ride.registered ? t('home.nextRide.view') : t('teams.dashboard.ride.register')}
            </Button>
          )}
          {ride.permissions.canEdit && (
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
 * One group: a check on the reader's own, name, pace, its departure when the ride's groups do not
 * all leave at the header's time (WEB-136; the header carries the zone mention), and how full it is —
 * « Complet », « 11/16 », or « 11 personnes » when uncapped — the cards' one form, the noun left
 * out of this tight line (docs/LEDGER_*.md WEB-167, R5). Its bar is primary, red once full.
 */
function GroupFill({
  group,
  timezone,
  showStartTime,
  mine,
}: {
  group: RideGroupSummaryDto
  timezone: string
  /** The departure the card's header gives: the reader's group's, else the ride's. */
  /** The ride's groups do not all leave at the time in the card's header. */
  showStartTime: boolean
  /** Whether the reader joined this group. */
  mine: boolean
}) {
  const { t } = useTranslation()
  const { speed } = useUnits()
  const departure = useRendezvousFormat(timezone)
  const max = group.maxParticipants

  return (
    <Stack gap={2}>
      {/* The card can be 260 px wide (three columns of `minmax(240px, 1fr)` beside the aside): the
          group's line wraps, a departure time stays whole and the fill never shrinks (« COMP… »,
          « départ 1… » were cut, docs/LEDGER_*.md WEB-167 N23). */}
      <Group justify="space-between" gap="xs" wrap="nowrap" align="flex-start">
        <Text size="sm" fw={500} style={{ minWidth: 0 }}>
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
              <span style={{ whiteSpace: 'nowrap' }}>{speed(group.averageSpeed)}</span>
            </Text>
          ) : null}
          {showStartTime ? (
            <Text span size="sm" c="dimmed" suppressHydrationWarning={departure.isGuessedText}>
              {' · '}
              <span style={{ whiteSpace: 'nowrap' }}>
                {t('teams.dashboard.ride.groupStart', {
                  time: departure.formatTime(group.startAt),
                })}
              </span>
            </Text>
          ) : null}
        </Text>
        {group.full ? (
          <Badge color="danger" variant="light" size="sm" style={{ flexShrink: 0 }}>
            {t('rides.detail.groups.full')}
          </Badge>
        ) : (
          <Text size="sm" c="dimmed" style={{ whiteSpace: 'nowrap', flexShrink: 0 }}>
            {max
              ? t('teams.dashboard.ride.fill', { current: group.countParticipants, max })
              : t('rides.detail.groups.participantsNoMax', { count: group.countParticipants })}
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
