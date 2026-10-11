#!/usr/bin/env node
// Generator for UI routes.
// Source: contracts/routes.yaml
// Outputs:
//   frontend/src/config/paths.generated.ts
//   mobile/lib/config/paths.generated.dart
//   frontend/public/.well-known/apple-app-site-association
//   mobile/android/app/src/main/AndroidManifest.xml (between deeplink markers)

import { createRequire } from 'node:module'
import { fileURLToPath } from 'node:url'
import { readFileSync, writeFileSync } from 'node:fs'
import path from 'node:path'

const scriptDir = path.dirname(fileURLToPath(import.meta.url))
const repoRoot = path.resolve(scriptDir, '..')
const frontendReq = createRequire(path.join(repoRoot, 'frontend', 'package.json'))
const YAML = frontendReq('yaml')

const LOCALES = ['en', 'fr']
const DEFAULT_LOCALE = 'en'
const IOS_APP_ID = '7Q49262697.fr.pedalons.mobile'
const MARKER_BEGIN = '<!-- BEGIN generated-deeplinks -->'
const MARKER_END = '<!-- END generated-deeplinks -->'

const outputs = {
  yaml: path.join(repoRoot, 'contracts', 'routes.yaml'),
  pathsTs: path.join(repoRoot, 'frontend', 'src', 'config', 'paths.generated.ts'),
  pathsDart: path.join(repoRoot, 'mobile', 'lib', 'config', 'paths.generated.dart'),
  aasa: path.join(repoRoot, 'frontend', 'public', '.well-known', 'apple-app-site-association'),
  manifest: path.join(repoRoot, 'mobile', 'android', 'app', 'src', 'main', 'AndroidManifest.xml'),
}

function normalizeLocaleMap(value) {
  if (value === undefined || value === null) return null
  if (typeof value === 'string') return { [DEFAULT_LOCALE]: value }
  return value
}

function normalizeParams(params) {
  if (!params) return []
  return params.map((p) => ({ name: String(p) }))
}

function loadRoutes() {
  const raw = YAML.parse(readFileSync(outputs.yaml, 'utf8'))
  if (!raw || !Array.isArray(raw.routes)) {
    throw new Error('contracts/routes.yaml must define a top-level `routes:` array')
  }
  return raw.routes.map((route) => {
    const normalized = {
      id: route.id,
      path: normalizeLocaleMap(route.path),
      params: normalizeParams(route.params),
      web: route.web !== false,
      mobile: route.mobile === true,
      mobileName: route.mobileName ?? route.id,
      appScreen: route.appScreen !== false,
      deeplink: route.deeplink === true,
      webFallback: route.webFallback ?? null,
    }
    if (!normalized.id) throw new Error(`route is missing id: ${JSON.stringify(route)}`)
    if (!normalized.appScreen) {
      if (!normalized.mobile || !normalized.web) {
        throw new Error(
          `route ${normalized.id}: appScreen: false only applies to a web route with mobile: true`
        )
      }
      if (normalized.deeplink) {
        throw new Error(
          `route ${normalized.id}: appScreen: false cannot be a deeplink — the app has no screen to open`
        )
      }
    }
    if (!normalized.path?.[DEFAULT_LOCALE]) {
      throw new Error(`route ${normalized.id} is missing path.${DEFAULT_LOCALE}`)
    }
    for (const locale of Object.keys(normalized.path)) {
      if (!LOCALES.includes(locale)) {
        throw new Error(
          `route ${normalized.id}: unknown locale "${locale}" — allowed: ${LOCALES.join(', ')}`
        )
      }
      for (const param of normalized.params) {
        if (!normalized.path[locale].includes(`{${param.name}}`)) {
          throw new Error(`route ${normalized.id}: param ${param.name} not found in ${locale} path`)
        }
      }
    }
    return normalized
  })
}

/** Every web: false deeplink names the web page a browser falls back to, which must exist. */
function checkWebFallbacks(routes) {
  const byId = new Map(routes.map((route) => [route.id, route]))
  for (const route of routes) {
    if (route.web || !route.deeplink) {
      if (route.webFallback) {
        throw new Error(`route ${route.id}: webFallback only applies to a web: false deeplink`)
      }
      continue
    }
    if (!route.webFallback) {
      throw new Error(
        `route ${route.id}: a web: false deeplink needs a webFallback — without the app, the link ends on the web`
      )
    }
    const target = byId.get(route.webFallback)
    if (!target?.web) {
      throw new Error(`route ${route.id}: webFallback ${route.webFallback} is not a web route`)
    }
    const own = new Set(route.params.map((p) => p.name))
    for (const p of target.params) {
      if (!own.has(p.name)) {
        throw new Error(`route ${route.id}: webFallback ${route.webFallback} needs param ${p.name}`)
      }
    }
  }
}

