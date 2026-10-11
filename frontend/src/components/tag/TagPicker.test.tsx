import { describe, it, expect, vi, afterEach } from 'vitest'
import { render, screen, cleanup } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import type { TagWithUsageDto, TeamRole } from '@/api/dto'

// Keys, not wording.
vi.mock('react-i18next', () => ({
  useTranslation: () => ({ t: (key: string) => key }),
}))

const state: { tags: TagWithUsageDto[] | undefined; role: TeamRole | undefined } = {
  tags: undefined,
  role: undefined,
}

vi.mock('@/api/endpoints/tags/tags', () => ({
  useListTeamTags: () => ({ data: state.tags }),
}))
vi.mock('@/api/endpoints/teams/teams', () => ({
  useGetTeam: () => ({ data: { slug: 'team', role: state.role } }),
}))
vi.mock('@/components/common/PrefetchLink', () => ({
  PrefetchLink: ({ to, children, ...rest }: { to: string; children: React.ReactNode }) => (
    <a href={to} {...rest}>
      {children}
    </a>
  ),
}))
vi.mock('@/config/paths', () => ({
  paths: { teamAdminTags: (slug: string) => `/teams/${slug}/admin/tags` },
}))

import { TagPicker } from './TagPicker'

const tag = (id: string, label: string): TagWithUsageDto => ({
  id,
  label,
  color: 'BLUE',
  type: 'AD',
  usageCount: 0,
})

function renderPicker(value: string[] | undefined = undefined) {
  return render(
    <MantineProvider>
      <TagPicker teamSlug="team" type="AD" value={value} onChange={() => {}} />
    </MantineProvider>
  )
}

describe('TagPicker', () => {
  afterEach(() => {
    cleanup()
    state.tags = undefined
    state.role = undefined
  })

  it('renders nothing while the vocabulary loads', () => {
    renderPicker(['a'])
    expect(screen.queryByText(/tags\.picker/)).toBeNull()
    expect(screen.queryByRole('combobox')).toBeNull()
  })

  it('sends an admin to the admin screen when the kind has no tag', () => {
    state.tags = []
    state.role = 'ADMIN'
    renderPicker()
    expect(screen.getByText('tags.picker.emptyAdmin')).toBeTruthy()
    const link = screen.getByRole('link', { name: 'tags.picker.manageLink' })
    expect(link.getAttribute('href')).toBe('/teams/team/admin/tags')
  })

  it('only tells an editor who is not an admin that there is no tag — never offers to create one', () => {
    state.tags = []
    state.role = 'ORGANIZER'
    renderPicker()
    expect(screen.getByText('tags.picker.empty')).toBeTruthy()
    expect(screen.queryByRole('link')).toBeNull()
  })

  it('shows the content’s tags among the vocabulary, and drops an id it no longer has', () => {
    state.tags = [tag('a', 'Cadre'), tag('b', 'Roue')]
    const { container } = renderPicker(['b', 'gone'])
    // The picked values are the input's pills; the vocabulary's options live in its dropdown.
    const pills = [...container.querySelectorAll('.mantine-Pill-label')].map((p) => p.textContent)
    expect(pills).toEqual(['Roue'])
  })
})
