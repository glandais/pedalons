import { describe, it, expect, vi, afterEach, beforeEach } from 'vitest'
import { render, screen, cleanup } from '@testing-library/react'
import { renderToString } from 'react-dom/server'
import { MantineProvider } from '@mantine/core'
import fr from '@/locales/fr/common.json'

// The French catalog's wording, interpolated: the reader is in Europe/Paris (Vitest's fixed zone,
// no signed-in user).
vi.mock('react-i18next', async (importOriginal) => ({
  ...(await importOriginal<typeof import('react-i18next')>()),
  useTranslation: () => ({
    t: (key: string, options: Record<string, string> = {}) =>
      ((fr as Record<string, string>)[key] ?? key).replace(
        /\{\{(\w+)\}\}/g,
        (_: string, name: string) => options[name] ?? ''
      ),
    i18n: { language: 'fr' },
  }),
}))

import { Rendezvous } from './Rendezvous'

function renderIt(node: React.ReactNode) {
  return render(
    <MantineProvider>
      <div data-testid="host">{node}</div>
    </MantineProvider>
  )
}

// docs/LEDGER_*.md API-60, plan §7.
describe('Rendezvous', () => {
  // « Now » in 2026: the year is said only outside the current one (docs/BRANDING.md §8.3).
  beforeEach(() => {
    vi.useFakeTimers({ toFake: ['Date'] })
    vi.setSystemTime(new Date('2026-10-01T10:00:00Z'))
  })
  afterEach(() => {
    cleanup()
    vi.useRealTimers()
  })

  it('reads the entity’s zone, with the full mention on a detail line', () => {
    // Sunday 11 October 2026, 06:00 in Tokyo = Saturday 23:00 in Paris.
    renderIt(<Rendezvous date="2026-10-10T21:00:00Z" zone="Asia/Tokyo" variant="detail" />)
    expect(screen.getByTestId('host').textContent).toBe(
      'dim. 11 oct. · 06:00 · heure de Tokyo (sam. 23:00 chez vous)'
    )
  })

  it('says nothing when the zone has the reader’s offset', () => {
    renderIt(<Rendezvous date="2026-10-11T06:00:00Z" zone="Europe/Brussels" variant="detail" />)
    expect(screen.getByTestId('host').textContent).toBe('dim. 11 oct. · 08:00')
    cleanup()
    renderIt(<Rendezvous date="2026-10-11T06:00:00Z" zone="Europe/Paris" />)
    expect(screen.queryByRole('img')).toBeNull()
  })

  it('puts the mention behind an icon on a card', () => {
    renderIt(<Rendezvous date="2026-10-10T23:00:00Z" zone="Asia/Tokyo" format="time" />)
    expect(screen.getByTestId('host').textContent).toBe('08:00')
    expect(screen.getByRole('img').getAttribute('aria-label')).toBe(
      'heure de Tokyo (01:00 chez vous)'
    )
  })

  it('makes the card icon focusable, so its tooltip reaches keyboard users', () => {
    renderIt(<Rendezvous date="2026-10-10T23:00:00Z" zone="Asia/Tokyo" format="time" />)
    expect(screen.getByRole('img').getAttribute('tabindex')).toBe('0')
  })

  it('falls back to the reader’s zone, without mention, for a zone Intl does not know', () => {
    renderIt(<Rendezvous date="2026-10-11T06:00:00Z" zone="Mars/Olympus_Mons" variant="detail" />)
    expect(screen.getByTestId('host').textContent).toBe('dim. 11 oct. · 08:00')
    cleanup()
    renderIt(<Rendezvous date="2026-10-11T06:00:00Z" zone="Mars/Olympus_Mons" />)
    expect(screen.queryByRole('img')).toBeNull()
  })

  it('renders no mention on the server, whose reader zone is only a placeholder', () => {
    // A Paris ride read by an anonymous visitor: the server knows only its UTC placeholder, so a
    // mention would claim « 06:00 chez vous » — false for a reader in Paris.
    const detail = renderToString(
      <MantineProvider>
        <Rendezvous date="2026-10-11T06:00:00Z" zone="Europe/Paris" variant="detail" />
      </MantineProvider>
    )
    expect(detail).toContain('dim. 11 oct. · 08:00')
    expect(detail).not.toContain('heure de')
    const card = renderToString(
      <MantineProvider>
        <Rendezvous date="2026-10-11T06:00:00Z" zone="Europe/Paris" />
      </MantineProvider>
    )
    expect(card).not.toContain('role="img"')
  })

  it('wraps the text in a sentence', () => {
    renderIt(
      <Rendezvous
        date="2026-10-10T23:00:00Z"
        zone="Asia/Tokyo"
        format="date"
        variant="detail"
        template={(date) => `Le ${date}`}
      />
    )
    expect(screen.getByTestId('host').textContent).toBe(
      'Le 11 octobre 2026 · heure de Tokyo (01:00 chez vous)'
    )
  })
})
