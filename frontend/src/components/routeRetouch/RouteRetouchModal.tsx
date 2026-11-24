import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import {
  Alert,
  Box,
  Button,
  Group,
  Modal,
  NumberInput,
  SegmentedControl,
  SimpleGrid,
  Skeleton,
  Stack,
  Text,
} from '@mantine/core'
import { IconAlertTriangle, IconInfoCircle, IconRefresh } from '@tabler/icons-react'
import type { GeoPoint, PlannerQuotaDto, RouteDetailDto, RouteRetouchOfferDto } from '@/api/dto'
import { useGetPlace } from '@/api/endpoints/places/places'
import { paths } from '@/config/paths'
import { useMediaMatch } from '@/hooks/useResponsive'
import { useUnits } from '@/hooks/useUnits'
import { isPlannerQuotaSpent } from '@/lib/plannerQuota'
import type { GeneratedHandoff } from '@/lib/routeGenerator'
import {
  clampTarget,
  generatorLinkFor,
  isDeadZone,
  isNoShorter,
  isOtherSeedUseful,
  isOutOfRange,
  isRetryableRetouchError,
  isShortening,
  retouchBounds,
  retouchErrorTone,
  retouchHandoff,
  routeRetouchErrorMessage,
  routeRetouchRequest,
  type RetouchTarget,
} from '@/lib/routeRetouch'
import { selectIsPlatformAdmin, useAuthStore } from '@/store/authStore'
import { PlaceAutocomplete } from '../common/PlaceAutocomplete'
import { RetouchedRouteCard } from './RetouchedRouteCard'
import { RouteRetouchMap } from './RouteRetouchMap'
import { useRouteRetouch } from './useRouteRetouch'

export type RetouchMode = 'resize' | 'moveEnd'

interface RouteRetouchModalProps {
  opened: boolean
  onClose: () => void
  teamSlug: string
  route: RouteDetailDto
  offer: RouteRetouchOfferDto
  /** The operation chosen in the menu; the dialog lets the reader switch. */
  initialMode: RetouchMode
  /** The team's planner quota, to say a save of the opened route will be refused. */
  plannerQuota?: PlannerQuotaDto
  /** « Ouvrir dans le planificateur »: the page navigates to a new route with this hand-off. */
  onOpen: (handoff: GeneratedHandoff) => void
  /**
   * « Modifier »: the page opens this route's editor with the proposal in place of its track
   * (ledger `WEB-203`). Absent for a reader who cannot edit the route: no button.
   */
  onEdit?: (handoff: GeneratedHandoff) => void
}

interface Submitted {
  target: RetouchTarget
  seed: number
}

/** Hundredths of the display unit are noise on a distance field: tenths, inwards. */
const ceil1 = (n: number) => Math.ceil(n * 10 - 1e-9) / 10
const floor1 = (n: number) => Math.floor(n * 10 + 1e-9) / 10

/**
 * Retouching a saved route (ledger `API-212`, plan lot 7c): aim at another distance, or move the
 * finish; up to three proposals over the original, the changed stretch highlighted, then open one in
 * the planner, which saves it as a new route. Nothing is saved here and no quota is drawn.
 */
