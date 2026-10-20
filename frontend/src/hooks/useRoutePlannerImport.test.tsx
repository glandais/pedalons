import { act, renderHook, waitFor } from '@testing-library/react'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { ApiClientError } from '@/lib/apiError'
import { ErrorCode, type GpxImportResponse, type WaypointDto } from '@/api/dto'
import { encode1, encode2 } from '@/lib/polyline'
import { useRoutePlanner, MAX_IMPORT_BYTES } from './useRoutePlanner'

const routeMock = vi.hoisted(() => vi.fn())
const lineElevationMock = vi.hoisted(() => vi.fn())
const importMock = vi.hoisted(() => vi.fn())
vi.mock('@/api/endpoints/router/router', () => ({
  route: routeMock,
  importGpx: importMock,
  lineElevation: lineElevationMock,
}))
vi.mock('react-i18next', () => ({ useTranslation: () => ({ t: (k: string) => k }) }))

function track(lng: number, lat: number, n = 20) {
  const coords = Array.from({ length: n }, (_, i) => [lng + i * 0.0005, lat])
  const climb = Array.from({ length: n }, (_, i) => i)
  return {
    line: encode2(coords),
    ele: encode1(Array.from({ length: n }, (_, i) => 100 + i)),
    climb: encode1(climb),
    dist: 1000,
    ascend: n - 1,
  }
}

function response(tracks = [track(5, 45)]): GpxImportResponse {
  return { name: 'Boucle', tracks, waypointCount: 0, elevationFallback: false }
}

function fileOf(name = 'a.gpx', size = 10) {
  const f = new File(['x'.repeat(size)], name, { lastModified: 1 })
  return f
}

const A = { lng: 5, lat: 45 }
const B = { lng: 5.01, lat: 45 }

