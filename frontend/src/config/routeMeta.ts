// Per-route Open Graph / Twitter `meta()` builders, co-located here (referenced from
// routes.config.ts) to keep the route table readable. Each runs during SSR AFTER the route's
// prefetch has populated the per-request QueryClient, so it only READS the cache — zero extra
// fetches. A missing entity, or a private one the visitor's session doesn't grant (including
// crawlers and other anonymous SSR renders), returns undefined, and buildMetaTags then emits
// site-wide defaults. Builders must never throw.
import type {
  GpxPreviewDto,
  PostDto,
  RouteDetailDto,
  TeamDetailDto,
  TeamPageDto,
  TripDto,
  RideDto,
  RideGroupDto,
} from '@/api/dto'
import type { Instant, Visibility } from '@/api/dto'
import type { Locale } from '@/config/paths'
import type { RouteConfig } from '@/config/routes.types'
import {
  buildMetaTags as _buildMetaTags,
  defaultImage,
  imgFromAsset,
  imgFromAssets,
  imgFromTemplate,
  stripMarkdown,
  truncate,
  type RouteMeta,
  type RouteMetaContext,
  type RouteMetaFn,
} from '@/lib/seo'
import { getGetTeamQueryKey } from '@/api/endpoints/teams/teams'
import { getGetRideQueryKey } from '@/api/endpoints/rides/rides'
import { getGetTripQueryKey } from '@/api/endpoints/trips/trips'
import { getGetPostQueryKey } from '@/api/endpoints/posts/posts'
import { getGetRouteQueryKey } from '@/api/endpoints/routes/routes'
import { getGetPageQueryKey } from '@/api/endpoints/team-pages/team-pages'
import { getGetPreviewQueryKey } from '@/api/endpoints/gpx-previews/gpx-previews'
import { soloGroup } from '@/utils/soloGroup'

// Re-export so routes.config.ts imports its meta wiring from one module.
export const buildMetaTags = _buildMetaTags

const appNameOf = (ctx: RouteMetaContext): string => ctx.config?.appName || 'Pédalons'

/**
 * Only `PUBLIC` is indexable. `PUBLIC_UNLISTED` is readable by anyone holding the link but must
 * stay out of search engines; `TEAM` only renders for a member's session, never for a crawler, and
 * is not indexable either. docs/LEDGER_*.md WEB-4.
 */
const notIndexable = (visibility: Visibility | undefined): boolean =>
  visibility !== undefined && visibility !== 'PUBLIC'

/**
 * Whether a route may be indexed at all, before its content is looked at: only a public page that
 * is not flagged `noindex`. A members-only page renders a sign-in redirect for a crawler, and an
 * `unauthenticated` one (sign-in, forgotten password) is a form with nothing to index.
 */
export function routeIndexable(route: Pick<RouteConfig, 'auth' | 'noindex'>): boolean {
  return route.auth === 'public' && !route.noindex
}

/**
 * The robots decision for the whole request, applied by entry-server on top of the route's own
 * `meta()`: a page is `noindex` when its content says so, when its route is not indexable
 * ({@link routeIndexable}), **or** when it belongs to a team that is not `PUBLIC` — every
 * team-scoped page (lists, calendar, members…, most of which have no `meta()`) has the team in the
 * per-request cache, since entry-server reads it for the 404/301 decision. Never throws.
 */
export function withIndexing(
  meta: RouteMeta | undefined,
  ctx: RouteMetaContext,
  route?: Pick<RouteConfig, 'auth' | 'noindex'>
): RouteMeta | undefined {
  const teamSlug = ctx.params.teamSlug
  const team = teamSlug
    ? ctx.queryClient.getQueryData<TeamDetailDto>(getGetTeamQueryKey(teamSlug))
    : undefined
  if (meta?.noindex) return meta
  if (!notIndexable(team?.visibility) && (!route || routeIndexable(route))) return meta
  return { ...meta, noindex: true }
}

