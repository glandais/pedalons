import { describe, expect, it } from 'vitest'
import { createServerI18n } from '@/i18n'
import { groupTitle } from './groupTitle'

// Decision of 2026-11-12 (KIT §9), the app's group_title.dart rule.
describe('groupTitle', () => {
  it('prefixes a name of one or two characters', async () => {
    const { t } = await createServerI18n('fr')
    expect(groupTitle('B', t)).toBe('Groupe B')
    expect(groupTitle(' 12 ', t)).toBe('Groupe 12')
    expect(groupTitle('É1', t)).toBe('Groupe É1')
    const en = await createServerI18n('en')
    expect(groupTitle('B', en.t)).toBe('Group B')
  })

  it('shows any other name as it is', async () => {
    const { t } = await createServerI18n('fr')
    expect(groupTitle('Les Rapides', t)).toBe('Les Rapides')
    expect(groupTitle('Groupe 1', t)).toBe('Groupe 1')
    expect(groupTitle('Gr. A', t)).toBe('Gr. A')
    expect(groupTitle('ABC', t)).toBe('ABC')
    expect(groupTitle('  ', t)).toBe('')
  })
})
