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
      const dir = path.join(outDir, 'assets')
      if (!fs.existsSync(path.join(outDir, 'planner.js')) || !fs.existsSync(dir)) return
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

/**
 * Only the keys the bundle can ask for, in both catalogues (docs/LEDGER_*.md WEB-183). The site
 * loads one language's catalogue at a time; this single file holds both, whole they made 380 KB
 * of the 2.6 MB of script. Each catalogue import is a placeholder until every module is known,
 * then `renderChunk` writes the catalogue filtered on the code of our own modules: a key is kept
 * when it appears there as a literal (plural forms with it), or when it starts with the fixed
 * head of a template key (`` t(`routes.surface.${type}`) `` keeps every `routes.surface.…`). A key
 * the planner builds another way (a concatenation) would be dropped: build keys as templates.
 */
const CATALOGUE = /\/locales\/(\w+)\/common\.json$/
const CATALOGUE_ID = '\0planner-catalogue:'
const PLURAL_SUFFIX = /_(?:zero|one|two|few|many|other)$/

function trimCatalogues(): Plugin {
  const catalogues = new Map<string, Record<string, string>>()
  const placeholder = (language: string) => `__PLANNER_CATALOGUE_${language}__`
  return {
    name: 'trim-catalogues',
    enforce: 'pre',
    // A virtual module, not the file: Vite's JSON plugin would parse the placeholder
    resolveId(source) {
      const match = source.match(CATALOGUE)
      return match ? CATALOGUE_ID + match[1] : null
    },
    load(id) {
      if (!id.startsWith(CATALOGUE_ID)) return null
      const language = id.slice(CATALOGUE_ID.length)
      const file = path.resolve(import.meta.dirname, `src/locales/${language}/common.json`)
      catalogues.set(language, JSON.parse(fs.readFileSync(file, 'utf8')))
      return `export default ${placeholder(language)}`
    },
    renderChunk(code) {
      const literals = new Set<string>()
      const heads = new Set<string>()
      for (const id of this.getModuleIds()) {
        if (id.includes('/node_modules/') || id.startsWith('\0')) continue
        const source = this.getModuleInfo(id)?.code
        if (!source) continue
        for (const [, key] of source.matchAll(/['"`]([A-Za-z][\w-]*(?:\.[\w-]+)+)['"`]/g))
          literals.add(key)
        for (const [, head] of source.matchAll(/`([A-Za-z][\w-]*(?:\.[\w-]+)*\.)\$\{/g))
          heads.add(head)
      }
      let result = code
      for (const [language, catalogue] of catalogues) {
        const kept = Object.fromEntries(
          Object.entries(catalogue).filter(
            ([key]) =>
              literals.has(key) ||
              literals.has(key.replace(PLURAL_SUFFIX, '')) ||
              [...heads].some((head) => key.startsWith(head))
          )
        )
        if (!result.includes(placeholder(language))) {
          this.error(`catalogue placeholder of ${language} not found in the chunk`)
        }
        result = result.replace(placeholder(language), JSON.stringify(kept))
      }
      return { code: result, map: null }
    },
  }
}

export default defineConfig({
  // `recordSources` last: it hashes what `inlineWorkerSource` wrote
  plugins: [trimCatalogues(), react(), forbidSiteModules(), inlineWorkerSource(), recordSources()],
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
      // Stadia Maps' search box (52 KB): the page searches through the app (`BridgeSearchControl`).
      // Both spellings: the planner imports it by a relative path.
      {
        find: /^(?:@\/components|\.\.)\/map\/MapSearchControl$/,
        replacement: path.resolve(
          import.meta.dirname,
          'src/embed/mobile-planner/stubs/MapSearchControl.tsx'
        ),
      },
      // The styles of the calendar and the date pickers (146 KB of CSS), which index.css imports
      // for the site: no date is picked in the planner.
      {
        find: /^@mantine\/(?:dates|schedule)\/styles\.css$/,
        replacement: path.resolve(import.meta.dirname, 'src/embed/mobile-planner/stubs/empty.css'),
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
