import { describe, it, expect, vi, afterEach, beforeEach } from 'vitest'
import { render, screen, cleanup, fireEvent, waitFor } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import { useState } from 'react'
import { ErrorCode, type GeocodeResultDto, type GeoJsonPoint } from '@/api/dto'
import { ApiClientError } from '@/lib/apiError'
import { frenchT } from '@/test/frenchT'

vi.mock('react-i18next', async (importOriginal) => ({
  ...(await importOriginal<typeof import('react-i18next')>()),
  useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
}))

// The search answers what the test sets; the place lookup is a spy (docs/LEDGER_*.md API-129).
const state = vi.hoisted(() => ({
  results: [] as GeocodeResultDto[],
  resolvePlace: vi.fn(),
}))

vi.mock('@/api/endpoints/geocode/geocode', () => ({
  useSearchPlaces: (params: { q: string }) => ({
    data: params.q.length >= 3 ? state.results : undefined,
    isFetching: false,
  }),
  resolvePlace: state.resolvePlace,
}))

import { GeocoderAutocomplete, type GeocoderAutocompleteProps } from './GeocoderAutocomplete'

const ANNECY: GeocodeResultDto = {
  id: 'whosonfirst:locality:101750851',
  displayName: 'Annecy, France',
}

function renderField(onChange = vi.fn(), extra: Partial<GeocoderAutocompleteProps> = {}) {
  function Harness() {
    const [value, setValue] = useState<GeoJsonPoint | null>(null)
    return (
      <GeocoderAutocomplete
        value={value}
        onChange={(point) => {
          setValue(point)
          onChange(point)
        }}
        label="Lieu"
        {...extra}
      />
    )
  }
  render(
    <MantineProvider>
      <Harness />
    </MantineProvider>
  )
  return onChange
}

async function pick(displayName: string) {
  fireEvent.change(screen.getByRole('textbox'), { target: { value: 'annecy' } })
  fireEvent.click(await screen.findByText(displayName))
}

beforeEach(() => {
  state.results = [ANNECY]
  state.resolvePlace.mockReset()
})

afterEach(() => {
  cleanup()
})

describe('GeocoderAutocomplete', () => {
  it('resolves the position of a picked suggestion that has none, and keeps its name', async () => {
    state.resolvePlace.mockResolvedValue({
      id: ANNECY.id,
      displayName: 'Annecy, Haute-Savoie, France',
      lat: 45.89964,
      lon: 6.12273,
    })
    const onChange = renderField()

    await pick('Annecy, France')

    await waitFor(() =>
      expect(onChange).toHaveBeenCalledWith({ type: 'Point', coordinates: [6.12273, 45.89964] })
    )
    expect(state.resolvePlace).toHaveBeenCalledTimes(1)
    expect(state.resolvePlace).toHaveBeenCalledWith(
      { id: ANNECY.id },
      { skipErrorToast: true },
      expect.any(AbortSignal)
    )
    expect(screen.getByText('Annecy, France')).toBeInTheDocument()
  })

  it('shows a loading state while the position is being resolved', async () => {
    state.resolvePlace.mockReturnValue(new Promise(() => {}))
    const onChange = renderField()

    await pick('Annecy, France')

    expect(await screen.findByLabelText(frenchT('geocoder.resolving'))).toBeInTheDocument()
    expect(screen.queryByRole('textbox')).not.toBeInTheDocument()
    expect(onChange).not.toHaveBeenCalled()
  })

  it('emits a suggestion that already has a position without any lookup', async () => {
    state.results = [{ ...ANNECY, lat: 45.9, lon: 6.1 }]
    const onChange = renderField()

    await pick('Annecy, France')

    expect(onChange).toHaveBeenCalledWith({ type: 'Point', coordinates: [6.1, 45.9] })
    expect(state.resolvePlace).not.toHaveBeenCalled()
  })

  it('never resolves the suggestions themselves, only the one picked', async () => {
    state.results = [ANNECY, { id: 'whosonfirst:locality:2', displayName: 'Annemasse, France' }]
    renderField()

    fireEvent.change(screen.getByRole('textbox'), { target: { value: 'anne' } })
    await screen.findByText('Annemasse, France')

    expect(state.resolvePlace).not.toHaveBeenCalled()
  })

  it('keeps the field usable with a message when the provider is unavailable', async () => {
    state.resolvePlace.mockRejectedValue(
      new ApiClientError(503, { code: ErrorCode.GEOCODING_UNAVAILABLE })
    )
    const onChange = renderField()

    await pick('Annecy, France')

    expect(await screen.findByText(frenchT('errors.api.GEOCODING_UNAVAILABLE'))).toBeInTheDocument()
    expect(screen.getByRole('textbox')).toBeEnabled()
    expect(onChange).not.toHaveBeenCalled()
  })

  it('says the position could not be found for any other failure', async () => {
    state.resolvePlace.mockRejectedValue(new ApiClientError(404, { code: ErrorCode.NOT_FOUND }))
    renderField()

    await pick('Annecy, France')

    expect(await screen.findByText(frenchT('geocoder.resolveFailed'))).toBeInTheDocument()
    expect(screen.getByRole('textbox')).toBeEnabled()
  })

  it('drops a lookup cancelled by clearing the field', async () => {
    let answer: (place: GeocodeResultDto) => void = () => {}
    state.resolvePlace.mockReturnValue(new Promise((resolve) => (answer = resolve)))
    const onChange = renderField()

    await pick('Annecy, France')
    fireEvent.click(await screen.findByLabelText(frenchT('geocoder.clear')))
    answer({ ...ANNECY, lat: 45.9, lon: 6.1 })

    await screen.findByRole('textbox')
    expect(onChange).toHaveBeenCalledTimes(1)
    expect(onChange).toHaveBeenCalledWith(null)
  })

  it('tells the form a lookup is running, so it can hold its submit, and when it is over', async () => {
    let answer: (place: GeocodeResultDto) => void = () => {}
    state.resolvePlace.mockReturnValue(new Promise((resolve) => (answer = resolve)))
    const onResolvingChange = vi.fn()
    renderField(vi.fn(), { onResolvingChange })

    await pick('Annecy, France')
    expect(onResolvingChange).toHaveBeenLastCalledWith(true)

    answer({ ...ANNECY, lat: 45.9, lon: 6.1 })
    await waitFor(() => expect(onResolvingChange).toHaveBeenLastCalledWith(false))
  })

  it('tells the form the lookup is over when it fails', async () => {
    state.resolvePlace.mockRejectedValue(new ApiClientError(404, { code: ErrorCode.NOT_FOUND }))
    const onResolvingChange = vi.fn()
    renderField(vi.fn(), { onResolvingChange })

    await pick('Annecy, France')

    await screen.findByText(frenchT('geocoder.resolveFailed'))
    expect(onResolvingChange).toHaveBeenLastCalledWith(false)
  })

  it('keeps the required mark, the description and the form error while resolving', async () => {
    state.resolvePlace.mockReturnValue(new Promise(() => {}))
    renderField(vi.fn(), {
      required: true,
      description: 'Le point de rendez-vous',
      error: 'Position requise',
    })

    await pick('Annecy, France')

    await screen.findByLabelText(frenchT('geocoder.resolving'))
    expect(screen.getByText('*')).toBeInTheDocument()
    expect(screen.getByText('Le point de rendez-vous')).toBeInTheDocument()
    expect(screen.getByText('Position requise')).toBeInTheDocument()
  })
})
