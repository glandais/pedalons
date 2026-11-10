import { useTranslation } from 'react-i18next'
import {
  IconArrowBackUp,
  IconArrowForwardUp,
  IconFileImport,
  IconLineDashed,
  IconTrash,
} from '@tabler/icons-react'
import { Box, Divider } from '@mantine/core'
import type { RouterProfile } from '@/api/dto'
import { MapToolbarButton } from '@/components/map/MapToolbarButton'
import { directShortcut } from '@/lib/plannerErrors'
import type { RouterTuning, TuningKey } from '@/lib/routerTuning'
import { PlannerHelpControl } from './PlannerHelpControl'
import { PlannerStatus } from './PlannerStatus'
import { RouterProfileSelector } from './RouterProfileSelector'

interface PlannerToolbarProps {
  /** Number of control points the user placed. */
  pointCount: number
  isLoading: boolean
  /** Already translated message of the last routing failure. */
  error: string | null
  /** Distance and ascent (metres) of the computed route; given once it has two points. */
  stats?: { distance: number; ascend: number }
  canUndo: boolean
  canRedo: boolean
  onUndo: () => void
  onRedo: () => void
  directMode: boolean
  onDirectModeChange: (on: boolean) => void
  routerProfile: RouterProfile
  onProfileChange: (profile: RouterProfile) => void
  routerTuning: RouterTuning
  onTuningChange: (key: TuningKey, value: number) => void
  onTuningReset: () => void
  /** Given where the map holds the tool: adds « Import a GPX file ». */
  onImport?: () => void
  /**
   * Given inline, where nothing else on the page clears the trace (the fullscreen editor has its
   * own button in its header): adds « Clear ».
   */
  onClear?: () => void
}

const separator = <Divider orientation="vertical" color="var(--ml-c-bg-3)" my={6} mx={2} />

/**
 * The planner's tools on a mouse, in one toolbar at the bottom centre of the map, inline and
 * fullscreen alike (docs/LEDGER_*.md WEB-157): the summary of the trace (distance, D+, points, the
 * calculation or the routing error), then history, how the next leg is drawn, and the file and
 * help. Its buttons keep the names (and shortcuts) they had in the map's control column. On a
 * finger the same tools are in `PlannerBottomBar`, outside the map.
 *
 * It is laid next to the map, not in it: a click on it never reaches MapLibre, so it never places a
 * point. The surface and the buttons follow the map controls' `--ml-*` variables (index.css).
 */
export function PlannerToolbar({
  pointCount,
  isLoading,
  error,
  stats,
  canUndo,
  canRedo,
  onUndo,
  onRedo,
  directMode,
  onDirectModeChange,
  routerProfile,
  onProfileChange,
  routerTuning,
  onTuningChange,
  onTuningReset,
  onImport,
  onClear,
}: PlannerToolbarProps) {
  const { t } = useTranslation()
  const hasSummary = pointCount > 0 || isLoading || error !== null || stats !== undefined

  return (
    <Box role="toolbar" aria-label={t('planner.toolbar')} className="map-toolbar">
      {hasSummary && (
        <>
          {/* Shrinks first, the buttons never: a long error is truncated (full text in a tooltip). */}
          <Box px="xs" style={{ flex: '0 1 auto', minWidth: 0, overflow: 'hidden' }}>
            <PlannerStatus
              pointCount={pointCount}
              isLoading={isLoading}
              error={error}
              stats={stats}
            />
          </Box>
          {separator}
        </>
      )}
      <MapToolbarButton
        label={t('planner.undo')}
        icon={<IconArrowBackUp size={20} />}
        onClick={onUndo}
        disabled={!canUndo}
      />
      <MapToolbarButton
        label={t('planner.redo')}
        icon={<IconArrowForwardUp size={20} />}
        onClick={onRedo}
        disabled={!canRedo}
      />
      {separator}
      {/* Its name is constant: the pressed state says whether it is on; the modifier key, held at
          the moment of a gesture, is not reflected here. */}
      <MapToolbarButton
        label={t('planner.direct.toggle.mouse', { shortcut: directShortcut(t) })}
        icon={<IconLineDashed size={20} />}
        onClick={() => onDirectModeChange(!directMode)}
        active={directMode}
      />
      <RouterProfileSelector
        currentProfile={routerProfile}
        onProfileChange={onProfileChange}
        tuning={routerTuning}
        onTuningChange={onTuningChange}
        onTuningReset={onTuningReset}
      />
      {separator}
      {onImport && (
        <MapToolbarButton
          label={t('planner.import')}
          icon={<IconFileImport size={20} />}
          onClick={onImport}
          disabled={isLoading}
        />
      )}
      <PlannerHelpControl />
      {onClear && (
        <>
          {separator}
          <MapToolbarButton
            label={t('planner.clear')}
            icon={<IconTrash size={20} />}
            onClick={onClear}
            disabled={pointCount === 0}
          />
        </>
      )}
    </Box>
  )
}
