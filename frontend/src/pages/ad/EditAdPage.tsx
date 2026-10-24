import { useParams, Navigate, useNavigate } from 'react-router-dom'
import { invalidateTeamDashboard } from '@/lib/teamDashboardCache'
import { useCanonicalPath } from '../../hooks/useCanonicalPath'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import i18next from 'i18next'
import { Container, Stack, Title } from '@mantine/core'
import {
  useUpdateAd,
  useChangeAdSlug,
  getListAdsQueryKey,
  getGetAdQueryKey,
  getGetAdEditQueryKey,
} from '../../api/endpoints/ads/ads'
import { LoadingPage } from '../../components/common/LoadingSpinner'
import { AdEditor } from '../../components/ad/AdEditor'
import { paths } from '@/config/paths'
import { AdRequest } from '@/api/dto'
import { useEditAdFormData } from './adFormData'
import { useAuth } from '../../hooks/useAuth'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'
import { teamAccess } from '@/lib/teamAccess'

export function EditAdPage() {
  const { t } = useTranslation()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  const { teamSlug, adSlug } = useParams<{ teamSlug: string; adSlug: string }>()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const { user } = useAuth()
  const { team: teamQuery, ad: adQuery } = useEditAdFormData(teamSlug, adSlug)
  const { data: team, isLoading: isLoadingTeam } = teamQuery
  const { data: ad, isLoading: isLoadingAd } = adQuery

  const updateMutation = useUpdateAd()
  const changeSlugMutation = useChangeAdSlug()

  useCanonicalPath(team && ad ? paths.adEdit(team.slug, ad.slug) : undefined)

  // The module is off for this team: the API refuses every ad, so there is nothing to show here.
  if (team && !team.enableAds) {
    return <Navigate to={paths.team(team.slug)} replace />
  }

  if (isLoadingTeam || isLoadingAd) {
    return <LoadingPage message={t('loading')} />
  }

  if (!team || !ad) {
    return <Navigate to={paths.ads(teamSlug!)} replace />
  }

  // The author or a team admin, as AdAccessChecker enforces — or a platform admin.
  const isAdmin = teamAccess(team, isPlatformAdmin).isAdmin
  const canEdit = isAdmin || (!!user && ad.createdById === user.id)

  if (!canEdit) {
    return <Navigate to={paths.ad(teamSlug!, adSlug!)} replace />
  }

  const handleSubmit = (data: AdRequest) => {
    updateMutation.mutate(
      {
        teamSlug: teamSlug!,
        slug: adSlug!,
        data,
      },
      {
        onSuccess: () => {
          queryClient.invalidateQueries({ queryKey: getListAdsQueryKey(teamSlug!) })
          invalidateTeamDashboard(queryClient, teamSlug!)
          queryClient.invalidateQueries({ queryKey: getGetAdQueryKey(teamSlug!, adSlug!) })
          queryClient.invalidateQueries({ queryKey: getGetAdEditQueryKey(teamSlug!, adSlug!) })
          notifications.show({ message: i18next.t('ads.notifications.updated'), color: 'green' })
          navigate(paths.ad(teamSlug!, adSlug!))
        },
      }
    )
  }

  const handleSlugChange = async (newSlug: string) => {
    await changeSlugMutation.mutateAsync(
      { teamSlug: teamSlug!, slug: adSlug!, data: { slug: newSlug } },
      {
        onSuccess: (updatedAd) => {
          queryClient.invalidateQueries({ queryKey: getListAdsQueryKey(teamSlug!) })
          invalidateTeamDashboard(queryClient, teamSlug!)
          queryClient.invalidateQueries({ queryKey: getGetAdQueryKey(teamSlug!, adSlug!) })
          queryClient.invalidateQueries({ queryKey: getGetAdEditQueryKey(teamSlug!, adSlug!) })
          // Navigate to the new slug URL
          navigate(paths.adEdit(teamSlug!, updatedAd.slug), { replace: true })
        },
      }
    )
  }

  // Prepare initial values from fetched ad data
  const initialValues = {
    ...ad,
    tagIds: ad.tags.map((tag) => tag.id),
  }

  return (
    <Container size="sm" py="xl">
      <Stack gap="xs">
        <Title order={1}>{t('ads.edit.title')}</Title>
      </Stack>

      <AdEditor
        teamSlug={teamSlug!}
        initialValues={initialValues}
        onSubmit={handleSubmit}
        onCancel={() => navigate(paths.ad(teamSlug!, adSlug!))}
        isPending={updateMutation.isPending}
        submitButtonText={t('actions.save')}
        currentSlug={adSlug!}
        onSlugChange={handleSlugChange}
        canEditSlug={isAdmin}
      />
    </Container>
  )
}
