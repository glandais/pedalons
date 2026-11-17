import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { Menu, Stack, Text } from '@mantine/core'
import type { GpsServiceConnectionDto, GpsServiceType, RouteGpsSyncStatusDto } from '@/api/dto'
import { GpsRouteSyncState } from '@/api/dto'
import { useFormattedDate } from '@/utils/dateFormat'

interface SendToDeviceItemsProps {
  services: GpsServiceConnectionDto[]
  /** The route's `gpsSyncStatuses`: where it already stands at the caller's services. */
  statuses: RouteGpsSyncStatusDto[] | undefined
  onSend: (serviceType: GpsServiceType) => void
  /** The icon before each service, where the menu has one. */
  icon?: ReactNode
}

/**
 * The entries of a « Envoyer vers l'appareil » menu, one per connected service, each saying where
 * the route already stands there (docs/LEDGER_*.md WEB-163): already sent, an older version, a send
 * in progress, a failure, a connection to renew. A service with no status says nothing — the route
 * is not there, or its automatic sync is off. Sending stays possible in every state.
 */
export function SendToDeviceItems({ services, statuses, onSend, icon }: SendToDeviceItemsProps) {
  const { t } = useTranslation()
  const { formatDateTime } = useFormattedDate()

  const statusLine = (status: RouteGpsSyncStatusDto | undefined): string | null => {
    switch (status?.state) {
      case GpsRouteSyncState.SENT:
        return status.syncedAt
          ? t('gps.routeStatus.sentOn', { date: formatDateTime(status.syncedAt) })
          : t('gps.routeStatus.sent')
      case GpsRouteSyncState.OUTDATED:
        return t('gps.routeStatus.outdated')
      case GpsRouteSyncState.PENDING:
        return t('gps.autoSync.state.pending')
      case GpsRouteSyncState.FAILING:
        return t('gps.routeStatus.failing')
      case GpsRouteSyncState.RECONNECT_REQUIRED:
        return t('gps.routeStatus.reconnectRequired')
      default:
        return null
    }
  }

  return services.map((service) => {
    const status = statuses?.find((s) => s.serviceType === service.serviceType)
    const line = statusLine(status)
    return (
      <Menu.Item
        key={service.serviceType}
        leftSection={icon}
        onClick={() => onSend(service.serviceType)}
      >
        <Stack gap={0}>
          <Text size="sm">
            {t(`gps.services.${service.serviceType.toLowerCase() as Lowercase<GpsServiceType>}`)}
          </Text>
          {line && (
            <Text
              size="xs"
              c={status?.state === GpsRouteSyncState.SENT ? 'teal' : 'dimmed'}
              data-testid={`gps-route-status-${service.serviceType}`}
            >
              {line}
            </Text>
          )}
        </Stack>
      </Menu.Item>
    )
  })
}
