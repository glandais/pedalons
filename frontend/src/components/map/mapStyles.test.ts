import { describe, it, expect } from 'vitest'
import {
  groupStyles,
  isDarkBasemap,
  isKnownGroup,
  mapStyleChoices,
  rendersDark,
  resolveMapChoice,
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

describe('resolveMapChoice', () => {
  it('falls back to the first served basemap when the remembered id has left the contract', () => {
    // The server may drop a basemap between two restarts; better a map than none.
    expect(resolveMapChoice(SERVED, 'graybeard', false)?.id).toBe('colorful')
    expect(resolveMapChoice(SERVED, null, false)?.id).toBe('colorful')
  })

  it('renders nothing rather than an invented style when nothing is served yet', () => {
    expect(resolveMapChoice([], 'colorful', false)).toBeUndefined()
  })

  it('carries the served attribution through to the resolved style', () => {
    // `MapAttribution` reads it off the resolved style and passes it as `customAttribution`. It is
    // set only where the provider's own style document declares none — IGN's PLAN.IGN — so losing
    // it in resolution would leave that one basemap uncredited, and only that one, which is
    // precisely the kind of gap nobody notices.
    expect(resolveMapChoice(SERVED, 'ign-vector', false)?.attribution).toContain('IGN')
    expect(resolveMapChoice(SERVED, 'colorful', false)?.attribution).toBeUndefined()
  })

  it('keeps a pinned rendering across a theme change, on the line that shows it', () => {
    const lightTheme = resolveMapChoice(SERVED, 'colorful:dark', false)
    expect(lightTheme?.id).toBe('colorful:dark')
    expect(rendersDark(lightTheme, false)).toBe(true)
    // Under a dark theme the same pick is what the theme gives: it is that line which lights up
    const darkTheme = resolveMapChoice(SERVED, 'colorful:dark', true)
    expect(darkTheme?.id).toBe('colorful')
    expect(rendersDark(darkTheme, true)).toBe(true)
  })

  it('ignores a pin on a basemap without a dark counterpart', () => {
    const choice = resolveMapChoice(SERVED, 'cyclosm:dark', false)
    expect(choice?.id).toBe('cyclosm')
    expect(choice?.pin).toBeNull()
  })
})

describe('mapStyleChoices', () => {
  it('offers the rendering the theme would not pick, only where a dark counterpart exists', () => {
    expect(mapStyleChoices(SERVED, false).map((s) => s.id)).toEqual([
      'colorful',
      'colorful:dark',
      'ign-vector',
      'ign-satellite',
      'cyclosm',
    ])
    expect(mapStyleChoices(SERVED, true).map((s) => s.id)).toContain('colorful:light')
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
