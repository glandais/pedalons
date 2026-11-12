import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { groupTitle } from '@/utils/groupTitle'
import { IconShieldCheck } from '@tabler/icons-react'
import { Badge, Box, Button, Group, Text } from '@mantine/core'
import type { RideGroupDto, RouteDetailDto, WeatherLegDto } from '@/api/dto'
import { DepartureLine } from '@/components/common/DepartureLine'
import { UserAvatar } from '@/components/common/UserAvatar'
import { AboveLink, ChildCard, ChildFacts } from '@/components/publication/ChildCard'
import { GpsMenuButton } from '@/components/route/GpsMenuButton'
import { GroupPeopleRow } from '@/components/ride/group/GroupPeopleRow'
import { LeaveGroupLink } from '@/components/ride/group/LeaveGroupLink'
import { GroupWeatherLine } from '@/components/weather'
import { paths } from '@/config/paths'
import { useRendezvousFormat } from '@/hooks/useRendezvousFormat'
import { useUnits } from '@/hooks/useUnits'
import type { GroupAction } from '@/pages/ride/rideGroupData'
import { ParticipantListModal } from './ParticipantListModal'

interface RideGroupCardProps {
  group: RideGroupDto
  /** The ride's zone: a group departure is a rendezvous read in it (docs/LEDGER_*.md API-60). */
  rideTimezone: string
  /** The ride's departure: the group's time shows only when `startAt` is another instant. */
  rideDateTime: string
  teamSlug: string
  /** The team's name: the « Signaler / Bloquer » menu of the people in « Voir tout » (R13). */
  teamName?: string
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
  /**
   * What the card offers, `groupAction(ride, group)` (docs/LEDGER_*.md WEB-167, R6): « Rejoindre »
   * or a disabled « Complet » in the corner; on the reader's own group, « Quitter le groupe » at the
   * foot and the « GPS » button. Nothing on a cancelled or finished ride.
   */
  action: GroupAction
  /**
   * « Changer pour {groupe} » at the foot of the card: the reader is registered in another group and
   * may move to this one (`canSwitchTo`). One call, no confirmation (ledger API-171, KIT §9).
   */
  canSwitch?: boolean
  /**
   * Whether the reader may see who takes part (a member of the team, or a platform admin — the
   * comments' rule, docs/LEDGER_*.md API-144). Otherwise the card shows the count only and
   * offers no list: the participants endpoint refuses them. Defaults to true.
   */
  canSeeParticipants?: boolean
  onJoin?: () => void
  onLeave?: () => void
  onSwitch?: () => void
  isLoading?: boolean
  onHover?: (groupId: string | null) => void
  isHighlighted?: boolean
  /** Why the last join/leave/switch on THIS group failed. Persists until the next attempt. */
  error?: string
}

export function RideGroupCard({
  group,
  rideTimezone,
  rideDateTime,
  teamSlug,
  teamName,
  rideSlug,
  rideRouteSlug,
  routesBySlug,
  trackColor,
  weatherLeg,
  showStartTime,
  action,
  canSwitch = false,
  canSeeParticipants = true,
  onJoin,
  onLeave,
  onSwitch,
  isLoading,
  onHover,
  isHighlighted = false,
  error,
}: RideGroupCardProps) {
  const { t } = useTranslation()
  const { distance } = useUnits()
  const [showParticipants, setShowParticipants] = useState(false)
  const rendezvous = useRendezvousFormat(rideTimezone)
  // « Groupe B », « Les Rapides » (KIT §9): the card's title, its switch button and its menus.
  const title = groupTitle(group.name, t)
  // `registered` is computed server-side (contract 1.3.0) — never recompute it here.
  const isJoined = group.registered
  // The reader rides here, the ride neither cancelled nor over: leave, and take the route along.
  const isMine = action === 'leave'

  // The group's route, else the ride's. Distance and climb come from the group itself; the route
  // only gives the GPX/FIT links, fetched once for every group by the parent (`routesBySlug`).
  const effectiveRouteSlug = group.routeSlug || rideRouteSlug
  const route = effectiveRouteSlug ? routesBySlug.get(effectiveRouteSlug) : undefined

  // The one filled control of the card, in its corner (R6): « Rejoindre », or « Complet » disabled
  // in its place — to a reader registered in another group too. Never « Quitter » here.
  const corner =
    action === 'join' ? (
      <Button size="xs" onClick={onJoin} disabled={isLoading}>
        {t('rides.detail.groups.join')}
      </Button>
    ) : action === 'full' ? (
      <Button size="xs" variant="default" disabled data-testid="group-full">
        {t('rides.detail.groups.full')}
      </Button>
    ) : null
  // Full width at the foot, never beside the name: there it cut the group's name short (KIT §8).
  // The reader's own group: the red « Quitter le groupe » link, at the foot as in the app.
  const footer =
    !isJoined && canSwitch ? (
      <Button fullWidth onClick={onSwitch} disabled={isLoading}>
        {t('rides.detail.groups.switchTo', { group: title })}
      </Button>
    ) : isMine && onLeave ? (
      <LeaveGroupLink onLeave={onLeave} pending={isLoading} />
    ) : null

  return (
    <ChildCard
      href={paths.rideGroup(teamSlug, rideSlug, group.id)}
      name={title}
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
        <ChildFacts
          averageSpeed={group.averageSpeed}
          distance={group.distance}
          elevationGain={group.distance !== undefined ? group.elevationGain : undefined}
        />
      }
      people={
        <AboveLink>
          <GroupPeopleRow
            participants={group.participants}
            countParticipants={group.countParticipants}
            maxParticipants={group.maxParticipants}
            full={group.full}
            leaderId={group.leader?.id}
            canSeeParticipants={canSeeParticipants}
            onViewAll={() => setShowParticipants(true)}
          />
        </AboveLink>
      }
      weather={<GroupWeatherLine leg={weatherLeg} timezone={rideTimezone} />}
      footer={footer}
      // « GPS » on the reader's own group only (R7): the other groups' routes leave from their
      // pages, and the route's.
      routeActions={
        isMine &&
        effectiveRouteSlug && (
          <GpsMenuButton
            teamSlug={teamSlug}
            routeSlug={effectiveRouteSlug}
            route={route}
            subtitle={
              group.distance !== undefined ? `${title} · ${distance(group.distance)}` : title
            }
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
          source={{ kind: 'ride', teamSlug, rideSlug, groupId: group.id, teamName }}
          count={group.countParticipants}
          groupName={title}
          leaderId={group.leader?.id}
        />
      )}
    </ChildCard>
  )
}
