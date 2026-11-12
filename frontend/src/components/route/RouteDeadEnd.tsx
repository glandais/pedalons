import { useMemo } from 'react'
import { useTranslation } from 'react-i18next'
import { useQueries } from '@tanstack/react-query'
import { Button, Paper, Stack, Text } from '@mantine/core'
import {
  getCountAllRoutesQueryOptions,
  getCountRoutesQueryOptions,
  getListAllRoutesQueryOptions,
  getListRoutesQueryOptions,
} from '@/api/endpoints/routes/routes'
import { FilteredEmptyState } from '../common/FilteredEmptyState'
import { searchFilter } from '../common/filteredEmpty'
import { RouteRow } from './RouteRow'
import { LIST_REQUEST } from '@/lib/listQuery'
import type { RouteFilters } from '@/hooks/filters/routeFilters'

/**
 * The filter keys a dead-end may propose lifting. Range bounds are lifted in pairs:
 * dropping only `minDistance` leaves a half-open range that is not what the user set.
 */
type LiftableKey =
  'distance' | 'elevationGain' | 'hilliness' | 'surfaceType' | 'windDirection' | 'tags'

/** A team's list also filters by tag; the cross-team one has no `tags`, so it never lifts them. */
type DeadEndFilters = RouteFilters & { tags?: string[] }

const LIFTABLE: { key: LiftableKey | 'search'; clears: (keyof DeadEndFilters)[] }[] = [
  { key: 'search', clears: ['search'] },
  { key: 'distance', clears: ['minDistance', 'maxDistance'] },
  { key: 'elevationGain', clears: ['minElevationGain', 'maxElevationGain'] },
  { key: 'hilliness', clears: ['hilliness'] },
  { key: 'surfaceType', clears: ['surfaceType'] },
  { key: 'windDirection', clears: ['windDirection'] },
  { key: 'tags', clears: ['tags'] },
]

interface RouteDeadEndProps {
  filters: DeadEndFilters
  /** Team list when set, cross-team list when not. */
  teamSlug?: string
  onSetFilters: (patch: Partial<DeadEndFilters>) => void
  onClearFilters: () => void
  /** The cross-team list's scope, when off its default: a filter too (RL4, RL10), never lifted alone. */
  scopeLabel?: string
}

/**
 * The "cul-de-sac": a search plus filters that return nothing — the routes' filtered empty state.
 *
 * The one every list has (`FilteredEmptyState`: « Aucun parcours pour ces filtres », the term and
 * the filters named, « Effacer les filtres », RL10), plus what only the routes can say: which single
 * filter brings back the most routes if lifted, and a preview of three of them.
 */
export function RouteDeadEnd({
  filters,
  teamSlug,
  onSetFilters,
  onClearFilters,
  scopeLabel,
}: RouteDeadEndProps) {
  const { t } = useTranslation()

  const active = useMemo(
    () => LIFTABLE.filter((entry) => entry.clears.some((k) => filters[k] !== undefined)),
    [filters]
  )

  const cleared = (entry: (typeof LIFTABLE)[number]) => {
    const next: Record<string, unknown> = { ...filters, page: 0 }
    entry.clears.forEach((k) => {
      next[k] = undefined
    })
    delete next.density
    return next
  }

  // One `useQueries` rather than a hook per filter: the number of active filters changes
  // between renders, and a variable number of hook calls breaks the rules of hooks.
  const counts = useQueries({
    queries: active.map((entry) => {
      const params = cleared(entry)
      return teamSlug
        ? getCountRoutesQueryOptions(teamSlug, params, { request: LIST_REQUEST })
        : getCountAllRoutesQueryOptions(params, { request: LIST_REQUEST })
    }),
  })

  // Keyed on the totals rather than on `counts`, which `useQueries` rebuilds each render.
  const countsSignature = counts.map((c) => c.data?.total).join(',')

  // The single lift that brings back the most routes — nothing if none brings back any.
  const best = useMemo(() => {
    let found: { entry: (typeof LIFTABLE)[number]; total: number } | null = null
    active.forEach((entry, i) => {
      const total = counts[i]?.data?.total ?? 0
      if (total > 0 && (!found || total > found.total)) found = { entry, total }
    })
    return found as { entry: (typeof LIFTABLE)[number]; total: number } | null
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [active, countsSignature])

  // `.map` over a 0-or-1 array rather than a conditional literal: a conditional would infer
  // a tuple type and `useQueries` would reject the one-element branch.
  const previewQueries = useQueries({
    queries: (best ? [best] : []).map((b) => {
      const params = { ...cleared(b.entry), size: 3 }
      return teamSlug
        ? getListRoutesQueryOptions(teamSlug, params, { request: LIST_REQUEST })
        : getListAllRoutesQueryOptions(params, { request: LIST_REQUEST })
    }),
  })
  const preview = previewQueries[0]?.data?.routes ?? []

  const activeLabels = [
    ...active.map((entry) =>
      entry.key === 'search'
        ? searchFilter(t, filters.search ?? '')
        : t(`routes.list.filters.${entry.key satisfies LiftableKey}.label`)
    ),
    ...(scopeLabel ? [scopeLabel] : []),
  ]

  const bestLabel = best
    ? best.entry.key === 'search'
      ? t('routes.deadEnd.searchTerm')
      : t(`routes.list.filters.${best.entry.key satisfies LiftableKey}.label`)
    : ''

  return (
    <Stack gap="md">
      <FilteredEmptyState
        resource="routes"
        filters={activeLabels}
        onClear={onClearFilters}
        extraActions={
          best && (
            <Button
              variant="default"
              onClick={() =>
                onSetFilters(
                  Object.fromEntries([
                    ...best!.entry.clears.map((k) => [k, undefined]),
                    ['page', 0],
                  ])
                )
              }
            >
              {t('routes.deadEnd.removeFilter', { filter: bestLabel })}
            </Button>
          )
        }
      />

      {best && preview.length > 0 && (
        <Paper withBorder radius="md">
          <Stack gap="xs" p="md">
            <Text size="xs" fw={600}>
              {t('routes.deadEnd.previewHeading', { filter: bestLabel, count: best.total })}
            </Text>
            {preview.map((route) => (
              <RouteRow key={route.id} route={route} compact />
            ))}
          </Stack>
        </Paper>
      )}
    </Stack>
  )
}
