import { useTranslation } from 'react-i18next'
import { Button, Menu, Tooltip } from '@mantine/core'
import { IconAdjustmentsHorizontal } from '@tabler/icons-react'
import {
  RouteRetouchOperation,
  RouteRetouchUnavailable,
  type RouteRetouchOfferDto,
} from '@/api/dto'
import type { RetouchMode } from './RouteRetouchModal'

interface RouteRetouchButtonProps {
  /** Undefined while loading or after a failure: nothing is shown. */
  offer: RouteRetouchOfferDto | undefined
  onChoose: (mode: RetouchMode) => void
}

/**
 * « Retoucher » on a route's page (ledger `API-212`): a menu of the operations the engine offers.
 * Nothing for a reader the action is not offered to, or when the engine cannot do it; disabled with
 * the reason while the route's analysis is not finished.
 */
export function RouteRetouchButton({ offer, onChoose }: RouteRetouchButtonProps) {
  const { t } = useTranslation()
  if (!offer) return null

  if (!offer.available) {
    if (offer.unavailableReason !== RouteRetouchUnavailable.NOT_READY) return null
    return (
      <Tooltip
        label={t('routeRetouch.notReadyHint')}
        withArrow
        events={{ hover: true, focus: true, touch: true }}
      >
        {/* A disabled button swallows the pointer and cannot take focus: the span carries the tooltip */}
        <span
          tabIndex={0}
          aria-label={`${t('routeRetouch.menu')}. ${t('routeRetouch.notReadyHint')}`}
        >
          <Button variant="default" leftSection={<IconAdjustmentsHorizontal size={16} />} disabled>
            {t('routeRetouch.menu')}
          </Button>
        </span>
      </Tooltip>
    )
  }

  const resize = offer.operations.includes(RouteRetouchOperation.RESIZE)
  const moveEnd = offer.operations.includes(RouteRetouchOperation.MOVE_END)
  if (!resize && !moveEnd) return null

  return (
    <Menu position="bottom-end" withinPortal>
      <Menu.Target>
        <Button variant="default" leftSection={<IconAdjustmentsHorizontal size={16} />}>
          {t('routeRetouch.menu')}
        </Button>
      </Menu.Target>
      <Menu.Dropdown>
        {resize && (
          <Menu.Item onClick={() => onChoose('resize')}>
            {t('routeRetouch.resize.action')}
          </Menu.Item>
        )}
        {moveEnd && (
          <Menu.Item onClick={() => onChoose('moveEnd')}>
            {t('routeRetouch.moveEnd.action')}
          </Menu.Item>
        )}
      </Menu.Dropdown>
    </Menu>
  )
}
