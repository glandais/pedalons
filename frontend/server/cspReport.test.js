// @vitest-environment node
import express from 'express'
import { afterEach, describe, expect, it } from 'vitest'
import { mountCspReportRoute, violationsOf } from './cspReport.js'

let server

/** A server with only the report route, and the lines it logged. */
async function start(options = {}) {
  const lines = []
  const app = express()
  mountCspReportRoute(app, { log: (line) => lines.push(line), ...options })
  app.use((_req, res) => res.status(404).end())
  await new Promise((resolve) => {
    server = app.listen(0, '127.0.0.1', resolve)
  })
  const url = `http://127.0.0.1:${server.address().port}/csp-report`
  const post = (body, type = 'application/csp-report') =>
    fetch(url, { method: 'POST', headers: { 'Content-Type': type }, body })
  return { lines, post, url }
}

afterEach(async () => {
  if (server) await new Promise((resolve) => server.close(resolve))
  server = undefined
})

const legacyReport = {
  'csp-report': {
    'document-uri': 'https://www.pedalons.fr/connexion?next=/x&token=SECRET#frag',
    'blocked-uri': 'inline',
    'violated-directive': 'script-src-elem',
    'effective-directive': 'script-src-elem',
    'source-file': 'https://www.pedalons.fr/assets/index-abc.js?v=1',
    'line-number': 12,
    'column-number': 7,
    'status-code': 200,
    disposition: 'report',
    'script-sample': 'window.secret = 1',
  },
}

describe('POST /csp-report', () => {
  it('logs one compact line per report-uri violation, without query, fragment or sample', async () => {
    const { lines, post } = await start()
    const response = await post(JSON.stringify(legacyReport))
    expect(response.status).toBe(204)
    expect(lines).toHaveLength(1)
    expect(lines[0].startsWith('[csp-report] ')).toBe(true)
    expect(JSON.parse(lines[0].slice('[csp-report] '.length))).toEqual({
      documentURL: 'https://www.pedalons.fr/connexion',
      blockedURL: 'inline',
      directive: 'script-src-elem',
      disposition: 'report',
      sourceFile: 'https://www.pedalons.fr/assets/index-abc.js',
      line: 12,
      column: 7,
      status: 200,
    })
    expect(lines[0]).not.toContain('SECRET')
    expect(lines[0]).not.toContain('window.secret')
  })

  it('reads the Reporting API format, csp-violation entries only', async () => {
    const { lines, post } = await start()
    const body = [
      {
        type: 'csp-violation',
        body: {
          documentURL: 'https://www.pedalons.fr/',
          blockedURL: 'https://evil.example/x.js?a=1',
          effectiveDirective: 'script-src-elem',
          disposition: 'report',
        },
      },
      { type: 'deprecation', body: { message: 'x' } },
    ]
    expect((await post(JSON.stringify(body), 'application/reports+json')).status).toBe(204)
    expect(lines).toHaveLength(1)
    expect(lines[0]).toContain('"blockedURL":"https://evil.example/x.js"')
  })

  it('keeps a forged line break inside the one JSON line', async () => {
    const { lines, post } = await start()
    const forged = {
      'csp-report': { 'violated-directive': 'x\n[csp-report] {"forged":true}\r\u001b[2J' },
    }
    await post(JSON.stringify(forged))
    expect(lines).toHaveLength(1)
    expect(lines[0]).not.toMatch(/[\n\r\u001b]/)
  })

  it('refuses a body over the size cap without parsing it', async () => {
    const { lines, post } = await start({ limitBytes: 1024 })
    const big = JSON.stringify({ 'csp-report': { 'blocked-uri': 'x'.repeat(4096) } })
    expect((await post(big)).status).toBe(413)
    expect(lines).toHaveLength(0)
  })

  it('refuses a malformed body', async () => {
    const { lines, post } = await start()
    expect((await post('{"csp-report": ')).status).toBe(400)
    expect(lines).toHaveLength(0)
  })

  it('refuses a content type that is not a report', async () => {
    const { lines, post } = await start()
    expect((await post(JSON.stringify(legacyReport), 'text/plain')).status).toBe(415)
    expect(lines).toHaveLength(0)
  })

  it('ignores JSON that is not a report', async () => {
    const { lines, post } = await start()
    expect((await post('{"hello":"world"}', 'application/json')).status).toBe(204)
    expect((await post('null', 'application/json')).status).toBe(204)
    expect((await post('"text"', 'application/json')).status).toBe(204)
    expect(lines).toHaveLength(0)
  })

  it('caps the lines per window for every sender together, then says how many it dropped', async () => {
    let clock = 0
    const { lines, post } = await start({ maxLinesPerWindow: 3, windowMs: 1000, now: () => clock })
    for (let i = 0; i < 5; i++) await post(JSON.stringify(legacyReport))
    expect(lines).toHaveLength(3)
    expect((await post(JSON.stringify(legacyReport))).status).toBe(429)
    clock = 1000
    await post(JSON.stringify(legacyReport))
    expect(lines[3]).toBe('[csp-report] {"dropped":3}')
    expect(lines).toHaveLength(5)
  })

  it('answers only POST', async () => {
    const { url } = await start()
    expect((await fetch(url)).status).toBe(404)
  })
})

describe('violationsOf', () => {
  it('reads at most 20 violations from one request', () => {
    const many = Array.from({ length: 50 }, () => ({ type: 'csp-violation', body: {} }))
    expect(violationsOf(many)).toHaveLength(20)
  })

  it('truncates long fields and drops non-integer numbers', () => {
    const [violation] = violationsOf({
      'csp-report': { 'violated-directive': 'a'.repeat(1000), 'line-number': 'NaN' },
    })
    expect(violation.directive.length).toBeLessThanOrEqual(257)
    expect(violation).not.toHaveProperty('line')
  })
})
