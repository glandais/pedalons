import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useLocation } from 'react-router-dom'
import { LoginForm, type LoginFormMode } from '@/components/auth/LoginForm'
import { TransactionalCardShell } from '@/components/common/TransactionalCard'
import { useAppName } from '../../hooks/useAppName'
import { usePageLabel } from '@/store/pageLabelStore'

/**
 * The sign-in page. The form itself — password, passkey, e-mailed code, account creation and the
 * `?next=` redirect — is `LoginForm`, shared with the visitor home hero.
 */
export function LoginPage() {
  const { t } = useTranslation()
  const appName = useAppName()
  const location = useLocation()
  // « Créer un compte » links open the register step directly: router state from inside the app
  // (`{ mode: 'register' }`), `?mode=register` from outside it.
  const initialMode: LoginFormMode =
    location.state?.mode === 'register' ||
    new URLSearchParams(location.search).get('mode') === 'register'
      ? 'register'
      : 'login'

  // The tab names the step shown: the route only knows « Connexion »
  const [mode, setMode] = useState<LoginFormMode>(initialMode)
  const [seenInitialMode, setSeenInitialMode] = useState(initialMode)
  if (seenInitialMode !== initialMode) {
    setSeenInitialMode(initialMode)
    setMode(initialMode)
  }
  usePageLabel(
    mode === 'register'
      ? t('auth.register.pageTitle')
      : mode === 'otp'
        ? t('auth.otp.title')
        : undefined
  )

  return (
    <TransactionalCardShell>
      <LoginForm
        key={initialMode}
        initialMode={initialMode}
        onModeChange={setMode}
        title={t('welcome', { appName })}
        subtitle={t('auth.login.subtitle')}
        titleOrder={1}
        afterSignIn="redirect"
      />
    </TransactionalCardShell>
  )
}
