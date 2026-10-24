import { useParams, Navigate } from 'react-router-dom'
import { useCanonicalPath } from '../../hooks/useCanonicalPath'
import { useTranslation } from 'react-i18next'
import { paths } from '../../config/paths'
import { Box, Group, Paper, Text, Title } from '@mantine/core'
import { LoadingPage } from '../../components/common/LoadingSpinner'
import { TeamLayout } from '../../components/team/TeamLayout'
import { MediaDisplay } from '../../components/common/MediaDisplay'
import { VisibilityBadge } from '../../components/card/common'
import { useTeamPageData } from './teamPageData'

export function TeamPageDetailPage() {
  const { teamSlug, pageSlug } = useParams<{ teamSlug: string; pageSlug: string }>()

  const { team: teamQuery, page: pageQuery } = useTeamPageData(teamSlug, pageSlug)
  const { data: team, isLoading: isTeamLoading } = teamQuery
  const { data: page, isLoading: isPageLoading } = pageQuery

  const { t } = useTranslation()

  useCanonicalPath(team && page ? paths.teamPage(team.slug, page.slug) : undefined)

  if (isTeamLoading || isPageLoading) {
    return <LoadingPage message={t('loading')} />
  }

  if (!team) {
    return <Navigate to={paths.teams()} replace />
  }

  if (!page) {
    return <Navigate to={paths.team(team.slug)} replace />
  }

  const isMember = !!team.role

  return (
    <TeamLayout team={team} currentTab={page.slug} onCustomPage>
      <Box py="md">
        <Paper p="lg" withBorder>
          <Group gap="sm" mb="md">
            <Title order={2}>{page.title}</Title>
            {page.visibility === 'TEAM' && isMember && (
              <VisibilityBadge visibility={page.visibility} />
            )}
          </Group>

          {/* Page Content */}
          <Box>
            <MediaDisplay media={page.media} />
            {!page.media?.markdown && (
              <Text c="dimmed" fs="italic">
                {t('teams.pages.noContent')}
              </Text>
            )}
          </Box>
        </Paper>
      </Box>
    </TeamLayout>
  )
}
