import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  IconBolt,
  IconUsers,
  IconClock,
  IconArrowsMaximize,
  IconArrowUp,
  IconShieldCheck,
  IconAlertTriangle,
  IconChevronRight,
} from '@tabler/icons-react'
import {
  Alert,
  Anchor,
  Paper,
  Group,
  Text,
  Button,
  Badge,
  UnstyledButton,
  Box,
} from '@mantine/core'
import type { RideGroupDto, RouteDetailDto, WeatherLegDto } from '@/api/dto'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { GroupWeatherLine } from '@/components/weather'
import { paths } from '@/config/paths'
import { UserAvatar, UserAvatarGroup } from '../common/UserAvatar'
import { ParticipantListModal } from './ParticipantListModal'
import { RideGroupRouteActions } from './RideGroupRouteActions'
import { useUnits } from '@/hooks/useUnits'
import { Rendezvous } from '../common/Rendezvous'
import { groupLeavesAtOwnTime } from '@/utils/groupStart'

interface RideGroupCardProps {
  group: RideGroupDto
  /** The ride's zone: a group departure is a rendezvous read in it (docs/LEDGER_*.md API-60). */
  rideTimezone: string
  /** The ride's departure: the group's time shows only when `startAt` is another instant. */
  rideDateTime: string
  teamSlug: string
  rideSlug: string
  rideRouteSlug?: string
  /**
   * Every route referenced by the ride, keyed by slug — the parent (`RideDetailPage`) fetches
   * them all in one `getRoutesBulk` call and shares the map across every group card, rather
   * than each card issuing its own `getRoute`.
   */
  routesBySlug: Map<string, RouteDetailDto>
  /**
   * The colour of the group's trace on the ride's map (`routeColorsById`), recalled by a bar in
   * front of its name; absent when the group has no trace of its own on the map.
   */
  trackColor?: string
  /**
   * The group's leg of the ride's forecast, when it has one (OK or STALE): a line on the card, not
   * a link — the whole weather is on the group's page.
   */
  weatherLeg?: WeatherLegDto
  canJoin?: boolean
  onJoin?: () => void
  onLeave?: () => void
  isLoading?: boolean
  onHover?: (groupId: string | null) => void
  isHighlighted?: boolean
  /** Why the last join/leave on THIS group failed. Persists until the next attempt. */
  error?: string
}