function paramSlotTs(name) {
  return `\${${name}}`
}

function paramSlotDart(name) {
  return `\$${name}`
}

function fillTemplate(template, params, slotFn) {
  let out = template
  for (const p of params) {
    out = out.split(`{${p.name}}`).join(slotFn(p.name))
  }
  return out
}

function tsParamSig(params) {
  return params.map((p) => `${p.name}: string`).join(', ')
}

function dartParamSig(params) {
  return params.map((p) => `String ${p.name}`).join(', ')
}

function localePathMap(route) {
  const base = route.path
  const result = {}
  for (const locale of LOCALES) {
    result[locale] = base[locale] ?? base[DEFAULT_LOCALE]
  }
  return result
}

function generatePathsTs(routes) {
  const lines = [
    '// GENERATED by scripts/generate-routes.mjs — edit contracts/routes.yaml instead.',
    '',
    "import { getCurrentLocale } from './locale-context'",
    '',
    `export type Locale = ${LOCALES.map((l) => `'${l}'`).join(' | ')}`,
    `export const LOCALES = [${LOCALES.map((l) => `'${l}'`).join(', ')}] as const satisfies readonly Locale[]`,
    `export const DEFAULT_LOCALE: Locale = '${DEFAULT_LOCALE}'`,
    '',
    '/** Type-safe path builders — returns URL in the current locale. */',
    'export const paths = {',
  ]
  for (const route of routes) {
    if (!route.web) continue
    const sig = tsParamSig(route.params)
    const map = localePathMap(route)
    const uniqueLocales = new Set(Object.values(map))
    if (uniqueLocales.size === 1) {
      const template = map[DEFAULT_LOCALE]
      const body =
        route.params.length === 0
          ? `'${template}'`
          : `\`${fillTemplate(template, route.params, paramSlotTs)}\``
      lines.push(`  ${route.id}: (${sig}) => ${body},`)
    } else {
      lines.push(`  ${route.id}: (${sig}) => {`)
      lines.push(`    switch (getCurrentLocale()) {`)
      for (const locale of LOCALES) {
        if (locale === DEFAULT_LOCALE) continue
        const template = map[locale]
        const body =
          route.params.length === 0
            ? `'${template}'`
            : `\`${fillTemplate(template, route.params, paramSlotTs)}\``
        lines.push(`      case '${locale}': return ${body}`)
      }
      const enTemplate = map[DEFAULT_LOCALE]
      const enBody =
        route.params.length === 0
          ? `'${enTemplate}'`
          : `\`${fillTemplate(enTemplate, route.params, paramSlotTs)}\``
      lines.push(`      default: return ${enBody}`)
      lines.push('    }')
      lines.push('  },')
    }
  }
  lines.push('} as const')
  lines.push('')
  lines.push('/** Per-locale URL variants — returns all locale pattern strings. */')
  lines.push('export const pathVariants = {')
  for (const route of routes) {
    if (!route.web) continue
    const sig = tsParamSig(route.params)
    const map = localePathMap(route)
    const entries = LOCALES.map((locale) => {
      const template = map[locale]
      const body =
        route.params.length === 0
          ? `'${template}'`
          : `\`${fillTemplate(template, route.params, paramSlotTs)}\``
      return `${locale}: ${body}`
    })
    lines.push(`  ${route.id}: (${sig}): Record<Locale, string> => ({ ${entries.join(', ')} }),`)
  }
  lines.push('} as const')
  lines.push('')
  lines.push('/**')
  lines.push(
    ' * App-only deeplinks (web: false): every locale pattern, and the web route a browser lands on'
  )
  lines.push(' * instead — the universal link reaches the web whenever the app is not installed.')
  lines.push(' */')
  lines.push('export const appOnlyFallbacks = [')
  for (const route of routes) {
    if (route.web || !route.deeplink) continue
    const map = localePathMap(route)
    const patterns = [
      ...new Set(LOCALES.map((locale) => fillTemplate(map[locale], route.params, (n) => `:${n}`))),
    ]
    lines.push(
      `  { id: '${route.id}', patterns: [${patterns.map((p) => `'${p}'`).join(', ')}], fallback: '${route.webFallback}' as const },`
    )
  }
  lines.push('] as const')
  lines.push('')
  return lines.join('\n')
}

