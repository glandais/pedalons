// @vitest-environment node
import fs from 'node:fs'
import path from 'node:path'
import { describe, expect, it, vi } from 'vitest'
import {
  BASE_POLICY,
  FCM_ORIGINS,
  buildDocumentPolicy,
  createConfigOriginResolver,
  documentCspHeaders,
  generateNonce,
  nonceInlineScripts,
  originOf,
  parseCspMode,
  parseExtraSources,
  styleDocumentOrigins,
} from './csp.js'

/** `directive` → its source list, from a policy string. */
const directives = (policy) =>
  Object.fromEntries(
    policy.split(';').map((part) => {
      const [name, ...sources] = part.trim().split(/\s+/)
      return [name, sources]
    })
  )

/** The defaults of backend/src/main/resources/application.properties, as GET /api/config serves them. */
const config = {
  mapStyles: [
    {
      id: 'colorful',
      url: 'https://tiles.versatiles.org/assets/styles/colorful/style.json',
      darkVariant: 'https://tiles.versatiles.org/assets/styles/eclipse/style.json',
    },
    {
      id: 'ign-vector',
      url: 'https://data.geopf.fr/annexes/ressources/vectorTiles/styles/PLAN.IGN/standard.json',
    },
    { id: 'osm', url: 'https://www.pedalons.fr/api/map/styles/osm.json' },
    { id: 'cyclosm', url: 'https://www.pedalons.fr/api/map/styles/cyclosm.json' },
  ],
  terrain: { url: 'https://tiles.mapterhorn.com/tilejson.json', maxZoom: 16 },
  webPush: { apiKey: 'k', appId: 'a', messagingSenderId: 's', vapidKey: 'v' },
}

const generatedStyles = {
  '/api/map/styles/osm.json': {
    version: 8,
    sources: {
      raster: { type: 'raster', tiles: ['https://tile.openstreetmap.org/{z}/{x}/{y}.png'] },
    },
    layers: [],
  },
  '/api/map/styles/cyclosm.json': {
    version: 8,
    sources: {
      raster: {
        type: 'raster',
        tiles: [
          'https://a.tile-cyclosm.openstreetmap.fr/cyclosm/{z}/{x}/{y}.png',
          'https://b.tile-cyclosm.openstreetmap.fr/cyclosm/{z}/{x}/{y}.png',
        ],
      },
    },
    layers: [],
  },
}

describe('generateNonce', () => {
  it('is 128 random bits, different on every call', () => {
    const nonces = new Set(Array.from({ length: 1000 }, generateNonce))
    expect(nonces.size).toBe(1000)
    for (const nonce of nonces) expect(Buffer.from(nonce, 'base64')).toHaveLength(16)
  })
})

describe('buildDocumentPolicy', () => {
  it('allows scripts by nonce and same origin only, never inline or eval', () => {
    const nonce = generateNonce()
    const policy = directives(buildDocumentPolicy({ nonce }))
    expect(policy['script-src']).toEqual(["'self'", `'nonce-${nonce}'`])
    expect(policy['script-src']).not.toContain("'unsafe-inline'")
    expect(policy['script-src']).not.toContain("'unsafe-eval'")
    expect(policy['default-src']).toEqual(["'self'"])
    expect(policy['worker-src']).toEqual(["'self'"])
  })

  it('keeps the four SEC-30 directives and reports to the server.js route', () => {
    const policy = buildDocumentPolicy({ nonce: 'n' })
    for (const directive of BASE_POLICY.split('; ')) expect(policy).toContain(directive)
    expect(directives(policy)['report-uri']).toEqual(['/csp-report'])
    expect(directives(policy)['report-to']).toEqual(['csp'])
  })

  it('keeps inline styles (Mantine) and images from any https host (markdown)', () => {
    const policy = directives(buildDocumentPolicy({ nonce: 'n' }))
    expect(policy['style-src']).toEqual(["'self'", "'unsafe-inline'"])
    expect(policy['img-src']).toEqual(["'self'", 'data:', 'blob:', 'https:'])
  })

  it('lists the connect origins once each, after self', () => {
    const policy = directives(
      buildDocumentPolicy({
        nonce: 'n',
        connectOrigins: ['https://a.example', 'https://b.example', 'https://a.example'],
      })
    )
    expect(policy['connect-src']).toEqual(["'self'", 'https://a.example', 'https://b.example'])
  })

  it('refuses to build a policy without a nonce', () => {
    expect(() => buildDocumentPolicy({})).toThrow()
  })
})

