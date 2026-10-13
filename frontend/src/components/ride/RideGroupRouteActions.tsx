import { useTranslation } from 'react-i18next'
import { IconMap, IconDownload, IconDeviceMobile } from '@tabler/icons-react'
import { Group, Text, UnstyledButton, Anchor, Menu, Loader } from '@mantine/core'
import type { GpsServiceType, RouteDetailDto } from '@/api/dto'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { paths } from '@/config/paths'
import { useAuth } from '@/hooks/useAuth'
import { useGpsConnections } from '@/hooks/useGpsConnections'

interface RideGroupRouteActionsProps {
  teamSlug: string
  /** The group's route, else the ride's: the one the group rides. */
  routeSlug: string
  /**
   * That route, from the ride's single `/routes/bulk` read (`useRideDetailData.routesBySlug`) —
   * only its GPX/FIT assets are read here. Undefined while it loads: the links wait for it.
   */
  route: RouteDetailDto | undefined
  size?: 'xs' | 'sm'
}

/**
 * What a rider does with a group's route: open it, download its GPX or FIT, send it to a connected
 * device. The same row on the group's card (ride page) and on the group's own page.
 */
export function RideGroupRouteActions({
  teamSlug,
  routeSlug,
  route,
  size = 'xs',
}: RideGroupRouteActionsProps) {
  const { t } = useTranslation()
  const { isAuthenticated } = useAuth()
  const { connectedServices, uploadRoute, isUploading } = useGpsConnections()

  const handleSendToDevice = (serviceType: GpsServiceType) => {
    uploadRoute({ serviceType, teamSlug, routeSlug })
  }

  return (
    <Group gap="xs">
      <Anchor component={PrefetchLink} to={paths.route(teamSlug, routeSlug)} size={size} c="dimmed">
        <Group gap={4}>
          <IconMap size={16} />
          {t('rides.detail.groups.route.view')}
        </Group>
      </Anchor>
      {route?.media?.assets?.gpx?.url && (
        <Anchor href={route.media.assets.gpx.url} size={size} c="dimmed" download>
          <Group gap={4}>
            <IconDownload size={16} />
            {t('rides.detail.groups.route.downloadGpx')}
          </Group>
        </Anchor>
      )}
      {route?.media?.assets?.fit?.url && (
        <Anchor href={route.media.assets.fit.url} size={size} c="dimmed" download>
          <Group gap={4}>
            <IconDownload size={16} />
            {t('rides.detail.groups.route.downloadFit')}
          </Group>
        </Anchor>
      )}
      {isAuthenticated && connectedServices.length > 0 && (
        <Menu shadow="md" width={200}>
          <Menu.Target>
            <UnstyledButton disabled={isUploading} aria-label={t('routes.detail.sendToDevice')}>
              <Group gap={4}>
                {isUploading ? <Loader size={16} /> : <IconDeviceMobile size={16} />}
                <Text size={size} c="dimmed">
                  {t('routes.detail.sendToDevice')}
                </Text>
              </Group>
            </UnstyledButton>
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
  )
}
