import { useEffect, useRef, useState } from 'react'
import { useSearchParams, useNavigate } from 'react-router-dom'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { useTranslation, Trans } from 'react-i18next'
import { useForm } from '@mantine/form'
import {
  IconCheck,
  IconX,
  IconFingerprint,
  IconLock,
  IconAlertTriangle,
  IconMailOpened,
  IconUsers,
} from '@tabler/icons-react'
import {
  Alert,
  Center,
  Paper,
  Stack,
  Title,
  Text,
  Button,
  Loader,
  PasswordInput,
} from '@mantine/core'
import { paths } from '@/config/paths'
import { useAuthStore } from '@/store/authStore'
import { isPasskeySupported, registerNewPasskey } from '@/lib/passkeys'
import { apiErrorCode } from '@/lib/apiError'
import type { MyInvitationDto } from '@/api/dto'
import { listMyInvitations } from '@/api/endpoints/invitations/invitations'
import { useAcceptPendingInvitation } from '@/components/team/useAcceptPendingInvitation'
import {
  activateAccount,
  confirmEmailChange,
  previewEmailLink,
  refresh,
} from '@/api/endpoints/authentication/authentication'

type VerificationState =
  | 'loading'
  | 'activate'
  | 'passkey'
  | 'activated'
  | 'invited'
  | 'emailChanged'
  | 'emailTaken'
  | 'error'

/**
 * Where a sign-up or address-change link lands. Nothing happens on load but reading the link: the
 * page shows the address first, and a sign-up only completes once its password is chosen here.
 * Loading the page used to sign its reader into the account — anyone's, if someone else's link was
 * forwarded to them (docs/LEDGER_*.md SEC-9, audit M5) — with the password whoever signed up had
 * typed (SEC-24, audit L4).
 *
 * A sign-up ends on the account's pending invitations when it has any (docs/LEDGER_*.md WEB-193),
 * read from the server by address: the token the invitation page kept in sessionStorage is gone
 * when the mail's link opens in another tab or browser, which is the usual case.
 */
