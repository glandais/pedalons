import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type {
  PlannerQuotaDto,
  RetouchedRouteDto,
  RouteDetailDto,
  RouteRetouchOfferDto,
  RouteRetouchResponse,
} from '@/api/dto'
import { ApiClientError } from '@/lib/apiError'

const retouchMock = vi.hoisted(() => vi.fn())
const mapProps = vi.hoisted(() => ({ last: undefined as Record<string, unknown> | undefined }))

vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})
vi.mock('@/api/endpoints/route-generator/route-generator', () => ({ retouchRoute: retouchMock }))
vi.mock('@/api/endpoints/places/places', () => ({
  useGetPlace: (_team: string, id: string) => ({
    data: id
      ? { id, name: 'Place', geometry: { type: 'Point', coordinates: [5.5, 45.5] } }
      : undefined,
  }),
}))
vi.mock('../common/PlaceAutocomplete', () => ({
  PlaceAutocomplete: (props: { onChange: (id: string | undefined) => void }) => (
    <button onClick={() => props.onChange('place1')}>choose place</button>
  ),
}))
// The map is out of scope: a stand-in that exposes what the dialog gives it, and places points.
vi.mock('./RouteRetouchMap', () => ({
  RouteRetouchMap: (props: {
    candidates: unknown[]
    placing: boolean
    onPick: (point: { lat: number; lng: number }) => void
  }) => {
    mapProps.last = props as never
    return (
      <div data-testid="map" data-lines={props.candidates.length} data-placing={props.placing}>
        <button onClick={() => props.onPick({ lat: 45, lng: 6 })}>pick end</button>
      </div>
    )
  },
}))

import { RouteRetouchModal, type RetouchMode } from './RouteRetouchModal'

const OFFER: RouteRetouchOfferDto = {
  available: true,
  operations: ['RESIZE', 'MOVE_END'],
  originalDistanceM: 82_400,
  minDistanceKm: 57.7,
  maxDistanceKm: 107.1,
  minChangeKm: 1,
  maxChangeShare: 0.3,
  endSnapM: 500,
  proposalsMax: 3,
  rideType: 'GRAVEL',
}

const ROUTE = {
  name: 'Boucle du lac',
  slug: 'boucle',
  tracks: [
    {
      line: {
        type: 'LineString',
        coordinates: [
          [5, 45],
          [5.1, 45.1],
        ],
      },
    },
  ],
} as unknown as RouteDetailDto

const candidate = (over: Partial<RetouchedRouteDto> = {}): RetouchedRouteDto => ({
  polyline: '_p~iF~ps|U',
  distanceM: 70_000,
  ascentM: 900,
  descentM: 900,
  kind: 'SHORTEN',
  keptShare: 0.85,
  unmatchedM: 0,
  changed: {
    fromM: 30_000,
    toM: 42_400,
    newM: 30_000,
    startIndex: 0,
    endIndex: 1,
    teamShare: 0.5,
    unpavedShare: 0,
    crossings: 0,
  },
  bounds: { minLat: 45, minLon: 5, maxLat: 45.1, maxLon: 5.1 },
  ...over,
})

const response = (over: Partial<RouteRetouchResponse> = {}): RouteRetouchResponse => ({
  operation: 'RESIZE',
  originalDistanceM: 82_400,
  originalAscentM: 1000,
  targetDistanceM: 70_000,
  candidates: [
    candidate({ distanceM: 70_000 }),
    candidate({ distanceM: 70_500 }),
    candidate({ distanceM: 69_800 }),
  ],
  ...over,
})

const onOpen = vi.fn()
const onEdit = vi.fn()
const onClose = vi.fn()

function renderModal(
  mode: RetouchMode = 'resize',
  extra: { plannerQuota?: PlannerQuotaDto; offer?: RouteRetouchOfferDto; editable?: boolean } = {}
) {
  render(
    <QueryClientProvider client={new QueryClient()}>
      <MantineProvider>
        <MemoryRouter>
          <RouteRetouchModal
            opened
            onClose={onClose}
            teamSlug="club"
            route={ROUTE}
            offer={extra.offer ?? OFFER}
            initialMode={mode}
            plannerQuota={extra.plannerQuota}
            onOpen={onOpen}
            onEdit={extra.editable ? onEdit : undefined}
          />
        </MemoryRouter>
      </MantineProvider>
    </QueryClientProvider>
  )
}

const field = () => screen.getByLabelText('Distance visée') as HTMLInputElement
const type = (value: string) => fireEvent.change(field(), { target: { value } })
const submit = () => screen.getByRole('button', { name: 'Proposer' }) as HTMLButtonElement
const cards = () => screen.queryAllByTestId('retouched-route-card')

beforeEach(() => {
  retouchMock.mockReset()
  onOpen.mockReset()
  onEdit.mockReset()
  retouchMock.mockResolvedValue(response())
})
afterEach(cleanup)

