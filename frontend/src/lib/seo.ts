// Server-side link-preview (Open Graph / Twitter) meta-tag emission.
//
// The SSR entry (entry-server.tsx) resolves the matched route's optional `meta()` AFTER the route
// prefetch has populated the per-request QueryClient, then serialises the result here into an HTML
// string injected at the <!--ssr-head--> placeholder (early in <head>, within Slack's ~32KB and
// WhatsApp's ~300KB budgets). No <meta> component is ever added to the React tree — that would let
// React 19 hoist tags into <body> and shift Mantine useId across the server/client boundary.
//
// Crawlers do not run JavaScript, so these tags MUST be in the initial server HTML. Client-side
// navigation deliberately does NOT update them (the browser tab title is handled by Layout).
import type { TFunction } from 'i18next'
import type { QueryClient } from '@tanstack/react-query'
import { generatePath } from 'react-router-dom'
import type { AssetDto, AssetsDto, ConfigDto } from '@/api/dto'
import type { Locale } from '@/config/paths'
import type { RouteParams } from '@/config/routes.types'

/** og:image (1200-fit) dimensions we can only trust when the source pixel size is known. */
export interface RouteMetaImage {
  /** Absolute HTTPS URL (already origin-prefixed and {size}-resolved). */
  url: string
  alt?: string
  /** Emitted only when accurately computed from the source asset dimensions. */
  width?: number
  height?: number
}

/** og:type values used across the app. */
export type OgType = 'website' | 'article' | 'profile' | 'product'

/** Structured, page-agnostic preview description produced by a route's `meta()`. */
export interface RouteMeta {
  title?: string
  description?: string
  type?: OgType
  image?: RouteMetaImage
  /** og:site_name override (e.g. the owning team). Defaults to config.appName. */
  siteName?: string
  /** Absolute canonical URL. Defaults to `origin + path` (browser-space) when omitted. */
  url?: string
  /** article:* subtags (only meaningful when type === 'article'). */
  article?: {
    publishedTime?: string
    modifiedTime?: string
    author?: string
    section?: string
  }
  /** product:* subtags (only meaningful when type === 'product'). */
  product?: {
    priceAmount?: string
    priceCurrency?: string
  }
  /**
   * Absolute `<link rel="canonical">` overriding the one entry-server derives from the route
   * ({@link RouteMetaContext.canonical}) — for a near-duplicate page that should point elsewhere.
   * Ignored on a `noindex` page.
   */
  canonical?: string
  /**
   * Keep the page out of search indexes (`<meta name="robots" content="noindex">`): set for
   * content or a team that is not `PUBLIC` — `PUBLIC_UNLISTED` is shareable by link, not indexed
   * (docs/LEDGER_*.md WEB-4) — and for every route that is not indexable as such (members-only,
   * transactional, `RouteConfig.noindex`). Absent: `index, follow`. A `noindex` page carries no
   * canonical link: pointing engines at a URL they are told not to index contradicts.
   */
  noindex?: boolean
}

/** Everything a route's `meta()` needs; assembled per-request in entry-server. */
export interface RouteMetaContext {
  queryClient: QueryClient
  params: RouteParams
  /** Scheme + host reconstructed from the forwarded proxy headers (per-domain absolute base). */
  origin: string
  /** Browser-space (clean, unprefixed) pathname of the request — canonical og:url base. */
  path: string
  locale: Locale
  config?: ConfigDto
  /** Per-request i18next translator bound to the resolved locale. */
  t: TFunction
  /**
   * Absolute canonical URL of the matched route ({@link buildCanonicalUrl}); absent on a page that
   * has none (404, redirect, unknown route). Dropped by buildMetaTags on a `noindex` page.
   */
  canonical?: string
}

export type RouteMetaFn = (ctx: RouteMetaContext) => RouteMeta | undefined

/**
 * The site's default language: the one a visitor without a preference — a crawler, which sends no
 * cookie and usually no Accept-Language — is served (i18n `fallbackLng`, entry-server's fallback).
 * Canonical URLs name its paths, like the sitemap (docs/LEDGER_*.md WEB-31).
 */
export const SITE_DEFAULT_LOCALE: Locale = 'fr'

/** The router ↔ address-bar mapping of a host pinned to one team (config/pinnedHistory.ts). */
export interface PinnedPathMapping {
  toBrowser: (path: string) => string
  toRouter: (path: string) => string
}

