import { useTranslation } from 'react-i18next'
import { IconMap } from '@tabler/icons-react'
import { Group, Anchor } from '@mantine/core'
import type { RouteDetailDto } from '@/api/dto'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { GpsMenuButton } from '@/components/route/GpsMenuButton'
import { paths } from '@/config/paths'

interface RideGroupRouteActionsProps {
  teamSlug: string
  /** The group's route, else the ride's: the one the group rides. */
  routeSlug: string
  /**
   * That route — from the ride's single `/routes/bulk` read (`useRideDetailData.routesBySlug`), or
   * the `RouteDto` a trip's stage embeds — only its GPX/FIT assets are read here. Undefined while
   * it loads: the « GPS » menu then reads it itself when opened. Its `gpsSyncStatuses` say, in the device menu, where it
   * already stands at the caller's services (docs/LEDGER_*.md WEB-163).
   */
  route: Pick<RouteDetailDto, 'media' | 'gpsSyncStatuses'> | undefined
  size?: 'xs' | 'sm'
  /** False on the ride page's group cards: the card itself opens the group, map and route included. */
  withViewLink?: boolean
}

/**
 * What a rider does with a group's route: open it, and take it away through the « GPS » menu (GPX,
 * FIT, a connected device). On a group's page under the map, and on a child page's route card.
 */
export function RideGroupRouteActions({
  teamSlug,
  routeSlug,
  route,
  size = 'xs',
  withViewLink = true,
}: RideGroupRouteActionsProps) {
  const { t } = useTranslation()

  return (
    <Group gap="sm" wrap="wrap" align="center">
      {withViewLink && (
        <Anchor
          component={PrefetchLink}
          to={paths.route(teamSlug, routeSlug)}
          size={size}
          c="dimmed"
        >
          <Group gap={4} wrap="nowrap">
            <IconMap size={16} />
            {t('rides.detail.groups.route.view')}
          </Group>
        </Anchor>
      )}
      {/* One « GPS » button for files and devices, as on the cards (KIT §8, docs/LEDGER_*.md
          WEB-165). Until the route is read, the menu reads it when it opens. */}
      <GpsMenuButton
        teamSlug={teamSlug}
        routeSlug={routeSlug}
        route={route}
        statuses={route?.gpsSyncStatuses}
        size={size}
      />
    </Group>
  )
}