describe('RouteRetouchModal, adjust the distance', () => {
  it('opens on the mode chosen in the menu, and says the length', () => {
    renderModal('moveEnd')
    expect(
      screen.getByText(/Touchez la carte pour poser la nouvelle arrivée, ou choisissez/)
    ).toBeTruthy()
    expect(screen.getByTestId('map').getAttribute('data-placing')).toBe('true')
    cleanup()
    renderModal('resize')
    expect(screen.getByText(/Actuellement 82,4.*km/)).toBeTruthy()
    expect(screen.getByTestId('map').getAttribute('data-placing')).toBe('false')
  })

  it('reads the bounds from the offer', () => {
    renderModal()
    expect(screen.getByText(/Entre 57,7.*km et 107,1.*km/)).toBeTruthy()
  })

  it('refuses a target in the dead zone, with the minimum change', () => {
    renderModal()
    type('82.9')
    expect(screen.getByText(/Visez au moins 1.*km de plus ou de moins/)).toBeTruthy()
    expect(submit().disabled).toBe(true)
  })

  it('refuses a target out of the range', () => {
    renderModal()
    type('150')
    expect(screen.getByText(/doit être comprise entre/)).toBeTruthy()
    expect(submit().disabled).toBe(true)
  })

  it('waits for a value', () => {
    renderModal()
    expect(submit().disabled).toBe(true)
  })

  it('says shortening is not always possible, only for a shortening', () => {
    renderModal()
    type('70')
    expect(screen.getByText(/Raccourcir réussit un peu plus d'une fois sur deux/)).toBeTruthy()
    type('90')
    expect(screen.queryByText(/Raccourcir réussit/)).toBeNull()
  })

  it('asks for the distance and shows the proposals', async () => {
    renderModal()
    type('70')
    fireEvent.click(submit())
    await waitFor(() => expect(cards()).toHaveLength(3))
    expect(retouchMock).toHaveBeenCalledTimes(1)
    expect(retouchMock.mock.calls[0].slice(0, 3)).toEqual([
      'club',
      'boucle',
      { targetDistanceKm: 70, discovery: 0.25, seed: 0 },
    ])
    expect(screen.getByTestId('map').getAttribute('data-lines')).toBe('3')
  })

  it('asks for other proposals with the next seed', async () => {
    renderModal()
    type('70')
    fireEvent.click(submit())
    await waitFor(() => expect(cards()).toHaveLength(3))
    fireEvent.click(screen.getByRole('button', { name: 'Autres propositions' }))
    await waitFor(() => expect(retouchMock).toHaveBeenCalledTimes(2))
    expect(retouchMock.mock.calls[1][2]).toMatchObject({ targetDistanceKm: 70, seed: 1 })
  })

  it('drops the proposals when the target changes', async () => {
    renderModal()
    type('70')
    fireEvent.click(submit())
    await waitFor(() => expect(cards()).toHaveLength(3))
    type('75')
    expect(cards()).toHaveLength(0)
  })

  it('hands the chosen proposal to the planner, named and typed', async () => {
    renderModal()
    type('70')
    fireEvent.click(submit())
    await waitFor(() => expect(cards()).toHaveLength(3))
    fireEvent.click(cards()[1])
    fireEvent.click(screen.getByRole('button', { name: "Ouvrir dans l'éditeur" }))
    expect(onOpen).toHaveBeenCalledWith({
      polyline: '_p~iF~ps|U',
      type: 'GRAVEL',
      distanceM: 70_500,
      name: 'Boucle du lac (retouché)',
    })
  })

  it("hands the chosen proposal to the route's editor with « Remplacer le tracé », under its own name", async () => {
    renderModal('resize', { editable: true })
    type('70')
    fireEvent.click(submit())
    await waitFor(() => expect(cards()).toHaveLength(3))
    fireEvent.click(cards()[1])
    fireEvent.click(screen.getByRole('button', { name: 'Remplacer le tracé' }))
    expect(onEdit).toHaveBeenCalledWith({
      polyline: '_p~iF~ps|U',
      type: 'GRAVEL',
      distanceM: 70_500,
      name: 'Boucle du lac',
    })
    expect(onOpen).not.toHaveBeenCalled()
  })

  it('offers no « Remplacer le tracé » to a reader who cannot edit the route', async () => {
    renderModal()
    type('70')
    fireEvent.click(submit())
    await waitFor(() => expect(cards()).toHaveLength(3))
    expect(screen.queryByRole('button', { name: 'Remplacer le tracé' })).toBeNull()
  })

  it('disables the opening, and says why, when the planner quota is spent', async () => {
    renderModal('resize', { plannerQuota: { used: 20, limit: 20 } as PlannerQuotaDto })
    type('70')
    fireEvent.click(submit())
    await waitFor(() => expect(cards()).toHaveLength(3))
    expect(
      (screen.getByRole('button', { name: "Ouvrir dans l'éditeur" }) as HTMLButtonElement).disabled
    ).toBe(true)
    expect(screen.getByText('Les enregistrements de tracés du mois sont épuisés.')).toBeTruthy()
  })
})

describe('RouteRetouchModal, refusals', () => {
  it('words a refused shortening as an answer, with the finish and the generator', async () => {
    retouchMock.mockRejectedValue(
      new ApiClientError(400, { code: 'ROUTE_RETOUCH_NO_SHORTER' } as never)
    )
    renderModal()
    type('70')
    fireEvent.click(submit())
    expect(await screen.findByText(/ne se raccourcit pas à 70.*km/)).toBeTruthy()
    // A reply, not a failure: no retry, and the next steps
    expect(screen.queryByRole('button', { name: 'Réessayer' })).toBeNull()
    const generator = screen.getByRole('link', { name: 'Ouvrir le générateur' })
    expect(generator.getAttribute('href')).toMatch(/^\/.+\?d=70&s=45.00000%2C5.00000&t=GRAVEL$/)
    fireEvent.click(screen.getByRole('button', { name: "Déplacer l'arrivée", hidden: true }))
    await waitFor(() => expect(screen.queryByText(/ne se raccourcit pas/)).toBeNull())
    expect(screen.getByTestId('map').getAttribute('data-placing')).toBe('true')
  })

  it('keeps « Autres propositions » after a refusal another seed can pass', async () => {
    retouchMock.mockRejectedValueOnce(
      new ApiClientError(422, { code: 'ROUTE_RETOUCH_NO_PROPOSAL' } as never)
    )
    retouchMock.mockResolvedValueOnce(response())
    renderModal()
    type('90')
    fireEvent.click(submit())
    expect(await screen.findByText(/Aucune proposition/)).toBeTruthy()
    fireEvent.click(await screen.findByTestId('retouch-more-after-error'))
    await waitFor(() => expect(cards()).toHaveLength(3))
    expect(retouchMock.mock.calls[1][2]).toMatchObject({ seed: 1 })
  })

  it('words the order anomaly with its own message', async () => {
    retouchMock.mockRejectedValue(
      new ApiClientError(400, { code: 'ROUTE_RETOUCH_ORDER_ANOMALY' } as never)
    )
    renderModal()
    type('90')
    fireEvent.click(submit())
    expect(await screen.findByText(/repasse sur elle-même/)).toBeTruthy()
    expect(screen.getByRole('link', { name: 'Ouvrir le générateur' })).toBeTruthy()
  })

  it('offers a retry on a busy engine, and none on a refusal', async () => {
    retouchMock.mockRejectedValueOnce(
      new ApiClientError(503, { code: 'ROUTE_GENERATOR_BUSY' } as never)
    )
    retouchMock.mockResolvedValueOnce(response())
    renderModal()
    type('90')
    fireEvent.click(submit())
    expect(await screen.findByText(/très demandé/)).toBeTruthy()
    fireEvent.click(screen.getByRole('button', { name: 'Réessayer' }))
    await waitFor(() => expect(cards()).toHaveLength(3))
  })
})

describe('RouteRetouchModal, move the finish', () => {
  it('waits for a point', () => {
    renderModal('moveEnd')
    expect(submit().disabled).toBe(true)
  })

  it('sends a tapped point as the end', async () => {
    retouchMock.mockResolvedValue(
      response({
        operation: 'MOVE_END',
        candidates: [candidate({ kind: 'MOVE_END', variant: 'BEST' })],
      })
    )
    renderModal('moveEnd')
    fireEvent.click(screen.getByRole('button', { name: 'pick end' }))
    fireEvent.click(submit())
    await waitFor(() => expect(cards()).toHaveLength(1))
    expect(retouchMock.mock.calls[0][2]).toEqual({
      end: { point: { lat: 45, lng: 6 } },
      discovery: 0.25,
      seed: 0,
    })
    expect(screen.getByText('Le moins de changement')).toBeTruthy()
  })

  it('sends a place of the team as the end, and only the place', async () => {
    renderModal('moveEnd')
    fireEvent.click(screen.getByRole('button', { name: 'choose place' }))
    fireEvent.click(submit())
    await waitFor(() => expect(retouchMock).toHaveBeenCalled())
    expect(retouchMock.mock.calls[0][2]).toEqual({
      end: { placeId: 'place1' },
      discovery: 0.25,
      seed: 0,
    })
  })

  it('switches mode from the control', () => {
    renderModal('resize')
    fireEvent.click(screen.getByText("Déplacer l'arrivée"))
    expect(screen.getByTestId('map').getAttribute('data-placing')).toBe('true')
  })

  it('offers only the operations of the offer', () => {
    renderModal('resize', { offer: { ...OFFER, operations: ['RESIZE'] } })
    expect(screen.queryByText("Déplacer l'arrivée")).toBeNull()
  })
})
