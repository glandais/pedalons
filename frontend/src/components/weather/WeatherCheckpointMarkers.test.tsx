import { afterEach, describe, expect, it, vi } from 'vitest'
import { act, cleanup, fireEvent, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import type { TrackDto, WeatherLegDto } from '@/api/dto'
import { usePreferencesStore } from '@/store/preferencesStore'
import { plain, routeLeg } from '@/test/weatherFixtures'

vi.mock('react-i18next', async () => {
  const { frenchT } = await import('@/test/frenchT')
  return { useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }) }
})

// The map's markers and popup as plain DOM: where each marker stands, and the popup's close button.
// A marker renders through a portal into an element of its own, nested in the map's container, as
// react-map-gl does: what a click on a badge lets through to the map depends on it.
vi.mock('react-map-gl/maplibre', async () => {
  const { useState } = await import('react')
  const { createPortal } = await import('react-dom')
  return {
    useMap: () => ({ current: undefined }),
    Marker: function Marker({
      longitude,
      latitude,
      children,
    }: {
      longitude: number
      latitude: number
      children?: React.ReactNode
    }) {
      const [element] = useState(() => document.createElement('div'))
      return (
        <div
          data-testid="marker"
          data-lnglat={`${longitude},${latitude}`}
          ref={(host) => {
            if (host && element.parentNode !== host) host.appendChild(element)
          }}
        >
          {createPortal(children, element)}
        </div>
      )
    },
    // MapLibre's popup: its close button, after the content, leaves the page before `close`
    // fires, so the focus it held has already fallen to the body when `onClose` runs (a blur
    // here, as the removal would).
    Popup: ({
      longitude,
      latitude,
      onClose,
      children,
    }: {
      longitude: number
      latitude: number
      onClose?: () => void
      children?: React.ReactNode
    }) => (
      <div
        className="maplibregl-popup"
        data-testid="popup"
        data-lnglat={`${longitude},${latitude}`}
      >
        {children}
        <button
          type="button"
          onClick={(event) => {
            event.currentTarget.blur()
            onClose?.()
          }}
        >
          Fermer
        </button>
      </div>
    ),
  }
})

import { WeatherCheckpointMarkers } from './WeatherCheckpointMarkers'

/** A northbound track of `km` km, a point every 15 km, its own distance restarting at 0. */
function track(km: number, fromLat: number): TrackDto {
  return {
    line: {
      type: 'LineString',
      coordinates: Array.from({ length: km / 15 + 1 }, (_, i) => [
        5,
        fromLat + (i * 15_000) / 111_195,
        300,
        i * 15_000,
      ]),
    },
    climbs: [],
  } as unknown as TrackDto
}

/** The fixture's 90 km leg on two 45 km tracks, the second far from the first's end. */
const TRACKS = [track(45, 45), track(45, 46)]

function show(leg: WeatherLegDto = routeLeg(), timezone = 'Europe/Paris') {
  return render(
    <MantineProvider>
      <WeatherCheckpointMarkers tracks={TRACKS} leg={leg} timezone={timezone} />
    </MantineProvider>
  )
}

const badges = () => screen.queryAllByTestId('weather-checkpoint-badge')
const detail = () => plain(screen.getByTestId('weather-checkpoint-detail').textContent)

