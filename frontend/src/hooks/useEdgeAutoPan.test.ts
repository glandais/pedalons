import { act, renderHook } from '@testing-library/react'
import type { RefObject } from 'react'
import type { MapRef } from 'react-map-gl/maplibre'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { EDGE_PAN_MAX_SPEED_PX_S as MAX } from '@/lib/edgePan'
import { useEdgeAutoPan } from './useEdgeAutoPan'

// A flat map, 1 degree = 1 px, 800 x 600, whose origin the panBy calls move
const SIZE = { clientWidth: 800, clientHeight: 600 }

function fakeMap() {
  const offset = { x: 0, y: 0 }
  const map = {
    project: vi.fn(([lng, lat]: [number, number]) => ({ x: lng - offset.x, y: lat - offset.y })),
    unproject: vi.fn(({ x, y }: { x: number; y: number }) => ({
      lng: x + offset.x,
      lat: y + offset.y,
    })),
    panBy: vi.fn(([dx, dy]: [number, number]) => {
      offset.x += dx
      offset.y += dy
    }),
    getContainer: () => SIZE,
  }
  return map
}

let frames: Map<number, FrameRequestCallback>
let nextFrame: number
/** Runs the pending animation frame at `time`. */
function runFrame(time: number) {
  const [id, cb] = [...frames.entries()][0]
  frames.delete(id)
  act(() => cb(time))
}

beforeEach(() => {
  frames = new Map()
  nextFrame = 0
  vi.stubGlobal('requestAnimationFrame', (cb: FrameRequestCallback) => {
    frames.set(++nextFrame, cb)
    return nextFrame
  })
  vi.stubGlobal('cancelAnimationFrame', (id: number) => frames.delete(id))
})
afterEach(() => vi.unstubAllGlobals())

function setup() {
  const map = fakeMap()
  const onPan = vi.fn()
  const ref = { current: map } as unknown as RefObject<MapRef | null>
  const hook = renderHook(() => useEdgeAutoPan(ref, onPan))
  return { map, onPan, hook }
}

describe('useEdgeAutoPan', () => {
  it('does not scroll for a grab near the edge, only once the point moved by 3 px', () => {
    const { map, hook } = setup()
    hook.result.current.begin({ lng: 5, lat: 300 })
    hook.result.current.follow({ lng: 6, lat: 300 })
    expect(frames.size).toBe(0)
    hook.result.current.follow({ lng: 10, lat: 300 })
    expect(frames.size).toBe(1)
    expect(map.panBy).not.toHaveBeenCalled()
  })

  it('pans without animation each frame and keeps the point under the pointer', () => {
    const { map, onPan, hook } = setup()
    hook.result.current.begin({ lng: 100, lat: 300 })
    hook.result.current.follow({ lng: 0, lat: 300 })
    runFrame(1000)
    // First frame: 16 ms at the maximum speed, towards the west
    expect(map.panBy).toHaveBeenCalledWith([-MAX * 0.016, 0], { animate: false })
    // The screen position (0, 300) is unchanged: the coordinates under it moved by the pan
    expect(onPan).toHaveBeenCalledWith({ lng: -MAX * 0.016, lat: 300 })
    expect(frames.size).toBe(1)
    runFrame(1016)
    expect(map.panBy).toHaveBeenCalledTimes(2)
    expect(map.panBy.mock.calls[1][0][0]).toBeCloseTo(-MAX * 0.016)
  })

  it('caps one frame at 50 ms', () => {
    const { map, hook } = setup()
    hook.result.current.begin({ lng: 100, lat: 300 })
    hook.result.current.follow({ lng: 0, lat: 300 })
    runFrame(1000)
    runFrame(5000)
    expect(map.panBy.mock.calls[1][0][0]).toBeCloseTo(-MAX * 0.05)
  })

  it('stops the frames when the point leaves the zone', () => {
    const { hook } = setup()
    hook.result.current.begin({ lng: 100, lat: 300 })
    hook.result.current.follow({ lng: 0, lat: 300 })
    runFrame(1000)
    hook.result.current.follow({ lng: 400, lat: 300 })
    // The pending frame finds the point in the middle and ends the loop
    runFrame(1016)
    expect(frames.size).toBe(0)
  })

  it('stop() ends the loop but a later follow in the zone resumes it', () => {
    const { hook } = setup()
    hook.result.current.begin({ lng: 100, lat: 300 })
    hook.result.current.follow({ lng: 0, lat: 300 })
    hook.result.current.stop()
    expect(frames.size).toBe(0)
    hook.result.current.follow({ lng: 2, lat: 300 })
    expect(frames.size).toBe(1)
  })

  it('block() refuses every follow until the next begin', () => {
    const { hook } = setup()
    hook.result.current.begin({ lng: 100, lat: 300 })
    hook.result.current.follow({ lng: 0, lat: 300 })
    hook.result.current.block()
    expect(frames.size).toBe(0)
    hook.result.current.follow({ lng: 1, lat: 300 })
    expect(frames.size).toBe(0)
    hook.result.current.begin({ lng: 100, lat: 300 })
    hook.result.current.follow({ lng: 0, lat: 300 })
    expect(frames.size).toBe(1)
  })

  it('ends on a pointerup on the window', () => {
    const { map, hook } = setup()
    hook.result.current.begin({ lng: 100, lat: 300 })
    hook.result.current.follow({ lng: 0, lat: 300 })
    window.dispatchEvent(new Event('pointerup'))
    expect(frames.size).toBe(0)
    // Disarmed: following again does nothing until a new begin
    hook.result.current.follow({ lng: 0, lat: 300 })
    expect(frames.size).toBe(0)
    expect(map.panBy).not.toHaveBeenCalled()
  })

  it('a release outside the map, after the mouse left it, still ends the gesture', () => {
    const { hook } = setup()
    hook.result.current.begin({ lng: 100, lat: 300 })
    hook.result.current.follow({ lng: 0, lat: 300 })
    hook.result.current.stop()
    window.dispatchEvent(new Event('pointerup'))
    // Back in the edge zone, button up: disarmed, nothing scrolls
    hook.result.current.follow({ lng: 2, lat: 300 })
    expect(frames.size).toBe(0)
  })

  it('cancels the loop on unmount', () => {
    const { hook } = setup()
    hook.result.current.begin({ lng: 100, lat: 300 })
    hook.result.current.follow({ lng: 0, lat: 300 })
    hook.unmount()
    expect(frames.size).toBe(0)
  })
})
