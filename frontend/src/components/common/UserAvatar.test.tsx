import { afterEach, describe, expect, it } from 'vitest'
import { cleanup, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import type { UserDto } from '@/api/dto'
import { useAuthStore } from '@/store/authStore'
import { avatarAccent } from '@/lib/avatarTint'
import { UserAvatarGroup } from './UserAvatar'

const people = ['Léa Martin', 'Karim Benali', 'Camille Durand', 'Noé Perrin'].map(
  (displayName, i) => ({ id: `u${i}`, displayName })
)

function renderGroup(props: Partial<Parameters<typeof UserAvatarGroup>[0]> = {}) {
  return render(
    <MantineProvider>
      <UserAvatarGroup users={people} {...props} />
    </MantineProvider>
  )
}

const background = (initials: string) => screen.getByText(initials).getAttribute('style') ?? ''
/** jsdom writes a hex colour back as `rgb(…)`. */
const rgb = (hex: string) => {
  const [r, g, b] = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16))
  return `rgb(${r}, ${g}, ${b})`
}

// R5 (docs/LEDGER_*.md WEB-167): one colour per person, the reader in the primary colour.
describe('UserAvatarGroup', () => {
  afterEach(() => {
    cleanup()
    useAuthStore.setState({ user: null })
  })

  it('draws each person in their own colour, the app’s', () => {
    renderGroup()
    expect(background('LM')).toContain(`background: ${rgb(avatarAccent('Léa Martin'))}`)
    expect(background('NP')).toContain(`background: ${rgb(avatarAccent('Noé Perrin'))}`)
    expect(avatarAccent('Léa Martin')).not.toBe(avatarAccent('Noé Perrin'))
  })

  it('draws the reader in the primary colour', () => {
    useAuthStore.setState({ user: { id: 'u2', displayName: 'Camille Durand' } as UserDto })
    renderGroup()
    expect(background('CD')).toContain('var(--mantine-primary-color-filled)')
    expect(background('KB')).not.toContain('primary')
  })

  it('leaves out the person a line already names, from the faces and from « +N »', () => {
    renderGroup({ excludeId: 'u0', total: 9, max: 2 })
    expect(screen.queryByText('LM')).toBeNull()
    expect(screen.getByText('KB')).toBeTruthy()
    // Nine people, the leader out: two faces and « +6 ».
    expect(screen.getByText('+6')).toBeTruthy()
  })

  it('overlaps by 4 px only, so that both initials stay readable', () => {
    renderGroup()
    expect(screen.getByTestId('avatar-cluster').getAttribute('style')).toContain(
      '--ag-spacing: calc(0.25rem * var(--mantine-scale))'
    )
  })
})
