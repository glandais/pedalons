import {
  createTheme,
  virtualColor,
  type CSSVariablesResolver,
  type MantineColorScheme,
} from '@mantine/core'
import type { ThemePreference } from '@/api/dto'

/** Maps the backend's `ThemePreference` (SYSTEM/LIGHT/DARK) to Mantine's own scheme type. */
export function mapThemePreference(theme: ThemePreference | null | undefined): MantineColorScheme {
  if (theme === 'LIGHT') return 'light'
  if (theme === 'DARK') return 'dark'
  return 'auto'
}

export const theme = createTheme({
  primaryColor: 'primary',
  fontFamily: 'Inter, system-ui, sans-serif',
  defaultRadius: 'md',
  autoContrast: true,
  luminanceThreshold: 0.3,
  colors: {
    primary: virtualColor({
      name: 'primary',
      light: 'indigo',
      dark: 'indigo',
    }),
    success: virtualColor({
      name: 'success',
      light: 'green',
      dark: 'green',
    }),
    warning: virtualColor({
      name: 'warning',
      light: 'yellow',
      dark: 'yellow',
    }),
    danger: virtualColor({
      name: 'danger',
      light: 'red',
      dark: 'red',
    }),
  },
  // Responsive typography
  headings: {
    sizes: {
      h1: { fontSize: 'clamp(1.5rem, 5vw, 2.125rem)', lineHeight: '1.2' },
      h2: { fontSize: 'clamp(1.25rem, 4vw, 1.625rem)', lineHeight: '1.3' },
      h3: { fontSize: 'clamp(1.125rem, 3vw, 1.375rem)', lineHeight: '1.4' },
      h4: { fontSize: 'clamp(1rem, 2.5vw, 1.125rem)', lineHeight: '1.5' },
    },
  },
  // Component-level responsive defaults
  components: {
    Button: {
      styles: {
        root: {
          // Touch-friendly minimum on mobile (44px), smaller on desktop.
          // The variable is defined in index.css — a media query cannot live in
          // a Mantine `styles` object, which compiles to an inline style.
          minHeight: 'var(--button-min-height, 44px)',
        },
      },
    },
    ActionIcon: {
      defaultProps: {
        // Larger touch targets on mobile
        size: 'lg',
      },
    },
  },
})

/**
 * Overrides of Mantine's scheme-dependent colours that fail WCAG SC 1.4.3 (4.5:1) on our surfaces.
 *
 * In light, `primary` renders one shade darker than Mantine's default: indigo-6 (#4c6ef5) is
 * 4.32:1 on white, for links, primary text and filled-button labels alike; indigo-7 (#4263eb) is
 * 4.98:1. Links go one shade further, indigo-8 (#3b5bdb): they also sit on tinted fills, and the
 * blue light-variant one of an `Alert` (#d0ebff) takes indigo-7 down to 4.03:1 (indigo-8: 4.59:1).
 * Not through `primaryShade`, which is global: it would shift the fill of *every* family,
 * the business colour code included, away from the mobile app's (docs/BRANDING.md §3.6).
 *
 * Mantine's `dimmed` is gray-6 (#868e96, 3.32:1 on white) in light and dark-2 (#828282,
 * 4.03:1 on #242424) in dark; no palette shade sits between "readable" and "as dark as body
 * text", hence the two hand-picked greys:
 * - light #666d75 — 5.24:1 on white, 4.71:1 on gray-1 (#f1f3f5);
 * - dark #9a9a9a — 5.52:1 on the page (#242424), 4.83:1 on raised surfaces (#2e2e2e).
 * The dark anchor moves from primary-4 (#748ffc, 4.41:1 on the blue light-variant fill) to
 * primary-3 (#91a7ff, 5.71:1 there, 6.78:1 on the page).
 */
export const cssVariablesResolver: CSSVariablesResolver = () => ({
  variables: {},
  light: {
    '--mantine-color-primary-filled': 'var(--mantine-color-primary-7)',
    '--mantine-color-primary-filled-hover': 'var(--mantine-color-primary-8)',
    '--mantine-color-primary-outline': 'var(--mantine-color-primary-7)',
    '--mantine-color-anchor': 'var(--mantine-color-primary-8)',
    '--mantine-color-dimmed': '#666d75',
  },
  dark: {
    '--mantine-color-dimmed': '#9a9a9a',
    '--mantine-color-anchor': 'var(--mantine-color-primary-3)',
  },
})
