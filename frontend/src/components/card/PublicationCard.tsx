import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import {
  IconCalendar,
  IconUsers,
  IconStack2,
  IconMessageCircle,
  IconMap,
  IconArrowUp,
} from '@tabler/icons-react'
import { Group, Box, Stack } from '@mantine/core'
import { Card, CardContent, CardTitle, CardDescription, CardImage, CardTeamLink } from './common'
import {
  TypeBadge,
  VisibilityBadge,
  DeletedBadge,
  StateBadge,
  RegisteredBadge,
  Stat,
  StatGroup,
  CardSkeleton,
  CardDayOverlay,
  cardBanner,
} from './common'
import { EntityLogo } from '../common/EntityLogo'
import { UserAvatarGroup } from '../common/UserAvatar'
import { Rendezvous } from '../common/Rendezvous'
import { PublicationDepartureLine } from '../common/DepartureLine'
import { GroupPlaceLine } from '../common/GroupPlaceLine'
import { paths } from '@/config/paths'
import { PublicationCardProgress } from './PublicationCardProgress'
import { RouteThumbnail } from '../route/RouteThumbnail'
import { TagList } from '../tag/TagList'
import { RideWeatherSummaryLine } from '../weather/RideWeatherSummaryLine'
import { isDated, spanStart } from '@/utils/publicationTiming'
import { cardState } from '@/utils/cardState'
import { visibilityIsException } from '@/utils/visibilityException'
import { useUnits } from '@/hooks/useUnits'
import { useResolvedColorScheme } from '@/hooks/useResolvedColorScheme'
import type { PublicationDto, RideDto, TripDto } from '@/api/dto'
import { Status } from '@/api/dto'

interface PublicationCardProps {
  publication: PublicationDto
  showTeam: boolean
  /**
   * The `⋯` menu (`PublicationCardActions`), given by a list that knows the reader's role in the
   * team — a team's own feed. Left out, the card has no actions.
   */
  actions?: ReactNode
  /** The first card of a page whose list starts on the first screen: see `CardImage.priority`. */
  priority?: boolean
}