/**
 * The canonical URL of a page, rebuilt from its route's locale templates (`RouteConfig.paths`,
 * generated from contracts/routes.yaml) and the params the router matched.
 *
 * Both locale variants of a path render the same page, in the language the request resolved
 * (account preference, `lang` cookie, Accept-Language — not the URL). The canonical must not
 * follow that: one URL would declare a different canonical from one request to the next. It is
 * therefore always the path in {@link SITE_DEFAULT_LOCALE} — what a crawler is served — which
 * folds `/teams/x` and `/equipes/x` into one. Never a query string: filters and pagination are
 * views of the same page.
 *
 * No hreflang alternates: the URL does not choose the language, so `/teams/x` serves French to a
 * crawler and could not be declared the English version (Google ignores such a cluster).
 *
 * @param pinned on a host pinned to one team, the path is mapped to the address bar's
 *   (`toBrowser`), and dropped unless `toRouter` brings it back to a path of the same route — a
 *   canonical the host cannot serve would be worse than none.
 * @returns undefined when the path cannot be rebuilt (a param missing) or served.
 */
export function buildCanonicalUrl(
  routePaths: Partial<Record<Locale, string>>,
  params: RouteParams,
  origin: string,
  pinned?: PinnedPathMapping
): string | undefined {
  const pattern =
    routePaths[SITE_DEFAULT_LOCALE] ??
    (Object.values(routePaths).find(Boolean) as string | undefined)
  if (!pattern) return undefined
  const pathOf = (template: string): string | undefined => {
    try {
      return generatePath(template, params as Record<string, string>)
    } catch {
      return undefined
    }
  }
  const routerPath = pathOf(pattern)
  if (!routerPath) return undefined
  if (!pinned) return origin + routerPath
  // Either locale variant of the route is the same page (a shared segment such as `admin` takes
  // the visitor's prefix): any of them counts as served.
  const browserPath = pinned.toBrowser(routerPath)
  const routed = pinned.toRouter(browserPath)
  const served = Object.values(routePaths).some(
    (template) => template && pathOf(template) === routed
  )
  return served ? origin + browserPath : undefined
}

/** imgproxy fits every image within a 1200x1200 box (rs:fit:1200:1200); this is the width token. */
const OG_IMAGE_SIZE = 1200

/** Escape a value for safe use inside an HTML double-quoted attribute. */
export function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;')
}

/** Truncate to `max` chars on a word boundary, appending an ellipsis when cut. */
export function truncate(value: string, max: number): string {
  const text = value.trim()
  if (text.length <= max) return text
  const slice = text.slice(0, max - 1)
  const lastSpace = slice.lastIndexOf(' ')
  const base = lastSpace > max * 0.6 ? slice.slice(0, lastSpace) : slice
  return base.replace(/[\s.,;:!?-]+$/, '') + '…'
}

/**
 * Strip Markdown/HTML to plain text for preview descriptions. Server-safe (no DOM): a lightweight
 * regex pass covering the syntax our editor emits — never a heavy renderer in the SSR path.
 */
