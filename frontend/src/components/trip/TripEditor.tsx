import { VisibilitySelector } from '@/components/visibility/VisibilitySelector'
import { allowedVisibilitiesFor } from '@/components/visibility/visibilityLabels'
import { Visibility } from '@/api/dto'
import { useState, useEffect, useMemo, useRef } from 'react'
import { useQueries } from '@tanstack/react-query'
import { useForm } from '@mantine/form'
import { zodFormValidator } from '@/lib/formUtils'
import { useTranslation } from 'react-i18next'
import { useUnits } from '@/hooks/useUnits'
import {
  TextInput,
  Radio,
  Stack,
  Group,
  Button,
  Text,
  Paper,
  SimpleGrid,
  Tabs,
  Badge,
  NumberInput,
} from '@mantine/core'
import { WallDateTimePicker } from '@/components/common/WallDateTimePicker'
import { IconPlus, IconTrash, IconSettings, IconRoute as IconRouteIcon } from '@tabler/icons-react'
import { SlugEditor } from '../common/SlugEditor'
import { paths } from '@/config/paths'
import { ReorderControls } from '../common/ReorderControls'
import { RoutePickerModal } from '../route/RoutePickerModal'
import { CreateRouteModal } from '../route/CreateRouteModal'
import { RoutePreview } from '../route/RoutePreview'
import { RoutePreviewCompact } from '../route/RoutePreviewCompact'
import { MediaEditor } from '../common/MediaEditor'
import { PlaceAutocomplete } from '../common/PlaceAutocomplete'
import { useRoutesBulk } from '@/hooks/useRoutesBulk'
import type { RouteDto, RouteDetailDto, TeamDetailDto, TripRequest } from '@/api/dto'
import { Status } from '@/api/dto'
import { defaultMedia } from '@/lib/apiUtils'
import { CreateTripBody } from '@/api/zod/trips/trips.zod'
import { TagPicker } from '@/components/tag'
import { getGetPlaceQueryOptions } from '@/api/endpoints/places/places'
import { useGetRoute } from '@/api/endpoints/routes/routes'
import {
  chainCandidate,
  useLastKnown,
  useZoneResolver,
  zoneSource,
  type ZoneResolution,
} from '@/hooks/useEventTimezone'
import { addDaysToWallTime, instantToWallTime, wallTimeToInstant } from '@/utils/wallTime'

interface TripEditorProps {
  team: TeamDetailDto
  /**
   * The visibilities this content may take, from the entity being edited
   * (`permissions.allowedVisibilities`); the team's list for its kind when absent (creation).
   */
  allowedVisibilities?: Visibility[]
  teamSlug: string
  initialValues: TripRequest
  onSubmit: (data: TripRequest) => void | Promise<void>
  onCancel: () => void
  isPending: boolean
  submitButtonText?: string
  cancelButtonText?: string
  currentSlug?: string
  onSlugChange?: (newSlug: string) => Promise<void>
  canEditSlug?: boolean
  /**
   * The zone the API gave the trip being edited (`TripDto.timezone`), which its wall times were
   * converted in; absent on creation.
   */
  timezone?: string
  /** Each edited stage's zone (`TripStageDto.timezone`), keyed by stage id. */
  stageTimezones?: Record<string, string>
}

type Target = { type: 'stage'; index: number } | { type: 'trip' }

