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
      rolldownOptions: {
        output: {
          // Order matters: specific checks MUST come before broad ones
          manualChunks(id) {
            if (!id.includes('node_modules/')) {
              return // Let Rollup handle app code
            }

            // === MAPS (check first - react-map-gl must not fall to react checks) ===
            if (
              id.includes('node_modules/maplibre-gl/') ||
              id.includes('node_modules/maplibre-theme/') ||
              id.includes('node_modules/react-map-gl/') ||
              id.includes('node_modules/geokdbush/') ||
              id.includes('node_modules/kdbush/')
            ) {
              return 'map-vendor'
            }

            // === EDITOR (Tiptap + unified ecosystem for markdown rendering) ===
            if (
              // Tiptap editor
              id.includes('node_modules/@tiptap/') ||
              id.includes('node_modules/tiptap-markdown/') ||
              id.includes('node_modules/prosemirror') ||
              id.includes('node_modules/markdown-it/') ||
              // React markdown (for MarkdownDisplay)
              id.includes('node_modules/react-markdown/') ||
              id.includes('node_modules/remove-markdown/') ||
              // Unified ecosystem (remark, rehype, mdast, hast, micromark, etc.)
              id.includes('node_modules/unified/') ||
              id.includes('node_modules/remark') ||
              id.includes('node_modules/rehype') ||
              id.includes('node_modules/mdast') ||
              id.includes('node_modules/hast') ||
              id.includes('node_modules/micromark') ||
              id.includes('node_modules/unist') ||
              id.includes('node_modules/vfile') ||
              // Unified utilities
              id.includes('node_modules/bail/') ||
              id.includes('node_modules/trough/') ||
              id.includes('node_modules/devlop/') ||
              id.includes('node_modules/ccount/') ||
              id.includes('node_modules/zwitch/') ||
              id.includes('node_modules/character-entities') ||
              id.includes('node_modules/character-reference') ||
              id.includes('node_modules/comma-separated-tokens/') ||
              id.includes('node_modules/space-separated-tokens/') ||
              id.includes('node_modules/property-information/') ||
              id.includes('node_modules/stringify-entities/') ||
              id.includes('node_modules/decode-named-character-reference/') ||
              id.includes('node_modules/estree-util-') ||
              id.includes('node_modules/parse-entities/') ||
              id.includes('node_modules/trim-lines/') ||
              id.includes('node_modules/is-plain-obj/')
            ) {
              return 'editor-vendor'
            }

            // (No calendar chunk: the calendar is `@mantine/schedule`, which belongs to
            // mantine-vendor below. The `@fullcalendar/` rule that used to sit here matched
            // nothing once the migration landed.)

            // === CHARTS (check before react - react-chartjs-2 must not fall to react) ===
            if (
              id.includes('node_modules/chart.js/') ||
              id.includes('node_modules/react-chartjs-2/') ||
              id.includes('node_modules/chartjs-plugin-zoom/') ||
              id.includes('node_modules/hammerjs/')
            ) {
              return 'chart-vendor'
            }

            // === FIREBASE (web push only, imported dynamically by lib/push/webPush.ts) ===
            // On its own: in the catch-all `vendor` chunk it would ride along with whatever
            // else shares that chunk (the login page did), instead of loading on demand.
            if (id.includes('node_modules/firebase/') || id.includes('node_modules/@firebase/')) {
              return 'firebase-vendor'
            }

            // === I18N (check before react - react-i18next must not fall to react) ===
            if (id.includes('node_modules/i18next') || id.includes('node_modules/react-i18next/')) {
              return 'i18n-vendor'
            }

            // === UI: Mantine (large, separate chunk) ===
            if (
              id.includes('node_modules/@mantine/') ||
              id.includes('node_modules/mantine-form-zod-resolver/')
            ) {
              return 'mantine-vendor'
            }

            // === ICONS (project uses @tabler, not @heroicons) ===
            if (id.includes('node_modules/@tabler/icons-react/')) {
              return 'icons-vendor'
            }

            // === REACT CORE (now safe - specific react-* packages already handled) ===
            if (
              id.includes('node_modules/react/') ||
              id.includes('node_modules/react-dom/') ||
              id.includes('node_modules/scheduler/')
            ) {
              return 'react-vendor'
            }

            // === REACT ROUTER ===
            if (id.includes('node_modules/react-router')) {
              return 'router-vendor'
            }

            // === DATA LAYER (state, fetching, validation) ===
            if (
              id.includes('node_modules/@tanstack/') ||
              id.includes('node_modules/zustand/') ||
              id.includes('node_modules/axios/') ||
              id.includes('node_modules/zod/')
            ) {
              return 'data-vendor'
            }

            // === DATES ===
            if (id.includes('node_modules/date-fns') || id.includes('node_modules/dayjs/')) {
              return 'date-vendor'
            }

            // === UI UTILITIES ===
            if (id.includes('node_modules/react-resizable-panels/')) {
              return 'ui-utils-vendor'
            }

            // === REMAINING VENDOR ===
            return 'vendor'
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