function generatePathsDart(routes) {
  const lines = [
    '// GENERATED by scripts/generate-routes.mjs — edit contracts/routes.yaml instead.',
    '// ignore_for_file: lines_longer_than_80_chars',
    '',
    "import 'locale_context.dart';",
    '',
    '/// Type-safe path builders — returns URL in the current locale.',
    'class Paths {',
    '  Paths._();',
    '',
  ]
  for (const route of routes) {
    if (!route.mobile) continue
    const sig = dartParamSig(route.params)
    const map = localePathMap(route)
    const uniqueLocales = new Set(Object.values(map))
    if (uniqueLocales.size === 1) {
      const template = map[DEFAULT_LOCALE]
      const body =
        route.params.length === 0
          ? `'${template}'`
          : `'${fillTemplate(template, route.params, paramSlotDart)}'`
      lines.push(`  static String ${route.mobileName}(${sig}) => ${body};`)
    } else {
      lines.push(`  static String ${route.mobileName}(${sig}) {`)
      lines.push('    switch (getCurrentLocale()) {')
      for (const locale of LOCALES) {
        if (locale === DEFAULT_LOCALE) continue
        const template = map[locale]
        const body =
          route.params.length === 0
            ? `'${template}'`
            : `'${fillTemplate(template, route.params, paramSlotDart)}'`
        lines.push(`      case '${locale}':`)
        lines.push(`        return ${body};`)
      }
      const enTemplate = map[DEFAULT_LOCALE]
      const enBody =
        route.params.length === 0
          ? `'${enTemplate}'`
          : `'${fillTemplate(enTemplate, route.params, paramSlotDart)}'`
      lines.push('      default:')
      lines.push(`        return ${enBody};`)
      lines.push('    }')
      lines.push('  }')
    }
  }
  lines.push('}')
  lines.push('')
  lines.push('/// Per-locale URL variants — returns all locale pattern strings.')
  lines.push('class PathVariants {')
  lines.push('  PathVariants._();')
  lines.push('')
  for (const route of routes) {
    if (!route.mobile) continue
    const sig = dartParamSig(route.params)
    const map = localePathMap(route)
    const entries = LOCALES.map((locale) => {
      const template = map[locale]
      const body =
        route.params.length === 0
          ? `'${template}'`
          : `'${fillTemplate(template, route.params, paramSlotDart)}'`
      return `'${locale}': ${body}`
    })
    lines.push(
      `  static Map<String, String> ${route.mobileName}(${sig}) => {${entries.join(', ')}};`
    )
  }
  lines.push('}')
  lines.push('')
  lines.push('/// Builders of [PathVariants] for pages of the **site** the app has no screen')
  lines.push('/// for (`appScreen: false`): their path only serves to open them in a browser.')
  lines.push('const Set<String> webOnlyRouteIds = <String>{')
  for (const route of routes) {
    if (!route.mobile || route.appScreen) continue
    lines.push(`  '${route.mobileName}',`)
  }
  lines.push('};')
  lines.push('')
  lines.push('/// Pages of the **site** a deeplink wildcard captures although the app has no')
  lines.push('/// screen for them, as anchored regular expressions. The OS hands such a link')
  lines.push('/// to the app, which opens it in the browser (docs/LEDGER_*.md MOB-59). The')
  lines.push('/// AASA excludes the same pages (`NOT …`); the Android manifest cannot.')
  lines.push('const List<String> sitePagePathPatterns = <String>[')
  for (const pattern of sitePagePatterns(routes, aasaPatterns(routes))) {
    const source = pattern
      .split('*')
      .map((part) => part.replace(/[.+?^${}()|[\]\\]/g, '\\$&'))
      .join('[^/]+')
    lines.push(`  r'^${source}/?$',`)
  }
  lines.push('];')
  lines.push('')
  return lines.join('\n')
}

/** The AASA pattern of one locale path: every parameter becomes `*`. */
function aasaPattern(route, locale) {
  let pattern = localePathMap(route)[locale]
  for (const p of route.params) {
    pattern = pattern.split(`{${p.name}}`).join('*')
  }
  return pattern
}

/** AASA matching: `*` matches any run of characters, `/` included. */
function aasaMatches(pattern, path) {
  const source = pattern
    .split('*')
    .map((part) => part.replace(/[.+?^${}()|[\]\\]/g, '\\$&'))
    .join('.*')
  return new RegExp(`^${source}$`).test(path)
}

function aasaPatterns(routes) {
  const seen = new Set()
  const patterns = []
  for (const route of routes) {
    if (!route.deeplink) continue
    for (const locale of LOCALES) {
      const pattern = aasaPattern(route, locale)
      if (!seen.has(pattern)) {
        seen.add(pattern)
        patterns.push(pattern)
      }
    }
  }
  return patterns
}

/**
 * The site's pages a deeplink wildcard would otherwise capture.
 *
 * `*` crosses `/`, so `/equipes/*` claims the whole team subtree, including pages the app has no
 * screen for (administration, ride or post forms…). The app opens those in the device's browser
 * (`openWebPage`, docs/LEDGER_*.md MOB-58), and the OS would hand them straight back to the app.
 * They become `NOT` entries at the head of the AASA (the first matching entry wins) and
 * `sitePagePathPatterns` in Dart, which sends them to the browser when Android — whose manifest
 * cannot exclude them — delivers one anyway (MOB-59). A deeplink's own path (each parameter as
 * `x`) must never be excluded — checked here rather than discovered on a phone.
 */
