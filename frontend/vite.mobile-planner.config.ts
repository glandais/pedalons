import crypto from 'node:crypto'
import fs from 'node:fs'
import path from 'node:path'
import { defineConfig, type Plugin } from 'vite'
import react from '@vitejs/plugin-react'

/**
 * Builds the route planner the mobile app embeds in a WebView (`src/embed/mobile-planner`) into
 * `mobile/assets/planner/`: `pnpm build:mobile-planner`. The output is committed, like the other
 * generated files the app reads; rebuild it after touching the planner (docs/LEDGER_*.md WEB-183).
 *
 * One classic script (IIFE), no hash: the app loads `index.html` from its assets, by file URL.
 */
const outDir = path.resolve(import.meta.dirname, '../mobile/assets/planner')

/**
 * MapLibre's worker, emitted apart by `?worker&url` (`setupMaplibreWorker.ts`), cannot be loaded
 * by URL from `file://`: its source is copied into `worker-src.js`, a classic script the page
 * turns into a Blob. The emitted file itself is of no use to the app and is removed.
 */
function inlineWorkerSource(): Plugin {
  return {
    name: 'inline-worker-source',
    closeBundle() {
      // Also called after a failed build, which wrote nothing: let its own error show
      if (!fs.existsSync(path.join(outDir, 'planner.js'))) return
      const dir = path.join(outDir, 'assets')
      const file = fs.readdirSync(dir).find((f) => f.startsWith('maplibre-gl-worker'))
      if (!file) throw new Error('MapLibre worker not found in the build')
      const source = fs.readFileSync(path.join(dir, file), 'utf8')
      fs.writeFileSync(
        path.join(outDir, 'worker-src.js'),
        `window.__maplibreWorkerSource = ${JSON.stringify(source)};\n`
      )
      fs.rmSync(path.join(dir, file))
      // Anything else emitted there would be referenced by a path `file://` cannot resolve
      const left = fs.readdirSync(dir)
      if (left.length > 0) {
        throw new Error(`unexpected emitted assets, not loadable from file://: ${left.join(', ')}`)
      }
      fs.rmdirSync(dir)
    },
  }
}

/**
 * What must never ride along. A single-file build inlines every lazy import, so one link to the
 * router or to the route table brings the whole site (megabytes of it) into the app's assets, with
 * nothing failing. The two stubs aliased below cut the known paths; this fails the build on a new
 * one.
 */
const FORBIDDEN_MODULES = [
  /\/node_modules\/(?:\.pnpm\/)?(?:react-router|firebase|@firebase|@tiptap)/,
  /\/src\/pages\//,
  /\/src\/config\/routes\.config/,
]

function forbidSiteModules(): Plugin {
  return {
    name: 'forbid-site-modules',
    generateBundle(_options, bundle) {
      const found = new Set<string>()
      for (const chunk of Object.values(bundle)) {
        if (chunk.type !== 'chunk') continue
        for (const id of Object.keys(chunk.modules)) {
          if (FORBIDDEN_MODULES.some((pattern) => pattern.test(id))) found.add(id)
        }
      }
      if (found.size > 0) {
        this.error(`the embedded planner must not bundle:\n${[...found].slice(0, 20).join('\n')}`)
      }
    },
  }
}

/**
 * What the bundle was built from, for `mobile/check.sh` to tell a stale one: every source file of
 * ours that went into it (the module graph, so a new import is covered by the file that imports
 * it), this config, the page, and the files written — each with its SHA-256, in the format
 * `shasum -a 256 -c` reads, paths from the repository root. Content hashes, not dates: a checkout
 * does not keep dates. Dependencies (`node_modules`) are not covered.
 */
const repoRoot = path.resolve(import.meta.dirname, '..')
const manifestFile = path.resolve(repoRoot, 'mobile/tool/planner_bundle.sha256')

function recordSources(): Plugin {
  const sources = new Set<string>()
  return {
    name: 'record-sources',
    generateBundle() {
      for (const id of this.getModuleIds()) {
        const file = id.split('?')[0]
        if (!file || !path.isAbsolute(file) || file.includes('/node_modules/')) continue
        if (!file.startsWith(import.meta.dirname + path.sep) || !fs.existsSync(file)) continue
        sources.add(file)
      }
    },
    closeBundle() {
      if (!fs.existsSync(path.join(outDir, 'planner.js'))) return
      const files = [
        ...sources,
        path.resolve(import.meta.dirname, 'vite.mobile-planner.config.ts'),
        path.resolve(import.meta.dirname, 'src/embed/mobile-planner/public/index.html'),
        ...fs.readdirSync(outDir).map((f) => path.join(outDir, f)),
      ]
      const lines = [...new Set(files)]
        .map((file) => {
          const hash = crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex')
          return `${hash}  ${path.relative(repoRoot, file).split(path.sep).join('/')}`
        })
        .sort((a, b) => (a.slice(66) < b.slice(66) ? -1 : 1))
      fs.writeFileSync(manifestFile, lines.join('\n') + '\n')
    },
  }
}

export default defineConfig({
  // `recordSources` last: it hashes what `inlineWorkerSource` wrote
  plugins: [react(), forbidSiteModules(), inlineWorkerSource(), recordSources()],
  resolve: {
    alias: [
      // The router, and through the route table every page of the site, stay out of the bundle:
      // see the stub. Listed first, a specific path wins over the `@` prefix.
      {
        find: '@/components/common/PrefetchLink',
        replacement: path.resolve(
          import.meta.dirname,
          'src/embed/mobile-planner/stubs/PrefetchLink.tsx'
        ),
      },
      // Firebase, which `authStore` imports lazily on sign out: see the stub.
      {
        find: '@/lib/push/webPush',
        replacement: path.resolve(import.meta.dirname, 'src/embed/mobile-planner/stubs/webPush.ts'),
      },
      { find: '@', replacement: path.resolve(import.meta.dirname, './src') },
    ],
  },
  define: {
    'process.env.NODE_ENV': JSON.stringify('production'),
    __PREFETCH_AUDIT_ENABLED__: 'false',
  },
  publicDir: path.resolve(import.meta.dirname, 'src/embed/mobile-planner/public'),
  build: {
    outDir,
    emptyOutDir: true,
    minify: true,
    copyPublicDir: true,
    lib: {
      entry: path.resolve(import.meta.dirname, 'src/embed/mobile-planner/main.tsx'),
      formats: ['iife'],
      name: 'PedalonsPlanner',
      fileName: () => 'planner.js',
      cssFileName: 'planner',
    },
  },
})
