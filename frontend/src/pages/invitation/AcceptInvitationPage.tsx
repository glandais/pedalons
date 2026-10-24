import { useEffect, useRef, useState } from 'react'
import { useSearchParams, useNavigate, useLocation } from 'react-router-dom'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { IconCheck, IconX, IconUsers, IconLogin } from '@tabler/icons-react'
import { Alert, Button, Center, Group, Loader, Paper, Stack, Text, Title } from '@mantine/core'
import { paths } from '@/config/paths'
import { useAuthStore } from '@/store/authStore'
import { preview, accept } from '@/api/endpoints/invitations/invitations'
import { getListTeamsQueryKey, useGetTeam } from '@/api/endpoints/teams/teams'
import { ApiClientError } from '@/lib/apiError'
import type { ErrorCode, InvitationPreviewDto } from '@/api/dto'

/**
 * Where an invitation e-mail lands.
 *
 * One page for three states — signed in, signed out with an account, signed out without one —
 * which is why both e-mail templates point here. The preview call is public precisely so that a
 * signed-out visitor is told who is inviting them and to what, instead of being dropped on a bare
 * login form with no explanation.
 *
 * The token is kept in sessionStorage across the login or sign-up detour, so coming back does not
 * depend on the browser having preserved the query string.
 */
const TOKEN_STORAGE_KEY = 'pendingInvitationToken'

type PageState = 'loading' | 'ready' | 'accepted' | 'error'

