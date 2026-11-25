import { Fragment } from 'react'
import { useTranslation } from 'react-i18next'
import { Menu, Text } from '@mantine/core'
import {
  RouteRetouchOperation,
  RouteRetouchUnavailable,
  type RouteRetouchOfferDto,
} from '@/api/dto'
import type { RetouchMode } from './RouteRetouchModal'

/**
 * « Retoucher » inside an editor's « Modifier ▾ » menu on a route's page (ledger `API-212`): a
 * section with the operations the engine offers. Nothing when the engine cannot do it; one disabled
 * line, with the reason, while the route's analysis is not finished. A reader who cannot edit gets
 * the separate `RouteRetouchButton` instead.
 */
export function RouteRetouchMenuItems({
  offer,
  onChoose,
}: {
  /** Undefined while loading or after a failure: nothing is shown. */
  offer: RouteRetouchOfferDto | undefined
  onChoose: (mode: RetouchMode) => void
}) {
  const { t } = useTranslation()
  if (!offer) return null

  if (!offer.available) {
    if (offer.unavailableReason !== RouteRetouchUnavailable.NOT_READY) return null
    return (
      <Menu.Item disabled data-testid="route-retouch-not-ready">
        <Text size="sm">{t('routeRetouch.menu')}</Text>
        <Text size="xs" c="dimmed">
          {t('routeRetouch.notReadyHint')}
        </Text>
      </Menu.Item>
    )
  }

  const resize = offer.operations.includes(RouteRetouchOperation.RESIZE)
  const moveEnd = offer.operations.includes(RouteRetouchOperation.MOVE_END)
  if (!resize && !moveEnd) return null

  return (
    <Fragment>
      <Menu.Label>{t('routeRetouch.menu')}</Menu.Label>
      {resize && (
        <Menu.Item onClick={() => onChoose('resize')}>{t('routeRetouch.resize.action')}</Menu.Item>
      )}
      {moveEnd && (
        <Menu.Item onClick={() => onChoose('moveEnd')}>
          {t('routeRetouch.moveEnd.action')}
        </Menu.Item>
      )}
    </Fragment>
  )
}
