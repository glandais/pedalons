import { useNavigate } from 'react-router-dom'
import { invalidateTeamDashboard, invalidateTeamEventTimes } from '@/lib/teamDashboardCache'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { useForm } from '@mantine/form'
import { zodFormValidator } from '@/lib/formUtils'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import i18next from 'i18next'
import { useEffect, useState } from 'react'
import {
  TextInput,
  Select,
  Checkbox,
  Switch,
  Button,
  Group,
  Stack,
  Text,
  Divider,
  Title,
  Badge,
  Loader,
} from '@mantine/core'
import {
  useCreateTeam,
  useUpdateTeam,
  getListTeamsQueryKey,
  getGetTeamQueryKey,
  usePreviewTeamTimezoneChange,
} from '@/api/endpoints/teams/teams'
import { useAdminUpdateTeamAttributes } from '@/api/endpoints/admin-teams/admin-teams'
import { SlugEditor } from '../common/SlugEditor'
import { Visibility, TeamDetailDto, TeamRequest, GeoJsonPoint } from '@/api/dto'
import { MediaEditor } from '../common/MediaEditor'
import { GeocoderAutocomplete } from '../common/GeocoderAutocomplete'
import { paths } from '@/config/paths'
import { CreateTeamBody } from '@/api/zod/teams/teams.zod'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'
import { TimezoneSelect } from '../common/TimezoneSelect'
import { ConfirmDialog } from '../common/ConfirmDialog'
import { TimezoneChangePreview } from './TimezoneChangePreview'
import { useBrowserTimezone } from '@/utils/timezones'

const teamSchema = CreateTeamBody

interface TeamFormProps {
  teamSlug?: string
  teamId?: string
  initialValues: TeamRequest & {
    visibilityEditable?: boolean
    joinable?: boolean
    addMemberAllowed?: boolean
    enableRoutePlanner?: boolean
  }
  onSuccess: (team: TeamDetailDto) => void
  create: boolean
  onSlugChange?: (newSlug: string) => Promise<void>
}