export function stripMarkdown(markdown: string): string {
  return markdown
    .replace(/```[\s\S]*?```/g, ' ') // fenced code blocks
    .replace(/`([^`]*)`/g, '$1') // inline code
    .replace(/!\[[^\]]*\]\([^)]*\)/g, ' ') // images
    .replace(/::asset\{[^}]*\}/g, ' ') // asset directives
    .replace(/\[([^\]]*)\]\([^)]*\)/g, '$1') // links -> text
    .replace(/<[^>]+>/g, ' ') // raw HTML tags
    .replace(/^\s{0,3}#{1,6}\s+/gm, '') // ATX headings
    .replace(/^\s{0,3}>\s?/gm, '') // blockquotes
    .replace(/^\s{0,3}[-*+]\s+/gm, '') // unordered list markers
    .replace(/^\s{0,3}\d+\.\s+/gm, '') // ordered list markers
    .replace(/[*_~]{1,3}/g, '') // emphasis / strikethrough
    .replace(/\s+/g, ' ')
    .trim()
}

/** Map the resolved locale to an Open Graph locale code. */
export function ogLocale(locale: Locale): string {
  return locale === 'en' ? 'en_GB' : 'fr_FR'
}

/** The other supported OG locale (for og:locale:alternate). */
export function ogLocaleAlternate(locale: Locale): string {
  return locale === 'en' ? 'fr_FR' : 'en_GB'
}

/** Resolve an imgproxy `{size}` template URL to an absolute, origin-prefixed 1200-wide image URL. */
function resolveTemplateUrl(origin: string, template: string): string {
  const sized = template.replace('{size}', String(OG_IMAGE_SIZE))
  return sized.startsWith('http') ? sized : `${origin}${sized}`
}

/**
 * Accurate 1200-fit output dimensions for a source asset. imgproxy uses rs:fit within a 1200x1200
 * box and does not enlarge, so we scale the ORIGINAL pixel size down to fit — matching the bytes
 * the crawler actually receives (never the biketeam declared-vs-actual mismatch).
 */
function fitDimensions(
  dims: { width?: number; height?: number } | undefined
): { width: number; height: number } | undefined {
  if (!dims?.width || !dims.height) return undefined
  const scale = Math.min(1, OG_IMAGE_SIZE / dims.width, OG_IMAGE_SIZE / dims.height)
  return {
    width: Math.round(dims.width * scale),
    height: Math.round(dims.height * scale),
  }
}

/** Build a preview image from an AssetDto (logo / photo / thumbnail asset), with accurate dims. */
export function imgFromAsset(
  origin: string,
  asset: AssetDto | undefined,
  alt?: string
): RouteMetaImage | undefined {
  if (!asset?.imageUrl) return undefined
  const dims = fitDimensions(asset.imageDimensions)
  return {
    url: resolveTemplateUrl(origin, asset.imageUrl),
    alt,
    width: dims?.width,
    height: dims?.height,
  }
}

/**
 * Build a preview image from a bare `{size}` template string (e.g. RideDto.thumbnailLightUrl).
 * No source dimensions travel with these, so width/height are intentionally omitted.
 */
export function imgFromTemplate(
  origin: string,
  template: string | undefined,
  alt?: string
): RouteMetaImage | undefined {
  if (!template) return undefined
  return { url: resolveTemplateUrl(origin, template), alt }
}

/** First uploaded image, then logo, of a media asset bundle — accurate-dims path. */
export function imgFromAssets(
  origin: string,
  assets: AssetsDto | undefined,
  alt?: string
): RouteMetaImage | undefined {
  if (!assets) return undefined
  return imgFromAsset(origin, assets.images?.[0], alt) ?? imgFromAsset(origin, assets.logo, alt)
}

/** The site-wide default OG image — a 1200x630 PNG we control, so dimensions are declared. */
export function defaultImage(origin: string, alt: string): RouteMetaImage {
  return { url: `${origin}/og-image.png`, alt, width: 1200, height: 630 }
}

/** Escaped `<meta property="..." content="...">` (Open Graph namespace). */
function property(name: string, content: string | undefined): string | null {
  if (!content) return null
  return `<meta property="${name}" content="${escapeHtml(content)}" />`
}

/** Escaped `<meta name="..." content="...">` (Twitter / standard namespace). */
function named(name: string, content: string | undefined): string | null {
  if (!content) return null
  return `<meta name="${name}" content="${escapeHtml(content)}" />`
}

/**
 * Serialise a resolved (or absent) RouteMeta into the full <head> preview block. Always emits a
 * complete, valid set of tags — falling back to site-wide defaults — so a bare tenant link and a
 * data-failure both unfurl correctly. Never throws: callers must be able to inject the result.
 */
export function buildMetaTags(meta: RouteMeta | undefined, ctx: RouteMetaContext): string {
  const { origin, path, locale, config, t } = ctx
  const appName = config?.appName || 'Pédalons'
  const indexable = !meta?.noindex
  const canonical = indexable ? meta?.canonical || ctx.canonical : undefined

  const title = truncate(meta?.title?.trim() || appName, 70)
  const description = truncate(meta?.description?.trim() || t('home.subtitle'), 200)
  const type: OgType = meta?.type || 'website'
  const url = meta?.url || canonical || `${origin}${path}`
  const image = meta?.image || defaultImage(origin, appName)

  const lines: (string | null)[] = [
    `<title>${escapeHtml(title)}</title>`,
    named('description', description),
    property('og:type', type),
    property('og:title', title),
    property('og:description', description),
    property('og:url', url),
    property('og:site_name', meta?.siteName?.trim() || appName),
    property('og:locale', ogLocale(locale)),
    property('og:locale:alternate', ogLocaleAlternate(locale)),
    property('og:image', image.url),
    property('og:image:alt', image.alt || appName),
    image.width ? property('og:image:width', String(image.width)) : null,
    image.height ? property('og:image:height', String(image.height)) : null,
    // The only robots tag of the page: index.html ships none, so there is never a static
    // `index, follow` left beside a per-page `noindex` (docs/LEDGER_*.md WEB-4).
    named('robots', indexable ? 'index, follow' : 'noindex'),
    named('twitter:card', 'summary_large_image'),
    // The name under the icon once the site is added to an iOS home screen (the manifest's name
    // plays that part elsewhere).
    named('apple-mobile-web-app-title', appName),
  ]

  if (type === 'article' && meta?.article) {
    lines.push(
      property('article:published_time', meta.article.publishedTime),
      property('article:modified_time', meta.article.modifiedTime),
      property('article:author', meta.article.author),
      property('article:section', meta.article.section)
    )
  }

  if (type === 'product' && meta?.product) {
    lines.push(
      property('product:price:amount', meta.product.priceAmount),
      property('product:price:currency', meta.product.priceCurrency)
    )
  }

  if (canonical) {
    lines.push(`<link rel="canonical" href="${escapeHtml(canonical)}" />`)
  }

  return lines.filter((line): line is string => line !== null).join('\n    ')
}
