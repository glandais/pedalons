import { useState } from 'react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type { GeneratedRouteDto, RouteGeneratorResponse, TeamDetailDto } from '@/api/dto'
import { ApiClientError } from '@/lib/apiError'

const generateMock = vi.hoisted(() => vi.fn())
const counts = vi.hoisted(() => ({
  state: { counts: { ROAD: 2, GRAVEL: 1, MTB: 0 }, isPending: false } as {
    counts: { ROAD?: number; GRAVEL?: number; MTB?: number }
    isPending: boolean
  },
}))
const places = vi.hoisted(() => ({
  state: { startPlaces: [], endPlaces: [] } as {
    startPlaces: { id: string; name: string; point: { lat: number; lng: number } }[]
    endPlaces: { id: string; name: string; point: { lat: number; lng: number } }[]
  },
}))
const mapProps = vi.hoisted(() => ({ last: undefined as Record<string, unknown> | undefined }))

vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})
vi.mock('@/api/endpoints/route-generator/route-generator', () => ({ generateRoutes: generateMock }))
vi.mock('@/pages/route/routeGeneratorData', () => ({
  useGeneratorTypeCounts: () => counts.state,
  useGeneratorPlaces: () => places.state,
}))
// The map is out of scope: a stand-in that exposes what the panel gives it, and places points.
vi.mock('./RouteGeneratorMap', () => ({
  RouteGeneratorMap: (props: {
    candidates: unknown[]
    clickMode: string | null
    onPick: (mode: 'start' | 'end', point: { lat: number; lng: number }) => void
  }) => {
    mapProps.last = props as never
    return (
      <div data-testid="map" data-lines={props.candidates.length} data-click-mode={props.clickMode}>
        <button onClick={() => props.onPick('end', { lat: 45, lng: 6 })}>pick far end</button>
        <button onClick={() => props.onPick('end', { lat: 45.01, lng: 5.01 })}>
          pick near end
        </button>
        <button onClick={() => props.onPick('start', { lat: 46, lng: 4 })}>pick start</button>
      </div>
    )
  },
}))

import { RouteGeneratorPanel, type RouteGeneratorPanelParams } from './RouteGeneratorPanel'
import { generatorParamPatch } from '@/hooks/filters/routeGeneratorFilters'

const TEAM = (over: Record<string, unknown> = {}) =>
  ({
    slug: 'club',
    role: 'ORGANIZER',
    enableRoutePlanner: true,
    geometry: { type: 'Point', coordinates: [5, 45] },
    ...over,
  }) as unknown as TeamDetailDto

const candidate = (over: Partial<GeneratedRouteDto> = {}): GeneratedRouteDto => ({
  polyline: '_p~iF~ps|U',
  distanceM: 82000,
  ascentM: 640,
  descentM: 640,
  familiarity: 0.5,
  unpavedShare: 0,
  sharedM: 0,
  crossings: 0,
  bounds: { minLat: 45, minLon: 5, maxLat: 45.1, maxLon: 5.1 },
  ...over,
})

const response = (over: Partial<RouteGeneratorResponse> = {}): RouteGeneratorResponse => ({
  candidates: [
    candidate({ distanceM: 82000, ascentM: 640, familiarity: 0.5, sharedM: 1200 }),
    candidate({ distanceM: 79000, ascentM: 700, familiarity: 0.9, sharedM: 40 }),
    candidate({ distanceM: 85000, ascentM: 500, familiarity: 0.1 }),
  ],
  network: {
    totalLengthM: 1e6,
    routeCount: 10,
    pendingRouteCount: 0,
    excludedRouteCount: 0,
    incomplete: false,
  },
  familiarityFallback: false,
  ...over,
})

const DEFAULTS: RouteGeneratorPanelParams = {
  distanceKm: 50,
  familiarity: 0.5,
  seed: 0,
  selected: 0,
  go: false,
}