export function AcceptInvitationPage() {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const location = useLocation()
  const queryClient = useQueryClient()
  const [searchParams] = useSearchParams()
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated)
  const logout = useAuthStore((state) => state.logout)

  const token = searchParams.get('token')

  const [state, setState] = useState<PageState>(() => (token ? 'loading' : 'error'))
  const [invitation, setInvitation] = useState<InvitationPreviewDto | null>(null)
  const [failureCode, setFailureCode] = useState<ErrorCode | null>(null)
  const [isAccepting, setIsAccepting] = useState(false)
  const hasLoaded = useRef(false)

  // An invitation that is no longer PENDING may simply be one this very member already accepted:
  // replaying the link is a success on the server's side, so it must not read as "no longer valid"
  // here. Only a member gets a role back; anyone else is told the invitation is spent.
  const checkMembership = isAuthenticated && invitation !== null && !invitation.redeemable
  const { data: invitedTeam, isLoading: isCheckingMembership } = useGetTeam(
    invitation?.teamSlug ?? '',
    {
      query: { enabled: checkMembership, retry: false },
      request: { skipErrorToast: true },
    }
  )
  const membershipPending = checkMembership && isCheckingMembership
  const isAlreadyMember = checkMembership && Boolean(invitedTeam?.role)

  useEffect(() => {
    if (!token || hasLoaded.current) {
      return
    }
    hasLoaded.current = true
    // Survives the trip through login or sign-up.
    sessionStorage.setItem(TOKEN_STORAGE_KEY, token)

    preview({ token })
      .then((data) => {
        setInvitation(data)
        setState('ready')
      })
      .catch((error) => {
        setFailureCode(error instanceof ApiClientError ? error.error.code : null)
        setState('error')
      })
  }, [token])

  const handleAccept = () => {
    if (!token) return
    setIsAccepting(true)
    setFailureCode(null)
    accept({ token })
      .then(() => {
        sessionStorage.removeItem(TOKEN_STORAGE_KEY)
        // A new membership: every teams listing, the team switcher's (WEB-111) and the home's included.
        queryClient.invalidateQueries({ queryKey: getListTeamsQueryKey() })
        setState('accepted')
        if (invitation) {
          navigate(paths.team(invitation.teamSlug), { replace: true })
        }
      })
      .catch((error) => {
        setFailureCode(error instanceof ApiClientError ? error.error.code : null)
        setState('error')
      })
      .finally(() => setIsAccepting(false))
  }

  // Whoever is signed in is not who the invitation is for. Signing out and coming back to this very
  // URL is the way through, so it is offered as a button rather than left as an exercise. logout()
  // reloads the page it is told to — by default the login page, which would drop the invitation.
  const handleSwitchAccount = () => logout({ redirectTo: `${location.pathname}${location.search}` })

  if (state === 'loading') {
    return (
      <Center mih="60vh">
        <Loader />
      </Center>
    )
  }

  if (state === 'error' || !invitation) {
    return (
      <Center mih="60vh">
        <Paper p="xl" withBorder maw={480} w="100%">
          <Stack align="center">
            <IconX size={40} color="var(--mantine-color-danger-6)" />
            <Title order={3} ta="center">
              {t('invitations.accept.unavailableTitle')}
            </Title>
            <Text c="dimmed" ta="center">
              {failureCode
                ? t(`errors.api.${failureCode}`)
                : t('invitations.accept.unavailableBody')}
            </Text>
            {failureCode === 'TEAM_INVITE_EMAIL_MISMATCH' && isAuthenticated && (
              <Button onClick={handleSwitchAccount}>{t('invitations.accept.switchAccount')}</Button>
            )}
            <Button component={PrefetchLink} to={paths.teams()} variant="default">
              {t('invitations.accept.backToTeams')}
            </Button>
          </Stack>
        </Paper>
      </Center>
    )
  }

  if (state === 'accepted') {
    return (
      <Center mih="60vh">
        <Paper p="xl" withBorder maw={480} w="100%">
          <Stack align="center">
            <IconCheck size={40} color="var(--mantine-color-success-6)" />
            <Title order={3} ta="center">
              {t('invitations.accept.joined', { team: invitation.teamName })}
            </Title>
          </Stack>
        </Paper>
      </Center>
    )
  }

  return (
    <Center mih="60vh">
      <Paper p="xl" withBorder maw={480} w="100%">
        <Stack>
          <Center>
            <IconUsers size={40} />
          </Center>
          <Title order={3} ta="center">
            {t('invitations.accept.title', {
              inviter: invitation.inviterName,
              team: invitation.teamName,
            })}
          </Title>
          <Text c="dimmed" ta="center">
            {t('invitations.accept.subtitle', {
              role: t(`roles.${invitation.role}`),
              email: invitation.maskedEmail,
            })}
          </Text>

          {membershipPending && (
            <Center>
              <Loader size="sm" />
            </Center>
          )}

          {isAlreadyMember && (
            <Stack gap="xs">
              <Alert color="success">
                {t('invitations.accept.alreadyMember', { team: invitation.teamName })}
              </Alert>
              <Button component={PrefetchLink} to={paths.team(invitation.teamSlug)} fullWidth>
                {t('invitations.accept.goToTeam')}
              </Button>
            </Stack>
          )}

          {!invitation.redeemable && !isAlreadyMember && !membershipPending && (
            <Alert color="orange">{t('invitations.accept.notRedeemable')}</Alert>
          )}

          {invitation.redeemable && isAuthenticated && (
            <Stack gap="xs">
              <Button onClick={handleAccept} loading={isAccepting} fullWidth>
                {t('invitations.accept.join')}
              </Button>
              <Button variant="subtle" size="compact-sm" onClick={handleSwitchAccount}>
                {t('invitations.accept.switchAccount')}
              </Button>
            </Stack>
          )}

          {invitation.redeemable && !isAuthenticated && (
            <Stack gap="xs">
              <Text size="sm" ta="center">
                {t('invitations.accept.signInPrompt')}
              </Text>
              <Group justify="center">
                <Button
                  component={PrefetchLink}
                  to={paths.login()}
                  state={{ from: location }}
                  leftSection={<IconLogin size={16} />}
                >
                  {t('invitations.accept.signIn')}
                </Button>
              </Group>
            </Stack>
          )}
        </Stack>
      </Paper>
    </Center>
  )
}
