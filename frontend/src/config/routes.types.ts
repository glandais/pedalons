import type { ComponentType, LazyExoticComponent } from 'react'
import type { QueryClient } from '@tanstack/react-query'
import type { Locale } from './paths'
import type { RouteMetaFn } from '@/lib/seo'
import type { TranslationKey } from '@/lib/i18nUtils'

/**
 * Authentication requirement for a route
 */
export type AuthRequirement = 'public' | 'authenticated' | 'unauthenticated'

/**
 * Parameter definitions for dynamic segments
 */
export interface RouteParams {
  teamSlug?: string
  rideSlug?: string
  postSlug?: string
  tripSlug?: string
  stageSlug?: string
  routeSlug?: string
  templateSlug?: string
  adSlug?: string
  pageSlug?: string
  previewId?: string
}

/**
 * Entity types that can provide dynamic breadcrumb labels
 */
export type EntityType =
  'team' | 'ride' | 'post' | 'trip' | 'stage' | 'route' | 'rideTemplate' | 'ad' | 'teamPage'

/**
 * Breadcrumb label configuration
 * - Static: i18n key string (e.g., "common:teams")
 * - Dynamic: object with entity type to fetch name from
 */
export type BreadcrumbLabel =
  { type: 'static'; i18nKey: TranslationKey } | { type: 'dynamic'; entity: EntityType }

/**
 * A shared navigation group whose (runtime-gated) items feed a breadcrumb crumb's dropdown.
 * - 'home': the top-level sections (feed, teams, calendar, routes)
 * - 'team': the team sections (publications, calendar, routes, ads, about, dynamic pages)
 */
export type NavGroup = 'home' | 'team'

/**
 * Single route configuration entry
 */
export interface RouteConfig {
  /** Unique identifier for this route */
  id: string

  /** URL path patterns per locale (react-router format). */
  paths: Record<Locale, string>

  /** Page component to render */
  component: ComponentType | LazyExoticComponent<ComponentType>

  /** Authentication requirement */
  auth: AuthRequirement

  /**
   * Which shell wraps this route.
   * - 'app' (default): rendered inside the shared `<Layout>` AppShell (header, footer, breadcrumbs).
   * - 'bare': rendered outside `<Layout>` — no header/footer/breadcrumbs. Auth guards still apply.
   *   Bare pages own their `document.title` (Layout won't set it). Used for fullscreen experiences.
   */
  layout?: 'app' | 'bare'

  /**
   * Parent route ID for breadcrumb hierarchy
   * Explicit parent allows custom breadcrumb chains that don't follow URL structure
   * null = no parent (root level)
   */
  parentId: string | null

  /**
   * Which shared navigation group populates this crumb's dropdown. The dropdown then mirrors the
   * actual tab bar for that level — honoring auth, team feature flags, membership and dynamic pages
   * — instead of a static hand-authored list. Omit for crumbs with no sibling-level switcher.
   */
  navGroup?: NavGroup

  /**
   * Breadcrumb label for this route
   * undefined = route not shown in breadcrumbs
   */
  breadcrumb?: BreadcrumbLabel

  /**
   * Whether this route is an index route (renders at parent path)
   */
  index?: boolean

  /**
   * Whether to show a prominent back link to parent in breadcrumb
   * Use for create/edit pages that need clear navigation back
   */
  showBackLink?: boolean

  /**
   * Hide/redirect this route on a single-team site (domain flagged single-team, or a pinned alias
   * host). Team browsing and team creation are meaningless there. Used both to redirect the route
   * to home and to drop its breadcrumb crumb.
   */
  hideWhenSingleTeam?: boolean

  /**
   * Optional data prefetch, run as a React Router loader in BOTH environments (SSR and client).
   *
   * On the server the request carries the visitor's session when the document request resolved one
   * (see docs/SSR.md) — but that resolution can fail or simply find no session, in which case the request
   * goes out anonymous. On the client the loader fires before auth initialization. Either way,
   * implementations must tolerate 401/403 responses. The loader adapter (see RouteGenerator) catches
   * all errors, so a failed prefetch never blocks the render; components fall back to their own
   * loading/error states.
   *
   * `url` carries the query string: a list page whose filters live there (`useUrlFilters`) must
   * prefetch the variant the URL asks for, not the default one — read it back with
   * `readUrlFilters(url.searchParams, …)` so the page and the prefetch resolve it identically.
   */
  prefetch?: (queryClient: QueryClient, params: RouteParams, url: URL) => Promise<void>

  /**
   * Optional redirect, checked by the route's loader before its `prefetch`: a non-empty return is
   * where the URL now lives. The loader throws React Router's `replace()`, so the server answers a
   * real redirect and a client navigation replaces its history entry instead of stacking the old
   * address under the new one. For former addresses kept for the links already out there — the
   * team feed and its tabs (pages/team/teamLegacyRedirects.ts, ledger `WEB-68`). Must be a pure
   * function of the URL, and return `undefined` for the URL it leads to.
   */
  redirect?: (params: RouteParams, url: URL) => string | undefined

  /**
   * Optional server-side link-preview (Open Graph / Twitter) descriptor. Invoked in entry-server
   * AFTER `prefetch` has populated the per-request QueryClient, so it only READS the cache (zero
   * extra fetches). Returns undefined to fall back to site-wide default tags. Attached to each
   * emitted RouteObject's `handle` by RouteGenerator so the matched leaf exposes it during SSR.
   */
  meta?: RouteMetaFn
}

/**
 * Complete route configuration
 */
export type RoutesConfig = RouteConfig[]
