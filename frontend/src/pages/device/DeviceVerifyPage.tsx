import { useCallback, useEffect, useState } from 'react'
import { useSearchParams, useLocation } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { notifications } from '@mantine/notifications'
import {
  IconDeviceDesktop,
  IconCheck,
  IconX,
  IconLink,
  IconAlertTriangle,
  IconBan,
  IconRefresh,
} from '@tabler/icons-react'
import {
  Center,
  Stack,
  Text,
  Button,
  Alert,
  ThemeIcon,
  Loader,
  PinInput,
  Group,
} from '@mantine/core'
import {
  TransactionalCard,
  TransactionalCardShell,
} from '../../components/common/TransactionalCard'
import { useAuth } from '../../hooks/useAuth'
import { useGpsConnections } from '../../hooks/useGpsConnections'
import { GpsConnectReturn, GpsServiceType } from '../../api/dto'
import type { CompleteRequest, DenyRequest, VerifyResponse } from '../../api/dto'
import { useFormattedDate } from '../../utils/dateFormat'
import { AXIOS_INSTANCE } from '../../lib/axiosInstance'
import { pathVariants } from '../../config/paths'

const hammerheadStepPaths = new Set(Object.values(pathVariants.deviceHammerhead()))

/**
 * Pairs a Karoo or a Garmin (device code, RFC 8628), then — for a Karoo — goes straight on to
 * linking Hammerhead, which carries the routes to it, and ends on « ready »
 * (docs/LEDGER_*.md API-63, plan docs/plans/2026-10-02-karoo-onboarding.md). The Karoo follows
 * `/api/device/me` meanwhile, so the order of the two steps does not matter to it.
 */
