import { useCallback, useMemo, useRef } from 'react'
import { useLocation, useSearchParams } from 'react-router-dom'
import type { z } from 'zod'

type AnyFiltersSchema = z.ZodObject<z.ZodRawShape>

export interface UseUrlFiltersOptions<S extends AnyFiltersSchema> {
  /** Keys are API param names; every field needs a `.default()` or `.optional()`. */
  schema: S
  /** API param name -> short URL key. Unlisted keys keep their own name. */
  alias?: Partial<Record<keyof z.infer<S> & string, string>>
  /**
   * Keys written to the URL even when they equal their default. Needed when the
   * default itself is context-dependent (e.g. derived from auth), so a shared
   * link resolves the same way for everyone.
   */
  alwaysSerialize?: ReadonlyArray<keyof z.infer<S> & string>
}

export interface UseUrlFiltersResult<S extends AnyFiltersSchema> {
  filters: z.infer<S>
  /** Merge into the current filters. Resets `page` unless the patch sets it. */
  setFilters: (patch: Partial<z.infer<S>>) => void
  /** Replace every filter. Omitted keys fall back to their default. */
  replaceFilters: (next: Partial<z.infer<S>>) => void
  defaults: z.infer<S>
}

/**
 * The filters a query string resolves to — the same reading the hook does, exposed so a route's
 * `prefetch` can fill the cache for the URL that was actually requested.
 *
 * Not duplicated on the prefetch side: the alias mapping (`p`, `q`, `w`…) and the
 * empty-param-is-an-absent-param rule below have to be applied identically, or a shared link with
 * filters would prefetch one variant and render another.
 */
export function readUrlFilters<S extends AnyFiltersSchema>(
  params: URLSearchParams,
  { schema, alias }: Pick<UseUrlFiltersOptions<S>, 'schema' | 'alias'>
): z.infer<S> {
  const raw: Record<string, string> = {}
  for (const apiKey of Object.keys(schema.shape)) {
    const value = params.get((alias as Record<string, string> | undefined)?.[apiKey] ?? apiKey)
    // An empty param is an absent param: `z.coerce.number()` turns '' into 0.
    if (value !== null && value !== '') raw[apiKey] = value
  }
  return schema.parse(raw) as z.infer<S>
}

/**
 * Binds a page's filters to the query string, making them survive navigation
 * and shareable as a link.
 *
 * Values equal to their default are omitted from the URL, which also keeps the
 * per-page `size` constant out of it while still returning it in `filters`.
 * Every write is a history `replace`, so typing in a search box does not bury
 * the previous page under one history entry per keystroke.
 */
export function useUrlFilters<S extends AnyFiltersSchema>({
  schema,
  alias,
  alwaysSerialize,
}: UseUrlFiltersOptions<S>): UseUrlFiltersResult<S> {
  const [searchParams, setSearchParams] = useSearchParams()

  const keys = useMemo(() => Object.keys(schema.shape), [schema])
  const defaults = useMemo(() => schema.parse({}) as z.infer<S>, [schema])
  const forced = useMemo(() => new Set<string>(alwaysSerialize ?? []), [alwaysSerialize])

  const toUrlKey = useCallback(
    (apiKey: string) => (alias as Record<string, string> | undefined)?.[apiKey] ?? apiKey,
    [alias]
  )

  const read = useCallback(
    (params: URLSearchParams): z.infer<S> => readUrlFilters(params, { schema, alias }),
    [schema, alias]
  )

  const ownUrlKeys = useMemo(() => new Set(keys.map(toUrlKey)), [keys, toUrlKey])

  // Builds on `base`'s params this hook does not own: two of them on one page (a group's
  // participants and its map's colour mode) each keep the other's.
  const serialize = useCallback(
    (next: Record<string, unknown>, base: URLSearchParams): URLSearchParams => {
      const defaultValues = defaults as Record<string, unknown>
      const params = new URLSearchParams()
      for (const [key, value] of base) {
        if (!ownUrlKeys.has(key)) params.append(key, value)
      }
      for (const apiKey of keys) {
        const value = next[apiKey]
        if (value === undefined || value === null || value === '') continue
        if (value === defaultValues[apiKey] && !forced.has(apiKey)) continue
        params.set(toUrlKey(apiKey), String(value))
      }
      return params
    },
    [keys, defaults, forced, toUrlKey, ownUrlKeys]
  )

  const filters = useMemo(() => read(searchParams), [read, searchParams])

  // Every write is a navigation, and the route's loader awaits its prefetch before the location
  // changes: until then the rendered `searchParams` — which is also what React Router hands to the
  // functional `setSearchParams(previous => …)` form — still shows the query string *before* our
  // last write. Two changes in quick succession (a sort, then a price bound) would each be built
  // on that stale string, and the second would silently drop the first.
  //
  // So the hook remembers the query strings it asked for and has not seen rendered yet, and builds
  // each write on the last of them. They are forgotten as soon as the location reaches the last
  // one, or moves somewhere we never asked for (back/forward, a link, a cancelled navigation).
  const { pathname } = useLocation()
  const rendered = `${pathname}?${searchParams.toString()}`
  const renderedRef = useRef(rendered)
  renderedRef.current = rendered
  const pendingRef = useRef<{ base: string; targets: string[] } | null>(null)

  const latestParams = useCallback((): URLSearchParams => {
    const current = renderedRef.current
    const pending = pendingRef.current
    if (pending) {
      const reached = pending.targets.indexOf(current)
      if (reached === pending.targets.length - 1) {
        pendingRef.current = null
      } else if (reached >= 0) {
        // An intermediate write landed; the later ones are still in flight.
        pendingRef.current = { base: current, targets: pending.targets.slice(reached + 1) }
      } else if (current !== pending.base) {
        pendingRef.current = null
      }
    }
    const target = pendingRef.current?.targets.at(-1) ?? current
    return new URLSearchParams(target.slice(target.indexOf('?') + 1))
  }, [])

  const commit = useCallback(
    (params: URLSearchParams) => {
      const current = renderedRef.current
      const target = `${current.slice(0, current.indexOf('?'))}?${params.toString()}`
      const pending = pendingRef.current
      pendingRef.current = pending
        ? { base: pending.base, targets: [...pending.targets, target] }
        : { base: current, targets: [target] }
      setSearchParams(params, { replace: true })
    },
    [setSearchParams]
  )

  const setFilters = useCallback(
    (patch: Partial<z.infer<S>>) => {
      // Rebuild from the latest params we asked for rather than a captured `filters`, so a
      // debounced search commit racing a page change never clobbers it (nor the reverse).
      const base = latestParams()
      const next = { ...read(base), ...patch } as Record<string, unknown>
      if (!('page' in patch) && 'page' in next) {
        next.page = (defaults as Record<string, unknown>).page
      }
      commit(serialize(next, base))
    },
    [latestParams, commit, read, serialize, defaults]
  )

  const replaceFilters = useCallback(
    (next: Partial<z.infer<S>>) => {
      // Builds on none of its own filters, but still goes through `commit` so a later `setFilters`
      // builds on it.
      commit(serialize(next as Record<string, unknown>, latestParams()))
    },
    [latestParams, commit, serialize]
  )

  return { filters, setFilters, replaceFilters, defaults }
}
