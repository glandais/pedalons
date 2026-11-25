import { describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import { MarkdownDisplay } from './MarkdownDisplay'

vi.mock('./AssetImage', () => ({ AssetImage: () => null }))

const MD = '# Un\n\n## Deux\n\n### Trois\n\n#### Quatre\n\n###### Six'

function renderMd(props: Partial<React.ComponentProps<typeof MarkdownDisplay>> = {}) {
  return render(
    <MantineProvider>
      <MarkdownDisplay markdown={MD} {...props} />
    </MantineProvider>
  )
}

describe('MarkdownDisplay headings', () => {
  it('goes one level down by default, never reaching h1', () => {
    renderMd()
    expect(screen.getByRole('heading', { level: 2, name: 'Un' })).toBeTruthy()
    expect(screen.getByRole('heading', { level: 3, name: 'Deux' })).toBeTruthy()
    expect(screen.getByRole('heading', { level: 4, name: 'Trois' })).toBeTruthy()
    expect(screen.getByRole('heading', { level: 5, name: 'Quatre' })).toBeTruthy()
    expect(screen.getByRole('heading', { level: 6, name: 'Six' })).toBeTruthy()
    expect(screen.queryByRole('heading', { level: 1 })).toBeNull()
  })

  it('keeps the written levels with headingOffset 0', () => {
    renderMd({ headingOffset: 0 })
    expect(screen.getByRole('heading', { level: 1, name: 'Un' })).toBeTruthy()
    expect(screen.getByRole('heading', { level: 2, name: 'Deux' })).toBeTruthy()
  })

  it('renders no heading in preview', () => {
    renderMd({ preview: true })
    expect(screen.queryByRole('heading')).toBeNull()
  })
})
