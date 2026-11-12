import { useTranslation } from 'react-i18next'
import { IconUsers } from '@tabler/icons-react'
import { Group, Box, Button } from '@mantine/core'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { useTeamAccess } from '@/lib/teamAccess'
import { useAuthStore, selectIsAuthenticated, selectIsPlatformAdmin } from '@/store/authStore'
import { isTeamFull } from '../team/TeamMemberLimit'
import { useJoinTeamAction } from '../team/useJoinTeamAction'
import type { TeamDetailDto } from '@/api/dto'
import { Card, CardContent, CardTitle, CardDescription, CardImage } from './common'
import { VisibilityBadge, Stat, CardSkeleton, RoleBadge } from './common'
import { TeamAvatar } from '../team/TeamAvatar'
import { paths } from '@/config/paths'

interface TeamCardProps {
  team: TeamDetailDto
  showRole?: boolean
}

export function TeamCard({ team, showRole = false }: TeamCardProps) {
  const { t } = useTranslation()

  const membersIcon = <IconUsers size={16} />
  // A member's card carries no action: touching it opens the team (R13).
  const { isMember } = useTeamAccess(team)

  return (
    <Card to={paths.team(team.slug)} footer={isMember ? undefined : <TeamCardJoin team={team} />}>
      {/* Header image */}
      <CardImage media={team.about} alt={team.name} height={120} type="TEAM" />

      <CardContent>
        {/* Title row with avatar */}
        <Group gap="sm" mb="xs" wrap="nowrap">
          <TeamAvatar team={team} size="md" />
          <Box style={{ flex: 1, minWidth: 0 }}>
            <CardTitle>{team.name}</CardTitle>
          </Box>
        </Group>

        <CardDescription excerpt={team.excerpt} markdown={true} media={team.about} />

        <Group justify="space-between" mt="md">
          <Stat icon={membersIcon}>{t('memberCount', { count: team.memberCount })}</Stat>

          <Group gap="xs">
            {team.visibility === 'TEAM' && (
              <VisibilityBadge visibility={team.visibility} showIcon={false} />
            )}
            {showRole && team.role && (
              <RoleBadge role={team.role}>
                {t(`roles.${team.role satisfies 'ADMIN' | 'ORGANIZER' | 'MEMBER'}`)}
              </RoleBadge>
            )}
          </Group>
        </Group>
      </CardContent>
    </Card>
  )
}

/**
 * The card's one action, at its foot (docs/LEDGER_*.md WEB-167, R13, the app's discovery card): to
 * a reader outside the team, « Rejoindre l'équipe » — the team page's call, « Adhésion… » while it
 * runs, the sign-in page first for an anonymous visitor —, or a disabled « Sur invitation » when the
 * team does not open to a button — a member's card gets none (`TeamCard`). Outside the card's link: a click joins, it
 * does not open the team.
 */
function TeamCardJoin({ team }: { team: TeamDetailDto }) {
  const { t } = useTranslation()
  const isAuthenticated = useAuthStore(selectIsAuthenticated)
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  const { join, isPending } = useJoinTeamAction(team.slug)

  // `joinable` is what the server enforces (TeamLayout's rule); a private team never opens.
  const open = team.visibility !== 'TEAM' && team.joinable
  if (!open) {
    return (
      <Button fullWidth variant="default" disabled>
        {t('teams.card.inviteOnly')}
      </Button>
    )
  }
  // A full free team refuses the join (BILL-10); a platform admin is exempt from the cap.
  if (isTeamFull(team) && !isPlatformAdmin) {
    return (
      <Button fullWidth variant="default" disabled>
        {t('teams.card.full')}
      </Button>
    )
  }
  if (!isAuthenticated) {
    return (
      <Button
        fullWidth
        component={PrefetchLink}
        to={paths.login()}
        state={{ from: { pathname: paths.team(team.slug), search: '' } }}
      >
        {t('teams.detail.actions.join')}
      </Button>
    )
  }
  return (
    <Button fullWidth onClick={join} disabled={isPending}>
      {isPending ? t('teams.detail.actions.joining') : t('teams.detail.actions.join')}
    </Button>
  )
}

interface TeamCardSkeletonProps {
  count?: number
}

export function TeamCardSkeleton({ count = 1 }: TeamCardSkeletonProps) {
  return (
    <CardSkeleton count={count} hasImage imageHeight="120px" hasLogo statCount={1} badgeCount={1} />
  )
}