describe('documentCspHeaders', () => {
  const policy = buildDocumentPolicy({ nonce: 'n' })

  it('reports the full policy beside the enforced SEC-30 one by default', () => {
    const headers = documentCspHeaders(parseCspMode(undefined).mode, policy)
    expect(headers['Content-Security-Policy']).toBe(BASE_POLICY)
    expect(headers['Content-Security-Policy-Report-Only']).toBe(policy)
    expect(headers['Reporting-Endpoints']).toBe('csp="/csp-report"')
  })

  it('enforces the full policy, alone, with CSP_MODE=enforce', () => {
    const headers = documentCspHeaders(parseCspMode('enforce').mode, policy)
    expect(headers['Content-Security-Policy']).toBe(policy)
    expect(headers).not.toHaveProperty('Content-Security-Policy-Report-Only')
  })
})

describe('parseCspMode', () => {
  it('reports unless told to enforce', () => {
    expect(parseCspMode(undefined)).toEqual({ mode: 'report-only' })
    expect(parseCspMode('')).toEqual({ mode: 'report-only' })
    expect(parseCspMode('report-only')).toEqual({ mode: 'report-only' })
    expect(parseCspMode(' Enforce ')).toEqual({ mode: 'enforce' })
    expect(parseCspMode('true')).toEqual({ mode: 'report-only', invalid: 'true' })
  })
})

describe('origins', () => {
  it('keeps only an http(s) origin', () => {
    expect(originOf('https://tile.openstreetmap.org/{z}/{x}/{y}.png')).toBe(
      'https://tile.openstreetmap.org'
    )
    expect(originOf('http://localhost:8080/x')).toBe('http://localhost:8080')
    expect(originOf('javascript:alert(1)')).toBeNull()
    expect(originOf('data:text/plain,x')).toBeNull()
    expect(originOf('/relative')).toBeNull()
    expect(originOf('https://{s}.tile.example/x')).toBeNull()
    expect(originOf(undefined)).toBeNull()
  })

  it('takes tiles, TileJSON, sprite and glyph hosts from a style document', () => {
    expect(
      styleDocumentOrigins({
        sources: {
          a: { tiles: ['https://t1.example/{z}'] },
          b: { url: 'https://tilejson.example/x.json' },
        },
        sprite: [{ id: 'default', url: 'https://sprites.example/s' }],
        glyphs: 'https://glyphs.example/{fontstack}/{range}.pbf',
      })
    ).toEqual([
      'https://t1.example',
      'https://tilejson.example',
      'https://sprites.example',
      'https://glyphs.example',
    ])
    expect(styleDocumentOrigins(null)).toEqual([])
  })

  it('accepts only origins as extras, so nothing can close a directive', () => {
    expect(
      parseExtraSources('https://cdn.example, https://*.tiles.example wss://ws.example/')
    ).toEqual({
      accepted: ['https://cdn.example', 'https://*.tiles.example', 'wss://ws.example'],
      rejected: [],
    })
    expect(parseExtraSources("https://a.example;script-src 'unsafe-inline' *").rejected).toEqual([
      'https://a.example;script-src',
      "'unsafe-inline'",
      '*',
    ])
    expect(parseExtraSources(undefined)).toEqual({ accepted: [], rejected: [] })
  })
})

