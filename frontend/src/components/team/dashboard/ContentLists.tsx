import { useTranslation } from 'react-i18next'
import { Anchor, Group, Paper, Stack, Text } from '@mantine/core'
import { IconMountain, IconRoute } from '@tabler/icons-react'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { Rendezvous } from '@/components/common/Rendezvous'
import { CardImage, SurfaceBadge, Stat, TypeBadge } from '@/components/card/common'
import { RouteThumbnail } from '@/components/route/RouteThumbnail'
import type { AdDto, AdType, PostDto, RentalPeriod, RouteDto } from '@/api/dto'
import { paths } from '@/config/paths'
import { useUnits } from '@/hooks/useUnits'

/** « Dernières publications »: title, excerpt, then date · author · comments. */
export function LatestPostsList({ posts }: { posts: PostDto[] }) {
  const { t } = useTranslation()
  return (
    <Stack gap="sm">
      {posts.map((post) => {
        // A post signed as the team reads as the team, whoever wrote it.
        const author = post.signedAsTeam ? post.team.name : post.createdBy?.displayName
        return (
          <Paper key={post.id} withBorder radius="md" p="md">
            <Group gap="md" wrap="nowrap" align="flex-start">
              {post.thumbnailUrl && (
                <div
                  style={{
                    width: 96,
                    flexShrink: 0,
                    borderRadius: 'var(--mantine-radius-md)',
                    overflow: 'hidden',
                  }}
                >
                  <CardImage
                    media={post.media}
                    thumbnailUrl={post.thumbnailUrl}
                    alt={post.name}
                    type="POST"
                    height={72}
                    sizes="96px"
                  />
                </div>
              )}
              <Stack gap={4} style={{ flex: 1, minWidth: 0 }}>
                <Anchor
                  component={PrefetchLink}
                  to={paths.post(post.team.slug, post.slug)}
                  fw={600}
                  c="inherit"
                  lineClamp={2}
                >
                  {post.name}
                </Anchor>
                {post.excerpt && (
                  <Text size="sm" c="dimmed" lineClamp={2}>
                    {post.excerpt}
                  </Text>
                )}
                <Text size="xs" c="dimmed">
                  <Rendezvous date={post.dateTime} zone={post.timezone} format="date" />
                  {author && ` · ${author}`}
                  {post.commentCount !== undefined &&
                    ` · ${t('comments.count', { count: post.commentCount })}`}
                </Text>
              </Stack>
            </Group>
          </Paper>
        )
      })}
    </Stack>
  )
}

/** « Nouveaux parcours »: thumbnail, name, distance, elevation and surface. */
export function NewRoutesList({ routes }: { routes: RouteDto[] }) {
  const { t } = useTranslation()
  const { distance, elevation } = useUnits()
  return (
    <Stack gap="sm">
      {routes.map((route) => (
        <Group key={route.id} gap="sm" wrap="nowrap">
          <RouteThumbnail fallbackUrl={route.thumbnailUrl} size="xs" />
          <Stack gap={2} style={{ flex: 1, minWidth: 0 }}>
            <Anchor
              component={PrefetchLink}
              to={paths.route(route.team.slug, route.slug)}
              fw={600}
              size="sm"
              c="inherit"
              truncate
            >
              {route.name}
            </Anchor>
            <Group gap="sm" wrap="wrap">
              <Stat icon={<IconRoute size={14} />}>{distance(route.distance)}</Stat>
              <Stat icon={<IconMountain size={14} />}>{elevation(route.elevationGain)}</Stat>
              <SurfaceBadge surface={route.surfaceType}>
                {t(
                  `routes.surfaceType.${route.surfaceType satisfies 'ROAD' | 'GRAVEL' | 'MTB' | 'MIXED'}`
                )}
              </SurfaceBadge>
            </Group>
          </Stack>
        </Group>
      ))}
    </Stack>
  )
}

/**
 * « Annonces »: type, price — « Prix à négocier » when the ad has none — and the sector as text.
 * The position stays a sector, never a pin, and an ad carries no contact: the ad page relays.
 */
export function LatestAdsList({ ads }: { ads: AdDto[] }) {
  const { t, i18n } = useTranslation()

  const formatPrice = (price: number | undefined, adType: AdType, rentalPeriod?: RentalPeriod) => {
    if (price === undefined || price === null) return t('ads.detail.priceNegotiable')
    const formatted = new Intl.NumberFormat(i18n.language, {
      style: 'currency',
      currency: 'EUR',
      maximumFractionDigits: Number.isInteger(price) ? 0 : 2,
    }).format(price)
    if (adType === 'RENTAL' && rentalPeriod) {
      const period = t(
        `ads.rentalPeriod.${rentalPeriod satisfies 'DAY' | 'WEEK' | 'MONTH'}`
      ).toLowerCase()
      return t('ads.pricePerPeriod', { price: formatted, period })
    }
    return formatted
  }

  return (
    <Stack gap="sm">
      {ads.map((ad) => (
        <Stack key={ad.id} gap={2}>
          <Group justify="space-between" gap="xs" wrap="nowrap">
            <TypeBadge type={ad.adType}>
              {t(`ads.adType.${ad.adType satisfies 'SALE' | 'RENTAL' | 'WANTED'}`)}
            </TypeBadge>
            <Text size="sm" fw={600}>
              {formatPrice(ad.price, ad.adType, ad.rentalPeriod)}
            </Text>
          </Group>
          <Anchor
            component={PrefetchLink}
            to={paths.ad(ad.team.slug, ad.slug)}
            size="sm"
            fw={500}
            c="inherit"
            truncate
          >
            {ad.name}
          </Anchor>
          {ad.locationDescription && (
            <Text size="xs" c="dimmed">
              {t('teams.dashboard.ads.sector', { place: ad.locationDescription })}
            </Text>
          )}
        </Stack>
      ))}
    </Stack>
  )
}
