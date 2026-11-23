import Axios from 'axios'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { ErrorCode } from '@/api/dto'
import { ApiClientError, apiErrorCode, apiErrorStatus, isNetworkError } from '@/lib/apiError'
import { isElevationUnsupported } from '@/lib/plannerElevation'
import { plannerQuotaRefusalOf } from '@/lib/plannerQuota'
import {
  bridgeRequest,
  bridgeTransport,
  fileFromBase64,
  resetBridgeRequests,
  resolvePlace,
  searchPlaces,
  settleResponse,
  type Outgoing,
} from './bridge'

let sent: Outgoing[]
const lastRequest = () => {
  const message = sent.at(-1)
  if (message?.type !== 'request') throw new Error('no request was sent')
  return message
}

beforeEach(() => {
  sent = []
  resetBridgeRequests()
  window.PedalonsBridge = { postMessage: (json) => sent.push(JSON.parse(json) as Outgoing) }
})

afterEach(() => {
  delete window.PedalonsBridge
})

describe('bridgeRequest', () => {
  it('posts the request and resolves with the body the app answers', async () => {
    const answer = bridgeRequest('POST', '/api/router', { from: 1 })
    expect(sent).toEqual([
      { type: 'request', id: '1', method: 'POST', path: '/api/router', body: { from: 1 } },
    ])
    settleResponse({ id: '1', status: 200, body: { route: 'r' } })
    await expect(answer).resolves.toEqual({ route: 'r' })
  })

  it('decodes a body sent as JSON text', async () => {
    const answer = bridgeRequest('GET', '/api/geocode/search?q=x')
    settleResponse({ id: '1', status: 200, body: '[{"id":"a"}]' })
    await expect(answer).resolves.toEqual([{ id: 'a' }])
  })

  it('matches each answer to its request, whatever the order', async () => {
    const first = bridgeRequest('POST', '/api/router', 'a')
    const second = bridgeRequest('POST', '/api/router', 'b')
    settleResponse({ id: '2', status: 200, body: 'second' })
    settleResponse({ id: '1', status: 200, body: 'first' })
    await expect(first).resolves.toBe('first')
    await expect(second).resolves.toBe('second')
  })

  it('fails with the API error code, as the site does: the planner words it by code', async () => {
    const answer = bridgeRequest('POST', '/api/router', {})
    settleResponse({
      id: '1',
      status: 429,
      body: { code: ErrorCode.ROUTING_DAILY_LIMIT_REACHED },
      retryAfter: 120,
    })
    const error = await answer.catch((e: unknown) => e)
    expect(error).toBeInstanceOf(ApiClientError)
    expect(apiErrorCode(error)).toBe(ErrorCode.ROUTING_DAILY_LIMIT_REACHED)
    expect(apiErrorStatus(error)).toBe(429)
    expect((error as ApiClientError).retryAfterSeconds).toBe(120)
  })

  it('carries the details of a spent quota, which the app is told about', async () => {
    const answer = bridgeRequest('POST', '/api/router', {})
    const details = {
      type: 'PLANNER_QUOTA_REACHED',
      scope: 'TEAM',
      limit: 20,
      current: 20,
      resetsOn: '2026-12-01',
      teamName: 'Les Mollets',
    }
    settleResponse({
      id: '1',
      status: 403,
      body: JSON.stringify({ code: ErrorCode.PLANNER_QUOTA_REACHED, errorDetails: details }),
    })
    expect(plannerQuotaRefusalOf(await answer.catch((e: unknown) => e))).toEqual(details)
  })

  it('fails with the status alone when the body has no code (an older backend)', async () => {
    const answer = bridgeRequest('POST', '/api/router/elevation', {})
    settleResponse({ id: '1', status: 404, body: '' })
    const error = await answer.catch((e: unknown) => e)
    expect(apiErrorCode(error)).toBeUndefined()
    expect(apiErrorStatus(error)).toBe(404)
    expect(isElevationUnsupported(error)).toBe(true)
  })

  it('reads a status 0 as a call that never got an answer', async () => {
    const answer = bridgeRequest('POST', '/api/router', {})
    settleResponse({ id: '1', status: 0 })
    const error = await answer.catch((e: unknown) => e)
    expect(isNetworkError(error)).toBe(true)
    expect(apiErrorStatus(error)).toBeUndefined()
  })

  it('tells the app to cancel when the signal aborts, and drops a late answer', async () => {
    const controller = new AbortController()
    const answer = bridgeRequest('POST', '/api/router', {}, controller.signal)
    controller.abort()
    expect(sent.at(-1)).toEqual({ type: 'cancel', id: '1' })
    const error = await answer.catch((e: unknown) => e)
    expect(Axios.isCancel(error)).toBe(true)
    // Nothing left to settle: no throw, no second cancel
    settleResponse({ id: '1', status: 200, body: {} })
    controller.abort()
    expect(sent).toHaveLength(2)
  })

  it('sends nothing for a signal already aborted (routing is billed per request)', async () => {
    const controller = new AbortController()
    controller.abort()
    const error = await bridgeRequest('POST', '/api/router', {}, controller.signal).catch(
      (e: unknown) => e
    )
    expect(Axios.isCancel(error)).toBe(true)
    expect(sent).toEqual([])
  })

  it('ignores an answer to a request it never made', () => {
    expect(() => settleResponse({ id: '42', status: 200 })).not.toThrow()
  })
})