describe('createConfigOriginResolver', () => {
  const resolver = (overrides = {}) => {
    const fetchStyle = vi.fn(async (stylePath) => {
      const style = generatedStyles[stylePath]
      if (!style) throw new Error('404')
      return style
    })
    return { fetchStyle, configOrigins: createConfigOriginResolver({ fetchStyle, ...overrides }) }
  }

  it('derives the hosts from the config, the generated raster styles and web push', async () => {
    const { configOrigins } = resolver()
    const origins = await configOrigins(config)
    expect(new Set(origins)).toEqual(
      new Set([
        'https://tiles.versatiles.org',
        'https://data.geopf.fr',
        'https://tiles.mapterhorn.com',
        ...FCM_ORIGINS,
        'https://tile.openstreetmap.org',
        'https://a.tile-cyclosm.openstreetmap.fr',
        'https://b.tile-cyclosm.openstreetmap.fr',
      ])
    )
    // A generated style is same-origin (mapStyles.ts sameOriginIfApi): its host is not listed.
    expect(origins).not.toContain('https://www.pedalons.fr')
  })

  it('leaves Firebase out when the config offers no web push, and copes with no config', async () => {
    const { configOrigins } = resolver()
    const origins = await configOrigins({ ...config, webPush: undefined })
    for (const origin of FCM_ORIGINS) expect(origins).not.toContain(origin)
  })

  it('has no origins to offer without a config until one has been seen, then keeps the last', async () => {
    const { configOrigins } = resolver()
    expect(await configOrigins(undefined)).toBeNull()
    const origins = await configOrigins(config)
    expect(await configOrigins(undefined)).toEqual(origins)
  })

  it('reads each generated style once per TTL, shared by concurrent requests', async () => {
    let clock = 0
    const { fetchStyle, configOrigins } = resolver({ ttlMs: 1000, now: () => clock })
    await Promise.all([configOrigins(config), configOrigins(config)])
    expect(fetchStyle).toHaveBeenCalledTimes(2) // osm + cyclosm
    clock = 999
    await configOrigins(config)
    expect(fetchStyle).toHaveBeenCalledTimes(2)
    clock = 1001
    await configOrigins(config)
    expect(fetchStyle).toHaveBeenCalledTimes(4)
  })

  it('leaves out the hosts of a style it cannot read, and retries it later', async () => {
    let clock = 0
    const onError = vi.fn()
    const { fetchStyle, configOrigins } = resolver({
      failureTtlMs: 100,
      now: () => clock,
      onError,
    })
    const broken = {
      mapStyles: [{ id: 'gone', url: 'https://www.pedalons.fr/api/map/styles/gone.json' }],
    }
    expect(await configOrigins(broken)).toEqual([])
    expect(onError).toHaveBeenCalledOnce()
    await configOrigins(broken)
    expect(fetchStyle).toHaveBeenCalledTimes(1)
    clock = 101
    await configOrigins(broken)
    expect(fetchStyle).toHaveBeenCalledTimes(2)
  })

  it('keeps the hosts of the last successful read when a refetch fails', async () => {
    let clock = 0
    let failing = false
    const onError = vi.fn()
    const fetchStyle = vi.fn(async (stylePath) => {
      if (failing) throw new Error('backend restarting')
      return generatedStyles[stylePath]
    })
    const configOrigins = createConfigOriginResolver({
      fetchStyle,
      ttlMs: 1000,
      failureTtlMs: 100,
      now: () => clock,
      onError,
    })
    const osm = { mapStyles: [{ id: 'osm', url: '/api/map/styles/osm.json' }] }
    const good = await configOrigins(osm)
    expect(good).toContain('https://tile.openstreetmap.org')

    failing = true
    clock = 1001
    expect(await configOrigins(osm)).toEqual(good)
    expect(onError).toHaveBeenCalledOnce()
    // Retried after failureTtlMs, still serving the old hosts while it fails...
    clock = 1102
    expect(await configOrigins(osm)).toEqual(good)
    expect(fetchStyle).toHaveBeenCalledTimes(3)
    // ...and the fresh document once it is back.
    failing = false
    clock = 1203
    expect(await configOrigins(osm)).toEqual(good)
    expect(fetchStyle).toHaveBeenCalledTimes(4)
  })

  it('never fetches an /api path that is not a generated style', async () => {
    const { fetchStyle, configOrigins } = resolver()
    await configOrigins({ mapStyles: [{ url: '/api/admin/../users/me' }, { url: '/api/x' }] })
    expect(fetchStyle).not.toHaveBeenCalled()
  })
})

describe('nonceInlineScripts', () => {
  it('stamps the theme script of index.html, and not the module entry', () => {
    const template = fs.readFileSync(path.resolve(import.meta.dirname, '../index.html'), 'utf-8')
    const stamped = nonceInlineScripts(template, 'abc')
    expect(stamped.match(/<script nonce="abc">\(function\(\)\{/g)).toHaveLength(1)
    expect(stamped).toContain('<script type="module" src="/src/entry-client.tsx"></script>')
    // Every inline script of the template now carries it: none would be blocked.
    expect(stamped).not.toMatch(/<script>/)
  })
})
