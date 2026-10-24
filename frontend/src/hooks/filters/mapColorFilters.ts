import { z } from 'zod'
import type { ColorByOption } from '@/components/route/ColorByControl'

/** Every mode a fullscreen map's line can arrive in, as its URL spells it. */
const MAP_COLOR_MODES = ['grade', 'surface', 'wind'] as const satisfies readonly ColorByOption[]

const DEFAULT_MAP_COLOR: ColorByOption = 'grade'

/**
 * What colours the line of a fullscreen map, carried by its URL (ledger WEB-117, plan
 * 2026-10-24-weather-on-map.md §5 palier 3): the page that opens the map passes its own mode, so a
 * shared link shows the same map. The grade, the default, writes nothing; a mode the URL names but
 * the map cannot offer (no surface, no forecast) is the page's to fall back from.
 */
export const mapColorFiltersSchema = z.object({
  colorBy: z.enum(MAP_COLOR_MODES).default(DEFAULT_MAP_COLOR).catch(DEFAULT_MAP_COLOR),
})

export const mapColorFiltersAlias = { colorBy: 'color' } as const

/** `path` opened in `colorBy`: `?color=wind`, nothing for the grade. */
export function withMapColor(path: string, colorBy: ColorByOption): string {
  if (colorBy === DEFAULT_MAP_COLOR) return path
  const params = new URLSearchParams({ [mapColorFiltersAlias.colorBy]: colorBy })
  return `${path}?${params.toString()}`
}
