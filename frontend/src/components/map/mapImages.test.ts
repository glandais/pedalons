import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { ROUTE_ARROW_IMAGE } from './routeArrowLayout'
import { PRELOADED_IMAGE_IDS, resolveMapImage, type ImageMap } from './mapImages'

function fakeMap() {
  const images = new Set<string>()
  const addImage = vi.fn((id: string, _image?: unknown, _options?: unknown) => void images.add(id))
  const map = { hasImage: (id: string) => images.has(id), addImage }
  return { map: map as unknown as ImageMap, addImage }
}

function fakeContext() {
  return new Proxy(
    {
      getImageData: (_x: number, _y: number, w: number, h: number) => ({ width: w, height: h }),
      measureText: () => ({ width: 40 }),
    } as Record<string, unknown>,
    {
      get: (target, key: string) => target[key] ?? (() => {}),
      set: () => true,
    }
  )
}

describe('resolveMapImage', () => {
  beforeEach(() => {
    vi.spyOn(HTMLCanvasElement.prototype, 'getContext').mockImplementation(
      () => fakeContext() as unknown as CanvasRenderingContext2D
    )
    vi.stubGlobal('Path2D', class {})
  })
  afterEach(() => {
    vi.restoreAllMocks()
    vi.unstubAllGlobals()
  })

  it.each([ROUTE_ARROW_IMAGE, 'pdl-waypoint:DANGER', 'pdl-waypoint-label:light:Café du Port'])(
    'draws %s at pixel ratio 2',
    async (id) => {
      const { map, addImage } = fakeMap()
      await resolveMapImage(map, id)
      expect(addImage).toHaveBeenCalledTimes(1)
      expect(addImage.mock.calls[0][0]).toBe(id)
      expect(addImage.mock.calls[0][2]).toEqual({ pixelRatio: 2 })
    }
  )

  it('ignores an id that is not ours', async () => {
    const { map, addImage } = fakeMap()
    await resolveMapImage(map, 'something-else')
    await resolveMapImage(map, 'pdl-waypoint-label:light:')
    expect(addImage).not.toHaveBeenCalled()
  })

  it('does not add an image twice', async () => {
    const { map, addImage } = fakeMap()
    await resolveMapImage(map, 'pdl-waypoint:WATER')
    await resolveMapImage(map, 'pdl-waypoint:WATER')
    expect(addImage).toHaveBeenCalledTimes(1)
  })

  it('survives a canvas with no 2d context', async () => {
    vi.spyOn(HTMLCanvasElement.prototype, 'getContext').mockReturnValue(null)
    const { map, addImage } = fakeMap()
    await resolveMapImage(map, ROUTE_ARROW_IMAGE)
    await resolveMapImage(map, 'pdl-waypoint:INFO')
    await resolveMapImage(map, 'pdl-waypoint-label:dark:x')
    expect(addImage).not.toHaveBeenCalled()
  })

  it('preloads the chevron and the twelve pictograms', () => {
    expect(PRELOADED_IMAGE_IDS).toHaveLength(13)
  })
})
