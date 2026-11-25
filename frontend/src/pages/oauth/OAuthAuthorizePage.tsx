import { useMemo, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { notifications } from '@mantine/notifications'
import { IconAlertTriangle, IconApps, IconCheck, IconX } from '@tabler/icons-react'
import { Alert, Button, Code, Loader, Stack, Text, ThemeIcon } from '@mantine/core'
import { TransactionalCard, TransactionalCardShell } from '@/components/common/TransactionalCard'
import { useAuth } from '@/hooks/useAuth'
import { useAppName } from '@/hooks/useAppName'
import { useOauthAuthorize } from '@/api/endpoints/oauth/oauth'
import { deniedRedirect, parseAuthorizeParams } from '@/lib/oauthAuthorize'

/**
 * The consent screen of the OAuth 2.0 authorization code flow (docs/LEDGER_*.md API-199): an
 * external application sent the browser here, the member — signed in by the route's guard — reads
 * who asks and where the code goes, then authorizes or refuses.
 *
 * Never on its own: nothing registers the application or vouches for its `redirect_uri`, so the
 * member pressing a button on a screen that shows both is the only check there is.
 */
export function OAuthAuthorizePage() {
  const { t } = useTranslation()
  const [searchParams] = useSearchParams()
  const { user } = useAuth()
  const appName = useAppName()
  const request = useMemo(() => parseAuthorizeParams(searchParams), [searchParams])
  const [leaving, setLeaving] = useState(false)

  const authorize = useOauthAuthorize({
    mutation: {
      onSuccess: ({ redirectUri }) => {
        setLeaving(true)
        window.location.assign(redirectUri)
      },
      onError: () => {
        notifications.show({ message: t('oauth.errors.authorizationFailed'), color: 'red' })
      },
    },
  })

  if (!request) {
    return (
      <TransactionalCard
        data-testid="oauth-invalid"
        icon={
          <ThemeIcon size={64} radius="xl" color="red">
            <IconX size={32} />
          </ThemeIcon>
        }
        title={t('oauth.errors.title')}
        description={t('oauth.errors.invalidRequest')}
      />
    )
  }

  if (leaving) {
    return (
      <TransactionalCardShell>
        <Stack align="center" gap="md">
          <Loader size="lg" />
          <Text c="dimmed">{t('oauth.redirecting')}</Text>
        </Stack>
      </TransactionalCardShell>
    )
  }

  const deny = () => {
    setLeaving(true)
    window.location.assign(deniedRedirect(request))
  }

  return (
    <TransactionalCard
      data-testid="oauth-consent"
      icon={
        <ThemeIcon size={64} radius="xl">
          <IconApps size={32} />
        </ThemeIcon>
      }
      title={t('oauth.confirm.title')}
      description={t('oauth.confirm.question', {
        application: request.clientId,
        name: user?.displayName ?? '',
      })}
      actions={
        <>
          <Button
            fullWidth
            leftSection={<IconCheck size={16} />}
            loading={authorize.isPending}
            onClick={() =>
              authorize.mutate({
                data: {
                  clientId: request.clientId,
                  redirectUri: request.redirectUri,
                  codeChallenge: request.codeChallenge,
                  codeChallengeMethod: 'S256',
                  state: request.state,
                  confirmed: true,
                },
              })
            }
          >
            {t('oauth.confirm.authorize')}
          </Button>
          <Button
            fullWidth
            variant="default"
            leftSection={<IconX size={16} />}
            disabled={authorize.isPending}
            onClick={deny}
          >
            {t('oauth.confirm.deny')}
          </Button>
        </>
      }
    >
      <Stack gap={4} w="100%">
        <Text size="sm" c="dimmed">
          {t('oauth.confirm.redirect')}
        </Text>
        <Code block style={{ whiteSpace: 'pre-wrap', wordBreak: 'break-all' }}>
          {request.redirectUri}
        </Code>
      </Stack>
      <Alert color="orange" variant="light" icon={<IconAlertTriangle size={16} />}>
        <Text size="sm">{t('oauth.confirm.warning', { appName })}</Text>
      </Alert>
    </TransactionalCard>
  )
}