export function DeviceVerifyPage() {
  const { t } = useTranslation()
  const [searchParams, setSearchParams] = useSearchParams()
  const location = useLocation()
  const { user } = useAuth()
  const { isConnected, isServiceAvailable, isLoadingAvailable, initiateConnect } =
    useGpsConnections()

  const gpsError = searchParams.get('gps_error')
  // The Karoo's fallback QR (/karoo/hammerhead), or the return of the Hammerhead OAuth: a Karoo
  // already authorized, at its Hammerhead step.
  const hammerheadStep =
    hammerheadStepPaths.has(location.pathname) ||
    searchParams.has('gps_connected') ||
    gpsError !== null

  const userCode = hammerheadStep ? undefined : searchParams.get('code')?.toUpperCase()

  const [isVerifying, setIsVerifying] = useState(() => Boolean(userCode))
  const [pending, setPending] = useState<VerifyResponse | null>(null)
  const [completed, setCompleted] = useState(false)
  const [connecting, setConnecting] = useState(false)
  const [denied, setDenied] = useState(false)
  const [submitting, setSubmitting] = useState<'confirm' | 'deny' | null>(null)
  const [manualCode, setManualCode] = useState('')
  const { formatRelative } = useFormattedDate()
  const codeValid = pending !== null

  // Verify the user code exists
  useEffect(() => {
    if (!userCode) return

    const verifyCode = async () => {
      // Reset state when code changes (important for manual entry)
      setIsVerifying(true)
      setPending(null)
      try {
        const response = await fetch(
          `/api/device/oauth/verify?code=${encodeURIComponent(userCode)}`
        )
        if (response.ok) {
          const data: VerifyResponse = await response.json()
          setPending(data)
          if (data.authorized) {
            setCompleted(true)
          }
        }
      } catch {
        // Code not valid
      } finally {
        setIsVerifying(false)
      }
    }

    verifyCode()
  }, [userCode])

  // Never on its own: a link carrying a code must not be enough to pair a stranger's device with
  // this account (docs/LEDGER_*.md SEC-2, audit H3). The user reads the code, compares it with the
  // device in front of them, and presses a button.
  const confirmAuthorization = useCallback(async () => {
    if (!userCode) return
    setSubmitting('confirm')
    try {
      const body: CompleteRequest = { userCode, confirmed: true }
      await AXIOS_INSTANCE.post('/api/device/oauth/complete', body)
      setCompleted(true)
    } catch {
      notifications.show({
        message: t('device.errors.authorizationFailed'),
        color: 'red',
      })
    } finally {
      setSubmitting(null)
    }
  }, [userCode, t])

  const denyAuthorization = useCallback(async () => {
    if (!userCode) return
    setSubmitting('deny')
    try {
      const body: DenyRequest = { userCode }
      await AXIOS_INSTANCE.post('/api/device/oauth/deny', body)
      setDenied(true)
    } catch {
      notifications.show({
        message: t('device.errors.denyFailed'),
        color: 'red',
      })
    } finally {
      setSubmitting(null)
    }
  }, [userCode, t])

  const isKaroo = hammerheadStep || pending?.clientId === 'karoo'

  // A Karoo once authorized: Hammerhead, unless the account has it or this server does not offer
  // it (the Karoo would then wait for something nobody can give it).
  if (isKaroo && (completed || hammerheadStep)) {
    if (isLoadingAvailable) {
      return (
        <TransactionalCardShell>
          <Center>
            <Loader size="lg" />
          </Center>
        </TransactionalCardShell>
      )
    }
    if (isConnected(GpsServiceType.HAMMERHEAD) || !isServiceAvailable(GpsServiceType.HAMMERHEAD)) {
      return (
        <TransactionalCard
          data-testid="device-ready"
          icon={
            <ThemeIcon size={64} radius="xl" color="green">
              <IconCheck size={32} />
            </ThemeIcon>
          }
          title={t('device.ready.title')}
          description={t('device.ready.message')}
        />
      )
    }
    return (
      <TransactionalCard
        data-testid="device-hammerhead"
        icon={
          <ThemeIcon size={64} radius="xl">
            <IconRefresh size={32} />
          </ThemeIcon>
        }
        title={t('device.hammerhead.title')}
        description={t('device.hammerhead.message')}
        actions={
          <>
            <Button
              fullWidth
              leftSection={<IconLink size={16} />}
              loading={connecting}
              onClick={() => {
                setConnecting(true)
                void initiateConnect(
                  GpsServiceType.HAMMERHEAD,
                  GpsConnectReturn.DEVICE_KAROO
                ).finally(() => setConnecting(false))
              }}
            >
              {t('device.hammerhead.connect')}
            </Button>
            {/* Under the button it describes. */}
            <Text size="sm" c="dimmed" ta="center">
              {t('device.hammerhead.hint')}
            </Text>
          </>
        }
      >
        <Group gap="xs" justify="center">
          <IconCheck size={16} color="var(--mantine-color-green-6)" />
          <Text size="sm">{t('device.hammerhead.authorized')}</Text>
        </Group>
        {gpsError && (
          <Alert color="red" variant="light" w="100%">
            <Text size="sm">
              {t(
                gpsError === 'access_denied'
                  ? 'device.hammerhead.denied'
                  : 'device.hammerhead.failed'
              )}
            </Text>
          </Alert>
        )}
      </TransactionalCard>
    )
  }

  // Show loading while verifying code
  if (isVerifying) {
    return (
      <TransactionalCardShell>
        <Stack align="center" gap="md">
          <Loader size="lg" />
          <Text c="dimmed">{t('device.verifying')}</Text>
        </Stack>
      </TransactionalCardShell>
    )
  }

  // No code provided - show manual entry form
  if (!userCode) {
    return (
      <TransactionalCard
        icon={
          <ThemeIcon size={64} radius="xl">
            <IconDeviceDesktop size={32} />
          </ThemeIcon>
        }
        title={t('device.manualEntry.title')}
        description={t('device.manualEntry.description')}
      >
        <PinInput
          length={6}
          type="alphanumeric"
          value={manualCode}
          onChange={(value) => {
            const upperValue = value.toUpperCase()
            setManualCode(upperValue)
            if (upperValue.length === 6) {
              setSearchParams({ code: upperValue })
            }
          }}
          size="xl"
          style={{ justifyContent: 'center' }}
        />
      </TransactionalCard>
    )
  }

  // Invalid code (code provided but not valid)
  if (!codeValid) {
    return (
      <TransactionalCard
        icon={
          <ThemeIcon size={64} radius="xl" color="red">
            <IconX size={32} />
          </ThemeIcon>
        }
        title={t('device.errors.title')}
        back={{
          label: t('device.manualEntry.tryAgain'),
          onClick: () => {
            setManualCode('')
            setPending(null)
            setSearchParams({})
          },
        }}
      >
        <Alert color="red" title={t('device.errors.invalidCode')}>
          {t('device.errors.invalidCodeMessage')}
        </Alert>
      </TransactionalCard>
    )
  }

  // Authorization completed (a Garmin, or another device: a Karoo is handled above)
  if (completed) {
    return (
      <TransactionalCard
        icon={
          <ThemeIcon size={64} radius="xl" color="green">
            <IconCheck size={32} />
          </ThemeIcon>
        }
        title={t('device.success.title')}
        description={t('device.success.message')}
      >
        <Alert color="blue" variant="light">
          <Text size="sm">{t('device.success.returnToDevice')}</Text>
        </Alert>
      </TransactionalCard>
    )
  }

  // Refused: the code is dead, the device will start over
  if (denied) {
    return (
      <TransactionalCard
        icon={
          <ThemeIcon size={64} radius="xl" color="gray">
            <IconBan size={32} />
          </ThemeIcon>
        }
        title={t('device.denied.title')}
        description={t('device.denied.message')}
      />
    )
  }

  // Explicit confirmation (RFC 8628 §5.4)
  const deviceName = t(
    pending?.clientId === 'karoo'
      ? 'device.client.karoo'
      : pending?.clientId === 'garmin'
        ? 'device.client.garmin'
        : 'device.client.other'
  )
  return (
    <TransactionalCard
      icon={
        <ThemeIcon size={64} radius="xl">
          <IconDeviceDesktop size={32} />
        </ThemeIcon>
      }
      title={t('device.confirm.title')}
      actions={
        <>
          <Button
            fullWidth
            leftSection={<IconCheck size={16} />}
            loading={submitting === 'confirm'}
            disabled={submitting !== null}
            onClick={confirmAuthorization}
          >
            {t('device.confirm.authorize')}
          </Button>
          <Button
            fullWidth
            variant="default"
            leftSection={<IconX size={16} />}
            loading={submitting === 'deny'}
            disabled={submitting !== null}
            onClick={denyAuthorization}
          >
            {t('device.confirm.deny')}
          </Button>
        </>
      }
    >
      {/* Normal text, not the dimmed description: it is the sentence to read before
          authorising (docs/LEDGER_*.md SEC-2). */}
      <Text ta="center">
        {t('device.confirm.question', {
          device: deviceName,
          name: user?.displayName ?? '',
        })}
      </Text>
      <Text ta="center" fz={32} fw={700} ff="monospace" style={{ letterSpacing: '0.2em' }}>
        {userCode}
      </Text>
      {pending?.requestedAt && (
        <Text size="sm" c="dimmed" ta="center">
          {t('device.confirm.requestedAt', { when: formatRelative(pending.requestedAt) })}
        </Text>
      )}
      <Alert color="orange" variant="light" icon={<IconAlertTriangle size={16} />}>
        <Text size="sm">{t('device.confirm.warning')}</Text>
      </Alert>
    </TransactionalCard>
  )
}
