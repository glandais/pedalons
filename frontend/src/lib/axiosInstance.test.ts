import { AxiosError, type AxiosAdapter, type InternalAxiosRequestConfig } from 'axios'
import { beforeEach, describe, expect, it, vi } from 'vitest'

const show = vi.hoisted(() => vi.fn())
vi.mock('@mantine/notifications', () => ({ notifications: { show } }))
vi.mock('./feedback/clientLog', () => ({ logEntry: vi.fn(), pathOnly: (path: string) => path }))

import { axiosMutator } from './axiosInstance'
import { ApiClientError } from './apiError'

/** An adapter answering every request with this refusal, as the backend would. */
function refusing(status: number, code: string): AxiosAdapter {
  return async (config: InternalAxiosRequestConfig) => {
    throw new AxiosError('refused', 'ERR_BAD_REQUEST', config, null, {
      status,
      statusText: '',
      headers: {},
      config,
      data: { code, message: code },
    })
  }
}

/**
 * The global error toast, as the response path of every generated hook runs it: a refusal its
 * screen explains in a dialog of its own stays quiet (docs/LEDGER_*.md WEB-166).
 */
describe('axiosMutator error toast', () => {
  beforeEach(() => show.mockClear())

  it('stays quiet for INCOMPATIBLE_VISIBILITY, which its screen renders itself', async () => {
    await expect(
      axiosMutator({
        url: '/api/teams/np/rides',
        method: 'post',
        adapter: refusing(400, 'INCOMPATIBLE_VISIBILITY'),
      })
    ).rejects.toBeInstanceOf(ApiClientError)
    expect(show).not.toHaveBeenCalled()
  })

  it('still shows one for any other refusal', async () => {
    await expect(
      axiosMutator({
        url: '/api/teams/np/rides',
        method: 'post',
        adapter: refusing(400, 'INVALID_VISIBILITY'),
      })
    ).rejects.toBeInstanceOf(ApiClientError)
    expect(show).toHaveBeenCalledTimes(1)
    expect(show.mock.calls[0][0]).toMatchObject({ color: 'red' })
  })
})
