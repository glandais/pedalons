import { useTranslation } from 'react-i18next'
import { IconUsers } from '@tabler/icons-react'
import { Group, Box } from '@mantine/core'
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

  return (
    <Card to={paths.team(team.slug)}>
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

interface TeamCardSkeletonProps {
  count?: number
}

export function TeamCardSkeleton({ count = 1 }: TeamCardSkeletonProps) {
  return (
    <CardSkeleton count={count} hasImage imageHeight="120px" hasLogo statCount={1} badgeCount={1} />
  )
}
