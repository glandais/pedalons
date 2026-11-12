import { describe, expect, it } from 'vitest'
import {
  AVATAR_ACCENTS,
  avatarAccent,
  avatarBackground,
  avatarInitials,
  stableHash,
} from './avatarTint'

// docs/LEDGER_*.md WEB-167, R5: one colour per person, the same as in the app.
describe('avatarTint', () => {
  it('hashes a name as the app does (`PdlAvatar.stableHash`, values read from Dart)', () => {
    expect(stableHash('Léa Martin')).toBe(2049026135)
    expect(stableHash('Karim Benali')).toBe(310587795)
    expect(stableHash('Noé Perrin')).toBe(1863211762)
    expect(stableHash('Jeanne Colin')).toBe(2028330404)
  })

  it('picks the app’s accent for that hash, in the app’s order', () => {
    expect(AVATAR_ACCENTS).toHaveLength(12)
    expect(avatarAccent('Léa Martin')).toBe('#e8590c')
    expect(avatarAccent('Karim Benali')).toBe('#1971c2')
    expect(avatarAccent('Noé Perrin')).toBe('#2f9e44')
    expect(avatarAccent('Sacha Morel')).toBe('#6741d9')
    expect(avatarAccent('Jeanne Colin')).toBe('#c92a2a')
  })

  it('draws the reader in the primary colour, whatever their name', () => {
    expect(avatarBackground('Karim Benali', true)).toBe('var(--mantine-primary-color-filled)')
    expect(avatarBackground('Karim Benali')).toBe('#1971c2')
  })

  it('takes two initials from the first two words', () => {
    expect(avatarInitials('Léa Martin')).toBe('LM')
    expect(avatarInitials('Jean Pierre Dupont')).toBe('JP')
    expect(avatarInitials('élodie')).toBe('É')
    expect(avatarInitials('  ')).toBe('?')
  })
})