/**
 * Zone of the dates in titles and link previews. Rendered by the SSR server, whose zone is UTC, and
 * read by anyone the link is shared with: neither the server's zone nor the reader's is the ride's
 * — the entity's own is the only one that makes sense (docs/LEDGER_*.md WEB-70, API-60, plan §7).
 * Paris only for a payload without one.
 */
const META_FALLBACK_TIME_ZONE = 'Europe/Paris'

/** Localised long date (day + month + year), matching the resolved SSR locale — not the browser. */
function formatDate(
  instant: Instant | undefined,
  locale: Locale,
  timeZone: string | undefined
): string | undefined {
  if (!instant) return undefined
  const d = new Date(instant)
  if (Number.isNaN(d.getTime())) return undefined
  const format = (zone: string) =>
    new Intl.DateTimeFormat(locale === 'en' ? 'en-GB' : 'fr-FR', {
      day: 'numeric',
      month: 'long',
      year: 'numeric',
      timeZone: zone,
    }).format(d)
  // A meta builder never throws: an identifier this runtime does not know falls back.
  try {
    return format(timeZone || META_FALLBACK_TIME_ZONE)
  } catch {
    return format(META_FALLBACK_TIME_ZONE)
  }
}

/** Localised time of day (« 08:30 »), in the entity's zone like {@link formatDate}. */
function formatTime(
  instant: Instant | undefined,
  locale: Locale,
  timeZone: string | undefined
): string | undefined {
  if (!instant) return undefined
  const d = new Date(instant)
  if (Number.isNaN(d.getTime())) return undefined
  const format = (zone: string) =>
    new Intl.DateTimeFormat(locale === 'en' ? 'en-GB' : 'fr-FR', {
      hour: '2-digit',
      minute: '2-digit',
      timeZone: zone,
    }).format(d)
  try {
    return format(timeZone || META_FALLBACK_TIME_ZONE)
  } catch {
    return format(META_FALLBACK_TIME_ZONE)
  }
}

/** ISO-8601 publication time, preferring the explicit publish time over creation. */
function publishedTime(publishAt?: Instant, createdAt?: Instant): string | undefined {
  return publishAt ?? createdAt ?? undefined
}

/** km, one decimal under 10 km, whole numbers above. */
function formatKm(meters: number): string {
  const km = meters / 1000
  return km < 10 ? km.toFixed(1) : String(Math.round(km))
}

/** A short club-content fallback description built from structured fields. */
function joinFacets(parts: (string | undefined | false)[]): string {
  return parts.filter((p): p is string => Boolean(p)).join(' · ')
}

// === home ===================================================================================
export const homeMeta: RouteMetaFn = (ctx) => {
  const appName = appNameOf(ctx)
  return {
    type: 'website',
    title: truncate(`${appName} · ${ctx.t('home.subtitle')}`, 65),
    description: ctx.t('home.subtitle'),
    image: defaultImage(ctx.origin, appName),
  }
}

// === apps ====================================================================================
export const appsMeta: RouteMetaFn = (ctx) => {
  const appName = appNameOf(ctx)
  return {
    type: 'website',
    title: truncate(`${ctx.t('apps.title')} · ${appName}`, 65),
    description: ctx.t('apps.subtitle'),
    image: defaultImage(ctx.origin, appName),
  }
}

// === features ================================================================================
export const featuresMeta: RouteMetaFn = (ctx) => {
  const appName = appNameOf(ctx)
  return {
    type: 'website',
    title: truncate(`${ctx.t('features.meta.title')} · ${appName}`, 65),
    description: ctx.t('features.meta.description'),
    image: defaultImage(ctx.origin, appName),
  }
}

// === teams (list) ===========================================================================
export const teamsMeta: RouteMetaFn = (ctx) => {
  const appName = appNameOf(ctx)
  return {
    type: 'website',
    title: truncate(`${ctx.t('teams.title')} · ${appName}`, 65),
    description: ctx.t('home.subtitle'),
    image: defaultImage(ctx.origin, appName),
  }
}

