import { useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  Alert,
  Box,
  Button,
  Group,
  ScrollArea,
  SegmentedControl,
  Skeleton,
  Slider,
  Stack,
  Text,
} from '@mantine/core'
import { IconAlertTriangle, IconInfoCircle, IconRefresh, IconRoute2 } from '@tabler/icons-react'
import { CompassPoint, RouteGeneratorType } from '@/api/dto'
import type { GeneratedRouteDto, GeoPoint, TeamDetailDto } from '@/api/dto'
import { EmptyState } from '@/components/common/EmptyState'
import { useMediaMatch } from '@/hooks/useResponsive'
import { useUnits } from '@/hooks/useUnits'
import {
  generatorErrorMessage,
  isRetryableGeneratorError,
  pointToParam,
  type GeneratorParams,
} from '@/lib/routeGenerator'
import { isPlannerQuotaSpent } from '@/lib/plannerQuota'
import { selectIsPlatformAdmin, useAuthStore } from '@/store/authStore'
import { tRegister, type TranslationKey } from '@/lib/i18nUtils'
import { CompassPicker } from './CompassPicker'
import { GeneratedRouteCard } from './GeneratedRouteCard'
import { RouteGeneratorMap, type GeneratorClickMode } from './RouteGeneratorMap'
import { useRouteGenerator } from './useRouteGenerator'

/** What the panel changes: the parameters of the request, never the results. */
export type GeneratorParamPatch = Partial<
  Pick<GeneratorParams, 'start' | 'end' | 'bearing' | 'distanceKm' | 'familiarity' | 'type'>
>

export interface RouteGeneratorPanelParams extends GeneratorParams {
  go: boolean
  selected: number
}

interface RouteGeneratorPanelProps {
  team: TeamDetailDto
  params: RouteGeneratorPanelParams
  /** A changed parameter drops the results: the host clears `go`, `seed` and `selected`. */
  onParamsChange: (patch: GeneratorParamPatch) => void
  onGenerate: () => void
  onMoreProposals: () => void
  onSelect: (index: number) => void
  onOpen: (candidate: GeneratedRouteDto, type: RouteGeneratorType) => void
  /** `page`: the map is 70 % of the viewport; `modal`: the panel fills the dialog under its header. */
  layout: 'page' | 'modal'
}

const TYPE_LABEL_KEYS: Record<RouteGeneratorType, TranslationKey> = {
  ROAD: tRegister('routes.surfaceType.ROAD'),
  GRAVEL: tRegister('routes.surfaceType.GRAVEL'),
  MTB: tRegister('routes.surfaceType.MTB'),
}

const FAMILIARITY_BANDS: TranslationKey[] = [
  tRegister('routeGenerator.card.band.low'),
  tRegister('routeGenerator.card.band.low'),
  tRegister('routeGenerator.card.band.mid'),
  tRegister('routeGenerator.card.band.high'),
  tRegister('routeGenerator.card.band.high'),
]

/**
 * The route generator: controls, proposals and map (ledger `WEB-179`). It owns no parameter: they
 * live in the query string on the page and in a reducer in the editor's modal. The only state here
 * is transient, what a click on the map places and which card is hovered.
 */
