// POST /csp-report: where browsers send the violations of the site's CSP (docs/LEDGER_*.md SEC-31).
// Each report becomes one compact JSON line on stdout, which reaches Loki with the container's other
// logs ({service="frontend"} |= "[csp-report]").
//
// Anyone can post here, so the route must not become a way to flood or forge the log:
// - bodies over `limitBytes` are refused before being parsed, and only report content types are read;
// - a global budget of `maxLinesPerWindow` lines per `windowMs`, whatever the sender — Traefik already
//   limits each client, and an address can be forged, so this bounds the total — then one line saying
//   how many were dropped;
// - only known fields are logged, each a short string or an integer, URLs without their query or
//   fragment (a page URL can carry a token), and the line is JSON, so a newline cannot start a
//   forged one. No script sample is kept: the policy does not ask for one ('report-sample').

import express from 'express'
import { REPORT_PATH } from './csp.js'

const REPORT_TYPES = ['application/csp-report', 'application/reports+json', 'application/json']
const MAX_FIELD = 256
const MAX_REPORTS_PER_REQUEST = 20

/** A URL without its query and fragment; keywords such as `inline` or `eval` stay as they are. */
function stripUrl(value) {
  if (typeof value !== 'string') return undefined
  let text = value
  try {
    const parsed = new URL(value)
    if (parsed.protocol === 'http:' || parsed.protocol === 'https:') {
      text = parsed.origin + parsed.pathname
    } else {
      text = parsed.protocol // data:, blob:… — the rest is content, not a location
    }
  } catch {
    text = value.split(/[?#]/)[0]
  }
  return shortText(text)
}

function shortText(value) {
  if (typeof value !== 'string') return undefined
  const clean = value.replace(/[\u0000-\u001f\u007f]/g, '')
  return clean.length > MAX_FIELD ? `${clean.slice(0, MAX_FIELD)}…` : clean
}

function integer(value) {
  const number = Number(value)
  return Number.isInteger(number) && number >= 0 && number < 1e9 ? number : undefined
}

/**
 * The violations of a report body, as the two formats send them: `report-uri`'s
 * `{"csp-report": {...}}` (kebab-case keys) and the Reporting API's array of
 * `{type: "csp-violation", body: {...}}` (camelCase keys). Anything else yields nothing.
 */
export function violationsOf(payload) {
  const raw = []
  if (Array.isArray(payload)) {
    for (const entry of payload) {
      if (entry && entry.type === 'csp-violation' && entry.body && typeof entry.body === 'object')
        raw.push(entry.body)
    }
  } else if (payload && typeof payload === 'object' && payload['csp-report']) {
    if (typeof payload['csp-report'] === 'object') raw.push(payload['csp-report'])
  }
  return raw.slice(0, MAX_REPORTS_PER_REQUEST).map((body) => {
    const pick = (...keys) => keys.map((key) => body[key]).find((value) => value !== undefined)
    const violation = {
      documentURL: stripUrl(pick('documentURL', 'document-uri')),
      blockedURL: stripUrl(pick('blockedURL', 'blocked-uri')),
      directive: shortText(pick('effectiveDirective', 'effective-directive', 'violated-directive')),
      disposition: shortText(pick('disposition')),
      sourceFile: stripUrl(pick('sourceFile', 'source-file')),
      line: integer(pick('lineNumber', 'line-number')),
      column: integer(pick('columnNumber', 'column-number')),
      status: integer(pick('statusCode', 'status-code')),
    }
    for (const key of Object.keys(violation)) {
      if (violation[key] === undefined) delete violation[key]
    }
    return violation
  })
}

/** Mounts POST /csp-report on `app`. `log` and `now` are there for the tests. */
export function mountCspReportRoute(
  app,
  {
    log = (line) => console.log(line),
    now = Date.now,
    windowMs = 60_000,
    maxLinesPerWindow = 120,
    limitBytes = 16 * 1024,
  } = {}
) {
  let windowStart = now()
  let budget = maxLinesPerWindow
  let dropped = 0

  const rollWindow = () => {
    if (now() - windowStart < windowMs) return
    if (dropped > 0) log(`[csp-report] ${JSON.stringify({ dropped })}`)
    windowStart = now()
    budget = maxLinesPerWindow
    dropped = 0
  }

  app.post(
    REPORT_PATH,
    (req, res, next) => {
      rollWindow()
      // Out of budget: refuse before reading anything.
      if (budget <= 0) {
        dropped += 1
        res.status(429).set('Cache-Control', 'no-store').end()
        return
      }
      next()
    },
    express.text({ type: REPORT_TYPES, limit: limitBytes }),
    (req, res) => {
      res.set('Cache-Control', 'no-store')
      if (typeof req.body !== 'string') {
        res.status(415).end()
        return
      }
      let payload
      try {
        payload = JSON.parse(req.body)
      } catch {
        res.status(400).end()
        return
      }
      for (const violation of violationsOf(payload)) {
        if (budget <= 0) {
          dropped += 1
          continue
        }
        budget -= 1
        log(`[csp-report] ${JSON.stringify(violation)}`)
      }
      res.status(204).end()
    },
    // The body parser's refusals (413 too large, 400 bad encoding): a status, never a stack.
    (err, _req, res, _next) => {
      res
        .status(err?.status === 413 || err?.type === 'entity.too.large' ? 413 : 400)
        .set('Cache-Control', 'no-store')
        .end()
    }
  )
}
