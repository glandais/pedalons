import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Button, Loader, Menu, Text } from '@mantine/core'
import {
  IconDeviceMobile,
  IconDeviceWatch,
  IconDownload,
  IconPlugConnected,
} from '@tabler/icons-react'
import type { GpsServiceType, RouteDetailDto } from '@/api/dto'
import { useGetRoutesBulk } from '@/api/endpoints/routes/routes'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { paths } from '@/config/paths'
import { useAuth } from '@/hooks/useAuth'
import { useGpsConnections } from '@/hooks/useGpsConnections'

interface GpsMenuButtonProps {
  teamSlug: string
  routeSlug: string
  /**
   * The route, when the card already has it (a ride's `/routes/bulk` read, the `RouteDto` a stage
   * embeds): its GPX and FIT links are read from it. Absent — « Ma prochaine sortie », « Vos
   * prochaines sorties », whose rows carry only the slug —, the menu reads them when it opens, from
   * the same `/routes/bulk` without geometry: one small request, and only for who asks.
   */
  route?: Pick<RouteDetailDto, 'media'>
  /** What leaves, on the menu's first line: « Groupe B · 78,0 km ». */
  subtitle?: string
  size?: 'xs' | 'sm'
}

/**
 * « GPS »: the one way a route leaves a card (docs/LEDGER_*.md WEB-167, R7; KIT §8 « Export du
 * parcours », the app's `GpsButton` and GPS sheet). An outlined button with a device icon, opening
 * a menu: « Vers un appareil », one line per connected service — or « Connecter un compteur » to the
 * devices page when none is —, then « Fichier GPX » and « Fichier FIT, pour compteur » when the
 * route has them. It replaces the cards' « GPX », « FIT » and « Envoyer vers l'appareil »; the
 * route's own page keeps its downloads.
 */
export function GpsMenuButton({
  teamSlug,
  routeSlug,
  route,
  subtitle,
  size = 'xs',
}: GpsMenuButtonProps) {
  const { t } = useTranslation()
  const { isAuthenticated } = useAuth()
  const { connectedServices, uploadRoute, isUploading } = useGpsConnections()
  const [opened, setOpened] = useState(false)

  const lazy = useGetRoutesBulk(
    teamSlug,
    { slug: [routeSlug], geometry: false },
    { query: { enabled: opened && !route, staleTime: 5 * 60 * 1000 } }
  )
  const assets = (route ?? lazy.data?.routes?.[0])?.media?.assets
  const loadingFiles = !route && lazy.isLoading && opened

  return (
    <Menu shadow="md" width={240} opened={opened} onChange={setOpened} position="bottom-start">
      <Menu.Target>
        <Button
          variant="default"
          size={size}
          loading={isUploading}
          leftSection={<IconDeviceMobile size={14} aria-hidden />}
          aria-label={t('routes.gps.buttonLabel')}
          data-testid="gps-button"
        >
          {t('routes.gps.button')}
        </Button>
      </Menu.Target>
      <Menu.Dropdown data-testid="gps-menu">
        {subtitle && (
          <Text size="xs" c="dimmed" px="sm" pt={6} pb={2}>
            {subtitle}
          </Text>
        )}
        <Menu.Label>{t('routes.gps.toDevice')}</Menu.Label>
        {isAuthenticated && connectedServices.length > 0 ? (
          connectedServices.map((service) => (
            <Menu.Item
              key={service.serviceType}
              leftSection={<IconDeviceWatch size={16} aria-hidden />}
              onClick={() => uploadRoute({ serviceType: service.serviceType, teamSlug, routeSlug })}
            >
              {t(`gps.services.${service.serviceType.toLowerCase() as Lowercase<GpsServiceType>}`)}
            </Menu.Item>
          ))
        ) : (
          <Menu.Item
            component={PrefetchLink}
            to={paths.profileDevices()}
            leftSection={<IconPlugConnected size={16} aria-hidden />}
          >
            {t('routes.gps.connectDevice')}
          </Menu.Item>
        )}
        <Menu.Divider />
        {loadingFiles ? (
          <Menu.Item disabled leftSection={<Loader size={14} />}>
            {t('routes.gps.loadingFiles')}
          </Menu.Item>
        ) : (
          <>
            {assets?.gpx?.url && (
              <Menu.Item
                component="a"
                href={assets.gpx.url}
                download
                leftSection={<IconDownload size={16} aria-hidden />}
              >
                {t('routes.gps.gpxFile')}
              </Menu.Item>
            )}
            {assets?.fit?.url && (
              <Menu.Item
                component="a"
                href={assets.fit.url}
                download
                leftSection={<IconDownload size={16} aria-hidden />}
              >
                {t('routes.gps.fitFile')}
              </Menu.Item>
            )}
            {!assets?.gpx?.url && !assets?.fit?.url && (
              <Menu.Item disabled>{t('routes.gps.noFile')}</Menu.Item>
            )}
          </>
        )}
      </Menu.Dropdown>
    </Menu>
  )
}