/** Shared team title/description/image resolver used by team-detail and team-about. */
function teamBase(team: TeamDetailDto, ctx: RouteMetaContext) {
  const appName = appNameOf(ctx)
  const stripped = stripMarkdown(team.about?.markdown ?? '')
  const description = stripped
    ? truncate(stripped, 200)
    : ctx.t('seo.team.description', { name: team.name, appName })
  const image =
    imgFromAsset(ctx.origin, team.about?.assets?.logo, team.name) ??
    imgFromAssets(ctx.origin, team.about?.assets, team.name) ??
    defaultImage(ctx.origin, appName)
  return { description, image }
}

// === team-detail ============================================================================
export const teamDetailMeta: RouteMetaFn = (ctx) => {
  const team = ctx.queryClient.getQueryData<TeamDetailDto>(getGetTeamQueryKey(ctx.params.teamSlug!))
  if (!team) return undefined
  const appName = appNameOf(ctx)
  const composed = `${team.name} · ${appName}`
  const title = team.name.length > 60 ? truncate(team.name, 65) : truncate(composed, 70)
  return { type: 'website', title, ...teamBase(team, ctx), noindex: notIndexable(team.visibility) }
}

// === team-about =============================================================================
export const teamAboutMeta: RouteMetaFn = (ctx) => {
  const team = ctx.queryClient.getQueryData<TeamDetailDto>(getGetTeamQueryKey(ctx.params.teamSlug!))
  if (!team) return undefined
  const base = teamBase(team, ctx)
  return {
    type: 'website',
    title: truncate(ctx.t('seo.teamAbout.title', { name: team.name }), 65),
    description: base.description,
    image: { ...base.image, alt: ctx.t('seo.teamAbout.imageAlt', { name: team.name }) },
    noindex: notIndexable(team.visibility),
  }
}

// === team-page ==============================================================================
export const teamPageMeta: RouteMetaFn = (ctx) => {
  const page = ctx.queryClient.getQueryData<TeamPageDto>(
    getGetPageQueryKey(ctx.params.teamSlug!, ctx.params.pageSlug!)
  )
  if (!page) return undefined
  const team = ctx.queryClient.getQueryData<TeamDetailDto>(getGetTeamQueryKey(ctx.params.teamSlug!))
  const teamName = page.team?.name ?? team?.name ?? appNameOf(ctx)
  const stripped = stripMarkdown(page.media?.markdown ?? '')
  const composed = `${page.title} · ${teamName}`
  return {
    type: 'article',
    title: page.title.length > 60 ? truncate(page.title, 65) : truncate(composed, 70),
    description: stripped
      ? truncate(stripped, 180)
      : ctx.t('seo.teamPage.description', { page: page.title, team: teamName }),
    image:
      imgFromAssets(ctx.origin, page.media?.assets, page.title) ??
      imgFromAsset(ctx.origin, team?.about?.assets?.logo, teamName) ??
      defaultImage(ctx.origin, appNameOf(ctx)),
    noindex: notIndexable(page.visibility),
  }
}

// === post-detail ============================================================================
export const postMeta: RouteMetaFn = (ctx) => {
  const post = ctx.queryClient.getQueryData<PostDto>(
    getGetPostQueryKey(ctx.params.teamSlug!, ctx.params.postSlug!)
  )
  if (!post) return undefined
  const team = ctx.queryClient.getQueryData<TeamDetailDto>(getGetTeamQueryKey(ctx.params.teamSlug!))
  const teamName = post.team?.name ?? appNameOf(ctx)
  const stripped = stripMarkdown(post.media?.markdown ?? '')
  const alt = `${post.name} — ${teamName}`
  return {
    type: 'article',
    title: truncate(post.name || appNameOf(ctx), 65),
    description: stripped ? truncate(stripped, 180) : `${post.name} · ${teamName}`,
    siteName: teamName,
    image:
      imgFromAssets(ctx.origin, post.media?.assets, alt) ??
      imgFromAsset(ctx.origin, team?.about?.assets?.logo, alt) ??
      defaultImage(ctx.origin, appNameOf(ctx)),
    article: { publishedTime: publishedTime(post.publishAt, post.createdAt) },
    noindex: notIndexable(post.visibility),
  }
}