export function PublicationCard({
  publication,
  showTeam,
  actions,
  priority = false,
}: PublicationCardProps) {
  const { t } = useTranslation()
  const { distance, elevation } = useUnits()
  const colorScheme = useResolvedColorScheme()
  // Read the server-computed flag — never recompute registration client-side.
  const isRegistered =
    publication.type === 'RIDE' || publication.type === 'TRIP'
      ? ((publication as RideDto | TripDto).registered ?? false)
      : false

  // Get the appropriate path based on publication type
  const getPublicationPath = () => {
    switch (publication.type) {
      case 'RIDE':
        return paths.ride(publication.team.slug, publication.slug)
      case 'POST':
        return paths.post(publication.team.slug, publication.slug)
      case 'TRIP':
        return paths.trip(publication.team.slug, publication.slug)
    }
  }

  // Get the type translation
  const getTypeLabel = () => {
    switch (publication.type) {
      case 'RIDE':
        return t('publicationType.ride')
      case 'POST':
        return t('publicationType.post')
      case 'TRIP':
        return t('publicationType.trip')
    }
  }

  const formattedDate = <Rendezvous date={publication.dateTime} zone={publication.timezone} />

  // Render stats based on publication type. A ride's or a trip's date is not one of them: it is the
  // day box on the picture and the departure line under the title (docs/BRANDING.md §7.1, ledger
  // `BRAND-8`) — it does not come back down here. A counter at zero is not shown: « 0 groupe »,
  // « 0 commentaire », « 0 étape » tell nothing (docs/LEDGER_*.md WEB-167, R4).
  const renderStats = () => {
    const participantsIcon = <IconUsers size={16} />
    const groupsIcon = <IconStack2 size={16} />

    // `commentCount` is absent when the caller may not read the comments — an outsider is
    // told nothing, not even zero. Undefined therefore means "hide", and so does zero.
    const commentCount = publication.commentCount ?? 0
    const commentStat =
      commentCount > 0 ? (
        <Stat icon={<IconMessageCircle size={16} />}>
          {t('comments.count', { count: commentCount })}
        </Stat>
      ) : null

    switch (publication.type) {
      case 'RIDE': {
        const ride = publication as RideDto
        // A ride without groups takes no registration: no count; nobody yet, no count either, as
        // the app's. « 8/12 personnes » when the ride has a limit, the group card's form (R5).
        const people =
          ride.groupCount > 0 && ride.participantCount > 0
            ? ride.maxParticipants
              ? t('rides.detail.groups.participants', {
                  current: ride.participantCount,
                  count: ride.maxParticipants,
                })
              : t('participantCount', { count: ride.participantCount })
            : null
        // The distance and climb the server picks for this reader — their group's route, else the
        // route every group shares, else nothing (docs/LEDGER_*.md API-178, R3). First, as the app's.
        const hasFigures =
          ride.displayDistance !== undefined || ride.displayElevationGain !== undefined
        if (!people && ride.groupCount === 0 && !commentStat && !hasFigures) return null
        return (
          <StatGroup>
            {ride.displayDistance !== undefined && (
              <Stat icon={<IconMap size={16} />}>{distance(ride.displayDistance)}</Stat>
            )}
            {ride.displayElevationGain !== undefined && (
              <Stat icon={<IconArrowUp size={16} />}>{elevation(ride.displayElevationGain)}</Stat>
            )}
            {people && <Stat icon={participantsIcon}>{people}</Stat>}
            {ride.groupCount > 0 && (
              <Stat icon={groupsIcon}>{t('groups.groupCount', { count: ride.groupCount })}</Stat>
            )}
            {commentStat}
          </StatGroup>
        )
      }
      case 'TRIP': {
        // The app's order: stages · distance · D+ · people, the comments when there are some. The
        // people's count is said to anyone who may read the trip — a count, never a name (API-144).
        const trip = publication as TripDto
        const hasAny =
          trip.stageCount > 0 ||
          trip.totalDistance !== undefined ||
          trip.totalElevationGain !== undefined ||
          trip.participantCount > 0 ||
          !!commentStat
        if (!hasAny) return null
        return (
          <StatGroup>
            {trip.stageCount > 0 && (
              <Stat icon={groupsIcon}>
                {t('trips.card.stageCount', { count: trip.stageCount })}
              </Stat>
            )}
            {trip.totalDistance !== undefined && (
              <Stat icon={<IconMap size={16} />}>{distance(trip.totalDistance)}</Stat>
            )}
            {trip.totalElevationGain !== undefined && (
              <Stat icon={<IconArrowUp size={16} />}>{elevation(trip.totalElevationGain)}</Stat>
            )}
            {trip.participantCount > 0 && (
              <Stat icon={participantsIcon}>
                {t('participantCount', { count: trip.participantCount })}
              </Stat>
            )}
            {commentStat}
          </StatGroup>
        )
      }
      case 'POST':
        return (
          <StatGroup>
            <Stat icon={<IconCalendar size={16} />}>{formattedDate}</Stat>
            {commentStat}
          </StatGroup>
        )
    }
  }

  // Get participants for avatar display
  const getParticipants = () => {
    if (publication.type === 'TRIP') {
      return (publication as TripDto).participants || []
    }
    if (publication.type === 'RIDE') {
      return (publication as RideDto).topParticipants || []
    }
    return []
  }

  const participants = getParticipants()

  // The header (R10): a post's photo; a ride's or a trip's photo, else its route's map, else the
  // gradient. `thumbnailUrl` is a photo only for a post — on a ride or a trip it is the map.
  const banner = isDated(publication) ? cardBanner(publication, colorScheme) : undefined
  const headerImageUrl =
    publication.type === 'POST'
      ? publication.thumbnailUrl
      : banner && banner.kind !== 'gradient'
        ? banner.url
        : undefined
  // The route's 160 px thumbnail, only beside a photo: under a map banner it repeated it.
  const thumbnail =
    banner?.kind === 'photo' && isDated(publication)
      ? { light: publication.thumbnailLightUrl, dark: publication.thumbnailDarkUrl }
      : undefined
  const hasThumbnail = !!thumbnail && !!(thumbnail.light || thumbnail.dark)

  // One state, after the type (R1): cancelled, draft, under way, over — never « Publié ».
  const state = cardState({
    status: publication.status,
    start: isDated(publication) ? publication.dateTime : undefined,
    end: isDated(publication) ? publication.endDateTime : undefined,
  })
  const stats = renderStats()

  return (
    <Card to={getPublicationPath()} actions={actions}>
      {/* Featured image with fallback chain; a ride's or a trip's day posed on it (§7.1). */}
      <Box pos="relative">
        <CardImage
          media={publication.media}
          thumbnailUrl={headerImageUrl}
          alt={publication.name}
          type={publication.type}
          height={160}
          priority={priority}
          kind={banner?.kind === 'map' ? 'map' : 'photo'}
        />
        {isDated(publication) && (
          <CardDayOverlay
            date={spanStart(publication)}
            zone={publication.timezone}
            tone={publication.type === 'TRIP' ? 'teal' : 'primary'}
            showRelative={!publication.finished && publication.status !== Status.CANCELLED}
            clearActions={!!actions}
          />
        )}
      </Box>

      <CardContent>
        {showTeam && (
          <CardTeamLink teamSlug={publication.team.slug} teamName={publication.team.name} />
        )}

        {/* Main content - title with logo, description, badges */}
        <Group align="flex-start" justify="space-between" mb="md" wrap="nowrap">
          <Group gap="sm" wrap="nowrap" style={{ flex: 1, minWidth: 0 }}>
            <EntityLogo logo={publication.media.assets.logo} alt={publication.name} size="sm" />
            <Box style={{ flex: 1, minWidth: 0 }}>
              <CardTitle>{publication.name}</CardTitle>
              {isDated(publication) && (
                <Box mt={4} mb={6}>
                  <PublicationDepartureLine publication={publication} />
                  {/* A ride the reader joined: « Groupe B · Place de la Mairie » under the
                      departure, which is their group's (docs/LEDGER_*.md WEB-167, R11). */}
                  {publication.type === 'RIDE' && (publication as RideDto).registeredGroup && (
                    <Box mt={4}>
                      <GroupPlaceLine
                        group={(publication as RideDto).registeredGroup?.name}
                        place={(publication as RideDto).startPlace?.name}
                      />
                    </Box>
                  )}
                </Box>
              )}
              <CardDescription
                excerpt={publication.excerpt}
                markdown={true}
                media={publication.media}
              />
            </Box>
          </Group>
          {/* Supprimé → type → one state → J'y vais, then the visibility only when it differs
              from the team's (R1): the column no longer eats half the card (N30). */}
          <Stack
            gap={4}
            align="flex-end"
            ml="sm"
            style={{ flexShrink: 0 }}
            data-testid="card-badges"
          >
            {publication.deleted && <DeletedBadge />}
            <TypeBadge type={publication.type}>{getTypeLabel()}</TypeBadge>
            <StateBadge state={state} subject={publication.type === 'TRIP' ? 'trip' : 'ride'} />
            {isRegistered && <RegisteredBadge />}
            {visibilityIsException(publication.visibility, publication.team) && (
              <VisibilityBadge visibility={publication.visibility} />
            )}
          </Stack>
        </Group>

        {/* The content's team tags, after the badges that say what it is — never mixed with them. */}
        <TagList tags={publication.tags} max={3} mb="md" />

        {/* Participants section - avatars, progress, and the route's thumbnail beside a photo */}
        {(participants.length > 0 || publication.type === 'RIDE' || hasThumbnail) && (
          <Group justify="space-between" align="center" mb="md" wrap="nowrap">
            <Group style={{ flex: 1 }}>
              {participants.length > 0 && (
                <UserAvatarGroup
                  users={participants}
                  total={(publication as RideDto | TripDto).participantCount}
                  max={5}
                />
              )}
              {publication.type === 'RIDE' && (
                <PublicationCardProgress ride={publication as RideDto} />
              )}
            </Group>
            {hasThumbnail && (
              <RouteThumbnail
                thumbnailLightUrl={thumbnail?.light}
                thumbnailDarkUrl={thumbnail?.dark}
                size="lg"
              />
            )}
          </Group>
        )}

        <Box mt="auto">
          {stats}
          {/* The server sends it only within the forecast window, or with its opening date; a
              trip's is that of its next stage (docs/LEDGER_*.md API-82). */}
          {(publication.type === 'RIDE' || publication.type === 'TRIP') && (
            <RideWeatherSummaryLine
              summary={(publication as RideDto | TripDto).weather}
              timezone={publication.timezone}
            />
          )}
        </Box>
      </CardContent>
    </Card>
  )
}

export function PublicationCardSkeleton() {
  return (
    <CardSkeleton
      count={1}
      hasImage={true}
      imageHeight="160px"
      hasLogo={true}
      statCount={3}
      badgeCount={3}
    />
  )
}