export function RouteGeneratorPanel({
  team,
  params,
  onParamsChange,
  onGenerate,
  onMoreProposals,
  onSelect,
  onOpen,
  layout,
}: RouteGeneratorPanelProps) {
  const { t } = useTranslation()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  const isCoarse = useMediaMatch('(pointer: coarse)')
  const { distance, unitSystem, distanceFromDisplay, distanceToDisplay } = useUnits()
  const isImperial = unitSystem === 'IMPERIAL'

  const [clickMode, setClickMode] = useState<GeneratorClickMode>(null)
  const [hovered, setHovered] = useState<number | null>(null)
  // « Ailleurs » without a point yet is a state of its own: nothing is written until the click
  const [endElsewhere, setEndElsewhere] = useState(params.end !== undefined)
  useEffect(() => {
    if (params.end !== undefined) setEndElsewhere(true)
  }, [params.end])
  // The distance follows the drag locally; the host is told when it is released (one history entry)
  const [distanceDraft, setDistanceDraft] = useState<number | null>(null)

  const generator = useRouteGenerator(team, { ...params, endPending: endElsewhere && !params.end })
  const quotaSpent = isPlannerQuotaSpent(team.plannerQuota, isPlatformAdmin)
  const teamHasLocation = !!team.geometry
  const candidates = generator.data?.candidates ?? []
  const selected = Math.min(params.selected, Math.max(0, candidates.length - 1))
  const distanceText = distance(params.distanceKm * 1000)

  const pick = (mode: 'start' | 'end', point: GeoPoint) => {
    setClickMode(null)
    onParamsChange(mode === 'start' ? { start: pointToParam(point) } : { end: pointToParam(point) })
  }

  // Slider in the reader's unit; the request is in km, between the backend's 10 and 300
  const sliderMin = isImperial ? 5 : 10
  const sliderMax = isImperial ? 185 : 300
  const shownDistance = Math.round(distanceToDisplay(params.distanceKm * 1000) ?? sliderMin)
  const sliderValue = distanceDraft ?? Math.min(sliderMax, Math.max(sliderMin, shownDistance))
  const draftText = distance(kmOf(sliderValue) * 1000)
  function kmOf(display: number): number {
    const km = Math.round((distanceFromDisplay(display) ?? 0) / 1000)
    return Math.min(300, Math.max(10, km))
  }

  const startLabel = params.start
    ? t('routeGenerator.start.picked')
    : teamHasLocation
      ? t('routeGenerator.start.team')
      : null

  const blockerText =
    generator.blocker === 'noStart'
      ? t('routeGenerator.start.missing')
      : generator.blocker === 'noEnd'
        ? t('routeGenerator.end.missing')
        : null

  const controls = (
    <Stack gap="md">
      {/* Départ */}
      <Stack gap={4}>
        <Text size="sm" fw={500}>
          {t('routeGenerator.start.label')}
        </Text>
        {startLabel ? (
          <Text size="sm">{startLabel}</Text>
        ) : (
          <Alert color="blue" variant="light" icon={<IconInfoCircle />}>
            {t('routeGenerator.start.noLocation')}
          </Alert>
        )}
        <Group gap="xs">
          <Button variant="subtle" size="compact-sm" onClick={() => setClickMode('start')}>
            {t('routeGenerator.start.pick')}
          </Button>
          {params.start && teamHasLocation && (
            <Button
              variant="subtle"
              size="compact-sm"
              onClick={() => onParamsChange({ start: undefined })}
            >
              {t('routeGenerator.start.reset')}
            </Button>
          )}
        </Group>
      </Stack>

      {/* Arrivée */}
      <Stack gap={4}>
        <Text size="sm" fw={500}>
          {t('routeGenerator.end.label')}
        </Text>
        <SegmentedControl
          size="xs"
          value={endElsewhere ? 'elsewhere' : 'loop'}
          onChange={(value) => {
            if (value === 'loop') {
              setEndElsewhere(false)
              setClickMode(null)
              if (params.end) onParamsChange({ end: undefined })
            } else {
              setEndElsewhere(true)
              if (!params.end) setClickMode('end')
            }
          }}
          data={[
            { value: 'loop', label: t('routeGenerator.end.loop') },
            { value: 'elsewhere', label: t('routeGenerator.end.elsewhere') },
          ]}
          aria-label={t('routeGenerator.end.label')}
        />
        {params.end && (
          <Group gap="xs">
            <Text size="sm">{t('routeGenerator.start.picked')}</Text>
            <Button variant="subtle" size="compact-sm" onClick={() => setClickMode('end')}>
              {t('routeGenerator.end.move')}
            </Button>
          </Group>
        )}
      </Stack>

      {/* Direction */}
      <Stack gap={4}>
        <Text size="sm" fw={500}>
          {t('routeGenerator.bearing.label')}
        </Text>
        <CompassPicker
          value={params.bearing}
          onChange={(bearing) => onParamsChange({ bearing: bearing as CompassPoint | undefined })}
          far={generator.far}
        />
      </Stack>

      {/* Distance */}
      <Stack gap={4}>
        <Group justify="space-between">
          <Text size="sm" fw={500}>
            {t('routeGenerator.distance.label')}
          </Text>
          <Text size="sm">{draftText}</Text>
        </Group>
        <Slider
          min={sliderMin}
          max={sliderMax}
          step={5}
          value={sliderValue}
          label={null}
          onChange={setDistanceDraft}
          onChangeEnd={(value) => {
            setDistanceDraft(null)
            const km = kmOf(value)
            if (km !== params.distanceKm) onParamsChange({ distanceKm: km })
          }}
          thumbLabel={t('routeGenerator.distance.label')}
          thumbValueText={() => draftText}
        />
      </Stack>

      {/* Fréquentation */}
      <Stack gap={4}>
        <Text size="sm" fw={500}>
          {t('routeGenerator.familiarity.label')}
        </Text>
        <Slider
          min={0}
          max={1}
          step={0.25}
          marks={[{ value: 0 }, { value: 0.25 }, { value: 0.5 }, { value: 0.75 }, { value: 1 }]}
          label={null}
          value={params.familiarity}
          onChange={(familiarity) => onParamsChange({ familiarity })}
          thumbLabel={t('routeGenerator.familiarity.label')}
          thumbValueText={(value) => t(FAMILIARITY_BANDS[Math.round(value * 4)])}
        />
        <Group justify="space-between" mt={8}>
          <Text size="xs" c="dimmed">
            {t('routeGenerator.familiarity.low')}
          </Text>
          <Text size="xs" c="dimmed">
            {t('routeGenerator.familiarity.high')}
          </Text>
        </Group>
      </Stack>

      {/* Type */}
      <Stack gap={4}>
        <Text size="sm" fw={500}>
          {t('routeGenerator.type.label')}
        </Text>
        {generator.typePending && params.type === undefined ? (
          <Skeleton h={30} />
        ) : (
          <SegmentedControl
            size="xs"
            value={generator.type}
            onChange={(value) => {
              const next = value as RouteGeneratorType
              // The dominant type is the default: it is not written
              onParamsChange({ type: next === generator.dominantType ? undefined : next })
            }}
            data={Object.values(RouteGeneratorType).map((type) => ({
              value: type,
              label: t(TYPE_LABEL_KEYS[type]),
            }))}
            aria-label={t('routeGenerator.type.label')}
          />
        )}
      </Stack>

      <Stack gap={4}>
        <Button
          fullWidth
          onClick={onGenerate}
          disabled={!generator.canGenerate}
          loading={generator.isFetching && !generator.isPlaceholder}
          loaderProps={{ type: 'dots' }}
        >
          {generator.isFetching && !generator.isPlaceholder
            ? t('routeGenerator.generating')
            : t('routeGenerator.generate')}
        </Button>
        {blockerText && (
          <Text size="xs" c="dimmed">
            {blockerText}
          </Text>
        )}
      </Stack>
    </Stack>
  )

  const openDisabledReason = quotaSpent ? t('routeGenerator.quotaSpent') : undefined
  const openLabel =
    layout === 'modal' ? t('routeGenerator.card.use') : t('routeGenerator.card.open')

  const results = (
    <Stack gap="sm" data-testid="route-generator-results">
      {generator.error ? (
        <Alert color="red" variant="light" icon={<IconAlertTriangle />}>
          <Stack gap="xs" align="flex-start">
            <Text size="sm">
              {generatorErrorMessage(generator.error, t, { distance: distanceText })}
            </Text>
            {isRetryableGeneratorError(generator.error) && (
              <Button size="compact-sm" variant="default" onClick={() => void generator.refetch()}>
                {t('routeGenerator.retry')}
              </Button>
            )}
          </Stack>
        </Alert>
      ) : candidates.length > 0 ? (
        <>
          <Box
            style={
              isCoarse
                ? undefined
                : { display: 'flex', flexDirection: 'column', gap: 'var(--mantine-spacing-sm)' }
            }
          >
            {isCoarse ? (
              <ScrollArea type="auto" offsetScrollbars>
                <Group wrap="nowrap" gap="sm" align="stretch">
                  {candidates.map((candidate, i) => (
                    <Box key={i} w={260} style={{ display: 'flex' }}>
                      {renderCard(candidate, i)}
                    </Box>
                  ))}
                </Group>
              </ScrollArea>
            ) : (
              candidates.map((candidate, i) => <div key={i}>{renderCard(candidate, i)}</div>)
            )}
          </Box>
          <Button
            variant="default"
            leftSection={<IconRefresh size={16} />}
            onClick={onMoreProposals}
            disabled={generator.isFetching}
          >
            {t('routeGenerator.more')}
          </Button>
          {generator.data?.familiarityFallback && (
            <Alert color="blue" variant="light" icon={<IconInfoCircle />}>
              {t('routeGenerator.fallback')}
            </Alert>
          )}
          {generator.data?.network.incomplete && (
            <Text size="sm" c="dimmed">
              {t('routeGenerator.incomplete', { count: generator.data.network.pendingRouteCount })}
            </Text>
          )}
        </>
      ) : generator.isFetching ? (
        <>
          {[0, 1, 2].map((i) => (
            <Skeleton key={i} h={120} data-testid="generated-route-skeleton" />
          ))}
          {generator.slow && (
            <Text size="sm" c="dimmed">
              {t('routeGenerator.slow')}
            </Text>
          )}
        </>
      ) : (
        <EmptyState
          icon={<IconRoute2 size={48} />}
          title={t('routeGenerator.empty.title')}
          description={t('routeGenerator.empty.text')}
        />
      )}
    </Stack>
  )

  function renderCard(candidate: GeneratedRouteDto, i: number) {
    return (
      <GeneratedRouteCard
        candidate={candidate}
        index={i}
        type={generator.type}
        selected={i === selected}
        onHover={setHovered}
        onSelect={onSelect}
        onOpen={(c) => onOpen(c, generator.type)}
        openLabel={openLabel}
        openDisabled={quotaSpent}
        openDisabledReason={openDisabledReason}
        dimmed={generator.isPlaceholder}
      />
    )
  }

  const mapHeight =
    layout === 'modal' ? (isCoarse ? '50dvh' : '100%') : isCoarse ? '50dvh' : '70dvh'
  const map = (
    <RouteGeneratorMap
      start={generator.start}
      end={generator.end}
      candidates={candidates}
      selected={selected}
      hovered={hovered}
      clickMode={clickMode}
      endElsewhere={endElsewhere}
      onPick={pick}
      onCancelClickMode={() => setClickMode(null)}
      onSelect={onSelect}
      loading={generator.isFetching && candidates.length === 0}
      height={mapHeight}
    />
  )

  if (isCoarse) {
    return (
      <Stack gap="md">
        {controls}
        {map}
        {results}
      </Stack>
    )
  }

  return (
    <Group
      align="flex-start"
      wrap="nowrap"
      gap="md"
      h={layout === 'modal' ? '100%' : undefined}
      p={layout === 'modal' ? 'md' : undefined}
    >
      <Stack
        w={360}
        gap="lg"
        style={{
          flexShrink: 0,
          maxHeight: layout === 'modal' ? '100%' : undefined,
          overflowY: 'auto',
        }}
      >
        {controls}
        {results}
      </Stack>
      <Box style={{ flex: 1, minWidth: 0, height: layout === 'modal' ? '100%' : undefined }}>
        {map}
      </Box>
    </Group>
  )
}
