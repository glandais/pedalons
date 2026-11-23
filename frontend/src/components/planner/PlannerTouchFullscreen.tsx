import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { IconFileImport, IconTrash } from '@tabler/icons-react'
import { ActionIcon, Box, Group } from '@mantine/core'
import type { RoutePlannerState } from '@/hooks/useRoutePlanner'
import { MapFullscreenShell } from '@/components/map/MapFullscreenShell'
import { PlannerBottomBar } from './PlannerBottomBar'
import { PlannerElevationStrip } from './PlannerElevationStrip'
import type { PlannerEditing } from './usePlannerEditing'

const STRIP_BODY_HEIGHT_TOUCH = 110

interface PlannerTouchFullscreenProps {
  planner: RoutePlannerState
  editing: PlannerEditing
  /** Left of the toolbar: the way back, which is the host's (a dialog to close, a screen to pop). */
  leading: ReactNode
  /** The toolbar's title, as the host names it (a dialog title on the site). */
  title: ReactNode
  /** Opens the host's file picker; the file comes back through `editing.offerFile`. */
  onImport: () => void
  /** « Done », in the bottom bar. */
  onDone: () => void
  /** The map, or the slot it is moved into. */
  children: ReactNode
}

/**
 * The planner's fullscreen editor on a finger: the toolbar (back, title, import, clear), the map,
 * and under it the elevation strip and the bottom bar that holds the tools.
 *
 * It has two hosts (docs/LEDGER_*.md WEB-183): the fullscreen dialog of the site's form
 * (`RoutePlannerField`) and the page the mobile app shows in a WebView
 * (`src/embed/mobile-planner`). The state is the host's, above it.
 */
export function PlannerTouchFullscreen({
  planner,
  editing,
  leading,
  title,
  onImport,
  onDone,
  children,
}: PlannerTouchFullscreenProps) {
  const { t } = useTranslation()
  const { controlPoints, isLoading } = planner
  return (
    <MapFullscreenShell
      leading={leading}
      title={title}
      // The figures are in the summary line of the bottom bar: not twice
      // (docs/LEDGER_*.md WEB-157).
      actions={
        // Out of the bottom bar, which has no room left for it at 360 px; away from the
        // thumb is also where a destructive action belongs.
        <Group gap={0} wrap="nowrap">
          <ActionIcon
            variant="subtle"
            size="xl"
            onClick={onImport}
            disabled={isLoading}
            aria-label={t('planner.import')}
          >
            <IconFileImport size={22} />
          </ActionIcon>
          <ActionIcon
            variant="subtle"
            color="red"
            size="xl"
            onClick={editing.handleClear}
            disabled={controlPoints.length === 0}
            aria-label={t('planner.clear')}
          >
            <IconTrash size={22} />
          </ActionIcon>
        </Group>
      }
      bottom={
        <Box style={{ flexShrink: 0 }}>
          {/* Kept in the DOM folded: the summary button's aria-controls points at it */}
          <Box id={editing.stripId}>
            {!editing.stripCollapsed && (
              <PlannerElevationStrip
                mappable={editing.mappable}
                hoveredIndex={editing.hoveredIndex}
                colorBy={planner.colorBy}
                onColorByChange={planner.setColorBy}
                surfaceStats={planner.surfaceStats}
                onHoverIndex={editing.handleHoverIndex}
                height={STRIP_BODY_HEIGHT_TOUCH}
                selectedWaypoint={editing.selectedWaypoint}
                onSelectWaypoint={editing.handleSelectWaypoint}
              />
            )}
          </Box>
          <PlannerBottomBar
            pointCount={controlPoints.length}
            isLoading={isLoading}
            error={planner.error}
            stats={editing.stats}
            profileOpen={!editing.stripCollapsed}
            onProfileToggle={editing.toggleStrip}
            profileId={editing.stripId}
            canUndo={planner.canUndo}
            canRedo={planner.canRedo}
            onUndo={planner.undo}
            onRedo={planner.redo}
            routerProfile={planner.routerProfile}
            onProfileChange={planner.setRouterProfile}
            routerTuning={planner.routerTuning}
            onTuningChange={planner.setRouterTuning}
            onTuningReset={planner.resetRouterTuning}
            engineChoice={planner.engineChoice}
            directMode={planner.directMode}
            onDirectModeChange={planner.setDirectMode}
            onDone={onDone}
          />
        </Box>
      }
    >
      {children}
    </MapFullscreenShell>
  )
}
