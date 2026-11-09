import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { IconShieldCheck, IconUsers } from '@tabler/icons-react'
import { Badge, Box, Button, Group, Text, UnstyledButton } from '@mantine/core'
import type { RideGroupDto, RouteDetailDto, WeatherLegDto } from '@/api/dto'
import { DepartureLine } from '@/components/common/DepartureLine'
import { UserAvatar, UserAvatarGroup } from '@/components/common/UserAvatar'
import { AboveLink, ChildCard, ChildFacts } from '@/components/publication/ChildCard'
import { GroupWeatherLine } from '@/components/weather'
import { paths } from '@/config/paths'
import { useRendezvousFormat } from '@/hooks/useRendezvousFormat'
import { ParticipantListModal } from './ParticipantListModal'
import { RideGroupRouteActions } from './RideGroupRouteActions'

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
   * The colour of the group's trace on the ride's map (`rideMapRoutes`), recalled by a bar in
   * front of its name — the same for every group on that route; absent when it rides no route.
   */
  trackColor?: string
  /**
   * The group's leg of the ride's forecast, when it has one (OK or STALE): a line on the card, not
   * a link — the whole weather is on the group's page.
   */
  weatherLeg?: WeatherLegDto
  /** Print the group's departure: its ride has groups leaving at different times. */
  showStartTime: boolean
  canJoin?: boolean
  /**
   * Whether the reader may see who takes part (a member of the team, or a platform admin — the
   * comments' rule, docs/LEDGER_*.md API-144). Otherwise the card shows the count only and
   * offers no list: the participants endpoint refuses them. Defaults to true.
   */
  canSeeParticipants?: boolean
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
  showStartTime,
  canJoin,
  canSeeParticipants = true,
  onJoin,
  onLeave,
  isLoading,
  onHover,
  isHighlighted = false,
  error,
}: RideGroupCardProps) {
  const { t } = useTranslation()
  const [showParticipants, setShowParticipants] = useState(false)
  const rendezvous = useRendezvousFormat(rideTimezone)
  // `full` and `registered` are computed server-side (contract 1.3.0) — never recompute them here.
  const isFull = group.full
  const isJoined = group.registered

  // The group's route, else the ride's. Distance and climb come from the group itself; the route
  // only gives the GPX/FIT links, fetched once for every group by the parent (`routesBySlug`).
  const effectiveRouteSlug = group.routeSlug || rideRouteSlug
  const route = effectiveRouteSlug ? routesBySlug.get(effectiveRouteSlug) : undefined

  const participantsLabel = group.maxParticipants
    ? t('rides.detail.groups.participants', {
        current: group.countParticipants,
        count: group.maxParticipants,
      })
    : t('rides.detail.groups.participantsNoMax', { count: group.countParticipants })

  const corner = isJoined ? (
    <Button variant="outline" size="xs" onClick={onLeave} disabled={isLoading}>
      {t('rides.detail.groups.leave')}
    </Button>
  ) : canJoin && !isFull ? (
    <Button size="xs" onClick={onJoin} disabled={isLoading}>
      {t('rides.detail.groups.join')}
    </Button>
  ) : canJoin && isFull ? (
    <Badge color="gray" variant="light">
      {t('rides.detail.groups.full')}
    </Badge>
  ) : null

  return (
    <ChildCard
      href={paths.rideGroup(teamSlug, rideSlug, group.id)}
      name={group.name}
      marker={
        trackColor && (
          <Box
            data-testid="group-track-color"
            aria-hidden
            w={4}
            h={20}
            style={{ flexShrink: 0, borderRadius: 2, backgroundColor: trackColor }}
          />
        )
      }
      badges={
        isJoined && (
          <Badge size="sm" color="primary" variant="light" style={{ flexShrink: 0 }}>
            {t('rides.detail.groups.joined')}
          </Badge>
        )
      }
      corner={corner}
      highlighted={isHighlighted}
      emphasized={isJoined}
      onHover={(hovering) => onHover?.(hovering ? group.id : null)}
      error={error}
      meta={
        <>
          <ChildFacts
            averageSpeed={group.averageSpeed}
            distance={group.distance}
            elevationGain={group.distance !== undefined ? group.elevationGain : undefined}
          />
          {!canSeeParticipants ? (
            <Group gap={4}>
              <IconUsers size={16} aria-hidden />
              <Text size="sm" c="dimmed">
                {participantsLabel}
              </Text>
            </Group>
          ) : (
            <AboveLink>
              <UnstyledButton
                onClick={() => setShowParticipants(true)}
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
                    <IconUsers size={16} aria-hidden />
                    <Text size="sm" c="dimmed">
                      {participantsLabel}
                    </Text>
                  </Group>
                  {group.countParticipants > 5 && (
                    <Text size="xs" fw={500} c="var(--mantine-primary-color-filled)">
                      {t('rides.detail.groups.viewAll')}
                    </Text>
                  )}
                </Group>
              </UnstyledButton>
            </AboveLink>
          )}
        </>
      }
      weather={<GroupWeatherLine leg={weatherLeg} timezone={rideTimezone} />}
      routeActions={
        effectiveRouteSlug && (
          <RideGroupRouteActions
            teamSlug={teamSlug}
            routeSlug={effectiveRouteSlug}
            route={route}
            withViewLink={false}
          />
        )
      }
    >
      {/* The group's own departure (docs/BRANDING.md §7.8, ledger BRAND-8): its time in 700 and the
          day when it is not the ride's — never a dimmed stat. */}
      {showStartTime && (
        <Box
          mt="xs"
          px="sm"
          py={6}
          // Indigo 0, not the « light » variant: the dimmed detail keeps 4.5:1 on it (#666d75 on
          // #edf2ff); dark-6 in dark mode, where the dimmed grey is drawn for it.
          bg="light-dark(var(--mantine-color-primary-0), var(--mantine-color-dark-6))"
          style={{ borderRadius: 'var(--mantine-radius-sm)' }}
          data-testid="group-own-time"
        >
          <DepartureLine
            date={group.startAt}
            zone={rideTimezone}
            withDay={!rendezvous.samePeriod(group.startAt, rideDateTime)}
          />
        </Box>
      )}

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

      {canSeeParticipants && (
        <ParticipantListModal
          isOpen={showParticipants}
          onClose={() => setShowParticipants(false)}
          source={{ kind: 'ride', teamSlug, rideSlug, groupId: group.id }}
          count={group.countParticipants}
          groupName={group.name}
          leaderId={group.leader?.id}
        />
      )}
    </ChildCard>
  )
}
