import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import express from 'express'
import compression from 'compression'
import expressStaticGzip from 'express-static-gzip'
import { createProxyMiddleware } from 'http-proxy-middleware'
import {
  BASE_POLICY,
  buildDocumentPolicy,
  createConfigOriginResolver,
  documentCspHeaders,
  generateNonce,
  nonceInlineScripts,
  parseCspMode,
  parseExtraSources,
} from './server/csp.js'
import { mountCspReportRoute } from './server/cspReport.js'
import { SSR_AUTH_STATE_ID, SSR_QUERY_STATE_ID, jsonScript } from './server/ssrState.js'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const isProduction = process.env.NODE_ENV === 'production'
const port = process.env.PORT || 3000
const apiTarget = process.env.API_BASE_URL || 'http://localhost:8080'

// apple-app-site-association lives under public/ in dev, and is copied into
// dist/client/ by the build. It must be served with a JSON content type (nginx
// did this via nginx-spa.conf); express.static would serve it as octet-stream.
const wellKnownDir = isProduction
  ? path.resolve(__dirname, 'dist/client/.well-known')
  : path.resolve(__dirname, 'public/.well-known')

const DEFAULT_APP_NAME = 'Pédalons'

// The site's CSP (server/csp.js, docs/LEDGER_*.md SEC-31). CSP_MODE=enforce enforces the document
// policy; anything else (the default) only reports it, beside SEC-30's four directives. Production
// only: the Vite dev server injects an inline React Refresh preamble and talks over a websocket.
const csp = parseCspMode(process.env.CSP_MODE)
if (csp.invalid !== undefined) {
  console.warn(`[csp] Unknown CSP_MODE "${csp.invalid}", reporting only`)
}
const cspExtraSources = parseExtraSources(process.env.CSP_CONNECT_SRC_EXTRA)
if (cspExtraSources.rejected.length) {
  console.warn('[csp] CSP_CONNECT_SRC_EXTRA: not origins, ignored:', cspExtraSources.rejected)
}

/**
 * The web app manifest. Only the name varies by domain — every tenant shares the icon set of
 * public/ (see docs/BRANDING.md). `id` and `start_url` are the site root: on a site pinned to one team,
 * `/` already opens that team. Colours are the brand blue of the icon background, as theme-color
 * in index.html.
 */
function webManifest(appName) {
  const shortName = appName.length > 12 ? appName.slice(0, 12).trim() : appName
  return {
    id: '/',
    name: appName,
    short_name: shortName,
    start_url: '/',
    scope: '/',
    display: 'standalone',
    theme_color: '#228be6',
    background_color: '#228be6',
    icons: [
      { src: '/pwa-64x64.png', sizes: '64x64', type: 'image/png' },
      { src: '/pwa-192x192.png', sizes: '192x192', type: 'image/png' },
      { src: '/pwa-512x512.png', sizes: '512x512', type: 'image/png', purpose: 'any' },
      {
        src: '/maskable-icon-512x512.png',
        sizes: '512x512',
        type: 'image/png',
        purpose: 'maskable',
      },
    ],
  }
}

