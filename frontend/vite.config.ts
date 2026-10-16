import { defineConfig, loadEnv, PluginOption } from 'vite'
import react from '@vitejs/plugin-react'
import { compression } from 'vite-plugin-compression2'
import path from 'path'
import fs from 'fs'
// import { visualizer } from 'rollup-plugin-visualizer'

// Load mkcert certificates if available (for Garmin simulator HTTPS testing)
function loadHttpsCerts() {
  const certPath = path.resolve(import.meta.dirname, 'localhost+2.pem')
  const keyPath = path.resolve(import.meta.dirname, 'localhost+2-key.pem')
  if (fs.existsSync(certPath) && fs.existsSync(keyPath)) {
    return {
      cert: fs.readFileSync(certPath),
      key: fs.readFileSync(keyPath),
    }
  }
  return false
}

// Request logger plugin for debugging
function requestLogger(): PluginOption {
  return {
    name: 'request-logger',
    configureServer(server) {
      server.middlewares.use((req, res, next) => {
        const timestamp = new Date().toISOString()
        console.log(`[${timestamp}] ${req.method} ${req.url} (from: ${req.headers['host']})`)
        next()
      })
    },
  }
}

/** A `codeSplitting` group test matching modules of the packages whose path starts with a prefix. */
function fromPackages(...prefixes: string[]) {
  return (id: string) => prefixes.some((prefix) => id.includes(`node_modules/${prefix}`))
}

