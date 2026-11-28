/** The class callers put on their `<svg>`: the map tones below are CSS variables scoped there. */
export const MAP_CLASS = 'features-map'
/** A road, a trace's casing and water, in the tones of the map stand-in (see `index.css`). */
export const MAP_ROAD = 'var(--features-map-road)'
export const MAP_CASING = 'var(--features-map-casing)'
export const MAP_WATER = 'var(--features-map-water)'

/**
 * The shared stand-in for a map: OpenStreetMap tones in light, anthracite in dark (the tones are
 * the `.features-map` variables of `index.css`, docs/LEDGER_*.md WEB-221) and two park patches. Callers put
 * `className={MAP_CLASS}` on their `<svg>`, draw roads in `MAP_ROAD` and a trace's casing in
 * `MAP_CASING`.
 */
export function MapBackdrop({ width, height }: { width: number; height: number }) {
  return (
    <>
      <rect width={width} height={height} fill="var(--features-map-ground)" />
      <ellipse
        cx={width * 0.8}
        cy={height * 0.2}
        rx={width * 0.1}
        ry={height * 0.1}
        fill="var(--features-map-park)"
      />
      <ellipse
        cx={width * 0.25}
        cy={height * 0.85}
        rx={width * 0.13}
        ry={height * 0.11}
        fill="var(--features-map-park)"
      />
    </>
  )
}

/** The start marker of the real maps: a green dot ringed with white. */
export function Pin({ x, y }: { x: number; y: number }) {
  return (
    <circle
      cx={x}
      cy={y}
      r={8}
      fill="var(--mantine-color-green-filled)"
      stroke="var(--mantine-color-white)"
      strokeWidth={3}
    />
  )
}
