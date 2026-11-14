import { useMemo, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { notifications } from '@mantine/notifications'
import { IconAlertTriangle, IconApps, IconCheck, IconX } from '@tabler/icons-react'
import {
  Alert,
  Button,
  Center,
  Code,
  Group,
  Loader,
  Paper,
  Stack,
  Text,
  ThemeIcon,
  Title,
} from '@mantine/core'
import { useAuth } from '@/hooks/useAuth'
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
      <Center mih="70vh">
        <Paper shadow="lg" radius="lg" p="xl" w="100%" maw={460} data-testid="oauth-invalid">
          <Stack align="center" gap="md">
            <ThemeIcon size={64} radius="xl" color="red">
              <IconX size={32} />
            </ThemeIcon>
            <Title order={2} ta="center">
              {t('oauth.errors.title')}
            </Title>
            <Text c="dimmed" ta="center">
              {t('oauth.errors.invalidRequest')}
            </Text>
          </Stack>
        </Paper>
      </Center>
    )
  }

  if (leaving) {
    return (
      <Center mih="70vh">
        <Paper shadow="lg" radius="lg" p="xl" w="100%" maw={460}>
          <Stack align="center" gap="md">
            <Loader size="lg" />
            <Text c="dimmed">{t('oauth.redirecting')}</Text>
          </Stack>
        </Paper>
      </Center>
    )
  }

  const deny = () => {
    setLeaving(true)
    window.location.assign(deniedRedirect(request))
  }

  return (
    <Center mih="70vh">
      <Paper shadow="lg" radius="lg" p="xl" w="100%" maw={460} data-testid="oauth-consent">
        <Stack align="center" gap="md">
          <ThemeIcon size={64} radius="xl" color="blue">
            <IconApps size={32} />
          </ThemeIcon>
          <Title order={2} ta="center">
            {t('oauth.confirm.title')}
          </Title>
          <Text ta="center">
            {t('oauth.confirm.question', {
              application: request.clientId,
              name: user?.displayName ?? '',
            })}
          </Text>
          <Stack gap={4} w="100%">
            <Text size="sm" c="dimmed">
              {t('oauth.confirm.redirect')}
            </Text>
            <Code block style={{ whiteSpace: 'pre-wrap', wordBreak: 'break-all' }}>
              {request.redirectUri}
            </Code>
          </Stack>
          <Alert color="orange" variant="light" icon={<IconAlertTriangle size={16} />}>
            <Text size="sm">{t('oauth.confirm.warning')}</Text>
          </Alert>
          <Group grow w="100%">
            <Button
              variant="default"
              leftSection={<IconX size={16} />}
              disabled={authorize.isPending}
              onClick={deny}
            >
              {t('oauth.confirm.deny')}
            </Button>
            <Button
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
          </Group>
        </Stack>
      </Paper>
    </Center>
  )
}