// === ride-detail ============================================================================
export const rideMeta: RouteMetaFn = (ctx) => {
  const ride = ctx.queryClient.getQueryData<RideDto>(
    getGetRideQueryKey(ctx.params.teamSlug!, ctx.params.rideSlug!)
  )
  if (!ride) return undefined
  const team = ctx.queryClient.getQueryData<TeamDetailDto>(getGetTeamQueryKey(ctx.params.teamSlug!))
  const teamName = ride.team?.name ?? appNameOf(ctx)
  const title =
    ride.name.length < 48 ? truncate(`${ride.name} · ${teamName}`, 65) : truncate(ride.name, 65)

  const stripped = stripMarkdown(ride.media?.markdown ?? '')
  // A solo ride's page is its group's (WEB-79): the group's facts stand in for the ride's count.
  const solo = soloGroup(ride)
  const description = stripped
    ? truncate(stripped, 200)
    : joinFacets([
        formatDate(ride.dateTime, ctx.locale, ride.timezone),
        ride.startPlace?.name && `${ctx.t('seo.ride.startPrefix')}${ride.startPlace.name}`,
        ...(solo
          ? groupFacts(solo, ride, ctx)
          : [
              ride.participantCount > 0 &&
                ctx.t('seo.ride.participants', { count: ride.participantCount }),
            ]),
      ])

  const alt = truncate(ctx.t('seo.ride.imageAlt', { name: ride.name, team: teamName }), 100)
  return {
    type: 'article',
    title,
    description,
    image:
      imgFromTemplate(ctx.origin, ride.thumbnailLightUrl, alt) ??
      imgFromAssets(ctx.origin, ride.media?.assets, alt) ??
      imgFromAsset(ctx.origin, team?.about?.assets?.logo, alt) ??
      defaultImage(ctx.origin, appNameOf(ctx)),
    article: { publishedTime: publishedTime(ride.publishAt, ride.createdAt) },
    noindex: notIndexable(ride.visibility),
  }
}

// === ride-group =============================================================================
/**
 * A group's facts for a preview: its departure, pace, distance and riders — the group page's
 * description, and a solo ride's (ledger WEB-79), whose page is its group's.
 */
function groupFacts(group: RideGroupDto, ride: RideDto, ctx: RouteMetaContext) {
  return [
    group.startAt &&
      ctx.t('seo.rideGroup.departure', {
        time: formatTime(group.startAt, ctx.locale, ride.timezone),
      }),
    !!group.averageSpeed && ctx.t('seo.rideGroup.pace', { speed: Math.round(group.averageSpeed) }),
    group.distance !== undefined && `${formatKm(group.distance)} km`,
    group.countParticipants > 0 &&
      ctx.t('seo.ride.participants', { count: group.countParticipants }),
  ]
}

export const rideGroupMeta: RouteMetaFn = (ctx) => {
  const ride = ctx.queryClient.getQueryData<RideDto>(
    getGetRideQueryKey(ctx.params.teamSlug!, ctx.params.rideSlug!)
  )
  const group = ride?.groups?.find((g) => g.id === ctx.params.groupId)
  // A group the ride no longer has falls back to the ride's own preview.
  if (!ride || !group) return rideMeta(ctx)
  const team = ctx.queryClient.getQueryData<TeamDetailDto>(getGetTeamQueryKey(ctx.params.teamSlug!))
  const teamName = ride.team?.name ?? appNameOf(ctx)
  const groupTitle = ctx.t('rides.group.title', { name: group.name })

  const description = joinFacets([
    formatDate(group.startAt ?? ride.dateTime, ctx.locale, ride.timezone),
    ...groupFacts(group, ride, ctx),
  ])

  const alt = truncate(
    ctx.t('seo.rideGroup.imageAlt', { group: group.name, name: ride.name, team: teamName }),
    100
  )
  return {
    type: 'article',
    title: truncate(`${groupTitle} · ${ride.name}`, 65),
    description,
    image:
      imgFromTemplate(ctx.origin, ride.thumbnailLightUrl, alt) ??
      imgFromAssets(ctx.origin, ride.media?.assets, alt) ??
      imgFromAsset(ctx.origin, team?.about?.assets?.logo, alt) ??
      defaultImage(ctx.origin, appNameOf(ctx)),
    article: { publishedTime: publishedTime(ride.publishAt, ride.createdAt) },
    noindex: notIndexable(ride.visibility),
  }
}