function Harness({
  team,
  initial,
}: {
  team: TeamDetailDto
  initial?: Partial<RouteGeneratorPanelParams>
}) {
  const [params, setParams] = useState<RouteGeneratorPanelParams>({ ...DEFAULTS, ...initial })
  const more = () => setParams((p) => ({ ...p, seed: p.seed + 1, selected: 0, go: true }))
  return (
    <RouteGeneratorPanel
      team={team}
      layout="page"
      params={params}
      onParamsChange={(patch) =>
        setParams((p) => ({ ...p, ...generatorParamPatch(patch) }) as never)
      }
      onGenerate={() => (params.go ? more() : setParams((p) => ({ ...p, go: true })))}
      onMoreProposals={more}
      onSelect={(selected) => setParams((p) => ({ ...p, selected }))}
      onOpen={onOpen}
    />
  )
}
const onOpen = vi.fn()

function renderPanel(team = TEAM(), initial?: Partial<RouteGeneratorPanelParams>) {
  render(
    <QueryClientProvider client={new QueryClient()}>
      <MantineProvider>
        <Harness team={team} initial={initial} />
      </MantineProvider>
    </QueryClientProvider>
  )
}

const generate = () => screen.getByRole('button', { name: 'Générer' }) as HTMLButtonElement
const cards = () => screen.queryAllByTestId('generated-route-card')

