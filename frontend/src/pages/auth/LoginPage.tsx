import { useTranslation } from 'react-i18next'
import { useLocation } from 'react-router-dom'
import { LoginForm, type LoginFormMode } from '@/components/auth/LoginForm'
import { TransactionalCardShell } from '@/components/common/TransactionalCard'
import { useAppName } from '../../hooks/useAppName'

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

  return (
    <TransactionalCardShell>
      <LoginForm
        key={initialMode}
        initialMode={initialMode}
        title={t('welcome', { appName })}
        subtitle={t('auth.login.subtitle')}
        titleOrder={1}
        afterSignIn="redirect"
      />
    </TransactionalCardShell>
  )
}
