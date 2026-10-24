import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import {
  IconCalendar,
  IconUsers,
  IconStack2,
  IconCheck,
  IconMessageCircle,
} from '@tabler/icons-react'
import { Badge, Group, Box, Stack } from '@mantine/core'
import { Card, CardContent, CardTitle, CardDescription, CardImage, CardTeamLink } from './common'
import {
  TypeBadge,
  StatusBadge,
  VisibilityBadge,
  DeletedBadge,
  Stat,
  StatGroup,
  CardSkeleton,
} from './common'
import { EntityLogo } from '../common/EntityLogo'
import { UserAvatarGroup } from '../common/UserAvatar'
import { Rendezvous } from '../common/Rendezvous'
import { paths } from '@/config/paths'
import { PublicationCardProgress } from './PublicationCardProgress'
import { RouteThumbnail } from '../route/RouteThumbnail'
import { TagList } from '../tag/TagList'
import { RideWeatherSummaryLine } from '../weather/RideWeatherSummaryLine'
import { InProgressBadge } from '../agenda/InProgressBadge'
import { PublicationTimeSpan } from '../agenda/PublicationTimeSpan'
import { isUnderWay } from '@/utils/publicationTiming'
import type { PublicationDto, RideDto, TripDto } from '@/api/dto'

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

  // Get the status translation - consolidated in common
  const getStatusLabel = () => {
    return t(`status.${publication.status satisfies 'DRAFT' | 'PUBLISHED' | 'CANCELLED'}`)
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

  // Render stats based on publication type
  const renderStats = () => {
    const calendarIcon = <IconCalendar size={16} />
    const participantsIcon = <IconUsers size={16} />
    const groupsIcon = <IconStack2 size={16} />

    // `commentCount` is absent when the caller may not read the comments — an outsider is
    // told nothing, not even zero. Undefined therefore means "hide", not "none".
    const commentCount = publication.commentCount
    const commentStat =
      commentCount === undefined ? null : (
        <Stat icon={<IconMessageCircle size={16} />}>
          {t('comments.count', { count: commentCount })}
        </Stat>
      )

    switch (publication.type) {
      case 'RIDE': {
        const ride = publication as RideDto
        return (
          <StatGroup>
            <Stat icon={calendarIcon}>
              <PublicationTimeSpan publication={ride} />
            </Stat>
            <Stat icon={participantsIcon}>
              {t('participantCount', { count: ride.participantCount })}
            </Stat>
            <Stat icon={groupsIcon}>{t('groups.groupCount', { count: ride.groupCount })}</Stat>
            {commentStat}
          </StatGroup>
        )
      }
      case 'TRIP': {
        const trip = publication as TripDto
        return (
          <StatGroup>
            <Stat icon={calendarIcon}>
              <PublicationTimeSpan publication={trip} />
            </Stat>
            <Stat icon={participantsIcon}>
              {t('participantCount', { count: trip.participantCount })}
            </Stat>
            <Stat icon={groupsIcon}>{t('trips.card.stageCount', { count: trip.stageCount })}</Stat>
            {commentStat}
          </StatGroup>
        )
      }
      case 'POST':
        return (
          <StatGroup>
            <Stat icon={calendarIcon}>{formattedDate}</Stat>
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

  // Get thumbnail URLs for rides and trips
  const getThumbnailUrls = () => {
    if (publication.type === 'RIDE') {
      const ride = publication as RideDto
      return {
        lightUrl: ride.thumbnailLightUrl,
        darkUrl: ride.thumbnailDarkUrl,
      }
    }
    if (publication.type === 'TRIP') {
      const trip = publication as TripDto
      return {
        lightUrl: trip.thumbnailLightUrl,
        darkUrl: trip.thumbnailDarkUrl,
      }
    }
    return { lightUrl: undefined, darkUrl: undefined }
  }

  const participants = getParticipants()
  const { lightUrl: thumbnailLightUrl, darkUrl: thumbnailDarkUrl } = getThumbnailUrls()

  // `thumbnailUrl` is a photo only for posts. On rides and trips it is the map preview, already
  // rendered below by RouteThumbnail — feeding it to the header would duplicate it.
  const headerImageUrl = publication.type === 'POST' ? publication.thumbnailUrl : undefined

  return (
    <Card to={getPublicationPath()} actions={actions}>
      {/* Featured image with fallback chain */}
      <CardImage
        media={publication.media}
        thumbnailUrl={headerImageUrl}
        alt={publication.name}
        type={publication.type}
        height={160}
        priority={priority}
      />

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
              <CardDescription
                excerpt={publication.excerpt}
                markdown={true}
                media={publication.media}
              />
            </Box>
          </Group>
          <Stack gap={4} align="flex-end" ml="sm">
            {/* First in the stack: deletion outranks type, status and visibility, which all
                describe an entity one still believes exists. */}
            {publication.deleted && <DeletedBadge />}
            {/* Derived on the client, like « J'y vais »: started, not over yet (API-85). */}
            {isUnderWay(publication) && <InProgressBadge />}
            {isRegistered && (
              <Badge
                size="sm"
                color="primary"
                variant="light"
                leftSection={<IconCheck size={12} />}
              >
                {t('publications.registered')}
              </Badge>
            )}
            <TypeBadge type={publication.type}>{getTypeLabel()}</TypeBadge>
            <StatusBadge status={publication.status}>{getStatusLabel()}</StatusBadge>
            <VisibilityBadge visibility={publication.visibility} />
          </Stack>
        </Group>

        {/* The content's team tags, after the badges that say what it is — never mixed with them. */}
        <TagList tags={publication.tags} max={3} mb="md" />

        {/* Participants section - avatars, progress, and route thumbnail */}
        {(participants.length > 0 ||
          publication.type === 'RIDE' ||
          thumbnailLightUrl ||
          thumbnailDarkUrl) && (
          <Group justify="space-between" align="center" mb="md" wrap="nowrap">
            <Group style={{ flex: 1 }}>
              {participants.length > 0 && (
                <UserAvatarGroup
                  users={participants}
                  total={(publication as RideDto | TripDto).participantCount}
                  max={5}
                  size="sm"
                />
              )}
              {publication.type === 'RIDE' && (
                <PublicationCardProgress ride={publication as RideDto} />
              )}
            </Group>
            {(thumbnailLightUrl || thumbnailDarkUrl) && (
              <RouteThumbnail
                thumbnailLightUrl={thumbnailLightUrl}
                thumbnailDarkUrl={thumbnailDarkUrl}
                size="lg"
              />
            )}
          </Group>
        )}

        <Box mt="auto">
          {renderStats()}
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