export function TripEditor({
  team,
  allowedVisibilities,
  teamSlug,
  initialValues,
  onSubmit,
  onCancel,
  isPending,
  submitButtonText,
  cancelButtonText,
  currentSlug,
  onSlugChange,
  canEditSlug = false,
  timezone,
  stageTimezones,
}: TripEditorProps) {
  const { t } = useTranslation()

  const [activeTab, setActiveTab] = useState<string>('details')
  const [showRoutePickerModal, setShowRoutePickerModal] = useState(false)
  const [showCreateRouteModal, setShowCreateRouteModal] = useState(false)
  const [pickerTarget, setPickerTarget] = useState<Target | null>(null)

  // The trip's zone, read by the validator below: useForm keeps the validator it was given first.
  const tripZoneRef = useRef(timezone ?? team.timezone)

  const tripSchema = useMemo(
    () =>
      CreateTripBody.refine(
        (data) => {
          if (data.status === Status.DRAFT && data.publishAt) {
            // A wall time of the trip's zone, not the browser's (docs/LEDGER_*.md API-60).
            return wallTimeToInstant(data.publishAt, tripZoneRef.current) > new Date()
          }
          return true
        },
        {
          message: t('form.publishAt.futureRequired'),
          path: ['publishAt'],
        }
      ),
    [t]
  )

  const { config, speedToDisplay, speedFromDisplay } = useUnits()

  const form = useForm<TripRequest>({
    validate: zodFormValidator<TripRequest>(tripSchema),
    initialValues,
    validateInputOnChange: true,
  })

  const status = form.values.status
  const dateTime = form.values.dateTime
  const stages = form.values.stages
  const routeSlug = form.values.routeSlug

  // One bulk request for every stage's route preview, instead of one `getRoute` per stage —
  // stages frequently share the same route. The key string is memoized on the slugs' own
  // values (not the `stages` array reference, which mantine's `useForm` may recreate on
  // unrelated field edits) so the request stays stable across renders that don't touch routes.
  const stageRouteSlugsKey = stages
    .map((s) => s.routeSlug)
    .filter((s): s is string => !!s)
    .sort()
    .join(',')
  const stageRouteSlugs = useMemo(
    () => (stageRouteSlugsKey ? Array.from(new Set(stageRouteSlugsKey.split(','))) : []),
    [stageRouteSlugsKey]
  )
  const {
    data: stageRoutesBulk,
    isLoading: isLoadingStageRoutes,
    isFetching: isFetchingStageRoutes,
    failedSlugs: failedStageRouteSlugs,
  } = useRoutesBulk(teamSlug, {
    // Only the name, distance and elevation gain are shown — ask for no geometry at all rather
    // than downloading each stage's track to throw it away.
    slug: stageRouteSlugs,
    geometry: false,
  })
  const stageRoutesBySlug = useMemo(() => {
    const map = new Map<string, RouteDetailDto>()
    for (const route of stageRoutesBulk?.routes ?? []) {
      map.set(route.slug, route)
    }
    return map
  }, [stageRoutesBulk])
  // `useRoutesBulk` keeps previous data while the slug set changes, so `isLoadingStageRoutes`
  // alone would only be true on first mount — picking a new route for one stage must still show
  // a spinner for THAT row rather than briefly rendering nothing (no match in `stageRoutesBySlug`
  // yet) or stale data for a different route. Rows whose slug is already resolved keep rendering
  // from the previous data untouched. A slug whose chunk failed (`failedStageRouteSlugs`) is never
  // "loading" — even while another chunk is still in flight — so its row falls through to
  // `RoutePreviewCompact`'s "not found" state instead of spinning forever.
  const isStageRouteLoading = (slug: string | undefined) =>
    !!slug &&
    !stageRoutesBySlug.has(slug) &&
    !failedStageRouteSlugs.has(slug) &&
    (isLoadingStageRoutes || isFetchingStageRoutes)

  // Each stage's zone, and the trip's, for the « heure de … » mention of the date fields
  // (docs/LEDGER_*.md API-60, plan §4). A stage: its start place, else its route's start, else the
  // previous stage's zone, else the trip route's start, else the team. The trip: its first stage's,
  // else its route's, else the team. Derived on every render rather than held per stage, so that
  // reordering, inserting or removing a stage re-chains the inheritance.
  //
  // One place query per distinct start place (the cache PlaceAutocomplete fills), the stage routes'
  // starts from the bulk query above, the trip route from RoutePreview's cache.
  const stagePlaceIdsKey = Array.from(
    new Set(stages.map((s) => s.startPlaceId).filter((id): id is string => !!id))
  )
    .sort()
    .join(',')
  const stagePlaceIds = useMemo(
    () => (stagePlaceIdsKey ? stagePlaceIdsKey.split(',') : []),
    [stagePlaceIdsKey]
  )
  const stagePlaceQueries = useQueries({
    queries: stagePlaceIds.map((id) => getGetPlaceQueryOptions(teamSlug, id)),
  })
  const tripRoute = useGetRoute(teamSlug, routeSlug ?? '', { query: { enabled: !!routeSlug } })

  const stageCandidates = stages.map((stage) => {
    const placeIndex = stage.startPlaceId ? stagePlaceIds.indexOf(stage.startPlaceId) : -1
    const place = placeIndex >= 0 ? stagePlaceQueries[placeIndex] : undefined
    const route = stage.routeSlug ? stageRoutesBySlug.get(stage.routeSlug) : undefined
    return chainCandidate([
      zoneSource(stage.startPlaceId && `place:${stage.startPlaceId}`, {
        loaded: !!place?.data,
        point: place?.data?.geometry,
        failed: place?.isError,
      }),
      zoneSource(stage.routeSlug && `route:${stage.routeSlug}`, {
        loaded: !!route,
        point: route?.start,
        failed: !!stage.routeSlug && failedStageRouteSlugs.has(stage.routeSlug),
      }),
    ])
  })
  const tripRouteCandidate = chainCandidate([
    zoneSource(routeSlug && `route:${routeSlug}`, {
      loaded: !!tripRoute.data,
      point: tripRoute.data?.start,
      failed: tripRoute.isError,
    }),
  ])
  // The trip route only counts when the first stage has neither place nor route.
  const needsTripRoute = stageCandidates.length === 0 || stageCandidates[0] === null
  // An edited trip already has its zones: each source that located a stage (or the trip) is seeded
  // with it, so nothing is asked until the organiser picks another place or route.
  const [zoneSeeds] = useState<Record<string, string>>(() => {
    const seeds: Record<string, string> = {}
    if (!timezone) return seeds
    for (const stage of initialValues.stages) {
      const zone = stage.id ? stageTimezones?.[stage.id] : undefined
      const key = stage.startPlaceId
        ? `place:${stage.startPlaceId}`
        : stage.routeSlug && `route:${stage.routeSlug}`
      if (zone && key) seeds[key] = zone
    }
    const first = initialValues.stages[0]
    const tripRouteKey = initialValues.routeSlug && `route:${initialValues.routeSlug}`
    if (
      tripRouteKey &&
      !seeds[tripRouteKey] &&
      (!first || (!first.startPlaceId && !first.routeSlug))
    ) {
      seeds[tripRouteKey] = timezone
    }
    return seeds
  })
  const resolveZone = useZoneResolver(
    teamSlug,
    [...stageCandidates, needsTripRoute ? tripRouteCandidate : null],
    zoneSeeds
  )
  const tripRouteResolution = resolveZone(tripRouteCandidate)
  const tripRouteZone = tripRouteResolution === null ? team.timezone : tripRouteResolution
  const stageResolutions: ZoneResolution[] = []
  stageCandidates.forEach((candidate, index) => {
    const own = resolveZone(candidate)
    stageResolutions.push(
      own !== null ? own : index > 0 ? stageResolutions[index - 1] : tripRouteZone
    )
  })
  const lastStageZones = useLastKnown(
    stageResolutions.every((zone) => zone !== undefined) ? stageResolutions.join('|') : undefined,
    initialValues.stages
      .map((stage) => (stage.id && stageTimezones?.[stage.id]) || timezone || team.timezone)
      .join('|')
  ).split('|')
  const stageZones = stageResolutions.map(
    (zone, index) => zone || lastStageZones[index] || team.timezone
  )
  const routeOnlyZone = useLastKnown(tripRouteZone, timezone ?? team.timezone)
  const tripZone = stageZones[0] ?? routeOnlyZone
  tripZoneRef.current = tripZone

  useEffect(() => {
    form.validateField('publishAt')
  }, [status, tripZone, form])

  const handleAddStage = () => {
    // J+n at the same wall time as the previous stage — calendar arithmetic on the string, so that
    // neither a daylight-saving change nor the browser's zone moves it (docs/LEDGER_*.md API-60,
    // WEB-71). The first stage starts with the trip.
    const previous = stages[stages.length - 1]?.dateTime
    const newStageDate = previous
      ? addDaysToWallTime(previous, 1)
      : dateTime || instantToWallTime(new Date(), tripZone)

    form.insertListItem('stages', {
      name: t('trips.create.form.stages.defaultName', { number: stages.length + 1 }),
      dateTime: newStageDate,
      media: defaultMedia(),
    })

    // Switch to the new stage tab
    setActiveTab(`stage-${stages.length}`)
  }

  const handleRemoveStage = (index: number) => {
    form.removeListItem('stages', index)
    // Switch back to details tab if removing current stage
    if (activeTab === `stage-${index}`) {
      setActiveTab('details')
    }
  }

  const handleMoveStage = (index: number, direction: 'up' | 'down') => {
    const newIndex = direction === 'up' ? index - 1 : index + 1
    if (newIndex >= 0 && newIndex < stages.length) {
      form.reorderListItem('stages', { from: index, to: newIndex })
      // Update active tab to follow the moved stage
      if (activeTab === `stage-${index}`) {
        setActiveTab(`stage-${newIndex}`)
      } else if (activeTab === `stage-${newIndex}`) {
        setActiveTab(`stage-${index}`)
      }
    }
  }

  const handleSubmit = (values: TripRequest) => {
    onSubmit(values)
  }

  return (
    <form onSubmit={form.onSubmit(handleSubmit)}>
      <Stack>
        <Tabs value={activeTab} onChange={(value) => setActiveTab(value || 'details')}>
          <Tabs.List>
            <Tabs.Tab value="details" leftSection={<IconSettings size={16} />}>
              {t('trips.tabs.details')}
            </Tabs.Tab>
            {stages.map((stage, index) => (
              <Tabs.Tab key={index} value={`stage-${index}`}>
                <Group gap="xs" wrap="nowrap">
                  <Badge size="sm" variant="light" color="primary" circle>
                    {index + 1}
                  </Badge>
                  <Text size="sm" lineClamp={1} style={{ maxWidth: 100 }}>
                    {stage.name || t('trips.create.form.stages.defaultName', { number: index + 1 })}
                  </Text>
                </Group>
              </Tabs.Tab>
            ))}
            <Tabs.Tab
              value="add"
              leftSection={<IconPlus size={16} />}
              onClick={(e) => {
                e.preventDefault()
                handleAddStage()
              }}
            >
              {t('trips.tabs.addStage')}
            </Tabs.Tab>
          </Tabs.List>

          {/* Details Tab */}
          <Tabs.Panel value="details" pt="md">
            <Stack>
              <TextInput
                label={
                  <>
                    {t('trips.create.form.title.label')}{' '}
                    <Text span c="red">
                      *
                    </Text>
                  </>
                }
                placeholder={t('trips.create.form.title.placeholder')}
                {...form.getInputProps('name')}
              />

              {currentSlug && onSlugChange && (
                <SlugEditor
                  currentSlug={currentSlug}
                  baseUrl={paths.trip(teamSlug, '')}
                  onSlugChange={onSlugChange}
                  disabled={!canEditSlug}
                />
              )}

              <Stack gap="xs">
                <Text size="sm" fw={500}>
                  {t('form.description')}
                </Text>
                <MediaEditor
                  value={form.values.media}
                  onChange={(val) => form.setFieldValue('media', val)}
                  placeholder={t('trips.create.form.description.placeholder')}
                  minHeight="150px"
                  disabled={isPending}
                  ariaLabel={t('form.description')}
                  teamSlug={teamSlug}
                />
              </Stack>

              <WallDateTimePicker
                label={
                  <>
                    {t('startPlace')}{' '}
                    <Text span c="red">
                      *
                    </Text>
                  </>
                }
                value={form.values.dateTime}
                onChange={(wall) => {
                  if (wall) form.setFieldValue('dateTime', wall)
                }}
                zone={tripZone}
                error={form.errors.dateTime}
              />

              <TagPicker
                teamSlug={teamSlug}
                type="TRIP"
                value={form.values.tagIds}
                onChange={(ids) => form.setFieldValue('tagIds', ids)}
                disabled={isPending}
              />

              <VisibilitySelector
                allowed={allowedVisibilities ?? allowedVisibilitiesFor(team, 'trip')}
                value={form.values.visibility}
                onChange={(v) => form.setFieldValue('visibility', v)}
                error={form.errors.visibility}
                teamPrivate={team.visibility === Visibility.TEAM}
                disabled={isPending}
              />

              <Radio.Group label={t('form.status')} {...form.getInputProps('status')}>
                <Stack gap="xs" mt="xs">
                  <Radio value="DRAFT" label={t('status.DRAFT')} />
                  <Radio value="PUBLISHED" label={t('status.PUBLISHED')} />
                  <Radio value="CANCELLED" label={t('status.CANCELLED')} />
                </Stack>
              </Radio.Group>

              {status === Status.DRAFT && (
                <WallDateTimePicker
                  label={t('trips.create.form.publishAt.label')}
                  description={t('form.publishAtHint')}
                  value={form.values.publishAt}
                  onChange={(wall) => form.setFieldValue('publishAt', wall)}
                  zone={tripZone}
                  error={form.errors.publishAt}
                  clearable
                />
              )}

              {/* Route Selection */}
              <Stack gap="xs">
                <Group justify="space-between">
                  <Text size="sm" fw={500}>
                    {t('trips.create.form.route.label')}
                  </Text>
                  <Group gap="xs">
                    <Button
                      variant="subtle"
                      size="xs"
                      onClick={() => {
                        setPickerTarget({ type: 'trip' })
                        setShowRoutePickerModal(true)
                      }}
                    >
                      {routeSlug ? t('actions.edit') : t('trips.create.form.route.select')}
                    </Button>
                    {routeSlug && (
                      <Button
                        variant="subtle"
                        size="xs"
                        color="danger"
                        onClick={() => form.setFieldValue('routeSlug', undefined)}
                      >
                        {t('trips.create.form.route.clear')}
                      </Button>
                    )}
                  </Group>
                </Group>
                {routeSlug ? (
                  <RoutePreview routeSlug={routeSlug} teamSlug={teamSlug} />
                ) : (
                  <Text size="sm" c="dimmed" fs="italic">
                    {t('noRouteSelected')}
                  </Text>
                )}
                <Text size="xs" c="dimmed">
                  {t('trips.create.form.route.hint')}
                </Text>
              </Stack>
            </Stack>
          </Tabs.Panel>

          {/* Stage Tabs */}
          {stages.map((stage, index) => (
            <Tabs.Panel key={index} value={`stage-${index}`} pt="md">
              <Paper withBorder p="md">
                <Group justify="space-between" mb="md">
                  <Group gap="xs">
                    <ReorderControls
                      index={index}
                      total={stages.length}
                      onMove={(dir) => handleMoveStage(index, dir)}
                    />
                    <Badge size="lg" variant="light" color="primary" circle>
                      {index + 1}
                    </Badge>
                    <Text size="lg" fw={500}>
                      {stage.name ||
                        t('trips.create.form.stages.defaultName', { number: index + 1 })}
                    </Text>
                  </Group>
                  <Button
                    variant="subtle"
                    size="xs"
                    color="danger"
                    leftSection={<IconTrash size={14} />}
                    onClick={() => handleRemoveStage(index)}
                  >
                    {t('trips.create.form.stages.remove')}
                  </Button>
                </Group>

                <Stack>
                  <SimpleGrid cols={{ base: 1, sm: 3 }} spacing="md">
                    <TextInput
                      label={t('trips.create.form.stages.name.label')}
                      placeholder={t('trips.create.form.stages.name.placeholder')}
                      {...form.getInputProps(`stages.${index}.name`)}
                    />
                    <WallDateTimePicker
                      label={t('trips.create.form.stages.date.label')}
                      value={form.values.stages[index]?.dateTime}
                      onChange={(wall) => {
                        if (wall) form.setFieldValue(`stages.${index}.dateTime`, wall)
                      }}
                      zone={stageZones[index] ?? tripZone}
                    />
                    <NumberInput
                      label={t('trips.create.form.stages.speed.label')}
                      placeholder={t('trips.create.form.stages.speed.placeholder', {
                        unit: config.speedUnit,
                      })}
                      min={0}
                      suffix={` ${config.speedUnit}`}
                      value={speedToDisplay(form.values.stages[index]?.averageSpeed) ?? ''}
                      onChange={(val) =>
                        form.setFieldValue(`stages.${index}.averageSpeed`, speedFromDisplay(val))
                      }
                    />
                  </SimpleGrid>

                  <SimpleGrid cols={{ base: 1, sm: 2 }} spacing="md">
                    <Stack gap={4}>
                      <Text size="sm" fw={500}>
                        {t('trips.create.form.stages.startPlace.label')}
                      </Text>
                      <PlaceAutocomplete
                        teamSlug={teamSlug}
                        value={stage.startPlaceId}
                        onChange={(placeId) =>
                          form.setFieldValue(`stages.${index}.startPlaceId`, placeId)
                        }
                        filterStart={true}
                        placeholder={t('trips.create.form.stages.startPlace.placeholder')}
                      />
                    </Stack>
                    <Stack gap={4}>
                      <Text size="sm" fw={500}>
                        {t('trips.create.form.stages.endPlace.label')}
                      </Text>
                      <PlaceAutocomplete
                        teamSlug={teamSlug}
                        value={stage.endPlaceId}
                        onChange={(placeId) =>
                          form.setFieldValue(`stages.${index}.endPlaceId`, placeId)
                        }
                        filterEnd={true}
                        placeholder={t('trips.create.form.stages.endPlace.placeholder')}
                      />
                    </Stack>
                  </SimpleGrid>

                  <Stack gap={4}>
                    <Text size="sm" fw={500}>
                      {t('form.description')}
                    </Text>
                    <MediaEditor
                      value={form.values.stages[index]?.media}
                      onChange={(val) => form.setFieldValue(`stages.${index}.media`, val)}
                      placeholder={t('trips.create.form.stages.description.placeholder')}
                      minHeight="120px"
                      disabled={isPending}
                      ariaLabel={t('form.description')}
                      teamSlug={teamSlug}
                    />
                  </Stack>

                  <Stack gap={4}>
                    <Group justify="space-between">
                      <Text size="sm" fw={500}>
                        {t('trips.create.form.stages.route.label')}
                      </Text>
                      <Group gap="xs">
                        <Button
                          variant="subtle"
                          size="xs"
                          leftSection={<IconRouteIcon size={14} />}
                          onClick={() => {
                            setPickerTarget({ type: 'stage', index })
                            setShowRoutePickerModal(true)
                          }}
                        >
                          {stage.routeSlug
                            ? t('actions.edit')
                            : t('trips.create.form.route.select')}
                        </Button>
                        {stage.routeSlug && (
                          <Button
                            variant="subtle"
                            size="xs"
                            color="danger"
                            onClick={() =>
                              form.setFieldValue(`stages.${index}.routeSlug`, undefined)
                            }
                          >
                            {t('trips.create.form.route.clear')}
                          </Button>
                        )}
                      </Group>
                    </Group>
                    {stage.routeSlug ? (
                      <RoutePreviewCompact
                        route={stageRoutesBySlug.get(stage.routeSlug)}
                        isLoading={isStageRouteLoading(stage.routeSlug)}
                      />
                    ) : (
                      <Text size="sm" c="dimmed" fs="italic">
                        {t('noRouteSelected')}
                      </Text>
                    )}
                  </Stack>
                </Stack>
              </Paper>
            </Tabs.Panel>
          ))}
        </Tabs>

        <Group justify="flex-end" pt="md">
          <Button variant="default" onClick={onCancel}>
            {cancelButtonText || t('actions.cancelAction')}
          </Button>
          <Button type="submit" disabled={isPending || !form.isValid()} loading={isPending}>
            {submitButtonText || t('actions.save')}
          </Button>
        </Group>

        <RoutePickerModal
          isOpen={showRoutePickerModal}
          onClose={() => {
            setShowRoutePickerModal(false)
            setPickerTarget(null)
          }}
          onSelect={(route: RouteDto | null) => {
            if (pickerTarget) {
              if (pickerTarget.type === 'trip') {
                form.setFieldValue('routeSlug', route ? route.slug : undefined)
              } else if (pickerTarget.type === 'stage') {
                form.setFieldValue(
                  `stages.${pickerTarget.index}.routeSlug`,
                  route ? route.slug : undefined
                )
              }
            }
            setShowRoutePickerModal(false)
            setPickerTarget(null)
          }}
          teamSlug={teamSlug}
          selectedRouteSlug={
            pickerTarget?.type === 'trip'
              ? routeSlug
              : pickerTarget?.type === 'stage'
                ? stages[pickerTarget.index]?.routeSlug
                : null
          }
          title={
            pickerTarget?.type === 'trip'
              ? t('trips.create.form.route.selectForTrip')
              : t('trips.create.form.route.selectForStage')
          }
          onCreateNew={() => {
            setShowRoutePickerModal(false)
            setShowCreateRouteModal(true)
          }}
        />

        <CreateRouteModal
          isOpen={showCreateRouteModal}
          onClose={() => {
            setShowCreateRouteModal(false)
            setPickerTarget(null)
          }}
          onRouteCreated={(route: RouteDto) => {
            if (pickerTarget) {
              if (pickerTarget.type === 'trip') {
                form.setFieldValue('routeSlug', route.slug)
              } else if (pickerTarget.type === 'stage') {
                form.setFieldValue(`stages.${pickerTarget.index}.routeSlug`, route.slug)
              }
            }
            setShowCreateRouteModal(false)
            setPickerTarget(null)
          }}
          team={team}
        />
      </Stack>
    </form>
  )
}
