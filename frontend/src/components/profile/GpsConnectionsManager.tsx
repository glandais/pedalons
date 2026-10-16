import { useEffect, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { notifications } from '@mantine/notifications'
import { useTranslation } from 'react-i18next'
import {
  Stack,
  Title,
  Text,
  Button,
  Group,
  Paper,
  ActionIcon,
  Badge,
  Skeleton,
  Image,
  Switch,
} from '@mantine/core'
import { IconLink, IconUnlink } from '@tabler/icons-react'
import { useGpsConnections } from '@/hooks/useGpsConnections'
import { ConfirmDialog } from '../common/ConfirmDialog'
import type { GpsServiceConnectionDto, GpsServiceType } from '@/api/dto'
import { useFormattedDate } from '@/utils/dateFormat'
import { isGpsAutoSyncEnabled } from '@/config/appConfig'

import garminLogo from '@/assets/gps/garmin.svg'
import hammerheadLogo from '@/assets/gps/hammerhead.svg'
import wahooLogo from '@/assets/gps/wahoo.svg'

// The logo of each service, shipped with the client: `GpsServiceType` is a closed enum, so the
// contract carries no logo URL (docs/LEDGER_*.md API-14). Each is a square tile with its own dark
// background, readable in both colour schemes; the mobile app ships the same tiles as PNGs.
const GPS_SERVICE_LOGOS: Record<GpsServiceType, string> = {
  HAMMERHEAD: hammerheadLogo,
  GARMIN: garminLogo,
  WAHOO: wahooLogo,
}

function serviceKey(type: GpsServiceType) {
  return `gps.services.${type.toLowerCase() as Lowercase<GpsServiceType>}` as const
}

interface AutoSyncControlProps {
  connection: GpsServiceConnectionDto
  /** The value being saved for this service, while it is. */
  pending: boolean | undefined
  onChange: (enabled: boolean) => void
  onReconnect: () => void
}

/**
 * The opt-in to the automatic sending of the routes of the member's rides to one connected service,
 * and where it stands (docs/LEDGER_*.md API-120, WEB-92). The state line reads `autoSyncState` only:
 * the server folds the routes sent, waiting and failing into it, per service.
 */
function AutoSyncControl({ connection, pending, onChange, onReconnect }: AutoSyncControlProps) {
  const { t } = useTranslation()
  const service = t(serviceKey(connection.serviceType))
  const checked = pending ?? connection.autoSync

  return (
    <Stack gap={6} mt="sm">
      <Switch
        size="sm"
        checked={checked}
        disabled={pending !== undefined}
        onChange={(event) => onChange(event.currentTarget.checked)}
        label={t('gps.autoSync.label')}
        description={t('gps.autoSync.description')}
        aria-label={t('gps.autoSync.ariaLabel', { service })}
      />
      {connection.autoSync && pending === undefined && (
        <AutoSyncStatus connection={connection} service={service} onReconnect={onReconnect} />
      )}
    </Stack>
  )
}

function AutoSyncStatus({
  connection,
  service,
  onReconnect,
}: {
  connection: GpsServiceConnectionDto
  service: string
  onReconnect: () => void
}) {
  const { t } = useTranslation()
  const { formatDateTime } = useFormattedDate()
  const lastSent = connection.lastAutoSyncAt
    ? t('gps.autoSync.lastSent', { date: formatDateTime(connection.lastAutoSyncAt) })
    : undefined
  switch (connection.autoSyncState) {
    case 'UP_TO_DATE':
      return (
        <Text size="xs" c="dimmed" data-testid="gps-auto-sync-status">
          {[
            connection.autoSyncRouteCount > 0
              ? t('gps.autoSync.state.upToDate', { count: connection.autoSyncRouteCount })
              : t('gps.autoSync.state.upToDateNone'),
            lastSent,
          ]
            .filter(Boolean)
            .join(' · ')}
        </Text>
      )
    case 'PENDING':
      return (
        <Text size="xs" c="dimmed" data-testid="gps-auto-sync-status">
          {t('gps.autoSync.state.pending')}
        </Text>
      )
    case 'FAILING':
      return (
        <Text size="xs" c="danger" data-testid="gps-auto-sync-status">
          {t('gps.autoSync.state.failing', { service })}
        </Text>
      )
    case 'RECONNECT_REQUIRED':
      return (
        <Group gap="xs" justify="space-between" wrap="nowrap">
          <Text size="xs" c="danger" data-testid="gps-auto-sync-status">
            {t('gps.autoSync.state.reconnectRequired', { service })}
          </Text>
          <Button size="compact-xs" variant="light" onClick={onReconnect}>
            {t('gps.autoSync.reconnect')}
          </Button>
        </Group>
      )
    default:
      // OFF while `autoSync` is true does not happen: say nothing rather than guess.
      return null
  }
}

export function GpsConnectionsManager() {
  const { t } = useTranslation()
  const { formatDate } = useFormattedDate()
  const {
    availableServices,
    isLoadingAvailable,
    isConnected,
    getConnection,
    initiateConnect,
    disconnect,
    isDisconnecting,
    setAutoSync,
    autoSyncPending,
  } = useGpsConnections()

  const [disconnectServiceType, setDisconnectServiceType] = useState<GpsServiceType | null>(null)
  // Off on this deployment: no switch at all, rather than one that promises a sending.
  const autoSyncAvailable = isGpsAutoSyncEnabled()

  // The OAuth callback lands here with its outcome in the query (docs/LEDGER_*.md API-63): say it
  // once, then drop it so a reload does not say it again.
  const [searchParams, setSearchParams] = useSearchParams()
  useEffect(() => {
    const connected = searchParams.get('gps_connected')
    const error = searchParams.get('gps_error')
    if (connected === null && error === null) return
    const service = connected ? t(`gps.services.${connected}`, { defaultValue: connected }) : ''
    notifications.show(
      connected
        ? { message: t('gps.notifications.connected', { service }), color: 'green' }
        : {
            message: t(
              error === 'access_denied'
                ? 'gps.notifications.returnDenied'
                : 'gps.notifications.returnFailed'
            ),
            color: 'danger',
          }
    )
    const next = new URLSearchParams(searchParams)
    next.delete('gps_connected')
    next.delete('gps_error')
    setSearchParams(next, { replace: true })
  }, [searchParams, setSearchParams, t])

  const handleConnect = (serviceType: GpsServiceType) => {
    initiateConnect(serviceType)
  }

  const handleDisconnect = () => {
    if (disconnectServiceType) {
      disconnect(disconnectServiceType, {
        onSuccess: () => setDisconnectServiceType(null),
      })
    }
  }

  const disconnectService = disconnectServiceType ? t(serviceKey(disconnectServiceType)) : ''
  // The routes the automatic sync sent go with the connection: say so before it is cut.
  const sentRoutes = disconnectServiceType
    ? (getConnection(disconnectServiceType)?.autoSyncRouteCount ?? 0)
    : 0
  const disconnectMessage = [
    t('gps.disconnectConfirm.message', { service: disconnectService }),
    sentRoutes > 0 &&
      t('gps.disconnectConfirm.autoSyncRoutes', { count: sentRoutes, service: disconnectService }),
  ]
    .filter(Boolean)
    .join(' ')

  return (
    <Stack>
      <Group justify="space-between">
        <Title order={3} size="h5">
          {t('gps.title')}
        </Title>
      </Group>

      <Text size="sm" c="dimmed">
        {t('gps.description')}
      </Text>

      <Stack gap="xs">
        {isLoadingAvailable ? (
          <>
            <Skeleton height={60} radius="sm" />
            <Skeleton height={60} radius="sm" />
          </>
        ) : availableServices.length === 0 ? (
          <Text size="sm" c="dimmed" ta="center" py="md">
            {t('gps.noServicesConfigured')}
          </Text>
        ) : (
          availableServices.map((type) => {
            const connected = isConnected(type)
            const connection = getConnection(type)

            return (
              <Paper key={type} withBorder p="sm">
                <Group justify="space-between">
                  <Group>
                    {/* Decorative: the service's name is the text right beside it */}
                    <Image src={GPS_SERVICE_LOGOS[type]} alt="" w={32} h={32} radius="sm" />
                    <div>
                      <Text size="sm" fw={500}>
                        {t(serviceKey(type))}
                      </Text>
                      {connected && connection && (
                        <Text size="xs" c="dimmed">
                          {t('gps.connectedSince', {
                            date: formatDate(connection.connectedAt),
                          })}
                        </Text>
                      )}
                    </div>
                  </Group>
                  <Group gap="xs">
                    {connected ? (
                      <>
                        <Badge color="green" variant="light">
                          {t('gps.connected')}
                        </Badge>
                        <ActionIcon
                          variant="subtle"
                          color="danger"
                          onClick={() => setDisconnectServiceType(type)}
                          title={t('gps.disconnect')}
                          aria-label={t('gps.disconnect')}
                        >
                          <IconUnlink size={16} />
                        </ActionIcon>
                      </>
                    ) : (
                      <Button
                        size="xs"
                        leftSection={<IconLink size={14} />}
                        onClick={() => handleConnect(type)}
                      >
                        {t('gps.connect')}
                      </Button>
                    )}
                  </Group>
                </Group>
                {autoSyncAvailable && connected && connection && (
                  <AutoSyncControl
                    connection={connection}
                    pending={
                      autoSyncPending?.serviceType === type ? autoSyncPending.enabled : undefined
                    }
                    onChange={(enabled) => setAutoSync(type, enabled)}
                    onReconnect={() => handleConnect(type)}
                  />
                )}
              </Paper>
            )
          })
        )}
      </Stack>

      <ConfirmDialog
        isOpen={disconnectServiceType !== null}
        onClose={() => setDisconnectServiceType(null)}
        onConfirm={handleDisconnect}
        title={t('gps.disconnectConfirm.title')}
        message={disconnectMessage}
        confirmText={t('gps.disconnectConfirm.confirm')}
        variant="danger"
        isLoading={isDisconnecting}
      />
    </Stack>
  )
}
