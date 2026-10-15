import { useState } from 'react'
import { useParams, Navigate, useNavigate, useLocation, useSearchParams } from 'react-router-dom'
import { useCanonicalPath } from '../../hooks/useCanonicalPath'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import i18next from 'i18next'
import { IconCopy } from '@tabler/icons-react'
import { Container, Stack, Group, Title, Text, Button } from '@mantine/core'
import { useCreateRideFormData } from '@/pages/ride/rideFormData'
import { useCreateRide } from '../../api/endpoints/rides/rides'
import { useGetTemplate } from '../../api/endpoints/ride-templates/ride-templates'
import { invalidateTeamPublications } from '@/lib/teamDashboardCache'
import { Status } from '@/api/dto'
import type { RideRequest, RideTemplateDto } from '@/api/dto'
import { LoadingPage } from '../../components/common/LoadingSpinner'
import { RideEditor } from '../../components/ride/RideEditor'
import { RideTemplatePickerModal } from '../../components/ridetemplate/RideTemplatePickerModal'
import { defaultMedia } from '@/lib/apiUtils'
import { paths } from '@/config/paths'
import { nextWeekdayWallTime } from '@/utils/wallTime'

export function CreateRidePage() {
  const { t } = useTranslation()
  const { teamSlug } = useParams<{ teamSlug: string }>()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const { team: teamQuery } = useCreateRideFormData(teamSlug)
  const { data: team, isLoading: isLoadingTeam } = teamQuery

  const createMutation = useCreateRide()

  const [showTemplateModal, setShowTemplateModal] = useState(false)
  const [editorKey, setEditorKey] = useState(0)
  // « Créer depuis un modèle » on the team dashboard hands the template over as router state; the
  // mobile dashboard, which opens this page in a browser and cannot carry router state, names it in
  // the URL instead (`?template=<slug>`, mobile `TeamWebPaths.rideNewFromTemplate`), and it is loaded.
  const location = useLocation()
  const stateTemplate = (location.state as { template?: RideTemplateDto } | null)?.template
  const [searchParams] = useSearchParams()
  const urlTemplateSlug = stateTemplate ? null : searchParams.get('template')
  const urlTemplate = useGetTemplate(teamSlug!, urlTemplateSlug ?? '', {
    query: { enabled: !!teamSlug && !!urlTemplateSlug, retry: false },
  })
  const [templateValues, setTemplateValues] = useState<RideTemplateDto | null>(() =>
    stateTemplate ? templateForNewRide(stateTemplate) : null
  )
  // The URL's template is applied once, when it arrives; a template picked afterwards wins.
  const [urlTemplateApplied, setUrlTemplateApplied] = useState(false)
  if (urlTemplate.data && !urlTemplateApplied) {
    setUrlTemplateApplied(true)
    if (!templateValues) {
      setTemplateValues(templateForNewRide(urlTemplate.data))
    }
  }

  useCanonicalPath(team ? paths.rideNew(team.slug) : undefined)

  // An empty form the template then fills would race the first keystrokes: wait for it. A template
  // that cannot be read (deleted, renamed) leaves the plain form.
  if (isLoadingTeam || (!!urlTemplateSlug && urlTemplate.isLoading)) {
    return <LoadingPage message={t('loading')} />
  }

  if (!team) {
    return <Navigate to={paths.teams()} replace />
  }

  if (!team.enableRides || !team.enableRoutes) {
    return <Navigate to={paths.team(teamSlug!)} replace />
  }

  const canCreate = team.role === 'ADMIN' || team.role === 'ORGANIZER'

  if (!canCreate) {
    return <Navigate to={paths.team(teamSlug!)} replace />
  }

  // Next Sunday at 08:00, a wall time of the team's zone: the SSR server and the browser compute the
  // same string, so the form hydrates without remounting (docs/LEDGER_*.md API-60).
  const getNextSunday = () => nextWeekdayWallTime(7, 8, team.timezone)

  // Prepare initial values - use template values if available
  const initialValues = templateValues
    ? {
        ...templateValues,
        media: {
          markdown: templateValues.markdown,
          assets: defaultMedia().assets,
        },
        dateTime: getNextSunday(),
        publishAt: undefined,
        routeSlug: undefined,
        // The template's tags are copied onto the ride, then editable like any other (plan D14).
        tagIds: templateValues.tags.map((tag) => tag.id),
      }
    : {
        name: '',
        media: defaultMedia(),
        dateTime: getNextSunday(),
        visibility: team.visibility,
        status: Status.DRAFT,
        publishAt: undefined,
        routeSlug: undefined,
        groups: [
          {
            name: t('rides.create.form.groups.defaultName', { number: 1 }),
            time: undefined,
            averageSpeed: undefined,
            maxParticipants: undefined,
            routeSlug: undefined,
            isNew: true,
          },
        ],
      }

  const handleTemplateSelect = (template: RideTemplateDto) => {
    setTemplateValues(templateForNewRide(template))
    setEditorKey((prev) => prev + 1)
    setShowTemplateModal(false)
  }

  const handleSubmit = (data: RideRequest) => {
    const filteredGroups = data.groups.filter((g) => g.name.trim())
    createMutation.mutate(
      {
        teamSlug: teamSlug!,
        data: {
          ...data,
          groups: filteredGroups,
          // Raises the template's number, if it has one, for the next ride (ledger API-108).
          templateId: templateValues?.id,
        },
      },
      {
        onSuccess: (ride) => {
          invalidateTeamPublications(queryClient, teamSlug!)
          notifications.show({ message: i18next.t('rides.notifications.created'), color: 'green' })
          navigate(paths.ride(teamSlug!, ride.slug))
        },
      }
    )
  }

  return (
    <Container size="sm" py="xl">
      <Stack>
        <Group justify="space-between" align="center">
          <Title order={1}>{t('rides.create.title')}</Title>
          <Button
            variant="light"
            leftSection={<IconCopy size={16} />}
            onClick={() => setShowTemplateModal(true)}
          >
            {t('rides.create.loadTemplate')}
          </Button>
        </Group>
        <Text c="dimmed">{t('rides.create.subtitle', { teamName: team.name })}</Text>
      </Stack>

      <RideEditor
        key={editorKey}
        team={team}
        teamSlug={teamSlug!}
        initialValues={initialValues}
        onSubmit={handleSubmit}
        onCancel={() => navigate(paths.team(teamSlug!))}
        isPending={createMutation.isPending}
        submitButtonText={t('rides.create.button')}
      />

      <RideTemplatePickerModal
        isOpen={showTemplateModal}
        onClose={() => setShowTemplateModal(false)}
        onSelect={handleTemplateSelect}
        teamSlug={teamSlug!}
      />
    </Container>
  )
}

/**
 * A template's values as a new ride starts from them: numbered « name #n » when the template counts
 * its rides (ledger API-108), with new groups routed nowhere.
 */
function templateForNewRide(template: RideTemplateDto): RideTemplateDto {
  return {
    ...template,
    name: template.nextNumber != null ? `${template.name} #${template.nextNumber}` : template.name,
    groups: template.groups.map((g) => ({
      ...g,
      routeSlug: undefined,
      isNew: true,
    })),
  }
}
