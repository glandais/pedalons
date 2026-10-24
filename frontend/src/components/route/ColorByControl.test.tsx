import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import { plain } from '@/test/weatherFixtures'

vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})

import { ColorByControl, type ColorByOption } from './ColorByControl'

function show(options: ColorByOption[], onChange = vi.fn()) {
  render(
    <MantineProvider>
      <ColorByControl value="grade" onChange={onChange} options={options} />
    </MantineProvider>
  )
  return onChange
}

describe('ColorByControl', () => {
  afterEach(cleanup)

  it('offers « Pente | Météo » without a surface (WEB-115)', () => {
    const onChange = show(['grade', 'wind'])
    const control = screen.getByRole('radiogroup', { name: /Colorer le tracé selon/ })
    expect(plain(control.textContent)).toBe('PenteMétéo')
    fireEvent.click(screen.getByLabelText('Météo'))
    expect(onChange).toHaveBeenCalledWith('wind')
  })

  it('draws nothing with a single mode', () => {
    show(['grade'])
    expect(screen.queryByRole('radiogroup')).toBeNull()
  })
})
