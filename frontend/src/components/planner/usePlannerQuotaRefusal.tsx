import { useState, type ReactNode } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import type { PlannerQuotaDetails } from '@/api/dto'
import { invalidatePlannerQuota, plannerQuotaRefusalOf } from '@/lib/plannerQuota'
import { PlannerQuotaModal } from './PlannerQuotaModal'

export interface PlannerQuotaRefusalHandler {
  /**
   * Takes a failed call: a PLANNER_QUOTA_REACHED refusal opens the dialog, refreshes the quota the
   * entry points read and returns true; anything else returns false and stays the caller's.
   * `teamSlug` overrides the hook's, for a screen that picks the team at the call (a promotion).
   */
  offer: (error: unknown, teamSlug?: string) => boolean
  /** The dialog, to render once in the screen. */
  modal: ReactNode
}

/**
 * A save's side of the refusal: `teamSlug` names the team a TEAM refusal refreshes (absent in the
 * GPX tools, where only the personal quota is refused). The code is in CALLER_RENDERED_ERROR_CODES:
 * no toast says it before the dialog does.
 */
export function usePlannerQuotaRefusal(teamSlug?: string): PlannerQuotaRefusalHandler {
  const queryClient = useQueryClient()
  const [refusal, setRefusal] = useState<PlannerQuotaDetails | null>(null)

  const offer = (error: unknown, slug = teamSlug) => {
    const details = plannerQuotaRefusalOf(error)
    if (!details) return false
    setRefusal(details)
    if (details.scope === 'PERSONAL') invalidatePlannerQuota(queryClient)
    else if (slug) invalidatePlannerQuota(queryClient, slug)
    return true
  }

  return {
    offer,
    modal: <PlannerQuotaModal refusal={refusal} onClose={() => setRefusal(null)} />,
  }
}
