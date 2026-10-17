import { useEffect } from 'react'
import { useTranslation } from 'react-i18next'
import { FullscreenControl, GeolocateControl } from 'react-map-gl/maplibre'
import { IconArrowLeft } from '@tabler/icons-react'
import { ActionIcon, Box, Skeleton } from '@mantine/core'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { MapFullscreenShell } from '@/components/map/MapFullscreenShell'
import { MapSearchControl } from '@/components/map/MapSearchControl'
import { PedalonsMap } from '@/components/map/PedalonsMap'
import { paths } from '@/config/paths'
import { useAppName } from '@/hooks/useAppName'
import { useDefaultMapView } from '@/hooks/useDefaultMapView'
import { useResolvedColorScheme } from '@/hooks/useResolvedColorScheme'

/**
 * A map with no track on it (`/outils-gpx/carte`): basemaps, relief and hillshade from
 * {@link PedalonsMap}, plus browser fullscreen and "where am I". Public — it reads nothing but
 * `/api/config`. Bare layout (no AppShell), so it owns its `document.title`, with the slim toolbar
 * of `RouteFullscreenView` minus the stats and the elevation strip.
 */
export function GpxBlankMapPage() {
  const { t } = useTranslation()
  const appName = useAppName()
  const colorScheme = useResolvedColorScheme()
  const initialViewState = useDefaultMapView()
  const title = t('gpxTools.blankMap.pageTitle')

  useEffect(() => {
    document.title = appName ? `${title} — ${appName}` : title
  }, [title, appName])

  return (
    <MapFullscreenShell
      leading={
        <ActionIcon
          component={PrefetchLink}
          to={paths.gpxTools()}
          variant="subtle"
          size="lg"
          aria-label={t('actions.back')}
        >
          <IconArrowLeft size={20} />
        </ActionIcon>
      }
      title={title}
    >
      <Box className={colorScheme === 'dark' ? 'dark' : undefined} h="100%">
        {!initialViewState ? (
          // /api/config hasn't said where to open yet: no map at an invented position.
          <Skeleton h="100%" w="100%" radius={0} />
        ) : (
          <PedalonsMap initialViewState={initialViewState}>
            <MapSearchControl />
            <FullscreenControl position="top-left" />
            <GeolocateControl
              position="top-left"
              trackUserLocation
              positionOptions={{ enableHighAccuracy: true }}
            />
          </PedalonsMap>
        )}
      </Box>
    </MapFullscreenShell>
  )
}
