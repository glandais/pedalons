// docs/LEDGER_*.md WEB-4: `PUBLIC_UNLISTED` is shareable by link but must not be indexed. The robots
// directive is part of the SSR head block, so it is checked here on the string buildMetaTags emits —
// with the canonical link that only an indexable page carries.
import { describe, it, expect, vi } from 'vitest'
import { QueryClient } from '@tanstack/react-query'
import type { TFunction } from 'i18next'
import type { RideDto, TeamDetailDto, Visibility } from '@/api/dto'
import { getGetTeamQueryKey } from '@/api/endpoints/teams/teams'
import { getGetRideQueryKey } from '@/api/endpoints/rides/rides'
import { buildMetaTags, buildCanonicalUrl, type RouteMetaContext } from '@/lib/seo'
import { rideGroupMeta, rideMeta, routeIndexable, teamDetailMeta, withIndexing } from './routeMeta'
import { pathVariants } from './paths'

vi.mock('@/config/appConfig', () => ({
  isSingleTeam: () => false,
  getPinnedTeamSlug: () => null,
}))

const { routeById } = await import('./routeUtils')

const t = ((key: string) => key) as unknown as TFunction

function context(teamVisibility: Visibility, rideVisibility?: Visibility): RouteMetaContext {
  const queryClient = new QueryClient()
  queryClient.setQueryData(getGetTeamQueryKey('np'), {
    slug: 'np',
    name: 'N Peloton',
    visibility: teamVisibility,
  } as TeamDetailDto)
  if (rideVisibility) {
    queryClient.setQueryData(getGetRideQueryKey('np', 'sortie'), {
      slug: 'sortie',
      name: 'Sortie du dimanche',
      visibility: rideVisibility,
      participantCount: 0,
      team: { slug: 'np', name: 'N Peloton', visibility: teamVisibility, accessible: true },
      // What the backend answers for these visibilities (the sitemap's rule): both PUBLIC.
      permissions: {
        canEdit: false,
        canDelete: false,
        indexable: teamVisibility === 'PUBLIC' && rideVisibility === 'PUBLIC',
      },
    } as unknown as RideDto)
  }
  return {
    queryClient,
    params: { teamSlug: 'np', rideSlug: 'sortie' },
    origin: 'https://pedalons.fr',
    path: '/equipes/np/sorties/sortie',
    locale: 'fr',
    t,
  }
}

/** The whole robots story of a page, as the SSR head block tells it. */
function robotsTags(ctx: RouteMetaContext, meta: ReturnType<typeof rideMeta>): string[] {
  const head = buildMetaTags(withIndexing(meta, ctx), ctx)
  return head.match(/<meta name="robots"[^>]*>/g) ?? []
}

describe('robots directive (WEB-4)', () => {
  it('indexes public content of a public team, with a single robots tag', () => {
    const ctx = context('PUBLIC', 'PUBLIC')
    expect(robotsTags(ctx, rideMeta(ctx))).toEqual([
      '<meta name="robots" content="index, follow" />',
    ])
  })

  it('does not index unlisted content', () => {
    const ctx = context('PUBLIC', 'PUBLIC_UNLISTED')
    expect(robotsTags(ctx, rideMeta(ctx))).toEqual(['<meta name="robots" content="noindex" />'])
  })

  it('does not index public content of an unlisted team', () => {
    const ctx = context('PUBLIC_UNLISTED', 'PUBLIC')
    expect(robotsTags(ctx, rideMeta(ctx))).toEqual(['<meta name="robots" content="noindex" />'])
  })

  it('does not index an unlisted team page', () => {
    const ctx = context('PUBLIC_UNLISTED')
    expect(teamDetailMeta(ctx)?.noindex).toBe(true)
    expect(robotsTags(ctx, teamDetailMeta(ctx))).toEqual([
      '<meta name="robots" content="noindex" />',
    ])
  })

  it('does not index a page of an unlisted team that has no meta() of its own', () => {
    const ctx = context('PUBLIC_UNLISTED')
    expect(robotsTags(ctx, undefined)).toEqual(['<meta name="robots" content="noindex" />'])
  })

  it('indexes a page outside any team', () => {
    const ctx = { ...context('PUBLIC_UNLISTED'), params: {} }
    expect(robotsTags(ctx, undefined)).toEqual(['<meta name="robots" content="index, follow" />'])
  })
})

