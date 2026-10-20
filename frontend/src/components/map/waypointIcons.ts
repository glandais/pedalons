import {
  IconAlertTriangle,
  IconArrowsSplit2,
  IconBinoculars,
  IconCoffee,
  IconDroplet,
  IconInfoSmall,
  IconMountain,
  IconPlayerPlay,
  IconToiletPaper,
  IconTool,
  IconToolsKitchen2,
  IconUsersGroup,
  type IconNode,
  type TablerIcon,
} from '@tabler/icons-react'
import { __iconNode as alertTriangle } from '@tabler/icons-react/dist/esm/icons/IconAlertTriangle.mjs'
import { __iconNode as arrowsSplit2 } from '@tabler/icons-react/dist/esm/icons/IconArrowsSplit2.mjs'
import { __iconNode as binoculars } from '@tabler/icons-react/dist/esm/icons/IconBinoculars.mjs'
import { __iconNode as coffee } from '@tabler/icons-react/dist/esm/icons/IconCoffee.mjs'
import { __iconNode as droplet } from '@tabler/icons-react/dist/esm/icons/IconDroplet.mjs'
import { __iconNode as infoSmall } from '@tabler/icons-react/dist/esm/icons/IconInfoSmall.mjs'
import { __iconNode as mountain } from '@tabler/icons-react/dist/esm/icons/IconMountain.mjs'
import { __iconNode as playerPlay } from '@tabler/icons-react/dist/esm/icons/IconPlayerPlay.mjs'
import { __iconNode as toiletPaper } from '@tabler/icons-react/dist/esm/icons/IconToiletPaper.mjs'
import { __iconNode as tool } from '@tabler/icons-react/dist/esm/icons/IconTool.mjs'
import { __iconNode as toolsKitchen2 } from '@tabler/icons-react/dist/esm/icons/IconToolsKitchen2.mjs'
import { __iconNode as usersGroup } from '@tabler/icons-react/dist/esm/icons/IconUsersGroup.mjs'
import { DEFAULT_THEME, isLightColor } from '@mantine/core'
import type { WaypointType } from '@/api/dto'
import { WAYPOINT_TYPE_COLORS } from '@/lib/badgeColors.generated'
import { waypointTypeOf } from '@/lib/waypoints'

/**
 * The shade of the waypoint discs on the map and the profile: 6 in both themes, like the track
 * surfaces (BRANDING §3.6) — the dark shades go out against a dark basemap.
 */
export const WAYPOINT_DISC_SHADE = 6

/** One Tabler icon per type (BRANDING §6): the component for the DOM, its drawing for canvases. */
export const WAYPOINT_ICONS = {
  REGROUP: { Icon: IconUsersGroup, node: usersGroup },
  SUPPLY: { Icon: IconToolsKitchen2, node: toolsKitchen2 },
  WATER: { Icon: IconDroplet, node: droplet },
  CAFE: { Icon: IconCoffee, node: coffee },
  TOILETS: { Icon: IconToiletPaper, node: toiletPaper },
  DANGER: { Icon: IconAlertTriangle, node: alertTriangle },
  SUMMIT: { Icon: IconMountain, node: mountain },
  VIEWPOINT: { Icon: IconBinoculars, node: binoculars },
  BIKE_SHOP: { Icon: IconTool, node: tool },
  REAL_START: { Icon: IconPlayerPlay, node: playerPlay },
  SPLIT: { Icon: IconArrowsSplit2, node: arrowsSplit2 },
  INFO: { Icon: IconInfoSmall, node: infoSmall },
} satisfies Record<WaypointType, { Icon: TablerIcon; node: IconNode }>

/** The disc colour of a type, outside React (the map and chart images). */
export function waypointDiscColor(type: string): string {
  const family = WAYPOINT_TYPE_COLORS[waypointTypeOf(type)] ?? 'gray'
  return DEFAULT_THEME.colors[family][WAYPOINT_DISC_SHADE]
}

/** The pictogram colour on that disc: same decision as `autoContrast` on the list's ThemeIcon. */
export function waypointGlyphColor(type: string): string {
  return isLightColor(waypointDiscColor(type), 0.3) ? '#212529' : '#fff'
}

interface DrawOptions {
  selected?: boolean
}

/**
 * Draws a waypoint — shadow, disc of its colour, white ring, Tabler pictogram — centred on
 * (`cx`, `cy`), `diameter` pixels wide. Shared by the map layer and the elevation profile. Without
 * `Path2D` (jsdom) only the disc is drawn.
 */
export function drawWaypointIcon(
  ctx: CanvasRenderingContext2D,
  type: string,
  cx: number,
  cy: number,
  diameter: number,
  { selected = false }: DrawOptions = {}
): void {
  const t = waypointTypeOf(type)
  const radius = diameter / 2
  ctx.save()
  ctx.shadowColor = 'rgba(0, 0, 0, 0.35)'
  ctx.shadowBlur = selected ? 6 : 3
  ctx.shadowOffsetY = 1
  ctx.beginPath()
  ctx.arc(cx, cy, radius, 0, Math.PI * 2)
  ctx.fillStyle = waypointDiscColor(t)
  ctx.fill()
  ctx.restore()

  ctx.save()
  ctx.beginPath()
  ctx.arc(cx, cy, radius - 1, 0, Math.PI * 2)
  ctx.lineWidth = 2
  ctx.strokeStyle = '#fff'
  ctx.stroke()
  ctx.restore()

  if (typeof Path2D === 'undefined') return
  const glyph = diameter * 0.62
  ctx.save()
  ctx.translate(cx - glyph / 2, cy - glyph / 2)
  ctx.scale(glyph / 24, glyph / 24)
  ctx.lineWidth = 2
  ctx.lineCap = 'round'
  ctx.lineJoin = 'round'
  ctx.strokeStyle = waypointGlyphColor(t)
  for (const [, attrs] of WAYPOINT_ICONS[t].node) {
    if (attrs.d) ctx.stroke(new Path2D(attrs.d))
  }
  ctx.restore()
}
