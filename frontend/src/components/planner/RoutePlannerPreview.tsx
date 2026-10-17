import { useTranslation } from 'react-i18next'
import { IconArrowUp, IconRoute } from '@tabler/icons-react'
import { Box, Button, Card, Group, Stack, Text } from '@mantine/core'
import { useUnits } from '@/hooks/useUnits'
import { trackSilhouette } from '@/lib/trackSilhouette'

interface RoutePlannerPreviewProps {
  routeGeoJson: GeoJSON.LineString | null
  /** Control points placed by the user. */
  pointCount: number
  /** Distance and ascent in metres. */
  distance: number
  ascend: number
  onOpen: () => void
}

/**
 * What the form shows of the track on a finger, instead of an interactive map: the shape of the
 * track, its distance, ascent and point count. Nothing here is interactive except opening the
 * fullscreen editor, which is where the track is drawn.
 */
export function RoutePlannerPreview({
  routeGeoJson,
  pointCount,
  distance,
  ascend,
  onOpen,
}: RoutePlannerPreviewProps) {
  const { t } = useTranslation()
  const units = useUnits()
  const silhouette = routeGeoJson ? trackSilhouette(routeGeoJson.coordinates) : null

  return (
    <Card withBorder padding="md" radius="md" mx="md">
      <Stack gap="sm">
        {silhouette ? (
          // A touch shortcut only: the button below is the accessible way in.
          <Box onClick={onOpen} style={{ cursor: 'pointer' }}>
            <Stack gap="xs">
              <Box
                bg="var(--mantine-color-default-hover)"
                style={{ borderRadius: 'var(--mantine-radius-sm)' }}
              >
                <svg
                  viewBox={`0 0 ${silhouette.width} ${silhouette.height}`}
                  preserveAspectRatio="xMidYMid meet"
                  width="100%"
                  height={120}
                  role="img"
                  aria-hidden="true"
                  data-testid="planner-silhouette"
                >
                  <polyline
                    points={silhouette.points}
                    fill="none"
                    stroke="var(--mantine-primary-color-filled)"
                    strokeWidth={3}
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    vectorEffect="non-scaling-stroke"
                  />
                </svg>
              </Box>
              <Group gap="md" wrap="wrap">
                <Group gap={4} wrap="nowrap">
                  <IconRoute size={16} />
                  <Text size="sm">{units.distance(distance)}</Text>
                </Group>
                <Group gap={4} wrap="nowrap">
                  <IconArrowUp size={16} />
                  <Text size="sm">{units.elevation(ascend)}</Text>
                </Group>
                <Text size="sm" c="dimmed">
                  {t('planner.pointCount', { count: pointCount })}
                </Text>
              </Group>
            </Stack>
          </Box>
        ) : pointCount > 0 ? (
          // One point: no shape yet, but the point is there.
          <Text size="sm" c="dimmed">
            {t('planner.pointCount', { count: pointCount })}
          </Text>
        ) : (
          <Text size="sm" c="dimmed">
            {t('planner.preview.empty')}
          </Text>
        )}
        <Button onClick={onOpen} fullWidth size="md">
          {pointCount > 0 ? t('planner.edit') : t('planner.draw')}
        </Button>
      </Stack>
    </Card>
  )
}
