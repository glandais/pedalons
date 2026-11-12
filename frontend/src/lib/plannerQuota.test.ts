import { describe, expect, it } from 'vitest'
import { ErrorCode } from '@/api/dto'
import { ApiClientError } from '@/lib/apiError'
import { CALLER_RENDERED_ERROR_CODES } from '@/lib/apiError'
import { createServerI18n } from '@/i18n'
import { plannerErrorMessage } from './plannerErrors'
import { isPlannerQuotaSpent, plannerQuotaRefusalOf, resetMonthName } from './plannerQuota'

const refusal = (errorDetails: Record<string, unknown>) =>
  new ApiClientError(403, {
    code: ErrorCode.PLANNER_QUOTA_REACHED,
    errorDetails: { type: 'PLANNER_QUOTA_REACHED', ...errorDetails } as never,
  })

describe('isPlannerQuotaSpent', () => {
  it('is spent at the limit, not below', () => {
    expect(isPlannerQuotaSpent({ limit: 20, used: 20, resetsOn: '2026-12-01' })).toBe(true)
    expect(isPlannerQuotaSpent({ limit: 20, used: 21, resetsOn: '2026-12-01' })).toBe(true)
    expect(isPlannerQuotaSpent({ limit: 20, used: 19, resetsOn: '2026-12-01' })).toBe(false)
  })

  it('is never spent unlimited, without a quota, or for the platform admin', () => {
    expect(isPlannerQuotaSpent({ used: 500, resetsOn: '2026-12-01' })).toBe(false)
    expect(isPlannerQuotaSpent(undefined)).toBe(false)
    expect(isPlannerQuotaSpent(null)).toBe(false)
    expect(isPlannerQuotaSpent({ limit: 10, used: 10, resetsOn: '2026-12-01' }, true)).toBe(false)
  })
})

describe('plannerQuotaRefusalOf', () => {
  it('reads the details of a refusal', () => {
    expect(
      plannerQuotaRefusalOf(
        refusal({ scope: 'TEAM', limit: 20, current: 20, resetsOn: '2026-12-01', teamName: 'Club' })
      )
    ).toEqual({
      type: 'PLANNER_QUOTA_REACHED',
      scope: 'TEAM',
      limit: 20,
      current: 20,
      resetsOn: '2026-12-01',
      teamName: 'Club',
    })
  })

  it('is undefined for another failure or a refusal without its details', () => {
    expect(plannerQuotaRefusalOf(new ApiClientError(403, { code: ErrorCode.FORBIDDEN }))).toBe(
      undefined
    )
    expect(
      plannerQuotaRefusalOf(new ApiClientError(403, { code: ErrorCode.PLANNER_QUOTA_REACHED }))
    ).toBe(undefined)
    expect(plannerQuotaRefusalOf(new Error('boom'))).toBe(undefined)
  })

  it('is rendered by its caller: no toast on top of the dialog', () => {
    expect(CALLER_RENDERED_ERROR_CODES.has(ErrorCode.PLANNER_QUOTA_REACHED)).toBe(true)
  })
})

describe('resetMonthName', () => {
  it('spells the month of the first day, whatever the zone', () => {
    expect(resetMonthName('2026-12-01', 'fr')).toBe('décembre')
    expect(resetMonthName('2027-01-01', 'en')).toBe('January')
  })
})

describe('the copy (real catalogue)', () => {
  it('says why the limit applies, the GPX import and the day it starts again', async () => {
    const { t } = await createServerI18n('fr')
    expect(t('planner.quota.team', { teamName: 'Les Copains', limit: 20 })).toBe(
      "Les Copains utilise l'offre gratuite, qui permet 20 enregistrements de parcours tracés sur la carte par mois. Ils sont tous utilisés ce mois-ci."
    )
    expect(t('planner.quota.personal', { limit: 10 })).toContain('aucune équipe débloquée')
    expect(t('planner.quota.alternative', { month: resetMonthName('2026-12-01', 'fr') })).toBe(
      "L'import de GPX reste disponible, et le compteur repart le 1er décembre."
    )
  })

  it('gives the planner its own line for the quota and the daily cap', async () => {
    const { t } = await createServerI18n('fr')
    const quota = plannerErrorMessage(
      new ApiClientError(403, { code: ErrorCode.PLANNER_QUOTA_REACHED }),
      t
    )
    expect(quota).toContain("L'import de GPX reste disponible")
    const daily = plannerErrorMessage(
      new ApiClientError(429, { code: ErrorCode.ROUTING_DAILY_LIMIT_REACHED }),
      t
    )
    expect(daily).toContain('Réessayez demain')
  })
})
