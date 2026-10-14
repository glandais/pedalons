import { useCallback, useEffect, useRef, useState, type ReactNode } from 'react'
import { useNavigate, useLocation } from 'react-router-dom'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { useTranslation, Trans } from 'react-i18next'
import { useForm } from '@mantine/form'
import { notifications } from '@mantine/notifications'
import { IconFingerprint, IconUserPlus, IconLock, IconMail } from '@tabler/icons-react'
import {
  Stack,
  Title,
  Text,
  Button,
  Anchor,
  TextInput,
  PasswordInput,
  Divider,
  Checkbox,
  type TitleOrder,
} from '@mantine/core'
import { startAuthentication, browserSupportsWebAuthn } from '@simplewebauthn/browser'
import { useAuth } from '@/hooks/useAuth'
import { useAuthStore } from '@/store/authStore'
import { paths } from '@/config/paths'
import { apiErrorCode } from '@/lib/apiError'
import {
  loginWithPassword,
  register as registerUser,
} from '@/api/endpoints/authentication/authentication'
import type { AuthResponse, ErrorCode } from '@/api/dto'
import type { TranslationKey } from '@/lib/i18nUtils'
import { OtpLogin } from './OtpLogin'
import { safeNextPath } from '@/lib/safeNextPath'

/** The codes the sign-in and sign-up forms word their own way; any other gets its `errors.api.*` message. */
const AUTH_ERROR_KEYS: Partial<Record<ErrorCode, TranslationKey>> = {
  CONTENT_REJECTED: 'auth.errors.CONTENT_REJECTED',
  EMAIL_ALREADY_EXISTS: 'auth.errors.EMAIL_ALREADY_EXISTS',
  EMAIL_NOT_VERIFIED: 'auth.errors.EMAIL_NOT_VERIFIED',
  INVALID_CREDENTIALS: 'auth.errors.INVALID_CREDENTIALS',
  LOGIN_RATE_LIMITED: 'auth.errors.LOGIN_RATE_LIMITED',
}

export type LoginFormMode = 'login' | 'register' | 'otp'

export interface LoginFormProps {
  /** Heading of the sign-in step. The register and code steps keep their own. */
  title: ReactNode
  subtitle: ReactNode
  /** `1` on the login page, where the form is the page; `2` inside the home hero. */
  titleOrder?: TitleOrder
  /**
   * `redirect` (the login page): once signed in — or when already signed in on arrival — go to
   * `?next=`, the page the visitor came from, or the home.
   * `stay` (the home hero): stay put — the page itself re-renders for the signed-in member.
   */
  afterSignIn?: 'redirect' | 'stay'
  /** Step shown first when the form is uncontrolled — `register` for a « Créer un compte » link. */
  initialMode?: LoginFormMode
  /** Controlled step, for a page that opens the register step from elsewhere (a CTA). */
  mode?: LoginFormMode
  onModeChange?: (mode: LoginFormMode) => void
}

/**
 * The sign-in form — password, passkey, e-mailed code, and the account creation step — shared by
 * `LoginPage` and the visitor home hero. All of the auth logic lives here, once: the two places
 * differ only by their heading and by what happens after a successful sign-in (`afterSignIn`).
 */
