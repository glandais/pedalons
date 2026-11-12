import { describe, expect, it } from 'vitest'
import { createServerI18n } from '@/i18n'
import { groupTitle } from './groupTitle'

describe('groupTitle (WEB-167, R11)', () => {
  it('prefixes a bare name, and leaves one already titled as it is', async () => {
    const { t } = await createServerI18n('fr')
    expect(groupTitle('B', t)).toBe('Groupe B')
    expect(groupTitle('Groupe 1', t)).toBe('Groupe 1')
    expect(groupTitle('groupe', t)).toBe('groupe')
    expect(groupTitle('Groupies', t)).toBe('Groupe Groupies')
    const en = await createServerI18n('en')
    expect(groupTitle('B', en.t)).toBe(en.t('rides.group.title', { name: 'B' }))
  })
})
