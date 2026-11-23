import { useTranslation } from 'react-i18next'
import { Alert, Button, Group, Stack, Text } from '@mantine/core'
import { IconMailOpened } from '@tabler/icons-react'
import { useListMyInvitations } from '@/api/endpoints/invitations/invitations'
import { useAuthStore } from '@/store/authStore'
import { useAcceptPendingInvitation } from './useAcceptPendingInvitation'

/**
 * "You have invitations waiting."
 *
 * This catches someone invited before they had an account who then signs up through the ordinary
 * form rather than by clicking the link in the e-mail, or who put off the end of their activation.
 * Nothing enrols them automatically — signing up is not joining a team — so without this banner
 * their invitations would simply sit in the database until they lapsed. It shows on the home and on
 * the team list (WEB-193).
 */
export function PendingInvitationsBanner() {
  const { t } = useTranslation()
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated)

  const { data } = useListMyInvitations({ query: { enabled: isAuthenticated } })
  const { acceptInvitation, isPending } = useAcceptPendingInvitation()

  const invitations = data?.invitations ?? []
  if (invitations.length === 0) {
    return null
  }

  return (
    <Alert icon={<IconMailOpened size={18} />} color="primary" mb="lg">
      <Stack gap="sm">
        <Text fw={500}>{t('invitations.banner.title', { count: invitations.length })}</Text>
        {invitations.map((invitation) => (
          <Group key={invitation.id} justify="space-between" wrap="wrap">
            <Text size="sm">
              {t('invitations.banner.line', {
                inviter: invitation.inviterName,
                team: invitation.team.name,
              })}
            </Text>
            <Button
              size="compact-sm"
              loading={isPending}
              onClick={() => acceptInvitation(invitation)}
            >
              {t('invitations.banner.accept')}
            </Button>
          </Group>
        ))}
      </Stack>
    </Alert>
  )
}