describe('useRoutePlanner importGpx', () => {
  beforeEach(() => {
    routeMock.mockReset()
    importMock.mockReset()
    localStorage.clear()
    routeMock.mockImplementation(async ({ to }: { to: { lng: number; lat: number } }) => ({
      route: {
        coordinates: [
          [5.01, 45, 100],
          [to.lng, to.lat, 100],
        ],
      },
      ascend: 3,
    }))
  })

  it('replaces the route, sends the team, and puts the operation in the history', async () => {
    importMock.mockResolvedValue(response())
    const { result } = renderHook(() => useRoutePlanner({ teamSlug: 'club' }))
    let info: unknown
    await act(async () => {
      info = await result.current.importGpx(fileOf(), 'replace')
    })
    expect(info).toMatchObject({ name: 'Boucle', mode: 'replace' })
    expect(importMock).toHaveBeenCalledTimes(1)
    expect(importMock.mock.calls[0][0]).toMatchObject({ teamSlug: 'club' })
    expect(importMock.mock.calls[0][1]).toMatchObject({ skipErrorToast: true })
    expect(result.current.route.points.length).toBeGreaterThanOrEqual(2)
    expect(result.current.route.ascend).toBeCloseTo(19, 5)
    expect(result.current.canUndo).toBe(true)
    act(() => result.current.undo())
    expect(result.current.route.points).toHaveLength(0)
  })

  it('the snapshot hands back the file while the route is the import, and not after any gesture, until an undo gives it back', async () => {
    importMock.mockResolvedValue(response())
    const file = fileOf()
    const { result } = renderHook(() => useRoutePlanner())
    await act(async () => {
      await result.current.importGpx(file, 'replace')
    })
    expect(result.current.snapshot().file).toBe(file)
    expect(result.current.snapshot().dirty).toBe(true)
    // a gesture
    await act(async () => {
      result.current.addControlPoint({ lng: 5.2, lat: 45.2 }, true)
    })
    await waitFor(() => expect(result.current.snapshot().file).toBeUndefined())
    // undo goes back to a copy of the import, which is still exactly the import: the file again
    act(() => result.current.undo())
    expect(result.current.snapshot().file).toBe(file)
  })

  it('keeps the file when the relief of the join between two tracks is read in the background', async () => {
    vi.useFakeTimers()
    try {
      importMock.mockResolvedValue(response([track(5, 45), track(5.05, 45.01)]))
      lineElevationMock.mockImplementation(
        async (body: { lines: { from: typeof A; to: typeof A }[] }) => ({
          lines: body.lines.map(({ from, to }) => ({
            line: encode2([
              [from.lng, from.lat],
              [to.lng, to.lat],
            ]),
            ele: encode1([100, 120]),
            climb: encode1([0, 20]),
            dist: 5000,
            ascend: 20,
          })),
          elevationFallback: false,
        })
      )
      const file = fileOf()
      const { result } = renderHook(() => useRoutePlanner())
      await act(async () => {
        await result.current.importGpx(file, 'replace')
      })
      const imported = result.current.route
      expect(result.current.snapshot().file).toBe(file)
      await act(async () => {
        await vi.advanceTimersByTimeAsync(300)
      })
      // One edge to read: the join. The route was enriched, and is still the import.
      expect(lineElevationMock).toHaveBeenCalledTimes(1)
      expect(result.current.route).not.toBe(imported)
      expect(result.current.route.points.some((p) => p.directProfile)).toBe(true)
      expect(result.current.snapshot().file).toBe(file)
      expect(result.current.canUndo).toBe(true)
    } finally {
      vi.useRealTimers()
    }
  })

  it('undoing the import then redoing it gives the file back', async () => {
    importMock.mockResolvedValue(response())
    const file = fileOf()
    const { result } = renderHook(() => useRoutePlanner())
    await act(async () => {
      await result.current.importGpx(file, 'replace')
    })
    act(() => result.current.undo())
    expect(result.current.snapshot().file).toBeUndefined()
    act(() => result.current.redo())
    expect(result.current.snapshot().file).toBe(file)
  })

  it('an import saved by its state carries the climb of its source', async () => {
    importMock.mockResolvedValue(response())
    const { result } = renderHook(() => useRoutePlanner())
    await act(async () => {
      await result.current.importGpx(fileOf(), 'replace')
    })
    expect(result.current.snapshot().plannerState?.sources[0].climb).toBeDefined()
  })

  it('appends after the drawn route with one routed call, keeping the earlier sources', async () => {
    importMock.mockResolvedValue(response([track(5.05, 45.01)]))
    const { result } = renderHook(() => useRoutePlanner())
    act(() => result.current.addControlPoint(A, true))
    await waitFor(() => expect(result.current.controlPoints).toHaveLength(1))
    act(() => result.current.addControlPoint(B, true))
    await waitFor(() => expect(result.current.controlPoints).toHaveLength(2))
    const before = result.current.route.points.length
    await act(async () => {
      await result.current.importGpx(fileOf(), 'append')
    })
    expect(routeMock).toHaveBeenCalledTimes(1)
    expect(result.current.route.points.length).toBeGreaterThan(before)
    const imported = result.current.route.points.filter((p) => p.imported)
    expect(imported.length).toBeGreaterThanOrEqual(2)
    expect(result.current.snapshot().file).toBeUndefined()
    expect(result.current.snapshot().plannerState?.sources).toHaveLength(1)
  })

  it('a join that fails fails the whole operation and the retry does not send the file again', async () => {
    importMock.mockResolvedValue(response([track(5.05, 45.01)]))
    const { result } = renderHook(() => useRoutePlanner())
    act(() => result.current.addControlPoint(A, true))
    await waitFor(() => expect(result.current.controlPoints).toHaveLength(1))
    act(() => result.current.addControlPoint(B, true))
    await waitFor(() => expect(result.current.controlPoints).toHaveLength(2))
    const points = result.current.route.points.length
    const file = fileOf()
    routeMock.mockRejectedValueOnce(new ApiClientError(422, { code: ErrorCode.ROUTING_NO_ROUTE }))
    let info: unknown = 'unset'
    await act(async () => {
      info = await result.current.importGpx(file, 'append')
    })
    expect(info).toBeNull()
    expect(result.current.error).toBe('planner.error.noRoute')
    expect(result.current.route.points).toHaveLength(points)
    expect(result.current.canUndo).toBe(true) // only the two drawn points
    await act(async () => {
      info = await result.current.importGpx(file, 'append')
    })
    expect(info).not.toBeNull()
    expect(importMock).toHaveBeenCalledTimes(1)
  })

  it('refuses a file over 10 MB without any request', async () => {
    const { result } = renderHook(() => useRoutePlanner())
    const big = fileOf('big.gpx', 10)
    Object.defineProperty(big, 'size', { value: MAX_IMPORT_BYTES + 1 })
    let info: unknown = 'unset'
    await act(async () => {
      info = await result.current.importGpx(big, 'replace')
    })
    expect(info).toBeNull()
    expect(importMock).not.toHaveBeenCalled()
    expect(result.current.error).toBe('planner.import.tooBig')
  })

  it('refuses tracks that would exceed the 8 sources, appended to a route that holds some', async () => {
    importMock.mockResolvedValueOnce(response([track(5, 45), track(5.1, 45.1)]))
    const { result } = renderHook(() => useRoutePlanner())
    await act(async () => {
      await result.current.importGpx(fileOf('a.gpx'), 'replace')
    })
    importMock.mockResolvedValueOnce(
      response(Array.from({ length: 7 }, (_, i) => track(6 + i * 0.1, 46)))
    )
    let info: unknown = 'unset'
    await act(async () => {
      info = await result.current.importGpx(fileOf('b.gpx'), 'append')
    })
    expect(info).toBeNull()
    expect(result.current.error).toBe('planner.import.tooManyTracks')
  })

  it('words the server refusals by their code, and a failure of its own otherwise', async () => {
    importMock.mockRejectedValueOnce(new ApiClientError(400, { code: ErrorCode.GPX_EMPTY }))
    const { result } = renderHook(() => useRoutePlanner())
    await act(async () => {
      await result.current.importGpx(fileOf('a.gpx'), 'replace')
    })
    expect(result.current.error).toBe('errors.api.GPX_EMPTY')
    importMock.mockRejectedValueOnce(new Error('network'))
    await act(async () => {
      await result.current.importGpx(fileOf('b.gpx'), 'replace')
    })
    expect(result.current.error).toBe('planner.import.failed')
    expect(result.current.route.points).toHaveLength(0)
  })

  it('is locked while an operation runs, and undo abandons it', async () => {
    importMock.mockImplementation(
      (_b: unknown, _o: unknown, signal?: AbortSignal) =>
        new Promise((_res, rej) =>
          signal?.addEventListener('abort', () => rej(new Error('aborted')))
        )
    )
    const { result } = renderHook(() => useRoutePlanner())
    let first: Promise<unknown> = Promise.resolve()
    act(() => {
      first = result.current.importGpx(fileOf('a.gpx'), 'replace')
    })
    await waitFor(() => expect(result.current.isLoading).toBe(true))
    let second: unknown = 'unset'
    await act(async () => {
      second = await result.current.importGpx(fileOf('b.gpx'), 'replace')
    })
    expect(second).toBeNull()
    expect(importMock).toHaveBeenCalledTimes(1)
    act(() => result.current.undo())
    await act(async () => {
      await first
    })
    expect(await first).toBeNull()
    expect(result.current.isLoading).toBe(false)
    expect(result.current.error).toBeNull()
    expect(result.current.canUndo).toBe(false)
  })

  it('reports the elevation fallback it was told of, and no route point left out when they all came', async () => {
    importMock.mockResolvedValue({ ...response(), waypointCount: 0, elevationFallback: true })
    const { result } = renderHook(() => useRoutePlanner())
    let info: unknown
    await act(async () => {
      info = await result.current.importGpx(fileOf(), 'replace')
    })
    expect(info).toMatchObject({ droppedWaypoints: 0, elevationFallback: true })
  })
})

