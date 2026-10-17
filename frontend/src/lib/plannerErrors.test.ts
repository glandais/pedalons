import { describe, expect, it } from 'vitest'
import { ErrorCode } from '@/api/dto'
import { ApiClientError } from '@/lib/apiError'
import { createServerI18n } from '@/i18n'
import { plannerErrorMessage } from './plannerErrors'

const fail = (code: ErrorCode, status = 400) => new ApiClientError(status, { code })

describe('plannerErrorMessage (real catalogue)', () => {
  it('spells the straight-line shortcut into the no-route message', async () => {
    const i18n = await createServerI18n('fr')
    const message = plannerErrorMessage(fail(ErrorCode.ROUTING_NO_ROUTE), i18n.t)
    expect(message).toContain('Aucun itinéraire trouvé')
    expect(message).not.toContain('{{')
    expect(message).toMatch(/Alt|⌥/)
  })

  it('names the team or the site depending on whose flag refused', async () => {
    const i18n = await createServerI18n('fr')
    const refused = fail(ErrorCode.ROUTE_PLANNER_DISABLED)
    expect(plannerErrorMessage(refused, i18n.t, 'club')).toContain('cette équipe')
    expect(plannerErrorMessage(refused, i18n.t)).toContain('sur ce site')
  })

  it('does not invite to retry a refusal of the team', async () => {
    const i18n = await createServerI18n('en')
    const message = plannerErrorMessage(fail(ErrorCode.FORBIDDEN, 403), i18n.t, 'club')
    expect(message).toContain('no longer')
    expect(message).not.toMatch(/try again/i)
  })
})
