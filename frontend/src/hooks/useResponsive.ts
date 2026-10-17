import { useMantineTheme, MantineSpacing, MantineSize, StyleProp } from '@mantine/core'
import { useCallback, useSyncExternalStore } from 'react'

const getServerSnapshot = () => false

/**
 * `matchMedia` as an external store: the hydration render reads `getServerSnapshot` (false, what
 * the SSR server rendered), React re-renders with the real match right after, and any component
 * mounted later reads the real match on its very first render.
 *
 * Mantine's `useMediaQuery` offers neither half of that. With `getInitialValueInEffect: false` it
 * ignores `initialValue` and reads `matchMedia` during hydration, so a phone hydrated
 * `isMobile=true` over server markup rendered with `false` — React #418 on every paginated list.
 * With `true` it starts from `initialValue` on every mount, so each client-side navigation would
 * render one frame for the wrong viewport.
 */
export function useMediaMatch(query: string): boolean {
  const subscribe = useCallback(
    (onChange: () => void) => {
      const mediaQuery = window.matchMedia(query)
      mediaQuery.addEventListener('change', onChange)
      return () => mediaQuery.removeEventListener('change', onChange)
    },
    [query]
  )
  return useSyncExternalStore(subscribe, () => window.matchMedia(query).matches, getServerSnapshot)
}

/**
 * Hook for responsive breakpoint detection. Every flag reads `false` on the server and during
 * hydration, then the real viewport.
 */
export function useResponsive() {
  const theme = useMantineTheme()

  const isMobile = useMediaMatch(`(max-width: ${theme.breakpoints.sm})`)
  const isTablet = useMediaMatch(
    `(min-width: ${theme.breakpoints.sm}) and (max-width: ${theme.breakpoints.md})`
  )
  const isDesktop = useMediaMatch(`(min-width: ${theme.breakpoints.md})`)

  // Responsive sizes for Mantine components (mobile: xs, tablet: sm, desktop: md)
  const size: MantineSize = isMobile ? 'xs' : isTablet ? 'sm' : 'md'
  const sizeCompact: MantineSize = isMobile ? 'xs' : 'sm'

  return { isMobile, isTablet, isDesktop, size, sizeCompact }
}

// Type for responsive spacing props
type ResponsiveSpacing = StyleProp<MantineSpacing>

/**
 * Responsive spacing values for consistent mobile-first design.
 * Usage: gap={responsiveSpacing.section}
 */
export const responsiveSpacing: Record<string, ResponsiveSpacing> = {
  /** Page-level padding/margins */
  page: { base: 'sm', sm: 'md', lg: 'lg' },
  /** Section spacing within pages */
  section: { base: 'md', sm: 'lg' },
  /** Card internal padding */
  card: { base: 'sm', sm: 'md' },
  /** Form element spacing */
  form: { base: 'md', sm: 'lg' },
}

/**
 * Map height variants.
 * - `compact`   — small maps embedded in cards / previews
 * - `standard`  — maps sitting beside other content (e.g. ride detail, half-width)
 * - `full`      — the primary map of a detail page (route / GPX preview)
 * - `fullscreen`— dedicated map pages where the map *is* the content
 */
export type MapHeightVariant = 'compact' | 'standard' | 'full' | 'fullscreen'

/**
 * Single source of truth for map heights.
 *
 * Every value is `clamp(min, N·dvh, max)`:
 * - `dvh` (dynamic viewport height) scales the map to the *actual* screen and follows the
 *   mobile address-bar collapse, so a map is never taller than the device — the old fixed
 *   `700px` was taller than a phone viewport and forced a full-screen scroll just to pan.
 * - the `min`/`max` bounds keep the map usable on very short screens and stop it from
 *   ballooning on ultra-tall/desktop windows.
 */
const MAP_HEIGHT_CSS: Record<MapHeightVariant, string> = {
  compact: 'clamp(200px, 34dvh, 360px)',
  standard: 'clamp(260px, 44dvh, 460px)',
  full: 'clamp(300px, 52dvh, 560px)',
  fullscreen: 'clamp(400px, 72dvh, 820px)',
}

/**
 * Returns the CSS height for a map container, unified across the app.
 * Pass the result straight to a Mantine `h` prop: `h={useMapHeight('full')}`.
 *
 * It's a hook (not a plain constant) so map sizing has one call site to evolve later —
 * e.g. honouring a user "big map" preference or a measured header offset.
 */
export function useMapHeight(variant: MapHeightVariant = 'full'): string {
  return MAP_HEIGHT_CSS[variant]
}