export function RideGroupCard({
  group,
  rideTimezone,
  rideDateTime,
  teamSlug,
  rideSlug,
  rideRouteSlug,
  routesBySlug,
  trackColor,
  weatherLeg,
  canJoin,
  onJoin,
  onLeave,
  isLoading,
  onHover,
  isHighlighted = false,
  error,
}: RideGroupCardProps) {
  const { t } = useTranslation()
  const { speed, distance, elevation } = useUnits()
  const [showParticipants, setShowParticipants] = useState(false)
  // `full` and `registered` are computed server-side (contract 1.3.0) — never recompute them here.
  const isFull = group.full
  const isJoined = group.registered

  // Determine effective route slug (group route or ride route as fallback)
  const effectiveRouteSlug = group.routeSlug || rideRouteSlug

  // Distance and elevation come from the group itself (RideGroupDto). The route is only
  // needed to build the GPX/FIT links and the device upload; `routesBySlug` was fetched once
  // for every group of the ride in a single bulk call by the parent.
  const route = effectiveRouteSlug ? routesBySlug.get(effectiveRouteSlug) : undefined

  return (
    <Paper
      shadow={isHighlighted ? 'md' : 'xs'}
      p="md"
      withBorder
      style={{
        borderColor: isHighlighted
          ? 'var(--mantine-primary-color-filled)'
          : isJoined
            ? 'var(--mantine-primary-color-filled)'
            : undefined,
        backgroundColor: isHighlighted ? 'var(--mantine-primary-color-light)' : undefined,
        boxShadow: isJoined ? '0 0 0 1px var(--mantine-primary-color-filled)' : undefined,
        transition: 'all 150ms ease',
      }}
      onMouseEnter={() => onHover?.(group.id)}
      onMouseLeave={() => onHover?.(null)}
    >
      {/* Header row: title + badge + button */}
      <Group justify="space-between" wrap="nowrap">
        <Group gap="sm" style={{ minWidth: 0 }}>
          {trackColor && (
            <Box
              data-testid="group-track-color"
              aria-hidden
              w={4}
              h={20}
              style={{ flexShrink: 0, borderRadius: 2, backgroundColor: trackColor }}
            />
          )}
          <Anchor
            component={PrefetchLink}
            to={paths.rideGroup(teamSlug, rideSlug, group.id)}
            fw={500}
            c="inherit"
            underline="hover"
            style={{ minWidth: 0 }}
          >
            <Group gap={2} wrap="nowrap">
              <Text fw={500} truncate inherit>
                {group.name}
              </Text>
              <IconChevronRight size={16} aria-hidden style={{ flexShrink: 0 }} />
            </Group>
          </Anchor>
          {isJoined && (
            <Badge size="sm" color="primary" variant="light">
              {t('rides.detail.groups.joined')}
            </Badge>
          )}
        </Group>

        {(canJoin || isJoined) && (
          <>
            {isJoined ? (
              <Button variant="outline" size="xs" onClick={onLeave} disabled={isLoading}>
                {t('rides.detail.groups.leave')}
              </Button>
            ) : canJoin && !isFull ? (
              <Button size="xs" onClick={onJoin} disabled={isLoading}>
                {t('rides.detail.groups.join')}
              </Button>
            ) : isFull ? (
              <Badge color="gray" variant="light">
                {t('rides.detail.groups.full')}
              </Badge>
            ) : null}
          </>
        )}
      </Group>

      {/* Leader — rendered only when one is designated; no fallback on the ride's creator */}
      {group.leader && (
        <Group gap="xs" mt="xs" wrap="nowrap">
          <UserAvatar user={group.leader} size="sm" />
          <Text size="sm" truncate>
            {group.leader.displayName}
          </Text>
          <Badge
            size="sm"
            variant="light"
            leftSection={<IconShieldCheck size={12} />}
            style={{ flexShrink: 0 }}
          >
            {t('rides.detail.groups.leader')}
          </Badge>
        </Group>
      )}

      {/* Details row */}
      <Group mt="xs">
        {/* The group leaves at its own time: `startAt` is not the ride's instant (never the
            deprecated `time`, docs/LEDGER_*.md API-60). */}
        {groupLeavesAtOwnTime(group.startAt, rideDateTime) && (
          <Group gap={4}>
            <IconClock size={16} />
            <Text size="sm" c="dimmed">
              <Rendezvous date={group.startAt} zone={rideTimezone} format="time" />
            </Text>
          </Group>
        )}
        {group.averageSpeed && (
          <Group gap={4}>
            <IconBolt size={16} />
            <Text size="sm" c="dimmed">
              {speed(group.averageSpeed)}
            </Text>
          </Group>
        )}
        {group.distance !== undefined && (
          <Group gap="md" wrap="nowrap">
            <Group gap={4}>
              <IconArrowsMaximize size={16} />
              <Text size="sm" c="dimmed">
                {distance(group.distance)}
              </Text>
            </Group>
            {group.elevationGain !== undefined && (
              <Group gap={4}>
                <IconArrowUp size={16} />
                <Text size="sm" c="dimmed">
                  {elevation(group.elevationGain)}
                </Text>
              </Group>
            )}
          </Group>
        )}
        <UnstyledButton
          onClick={() => setShowParticipants(true)}
          title={t('rides.detail.groups.viewParticipants')}
          aria-label={t('rides.detail.groups.viewParticipants')}
          style={{ borderRadius: 'var(--mantine-radius-sm)' }}
        >
          <Group gap="sm">
            {group.participants.length > 0 && (
              <UserAvatarGroup
                users={group.participants}
                total={group.countParticipants}
                max={5}
                size="sm"
              />
            )}
            <Group gap={4}>
              <IconUsers size={16} />
              <Text size="sm" c="dimmed">
                {group.maxParticipants
                  ? t('rides.detail.groups.participants', {
                      current: group.countParticipants,
                      max: group.maxParticipants,
                    })
                  : t('rides.detail.groups.participantsNoMax', {
                      current: group.countParticipants,
                    })}
              </Text>
            </Group>
            {group.countParticipants > 5 && (
              <Text size="xs" fw={500} c="var(--mantine-primary-color-filled)">
                {t('rides.detail.groups.viewAll')}
              </Text>
            )}
          </Group>
        </UnstyledButton>
      </Group>

      <Box mt="xs">
        <GroupWeatherLine leg={weatherLeg} timezone={rideTimezone} />
      </Box>

      {/* The group's page, then its route */}
      <Group mt="sm" gap="md" wrap="wrap">
        <Anchor
          component={PrefetchLink}
          to={paths.rideGroup(teamSlug, rideSlug, group.id)}
          size="xs"
          fw={500}
        >
          <Group gap={2} wrap="nowrap">
            {t('rides.group.view')}
            <IconChevronRight size={14} aria-hidden />
          </Group>
        </Anchor>
        {effectiveRouteSlug && (
          <RideGroupRouteActions
            teamSlug={teamSlug}
            routeSlug={effectiveRouteSlug}
            route={route}
            withViewLink={false}
          />
        )}
      </Group>

      {error && (
        <Alert color="red" variant="light" mt="sm" icon={<IconAlertTriangle size={16} />}>
          {error}
        </Alert>
      )}

      <ParticipantListModal
        isOpen={showParticipants}
        onClose={() => setShowParticipants(false)}
        source={{ kind: 'ride', teamSlug, rideSlug, groupId: group.id }}
        count={group.countParticipants}
        groupName={group.name}
        leaderId={group.leader?.id}
      />
    </Paper>
  )
}