describe('useRoutePlanner importGpx and the route points (C3e)', () => {
  const wpt = (name: string, i = 0): WaypointDto => ({
    geometry: { type: 'Point', coordinates: [5.002 + i * 0.0001, 45] },
    name,
    type: 'WATER',
    origin: 'IMPORTED',
  })

  beforeEach(() => {
    routeMock.mockReset()
    importMock.mockReset()
    localStorage.clear()
  })

  it('loads the file’s route points into the list, as imported ones with no id', async () => {
    importMock.mockResolvedValue({
      ...response(),
      waypointCount: 2,
      waypoints: [wpt('Source'), wpt('Fontaine', 1)],
    })
    const { result } = renderHook(() => useRoutePlanner())
    let info: unknown
    await act(async () => {
      info = await result.current.importGpx(fileOf(), 'replace')
    })
    expect(info).toMatchObject({ droppedWaypoints: 0 })
    expect(result.current.waypoints.map((w) => [w.name, w.origin, w.id])).toEqual([
      ['Source', 'IMPORTED', undefined],
      ['Fontaine', 'IMPORTED', undefined],
    ])
    // the list changed: it goes to the server, the file's own are in it
    expect(result.current.snapshot().waypoints).toHaveLength(2)
    // and it is one operation: undone with the track
    act(() => result.current.undo())
    expect(result.current.waypoints).toHaveLength(0)
  })

  it('replace drops the imported points and keeps the author’s; append keeps both', async () => {
    const opening = [
      { ...wpt('Vieux'), id: '0a1' },
      { ...wpt('Mien'), id: '0a2', origin: 'AUTHOR' },
    ] as WaypointDto[]
    importMock.mockResolvedValue({ ...response(), waypointCount: 1, waypoints: [wpt('Neuf')] })
    const { result } = renderHook(() => useRoutePlanner({ initialWaypoints: opening }))
    await act(async () => {
      await result.current.importGpx(fileOf('a.gpx'), 'replace')
    })
    expect(result.current.waypoints.map((w) => w.name)).toEqual(['Mien', 'Neuf'])
    expect(result.current.waypoints[0].id).toBe('0a2')

    importMock.mockResolvedValue({ ...response([track(5.05, 45)]), waypoints: [wpt('Autre')] })
    routeMock.mockResolvedValue({ route: { coordinates: [[5.05, 45, 100]] }, ascend: 0 })
    await act(async () => {
      await result.current.importGpx(fileOf('b.gpx'), 'append')
    })
    expect(result.current.waypoints.map((w) => w.name)).toEqual(['Mien', 'Neuf', 'Autre'])
  })

  it('stops at 500 and counts what the server cut and what the list could not take', async () => {
    const opening = Array.from({ length: 498 }, (_, i) => ({
      ...wpt(`a${i}`),
      id: `id${i}`,
      origin: 'AUTHOR',
    })) as WaypointDto[]
    // the file had 505 points: the response carries the first 500, three came in
    importMock.mockResolvedValue({
      ...response(),
      waypointCount: 505,
      waypoints: Array.from({ length: 5 }, (_, i) => wpt(`n${i}`, i)),
    })
    const { result } = renderHook(() => useRoutePlanner({ initialWaypoints: opening }))
    let info: unknown
    await act(async () => {
      info = await result.current.importGpx(fileOf(), 'replace')
    })
    expect(result.current.waypoints).toHaveLength(500)
    expect(info).toMatchObject({ droppedWaypoints: 500 + 3 })
  })

  it('a route point operation leaves an import intact: the file still goes up', async () => {
    importMock.mockResolvedValue(response())
    const file = fileOf()
    const { result } = renderHook(() => useRoutePlanner())
    await act(async () => {
      await result.current.importGpx(file, 'replace')
    })
    act(() => {
      result.current.addWaypoint(
        { lng: 5.002, lat: 45, distance: 150 },
        { type: 'REGROUP', name: 'Ici', description: '' }
      )
    })
    expect(result.current.snapshot().file).toBe(file)
    expect(result.current.snapshot().waypoints).toHaveLength(1)
    // undoing the point goes back to the import, which is still the file
    act(() => result.current.undo())
    expect(result.current.snapshot().file).toBe(file)
    expect(result.current.snapshot().waypoints).toBeUndefined()
  })
})