export function VerifyEmailPage() {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()
  const token = searchParams.get('token')
  const { user: currentUser, isAuthenticated, setAccessToken, setUser } = useAuthStore()

  const [state, setState] = useState<VerificationState>(() => (token ? 'loading' : 'error'))
  const [email, setEmail] = useState<string | null>(null)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [isRegisteringPasskey, setIsRegisteringPasskey] = useState(false)
  const [invitations, setInvitations] = useState<MyInvitationDto[]>([])
  const { acceptInvitation, isPending: isAccepting } = useAcceptPendingInvitation()
  const hasRead = useRef(false)

  const form = useForm({
    initialValues: { password: '', confirmPassword: '' },
    validate: {
      password: (v) => (v.length < 8 ? t('auth.validation.passwordMin') : null),
      confirmPassword: (v, values) =>
        v !== values.password ? t('auth.validation.passwordMismatch') : null,
    },
  })

  useEffect(() => {
    if (!token || hasRead.current) {
      return
    }
    hasRead.current = true

    const read = async () => {
      try {
        const link = await previewEmailLink({ token }, { skipErrorToast: true })
        setEmail(link.email)
        if (link.kind === 'SIGN_UP') {
          setState('activate')
          return
        }
        // An address change needs no password and opens no session: it applies at once.
        await confirmEmailChange({ token }, { skipErrorToast: true })
        setState('emailChanged')
        if (useAuthStore.getState().isAuthenticated) {
          // The access token in hand names the old address, which the backend no longer resolves
          // (a 403, not a 401: the interceptor would not refresh). A fresh one carries the new
          // address. The change is applied either way, so a failure here is not the link's.
          try {
            const session = await refresh({ skipErrorToast: true })
            if (session.accessToken) setAccessToken(session.accessToken)
            if (session.user) setUser(session.user)
          } catch {
            // The next 401 refreshes the session; nothing to show here.
          }
        }
      } catch (error: unknown) {
        setState(apiErrorCode(error) === 'EMAIL_ALREADY_EXISTS' ? 'emailTaken' : 'error')
      }
    }

    void read()
  }, [token, setAccessToken, setUser])

  const handleActivate = async (values: { password: string }) => {
    if (!token) return
    setIsSubmitting(true)
    try {
      const data = await activateAccount(
        { token, password: values.password },
        { skipErrorToast: true }
      )
      if (data.accessToken) setAccessToken(data.accessToken)
      if (data.user) setUser(data.user)
      if (isPasskeySupported()) {
        setState('passkey')
      } else {
        setState((await showInvitations()) ? 'invited' : 'activated')
      }
    } catch {
      setState('error')
    } finally {
      setIsSubmitting(false)
    }
  }

  /** Loads the new account's pending invitations; true when there is one to offer. */
  const showInvitations = async () => {
    try {
      const data = await listMyInvitations({ skipErrorToast: true })
      setInvitations(data.invitations)
      return data.invitations.length > 0
    } catch {
      // The home's banner offers them all the same.
      return false
    }
  }

  // After the passkey step, taken or declined: the invitations first, the home otherwise.
  const finish = async () => {
    if (await showInvitations()) {
      setState('invited')
    } else {
      navigate(paths.home())
    }
  }

  const handleRegisterPasskey = async () => {
    setIsRegisteringPasskey(true)
    try {
      await registerNewPasskey(undefined)
    } catch {
      // A failed registration does not hold up the account: carry on.
    }
    setIsRegisteringPasskey(false)
    await finish()
  }

  const renderContent = () => {
    switch (state) {
      case 'loading':
        return (
          <Stack align="center" gap="md">
            <Loader size="lg" />
            <Text>{t('auth.verifyEmail.verifying')}</Text>
          </Stack>
        )

      case 'activate':
        return (
          <Stack>
            <Stack gap="xs" ta="center">
              <Title order={1} size="h2">
                {t('auth.verifyEmail.activate.title')}
              </Title>
              <Text c="dimmed">
                <Trans
                  i18nKey="auth.verifyEmail.activate.message"
                  values={{ email }}
                  components={{ strong: <strong /> }}
                />
              </Text>
            </Stack>
            {isAuthenticated && currentUser && currentUser.email !== email && (
              <Alert color="yellow" icon={<IconAlertTriangle size={18} />}>
                <Trans
                  i18nKey="auth.verifyEmail.activate.signedInAs"
                  values={{ current: currentUser.email, email }}
                  components={{ strong: <strong /> }}
                />
              </Alert>
            )}
            <form onSubmit={form.onSubmit(handleActivate)}>
              <Stack>
                {/* The address, for password managers: they file the new password under it. */}
                <input
                  type="email"
                  name="email"
                  autoComplete="username"
                  value={email ?? ''}
                  readOnly
                  hidden
                />
                <PasswordInput
                  label={t('auth.form.password')}
                  placeholder={t('auth.form.passwordPlaceholder')}
                  name="new-password"
                  autoComplete="new-password"
                  leftSection={<IconLock size={16} />}
                  {...form.getInputProps('password')}
                />
                <PasswordInput
                  label={t('auth.form.confirmPassword')}
                  placeholder={t('auth.form.confirmPasswordPlaceholder')}
                  name="new-password-confirm"
                  autoComplete="new-password"
                  leftSection={<IconLock size={16} />}
                  {...form.getInputProps('confirmPassword')}
                />
                <Button type="submit" fullWidth loading={isSubmitting}>
                  {t('auth.verifyEmail.activate.button')}
                </Button>
              </Stack>
            </form>
            <Text size="sm" c="dimmed" ta="center">
              {t('auth.verifyEmail.activate.notYours')}
            </Text>
          </Stack>
        )

      case 'passkey':
        return (
          <Stack ta="center">
            <IconFingerprint
              size={48}
              style={{ margin: '0 auto' }}
              color="var(--mantine-color-blue-6)"
            />
            <Title order={1} size="h2">
              {t('auth.verifyEmail.passkey.title')}
            </Title>
            <Text c="dimmed">{t('auth.verifyEmail.passkey.message')}</Text>
            <Button
              onClick={handleRegisterPasskey}
              loading={isRegisteringPasskey}
              fullWidth
              leftSection={<IconFingerprint size={18} />}
            >
              {t('auth.verifyEmail.passkey.register')}
            </Button>
            <Button onClick={() => void finish()} variant="subtle" fullWidth>
              {t('auth.verifyEmail.passkey.skip')}
            </Button>
          </Stack>
        )

      case 'activated':
        return (
          <Stack ta="center">
            <IconCheck
              size={48}
              style={{ margin: '0 auto' }}
              color="var(--mantine-color-green-6)"
            />
            <Title order={1} size="h2">
              {t('auth.verifyEmail.success.title')}
            </Title>
            <Text c="dimmed">{t('auth.verifyEmail.success.message')}</Text>
            <Button component={PrefetchLink} to={paths.home()} fullWidth>
              {t('auth.verifyEmail.success.continue')}
            </Button>
          </Stack>
        )

      case 'invited':
        return (
          <Stack>
            <Stack gap="xs" ta="center">
              <IconMailOpened
                size={48}
                style={{ margin: '0 auto' }}
                color="var(--mantine-color-primary-6)"
              />
              <Title order={1} size="h2">
                {t('auth.verifyEmail.invited.title')}
              </Title>
              <Text c="dimmed">{t('invitations.banner.title', { count: invitations.length })}</Text>
            </Stack>
            {invitations.map((invitation) => (
              <Stack key={invitation.id} gap="xs">
                <Text ta="center">
                  {t('invitations.banner.line', {
                    inviter: invitation.inviterName,
                    team: invitation.team.name,
                  })}
                </Text>
                <Button
                  onClick={() => acceptInvitation(invitation)}
                  loading={isAccepting}
                  fullWidth
                  leftSection={<IconUsers size={18} />}
                >
                  {invitations.length === 1
                    ? t('invitations.accept.join')
                    : t('auth.verifyEmail.invited.joinTeam', { team: invitation.team.name })}
                </Button>
              </Stack>
            ))}
            <Button component={PrefetchLink} to={paths.home()} variant="subtle" fullWidth>
              {t('auth.verifyEmail.invited.later')}
            </Button>
          </Stack>
        )

      case 'emailChanged':
        return (
          <Stack ta="center">
            <IconCheck
              size={48}
              style={{ margin: '0 auto' }}
              color="var(--mantine-color-green-6)"
            />
            <Title order={1} size="h2">
              {t('auth.verifyEmail.emailChanged.title')}
            </Title>
            <Text c="dimmed">
              <Trans
                i18nKey="auth.verifyEmail.emailChanged.message"
                values={{ email }}
                components={{ strong: <strong /> }}
              />
            </Text>
            {isAuthenticated ? (
              <Button component={PrefetchLink} to={paths.home()} fullWidth>
                {t('auth.verifyEmail.success.continue')}
              </Button>
            ) : (
              <Button component={PrefetchLink} to={paths.login()} fullWidth>
                {t('auth.verifyEmail.success.login')}
              </Button>
            )}
          </Stack>
        )

      case 'emailTaken':
      case 'error':
        return (
          <Stack ta="center">
            <IconX size={48} style={{ margin: '0 auto' }} color="var(--mantine-color-red-6)" />
            <Title order={1} size="h2">
              {t('auth.verifyEmail.error.title')}
            </Title>
            <Text c="dimmed">
              {state === 'emailTaken'
                ? t('auth.verifyEmail.emailChanged.taken')
                : t('auth.verifyEmail.error.message')}
            </Text>
            <Button component={PrefetchLink} to={paths.login()} fullWidth>
              {t('auth.verifyEmail.success.login')}
            </Button>
          </Stack>
        )
    }
  }

  return (
    <Center mih="70vh">
      <Paper shadow="lg" radius="lg" p="xl" w="100%" maw={420}>
        {renderContent()}
      </Paper>
    </Center>
  )
}
