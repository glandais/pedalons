// jsdom (the default environment): the server's serialisation is read back by the client's reader.
import { afterEach, describe, expect, it, vi } from 'vitest'
import {
  SSR_AUTH_STATE_ID,
  SSR_QUERY_STATE_ID,
  jsonScript,
  serializeForScript,
} from './ssrState.js'
import * as client from '../src/lib/ssrState.ts'

/** Parses `html` as a full document's body, the way the browser receives server.js's page. */
function loadBody(html) {
  const parsed = new DOMParser().parseFromString(`<!doctype html><body>${html}</body>`, 'text/html')
  document.body.replaceWith(document.importNode(parsed.body, true))
}

afterEach(() => {
  document.body.innerHTML = ''
})

describe('SSR state blocks', () => {
  it('use the ids the client reads', () => {
    expect(client.SSR_QUERY_STATE_ID).toBe(SSR_QUERY_STATE_ID)
    expect(client.SSR_AUTH_STATE_ID).toBe(SSR_AUTH_STATE_ID)
  })

  it('round-trip through a non-executable block', () => {
    const auth = {
      accessToken: 'eyJ.x.y',
      user: { id: '0abc', displayName: 'Zoé « vélo » & co', theme: 'DARK' },
      hasPasskeys: false,
    }
    const queries = { mutations: [], queries: [{ queryKey: ['/api/config'], state: { data: 1 } }] }
    loadBody(
      `<div id="root"></div>${jsonScript(SSR_QUERY_STATE_ID, queries)}${jsonScript(SSR_AUTH_STATE_ID, auth)}`
    )
    const block = document.getElementById(SSR_AUTH_STATE_ID)
    expect(block.getAttribute('type')).toBe('application/json')
    expect(client.ssrAuthState()).toEqual(auth)
    expect(client.ssrQueryState()).toEqual(queries)
  })

  it('cannot be closed or commented out by the data they carry', () => {
    const hostile = {
      title: '</script><script>alert(1)</script><!--<script>',
      other: '</SCRIPT >  ',
    }
    const html = jsonScript(SSR_QUERY_STATE_ID, hostile)
    // One element, whose only `<` are its own tags.
    expect(html.match(/</g)).toHaveLength(2)
    expect(html).not.toMatch(/<\/script>.*<\/script>/is)
    loadBody(`${html}<p id="after">after</p>`)
    expect(document.querySelectorAll('script')).toHaveLength(1)
    expect(document.getElementById('after')?.textContent).toBe('after')
    expect(client.ssrQueryState()).toEqual(hostile)
  })

  it('write nothing for a value without JSON form', () => {
    expect(jsonScript(SSR_AUTH_STATE_ID, undefined)).toBe('')
    expect(serializeForScript(undefined)).toBeUndefined()
  })

  it('are read only from <body> itself, not from the page content', () => {
    loadBody(
      `<div id="root"><script type="application/json" id="${SSR_AUTH_STATE_ID}">{"user":{"id":"forged"}}</script></div>`
    )
    expect(client.ssrAuthState()).toBeUndefined()
  })

  it('read as nothing when absent or unreadable', () => {
    expect(client.ssrAuthState()).toBeUndefined()
    const error = vi.spyOn(console, 'error').mockImplementation(() => {})
    loadBody(`<script type="application/json" id="${SSR_AUTH_STATE_ID}">{not json</script>`)
    expect(client.ssrAuthState()).toBeUndefined()
    expect(error).toHaveBeenCalled()
    error.mockRestore()
  })
})
