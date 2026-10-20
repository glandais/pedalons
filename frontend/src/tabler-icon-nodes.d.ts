// Tabler ships each icon's drawing next to its React component; the waypoint pictograms are drawn
// on a canvas from it (components/map/waypointIcons.ts). The package has no `exports` map.
declare module '@tabler/icons-react/dist/esm/icons/*.mjs' {
  import type { IconNode } from '@tabler/icons-react'
  export const __iconNode: IconNode
}