/**
 * An entity's page follows the backend's `permissions.indexable` and nothing else
 * (docs/LEDGER_*.md WEB-166): the client no longer re-derives it from the visibilities, nor from the
 * team in the cache — which a private team's public content, read by link, does not have.
 */
describe('robots directive of an entity page (WEB-166)', () => {
  function withRide(ctx: RouteMetaContext, patch: Partial<RideDto>): RouteMetaContext {
    const key = getGetRideQueryKey('np', 'sortie')
    const ride = ctx.queryClient.getQueryData<RideDto>(key)!
    ctx.queryClient.setQueryData(key, { ...ride, ...patch })
    return ctx
  }

  it('does not index a page the backend says is not indexable, whatever the visibilities', () => {
    // A draft, or a ride hidden by moderation: both PUBLIC, still not in the sitemap.
    const ctx = withRide(context('PUBLIC', 'PUBLIC'), {
      permissions: { canEdit: false, canDelete: false, indexable: false },
    })
    expect(robotsTags(ctx, rideMeta(ctx))).toEqual(['<meta name="robots" content="noindex" />'])
  })

  it("keeps a private team's public ride, read by link, out of the index (decision D1)", () => {
    const queryClient = new QueryClient()
    // No team in the cache: its loaders never asked for it, `accessible` is false.
    queryClient.setQueryData(getGetRideQueryKey('np', 'sortie'), {
      slug: 'sortie',
      name: 'Sortie du dimanche',
      visibility: 'PUBLIC',
      participantCount: 0,
      team: { slug: 'np', name: 'N Peloton', visibility: 'TEAM', accessible: false },
      permissions: { canEdit: false, canDelete: false, indexable: false },
    } as unknown as RideDto)
    const ctx = { ...context('PUBLIC'), queryClient }
    expect(rideMeta(ctx)?.noindex).toBe(true)
    expect(robotsTags(ctx, rideMeta(ctx))).toEqual(['<meta name="robots" content="noindex" />'])
  })

  it('indexes what the backend calls indexable without looking at the team in the cache', () => {
    // A stale team in the cache must not overrule the entity's own answer.
    const ctx = context('PUBLIC_UNLISTED', 'PUBLIC')
    withRide(ctx, { permissions: { canEdit: false, canDelete: false, indexable: true } })
    expect(robotsTags(ctx, rideMeta(ctx))).toEqual([
      '<meta name="robots" content="index, follow" />',
    ])
  })

  it('still lets a route that is not indexable as such veto the page', () => {
    const ctx = context('PUBLIC', 'PUBLIC')
    const head = buildMetaTags(withIndexing(rideMeta(ctx), ctx, { auth: 'authenticated' }), ctx)
    expect(head).toContain('<meta name="robots" content="noindex" />')
  })
})

describe('ride date in the link preview (WEB-70)', () => {
  it('is the day in Paris, not the SSR server’s UTC day', () => {
    const ctx = context('PUBLIC', 'PUBLIC')
    const ride = ctx.queryClient.getQueryData<RideDto>(getGetRideQueryKey('np', 'sortie'))!
    // 00:30 in Paris on 11 October is still 10 October in UTC.
    ctx.queryClient.setQueryData(getGetRideQueryKey('np', 'sortie'), {
      ...ride,
      dateTime: '2026-10-10T22:30:00Z',
    })
    expect(rideMeta(ctx)?.description).toContain('11 octobre 2026')
  })

  it('is the day in the ride’s own zone (docs/LEDGER_*.md API-60)', () => {
    const ctx = context('PUBLIC', 'PUBLIC')
    const ride = ctx.queryClient.getQueryData<RideDto>(getGetRideQueryKey('np', 'sortie'))!
    // Where Paris would say otherwise: 23:30 UTC on 10 October is the 11th in Paris but the 10th in
    // New York; 16:30 UTC is the 10th in Paris but the 11th in Tokyo.
    ctx.queryClient.setQueryData(getGetRideQueryKey('np', 'sortie'), {
      ...ride,
      dateTime: '2026-10-10T23:30:00Z',
      timezone: 'America/New_York',
    })
    expect(rideMeta(ctx)?.description).toContain('10 octobre 2026')
    ctx.queryClient.setQueryData(getGetRideQueryKey('np', 'sortie'), {
      ...ride,
      dateTime: '2026-10-10T16:30:00Z',
      timezone: 'Asia/Tokyo',
    })
    expect(rideMeta(ctx)?.description).toContain('11 octobre 2026')
  })
})