function sitePagePatterns(routes, deeplinkPatterns) {
  const deeplinks = new Set(deeplinkPatterns)
  const seen = new Set()
  const exclusions = []
  for (const route of routes) {
    // A page the app has a screen for stays with the app, deeplink or not.
    if (!route.web || route.deeplink || (route.mobile && route.appScreen)) continue
    for (const locale of LOCALES) {
      const pattern = aasaPattern(route, locale)
      if (seen.has(pattern) || deeplinks.has(pattern)) continue
      if (!deeplinkPatterns.some((d) => aasaMatches(d, pattern))) continue
      seen.add(pattern)
      exclusions.push(pattern)
    }
  }
  for (const route of routes) {
    if (!route.deeplink) continue
    for (const locale of LOCALES) {
      const sample = aasaPattern(route, locale).split('*').join('x')
      const culprit = exclusions.find((e) => aasaMatches(e, sample))
      if (culprit) {
        throw new Error(
          `route ${route.id}: its deeplink ${sample} would be excluded by NOT ${culprit}`
        )
      }
    }
  }
  return exclusions
}

function generateAasa(routes) {
  const deeplinkPatterns = aasaPatterns(routes)
  const exclusions = sitePagePatterns(routes, deeplinkPatterns).map((e) => `NOT ${e}`)
  const payload = {
    applinks: {
      apps: [],
      details: [
        {
          appID: IOS_APP_ID,
          paths: [...exclusions, ...deeplinkPatterns],
        },
      ],
    },
    webcredentials: {
      apps: [IOS_APP_ID],
    },
  }
  return JSON.stringify(payload, null, 2) + '\n'
}

function manifestEntries(routes) {
  const seen = new Set()
  const entries = []
  for (const route of routes) {
    if (!route.deeplink) continue
    const map = localePathMap(route)
    for (const locale of LOCALES) {
      const template = map[locale]
      let attr, value
      if (route.params.length === 0) {
        attr = 'android:path'
        value = template
      } else {
        attr = 'android:pathPattern'
        value = route.params.reduce((acc, p) => acc.split(`{${p.name}}`).join('.*'), template)
      }
      const key = `${attr}:${value}`
      if (!seen.has(key)) {
        seen.add(key)
        entries.push({ attr, value })
      }
    }
  }
  return entries
}

function generateManifestBlock(routes, indent) {
  return manifestEntries(routes)
    .map((e) => `${indent}<data ${e.attr}="${e.value}" />`)
    .join('\n')
}

function injectIntoManifest(routes) {
  const content = readFileSync(outputs.manifest, 'utf8')
  const beginIdx = content.indexOf(MARKER_BEGIN)
  const endIdx = content.indexOf(MARKER_END)
  if (beginIdx === -1 || endIdx === -1) {
    throw new Error(
      `AndroidManifest.xml is missing deeplink markers (${MARKER_BEGIN} / ${MARKER_END})`
    )
  }
  const lineStart = content.lastIndexOf('\n', beginIdx) + 1
  const indent = content.slice(lineStart, beginIdx)
  const block = generateManifestBlock(routes, indent)
  const before = content.slice(0, beginIdx + MARKER_BEGIN.length)
  const after = content.slice(endIdx)
  return `${before}\n${block}\n${indent}${after}`
}

function writeIfChanged(target, content) {
  let prev = null
  try {
    prev = readFileSync(target, 'utf8')
  } catch {}
  if (prev === content) return false
  writeFileSync(target, content)
  return true
}

function main() {
  const routes = loadRoutes()
  checkWebFallbacks(routes)
  const seen = new Set()
  for (const r of routes) {
    if (seen.has(r.id)) throw new Error(`Duplicate route id: ${r.id}`)
    seen.add(r.id)
  }

  const results = [
    ['paths.generated.ts', outputs.pathsTs, generatePathsTs(routes)],
    ['paths.generated.dart', outputs.pathsDart, generatePathsDart(routes)],
    ['apple-app-site-association', outputs.aasa, generateAasa(routes)],
    ['AndroidManifest.xml', outputs.manifest, injectIntoManifest(routes)],
  ]

  let changed = 0
  for (const [, target, content] of results) {
    const didWrite = writeIfChanged(target, content)
    const rel = path.relative(repoRoot, target)
    console.log(`${didWrite ? 'wrote ' : 'skip  '} ${rel}${didWrite ? '' : ' (unchanged)'}`)
    if (didWrite) changed += 1
  }
  console.log(`Generated ${routes.length} routes; ${changed} file(s) updated.`)
}

main()
