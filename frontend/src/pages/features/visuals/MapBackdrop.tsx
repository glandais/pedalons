/**
 * The shared stand-in for a map, drawn in the theme's colours so the dark scheme keeps parity:
 * a green-tinted ground and two park patches. Roads are drawn by the caller in
 * `var(--mantine-color-body)`.
 */
export function MapBackdrop({ width, height }: { width: number; height: number }) {
  return (
    <>
      <rect width={width} height={height} fill="var(--mantine-color-green-light)" />
      <ellipse
        cx={width * 0.8}
        cy={height * 0.2}
        rx={width * 0.1}
        ry={height * 0.1}
        fill="var(--mantine-color-green-light-hover)"
      />
      <ellipse
        cx={width * 0.25}
        cy={height * 0.85}
        rx={width * 0.13}
        ry={height * 0.11}
        fill="var(--mantine-color-green-light-hover)"
      />
    </>
  )
}

/** The start marker of the real maps: a green dot ringed with the page colour. */
export function Pin({ x, y }: { x: number; y: number }) {
  return (
    <circle
      cx={x}
      cy={y}
      r={8}
      fill="var(--mantine-color-green-filled)"
      stroke="var(--mantine-color-body)"
      strokeWidth={3}
    />
  )
}
