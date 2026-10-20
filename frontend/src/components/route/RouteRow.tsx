import { PrefetchLink } from '@/components/common/PrefetchLink'
import { useTranslation } from 'react-i18next'
import { Box, Group, Paper, Stack, Text } from '@mantine/core'
import { IconArrowUp, IconChevronRight, IconMap } from '@tabler/icons-react'
import type { RouteDto } from '@/api/dto'
import { DeletedBadge, SurfaceBadge, VisibilityBadge } from '../card/common'
import { RouteThumbnail } from './RouteThumbnail'
import { paths } from '@/config/paths'
import { useUnits } from '@/hooks/useUnits'
import { TagList } from '../tag/TagList'

interface RouteRowProps {
  route: RouteDto
  /** 80px on a list, 56px on the dead-end preview. */
  compact?: boolean
}

/**
 * The dense route line: a square thumbnail, one line of title, distance and elevation
 * side by side, the surface and visibility badges, a chevron.
 *
 * About 100px tall against ~330px for the thumbnail card, so a 2 500-route library is
 * navigable a screenful at a time instead of twelve tall cards at a time.
 */
export function RouteRow({ route, compact = false }: RouteRowProps) {
  const { t } = useTranslation()
  const { distance, elevation } = useUnits()

  return (
    <Paper
      component={PrefetchLink}
      to={paths.route(route.team.slug, route.slug)}
      withBorder
      radius="md"
      p={compact ? 8 : 10}
      style={{ display: 'block', textDecoration: 'none', color: 'inherit' }}
    >
      <Group gap="sm" wrap="nowrap" align="center">
        <RouteThumbnail
          thumbnailLightUrl={route.media.assets.thumbnailLight?.imageUrl}
          thumbnailDarkUrl={route.media.assets.thumbnailDark?.imageUrl}
          fallbackUrl={route.thumbnailUrl}
          size={compact ? 'xs' : 'sm'}
        />

        <Stack gap={compact ? 2 : 4} style={{ flex: 1, minWidth: 0 }}>
          <Text fw={700} lh={1.35} truncate>
            {route.name}
          </Text>

          {/* Distance then elevation, side by side, never wrapping — whitespace is the separator */}
          <Group gap="sm" wrap="nowrap">
            <Group gap={5} wrap="nowrap">
              {!compact && <IconMap size={16} color="var(--mantine-color-dimmed)" />}
              <Text size="sm" fw={600}>
                {distance(route.distance)}
              </Text>
            </Group>
            <Group gap={5} wrap="nowrap" c="var(--mantine-color-green-7)">
              {!compact && <IconArrowUp size={16} />}
              <Text size="sm" fw={600}>
                {elevation(route.elevationGain)}
              </Text>
            </Group>
          </Group>

          {!compact && (
            <Group gap={4}>
              {/* First, as on the card: deletion outranks what describes a route still believed to exist */}
              {route.deleted && <DeletedBadge />}
              {route.surfaceType && (
                <SurfaceBadge surface={route.surfaceType}>
                  {t(
                    `routes.surfaceType.${route.surfaceType satisfies 'ROAD' | 'GRAVEL' | 'MTB' | 'MIXED'}`
                  )}
                </SurfaceBadge>
              )}
              <VisibilityBadge visibility={route.visibility} />
            </Group>
          )}

          {/* The dense line keeps to two tags: it is read a screenful of routes at a time. */}
          {!compact && <TagList tags={route.tags} max={2} size="xs" />}
        </Stack>

        {compact && route.deleted && <DeletedBadge />}
        {compact
          ? route.surfaceType && (
              <SurfaceBadge surface={route.surfaceType}>
                {t(
                  `routes.surfaceType.${route.surfaceType satisfies 'ROAD' | 'GRAVEL' | 'MTB' | 'MIXED'}`
                )}
              </SurfaceBadge>
            )
          : null}

        {!compact && (
          <Box style={{ flexShrink: 0, lineHeight: 0 }} c="var(--mantine-color-dimmed)">
            <IconChevronRight size={20} />
          </Box>
        )}
      </Group>
    </Paper>
  )
}
