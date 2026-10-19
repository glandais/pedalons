import { describe, it, expect } from 'vitest'
import {
  groupStyles,
  isDarkBasemap,
  isKnownGroup,
  resolveMapStyle,
  styleUrlFor,
  type MapStyle,
} from './mapStyles'

const style = (
  id: string,
  group: string,
  darkVariant?: string,
  attribution?: string
): MapStyle => ({
  id,
  label: id,
  group,
  url: `https://tiles.example/${id}.json`,
  ...(darkVariant ? { darkVariant } : {}),
  ...(attribution ? { attribution } : {}),
})

const SERVED: MapStyle[] = [
  style('colorful', 'vector', 'https://tiles.example/eclipse.json'),
  style('ign-vector', 'vector', undefined, '<a href="https://www.ign.fr/">IGN</a>'),
  style('ign-satellite', 'satellite'),
  style('cyclosm', 'raster'),
]

describe('resolveMapStyle', () => {
  it('falls back to the first served basemap when the remembered id has left the contract', () => {
    // The server may drop a basemap between two restarts; better a map than none.
    expect(resolveMapStyle(SERVED, 'graybeard')?.id).toBe('colorful')
    expect(resolveMapStyle(SERVED, null)?.id).toBe('colorful')
  })

  it('renders nothing rather than an invented style when nothing is served yet', () => {
    expect(resolveMapStyle([], 'colorful')).toBeUndefined()
  })

  it('carries the served attribution through to the resolved style', () => {
    // `MapAttribution` reads it off the resolved style and passes it as `customAttribution`. It is
    // set only where the provider's own style document declares none — IGN's PLAN.IGN — so losing
    // it in resolution would leave that one basemap uncredited, and only that one, which is
    // precisely the kind of gap nobody notices.
    expect(resolveMapStyle(SERVED, 'ign-vector')?.attribution).toContain('IGN')
    expect(resolveMapStyle(SERVED, 'colorful')?.attribution).toBeUndefined()
  })
})

describe('styleUrlFor', () => {
  it('loads the dark counterpart only when there is one', () => {
    // A satellite view has no night version: hiding it after dark would be worse than showing it.
    expect(styleUrlFor(SERVED[0], true)).toBe('https://tiles.example/eclipse.json')
    expect(styleUrlFor(SERVED[2], true)).toBe(SERVED[2].url)
  })
})

describe('isDarkBasemap', () => {
  it('follows what is rendered, not the colour scheme alone', () => {
    // Dark mode loads the dark counterpart where there is one…
    expect(isDarkBasemap(SERVED[0], true)).toBe(true)
    expect(isDarkBasemap(SERVED[0], false)).toBe(false)
    // …and keeps a light basemap that has none
    expect(isDarkBasemap(SERVED[1], true)).toBe(false)
    expect(isDarkBasemap(SERVED[3], true)).toBe(false)
    // A satellite view is dark at any hour
    expect(isDarkBasemap(SERVED[2], false)).toBe(true)
  })
})

describe('groupStyles', () => {
  it('sections in served order without re-sorting', () => {
    expect(groupStyles(SERVED).map((s) => [s.group, s.styles.length])).toEqual([
      ['vector', 2],
      ['satellite', 1],
      ['raster', 1],
    ])
  })

  it('keeps two runs of the same group apart', () => {
    // A server that separated them meant to: merging would silently overrule its classification.
    const interleaved = [SERVED[0], SERVED[2], SERVED[1]]
    expect(groupStyles(interleaved).map((s) => s.group)).toEqual(['vector', 'satellite', 'vector'])
  })

  it('leaves an unknown group to be titled by its raw value', () => {
    expect(isKnownGroup('vector')).toBe(true)
    expect(isKnownGroup('hillshade')).toBe(false)
  })
})
