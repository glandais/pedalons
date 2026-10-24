import { useTranslation } from 'react-i18next'
import {
  IconMap,
  IconArrowUp,
  IconArrowDown,
  IconDownload,
  IconDeviceMobile,
} from '@tabler/icons-react'
import { Box, Button, Group, Stack, Text, Title, Badge, Menu, Loader } from '@mantine/core'
import {
  ElevationState,
  type RouteDetailDto,
  type GpsServiceType,
  type WeatherAttributionDto,
  type WeatherLegDto,
} from '@/api/dto'
import { RouteMapView } from './RouteMapView'
import { ColorModeControls } from './ColorModeControls'
import type { ColorByOption } from './ColorByControl'
import { RouteWaypointList } from './RouteWaypointList'
import { useWaypointSelection } from '@/hooks/useWaypointSelection'
import { useWindColorMode } from '@/hooks/useWindColorMode'
import { useUnits } from '@/hooks/useUnits'
import { useGpsConnections } from '@/hooks/useGpsConnections'
import { useAuth } from '@/hooks/useAuth'
import { FormattedDate } from '@/components/common/FormattedDate'
import { BADGE_VARIANTS, CLIMB_CATEGORY_COLORS } from '@/lib/badgeColors.generated'
import { TagList } from '@/components/tag'

interface RouteDetailViewProps {
  route: RouteDetailDto
  /** Team slug for GPS upload functionality */
  teamSlug?: string
  /** Show download buttons (default: true) */
  showDownload?: boolean
  /** Show route info section with visibility and surface type (default: true) */
  showInfo?: boolean
  /**
   * When set, the map shows a fullscreen action linking to this path (built via paths.xxx) — or to
   * the path this builds for the mode the line is in (a stage's map, ledger WEB-118).
   */
  fullscreenPath?: string | ((colorBy: ColorByOption) => string)
  /**
   * A leg with a forecast offers the Météo mode (a trip stage's, WEB-118): the line by the wind, a
   * badge per forecast point, the legend and the credit. The page decides (`stageWindLeg`).
   */
  windLeg?: WeatherLegDto
  /** The forecast's credit, owed while the wind colours the line. */
  windAttribution?: WeatherAttributionDto
  /** The stage's zone: the passages of the forecast's points read in it. */
  timezone?: string
}

/**
 * Detailed route view component showing map, stats, info, and climbs.
 * Used in RouteDetailPage and StageDetailPage, where a stage's forecast adds the Météo mode.
 */