export function LoginForm({
  title,
  subtitle,
  titleOrder = 1,
  afterSignIn = 'redirect',
  initialMode = 'login',
  mode: controlledMode,
  onModeChange,
}: LoginFormProps) {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const location = useLocation()
  const { isAuthenticated } = useAuth()
  const { setAccessToken, setUser } = useAuthStore()
  const redirects = afterSignIn === 'redirect'

  const fromLocation = location.state?.from
  // `?next=` comes from outside the router: the backend sends a visitor without a session there
  // from a download link (a data export), the API client after a session ended mid-page. A browser
  // path — loaded as such, which also keeps it right on a pinned host. Same-origin paths only.
  const next = redirects ? safeNextPath(new URLSearchParams(location.search).get('next')) : null
  const redirectTo =
    next ?? (fromLocation ? `${fromLocation.pathname}${fromLocation.search || ''}` : paths.home())
  const leaving = useRef(false)
  const goToRedirect = useCallback(() => {
    if (!redirects) return
    if (next) {
      if (!leaving.current) window.location.assign(next)
      leaving.current = true
    } else {
      navigate(redirectTo)
    }
  }, [navigate, next, redirectTo, redirects])

  const [ownMode, setOwnMode] = useState<LoginFormMode>(initialMode)
  const mode = controlledMode ?? ownMode
  const setMode = (value: LoginFormMode) => {
    setOwnMode(value)
    onModeChange?.(value)
  }
  const [isLoading, setIsLoading] = useState(false)
  const [passkeySupported, setPasskeySupported] = useState(false)

  useEffect(() => {
    setPasskeySupported(browserSupportsWebAuthn())
  }, [])

  const loginForm = useForm({
    initialValues: { email: '', password: '' },
    validate: {
      email: (v) =>
        !v || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v) ? t('auth.validation.email') : null,
      password: (v) => (!v ? t('auth.validation.required') : null),
    },
  })

  const registerForm = useForm({
    initialValues: {
      email: '',
      displayName: '',
      acceptTerms: false,
    },
    validate: {
      email: (v) =>
        !v || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v) ? t('auth.validation.email') : null,
      displayName: (v) =>
        !v || v.length < 2
          ? t('auth.validation.displayNameMin')
          : v.length > 100
            ? t('auth.validation.displayNameMax')
            : null,
      acceptTerms: (v) => (v ? null : t('auth.validation.acceptTerms')),
    },
  })

  useEffect(() => {
    if (isAuthenticated) {
      goToRedirect()
    }
  }, [isAuthenticated, goToRedirect])

  const handlePasskeyLogin = async () => {
    setIsLoading(true)
    try {
      const optionsResponse = await fetch('/api/auth/passkeys/authentication-options', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({}),
      })

      if (!optionsResponse.ok) {
        notifications.show({ message: t('auth.errors.passkeyFailed'), color: 'red' })
        return
      }

      const options = await optionsResponse.json()
      const assertion = await startAuthentication({ optionsJSON: options })

      const authResponse = await fetch('/api/auth/passkeys/authenticate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify(assertion),
      })

      if (authResponse.ok) {
        const data = await authResponse.json()
        setAccessToken(data.accessToken)
        setUser(data.user)
        goToRedirect()
      } else {
        notifications.show({ message: t('auth.errors.passkeyFailed'), color: 'red' })
      }
    } catch (error) {
      if (error instanceof Error && error.name === 'NotAllowedError') {
        return
      }
      notifications.show({ message: t('auth.errors.passkeyFailed'), color: 'red' })
    } finally {
      setIsLoading(false)
    }
  }

  const completeLogin = (data: AuthResponse) => {
    if (data.accessToken) setAccessToken(data.accessToken)
    if (data.user) setUser(data.user)
    goToRedirect()
  }

  const handleLogin = async (values: { email: string; password: string }) => {
    setIsLoading(true)
    try {
      // One message, the form's own: the mutator's toast would come on top of it.
      completeLogin(
        await loginWithPassword(
          { email: values.email, password: values.password },
          { skipErrorToast: true }
        )
      )
    } catch (error: unknown) {
      console.error('Login failed', error)
      const code = apiErrorCode(error)
      notifications.show({
        message:
          code && AUTH_ERROR_KEYS[code]
            ? t(AUTH_ERROR_KEYS[code])
            : t(`errors.api.${code}`, { defaultValue: t('auth.errors.loginFailed') }),
        color: 'red',
      })
    } finally {
      setIsLoading(false)
    }
  }

  const handleRegister = async (values: {
    email: string
    displayName: string
    acceptTerms: boolean
  }) => {
    setIsLoading(true)
    try {
      await registerUser(
        {
          email: values.email,
          displayName: values.displayName,
          acceptTerms: values.acceptTerms,
        },
        { skipErrorToast: true }
      )
      notifications.show({
        message: t('auth.register.success.checkEmail'),
        color: 'green',
      })
      setMode('login')
      loginForm.setFieldValue('email', values.email)
    } catch (error: unknown) {
      console.error('Registration failed', error)
      const code = apiErrorCode(error)
      notifications.show({
        message:
          code && AUTH_ERROR_KEYS[code]
            ? t(AUTH_ERROR_KEYS[code])
            : t(`errors.api.${code}`, { defaultValue: t('auth.errors.registrationFailed') }),
        color: 'red',
      })
    } finally {
      setIsLoading(false)
    }
  }

  if (mode === 'otp') {
    return (
      <OtpLogin
        initialEmail={loginForm.values.email}
        onSuccess={completeLogin}
        onBack={() => setMode('login')}
      />
    )
  }

  if (mode === 'register') {
    return (
      <Stack>
        <Stack gap="xs" ta="center">
          <Title order={2}>{t('auth.register.title')}</Title>
          <Text c="dimmed">{t('auth.register.subtitle')}</Text>
        </Stack>

        <form onSubmit={registerForm.onSubmit(handleRegister)}>
          <Stack>
            <TextInput
              label={t('auth.form.email')}
              placeholder="email@example.com"
              name="email"
              autoComplete="email"
              {...registerForm.getInputProps('email')}
            />
            <TextInput
              label={t('auth.form.displayName')}
              placeholder={t('auth.form.displayNamePlaceholder')}
              name="name"
              autoComplete="name"
              {...registerForm.getInputProps('displayName')}
            />
            {/* No password here: it is chosen on the page the mailed link opens, by whoever
                holds the mailbox (docs/LEDGER_*.md SEC-24, audit L4). */}
            {/* Mandatory: the terms carry the zero-tolerance clause on abusive content. The links
                open in a new tab so the half-filled form survives reading them. */}
            <Checkbox
              name="accept-terms"
              label={
                <Trans
                  i18nKey="auth.register.acceptTerms"
                  components={{
                    termsLink: <Anchor href={paths.terms()} target="_blank" inherit />,
                    privacyLink: <Anchor href={paths.privacy()} target="_blank" inherit />,
                  }}
                />
              }
              {...registerForm.getInputProps('acceptTerms', { type: 'checkbox' })}
            />
            <Button
              type="submit"
              fullWidth
              loading={isLoading}
              leftSection={<IconUserPlus size={20} />}
            >
              {t('auth.register.button')}
            </Button>
          </Stack>
        </form>

        <Text size="sm" ta="center">
          {t('auth.register.haveAccount')}{' '}
          <Anchor component="button" onClick={() => setMode('login')}>
            {t('auth.login.title')}
          </Anchor>
        </Text>
      </Stack>
    )
  }

  return (
    <Stack>
      <Stack gap="xs" ta="center">
        <Title order={titleOrder}>{title}</Title>
        <Text c="dimmed">{subtitle}</Text>
      </Stack>

      <form onSubmit={loginForm.onSubmit(handleLogin)}>
        <Stack>
          <TextInput
            label={t('auth.form.email')}
            placeholder="email@example.com"
            name="email"
            autoComplete="email"
            {...loginForm.getInputProps('email')}
          />
          <PasswordInput
            label={t('auth.form.password')}
            placeholder={t('auth.form.passwordPlaceholder')}
            name="password"
            autoComplete="current-password"
            leftSection={<IconLock size={16} />}
            {...loginForm.getInputProps('password')}
          />
          <Anchor component={PrefetchLink} to={paths.forgotPassword()} size="sm" ta="right">
            {t('auth.login.forgotPassword')}
          </Anchor>
          <Button type="submit" fullWidth loading={isLoading}>
            {t('auth.login.button')}
          </Button>
        </Stack>
      </form>

      <Divider label={t('common.or')} labelPosition="center" />

      {passkeySupported && (
        <Button
          variant="default"
          fullWidth
          leftSection={<IconFingerprint size={20} />}
          onClick={handlePasskeyLogin}
          loading={isLoading}
        >
          {t('auth.login.methods.passkey')}
        </Button>
      )}

      <Button
        variant="default"
        fullWidth
        leftSection={<IconMail size={20} />}
        onClick={() => setMode('otp')}
        disabled={isLoading}
      >
        {t('auth.login.methods.otp')}
      </Button>

      <Text size="sm" ta="center">
        {t('auth.login.noAccount')}{' '}
        <Anchor component="button" onClick={() => setMode('register')}>
          {t('auth.login.methods.register')}
        </Anchor>
      </Text>

      <Text size="xs" c="dimmed" ta="center">
        <Trans
          i18nKey="auth.login.termsText"
          components={{
            termsLink: <Anchor href={paths.terms()} />,
            privacyLink: <Anchor href={paths.privacy()} />,
          }}
        />
      </Text>
    </Stack>
  )
}