// === trip-detail ============================================================================
export const tripMeta: RouteMetaFn = (ctx) => {
  const trip = ctx.queryClient.getQueryData<TripDto>(
    getGetTripQueryKey(ctx.params.teamSlug!, ctx.params.tripSlug!)
  )
  if (!trip) return undefined
  const team = ctx.queryClient.getQueryData<TeamDetailDto>(getGetTeamQueryKey(ctx.params.teamSlug!))
  const teamName = trip.team?.name ?? appNameOf(ctx)

  const stripped = stripMarkdown(trip.media?.markdown ?? '')
  const description = stripped
    ? truncate(stripped, 200)
    : joinFacets([
        trip.stageCount > 0 && ctx.t('seo.trip.stages', { count: trip.stageCount }),
        formatDate(trip.dateTime, ctx.locale, trip.timezone) &&
          `${ctx.t('seo.trip.startPrefix')}${formatDate(trip.dateTime, ctx.locale, trip.timezone)}`,
        trip.participantCount > 0 &&
          ctx.t('seo.ride.participants', { count: trip.participantCount }),
      ])

  const alt = ctx.t('seo.trip.imageAlt', { name: trip.name })
  return {
    type: 'article',
    title:
      trip.name.length > 60 ? truncate(trip.name, 65) : truncate(`${trip.name} · ${teamName}`, 70),
    description,
    image:
      imgFromTemplate(ctx.origin, trip.thumbnailLightUrl, alt) ??
      imgFromAssets(ctx.origin, trip.media?.assets, alt) ??
      imgFromAsset(ctx.origin, team?.about?.assets?.logo, alt) ??
      defaultImage(ctx.origin, appNameOf(ctx)),
    article: {
      publishedTime: publishedTime(trip.publishAt, trip.createdAt),
      section: ctx.t('seo.trip.section'),
    },
    noindex: notIndexable(trip.visibility),
  }
}

// === stage-detail ===========================================================================
export const stageMeta: RouteMetaFn = (ctx) => {
  const trip = ctx.queryClient.getQueryData<TripDto>(
    getGetTripQueryKey(ctx.params.teamSlug!, ctx.params.tripSlug!)
  )
  if (!trip) return undefined
  const stage = trip.stages?.find((s) => s.slug === ctx.params.stageSlug)
  const team = ctx.queryClient.getQueryData<TeamDetailDto>(getGetTeamQueryKey(ctx.params.teamSlug!))
  const teamName = trip.team?.name ?? appNameOf(ctx)

  // Stage deleted/renamed since prefetch: degrade to the parent trip's preview.
  if (!stage) {
    return {
      type: 'article',
      title: truncate(trip.name, 65),
      description: truncate(stripMarkdown(trip.media?.markdown ?? ''), 180) || trip.name,
      image:
        imgFromTemplate(ctx.origin, trip.thumbnailLightUrl, trip.name) ??
        imgFromAssets(ctx.origin, trip.media?.assets, trip.name) ??
        defaultImage(ctx.origin, appNameOf(ctx)),
      noindex: notIndexable(trip.visibility),
    }
  }

  const alt = `${stage.name} — ${trip.name}`
  const stripped = stripMarkdown(stage.media?.markdown ?? '')
  const description = stripped
    ? truncate(stripped, 180)
    : joinFacets([
        stage.route && `${formatKm(stage.route.distance)} km`,
        stage.route && `${Math.round(stage.route.elevationGain)} m ${ctx.t('seo.elevation')}`,
        stage.startPlace?.name &&
          stage.endPlace?.name &&
          `${stage.startPlace.name} → ${stage.endPlace.name}`,
      ]) || ctx.t('seo.stage.description', { trip: trip.name })

  return {
    type: 'article',
    title: truncate(`${stage.name} · ${trip.name}`, 65),
    description,
    image:
      imgFromAsset(ctx.origin, stage.route?.media?.assets?.thumbnailLight, alt) ??
      imgFromAsset(ctx.origin, stage.media?.assets?.logo, alt) ??
      imgFromTemplate(ctx.origin, trip.thumbnailLightUrl, alt) ??
      imgFromAssets(ctx.origin, trip.media?.assets, alt) ??
      imgFromAsset(ctx.origin, team?.about?.assets?.logo, alt) ??
      defaultImage(ctx.origin, appNameOf(ctx)),
    article: {
      publishedTime: publishedTime(trip.publishAt, trip.createdAt),
      section: trip.name,
      author: teamName,
    },
    // A stage has no visibility of its own: it is its trip's.
    noindex: notIndexable(trip.visibility),
  }
}