export function RouteRetouchModal({
  opened,
  onClose,
  teamSlug,
  route,
  offer,
  initialMode,
  plannerQuota,
  onOpen,
  onEdit,
}: RouteRetouchModalProps) {
  const { t } = useTranslation()
  const { distance, distanceToDisplay, distanceFromDisplay, unitSystem, percent } = useUnits()
  const isMobile = useMediaMatch('(max-width: 48em)')
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  const quotaSpent = isPlannerQuotaSpent(plannerQuota, isPlatformAdmin)
  const bounds = useMemo(() => retouchBounds(offer), [offer])

  const [mode, setMode] = useState<RetouchMode>(initialMode)
  const [value, setValue] = useState<string | number>('')
  const [endPoint, setEndPoint] = useState<GeoPoint | undefined>()
  const [placeId, setPlaceId] = useState<string | undefined>()
  const [submitted, setSubmitted] = useState<Submitted | undefined>()
  const [selected, setSelected] = useState(0)
  const [hovered, setHovered] = useState<number | null>(null)

  const request = useMemo(
    () => (submitted ? routeRetouchRequest(submitted.target, submitted.seed) : undefined),
    [submitted]
  )
  const retouch = useRouteRetouch(teamSlug, route.slug, request, `${route.updatedAt}`)

  const place = useGetPlace(teamSlug, placeId ?? '', { query: { enabled: !!placeId } })
  const placeCoords = placeId ? place.data?.geometry?.coordinates : undefined
  const endShown: GeoPoint | undefined = placeId
    ? placeCoords
      ? { lng: placeCoords[0], lat: placeCoords[1] }
      : undefined
    : endPoint

  const original = useMemo(() => route.tracks[0]?.line.coordinates ?? [], [route.tracks])

  const targetKm = useMemo(() => {
    if (value === '' || !bounds) return undefined
    const meters = distanceFromDisplay(value)
    return meters === undefined || !Number.isFinite(meters) ? undefined : meters / 1000
  }, [value, bounds, distanceFromDisplay])

  if (!bounds) return null

  const currentText = distance(bounds.currentKm * 1000)
  const minShown = ceil1(distanceToDisplay(bounds.minKm * 1000) ?? 0)
  const maxShown = floor1(distanceToDisplay(bounds.maxKm * 1000) ?? 0)
  const deadZone = targetKm !== undefined && isDeadZone(targetKm, bounds)
  const outOfRange = targetKm !== undefined && isOutOfRange(targetKm, bounds)
  const resizeValid = targetKm !== undefined && !deadZone && !outOfRange
  const canSubmit =
    mode === 'resize' ? resizeValid : endShown !== undefined || placeId !== undefined
  const unitLabel = unitSystem === 'IMPERIAL' ? 'mi' : 'km'

  const reset = () => {
    setSubmitted(undefined)
    setSelected(0)
    setHovered(null)
  }

  const target = (): RetouchTarget | undefined => {
    if (mode === 'resize') {
      return targetKm === undefined ? undefined : { mode, targetKm: clampTarget(targetKm, bounds) }
    }
    if (placeId) return { mode, placeId }
    return endPoint ? { mode, point: endPoint } : undefined
  }

  const submit = () => {
    const next = target()
    if (!next) return
    setSelected(0)
    setSubmitted({ target: next, seed: 0 })
  }

  const more = () => {
    if (!submitted) return
    setSelected(0)
    setSubmitted({ ...submitted, seed: submitted.seed + 1 })
  }

  const answer = retouch.data
  const candidates = answer?.candidates ?? []
  const chosen = candidates[Math.min(selected, Math.max(0, candidates.length - 1))]
  const askedKm = submitted?.target.mode === 'resize' ? submitted.target.targetKm : undefined

  const open = () => {
    if (!chosen) return
    onOpen(
      retouchHandoff(chosen, offer.rideType, t('routeRetouch.retouchedName', { name: route.name }))
    )
  }

  const edit = () => {
    if (!chosen || !onEdit) return
    onEdit(retouchHandoff(chosen, offer.rideType, route.name))
  }

  const error = retouch.error
  const tone = error ? retouchErrorTone(error) : undefined
  const generatorLink = generatorLinkFor(
    paths.routeGenerate(teamSlug),
    original[0],
    askedKm ?? bounds.currentKm,
    offer.rideType
  )

  const fields =
    mode === 'resize' ? (
      <Stack gap="xs">
        <Text size="sm">{t('routeRetouch.current', { distance: currentText })}</Text>
        <NumberInput
          label={t('routeRetouch.resize.label')}
          description={t('routeRetouch.resize.help', {
            min: distance(bounds.minKm * 1000),
            max: distance(bounds.maxKm * 1000),
          })}
          value={value}
          onChange={(next) => {
            setValue(next)
            reset()
          }}
          min={minShown}
          max={maxShown}
          decimalScale={1}
          rightSection={<Text size="sm">{unitLabel}</Text>}
          rightSectionWidth={36}
          error={
            deadZone
              ? t('routeRetouch.resize.deadZone', { min: distance(bounds.minChangeKm * 1000) })
              : outOfRange
                ? t('routeRetouch.resize.outOfRange', {
                    min: distance(bounds.minKm * 1000),
                    max: distance(bounds.maxKm * 1000),
                  })
                : undefined
          }
          data-testid="retouch-distance"
        />
        {resizeValid && isShortening(targetKm, bounds.currentKm) && (
          <Text size="xs" c="dimmed">
            {t('routeRetouch.resize.shortenHint')}
          </Text>
        )}
      </Stack>
    ) : (
      <Stack gap="xs">
        <Text size="sm">{t('routeRetouch.moveEnd.help')}</Text>
        <Stack gap={4}>
          <Text size="sm" fw={500}>
            {t('routeRetouch.moveEnd.place')}
          </Text>
          <PlaceAutocomplete
            teamSlug={teamSlug}
            value={placeId}
            filterEnd
            onChange={(id) => {
              setPlaceId(id)
              if (id) setEndPoint(undefined)
              reset()
            }}
          />
        </Stack>
      </Stack>
    )

  const results = (
    <Stack gap="sm" data-testid="route-retouch-results">
      {error ? (
        <Alert
          color={tone === 'info' ? 'blue' : 'red'}
          variant="light"
          icon={tone === 'info' ? <IconInfoCircle /> : <IconAlertTriangle />}
        >
          <Stack gap="xs" align="flex-start">
            <Text size="sm">
              {routeRetouchErrorMessage(error, t, {
                distance: distance((askedKm ?? bounds.currentKm) * 1000),
                current: currentText,
                min: distance(bounds.minChangeKm * 1000),
                percent: percent(bounds.maxChangeShare * 100),
              })}
            </Text>
            <Group gap="xs">
              {isNoShorter(error) && (
                <Button
                  size="compact-sm"
                  variant="default"
                  onClick={() => {
                    setMode('moveEnd')
                    reset()
                  }}
                >
                  {t('routeRetouch.moveEnd.action')}
                </Button>
              )}
              {isOtherSeedUseful(error) && (
                <Button
                  size="compact-sm"
                  variant="default"
                  leftSection={<IconRefresh size={14} />}
                  onClick={more}
                  loading={retouch.isFetching}
                  data-testid="retouch-more-after-error"
                >
                  {t('routeRetouch.more')}
                </Button>
              )}
              {tone === 'info' && (
                <Button size="compact-sm" variant="default" component={Link} to={generatorLink}>
                  {t('routeRetouch.openGenerator')}
                </Button>
              )}
              {isRetryableRetouchError(error) && (
                <Button
                  size="compact-sm"
                  variant="default"
                  leftSection={<IconRefresh size={14} />}
                  onClick={() => void retouch.refetch()}
                >
                  {t('routeGenerator.retry')}
                </Button>
              )}
            </Group>
          </Stack>
        </Alert>
      ) : candidates.length > 0 && answer ? (
        <>
          <Stack gap="xs">
            {candidates.map((candidate, i) => (
              <RetouchedRouteCard
                key={i}
                candidate={candidate}
                index={i}
                originalDistanceM={answer.originalDistanceM}
                originalAscentM={answer.originalAscentM}
                selected={i === selected}
                onHover={setHovered}
                onSelect={setSelected}
                dimmed={retouch.isPlaceholder}
              />
            ))}
          </Stack>
          <Group justify="space-between" wrap="wrap">
            <Button
              variant="subtle"
              size="compact-md"
              leftSection={<IconRefresh size={14} />}
              onClick={more}
              loading={retouch.isFetching}
            >
              {t('routeRetouch.more')}
            </Button>
            <Group gap="xs" wrap="wrap">
              {onEdit && (
                <Button
                  variant="default"
                  onClick={edit}
                  disabled={quotaSpent || retouch.isPlaceholder}
                >
                  {t('routeRetouch.edit')}
                </Button>
              )}
              <Button onClick={open} disabled={quotaSpent || retouch.isPlaceholder}>
                {t('routeRetouch.open')}
              </Button>
            </Group>
          </Group>
          <Text size="xs" c="dimmed">
            {quotaSpent
              ? t('routeGenerator.quotaSpent')
              : onEdit
                ? t('routeRetouch.editHelp')
                : t('routeRetouch.openHelp')}
          </Text>
        </>
      ) : retouch.isFetching ? (
        <>
          {Array.from({ length: 3 }).map((_, i) => (
            <Skeleton key={i} h={110} data-testid="retouched-route-skeleton" />
          ))}
        </>
      ) : null}
      {retouch.isFetching && retouch.slow && (
        <Text size="xs" c="dimmed" role="status">
          {t('routeRetouch.slow')}
        </Text>
      )}
    </Stack>
  )

  return (
    <Modal
      opened={opened}
      onClose={onClose}
      size="xl"
      fullScreen={isMobile}
      title={t('routeRetouch.title', { name: route.name })}
      zIndex={300}
    >
      <Stack gap="md">
        <SegmentedControl
          value={mode}
          onChange={(next) => {
            setMode(next as RetouchMode)
            reset()
          }}
          data={[
            ...(offer.operations.includes('RESIZE')
              ? [{ value: 'resize', label: t('routeRetouch.resize.action') }]
              : []),
            ...(offer.operations.includes('MOVE_END')
              ? [{ value: 'moveEnd', label: t('routeRetouch.moveEnd.action') }]
              : []),
          ]}
        />
        <SimpleGrid cols={{ base: 1, md: 2 }} spacing="md">
          <Stack gap="md">
            {fields}
            <Button
              onClick={submit}
              disabled={!canSubmit}
              loading={retouch.isFetching && !retouch.isPlaceholder}
            >
              {t('routeRetouch.submit')}
            </Button>
            {results}
          </Stack>
          <Box>
            <RouteRetouchMap
              original={original}
              candidates={candidates}
              selected={selected}
              hovered={hovered}
              end={endShown}
              endSnapM={offer.endSnapM}
              placing={mode === 'moveEnd'}
              onPick={(point) => {
                setEndPoint(point)
                setPlaceId(undefined)
                reset()
              }}
              height={isMobile ? '320px' : '520px'}
            />
          </Box>
        </SimpleGrid>
      </Stack>
    </Modal>
  )
}