describe('ride group link preview (WEB-77)', () => {
  function groupContext(groupId: string, rideVisibility: Visibility = 'PUBLIC') {
    const ctx = context('PUBLIC', rideVisibility)
    const ride = ctx.queryClient.getQueryData<RideDto>(getGetRideQueryKey('np', 'sortie'))!
    ctx.queryClient.setQueryData(getGetRideQueryKey('np', 'sortie'), {
      ...ride,
      dateTime: '2026-10-11T06:00:00Z',
      timezone: 'Europe/Paris',
      groups: [
        {
          id: 'g1',
          name: 'Rapide',
          startAt: '2026-10-11T06:30:00Z',
          averageSpeed: 28,
          distance: 82_400,
          countParticipants: 3,
        },
      ],
    })
    return { ...ctx, params: { ...ctx.params, groupId } }
  }

  it('titles the group within its ride and describes its departure, pace and distance', () => {
    const meta = rideGroupMeta(groupContext('g1'))
    // « Rapide » has more than two characters: shown as it is (KIT §9).
    expect(meta?.title).toBe('Rapide · Sortie du dimanche')
    expect(meta?.description).toContain('11 octobre 2026')
    expect(meta?.description).toContain('seo.rideGroup.departure')
    expect(meta?.description).toContain('82 km')
  })

  it('keeps an unlisted ride out of the index', () => {
    const ctx = groupContext('g1', 'PUBLIC_UNLISTED')
    expect(robotsTags(ctx, rideGroupMeta(ctx))).toEqual([
      '<meta name="robots" content="noindex" />',
    ])
  })

  it("falls back to the ride's preview for a group the ride no longer has", () => {
    const ctx = groupContext('gone')
    expect(rideGroupMeta(ctx)).toEqual(rideMeta(ctx))
  })
})

describe('solo ride link preview (WEB-79)', () => {
  it("describes a ride with one group by its group's pace and distance", () => {
    const ctx = context('PUBLIC', 'PUBLIC')
    const ride = ctx.queryClient.getQueryData<RideDto>(getGetRideQueryKey('np', 'sortie'))!
    const solo = { id: 'g1', name: 'Rapide', averageSpeed: 28, distance: 82_400 }
    ctx.queryClient.setQueryData(getGetRideQueryKey('np', 'sortie'), {
      ...ride,
      dateTime: '2026-10-11T06:00:00Z',
      groups: [{ ...solo, countParticipants: 3 }],
    })
    expect(rideMeta(ctx)?.description).toContain('seo.rideGroup.pace')
    expect(rideMeta(ctx)?.description).toContain('82 km')
    ctx.queryClient.setQueryData(getGetRideQueryKey('np', 'sortie'), {
      ...ride,
      dateTime: '2026-10-11T06:00:00Z',
      groups: [solo, { ...solo, id: 'g2' }],
    })
    expect(rideMeta(ctx)?.description).not.toContain('82 km')
  })
})

