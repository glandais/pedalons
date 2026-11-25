import { describe, expect, it } from 'vitest'
import { formatPageTitle, joinTitle } from './pageTitle'

describe('formatPageTitle', () => {
  it.each([
    [['Agenda', 'N Peloton', 'Pédalons'], 'Agenda · N Peloton — Pédalons'],
    [['N Peloton', 'N Peloton', 'Pédalons'], 'N Peloton — Pédalons'],
    [['Préférences', undefined, 'Pédalons'], 'Préférences — Pédalons'],
    [['Agenda', 'N Peloton', ''], 'Agenda · N Peloton'],
    [[undefined, undefined, 'Pédalons'], 'Pédalons'],
    [['', 'N Peloton', 'Pédalons'], 'N Peloton — Pédalons'],
    [['Pédalons', undefined, 'Pédalons'], 'Pédalons'],
    [['Agenda', 'Club X', 'Club X'], 'Agenda — Club X'],
    [[' Agenda ', ' N ', ' Pédalons '], 'Agenda · N — Pédalons'],
    [['Modifier · Sortie', 'N', 'P'], 'Modifier · Sortie · N — P'],
    [[undefined, undefined, undefined], ''],
  ] as const)('%j -> %s', ([label, context, site], expected) => {
    expect(formatPageTitle(label, context, site)).toBe(expected)
  })
})

describe('joinTitle', () => {
  it('drops empty parts and trims', () => {
    expect(joinTitle('Modifier', undefined, ' Sortie ')).toBe('Modifier · Sortie')
  })
  it('is empty without parts', () => {
    expect(joinTitle()).toBe('')
  })
})
