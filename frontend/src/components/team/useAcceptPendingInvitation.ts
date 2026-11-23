import { useNavigate } from 'react-router-dom'
import { useQueryClient } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import i18next from 'i18next'
import {
  useAcceptMyInvitation,
  getListMyInvitationsQueryKey,
} from '@/api/endpoints/invitations/invitations'
import { getListTeamsQueryKey } from '@/api/endpoints/teams/teams'
import type { MyInvitationDto } from '@/api/dto'
import { paths } from '@/config/paths'

/**
 * Accepts one of the caller's own invitations and lands on the team it opens, as the e-mail link's
 * page does (`AcceptInvitationPage`). Shared by `PendingInvitationsBanner` and the end of an
 * account activation (`VerifyEmailPage`), docs/LEDGER_*.md WEB-193.
 */
export function useAcceptPendingInvitation() {
  const queryClient = useQueryClient()
  const navigate = useNavigate()
  const mutation = useAcceptMyInvitation()

  const acceptInvitation = (invitation: MyInvitationDto) => {
    mutation.mutate(
      { invitationId: invitation.id },
      {
        onSuccess: () => {
          queryClient.invalidateQueries({ queryKey: getListMyInvitationsQueryKey() })
          // A new membership: every teams listing, the team switcher's and the home's included.
          queryClient.invalidateQueries({ queryKey: getListTeamsQueryKey() })
          notifications.show({
            message: i18next.t('invitations.banner.joined', { team: invitation.team.name }),
            color: 'green',
          })
          navigate(paths.team(invitation.team.slug))
        },
      }
    )
  }

  return { acceptInvitation, isPending: mutation.isPending }
}
