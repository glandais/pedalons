import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  Stack,
  Title,
  Text,
  Button,
  Group,
  Paper,
  ActionIcon,
  Loader,
  Alert,
  TextInput,
  Modal,
} from '@mantine/core'
import { IconKey, IconTrash, IconPlus, IconAlertCircle, IconDevices } from '@tabler/icons-react'
import {
  useListPasskeys,
  useDeletePasskey,
  getListPasskeysQueryKey,
} from '@/api/endpoints/passkeys/passkeys'
import { useQueryClient } from '@tanstack/react-query'
import {
  registerNewPasskey,
  isPasskeySupported,
  isPlatformAuthenticatorAvailable,
} from '@/lib/passkeys'
import { useAuthStore } from '@/store/authStore'
import { ConfirmDialog } from '../common/ConfirmDialog'
import { useEffect } from 'react'
import { useFormattedDate } from '@/utils/dateFormat'

export function PasskeyManager() {
  const { t } = useTranslation()
  const { formatDate } = useFormattedDate()
  const queryClient = useQueryClient()
  const setHasPasskeys = useAuthStore((state) => state.setHasPasskeys)

  // Resolved after mount, never during render: `isPasskeySupported()` reads `window`, so seeding
  // state with it makes the server take the "not supported" branch and the client the other one —
  // a hydration mismatch on /profile. Same shape as LoginPage's `passkeySupported`, except `null`
  // means "not resolved yet" and renders nothing: defaulting to `false` would flash "your browser
  // doesn't support passkeys" at every visitor whose browser does.
  const [isSupported, setIsSupported] = useState<boolean | null>(null)
  const [hasPlatformAuth, setHasPlatformAuth] = useState(false)
  const [isRegistering, setIsRegistering] = useState(false)
  const [registerError, setRegisterError] = useState<string | null>(null)
  const [showRegisterModal, setShowRegisterModal] = useState(false)
  const [deviceName, setDeviceName] = useState('')
  const [deletePasskeyId, setDeletePasskeyId] = useState<string | null>(null)

  const { data: passkeys, isLoading } = useListPasskeys()
  const deletePasskeyMutation = useDeletePasskey()

  useEffect(() => {
    setIsSupported(isPasskeySupported())
    isPlatformAuthenticatorAvailable().then(setHasPlatformAuth)
  }, [])

  const handleRegister = async () => {
    setIsRegistering(true)
    setRegisterError(null)

    try {
      await registerNewPasskey(deviceName || undefined)
      queryClient.invalidateQueries({ queryKey: getListPasskeysQueryKey() })
      setHasPasskeys(true)
      setShowRegisterModal(false)
      setDeviceName('')
    } catch (error) {
      console.error('Passkey registration failed:', error)
      if (error instanceof Error) {
        if (error.name === 'NotAllowedError') {
          setRegisterError(t('passkeys.errors.cancelled'))
        } else {
          setRegisterError(error.message)
        }
      } else {
        setRegisterError(t('passkeys.errors.registrationFailed'))
      }
    } finally {
      setIsRegistering(false)
    }
  }

  const handleDelete = (id: string) => {
    deletePasskeyMutation.mutate(
      { id },
      {
        onSuccess: () => {
          queryClient.invalidateQueries({ queryKey: getListPasskeysQueryKey() })
          const remainingPasskeys = (passkeys?.length ?? 0) - 1
          if (remainingPasskeys === 0) {
            setHasPasskeys(false)
          }
          setDeletePasskeyId(null)
        },
      }
    )
  }

  if (isSupported === null) return null

  if (!isSupported) {
    return (
      <Stack>
        <Title order={2} size="h5">
          {t('passkeys.title')}
        </Title>
        <Alert icon={<IconAlertCircle size={16} />} color="yellow">
          {t('passkeys.notSupported')}
        </Alert>
      </Stack>
    )
  }

  return (
    <Stack>
      <Group justify="space-between">
        <Title order={2} size="h5">
          {t('passkeys.title')}
        </Title>
        <Button
          leftSection={<IconPlus size={16} />}
          size="xs"
          onClick={() => setShowRegisterModal(true)}
        >
          {t('passkeys.add')}
        </Button>
      </Group>

      <Text size="sm" c="dimmed">
        {t('passkeys.description')}
      </Text>

      {!hasPlatformAuth && (
        <Alert icon={<IconAlertCircle size={16} />} color="yellow" variant="light">
          {t('passkeys.noPlatformAuthenticator')}
        </Alert>
      )}

      {isLoading ? (
        <Loader size="sm" />
      ) : passkeys && passkeys.length > 0 ? (
        <Stack gap="xs">
          {passkeys.map((passkey) => (
            <Paper key={passkey.id} withBorder p="sm">
              <Group justify="space-between">
                <Group>
                  <IconKey size={20} />
                  <div>
                    <Text size="sm" fw={500}>
                      {passkey.deviceName || t('passkeys.unnamedDevice')}
                    </Text>
                    <Text size="xs" c="dimmed">
                      {t('passkeys.lastUsed', {
                        date: passkey.lastUsedAt
                          ? formatDate(passkey.lastUsedAt)
                          : t('passkeys.never'),
                      })}
                    </Text>
                  </div>
                </Group>
                <ActionIcon
                  variant="subtle"
                  color="red"
                  onClick={() => passkey.id && setDeletePasskeyId(passkey.id)}
                  title={t('passkeys.delete')}
                  aria-label={t('passkeys.delete')}
                >
                  <IconTrash size={16} />
                </ActionIcon>
              </Group>
            </Paper>
          ))}
        </Stack>
      ) : (
        <Paper withBorder p="md">
          <Stack align="center" gap="xs">
            <IconDevices size={32} opacity={0.5} />
            <Text size="sm" c="dimmed" ta="center">
              {t('passkeys.empty')}
            </Text>
          </Stack>
        </Paper>
      )}

      <Modal
        opened={showRegisterModal}
        onClose={() => {
          setShowRegisterModal(false)
          setDeviceName('')
          setRegisterError(null)
        }}
        title={t('passkeys.register.title')}
      >
        <Stack>
          <Text size="sm" c="dimmed">
            {t('passkeys.register.description')}
          </Text>

          <TextInput
            label={t('passkeys.register.deviceName')}
            placeholder={t('passkeys.register.deviceNamePlaceholder')}
            value={deviceName}
            onChange={(e) => setDeviceName(e.target.value)}
          />

          {registerError && (
            <Alert icon={<IconAlertCircle size={16} />} color="red">
              {registerError}
            </Alert>
          )}

          <Group justify="flex-end" mt="md">
            <Button variant="default" onClick={() => setShowRegisterModal(false)}>
              {t('actions.cancelAction')}
            </Button>
            <Button onClick={handleRegister} loading={isRegistering}>
              {t('passkeys.register.confirm')}
            </Button>
          </Group>
        </Stack>
      </Modal>

      <ConfirmDialog
        isOpen={deletePasskeyId !== null}
        onClose={() => setDeletePasskeyId(null)}
        onConfirm={() => deletePasskeyId && handleDelete(deletePasskeyId)}
        title={t('passkeys.deleteConfirm.title')}
        message={t('passkeys.deleteConfirm.message')}
        confirmText={t('passkeys.deleteConfirm.confirm')}
        variant="danger"
        isLoading={deletePasskeyMutation.isPending}
      />
    </Stack>
  )
}