export function TeamForm({
  teamSlug,
  teamId,
  initialValues,
  onSuccess,
  create,
  onSlugChange,
}: TeamFormProps) {
  const { t } = useTranslation()
  const queryClient = useQueryClient()
  const navigate = useNavigate()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  const [visibilityEditable, setVisibilityEditable] = useState(
    initialValues.visibilityEditable ?? false
  )
  const [joinable, setJoinable] = useState(initialValues.joinable ?? false)
  // A picked place whose position is still being looked up (docs/LEDGER_*.md API-129).
  const [geocoding, setGeocoding] = useState(false)
  const [addMemberAllowed, setAddMemberAllowed] = useState(initialValues.addMemberAllowed ?? false)
  const [enableRoutePlanner, setEnableRoutePlanner] = useState(
    initialValues.enableRoutePlanner ?? false
  )

  const createMutation = useCreateTeam()
  const updateMutation = useUpdateTeam()
  const adminAttrsMutation = useAdminUpdateTeamAttributes()
  const mutation = teamSlug ? updateMutation : createMutation

  function getSubmitButtonText(): string {
    if (mutation.isPending) {
      return create ? t('status.creating') : t('status.saving')
    }
    return create ? t('teams.create.button') : t('actions.save')
  }

  const form = useForm<TeamRequest>({
    validate: zodFormValidator<TeamRequest>(teamSchema),
    initialValues,
    validateInputOnChange: true,
  })

  // A new team starts in its creator's zone (plan §2.1), set once hydrated: useForm reads its
  // initial values only once, and the server rendering the page does not know the browser's zone.
  // Left empty when unknown, the backend falls back to Europe/Paris (docs/LEDGER_*.md API-60).
  const browserZone = useBrowserTimezone()
  const { setFieldValue } = form
  const timezoneValue = form.values.timezone
  useEffect(() => {
    if (create && browserZone && !timezoneValue) setFieldValue('timezone', browserZone)
  }, [create, browserZone, timezoneValue, setFieldValue])

  // A change of zone moves the team's upcoming place-less rendezvous at constant wall time (plan
  // §9): the backend lists them, the admin confirms before saving (docs/LEDGER_*.md API-60).
  const zoneChanged =
    !create && !!teamSlug && !!timezoneValue && timezoneValue !== initialValues.timezone
  const [pendingValues, setPendingValues] = useState<TeamRequest | null>(null)
  const preview = usePreviewTeamTimezoneChange(
    teamSlug ?? '',
    { timezone: timezoneValue ?? '' },
    { query: { enabled: zoneChanged, retry: false } }
  )

  const handleSubmit = (values: TeamRequest) => {
    if (geocoding) return
    if (zoneChanged) {
      // A preview that failed is cached in error under the same key: ask again rather than reopen
      // on the same error with Confirm disabled.
      if (preview.isError && !preview.isFetching) void preview.refetch()
      setPendingValues(values)
      return
    }
    save(values)
  }

  const save = (values: TeamRequest) => {
    if (create) {
      createMutation.mutate(
        { data: values },
        {
          onSuccess: (team) => {
            queryClient.invalidateQueries({ queryKey: getListTeamsQueryKey() })
            notifications.show({
              message: i18next.t('teams.notifications.created'),
              color: 'green',
            })
            onSuccess(team)
            navigate(paths.team(team.slug))
          },
        }
      )
    } else if (teamSlug) {
      updateMutation.mutate(
        { teamSlug, data: values },
        {
          onSuccess: (team) => {
            queryClient.invalidateQueries({ queryKey: getGetTeamQueryKey(teamSlug) })
            invalidateTeamDashboard(queryClient, teamSlug)
            // The backend rewrote the instants of the team's place-less rendezvous.
            if (values.timezone !== initialValues.timezone) {
              invalidateTeamEventTimes(queryClient, teamSlug)
            }
            queryClient.invalidateQueries({ queryKey: getListTeamsQueryKey() })
            queryClient.setQueryData(getGetTeamQueryKey(team.slug), team)
            if (isPlatformAdmin && teamId) {
              adminAttrsMutation.mutate(
                {
                  teamId,
                  data: { visibilityEditable, joinable, addMemberAllowed, enableRoutePlanner },
                },
                {
                  onSuccess: () => {
                    queryClient.invalidateQueries({ queryKey: getGetTeamQueryKey(team.slug) })
                    invalidateTeamDashboard(queryClient, team.slug)
                    notifications.show({
                      message: i18next.t('teams.notifications.updated'),
                      color: 'green',
                    })
                    onSuccess(team)
                    navigate(paths.team(team.slug))
                  },
                  onError: () => {
                    notifications.show({
                      message: i18next.t('teams.notifications.governanceUpdateFailed'),
                      color: 'red',
                    })
                  },
                }
              )
            } else {
              notifications.show({
                message: i18next.t('teams.notifications.updated'),
                color: 'green',
              })
              onSuccess(team)
              navigate(paths.team(team.slug))
            }
          },
        }
      )
    }
  }

  return (
    <form onSubmit={form.onSubmit(handleSubmit)}>
      <Stack>
        <TextInput
          label={
            <>
              {t('teams.create.form.name.label')}
              {create && (
                <Text span c="red">
                  {' '}
                  *
                </Text>
              )}
            </>
          }
          placeholder={create ? t('teams.create.form.name.placeholder') : undefined}
          {...form.getInputProps('name')}
        />

        {!create && teamSlug && onSlugChange && (
          <SlugEditor currentSlug={teamSlug} baseUrl={paths.team('')} onSlugChange={onSlugChange} />
        )}

        <Stack gap="xs">
          <Text size="sm" fw={500}>
            {t('form.description')}
          </Text>
          <MediaEditor
            value={form.values.media}
            onChange={(val) => form.setFieldValue('media', val)}
            placeholder={t('teams.create.form.description.placeholder')}
            minHeight="150px"
            disabled={mutation.isPending}
            ariaLabel={t('teams.create.form.description.placeholder')}
            teamSlug={teamSlug}
          />
          <Text size="xs" c="dimmed">
            {t('form.charCount', {
              count: form.values.media.markdown.length || 0,
              max: 2000,
            })}
          </Text>
        </Stack>

        <GeocoderAutocomplete
          value={form.values.geometry as GeoJsonPoint | null | undefined}
          onChange={(point) => form.setFieldValue('geometry', point ?? undefined)}
          label={t('geocoder.label')}
          disabled={mutation.isPending}
          onResolvingChange={setGeocoding}
        />

        <TimezoneSelect
          label={t('teams.create.form.timezone.label')}
          description={t('teams.create.form.timezone.hint')}
          value={timezoneValue}
          onChange={(zone) => {
            if (zone) form.setFieldValue('timezone', zone)
          }}
          disabled={mutation.isPending}
          error={form.errors.timezone}
        />

        <Checkbox
          label={t('teams.create.form.enableRoutes.label')}
          description={t('teams.create.form.enableRoutes.hint')}
          {...form.getInputProps('enableRoutes', { type: 'checkbox' })}
          onChange={(e) => {
            form.getInputProps('enableRoutes', { type: 'checkbox' }).onChange(e)
            if (!e.currentTarget.checked) {
              form.setFieldValue('enableRides', false)
              form.setFieldValue('enableTrips', false)
            }
          }}
        />

        <Checkbox
          label={t('teams.create.form.enableRides.label')}
          description={t('teams.create.form.enableRides.hint')}
          {...form.getInputProps('enableRides', { type: 'checkbox' })}
          disabled={!form.values.enableRoutes}
        />

        <Checkbox
          label={t('teams.create.form.enableTrips.label')}
          description={t('teams.create.form.enableTrips.hint')}
          {...form.getInputProps('enableTrips', { type: 'checkbox' })}
          disabled={!form.values.enableRoutes}
        />

        <Checkbox
          label={t('teams.create.form.enablePosts.label')}
          description={t('teams.create.form.enablePosts.hint')}
          {...form.getInputProps('enablePosts', { type: 'checkbox' })}
        />

        <Checkbox
          label={t('teams.create.form.enableAds.label')}
          description={t('teams.create.form.enableAds.hint')}
          {...form.getInputProps('enableAds', { type: 'checkbox' })}
        />

        {/* Off by default, unlike every other enable_* flag: turning it on shows the whole roster
            to every member, so it is an act the team takes rather than one a migration takes for
            it. Organisers see the directory either way — they need it to pick a group leader. */}
        <Checkbox
          label={t('teams.create.form.enableMemberDirectory.label')}
          description={t('teams.create.form.enableMemberDirectory.hint')}
          {...form.getInputProps('enableMemberDirectory', { type: 'checkbox' })}
        />

        {/* Where a new post's « on behalf of the team » box starts; each post keeps its own value
            (docs/LEDGER_*.md API-6). On unless the team chooses to show its authors. */}
        <Checkbox
          label={t('teams.create.form.postsAsTeamByDefault.label')}
          description={t('teams.create.form.postsAsTeamByDefault.hint')}
          {...form.getInputProps('postsAsTeamByDefault', { type: 'checkbox' })}
          disabled={!form.values.enablePosts}
        />

        {!create && (
          <>
            <Divider mt="md" />
            <Stack gap="xs">
              <Title order={4}>{t('teams.settings.platformAdmin.title')}</Title>

              {initialValues.visibilityEditable || isPlatformAdmin ? (
                <Select
                  label={t('teams.create.form.visibility.label')}
                  description={t('teams.create.form.visibility.hint')}
                  data={[
                    { value: Visibility.TEAM, label: t('visibility.team') },
                    { value: Visibility.PUBLIC_UNLISTED, label: t('visibility.public_unlisted') },
                    { value: Visibility.PUBLIC, label: t('visibility.public') },
                  ]}
                  {...form.getInputProps('visibility')}
                />
              ) : (
                <Group gap="xs">
                  <Text size="sm" fw={500}>
                    {t('teams.create.form.visibility.label')}
                  </Text>
                  <Badge variant="light">
                    {
                      {
                        [Visibility.TEAM]: t('visibility.team'),
                        [Visibility.PUBLIC_UNLISTED]: t('visibility.public_unlisted'),
                        [Visibility.PUBLIC]: t('visibility.public'),
                      }[form.values.visibility]
                    }
                  </Badge>
                </Group>
              )}

              <Switch
                label={t('teams.settings.platformAdmin.visibilityEditable')}
                checked={visibilityEditable}
                disabled={!isPlatformAdmin || !teamId}
                onChange={(e) => setVisibilityEditable(e.currentTarget.checked)}
              />
              <Switch
                label={t('teams.settings.platformAdmin.joinable')}
                checked={joinable}
                disabled={!isPlatformAdmin || !teamId}
                onChange={(e) => setJoinable(e.currentTarget.checked)}
              />
              <Switch
                label={t('teams.settings.platformAdmin.addMemberAllowed')}
                checked={addMemberAllowed}
                disabled={!isPlatformAdmin || !teamId}
                onChange={(e) => setAddMemberAllowed(e.currentTarget.checked)}
              />
              <Switch
                label={t('teams.settings.platformAdmin.enableRoutePlanner')}
                description={t('teams.settings.platformAdmin.enableRoutePlannerHint')}
                checked={enableRoutePlanner}
                disabled={!isPlatformAdmin || !teamId}
                onChange={(e) => setEnableRoutePlanner(e.currentTarget.checked)}
              />
            </Stack>
          </>
        )}

        <Group justify="flex-end" pt="md">
          <Button
            variant="default"
            component={PrefetchLink}
            to={create ? paths.teams() : paths.team(teamSlug!)}
          >
            {t('actions.cancelAction')}
          </Button>
          <Button
            type="submit"
            disabled={mutation.isPending || geocoding || !form.isValid()}
            loading={mutation.isPending}
          >
            {getSubmitButtonText()}
          </Button>
        </Group>
      </Stack>

      <ConfirmDialog
        isOpen={!!pendingValues}
        onClose={() => setPendingValues(null)}
        onConfirm={() => {
          if (pendingValues) save(pendingValues)
          setPendingValues(null)
        }}
        title={t('teams.settings.timezoneChange.title')}
        message={
          preview.data ? (
            <TimezoneChangePreview preview={preview.data} />
          ) : preview.isError && !preview.isFetching ? (
            <Stack gap="xs" align="flex-start">
              <Text size="sm">{t('teams.settings.timezoneChange.error')}</Text>
              <Button size="xs" variant="light" onClick={() => void preview.refetch()}>
                {t('generic.retry')}
              </Button>
            </Stack>
          ) : (
            <Loader size="sm" />
          )
        }
        confirmText={t('teams.settings.timezoneChange.confirm')}
        confirmDisabled={!preview.data || preview.isFetching}
        isLoading={mutation.isPending}
      />
    </form>
  )
}
