import { useState } from 'react'
import { invalidateTeamDashboard } from '@/lib/teamDashboardCache'
import { useNavigate } from 'react-router-dom'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { Stack, Group, Button, Box } from '@mantine/core'
import { getGetTeamQueryKey } from '@/api/endpoints/teams/teams'
import {
  useLeaveTeam,
  useJoinTeam,
  getGetMembersQueryKey,
} from '@/api/endpoints/team-members/team-members'
import { useAuth } from '../../hooks/useAuth'
import { useFavicon } from '../../hooks/useFavicon'
import { useTeamNavItems } from '@/hooks/useNavItems'
import { ConfirmDialog } from '../common/ConfirmDialog'
import { NavButtons } from '../common/NavButtons'
import { ShareButton } from '../common/ShareButton'
import { VisibilityBadge } from '../card/common'
import { TeamAvatar } from './TeamAvatar'
import { TeamSwitcher } from './TeamSwitcher'
import { invalidateTeamSwitcher } from './teamSwitcherData'
import type { TeamDetailDto } from '@/api/dto'
import { paths } from '@/config/paths'
import { useTeamAccess } from '@/lib/teamAccess'

interface TeamLayoutProps {
  team: TeamDetailDto
  /** Tab identifier (`useTeamNavItems`): 'dashboard', 'agenda', 'posts', 'routes', 'about'…, or a page slug */
  currentTab: string
  /** `currentTab` is a custom page's slug, which may read like a section's id (a page « Agenda »). */
  onCustomPage?: boolean
  children: React.ReactNode
  /** Under the name: the dashboard puts the reader's role and the member count there. */
  meta?: React.ReactNode
  /** Before the header's own buttons: the dashboard's shortcuts (calendar, create). */
  actions?: React.ReactNode
}

export function TeamLayout({
  team,
  currentTab,
  onCustomPage,
  children,
  meta,
  actions,
}: TeamLayoutProps) {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const { isAuthenticated } = useAuth()
  const [showLeaveConfirm, setShowLeaveConfirm] = useState(false)

  // Set favicon to team logo
  useFavicon(team.about?.assets?.logo?.imageUrl?.replace('{size}', String(128)))

  // Joining and leaving follow the real membership; the administration entry, the rights a
  // platform admin holds everywhere (docs/LEDGER_*.md API-137).
  const { isMember, isOrganizer } = useTeamAccess(team)
  // `joinable` is what UserTeamAccessChecker enforces; without it the button only earns a 403.
  const canJoin = isAuthenticated && !isMember && team.visibility !== 'TEAM' && team.joinable
  const canLeave = isMember && team.role !== 'ADMIN'

  const joinMutation = useJoinTeam()
  const leaveMutation = useLeaveTeam()

  const handleJoin = () => {
    joinMutation.mutate(
      { teamSlug: team.slug },
      {
        onSuccess: () => {
          queryClient.invalidateQueries({ queryKey: getGetTeamQueryKey(team.slug) })
          queryClient.invalidateQueries({ queryKey: getGetMembersQueryKey(team.slug) })
          invalidateTeamSwitcher(queryClient)
          invalidateTeamDashboard(queryClient, team.slug)
        },
      }
    )
  }

  const handleLeave = () => {
    leaveMutation.mutate(
      { teamSlug: team.slug },
      {
        onSuccess: () => {
          queryClient.invalidateQueries({ queryKey: getGetTeamQueryKey(team.slug) })
          queryClient.invalidateQueries({ queryKey: getGetMembersQueryKey(team.slug) })
          invalidateTeamSwitcher(queryClient)
          invalidateTeamDashboard(queryClient, team.slug)
          navigate(paths.teams())
        },
      }
    )
  }

  // Tab list (shared with the breadcrumb dropdown as the single source of truth)
  const tabs = useTeamNavItems(team)

  return (
    <Stack>
      {/* Team Header */}
      {/* Kept under ~120px so the first real content is visible without scrolling */}
      <Group align="center" wrap="nowrap" gap="sm">
        <TeamAvatar team={team} size="lg" />
        <Box style={{ flex: 1, minWidth: 0 }}>
          <Group justify="space-between" align="center" wrap="wrap" gap="sm">
            <Group gap="sm" style={{ minWidth: 0 }}>
              <TeamSwitcher team={team} section={onCustomPage ? undefined : currentTab} />
              <VisibilityBadge visibility={team.visibility} />
            </Group>

            <Group gap="sm">
              {actions}

              {canJoin && (
                <Button onClick={handleJoin} loading={joinMutation.isPending}>
                  {joinMutation.isPending
                    ? t('teams.detail.actions.joining')
                    : t('teams.detail.actions.join')}
                </Button>
              )}

              {canLeave && (
                <Button variant="default" onClick={() => setShowLeaveConfirm(true)}>
                  {t('teams.detail.actions.leave')}
                </Button>
              )}

              {isOrganizer && (
                <Button variant="default" component={PrefetchLink} to={paths.teamAdmin(team.slug)}>
                  {t('teams.detail.actions.admin')}
                </Button>
              )}

              <ShareButton title={team.name} />
            </Group>
          </Group>
          {meta}
        </Box>
      </Group>

      {/* Team Navigation */}
      <NavButtons items={tabs} currentId={currentTab} label={t('nav.landmark.team')} />

      {/* Page Content */}
      <div>{children}</div>

      {/* Leave Team Confirmation Dialog */}
      <ConfirmDialog
        isOpen={showLeaveConfirm}
        onClose={() => setShowLeaveConfirm(false)}
        onConfirm={handleLeave}
        title={t('teams.detail.actions.leave')}
        message={t('teams.detail.actions.confirmLeave')}
        confirmText={t('teams.detail.actions.leave')}
        variant="warning"
        isLoading={leaveMutation.isPending}
      />
    </Stack>
  )
}