export default defineConfig(({ mode, isSsrBuild }) => {
  // API proxy target: from .env (VITE_API_TARGET) or staging by default
  const env = loadEnv(mode, import.meta.dirname, '')
  const apiTarget = env.VITE_API_TARGET || 'https://staging.pedalons.fr'
  const apiUrl = new URL(apiTarget)
  const isHttps = apiUrl.protocol === 'https:'

  // FRONTEND_PREFETCH_AUDIT lives in the root .env (docker-compose's), not frontend/.env, so read
  // it from there — in a docker build the build context is frontend/ only, so this finds nothing
  // there either; build.sh forwards it as a build-arg instead (see Dockerfile). Opt-in on any
  // environment, including a built/staging bundle, to catch prefetch gaps that only show up there.
  const rootEnv = loadEnv(mode, path.resolve(import.meta.dirname, '..'), 'FRONTEND_')
  const prefetchAuditEnabled = rootEnv.FRONTEND_PREFETCH_AUDIT === 'true'
  console.log(
    `[vite.config.ts] FRONTEND_PREFETCH_AUDIT=${rootEnv.FRONTEND_PREFETCH_AUDIT} (prefetch audit ${prefetchAuditEnabled ? 'enabled' : 'disabled'})`
  )

  return {
    define: {
      // A plain global, not an `import.meta.env.*` key — those get merged into Vite's own client-env
      // object and come out serialized differently between the dev-server transform and the
      // build/Rollup one (string vs boolean). A bare identifier define is a straight textual
      // substitution in both, so __PREFETCH_AUDIT_ENABLED__ stays the same boolean everywhere.
      __PREFETCH_AUDIT_ENABLED__: JSON.stringify(prefetchAuditEnabled),
    },
    plugins: [
      requestLogger(),
      react(),
      // Brotli + gzip siblings of the client assets, written once at build time and served as-is by
      // express-static-gzip in server.js — instead of gzipping map-vendor (1 MB) on every request
      // (docs/LEDGER_*.md WEB-82). Not the SSR bundle, which no browser downloads. index.html is the
      // SSR template, never served as a file; sw.js has its own no-cache route.
      !isSsrBuild &&
        compression({
          algorithms: ['brotliCompress', 'gzip'],
          threshold: 1024,
          exclude: [/\.html$/, /(^|\/)sw\.js$/],
        }),
      /*
    visualizer({
      open: false,
      template: 'flamegraph',
    }),
    */
    ],
    resolve: {
      alias: {
        '@': path.resolve(import.meta.dirname, './src'),
      },
    },
    test: {
      // jsdom for everything: component tests need a DOM, and the pure-logic tests don't care.
      // `src/test/setup.ts` supplies what jsdom lacks and Mantine requires (matchMedia,
      // ResizeObserver, IntersectionObserver) — it existed before this block and was never loaded.
      environment: 'jsdom',
      // @testing-library/jest-dom extends a global `expect`, so it needs the globals.
      globals: true,
      setupFiles: ['./src/test/setup.ts'],
      // A fixed zone, so a test that leans on the process zone gives the same result on every
      // machine and in CI (docs/LEDGER_*.md API-60, plan §11). Tests about a zone pass it explicitly.
      env: { TZ: 'Europe/Paris' },
    },
    build: {
      sourcemap: process.env.VITE_BUILD_SOURCEMAP === 'true',
      // dist/client/.vite/manifest.json: server.js reads it to preload the rendered language's
      // catalogue chunk (src/i18n/index.ts). The dot directory is never served (send 404s it).
      manifest: !isSsrBuild,
      rolldownOptions: {
        output: {
          // Vendor chunks as priority groups (Rolldown `codeSplitting`, which replaced
          // `manualChunks`). A group also captures the dependencies of what it matches
          // (`includeDependenciesRecursively`, on by default), so a shared package lands in the
          // first group that reaches it unless a higher-priority group claims it. With the old
          // ordered `manualChunks`, `react` ended up in chart-vendor (via react-chartjs-2) and
          // `use-sync-external-store` in editor-vendor (via @tiptap/react): every page then
          // preloaded Chart.js and Tiptap. Hence three tiers — the core every page needs, then
          // Mantine, then the feature chunks that only their pages load — and nothing a page
          // shell imports may sit in a feature group. Check `index.html`'s modulepreload list
          // after changing a group.
          codeSplitting: {
            groups: [
              // === TRANSLATIONS: one chunk per language, `locale-<lang>` ===
              // The browser imports only the language it renders (src/i18n/index.ts), and
              // server.js finds that chunk in the manifest by this name to preload it.
              {
                name: (id) => `locale-${/src[\\/]locales[\\/]([^\\/]+)[\\/]/.exec(id)?.[1]}`,
                test: /src[\\/]locales[\\/][^\\/]+[\\/]common\.json$/,
                priority: 50,
              },

              // === CORE (every page) ===
              {
                name: 'react-vendor',
                test: fromPackages(
                  'react/',
                  'react-dom/',
                  'scheduler/',
                  'use-sync-external-store/'
                ),
                priority: 40,
              },
              { name: 'router-vendor', test: fromPackages('react-router'), priority: 30 },
              {
                name: 'i18n-vendor',
                test: fromPackages('i18next', 'react-i18next/'),
                priority: 30,
              },
              {
                name: 'data-vendor',
                test: fromPackages('@tanstack/', 'zustand/', 'axios/', 'zod/'),
                priority: 30,
              },
              { name: 'date-vendor', test: fromPackages('date-fns', 'dayjs/'), priority: 30 },
              { name: 'icons-vendor', test: fromPackages('@tabler/icons-react/'), priority: 30 },

              // === UI: Mantine, minus the calendar and the editor bindings (feature chunks) ===
              {
                name: 'mantine-vendor',
                test: (id) =>
                  fromPackages('@mantine/', 'mantine-form-zod-resolver/')(id) &&
                  !fromPackages('@mantine/schedule/', '@mantine/tiptap/')(id),
                priority: 20,
              },

              // === FEATURES (loaded by the pages that use them) ===
              // Markdown *display* (MarkdownDisplay) before the editor, so a page that only
              // renders markdown never pulls Tiptap through a shared dependency.
              {
                name: 'markdown-vendor',
                test: fromPackages(
                  'react-markdown/',
                  'remove-markdown/',
                  'unified/',
                  'remark',
                  'rehype'
                ),
                priority: 12,
              },
              {
                name: 'editor-vendor',
                test: fromPackages(
                  '@tiptap/',
                  'tiptap-markdown/',
                  'prosemirror',
                  'markdown-it/',
                  '@mantine/tiptap/'
                ),
                priority: 10,
              },
              {
                name: 'map-vendor',
                test: fromPackages(
                  'maplibre-gl/',
                  'maplibre-theme/',
                  'react-map-gl/',
                  'geokdbush/',
                  'kdbush/'
                ),
                priority: 10,
              },
              {
                name: 'chart-vendor',
                test: fromPackages(
                  'chart.js/',
                  'react-chartjs-2/',
                  'chartjs-plugin-zoom/',
                  'hammerjs/'
                ),
                priority: 10,
              },
              {
                name: 'schedule-vendor',
                test: fromPackages('@mantine/schedule/', 'rrule/'),
                priority: 10,
              },
              // Web push only, imported dynamically by lib/push/webPush.ts: on its own, so it
              // never rides along with whatever else would share a catch-all chunk.
              {
                name: 'firebase-vendor',
                test: fromPackages('firebase/', '@firebase/'),
                priority: 10,
              },
              {
                name: 'ui-utils-vendor',
                test: fromPackages('react-resizable-panels/'),
                priority: 10,
              },

              // === REMAINING VENDOR ===
              { name: 'vendor', test: fromPackages(''), priority: 0 },
            ],
          },
        },
      },
      chunkSizeWarningLimit: 500,
    },
    server: {
      port: 5173,
      https: loadHttpsCerts(),
      proxy: {
        '/api': {
          target: apiTarget,
          changeOrigin: true,
          secure: isHttps,
          configure: (proxy) => {
            proxy.on('proxyReq', (proxyReq) => {
              // Force the target host so DomainResolver finds the right tenant
              proxyReq.setHeader('X-Forwarded-Host', apiUrl.host)
              proxyReq.setHeader('X-Forwarded-Proto', isHttps ? 'https' : 'http')
            })
          },
        },
      },
    },
    preview: {
      port: 5173,
      proxy: {
        '/api': {
          target: apiTarget,
          changeOrigin: true,
          secure: isHttps,
          headers: {
            'X-Forwarded-Host': apiUrl.host,
            'X-Forwarded-Proto': isHttps ? 'https' : 'http',
          },
        },
      },
    },
  }
})
