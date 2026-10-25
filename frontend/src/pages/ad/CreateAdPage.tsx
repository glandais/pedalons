import { useParams, Navigate, useNavigate } from 'react-router-dom'
import { invalidateTeamDashboard } from '@/lib/teamDashboardCache'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import i18next from 'i18next'
import { Container, Stack, Title } from '@mantine/core'
import { useCreateAd, getListAdsQueryKey } from '../../api/endpoints/ads/ads'
import { LoadingPage } from '../../components/common/LoadingSpinner'
import { AdEditor } from '../../components/ad/AdEditor'
import { defaultMedia } from '@/lib/apiUtils'
import { paths } from '@/config/paths'
import { AdRequest, AdType, Status } from '../../api/dto'
import { useCanonicalPath } from '../../hooks/useCanonicalPath'
import { useCreateAdFormData } from './adFormData'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'

export function CreateAdPage() {
  const { t } = useTranslation()
  const { teamSlug } = useParams<{ teamSlug: string }>()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const { team: teamQuery } = useCreateAdFormData(teamSlug)
  const { data: team, isLoading: isLoadingTeam } = teamQuery

  const createMutation = useCreateAd()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)

  useCanonicalPath(team ? paths.adNew(team.slug) : undefined)

  if (isLoadingTeam) {
    return <LoadingPage message={t('loading')} />
  }

  if (!team || !teamSlug) {
    return <Navigate to={paths.teams()} replace />
  }

  // The module is off for this team: the API refuses every ad, so there is nothing to show here.
  if (team && !team.enableAds) {
    return <Navigate to={paths.team(team.slug)} replace />
  }

  // Any member can create ads, and a platform admin, whose `team.role` is their real membership
  // (docs/LEDGER_*.md API-137)
  const canCreate = !!team.role || isPlatformAdmin

  if (!canCreate) {
    return <Navigate to={paths.ads(teamSlug!)} replace />
  }

  // Prepare initial values for create mode
  const initialValues = {
    name: '',
    media: defaultMedia(),
    dateTime: new Date().toISOString(),
    status: Status.DRAFT,
    adType: AdType.SALE,
    price: undefined,
    rentalPeriod: undefined,
    latitude: undefined,
    longitude: undefined,
    locationDescription: '',
  }

  const handleSubmit = (data: AdRequest) => {
    createMutation.mutate(
      {
        teamSlug: teamSlug!,
        data,
      },
      {
        onSuccess: (ad) => {
          queryClient.invalidateQueries({ queryKey: getListAdsQueryKey(teamSlug!) })
          invalidateTeamDashboard(queryClient, teamSlug!)
          notifications.show({ message: i18next.t('ads.notifications.created'), color: 'green' })
          navigate(paths.ad(teamSlug!, ad.slug))
        },
      }
    )
  }

  return (
    <Container size="sm" py="xl">
      <Stack gap="xs">
        <Title order={1}>{t('ads.create.title')}</Title>
      </Stack>

      <AdEditor
        teamSlug={teamSlug!}
        initialValues={initialValues}
        onSubmit={handleSubmit}
        onCancel={() => navigate(paths.ads(teamSlug!))}
        isPending={createMutation.isPending}
        submitButtonText={t('ads.create.submit')}
      />
    </Container>
  )
}