export function RouteDetailView({
  route,
  teamSlug,
  showDownload = true,
  showInfo = true,
  fullscreenPath,
  windLeg,
  windAttribution,
  timezone,
}: RouteDetailViewProps) {
  const { t } = useTranslation()
  const { distance, elevation, formatDistance, config } = useUnits()
  const { isAuthenticated } = useAuth()
  const mode = useWindColorMode({
    tracks: route.tracks,
    leg: windLeg,
    attribution: windAttribution,
    timezone,
  })
  const { connectedServices, uploadRoute, isUploading } = useGpsConnections()
  const { selection, setSelection, mapBoxRef, selectFromList } = useWaypointSelection()

  const handleSendToDevice = (serviceType: GpsServiceType) => {
    if (teamSlug && route.slug) {
      uploadRoute({ serviceType, teamSlug, routeSlug: route.slug })
    }
  }

  return (
    <Stack>
      {/* Interactive Map with Elevation Chart */}
      <Box ref={mapBoxRef}>
        <RouteMapView
          route={route}
          fullscreenPath={
            typeof fullscreenPath === 'function' ? fullscreenPath(mode.colorBy) : fullscreenPath
          }
          colorBy={mode.plannerColorBy}
          {...mode.mapProps}
          waypointSelection={selection}
          onWaypointSelectionChange={setSelection}
        />
      </Box>

      {route.elevationState === ElevationState.PENDING && (
        <Text size="xs" c="dimmed">
          {t('routes.detail.elevationRefining')}
        </Text>
      )}

      {/* « Pente | Revêtement », plus « Météo » with a forecast (WEB-118) */}
      <ColorModeControls
        mode={mode}
        tracks={route.tracks}
        attribution={windAttribution}
        subject="stage"
      />

      {/* Download Buttons - inline without wrapper */}
      {showDownload && (route.media.assets.gpx || route.media.assets.fit) && (
        <Group gap="sm" wrap="wrap">
          {route.media.assets.gpx && (
            <Button
              variant="default"
              size="sm"
              component="a"
              href={route.media.assets.gpx.url}
              leftSection={<IconDownload size={16} />}
            >
              {t('routes.detail.download.gpx')}
            </Button>
          )}
          {route.media.assets.fit && (
            <Button
              variant="default"
              size="sm"
              component="a"
              href={route.media.assets.fit.url}
              leftSection={<IconDownload size={16} />}
            >
              {t('routes.detail.download.fit')}
            </Button>
          )}
          {/* Send to Device - only show if authenticated with connected services */}
          {isAuthenticated && teamSlug && connectedServices.length > 0 && (
            <Menu shadow="md" width={200}>
              <Menu.Target>
                <Button
                  variant="default"
                  size="sm"
                  leftSection={isUploading ? <Loader size={16} /> : <IconDeviceMobile size={16} />}
                  disabled={isUploading}
                >
                  {t('routes.detail.sendToDevice')}
                </Button>
              </Menu.Target>
              <Menu.Dropdown>
                {connectedServices.map((service) => (
                  <Menu.Item
                    key={service.serviceType}
                    onClick={() => handleSendToDevice(service.serviceType)}
                  >
                    {t(
                      `gps.services.${service.serviceType.toLowerCase() as Lowercase<GpsServiceType>}`
                    )}
                  </Menu.Item>
                ))}
              </Menu.Dropdown>
            </Menu>
          )}
        </Group>
      )}

      {/* Stats - compact inline display */}
      <Group gap="xl" wrap="wrap">
        <Group gap="xs">
          <IconMap size={24} color="var(--mantine-primary-color-filled)" />
          <Box>
            <Text size="xs" c="dimmed">
              {t('routes.detail.stats.distance')}
            </Text>
            <Text size="lg" fw={700}>
              {distance(route.distance)}
            </Text>
          </Box>
        </Group>

        <Group gap="xs">
          <IconArrowUp size={24} color="var(--mantine-color-green-text)" />
          <Box>
            <Text size="xs" c="dimmed">
              {t('routes.detail.stats.elevationGain')}
            </Text>
            <Text size="lg" fw={700}>
              {elevation(route.elevationGain)}
            </Text>
          </Box>
        </Group>

        <Group gap="xs">
          <IconArrowDown size={24} color="var(--mantine-color-red-text)" />
          <Box>
            <Text size="xs" c="dimmed">
              {t('routes.detail.stats.elevationLoss')}
            </Text>
            <Text size="lg" fw={700}>
              {elevation(route.elevationLoss)}
            </Text>
          </Box>
        </Group>
      </Group>

      {/* Route Info - compact inline badges */}
      {showInfo && (
        <Group gap="sm" wrap="wrap">
          {route.surfaceType && (
            <Badge color="green" variant="light" size="lg">
              {t(
                `routes.surfaceType.${route.surfaceType satisfies 'ROAD' | 'GRAVEL' | 'MTB' | 'MIXED'}`
              )}
            </Badge>
          )}
          <Badge color="gray" variant="light" size="lg">
            {t(
              `visibility.${route.visibility.toLowerCase() as 'public' | 'public_unlisted' | 'team'}`
            )}
          </Badge>
          <Text size="sm" c="dimmed">
            {t('routes.detail.info.createdAt')}: <FormattedDate date={route.createdAt} />
          </Text>
        </Group>
      )}

      {/* The route's team tags. Not on a stage (`showInfo` off): tags stay on the route (plan D15). */}
      {showInfo && <TagList tags={route.tags} />}

      <RouteWaypointList
        waypoints={route.waypoints}
        selected={selection?.waypoint ?? null}
        onSelect={selectFromList}
      />

      {/* Climbs Section - compact list */}
      {(() => {
        const allClimbs = route.tracks?.flatMap((track) => track.climbs) || []
        return (
          allClimbs.length > 0 && (
            <Box>
              <Title order={4} mb="sm">
                {t('routes.detail.climbs.title')} ({allClimbs.length})
              </Title>
              <Stack gap="xs">
                {allClimbs.map((climb, index) => (
                  <Box
                    key={index}
                    py="xs"
                    style={{ borderBottom: '1px solid var(--mantine-color-default-border)' }}
                  >
                    <Group justify="space-between" wrap="wrap" gap="xs">
                      <Group gap="xs">
                        {climb.category && (
                          <Badge
                            color={CLIMB_CATEGORY_COLORS[climb.category]}
                            variant={BADGE_VARIANTS.ClimbCategory}
                            size="sm"
                          >
                            {t(
                              `routes.climbCategory.${climb.category satisfies 'HC' | 'CAT1' | 'CAT2' | 'CAT3' | 'CAT4'}`
                            )}
                          </Badge>
                        )}
                        <Text size="sm" fw={500}>
                          {/* docs/LEDGER_*.md API-10: the waypoint at the top, else « Montée N ». */}
                          {climb.name ?? t('routes.detail.climbs.unnamed', { number: index + 1 })}
                        </Text>
                        <Text size="sm" c="dimmed">
                          {t('routes.detail.climbs.distance', {
                            start: formatDistance(climb.startDistance),
                            end: formatDistance(climb.endDistance),
                            unit: config.distanceUnit,
                          })}
                        </Text>
                      </Group>
                      <Group>
                        <Text size="sm">
                          <Text span c="dimmed">
                            {t('routes.detail.climbs.gain')}:
                          </Text>{' '}
                          <Text span fw={500}>
                            {elevation(climb.elevationGain)}
                          </Text>
                        </Text>
                        <Text size="sm">
                          <Text span c="dimmed">
                            {t('routes.detail.climbs.avgGradient')}:
                          </Text>{' '}
                          <Text span fw={500}>
                            {climb.averageGradient.toFixed(1)}%
                          </Text>
                        </Text>
                        <Text size="sm">
                          <Text span c="dimmed">
                            {t('routes.detail.climbs.maxGradient')}:
                          </Text>{' '}
                          <Text span fw={500}>
                            {climb.maxGradient.toFixed(1)}%
                          </Text>
                        </Text>
                      </Group>
                    </Group>
                  </Box>
                ))}
              </Stack>
            </Box>
          )
        )
      })()}
    </Stack>
  )
}