// === route-detail ===========================================================================
export const routeMeta: RouteMetaFn = (ctx) => {
  const route = ctx.queryClient.getQueryData<RouteDetailDto>(
    getGetRouteQueryKey(ctx.params.teamSlug!, ctx.params.routeSlug!)
  )
  if (!route) return undefined
  const team = ctx.queryClient.getQueryData<TeamDetailDto>(getGetTeamQueryKey(ctx.params.teamSlug!))
  const teamName = route.team?.name

  const surfaceLabel = ctx.t(
    `routes.surfaceType.${route.surfaceType satisfies 'ROAD' | 'GRAVEL' | 'MTB' | 'MIXED'}`
  )
  const stats = `${formatKm(route.distance)} km · ${Math.round(route.elevationGain)} m ${ctx.t('seo.elevation')} · ${surfaceLabel}`
  const intro = stripMarkdown(route.media?.markdown ?? '')
  const description = truncate(intro ? `${stats} — ${intro}` : stats, 200)

  const alt = ctx.t('seo.route.imageAlt', { name: route.name })
  return {
    type: 'website',
    title: teamName ? truncate(`${route.name} · ${teamName}`, 65) : truncate(route.name, 65),
    description,
    image:
      imgFromAsset(ctx.origin, route.media?.assets?.thumbnailLight, alt) ??
      imgFromAsset(ctx.origin, team?.about?.assets?.logo, route.name) ??
      defaultImage(ctx.origin, appNameOf(ctx)),
    noindex: notIndexable(route.visibility),
  }
}

// No ad builder: `ad-detail` is a member-only route (the ad API is `@RolesAllowed("user")`), and
// every unfurl crawler is anonymous — there is no cache for a builder to read. See docs/LINK_PREVIEW.md.

// === gpx-tools-view =========================================================================
export const gpxPreviewMeta: RouteMetaFn = (ctx) => {
  const preview = ctx.queryClient.getQueryData<GpxPreviewDto>(
    getGetPreviewQueryKey(ctx.params.previewId!)
  )
  if (!preview) return undefined
  const appName = appNameOf(ctx)
  const km = formatKm(preview.distance)
  const name = preview.name?.trim() || ctx.t('gpxTools.preview.title')
  const alt = ctx.t('seo.gpx.imageAlt', { name, km, appName })

  return {
    type: 'website',
    title: truncate(`${name} · ${km} km — ${appName}`, 65),
    description: `${ctx.t('seo.gpx.stats', {
      km,
      gain: Math.round(preview.elevationGain),
      loss: Math.round(preview.elevationLoss),
    })} · ${Math.round(preview.hilliness)} m/km — ${ctx.t('seo.gpx.sharedVia', { appName })}`,
    image: imgFromTemplate(ctx.origin, preview.thumbnailUrl, alt) ?? {
      ...defaultImage(ctx.origin, appName),
      alt,
    },
  }
}
