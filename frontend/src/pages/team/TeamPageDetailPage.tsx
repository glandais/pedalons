import { useParams, Navigate } from 'react-router-dom'
import { useCanonicalPath } from '../../hooks/useCanonicalPath'
import { useTranslation } from 'react-i18next'
import { paths } from '../../config/paths'
import { Box, Container, Group, Paper, Text, Title } from '@mantine/core'
import { LoadingPage } from '../../components/common/LoadingSpinner'
import { TeamLayout } from '../../components/team/TeamLayout'
import { TeamContextBanner } from '../../components/team/TeamContextBanner'
import { MediaDisplay } from '../../components/common/MediaDisplay'
import { VisibilityBadge } from '../../components/card/common'
import type { TeamPageDto } from '@/api/dto'
import { useTeamPageData } from './teamPageData'

/** The page itself, in the team's layout or on its own. */
function PageContent({ page, showBadge }: { page: TeamPageDto; showBadge: boolean }) {
  const { t } = useTranslation()
  return (
    <Paper p="lg" withBorder>
      <Group gap="sm" mb="md">
        <Title order={2}>{page.title}</Title>
        {page.visibility === 'TEAM' && showBadge && (
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
  )
}

export function TeamPageDetailPage() {
  const { teamSlug, pageSlug } = useParams<{ teamSlug: string; pageSlug: string }>()

  const { team: teamQuery, page: pageQuery } = useTeamPageData(teamSlug, pageSlug)
  const { data: team, isLoading: isTeamLoading } = teamQuery
  const { data: page, isLoading: isPageLoading } = pageQuery

  const { t } = useTranslation()

  useCanonicalPath(page ? paths.teamPage(page.team.slug, page.slug) : undefined)

  if (isTeamLoading || isPageLoading) {
    return <LoadingPage message={t('loading')} />
  }

  // The team is only read once the page says it is open, so it is rarely there on a failed page:
  // the team's home decides on its own whether the reader may see it.
  if (!page) {
    return <Navigate to={teamSlug ? paths.team(teamSlug) : paths.teams()} replace />
  }

  // A private team's public page, read by link (docs/LEDGER_*.md WEB-166): no team to lay it out
  // in — `GET team` is closed to the reader —, the page on its own under the team's name.
  if (!page.team.accessible || !team) {
    return (
      <Container size="md" py="xl">
        <TeamContextBanner team={page.team} />
        <PageContent page={page} showBadge={false} />
      </Container>
    )
  }

  return (
    <TeamLayout team={team} currentTab={page.slug} onCustomPage>
      <Box py="md">
        {/* The badge tells who else reads the page; a « Équipe » page only reaches its members and a
            platform admin, so no role needs reading for it (docs/LEDGER_*.md WEB-166). */}
        <PageContent page={page} showBadge />
      </Box>
    </TeamLayout>
  )
}
