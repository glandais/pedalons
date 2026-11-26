import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Button, Loader, Menu, Text } from '@mantine/core'
import { IconDeviceWatch, IconDownload, IconGps, IconPlugConnected } from '@tabler/icons-react'
import type { GpsServiceType, RouteDetailDto, RouteGpsSyncStatusDto } from '@/api/dto'
import { useGetRoutesBulk } from '@/api/endpoints/routes/routes'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { SendToDeviceItems } from '@/components/route/SendToDeviceItems'
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
  route?: Pick<RouteDetailDto, 'media' | 'gpsSyncStatuses'>
  /**
   * Where the route already stands at the caller's services, said on each service's line
   * (docs/LEDGER_*.md WEB-163): a group's or a ride's `gpsSyncStatuses` — the route its automatic
   * sync sends. Absent, the route's own (given, or read when the menu opens).
   */
  statuses?: RouteGpsSyncStatusDto[]
  /** What leaves, on the menu's first line: « Groupe B · 78,0 km ». */
  subtitle?: string
  size?: 'xs' | 'sm'
}

/**
 * « GPS »: the one way a route leaves a card (docs/LEDGER_*.md WEB-167, R7; KIT §8 « Export du
 * parcours », the app's `GpsButton` and GPS sheet). An outlined button with a navigation icon, opening
 * a menu: « Vers un appareil », one line per connected service — or « Connecter un compteur » to the
 * devices page when none is —, then « Fichier GPX » and « Fichier FIT, pour compteur » when the
 * route has them. It replaces « GPX », « FIT » and « Envoyer vers l'appareil » everywhere a route
 * leaves: cards, a group's page, the route's own page (docs/LEDGER_*.md WEB-165).
 */
export function GpsMenuButton({
  teamSlug,
  routeSlug,
  route,
  subtitle,
  size = 'xs',
  statuses,
}: GpsMenuButtonProps) {
  const { uploadRoute, isUploading } = useGpsConnections()
  const [opened, setOpened] = useState(false)

  const lazy = useGetRoutesBulk(
    teamSlug,
    { slug: [routeSlug], geometry: false },
    { query: { enabled: opened && !route, staleTime: 5 * 60 * 1000 } }
  )
  const read = route ?? lazy.data?.routes?.[0]
  const assets = read?.media?.assets

  return (
    <GpsMenu
      opened={opened}
      onChange={setOpened}
      gpxUrl={assets?.gpx?.url}
      fitUrl={assets?.fit?.url}
      loadingFiles={!route && lazy.isLoading && opened}
      statuses={statuses ?? read?.gpsSyncStatuses}
      onSend={(serviceType) => uploadRoute({ serviceType, teamSlug, routeSlug })}
      isUploading={isUploading}
      subtitle={subtitle}
      size={size}
    />
  )
}

interface GpsMenuProps {
  gpxUrl?: string
  fitUrl?: string
  /** The files are being read: one disabled line in their place. */
  loadingFiles?: boolean
  statuses?: RouteGpsSyncStatusDto[]
  onSend: (serviceType: GpsServiceType) => void
  isUploading: boolean
  subtitle?: string
  size?: 'xs' | 'sm'
  /** Controlled opening, for a caller that reads the files only once the menu opens. */
  opened?: boolean
  onChange?: (opened: boolean) => void
}

/**
 * The « GPS » button and its menu, whatever leaves: a team's route (`GpsMenuButton`) or a GPX
 * tool's preview, which has files and a send of its own (docs/LEDGER_*.md WEB-165).
 */
export function GpsMenu({
  gpxUrl,
  fitUrl,
  loadingFiles = false,
  statuses,
  onSend,
  isUploading,
  subtitle,
  size = 'xs',
  opened,
  onChange,
}: GpsMenuProps) {
  const { t } = useTranslation()
  const { isAuthenticated } = useAuth()
  const { connectedServices } = useGpsConnections()

  return (
    <Menu shadow="md" width={240} opened={opened} onChange={onChange} position="bottom-start">
      <Menu.Target>
        <Button
          variant="default"
          size={size}
          loading={isUploading}
          leftSection={<IconGps size={14} aria-hidden />}
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
          <SendToDeviceItems
            services={connectedServices}
            statuses={statuses}
            onSend={onSend}
            icon={<IconDeviceWatch size={16} aria-hidden />}
          />
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
            {gpxUrl && (
              <Menu.Item
                component="a"
                href={gpxUrl}
                download
                leftSection={<IconDownload size={16} aria-hidden />}
              >
                {t('routes.gps.gpxFile')}
              </Menu.Item>
            )}
            {fitUrl && (
              <Menu.Item
                component="a"
                href={fitUrl}
                download
                leftSection={<IconDownload size={16} aria-hidden />}
              >
                {t('routes.gps.fitFile')}
              </Menu.Item>
            )}
            {!gpxUrl && !fitUrl && <Menu.Item disabled>{t('routes.gps.noFile')}</Menu.Item>}
          </>
        )}
      </Menu.Dropdown>
    </Menu>
  )
}
