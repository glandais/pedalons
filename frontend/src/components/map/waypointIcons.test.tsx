import { describe, expect, it } from 'vitest'
import { renderToStaticMarkup } from 'react-dom/server'
import { WaypointType } from '@/api/dto'
import { WAYPOINT_TYPE_COLORS } from '@/lib/badgeColors.generated'
import { waypointTypeOf } from '@/lib/waypoints'
import { WAYPOINT_ICONS, waypointDiscColor, waypointGlyphColor } from './waypointIcons'

describe('waypoint icons', () => {
  it.each(Object.values(WaypointType))(
    '%s: the drawing is the one of the React component, made of paths',
    (type) => {
      const { Icon, node } = WAYPOINT_ICONS[type]
      expect(node.every(([element]) => element === 'path')).toBe(true)
      const svg = renderToStaticMarkup(<Icon />)
      const rendered = [...svg.matchAll(/ d="([^"]+)"/g)].map((m) => m[1])
      expect(node.map(([, attrs]) => attrs.d)).toEqual(rendered)
      expect(WAYPOINT_TYPE_COLORS[type]).toBeTruthy()
      expect(waypointDiscColor(type)).toMatch(/^#[0-9a-f]{6}$/i)
    }
  )

  it('falls back to the information for an unknown type', () => {
    expect(waypointTypeOf('FOO')).toBe('INFO')
    expect(waypointDiscColor('FOO')).toBe(waypointDiscColor('INFO'))
  })

  it('picks a dark pictogram on a light disc and a white one otherwise', () => {
    expect(waypointGlyphColor('SPLIT')).toBe('#212529')
    expect(waypointGlyphColor('WATER')).toBe('#fff')
  })
})
