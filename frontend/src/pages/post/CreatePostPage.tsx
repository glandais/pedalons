import { useParams, Navigate, useNavigate } from 'react-router-dom'
import { useCanonicalPath } from '../../hooks/useCanonicalPath'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import { Container, Stack, Title } from '@mantine/core'
import { useCreatePost } from '../../api/endpoints/posts/posts'
import { invalidateTeamPublications } from '@/lib/teamDashboardCache'
import { LoadingPage } from '../../components/common/LoadingSpinner'
import { PostEditor } from '../../components/post/PostEditor'
import { defaultMedia } from '@/lib/apiUtils'
import { paths } from '@/config/paths'
import { PostRequest, Status } from '../../api/dto'
import { useCreatePostFormData } from './postFormData'
import { instantToWallTime } from '@/utils/wallTime'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'
import { teamAccess } from '@/lib/teamAccess'

export function CreatePostPage() {
  const { t } = useTranslation()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  const { teamSlug } = useParams<{ teamSlug: string }>()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const {
    team: { data: team, isLoading: isLoadingTeam },
  } = useCreatePostFormData(teamSlug)

  const createMutation = useCreatePost()

  useCanonicalPath(team ? paths.postNew(team.slug) : undefined)

  if (isLoadingTeam) {
    return <LoadingPage message={t('loading')} />
  }

  if (!team || !teamSlug) {
    return <Navigate to={paths.teams()} replace />
  }

  if (!team.enablePosts) {
    return <Navigate to={paths.team(teamSlug!)} replace />
  }

  const canCreate = teamAccess(team, isPlatformAdmin).isOrganizer

  if (!canCreate) {
    return <Navigate to={paths.team(teamSlug!)} replace />
  }

  // Prepare initial values for create mode
  const initialValues: PostRequest = {
    name: '',
    media: defaultMedia(),
    // Now, as the clock reads in the team's zone — a post's zone (docs/LEDGER_*.md API-60).
    dateTime: instantToWallTime(new Date(), team.timezone),
    visibility: team.visibility,
    status: Status.DRAFT,
    publishAt: undefined,
    // The team decides how a post starts out signed; the author may change it (docs/LEDGER_*.md API-6)
    signedAsTeam: team.postsAsTeamByDefault,
  }

  const handleSubmit = (data: PostRequest) => {
    createMutation.mutate(
      {
        teamSlug: teamSlug!,
        data,
      },
      {
        onSuccess: (post) => {
          invalidateTeamPublications(queryClient, teamSlug!)
          notifications.show({ message: t('posts.notifications.created'), color: 'green' })
          navigate(paths.post(teamSlug!, post.slug))
        },
      }
    )
  }

  return (
    <Container size="sm" py="xl">
      <Stack gap="xs">
        <Title order={1}>{t('posts.create.title')}</Title>
      </Stack>

      <PostEditor
        team={team}
        teamSlug={teamSlug!}
        initialValues={initialValues}
        onSubmit={handleSubmit}
        onCancel={() => navigate(paths.team(teamSlug!))}
        isPending={createMutation.isPending}
        submitButtonText={t('posts.create.submit')}
      />
    </Container>
  )
}
