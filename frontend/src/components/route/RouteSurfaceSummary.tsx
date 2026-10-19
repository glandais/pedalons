import { useMemo } from 'react'
import { useTranslation } from 'react-i18next'
import {
  Anchor,
  Box,
  Group,
  Progress,
  SegmentedControl,
  Stack,
  Text,
  Tooltip,
  useMantineTheme,
} from '@mantine/core'
import type { TrackDto, TrackSurface } from '@/api/dto'
import { useResolvedColorScheme } from '@/hooks/useResolvedColorScheme'
import type { PlannerColorBy } from '@/lib/plannerSurface'
import { hasSurfaces, surfaceShares, surfacesPending, trackSurfaceColors } from '@/lib/trackSurface'

const CLASS_LABEL_KEYS = {
  PAVED: 'routes.surface.class.PAVED',
  PAVED_ROUGH: 'routes.surface.class.PAVED_ROUGH',
  GRAVEL: 'routes.surface.class.GRAVEL',
  DIRT: 'routes.surface.class.DIRT',
  PATH: 'routes.surface.class.PATH',
  UNKNOWN: 'routes.surface.class.UNKNOWN',
  OFF_NETWORK: 'routes.surface.class.OFF_NETWORK',
} as const satisfies Record<TrackSurface, string>

interface RouteSurfaceSummaryProps {
  tracks: TrackDto[]
  colorBy: PlannerColorBy
  onColorByChange: (value: PlannerColorBy) => void
}

/**
 * What a saved route is made of (WEB-100 C1b), under its map: the switch of what the profile and
 * the line are coloured by, the breakdown by surface class and the OpenStreetMap credit the data
 * requires. While the surface is being computed it says so; without it (a route saved before the
 * feature, a track the provider could not match, the feature off) it shows nothing.
 */
export function RouteSurfaceSummary({
  tracks,
  colorBy,
  onColorByChange,
}: RouteSurfaceSummaryProps) {
  const { t } = useTranslation()
  const theme = useMantineTheme()
  const colorScheme = useResolvedColorScheme()
  const colors = useMemo(() => trackSurfaceColors(theme, colorScheme), [theme, colorScheme])
  const shares = useMemo(() => surfaceShares(tracks), [tracks])

  if (!hasSurfaces(tracks)) {
    return surfacesPending(tracks) ? (
      <Text size="xs" c="dimmed" data-testid="route-surface-pending">
        {t('routes.surface.pending')}
      </Text>
    ) : null
  }

  // Rounded to the unit; a class too small to round to 1 % is told as « < 1 % », not as 0
  const percent = (share: number) =>
    share < 0.005
      ? t('routes.surface.shareBelowOne')
      : t('routes.surface.share', { share: Math.round(share * 100) })

  return (
    <Stack gap="xs" data-testid="route-surface-summary">
      <SegmentedControl
        size="xs"
        w="fit-content"
        value={colorBy}
        onChange={(value) => onColorByChange(value as PlannerColorBy)}
        aria-label={t('routes.surface.colorBy.label')}
        data={[
          { value: 'grade', label: t('routes.surface.colorBy.grade') },
          { value: 'surface', label: t('routes.surface.colorBy.surface') },
        ]}
      />
      {/* The bar says by colour what the legend below says in words: hidden from assistive tech */}
      <Progress.Root size="lg" aria-hidden data-testid="route-surface-bar">
        {shares.map(({ surface, share }) => (
          <Tooltip
            key={surface}
            label={`${t(CLASS_LABEL_KEYS[surface])} ${percent(share)}`}
            position="top"
          >
            <Progress.Section value={share * 100} color={colors[surface]} />
          </Tooltip>
        ))}
      </Progress.Root>
      <Group gap="md" wrap="wrap" style={{ rowGap: 2 }} data-testid="route-surface-legend">
        {shares.map(({ surface, share }) => (
          <Group key={surface} gap={4} wrap="nowrap">
            {/* A stroke of the line's colour, as in the editor's legend */}
            <Box
              w={14}
              h={0}
              style={{ borderTop: `4px solid ${colors[surface]}`, flexShrink: 0 }}
            />
            <Text size="xs">
              {t(CLASS_LABEL_KEYS[surface])} {percent(share)}
            </Text>
          </Group>
        ))}
      </Group>
      <Text size="xs" c="dimmed" data-testid="route-surface-attribution">
        <Anchor
          href="https://www.openstreetmap.org/copyright"
          target="_blank"
          rel="noopener noreferrer"
          inherit
        >
          {t('routes.surface.attribution')}
        </Anchor>
      </Text>
    </Stack>
  )
}
