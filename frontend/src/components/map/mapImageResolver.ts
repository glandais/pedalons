import type { Map as MapLibreMap } from 'maplibre-gl'
import { getOverlayBg } from '@/lib/colors'
import {
  WAYPOINT_ICON_PREFIX,
  WAYPOINT_LABEL_PREFIX,
  WAYPOINT_PRIORITY,
  waypointTypeOf,
} from '@/lib/waypoints'
import { ROUTE_ARROW_IMAGE } from './routeArrowLayout'
import { drawWaypointIcon } from './waypointIcons'

/** What the resolver needs of a map (a MapLibre `Map` fits). */
export type ImageMap = Pick<MapLibreMap, 'hasImage' | 'addImage'>

/** The chevron is drawn at twice its displayed size, pointing east: a `line` placement turns the
 * icon's x axis along the line, in the direction of its coordinates. */
const ARROW_SIZE = 32
/** A waypoint disc: 26 logical pixels, drawn at twice that. */
const ICON_LOGICAL = 26
const LABEL_MAX_CHARS = 28
const LABEL_HEIGHT = 22

function canvasOf(width: number, height: number): CanvasRenderingContext2D | null {
  const canvas = document.createElement('canvas')
  canvas.width = width
  canvas.height = height
  return canvas.getContext('2d')
}

function drawArrow(): ImageData | null {
  const ctx = canvasOf(ARROW_SIZE, ARROW_SIZE)
  if (!ctx) return null
  ctx.lineCap = 'round'
  ctx.lineJoin = 'round'
  const chevron = () => {
    ctx.beginPath()
    ctx.moveTo(12, 8)
    ctx.lineTo(21, 16)
    ctx.lineTo(12, 24)
  }
  // A dark rim under a white stroke: readable on every trace colour and every basemap.
  ctx.strokeStyle = 'rgba(0, 0, 0, 0.55)'
  ctx.lineWidth = 7
  chevron()
  ctx.stroke()
  ctx.strokeStyle = '#fff'
  ctx.lineWidth = 4
  chevron()
  ctx.stroke()
  return ctx.getImageData(0, 0, ARROW_SIZE, ARROW_SIZE)
}

function drawIcon(type: string): ImageData | null {
  const size = ICON_LOGICAL * 2
  const ctx = canvasOf(size, size)
  if (!ctx) return null
  drawWaypointIcon(ctx, type, size / 2, size / 2, size - 8)
  return ctx.getImageData(0, 0, size, size)
}

function truncate(name: string): string {
  const chars = Array.from(name)
  return chars.length > LABEL_MAX_CHARS ? `${chars.slice(0, LABEL_MAX_CHARS - 1).join('')}…` : name
}

const LABEL_FONT = '500 12px Inter, system-ui, sans-serif'

/**
 * A waypoint's name as an image: the basemaps are mostly raster dressings with no `glyphs`, so a
 * `text-field` would break the layer on them. Rounded label in the overlay colours.
 */
async function drawLabel(name: string, dark: boolean): Promise<ImageData | null> {
  try {
    await document.fonts?.load(LABEL_FONT)
  } catch {
    // the fallback face does the job
  }
  const text = truncate(name)
  const measure = canvasOf(1, 1)
  if (!measure) return null
  measure.font = LABEL_FONT
  const width = Math.ceil(measure.measureText(text).width) + 12
  const ratio = 2
  const ctx = canvasOf(width * ratio, LABEL_HEIGHT * ratio)
  if (!ctx) return null
  ctx.scale(ratio, ratio)
  ctx.fillStyle = getOverlayBg(dark ? 'dark' : 'light')
  ctx.beginPath()
  ctx.roundRect(0, 0, width, LABEL_HEIGHT, 4)
  ctx.fill()
  ctx.font = LABEL_FONT
  ctx.textBaseline = 'middle'
  ctx.fillStyle = dark ? '#c9c9c9' : '#212529'
  ctx.fillText(text, 6, LABEL_HEIGHT / 2 + 0.5)
  return ctx.getImageData(0, 0, width * ratio, LABEL_HEIGHT * ratio)
}

/**
 * Adds the image an id stands for, if it is one of ours and not already there. The id carries all
 * that is needed to draw it, so a basemap switch (which drops the style's images) loses nothing.
 * The one resolver per map (MapLibre keeps a single one) routes by the id's prefix.
 */
export function resolveMapImage(map: ImageMap, id: string): Promise<void> | void {
  if (map.hasImage(id)) return
  const add = (image: ImageData | null) => {
    // The label is drawn after a font load: the map may have been removed meanwhile
    try {
      if (image && !map.hasImage(id)) map.addImage(id, image, { pixelRatio: 2 })
    } catch {
      // Removed map: nothing to draw on
    }
  }
  if (id === ROUTE_ARROW_IMAGE) return add(drawArrow())
  if (id.startsWith(WAYPOINT_ICON_PREFIX)) {
    return add(drawIcon(waypointTypeOf(id.slice(WAYPOINT_ICON_PREFIX.length))))
  }
  if (id.startsWith(WAYPOINT_LABEL_PREFIX)) {
    const rest = id.slice(WAYPOINT_LABEL_PREFIX.length)
    const colon = rest.indexOf(':')
    const name = rest.slice(colon + 1)
    if (colon < 0 || !name) return
    return drawLabel(name, rest.slice(0, colon) === 'dark').then(add)
  }
}

/** Every image drawn ahead of time: the chevron and the twelve pictograms. */
export const PRELOADED_IMAGE_IDS: string[] = [
  ROUTE_ARROW_IMAGE,
  ...Object.keys(WAYPOINT_PRIORITY).map((type) => `${WAYPOINT_ICON_PREFIX}${type}`),
]
