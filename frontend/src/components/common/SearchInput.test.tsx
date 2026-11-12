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

import { SearchInput } from './SearchInput'

afterEach(cleanup)

describe('SearchInput — the clear button (DL19)', () => {
  it('is named « Effacer la recherche » and empties the field', () => {
    const onChange = vi.fn()
    render(
      <MantineProvider>
        <SearchInput value="col" onChange={onChange} placeholder="Rechercher" />
      </MantineProvider>
    )
    fireEvent.click(screen.getByRole('button', { name: 'Effacer la recherche' }))
    expect(onChange).toHaveBeenCalledWith('')
  })
})