async function createServer() {
  const app = express()
  // No `X-Powered-By: Express` (audit V4, docs/LEDGER_*.md SEC-30).
  app.disable('x-powered-by')

  // Behind traefik (prod) / http-proxy-middleware (dev) — trust X-Forwarded-* so
  // req.protocol and req.ip reflect the original client.
  app.set('trust proxy', true)

  // API proxy — must be before Vite middleware. In prod, traefik routes /api
  // straight to the backend and this never runs.
  //
  // Mounted at the root with pathFilter (not app.use('/api', ...)): Express's path-mount form
  // strips the '/api' prefix from req.url before the middleware sees it, and http-proxy-middleware
  // v4 (unlike v2/v3) no longer restores it — every request silently proxied to
  // "<target>/<path-without-/api>" instead of "<target>/api/<path>", 404ing against a real
  // upstream (or just failing to connect against one that isn't listening on that empty path).
  app.use(
    createProxyMiddleware({
      target: apiTarget,
      changeOrigin: true,
      pathFilter: '/api',
      on: {
        proxyReq: (proxyReq, req) => {
          const host = req.headers.host || req.headers[':authority'] || 'localhost'
          proxyReq.setHeader('X-Forwarded-Host', host)
          proxyReq.setHeader('X-Forwarded-Proto', req.protocol)
        },
        error: (err, req, res) => {
          console.error('[proxy] API proxy error:', err.message)
          if (res.writeHead && !res.headersSent) {
            res.writeHead(502, { 'Content-Type': 'application/json' })
            res.end(JSON.stringify({ error: 'API unavailable' }))
          } else {
            res.end()
          }
        },
      },
    })
  )

  // SEC-30's four directives on everything else this server answers, set before any route can end
  // the response; the SSR handler below adds the document policy (docs/LEDGER_*.md SEC-31). After
  // the API proxy on purpose: the API must carry no policy of ours (server/csp.js says why), and in
  // prod Traefik routes /api to the backend anyway.
  app.use((_req, res, next) => {
    res.setHeader('Content-Security-Policy', BASE_POLICY)
    next()
  })

  // Violation reports of the document policy, one log line each (server/cspReport.js).
  mountCspReportRoute(app)

  // The map and push hosts of a config, for the document policy's connect-src. The generated raster
  // styles are read from the backend directly, as the SSR render reads everything else.
  const configOrigins = createConfigOriginResolver({
    fetchStyle: async (stylePath) => {
      const response = await fetch(`${apiTarget}${stylePath}`, {
        headers: { Accept: 'application/json' },
        signal: AbortSignal.timeout(2000),
      })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      return response.json()
    },
    onError: (stylePath, err) => {
      console.error(`[csp] Failed to read the map style ${stylePath}:`, err.message)
    },
  })

  // Serve apple-app-site-association as JSON (parity with nginx-spa.conf). Must be
  // registered before the static/Vite middleware so it wins the content type.
  // `dotfiles: 'allow'` is required: send (express 5) 404s any path with a segment
  // starting with a dot, so /.well-known/* is invisible to sendFile without it.
  app.get('/.well-known/apple-app-site-association', (_req, res) => {
    res.type('application/json')
    res.sendFile(
      path.join(wellKnownDir, 'apple-app-site-association'),
      { dotfiles: 'allow' },
      (err) => {
        if (err && !res.headersSent) {
          res.status(404).end()
        }
      }
    )
  })

  // The service worker (public/sw.js). Served by its own route so it is never cached for long:
  // express.static below would give it 31 days, and a browser would then keep running a stale
  // worker. Registered for the whole site, hence Service-Worker-Allowed.
  const swFile = isProduction
    ? path.resolve(__dirname, 'dist/client/sw.js')
    : path.resolve(__dirname, 'public/sw.js')
  app.get('/sw.js', (_req, res) => {
    res.set({ 'Cache-Control': 'no-cache', 'Service-Worker-Allowed': '/' })
    res.type('application/javascript')
    res.sendFile(swFile, (err) => {
      if (err && !res.headersSent) {
        res.status(404).end()
      }
    })
  })

  // The web app manifest, per domain: the installed app is named after the site it was installed
  // from (GET /api/config resolves the tenant from the forwarded host, as for every SSR request).
  app.get('/manifest.webmanifest', async (req, res) => {
    const host = req.headers['x-forwarded-host'] || req.headers.host
    let appName = DEFAULT_APP_NAME
    try {
      const response = await fetch(`${apiTarget}/api/config`, {
        headers: {
          Accept: 'application/json',
          ...(host ? { 'X-Forwarded-Host': String(host) } : {}),
          'X-Forwarded-Proto': req.protocol,
        },
        signal: AbortSignal.timeout(3000),
      })
      if (response.ok) {
        const config = await response.json()
        appName = config.appName || DEFAULT_APP_NAME
      }
    } catch (err) {
      // An install must not fail for want of the name: fall back to the brand.
      console.error('[manifest] Failed to load config:', err.message)
    }
    res
      .set({
        'Content-Type': 'application/manifest+json',
        'Cache-Control': 'public, max-age=3600',
        Vary: 'Host, X-Forwarded-Host',
      })
      .send(JSON.stringify(webManifest(appName)))
  })

  // Everything else under /.well-known (assetlinks.json for Android App Links and
  // passkey origins). Mounted on its own path so the dot segment is stripped before
  // send sees it; extensions still drive the content type.
  app.use('/.well-known', express.static(wellKnownDir, { index: false }))

  let vite
  let template
  let render
  let renderSitemap
  let renderLlmsTxt

  // The SSR render refreshes the visitor's session, and the refresh rotates its token
  // (docs/LEDGER_*.md SEC-27): the new cookie must reach the browser on whatever this server answers
  // — page, redirect or error. Kept from the browser, the old one becomes a replay once the
  // rotation's grace is over, and a replay revokes the session.
  const relayRotatedSessionCookie = (res, sink) => {
    if (!sink.setCookies?.length || sink.relayed) return
    res.append('Set-Cookie', sink.setCookies)
    sink.relayed = true
  }

  const publicHost = (req) =>
    String(req.headers['x-forwarded-host'] || req.headers.host || 'localhost')

  // robots.txt, served here rather than as a static file so it can name this host's sitemap: the
  // protocol wants an absolute URL, and every tenant has its own host. The rules themselves stay in
  // public/robots.txt.
  const robotsPath = isProduction
    ? path.resolve(__dirname, 'dist/client/robots.txt')
    : path.resolve(__dirname, 'public/robots.txt')
  app.get('/robots.txt', (req, res) => {
    const rules = fs.readFileSync(robotsPath, 'utf-8').trimEnd()
    res
      .set({
        'Content-Type': 'text/plain; charset=utf-8',
        'Cache-Control': 'public, max-age=3600',
        Vary: 'Host, X-Forwarded-Host',
      })
      .send(`${rules}\n\nSitemap: ${req.protocol}://${publicHost(req)}/sitemap.xml\n`)
  })

  // The public pages of this host's site (docs/LEDGER_DONE.md WEB-31). Anonymous and the same for
  // every visitor of a host, hence cacheable, unlike the HTML pages below.
  app.get('/sitemap.xml', async (req, res) => {
    try {
      const sitemapRenderer = isProduction
        ? renderSitemap
        : (await vite.ssrLoadModule('/src/entry-server.tsx')).renderSitemap
      const xml = await sitemapRenderer({
        host: publicHost(req),
        'x-forwarded-host': publicHost(req),
        'x-forwarded-proto': req.protocol,
      })
      res
        .set({
          'Content-Type': 'application/xml; charset=utf-8',
          'Cache-Control': 'public, max-age=3600',
          Vary: 'Host, X-Forwarded-Host',
        })
        .send(xml)
    } catch (err) {
      console.error('[sitemap] Failed to build the sitemap:', err.message)
      res.status(503).set('Cache-Control', 'no-store').send('Sitemap unavailable')
    }
  })

  // llms.txt (https://llmstxt.org): this host's public teams and its sitemap, for a language model
  // (docs/LEDGER_DONE.md WEB-34). Nothing the sitemap does not already expose; cacheable likewise.
  app.get('/llms.txt', async (req, res) => {
    try {
      const llmsTxtRenderer = isProduction
        ? renderLlmsTxt
        : (await vite.ssrLoadModule('/src/entry-server.tsx')).renderLlmsTxt
      const txt = await llmsTxtRenderer({
        host: publicHost(req),
        'x-forwarded-host': publicHost(req),
        'x-forwarded-proto': req.protocol,
      })
      res
        .set({
          'Content-Type': 'text/markdown; charset=utf-8',
          'Cache-Control': 'public, max-age=3600',
          Vary: 'Host, X-Forwarded-Host',
        })
        .send(txt)
    } catch (err) {
      console.error('[llms.txt] Failed to build llms.txt:', err.message)
      res.status(503).set('Cache-Control', 'no-store').send('llms.txt unavailable')
    }
  })

  if (isProduction) {
    // compression() is for what is rendered per request (SSR pages, sitemap, llms.txt). The static
    // files come pre-compressed from the build (vite-plugin-compression2, .br/.gz siblings):
    // express-static-gzip picks the variant the browser accepts and sets Content-Encoding, which
    // compression() then leaves alone — no more gzipping map-vendor on every request
    // (docs/LEDGER_*.md WEB-82). A file without a variant falls through to plain serve-static.
    app.use(compression())
    app.use(
      expressStaticGzip(path.resolve(__dirname, 'dist/client'), {
        enableBrotli: true,
        orderPreference: ['br', 'gzip'],
        index: false,
        serveStatic: {
          index: false,
          setHeaders: (res, filePath) => {
            // Hashed build assets are immutable and safe to cache for a long time.
            if (filePath.includes(`${path.sep}assets${path.sep}`)) {
              res.setHeader('Cache-Control', 'public, max-age=2678400, immutable')
            } else {
              res.setHeader('Cache-Control', 'public, max-age=2678400')
            }
          },
        },
      })
    )
    template = fs.readFileSync(path.resolve(__dirname, 'dist/client/index.html'), 'utf-8')
    const serverModule = await import(path.resolve(__dirname, 'dist/server/entry-server.js'))
    render = serverModule.render
    renderSitemap = serverModule.renderSitemap
    renderLlmsTxt = serverModule.renderLlmsTxt
  } else {
    const { createServer: createViteServer } = await import('vite')
    vite = await createViteServer({
      server: { middlewareMode: true },
      appType: 'custom',
    })
    app.use(vite.middlewares)
  }

  // 503 once SIGTERM is received: traefik's health check routes around this instance while it
  // still serves (see the drain below).
  let draining = false
  app.get('/health', (_, res) => (draining ? res.status(503).send('draining') : res.send('ok')))

  // Express 5 / path-to-regexp v8: bare '*' throws — the catch-all wildcard must
  // be named ('*splat').
  app.use('*splat', async (req, res) => {
    const url = req.originalUrl
    // Filled by render() as soon as the SSR session refresh answers (see relayRotatedSessionCookie).
    const sink = {}
    // This document's CSP nonce: on the inline scripts of the template and of React Router.
    const nonce = generateNonce()

    try {
      let currentTemplate, currentRender

      if (isProduction) {
        currentTemplate = template
        currentRender = render
      } else {
        currentTemplate = fs.readFileSync(path.resolve(__dirname, 'index.html'), 'utf-8')
        currentTemplate = await vite.transformIndexHtml(url, currentTemplate)
        const module = await vite.ssrLoadModule('/src/entry-server.tsx')
        currentRender = module.render
      }

      // Filter to single-value headers — render() types headers as Record<string, string>, but Express req.headers can contain string[] values (e.g. set-cookie)
      const result = await currentRender(
        url,
        Object.fromEntries(Object.entries(req.headers).filter(([, v]) => typeof v === 'string')),
        sink,
        { nonce }
      )
      relayRotatedSessionCookie(res, sink)

      // Handle redirects. Never cached, even a 301: browsers keep a permanent redirect with no
      // Cache-Control indefinitely, and these are not forever — a team can take its former slug
      // back, or another team take it, and a cached /equipes/a → /equipes/b would then loop or
      // land on the wrong team. Some depend on the session too, like the pages below.
      if (result.redirect) {
        res
          .set({ 'Cache-Control': 'no-store', Vary: 'Cookie' })
          .redirect(result.statusCode || 302, result.redirect)
        return
      }

      const { html: appHtml, dehydratedState, auth, lang, head, themePreference, config } = result

      // Data blocks, not scripts (server/ssrState.js): they never run, so the CSP needs no exception
      // for them, and every '<' is escaped so no </script> in the data can close them.
      let stateScript = ''
      try {
        stateScript = dehydratedState ? jsonScript(SSR_QUERY_STATE_ID, dehydratedState) : ''
      } catch (serErr) {
        console.error(`[SSR] Failed to serialize dehydrated state for "${url}":`, serErr)
        // Continue without SSR state — client will refetch
      }

      // The session the page was rendered with, so the client's first render matches the markup.
      // It carries a 15-minute access token: this response must never be cached or shared, which is
      // what the Cache-Control/Vary headers below enforce.
      let authScript = ''
      try {
        authScript = auth ? jsonScript(SSR_AUTH_STATE_ID, auth) : ''
      } catch (serErr) {
        console.error(`[SSR] Failed to serialize auth state for "${url}":`, serErr)
        // Continue without it — the client falls back to its own /api/auth/refresh at boot
      }

      // Replacer functions, not strings: a replacement string interprets `$&`, `$'` and `$\``, and
      // the markup carries user content — a title holding `$'` would splice the rest of the
      // template into the page (docs/LEDGER_*.md SEC-12, audit L7).
      // The nonce goes on the template's own inline script (the theme script of index.html) before
      // anything else is spliced in, so only the template's tags can receive it.
      let finalHtml = nonceInlineScripts(currentTemplate, nonce)
        .replace('<!--ssr-outlet-->', () => appHtml)
        .replace('<!--ssr-state-->', () => stateScript)
        .replace('<!--ssr-auth-->', () => authScript)
        .replace('<!--ssr-head-->', () => head || '')

      // The SSR-built link-preview block (injected above) owns the dynamic <title>. index.html also
      // ships a static fallback <title> for the JS-less dev SPA tab; once the block is present there
      // are two, so drop the LAST one (the static fallback) — leaving exactly one, dynamic title.
      if (head) {
        finalHtml = finalHtml.replace(/\n?\s*<title>[^<]*<\/title>(?![\s\S]*<title>)/, '')
      }

      // Reflect the request-resolved language on the root <html> element.
      if (lang) {
        finalHtml = finalHtml.replace('<html lang="en">', `<html lang="${lang}">`)
      }

      // A signed-in visitor's explicit LIGHT/DARK theme is already known at render time — set it
      // directly on <html> so it's there before index.html's pre-hydration script even runs, instead
      // of that script deriving it from this browser's localStorage/matchMedia (which don't know
      // this visitor and can briefly disagree with the SSR markup). 'auto' is left alone: that
      // script's existing localStorage/matchMedia resolution is still correct for it.
      if (themePreference === 'light' || themePreference === 'dark') {
        finalHtml = finalHtml.replace(
          /<html lang="([^"]*)">/,
          `<html lang="$1" data-mantine-color-scheme="${themePreference}">`
        )
      }

      // No config and none seen yet since the process started (configOrigins returns null): the
      // map and push hosts are unknown, and the SPA keeps this document's policy for the whole
      // session, so this one document only reports the policy instead of enforcing connect-src 'self'.
      const knownOrigins = isProduction ? await configOrigins(config) : null
      const cspHeaders = isProduction
        ? documentCspHeaders(
            knownOrigins === null ? 'report-only' : csp.mode,
            buildDocumentPolicy({
              nonce,
              connectOrigins: [...(knownOrigins ?? []), ...cspExtraSources.accepted],
            })
          )
        : {}

      res
        .status(result.statusCode || 200)
        .set({
          ...cspHeaders,
          'Content-Type': 'text/html',
          // The markup is rendered for whoever sent the cookie: it embeds their name, their access
          // token and their view of the data. no-store keeps it out of every cache; Vary states the
          // dependency for anything that might ignore that. Do not add HTML caching here — it would
          // serve one visitor's page to another.
          'Cache-Control': 'no-store',
          Vary: 'Cookie',
        })
        .send(finalHtml)
    } catch (e) {
      if (!isProduction && vite) {
        vite.ssrFixStacktrace(e)
      }
      console.error(e.stack || e)
      if (!res.headersSent) relayRotatedSessionCookie(res, sink)
      res
        .status(500)
        .set({ 'Content-Type': 'text/html' })
        .send(
          isProduction
            ? '<h1>Internal Server Error</h1>'
            : `<pre>${String(e.stack || e.message || e)
                .replace(/</g, '&lt;')
                .replace(/>/g, '&gt;')}</pre>`
        )
    }
  })

  const server = app.listen(port, () => {
    console.log(`Server running at http://localhost:${port}`)
  })
  server.on('error', (err) => {
    console.error(`Fatal: failed to bind to port ${port}:`, err.message)
    process.exit(1)
  })

  // Rolling update (docker-compose.yml, `order: start-first`): Swarm sends SIGTERM to the old task
  // once the new one is healthy. Keep serving until traefik has stopped routing here, then close.
  // Node as PID 1 would otherwise ignore SIGTERM and be killed at the end of stop_grace_period.
  if (isProduction)
    process.once('SIGTERM', () => {
      draining = true
      // Longer than traefik's health-check interval + timeout (3 s + 10 s, docker-compose.yml).
      setTimeout(() => {
        server.close(() => process.exit(0))
        server.closeIdleConnections()
        setTimeout(() => process.exit(0), 5000).unref()
      }, 15000)
    })
}

process.on('unhandledRejection', (reason) => {
  console.error('[SSR] Unhandled promise rejection:', reason)
})

process.on('uncaughtException', (err) => {
  console.error('[SSR] Uncaught exception — server is in an unknown state:', err)
  process.exit(1)
})

createServer().catch((err) => {
  console.error('Fatal: failed to start SSR server', err)
  process.exit(1)
})