describe('canonical link', () => {
  const origin = 'https://club.example'
  const ride = pathVariants.ride(':teamSlug', ':rideSlug')
  const params = { teamSlug: 'np', rideSlug: 'sortie' }

  it('always declares the French path, whichever variant or language was served', () => {
    // No locale argument at all: the canonical cannot depend on the cookie or Accept-Language.
    expect(buildCanonicalUrl(ride, params, origin)).toBe(
      'https://club.example/equipes/np/sorties/sortie'
    )
  })

  it('encodes params', () => {
    expect(buildCanonicalUrl(ride, { teamSlug: 'np', rideSlug: 'été' }, origin)).toBe(
      'https://club.example/equipes/np/sorties/%C3%A9t%C3%A9'
    )
  })

  it('emits nothing it cannot rebuild, and falls back to the only locale a route has', () => {
    expect(buildCanonicalUrl(ride, { teamSlug: 'np' }, origin)).toBeUndefined()
    expect(buildCanonicalUrl({ en: '/teams/:teamSlug' }, { teamSlug: 'np' }, origin)).toBe(
      'https://club.example/teams/np'
    )
  })

  it('drops a pinned-host path the host would not route back to the same page', () => {
    const pinned = {
      toBrowser: (p: string) => p.replace('/equipes/np', ''),
      toRouter: (p: string) => p,
    }
    expect(buildCanonicalUrl(ride, params, origin, pinned)).toBeUndefined()
  })

  function head(ctx: RouteMetaContext, meta: ReturnType<typeof rideMeta>): string {
    const withLinks = { ...ctx, canonical: buildCanonicalUrl(ride, params, ctx.origin) }
    return buildMetaTags(withIndexing(meta, withLinks), withLinks)
  }

  it('puts the canonical and og:url on an indexable page, no hreflang, never a query string', () => {
    for (const locale of ['fr', 'en'] as const) {
      const ctx = { ...context('PUBLIC', 'PUBLIC'), locale, path: '/teams/np/rides/sortie' }
      const tags = head(ctx, rideMeta(ctx))
      expect(tags.match(/<link rel="canonical"[^>]*>/g)).toEqual([
        '<link rel="canonical" href="https://pedalons.fr/equipes/np/sorties/sortie" />',
      ])
      expect(tags).not.toContain('hreflang')
      expect(tags).toContain(
        '<meta property="og:url" content="https://pedalons.fr/equipes/np/sorties/sortie" />'
      )
      expect(tags).not.toContain('?')
    }
  })

  it('puts no canonical on a noindex page', () => {
    const ctx = context('PUBLIC', 'PUBLIC_UNLISTED')
    const tags = head(ctx, rideMeta(ctx))
    expect(tags).toContain('<meta name="robots" content="noindex" />')
    expect(tags).not.toContain('rel="canonical"')
  })
})

describe('routes kept out of the index', () => {
  const route = (id: string) => {
    const config = routeById.get(id)
    if (!config) throw new Error(`no route ${id}`)
    return config
  }

  it.each([
    'login',
    'forgot-password',
    'reset-password',
    'verify-email',
    'invitation',
    'biketeam-migration',
    'oauth-authorize',
    'device-verify-garmin',
    'device-verify-karoo',
    'device-hammerhead',
    'teams-new',
    'profile',
    'calendar',
    'team-settings',
    'ride-edit',
    'all-routes',
    'all-routes-map',
    'routes',
    'routes-map',
    'gpx-tools-view',
    'gpx-tools-map',
    'gpx-tools-blank-map',
  ])('%s is noindex', (id) => {
    expect(routeIndexable(route(id))).toBe(false)
    const ctx = { ...context('PUBLIC'), params: {} }
    expect(robotsTags(ctx, undefined)).toEqual(['<meta name="robots" content="index, follow" />'])
    expect(buildMetaTags(withIndexing(undefined, ctx, route(id)), ctx)).toContain(
      '<meta name="robots" content="noindex" />'
    )
  })

  it.each([
    'home',
    'teams',
    'team-detail',
    'team-about',
    'team-page',
    'ride-detail',
    'post-detail',
    'trip-detail',
    'stage-detail',
    'route-detail',
    'route-map',
    'features',
    'apps',
  ])('%s stays indexable', (id) => {
    expect(routeIndexable(route(id))).toBe(true)
  })

  // An entity's page leans on its own `permissions.indexable`: without a meta(), withIndexing
  // falls back on the team in the cache, which a private team's content read by link does not
  // have — the page would come out indexable (decision D1, docs/LEDGER_*.md WEB-166).
  it('gives every indexable route of an entity a meta() of its own', () => {
    const withoutMeta = [...routeById.values()]
      .filter((config) => routeIndexable(config) && !config.meta)
      .filter((config) =>
        Object.values(config.paths).some((path) =>
          (String(path).match(/:\w+/g) ?? []).some((param) => param !== ':teamSlug')
        )
      )
      .map((config) => config.id)
    expect(withoutMeta).toEqual([])
  })
})
