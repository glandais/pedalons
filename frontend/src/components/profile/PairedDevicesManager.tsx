import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import {
  ActionIcon,
  Anchor,
  Group,
  Image,
  Paper,
  Skeleton,
  Stack,
  Text,
  Title,
} from '@mantine/core'
import { IconDevices, IconUnlink } from '@tabler/icons-react'
import {
  getListPairedDevicesQueryKey,
  useListPairedDevices,
  useUnpairDevice,
} from '@/api/endpoints/users/users'
import type { PairedDeviceDto, PairedDeviceType } from '@/api/dto'
import { useFormattedDate } from '@/utils/dateFormat'
import { paths } from '@/config/paths'
import { PrefetchLink } from '../common/PrefetchLink'
import { ConfirmDialog } from '../common/ConfirmDialog'

import garminLogo from '@/assets/gps/garmin.svg'
import hammerheadLogo from '@/assets/gps/hammerhead.svg'

// A Karoo is Hammerhead's, an Edge Garmin's: the same tiles as the services above. A client id
// neither app sends has no logo.
const DEVICE_LOGOS: Partial<Record<PairedDeviceType, string>> = {
  KAROO: hammerheadLogo,
  GARMIN: garminLogo,
}

/**
 * The devices paired with the account by code, each with its own unpairing (docs/LEDGER_*.md
 * API-64) — until then, only « Déconnecter tous les appareils » could unpair one.
 */
export function PairedDevicesManager() {
  const { t } = useTranslation()
  const { formatDate, formatRelative } = useFormattedDate()
  const queryClient = useQueryClient()
  const { data: devices = [], isLoading } = useListPairedDevices()
  const [toUnpair, setToUnpair] = useState<PairedDeviceDto | null>(null)

  const unpair = useUnpairDevice({
    mutation: {
      onSuccess: () => {
        setToUnpair(null)
        queryClient.invalidateQueries({ queryKey: getListPairedDevicesQueryKey() })
        notifications.show({ message: t('gps.devices.notifications.unpaired'), color: 'green' })
      },
      onError: () => {
        notifications.show({ message: t('gps.devices.notifications.unpairFailed'), color: 'red' })
      },
    },
  })

  // An external application authorized through OAuth (docs/LEDGER_*.md API-199) is listed here
  // too, under the name it gave itself; a device under its kind.
  const deviceName = (device: PairedDeviceDto) =>
    device.applicationName
      ? t('gps.devices.application', { name: device.applicationName })
      : t(`gps.devices.types.${device.type.toLowerCase() as Lowercase<PairedDeviceType>}`)

  return (
    <Stack>
      <Title order={3} size="h5">
        {t('gps.devices.title')}
      </Title>

      <Text size="sm" c="dimmed">
        {t('gps.devices.description')}
      </Text>

      <Stack gap="xs">
        {isLoading ? (
          <Skeleton height={60} radius="sm" />
        ) : devices.length === 0 ? (
          <Text size="sm" c="dimmed">
            {t('gps.devices.empty')}{' '}
            <Anchor component={PrefetchLink} to={paths.apps()} size="sm">
              {t('gps.devices.howToPair')}
            </Anchor>
          </Text>
        ) : (
          devices.map((device) => {
            const logo = DEVICE_LOGOS[device.type]
            return (
              <Paper key={device.id} withBorder p="sm">
                <Group justify="space-between" wrap="nowrap">
                  <Group wrap="nowrap">
                    {/* Decorative: the device's name is the text right beside it */}
                    {logo ? (
                      <Image src={logo} alt="" w={32} h={32} radius="sm" />
                    ) : (
                      <IconDevices size={32} stroke={1.5} aria-hidden />
                    )}
                    <div>
                      <Text size="sm" fw={500}>
                        {deviceName(device)}
                      </Text>
                      <Text size="xs" c="dimmed">
                        {t('gps.devices.pairedOn', { date: formatDate(device.pairedAt) })}
                        {device.lastUsedAt &&
                          ` · ${t('gps.devices.lastUsed', { when: formatRelative(device.lastUsedAt) })}`}
                      </Text>
                    </div>
                  </Group>
                  <ActionIcon
                    variant="subtle"
                    color="danger"
                    onClick={() => setToUnpair(device)}
                    title={t('gps.devices.unpair')}
                    aria-label={t('gps.devices.unpairLabel', { device: deviceName(device) })}
                  >
                    <IconUnlink size={16} />
                  </ActionIcon>
                </Group>
              </Paper>
            )
          })
        )}
      </Stack>

      <ConfirmDialog
        isOpen={toUnpair !== null}
        onClose={() => setToUnpair(null)}
        onConfirm={() => toUnpair && unpair.mutate({ deviceId: toUnpair.id })}
        title={t('gps.devices.unpairConfirm.title')}
        message={t('gps.devices.unpairConfirm.message', {
          device: toUnpair ? deviceName(toUnpair) : '',
        })}
        confirmText={t('gps.devices.unpairConfirm.confirm')}
        variant="danger"
        isLoading={unpair.isPending}
      />
    </Stack>
  )
}
