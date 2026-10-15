import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { act, cleanup, fireEvent, render, screen } from '@testing-library/react'
import { renderToString } from 'react-dom/server'
import { MantineProvider } from '@mantine/core'

vi.mock('react-i18next', async (importOriginal) => ({
  ...(await importOriginal<typeof import('react-i18next')>()),
  useTranslation: () => ({ t: (key: string) => key, i18n: { language: 'fr' } }),
}))
vi.mock('@/components/common/MarkdownDisplay', () => ({
  MarkdownDisplay: () => <div data-testid="policy-markdown" />,
}))

import { OPT_OUT_KEY, setAnalyticsOptedOut } from '@/lib/analytics/optOut'
import { PrivacyPolicyPage } from './PrivacyPolicyPage'

/**
 * The opposition to the audience measurement on the privacy page, outside the policy's Markdown
 * (docs/plans/2026-10-15-web-analytics.md §4.4, docs/LEDGER_*.md WEB-90).
 */

const items = new Map<string, string>()
const storage = {
  getItem: (key: string) => items.get(key) ?? null,
  setItem: (key: string, value: string) => void items.set(key, value),
  removeItem: (key: string) => void items.delete(key),
  clear: () => items.clear(),
}

const page = () => (
  <MantineProvider>
    <PrivacyPolicyPage />
  </MantineProvider>
)

beforeEach(() => {
  vi.stubGlobal('localStorage', storage)
  items.clear()
  Object.defineProperty(navigator, 'doNotTrack', { value: null, configurable: true })
  Object.defineProperty(navigator, 'globalPrivacyControl', { value: undefined, configurable: true })
})

afterEach(() => {
  cleanup()
  vi.unstubAllGlobals()
})

describe('PrivacyPolicyPage', () => {
  it('renders the switch above the policy text, under its anchor', () => {
    render(page())
    const box = document.getElementById('mesure-audience')!
    expect(box).not.toBeNull()
    const markdown = screen.getByTestId('policy-markdown')
    expect(box.compareDocumentPosition(markdown) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy()
    expect(box).toContainElement(screen.getByRole('switch', { name: 'analytics.optOut.label' }))
  })

  it('stores the opposition in this browser, and withdraws it', () => {
    render(page())
    const toggle = screen.getByRole('switch', { name: 'analytics.optOut.label' })
    expect(toggle).toBeChecked()
    fireEvent.click(toggle)
    expect(items.get(OPT_OUT_KEY)).toBe('1')
    expect(toggle).not.toBeChecked()
    fireEvent.click(toggle)
    expect(items.has(OPT_OUT_KEY)).toBe(false)
    expect(toggle).toBeChecked()
  })

  it('follows a change made elsewhere (the profile switch)', () => {
    render(page())
    act(() => setAnalyticsOptedOut(true))
    expect(screen.getByRole('switch', { name: 'analytics.optOut.label' })).not.toBeChecked()
  })

  it('says the browser signal already opposes, and locks the switch', () => {
    Object.defineProperty(navigator, 'globalPrivacyControl', { value: true, configurable: true })
    render(page())
    const toggle = screen.getByRole('switch', { name: 'analytics.optOut.label' })
    expect(toggle).toBeDisabled()
    expect(toggle).not.toBeChecked()
    expect(screen.getByText('analytics.optOut.browserSignal')).toBeInTheDocument()
  })

  it('renders on the server without reading the browser: the neutral state', () => {
    items.set(OPT_OUT_KEY, '1')
    const getItem = vi.spyOn(storage, 'getItem')
    const html = renderToString(page())
    expect(getItem).not.toHaveBeenCalledWith(OPT_OUT_KEY)
    expect(html).toContain('id="mesure-audience"')
    // The stored opposition is not seen on the server: the switch renders on, the client corrects it.
    expect(html).toMatch(/<input[^>]*role="switch"[^>]*checked=""/)
    expect(html).not.toContain('analytics.optOut.browserSignal')
  })
})
