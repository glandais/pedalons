import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { IconMap, IconArrowUp, IconMessageCircle, IconRoute } from '@tabler/icons-react'
import { useUnits } from '@/hooks/useUnits'
import { Group, Image, Box } from '@mantine/core'
import type { RouteDto } from '@/api/dto'
import { useResolvedColorScheme } from '@/hooks/useResolvedColorScheme'
import { Card, CardContent, CardTitle, CardDescription, CardImage, CardTeamLink } from './common'
import {
  SurfaceBadge,
  VisibilityBadge,
  DeletedBadge,
  Stat,
  StatGroup,
  CardSkeleton,
} from './common'
import { EntityLogo } from '../common/EntityLogo'
import { paths } from '@/config/paths'
import { TagList } from '../tag/TagList'
import { visibilityIsException } from '@/utils/visibilityException'
import { CARD_GRID_SIZES, sizedUrl, widthSrcSet } from '@/lib/imageSrcSet'

interface RouteCardProps {
  route: RouteDto
  showTeam: boolean
  /** The `⋯` menu (`RouteCardActions`), from a team's own route list. */
  actions?: ReactNode
}

export function RouteCard({ route, showTeam, actions }: RouteCardProps) {
  const { t } = useTranslation()
  const { distance, elevation } = useUnits()
  const colorScheme = useResolvedColorScheme()
  // A compact row carries the themed variants (contract 1.5.1); `thumbnailUrl` stays the
  // fallback for a route that only ever had the collapsed one.
  const themedThumbnail =
    colorScheme === 'dark' ? route.media.assets.thumbnailDark : route.media.assets.thumbnailLight
  const thumbnailUrl = themedThumbnail?.imageUrl ?? route.thumbnailUrl

  return (
    <Card to={paths.route(route.team.slug, route.slug)} actions={actions}>
      {/* Map thumbnails are square: the ratio holds the card's height before the picture loads. */}
      {/* Without a thumbnail yet: the gradient and the route's icon, as in the app (R10). */}
      {thumbnailUrl ? (
        <Image
          src={sizedUrl(thumbnailUrl, 400)}
          srcSet={widthSrcSet(thumbnailUrl, [400, 800, 1200])}
          sizes={CARD_GRID_SIZES}
          alt={route.name}
          loading="lazy"
          style={{ aspectRatio: '1 / 1' }}
        />
      ) : (
        <CardImage media={route.media} alt={route.name} type="RIDE" icon={IconRoute} height={160} />
      )}

      <CardContent>
        {showTeam && <CardTeamLink teamSlug={route.team.slug} teamName={route.team.name} />}

        <Group gap="sm" wrap="nowrap" align="flex-start">
          <EntityLogo logo={route.media.assets.logo} alt={route.name} size="md" />
          <Box style={{ flex: 1, minWidth: 0 }}>
            <CardTitle>{route.name}</CardTitle>
            <CardDescription excerpt={route.excerpt} markdown={true} media={route.media} />
          </Box>
        </Group>

        <StatGroup>
          <Stat icon={<IconMap size={16} />}>{distance(route.distance)}</Stat>
          <Stat icon={<IconArrowUp size={16} />}>{elevation(route.elevationGain)}</Stat>
          {/* No « 0 commentaire » (R4); none at all for an outsider, who may not read them. */}
          {!!route.commentCount && (
            <Stat icon={<IconMessageCircle size={16} />}>
              {t('comments.count', { count: route.commentCount })}
            </Stat>
          )}
        </StatGroup>

        <Group gap="xs">
          {/* First in the row: deletion outranks surface and visibility, which both describe a
              route one still believes exists. */}
          {route.deleted && <DeletedBadge />}
          {route.surfaceType && (
            <SurfaceBadge surface={route.surfaceType}>
              {t(
                `routes.surfaceType.${route.surfaceType satisfies 'ROAD' | 'GRAVEL' | 'MTB' | 'MIXED'}`
              )}
            </SurfaceBadge>
          )}
          {/* Only when it differs from its team's (R1): a private team's route open to all. */}
          {visibilityIsException(route.visibility, route.team) && (
            <VisibilityBadge visibility={route.visibility} />
          )}
        </Group>

        <TagList tags={route.tags} max={3} mt="xs" />
      </CardContent>
    </Card>
  )
}

interface RouteCardSkeletonProps {
  count?: number
}

export function RouteCardSkeleton({ count = 1 }: RouteCardSkeletonProps) {
  return (
    <CardSkeleton count={count} hasImage imageHeight="200px" hasLogo statCount={2} badgeCount={2} />
  )
}