describe('bridgeTransport', () => {
  it('sends the three calls of the planner on their paths', () => {
    void bridgeTransport.route({
      from: { lng: 1, lat: 2 },
      to: { lng: 3, lat: 4 },
      profile: 'FASTBIKE',
      teamSlug: 't',
    })
    expect(lastRequest()).toMatchObject({
      method: 'POST',
      path: '/api/router',
      body: { from: { lng: 1, lat: 2 }, to: { lng: 3, lat: 4 }, teamSlug: 't' },
    })
    void bridgeTransport.lineElevation({ teamSlug: 't', lines: [] })
    expect(lastRequest()).toMatchObject({
      method: 'POST',
      path: '/api/router/elevation',
      body: { teamSlug: 't', lines: [] },
    })
  })

  it('asks the engines on offer, with the team when there is one', () => {
    void bridgeTransport.engines('les-mollets')
    expect(lastRequest()).toMatchObject({
      method: 'GET',
      path: '/api/router/engines?teamSlug=les-mollets',
    })
    void bridgeTransport.engines()
    expect(lastRequest()).toMatchObject({ method: 'GET', path: '/api/router/engines' })
  })

  it('sends a file as a multipart description, its bytes in base64', async () => {
    const file = new File(['<gpx/>'], 'tour.gpx', { type: 'application/gpx+xml' })
    void bridgeTransport.importGpx({ gpxFile: file, teamSlug: 'les-mollets' })
    await vi.waitFor(() => expect(sent).toHaveLength(1))
    expect(lastRequest()).toMatchObject({
      method: 'POST',
      path: '/api/router/import-gpx',
      body: {
        multipart: {
          fields: { teamSlug: 'les-mollets' },
          file: { name: 'tour.gpx', base64: btoa('<gpx/>'), contentType: 'application/gpx+xml' },
        },
      },
    })
  })

  it('rebuilds the file the app picked from its base64 bytes', async () => {
    const file = fileFromBase64('tour.gpx', btoa('<gpx/>'))
    expect(file.name).toBe('tour.gpx')
    expect(file.size).toBe(6)
  })
})

describe('place search', () => {
  it('goes through the backend proxy, never the provider', () => {
    void searchPlaces('col de la Croix-Fry & co')
    expect(lastRequest()).toMatchObject({
      method: 'GET',
      path: '/api/geocode/search?q=col%20de%20la%20Croix-Fry%20%26%20co',
    })
    void resolvePlace('openstreetmap:venue:node/1')
    expect(lastRequest()).toMatchObject({
      method: 'GET',
      path: '/api/geocode/place?id=openstreetmap%3Avenue%3Anode%2F1',
    })
  })
})
