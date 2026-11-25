import { useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Alert, Button, Group, Stack, Text, Title } from '@mantine/core'
import { IconBellOff, IconBellRinging, IconDeviceMobile } from '@tabler/icons-react'
import { useGetConfig } from '@/api/endpoints/configuration/configuration'
import {
  disableWebPush,
  enableWebPush,
  webPushStatus,
  type WebPushStatus,
} from '@/lib/push/webPush'
import { openInstallInstructions } from '@/lib/install/installStore'
import { ProfileCard } from './ProfileShell'

/**
 * « Sur cet appareil », at the head of the notification settings: subscribes the browser to the PUSH channel. Shown only when the
 * server offers web push (`ConfigDto.webPush`), and only after hydration — the status depends on
 * the browser's permission and on localStorage.
 */
export function WebPushSettings() {
  const { t } = useTranslation()
  const { data: config } = useGetConfig()
  const webPush = config?.webPush
  const [status, setStatus] = useState<WebPushStatus | null>(null)
  const [pending, setPending] = useState(false)
  const [failed, setFailed] = useState(false)

  useEffect(() => {
    setStatus(webPushStatus())
  }, [])

  if (!webPush || !status || status === 'unsupported') return null

  const run = async (action: () => Promise<WebPushStatus>) => {
    setPending(true)
    setFailed(false)
    try {
      setStatus(await action())
    } catch (error) {
      console.error('Web push subscription failed', error)
      setFailed(true)
    } finally {
      setPending(false)
    }
  }

  return (
    <ProfileCard>
      <Stack gap="xs">
        <Title order={2} size="h5">
          {t('notifications.webPush.title')}
        </Title>
        {status === 'needsInstall' && (
          <Group justify="space-between" wrap="wrap" gap="xs">
            <Text size="sm" c="dimmed">
              {t('notifications.webPush.needsInstall')}
            </Text>
            <Button
              size="xs"
              variant="light"
              leftSection={<IconDeviceMobile size={14} />}
              onClick={openInstallInstructions}
            >
              {t('install.action')}
            </Button>
          </Group>
        )}
        {status === 'denied' && (
          <Text size="sm" c="dimmed">
            {t('notifications.webPush.denied')}
          </Text>
        )}
        {status === 'disabled' && (
          <Group justify="space-between" wrap="wrap" gap="xs">
            <Text size="sm" c="dimmed">
              {t('notifications.webPush.disabled')}
            </Text>
            <Button
              size="xs"
              leftSection={<IconBellRinging size={14} />}
              loading={pending}
              onClick={() => run(() => enableWebPush(webPush))}
            >
              {t('notifications.webPush.enable')}
            </Button>
          </Group>
        )}
        {status === 'enabled' && (
          <Group justify="space-between" wrap="wrap" gap="xs">
            <Text size="sm" c="dimmed">
              {t('notifications.webPush.enabled')}
            </Text>
            <Button
              size="xs"
              variant="default"
              leftSection={<IconBellOff size={14} />}
              loading={pending}
              onClick={() =>
                run(async () => {
                  await disableWebPush()
                  return webPushStatus()
                })
              }
            >
              {t('notifications.webPush.disable')}
            </Button>
          </Group>
        )}
        {failed && (
          <Alert variant="light" color="danger">
            {t('notifications.webPush.failed')}
          </Alert>
        )}
      </Stack>
    </ProfileCard>
  )
}
