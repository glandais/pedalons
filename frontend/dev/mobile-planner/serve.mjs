// Harness of the planner the mobile app embeds (src/embed/mobile-planner, ledger WEB-183): serves
// the built `mobile/assets/planner/` to a desktop browser with a fake `PedalonsBridge`, so the page
// can be tried without the app. Never shipped: nothing of the build reads this folder.
//
//   pnpm build:mobile-planner
//   pnpm dev:mobile-planner                      canned answers, no backend
//   API=http://localhost:8080 TOKEN=<access token> TEAM=<team slug> pnpm dev:mobile-planner
//
// then http://localhost:5199/?theme=dark&locale=en&units=IMPERIAL (all optional). Open it with the
// devtools' device toolbar on: the page is the touch editor and reads `(pointer: coarse)`.
//
// With API, every `request` of the page is sent there by this server, as Flutter's Dio will: with
// the bearer token, on the closed list of paths. The basemaps come from its `GET /api/config`, the
// style documents it serves itself fetched here and handed over as objects.
import fs from 'node:fs'
import http from 'node:http'
import path from 'node:path'

const PORT = Number(process.env.PORT ?? 5199)
const API = process.env.API?.replace(/\/$/, '')
const TOKEN = process.env.TOKEN
const TEAM = process.env.TEAM ?? 'demo'
const here = import.meta.dirname
const assets = path.resolve(here, '../../../mobile/assets/planner')

const ALLOWED = [
  /^\/api\/router$/,
  /^\/api\/router\/elevation$/,
  /^\/api\/router\/import-gpx$/,
  /^\/api\/geocode\/(search|place)\?/,
]

const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css' }

function apiHeaders() {
  return {
    ...(TOKEN && { Authorization: `Bearer ${TOKEN}` }),
    // The tenant is the API's own host, as the site's dev proxy does
    'X-Forwarded-Host': new URL(API).host,
  }
}

/** One `request` of the page, sent to the API. */
async function forward({ method, path: target, body }) {
  if (!ALLOWED.some((pattern) => pattern.test(target))) return { status: 0 }
  const init = { method, headers: apiHeaders() }
  if (body?.multipart) {
    const form = new FormData()
    for (const [key, value] of Object.entries(body.multipart.fields)) form.append(key, value)
    const { name, base64, contentType } = body.multipart.file
    form.append('gpxFile', new Blob([Buffer.from(base64, 'base64')], { type: contentType }), name)
    init.body = form
  } else if (body !== undefined) {
    init.headers['Content-Type'] = 'application/json'
    init.body = JSON.stringify(body)
  }
  try {
    const response = await fetch(API + target, init)
    const text = await response.text()
    const retryAfter = Number(response.headers.get('retry-after'))
    return {
      status: response.status,
      body: text,
      ...(Number.isFinite(retryAfter) && retryAfter > 0 && { retryAfter }),
    }
  } catch {
    return { status: 0 }
  }
}

/** Without an API: a straight line for a leg, two places for a search, a refusal for the rest. */
function canned({ path: target, body }) {
  if (target === '/api/router') {
    const { from, to } = body
    const coordinates = Array.from({ length: 21 }, (_, i) => [
      from.lng + ((to.lng - from.lng) * i) / 20,
      from.lat + ((to.lat - from.lat) * i) / 20,
      50 + 30 * Math.sin(i / 3),
    ])
    return { status: 200, body: { route: { type: 'LineString', coordinates }, unpaved: [] } }
  }
  if (target.startsWith('/api/geocode/search')) {
    return {
      status: 200,
      body: [
        { id: 'canned:nantes', displayName: 'Nantes, France', lat: 47.218, lon: -1.553 },
        { id: 'canned:annecy', displayName: 'Annecy, France' },
      ],
    }
  }
  if (target.startsWith('/api/geocode/place')) {
    return {
      status: 200,
      body: { id: 'canned:annecy', displayName: 'Annecy', lat: 45.9, lon: 6.13 },
    }
  }
  if (target === '/api/router/import-gpx') return { status: 400, body: { code: 'GPX_FAILURE' } }
  return { status: 404, body: '' }
}

const OSM_STYLE = {
  version: 8,
  sources: {
    osm: {
      type: 'raster',
      tiles: ['https://tile.openstreetmap.org/{z}/{x}/{y}.png'],
      tileSize: 256,
      maxzoom: 19,
      attribution: '© OpenStreetMap contributors',
    },
  },
  layers: [{ id: 'osm', type: 'raster', source: 'osm' }],
}

/** What the app would pass to `load`. */
async function loadPayload() {
  const base = { teamSlug: TEAM, theme: 'light', locale: 'fr', units: 'METRIC' }
  if (!API) {
    return {
      ...base,
      styles: [{ id: 'osm', label: 'OpenStreetMap', group: 'raster', style: OSM_STYLE }],
      defaultCenter: { lon: -1.553, lat: 47.218, zoom: 11 },
    }
  }
  const config = await (await fetch(`${API}/api/config`, { headers: apiHeaders() })).json()
  const document = async (url) => {
    if (!url || !new URL(url, API).pathname.startsWith('/api/')) return undefined
    return (await fetch(new URL(url, API), { headers: apiHeaders() })).json()
  }
  const styles = []
  for (const entry of config.mapStyles) {
    const style = await document(entry.url)
    const darkStyle = await document(entry.darkVariant)
    styles.push({
      ...entry,
      ...(style && { style, url: undefined }),
      ...(darkStyle && { darkStyle, darkVariant: undefined }),
    })
  }
  return { ...base, styles, terrain: config.terrain, defaultCenter: config.defaultCenter }
}

function json(res, value) {
  res.writeHead(200, { 'Content-Type': 'application/json' })
  res.end(JSON.stringify(value))
}

http
  .createServer(async (req, res) => {
    try {
      const url = new URL(req.url, `http://localhost:${PORT}`)
      if (url.pathname === '/__load') return json(res, await loadPayload())
      if (url.pathname === '/__request') {
        const chunks = []
        for await (const chunk of req) chunks.push(chunk)
        const message = JSON.parse(Buffer.concat(chunks).toString())
        return json(res, API ? await forward(message) : canned(message))
      }
      if (url.pathname === '/__fake-bridge.js') {
        res.writeHead(200, { 'Content-Type': 'text/javascript' })
        return res.end(fs.readFileSync(path.join(here, 'fake-bridge.js')))
      }
      const name = url.pathname === '/' ? 'index.html' : path.basename(url.pathname)
      const file = path.join(assets, name)
      if (!fs.existsSync(file)) {
        res.writeHead(404)
        return res.end('not found — run `pnpm build:mobile-planner` first')
      }
      let content = fs.readFileSync(file)
      if (name === 'index.html') {
        // The fake bridge must exist before planner.js says `ready`
        content = content
          .toString()
          .replace('<script src="worker-src.js">', '<script src="/__fake-bridge.js"></script>$&')
      }
      res.writeHead(200, {
        'Content-Type': TYPES[path.extname(name)] ?? 'application/octet-stream',
      })
      res.end(content)
    } catch (error) {
      res.writeHead(500)
      res.end(String(error))
    }
  })
  .listen(PORT, () => {
    console.log(
      `planner harness: http://localhost:${PORT}/  (${API ? `API ${API}` : 'canned answers'})`
    )
  })
