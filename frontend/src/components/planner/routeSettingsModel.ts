import { useMemo } from 'react'
import { RouterEngine, type RouterProfile } from '@/api/dto'
import type { RoutePlannerState } from '@/hooks/useRoutePlanner'
import type { EngineChoice } from '@/lib/routerEngine'
import {
  defaultHillsStep,
  defaultTrafficStep,
  hillsStepOf,
  isTunable,
  trafficStepOf,
  type RouterTuning,
  type TuningKey,
} from '@/lib/routerTuning'

/** Id of the « Réglages du tracé » panel in the map's open-panel state (one panel at a time per map). */
export const ROUTE_SETTINGS_PANEL_ID = 'route-settings'

/**
 * Everything the settings panel, its button and its footer need (WEB-202): bundled so the toolbar,
 * the touch bar and the docked panel take one prop instead of ten.
 */
export interface RouteSettingsModel {
  profile: RouterProfile
  onProfileChange: (profile: RouterProfile) => void
  /** The knobs set for the current profile; absent ones are the profile's values. */
  tuning: RouterTuning
  onTuningChange: (key: TuningKey, value: number) => void
  onTuningReset: () => void
  /** The choice of calculation; absent when the Pédalons engine is not on offer for the profile. */
  engineChoice?: EngineChoice
  /** Number of control points the user placed. */
  pointCount: number
  isLoading: boolean
  /** What a recalculation would touch: routed legs, their summed length (m), and whether anything stays. */
  recalcScope: { legs: number; distance: number; keeps: boolean }
  /** The route is the one the last recalculation produced, with the current settings. */
  recalculated: boolean
  onRecalculate: () => void
}

/**
 * What the panel says is « ajusté »: a step shown differs from the practice's. The Côtes step counts
 * only while it is shown (the Pédalons engine knows no elevation): nothing hidden lights it, a
 * stored one stays stored for when the standard calculation is chosen again.
 */
export function isSettingsAdjusted(settings: RouteSettingsModel): boolean {
  const { profile, tuning, engineChoice } = settings
  if (!isTunable(profile)) return false
  const hillsShown = !engineChoice || engineChoice.value === RouterEngine.STADIA
  return (
    trafficStepOf(profile, tuning) !== defaultTrafficStep(profile) ||
    (hillsShown && hillsStepOf(profile, tuning) !== defaultHillsStep(profile))
  )
}

type PlannerFields = Pick<
  RoutePlannerState,
  | 'routerProfile'
  | 'setRouterProfile'
  | 'routerTuning'
  | 'setRouterTuning'
  | 'resetRouterTuning'
  | 'engineChoice'
  | 'controlPoints'
  | 'isLoading'
  | 'recalcScope'
  | 'recalculated'
  | 'recalculate'
>

function modelOf(p: PlannerFields): RouteSettingsModel {
  return {
    profile: p.routerProfile,
    onProfileChange: p.setRouterProfile,
    tuning: p.routerTuning,
    onTuningChange: p.setRouterTuning,
    onTuningReset: p.resetRouterTuning,
    engineChoice: p.engineChoice,
    pointCount: p.controlPoints.length,
    isLoading: p.isLoading,
    recalcScope: p.recalcScope,
    recalculated: p.recalculated,
    onRecalculate: () => void p.recalculate(),
  }
}

/** The same model, stable while the planner fields it reads do not change. */
export function useRouteSettings(planner: RoutePlannerState): RouteSettingsModel {
  const {
    routerProfile,
    setRouterProfile,
    routerTuning,
    setRouterTuning,
    resetRouterTuning,
    engineChoice,
    controlPoints,
    isLoading,
    recalcScope,
    recalculated,
    recalculate,
  } = planner
  return useMemo(
    () =>
      modelOf({
        routerProfile,
        setRouterProfile,
        routerTuning,
        setRouterTuning,
        resetRouterTuning,
        engineChoice,
        controlPoints,
        isLoading,
        recalcScope,
        recalculated,
        recalculate,
      }),
    [
      routerProfile,
      setRouterProfile,
      routerTuning,
      setRouterTuning,
      resetRouterTuning,
      engineChoice,
      controlPoints,
      isLoading,
      recalcScope,
      recalculated,
      recalculate,
    ]
  )
}