describe('WeatherCheckpointMarkers (WEB-116)', () => {
  afterEach(() => {
    cleanup()
    usePreferencesStore.setState({ unitSystem: 'METRIC' })
  })

  it('puts a compact badge at every checkpoint, placed on the chained distance', () => {
    show()
    expect(badges()).toHaveLength(7)
    // km 60 stands on the second track's second point (45 + 15), not past the first one's end
    const km60 = badges()[4].closest('[data-testid=marker]')!
    const [lng, lat] = TRACKS[1].line.coordinates[1]
    expect(km60.getAttribute('data-lnglat')).toBe(`${lng},${lat}`)
    // At rest: the temperature, the full point in its accessible name
    expect(plain(badges()[4].textContent)).toBe('16 °C')
    expect(plain(badges()[4].getAttribute('aria-label'))).toContain('10:30')
    expect(screen.queryByTestId('popup')).toBeNull()
  })

  it('shows no badge for a checkpoint without its weather', () => {
    const leg = routeLeg()
    leg.checkpoints = leg.checkpoints.map((c, i) => (i % 2 ? { ...c, weather: undefined } : c))
    show(leg)
    expect(badges()).toHaveLength(4)
  })

  it('opens the detail on a click: passage in the ride zone, rain, wind and gusts', () => {
    show()
    fireEvent.click(badges()[2])
    expect(badges()[2].getAttribute('aria-expanded')).toBe('true')
    // Its accessible title: the place and the passage, read in Paris time
    expect(screen.getByRole('dialog', { name: /^km\s30\.0\s·\s09:30$/ })).toBeTruthy()
    const text = detail()
    expect(text).toContain('9 °C')
    expect(text).toContain('Partiellement nuageux')
    expect(text).toContain('Pluie 13 %')
    expect(text).toContain('N 14 km/h, rafales 32 km/h')
    expect(text).toContain('Vent de face')
  })

  it('reads the passage in the ride zone, not the reader one', () => {
    show(routeLeg(), 'Asia/Tokyo')
    fireEvent.click(badges()[2])
    expect(detail()).toContain('16:30')
  })

  it('says nothing of gusts the model lacks, and the amount of rain when there is some', () => {
    const leg = routeLeg()
    const c = leg.checkpoints[1]
    leg.checkpoints[1] = {
      ...c,
      weather: {
        ...c.weather!,
        precipitation: 1.2,
        precipitationProbability: 60,
        wind: { ...c.weather!.wind, gusts: undefined },
      },
    }
    show(leg)
    fireEvent.click(badges()[1])
    const text = detail()
    expect(text).not.toMatch(/rafales/i)
    expect(text).not.toContain('0 km/h,')
    // The decimal of the reader's language, through the unit formatter
    expect(text).toContain('Pluie 60 % · 1,2 mm')
  })

  it('gives the amount of rain in inches to an imperial reader', () => {
    usePreferencesStore.setState({ unitSystem: 'IMPERIAL' })
    const leg = routeLeg()
    const c = leg.checkpoints[1]
    leg.checkpoints[1] = {
      ...c,
      weather: { ...c.weather!, precipitation: 1.2, precipitationProbability: 60 },
    }
    show(leg)
    fireEvent.click(badges()[1])
    expect(detail()).toContain('Pluie 60 % · 0,05 in')
    expect(detail()).not.toContain('mm')
  })

  it('converts to °F and mph for an imperial reader', () => {
    usePreferencesStore.setState({ unitSystem: 'IMPERIAL' })
    show()
    expect(plain(badges()[4].textContent)).toBe('61 °F')
    fireEvent.click(badges()[4])
    const text = detail()
    expect(text).toContain('61 °F')
    expect(text).toContain('N 10 mph, rafales 15 mph')
  })

  it('keeps one popup at a time, closed by the badge again, its button or Escape', () => {
    show()
    fireEvent.click(badges()[1])
    fireEvent.click(badges()[3])
    expect(screen.getAllByTestId('popup')).toHaveLength(1)
    expect(detail()).toContain('km 45.0')
    expect(badges()[1].getAttribute('aria-expanded')).toBe('false')

    fireEvent.click(badges()[3])
    expect(screen.queryByTestId('popup')).toBeNull()

    fireEvent.click(badges()[3])
    fireEvent.click(screen.getByRole('button', { name: 'Fermer' }))
    expect(screen.queryByTestId('popup')).toBeNull()

    fireEvent.click(badges()[3])
    act(() => {
      window.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }))
    })
    expect(screen.queryByTestId('popup')).toBeNull()
  })

  it('puts the focus on the titled detail when it opens, not on the close button', () => {
    show()
    fireEvent.click(badges()[2])
    expect(document.activeElement).toBe(
      screen.getByRole('dialog', { name: /^km\s30\.0\s·\s09:30$/ })
    )
  })

  it('hands the focus back to its badge when its close button closes it', () => {
    show()
    fireEvent.click(badges()[2])
    const close = screen.getByRole('button', { name: 'Fermer' })
    close.focus()
    // The close button drops the focus before `onClose`, as MapLibre removing it does
    fireEvent.click(close)
    expect(screen.queryByTestId('popup')).toBeNull()
    expect(document.activeElement).toBe(badges()[2])
  })

  it('leaves the focus where it is when it was not in the popup', () => {
    show()
    fireEvent.click(badges()[2])
    badges()[5].focus()
    act(() => {
      window.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }))
    })
    expect(screen.queryByTestId('popup')).toBeNull()
    expect(document.activeElement).toBe(badges()[5])
  })

  it("keeps a badge's click from the map, which would select or drop a waypoint", () => {
    const { container } = show()
    const mapClick = vi.fn()
    container.addEventListener('click', mapClick)
    fireEvent.click(badges()[2])
    expect(screen.getByTestId('popup')).toBeTruthy()
    expect(mapClick).not.toHaveBeenCalled()
  })

  it('hands the focus back to its badge when Escape closes it from inside', () => {
    show()
    fireEvent.click(badges()[2])
    const close = screen.getByRole('button', { name: 'Fermer' })
    close.focus()
    fireEvent.keyDown(close, { key: 'Escape' })
    expect(screen.queryByTestId('popup')).toBeNull()
    expect(document.activeElement).toBe(badges()[2])
  })

  it('drops a drop where rain becomes likely, nowhere without an alert', () => {
    show(
      routeLeg({
        rainAlert: {
          probability: 55,
          time: routeLeg().checkpoints[3].time,
          distance: 45_000,
          condition: 'SHOWERS',
        },
      })
    )
    const drop = screen.getByTestId('weather-rain-alert')
    expect(plain(drop.getAttribute('aria-label'))).toBe(
      'Averses probable (55 %) vers 10:00, à km 45'
    )
    const [lng, lat] = TRACKS[0].line.coordinates[3]
    expect(drop.closest('[data-testid=marker]')!.getAttribute('data-lnglat')).toBe(`${lng},${lat}`)
    cleanup()
    show()
    expect(screen.queryByTestId('weather-rain-alert')).toBeNull()
  })
})
