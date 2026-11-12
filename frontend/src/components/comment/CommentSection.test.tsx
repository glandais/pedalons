import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'

vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})
vi.mock('@/hooks/useAuth', () => ({ useAuth: () => ({ user: { id: 'me' } }) }))
vi.mock('./CommentItem', () => ({
  CommentItem: ({ comment }: { comment: { content: string } }) => <p>{comment.content}</p>,
}))
vi.mock('./CommentForm', () => ({ CommentForm: () => null }))

const state = vi.hoisted(() => ({
  options: undefined as unknown,
  fetchNextPage: () => {},
}))

vi.mock('@/hooks/useComments', async (importOriginal) => ({
  ...(await importOriginal<typeof import('@/hooks/useComments')>()),
  useComments: (_team: string, _type: string, _slug: string, options: unknown) => {
    state.options = options
    return {
      data: {
        pages: [
          {
            total: 25,
            items: [
              { id: '1', content: 'Le premier' },
              { id: '2', content: 'Le deuxième' },
            ],
          },
        ],
      },
      isLoading: false,
      hasNextPage: true,
      isFetchingNextPage: false,
      fetchNextPage: state.fetchNextPage,
    }
  },
  useCreateComment: () => ({ mutate: () => {}, isPending: false }),
  useDeleteComment: () => ({ mutate: () => {}, isPending: false }),
}))

import { CommentSection } from './CommentSection'

afterEach(cleanup)

describe('CommentSection (RL5, RL12)', () => {
  it('reads the oldest first, and offers « Afficher plus de commentaires »', () => {
    state.fetchNextPage = vi.fn()
    render(
      <MantineProvider>
        <CommentSection
          teamSlug="vc"
          teamName="VC"
          entityType="rides"
          entitySlug="mardi"
          isOrganizer={false}
        />
      </MantineProvider>
    )
    expect(state.options).toMatchObject({ sort: 'ASC' })
    const shown = screen.getAllByText(/^Le /).map((node) => node.textContent)
    expect(shown).toEqual(['Le premier', 'Le deuxième'])
    fireEvent.click(screen.getByRole('button', { name: 'Afficher plus de commentaires' }))
    expect(state.fetchNextPage).toHaveBeenCalled()
  })
})