describe('RouteGeneratorPanel (WEB-179)', () => {
  beforeEach(() => {
    // Mantine's combobox scrolls to the selected option, which jsdom does not implement
    Element.prototype.scrollIntoView = vi.fn()
    generateMock.mockReset()
    onOpen.mockReset()
    counts.state = { counts: { ROAD: 2, GRAVEL: 1, MTB: 0 }, isPending: false }
    places.state = { startPlaces: [], endPlaces: [] }
  })
  afterEach(cleanup)

  it('cannot generate for a team without location until a start is chosen', () => {
    renderPanel(TEAM({ geometry: undefined }))
    expect(generate().disabled).toBe(true)
    expect(screen.getByText('Choisissez un départ sur la carte.')).toBeTruthy()
    expect(screen.getByText(/L'équipe n'a ni localisation ni lieu de départ/)).toBeTruthy()
    fireEvent.click(screen.getByText('pick start'))
    expect(generate().disabled).toBe(false)
  })

  it('cannot generate with an end « Ailleurs » that is not placed yet', () => {
    // Neither a team location nor an end place: the map is the only way to place the end
    renderPanel(TEAM({ geometry: undefined }), { start: '45.00000,5.00000' })
    expect(generate().disabled).toBe(false)
    fireEvent.click(screen.getByText('Ailleurs'))
    expect(generate().disabled).toBe(true)
    expect(screen.getByTestId('map').getAttribute('data-click-mode')).toBe('end')
    expect(screen.getByText("Choisissez l'arrivée sur la carte.")).toBeTruthy()
    fireEvent.click(screen.getByText('pick near end'))
    expect(generate().disabled).toBe(false)
  })

  it('offers the start places of a team without location, and sends the one picked', async () => {
    generateMock.mockResolvedValue(response())
    places.state = {
      startPlaces: [{ id: 'p1', name: 'Parking du stade', point: { lat: 45.2, lng: 5.7 } }],
      endPlaces: [],
    }
    renderPanel(TEAM({ geometry: undefined }))
    expect(generate().disabled).toBe(true)
    expect(screen.getByText('Choisissez un départ dans la liste ou sur la carte.')).toBeTruthy()
    expect(screen.queryByText(/L'équipe n'a ni localisation/)).toBeNull()
    fireEvent.click(screen.getByRole('combobox', { name: 'Départ' }))
    expect(
      screen.queryByRole('option', { name: "Localisation de l'équipe", hidden: true })
    ).toBeNull()
    fireEvent.click(screen.getByRole('option', { name: 'Parking du stade', hidden: true }))
    fireEvent.click(generate())
    await waitFor(() => expect(generateMock).toHaveBeenCalled())
    expect(generateMock.mock.calls[0][1].start).toEqual({ lat: 45.2, lng: 5.7 })
  })

  it('lists the team location first and recognises a place from its point', async () => {
    generateMock.mockResolvedValue(response())
    places.state = {
      startPlaces: [{ id: 'p1', name: 'Parking du stade', point: { lat: 45.2, lng: 5.7 } }],
      endPlaces: [],
    }
    renderPanel(TEAM(), { start: '45.20000,5.70000' })
    const select = screen.getByRole('combobox', { name: 'Départ' }) as HTMLInputElement
    expect(select.value).toBe('Parking du stade')
    fireEvent.click(select)
    const options = screen.getAllByRole('option', { hidden: true }).map((o) => o.textContent)
    expect(options).toEqual(["Localisation de l'équipe", 'Parking du stade'])
    // Back to the team location: no start is sent at all
    fireEvent.click(screen.getByRole('option', { name: "Localisation de l'équipe", hidden: true }))
    fireEvent.click(generate())
    await waitFor(() => expect(generateMock).toHaveBeenCalled())
    expect('start' in generateMock.mock.calls[0][1]).toBe(false)
  })

  it('shows a point clicked on the map as such in the list', () => {
    renderPanel(TEAM())
    fireEvent.click(screen.getByText('pick start'))
    expect((screen.getByRole('combobox', { name: 'Départ' }) as HTMLInputElement).value).toBe(
      'Point choisi sur la carte'
    )
  })

  it('offers the team location and the end places for an end « Ailleurs »', async () => {
    generateMock.mockResolvedValue(response())
    places.state = {
      startPlaces: [],
      endPlaces: [{ id: 'p2', name: 'Gare', point: { lat: 45.05, lng: 5.05 } }],
    }
    renderPanel()
    fireEvent.click(screen.getByText('Ailleurs'))
    // A list to pick from: the map does not take the click until asked
    expect(screen.getByTestId('map').getAttribute('data-click-mode')).toBeNull()
    expect(generate().disabled).toBe(true)
    expect(screen.getByText("Choisissez l'arrivée dans la liste ou sur la carte.")).toBeTruthy()
    const endSelect = screen.getByRole('combobox', { name: "Lieu d'arrivée" })
    fireEvent.click(endSelect)
    const listbox = document.getElementById(endSelect.getAttribute('aria-controls')!)!
    const options = within(listbox)
      .getAllByRole('option', { hidden: true })
      .map((o) => o.textContent)
    expect(options).toEqual(["Localisation de l'équipe", 'Gare'])
    fireEvent.click(screen.getByRole('option', { name: 'Gare', hidden: true }))
    fireEvent.click(generate())
    await waitFor(() => expect(generateMock).toHaveBeenCalled())
    expect(generateMock.mock.calls[0][1].end).toEqual({ lat: 45.05, lng: 5.05 })
  })

  it('sends the dominant type, no start and no bearing for the team location', async () => {
    generateMock.mockResolvedValue(response())
    renderPanel()
    fireEvent.click(generate())
    await waitFor(() => expect(generateMock).toHaveBeenCalledTimes(1))
    const [slug, body, options] = generateMock.mock.calls[0]
    expect(slug).toBe('club')
    expect(body).toEqual({ distanceKm: 50, familiarity: 0.5, type: 'ROAD', seed: 0 })
    expect(options).toEqual({ skipErrorToast: true })
  })

  it('takes the type with the most routes', async () => {
    counts.state = { counts: { ROAD: 1, GRAVEL: 4, MTB: 0 }, isPending: false }
    generateMock.mockResolvedValue(response())
    renderPanel()
    fireEvent.click(generate())
    await waitFor(() => expect(generateMock).toHaveBeenCalled())
    expect(generateMock.mock.calls[0][1].type).toBe('GRAVEL')
  })

  it('does not send the bearing when the end is far, and the compass is disabled', async () => {
    generateMock.mockResolvedValue(response())
    renderPanel(TEAM(), { bearing: 'N', distanceKm: 50 })
    fireEvent.click(screen.getByText('Ailleurs'))
    fireEvent.click(screen.getByText('pick far end'))
    // 6° of longitude at 45°N is about 470 km: far
    expect((screen.getByRole('button', { name: 'Nord' }) as HTMLButtonElement).disabled).toBe(true)
    fireEvent.click(generate())
    await waitFor(() => expect(generateMock).toHaveBeenCalled())
    expect('bearing' in generateMock.mock.calls[0][1]).toBe(false)
    expect(generateMock.mock.calls[0][1].end).toEqual({ lat: 45, lng: 6 })
  })

  it('sends the bearing for a near end', async () => {
    generateMock.mockResolvedValue(response())
    renderPanel(TEAM(), { bearing: 'N' })
    fireEvent.click(screen.getByText('Ailleurs'))
    fireEvent.click(screen.getByText('pick near end'))
    fireEvent.click(generate())
    await waitFor(() => expect(generateMock).toHaveBeenCalled())
    expect(generateMock.mock.calls[0][1].bearing).toBe('N')
  })

  it('shows the cards in the API order, with the shared stretch from 100 m and no unpaved share on a road ride', async () => {
    generateMock.mockResolvedValue(response())
    renderPanel()
    fireEvent.click(generate())
    await waitFor(() => expect(cards()).toHaveLength(3))
    expect(screen.getByTestId('map').getAttribute('data-lines')).toBe('3')
    const [first, second, third] = cards()
    expect(within(first).getByText('Proposition 1')).toBeTruthy()
    expect(within(first).getByText(/82([,.]0)?\s?km/)).toBeTruthy()
    expect(within(first).getByText(/Dénivelé positif 640/)).toBeTruthy()
    expect(within(first).getByText('Routes prises de temps en temps')).toBeTruthy()
    expect(within(first).getByText(/Tronçon commun aller-retour/)).toBeTruthy()
    expect(within(second).getByText("Routes habituelles de l'équipe")).toBeTruthy()
    expect(within(second).queryByText(/Tronçon commun/)).toBeNull()
    expect(within(third).getByText("Routes peu prises par l'équipe")).toBeTruthy()
    expect(within(third).queryByText(/Non revêtu/)).toBeNull()
  })

  it('shows the unpaved share on a gravel ride', async () => {
    generateMock.mockResolvedValue(response())
    renderPanel(TEAM(), { type: 'GRAVEL' })
    fireEvent.click(generate())
    await waitFor(() => expect(cards()).toHaveLength(3))
    expect(within(cards()[0]).getByText(/Non revêtu : 0\s?%/)).toBeTruthy()
  })

  it('hands the chosen candidate and its type to the host', async () => {
    generateMock.mockResolvedValue(response())
    renderPanel()
    fireEvent.click(generate())
    await waitFor(() => expect(cards()).toHaveLength(3))
    fireEvent.click(within(cards()[1]).getByRole('button', { name: "Ouvrir dans l'éditeur" }))
    expect(onOpen).toHaveBeenCalledTimes(1)
    expect(onOpen.mock.calls[0][0].distanceM).toBe(79000)
    expect(onOpen.mock.calls[0][1]).toBe('ROAD')
  })

  it('« Autres propositions » sends seed 1 and keeps the previous cards, dimmed, until the answer', async () => {
    let release: (r: RouteGeneratorResponse) => void = () => {}
    generateMock.mockResolvedValueOnce(response())
    generateMock.mockImplementationOnce(
      () => new Promise<RouteGeneratorResponse>((resolve) => (release = resolve))
    )
    renderPanel()
    fireEvent.click(generate())
    await waitFor(() => expect(cards()).toHaveLength(3))
    fireEvent.click(screen.getByRole('button', { name: 'Autres propositions' }))
    await waitFor(() => expect(generateMock).toHaveBeenCalledTimes(2))
    expect(generateMock.mock.calls[1][1].seed).toBe(1)
    expect(cards()).toHaveLength(3)
    expect(cards()[0].style.opacity).toBe('0.5')
    release(response({ candidates: [candidate({ distanceM: 90000 })] }))
    await waitFor(() => expect(cards()).toHaveLength(1))
    expect(cards()[0].style.opacity).toBe('1')
  })

  it('a changed parameter drops the results', async () => {
    generateMock.mockResolvedValue(response())
    renderPanel()
    fireEvent.click(generate())
    await waitFor(() => expect(cards()).toHaveLength(3))
    fireEvent.click(screen.getByText('Gravel'))
    expect(cards()).toHaveLength(0)
    expect(screen.getByText('Aucune proposition pour le moment')).toBeTruthy()
  })

  it('words the failure in French, without a toast, and retries on a busy server', async () => {
    generateMock.mockRejectedValueOnce(new ApiClientError(503, { code: 'ROUTE_GENERATOR_BUSY' }))
    generateMock.mockResolvedValueOnce(response())
    renderPanel()
    fireEvent.click(generate())
    expect(await screen.findByText(/très demandé/)).toBeTruthy()
    fireEvent.click(screen.getByRole('button', { name: 'Réessayer' }))
    await waitFor(() => expect(cards()).toHaveLength(3))
  })

  it('names the distance of a refusal and does not offer a retry', async () => {
    generateMock.mockRejectedValue(new ApiClientError(400, { code: 'GENERATOR_NO_ROUTE' }))
    renderPanel(TEAM(), { distanceKm: 120 })
    fireEvent.click(generate())
    expect(await screen.findByText(/pour 120([,.]0)?\s?km/)).toBeTruthy()
    expect(screen.queryByRole('button', { name: 'Réessayer' })).toBeNull()
  })

  it('says what is missing when the team roads are still being analysed', async () => {
    generateMock.mockRejectedValue(
      new ApiClientError(400, {
        code: 'GENERATOR_NETWORK_TOO_SMALL',
        errorDetails: {
          type: 'GENERATOR_NETWORK_TOO_SMALL',
          routeCount: 1,
          pendingRouteCount: 3,
          excludedRouteCount: 0,
          totalLengthM: 1000,
          incomplete: true,
        } as never,
      })
    )
    renderPanel()
    fireEvent.click(generate())
    expect(await screen.findByText(/encore 3 parcours à traiter/)).toBeTruthy()
  })

  it('shows the fallback and the incomplete notices', async () => {
    generateMock.mockResolvedValue(
      response({
        familiarityFallback: true,
        network: {
          totalLengthM: 1,
          routeCount: 3,
          pendingRouteCount: 2,
          excludedRouteCount: 0,
          incomplete: true,
        },
      })
    )
    renderPanel()
    fireEvent.click(generate())
    expect(
      await screen.findByText(/la fréquentation tient compte de tous ses parcours/)
    ).toBeTruthy()
    expect(screen.getByText(/2 parcours en attente/)).toBeTruthy()
  })

  it("disables « Ouvrir dans l'éditeur » at a spent quota", async () => {
    generateMock.mockResolvedValue(response())
    renderPanel(TEAM({ plannerQuota: { limit: 20, used: 20, resetsOn: '2026-12-01' } }))
    fireEvent.click(generate())
    await waitFor(() => expect(cards()).toHaveLength(3))
    expect(
      (
        within(cards()[0]).getByRole('button', {
          name: "Ouvrir dans l'éditeur",
        }) as HTMLButtonElement
      ).disabled
    ).toBe(true)
  })
})
