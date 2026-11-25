import { describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import { MarkdownDisplay } from './MarkdownDisplay'

vi.mock('./AssetImage', () => ({ AssetImage: () => null }))

function renderMd(
  markdown: string,
  props: Partial<React.ComponentProps<typeof MarkdownDisplay>> = {}
) {
  return render(
    <MantineProvider>
      <MarkdownDisplay markdown={markdown} {...props} />
    </MantineProvider>
  )
}

describe('MarkdownDisplay headings (WEB-207)', () => {
  it('puts the highest heading at h2 and keeps the distances, never reaching h1', () => {
    renderMd('# Un\n\n## Deux\n\n### Trois\n\n#### Quatre\n\n###### Six')
    expect(screen.getByRole('heading', { level: 2, name: 'Un' })).toBeTruthy()
    expect(screen.getByRole('heading', { level: 3, name: 'Deux' })).toBeTruthy()
    expect(screen.getByRole('heading', { level: 4, name: 'Trois' })).toBeTruthy()
    expect(screen.getByRole('heading', { level: 5, name: 'Quatre' })).toBeTruthy()
    expect(screen.getByRole('heading', { level: 6, name: 'Six' })).toBeTruthy()
    expect(screen.queryByRole('heading', { level: 1 })).toBeNull()
  })

  it('leaves no gap under the page title when the content starts at ##', () => {
    renderMd('## Programme\n\n### Matin')
    expect(screen.getByRole('heading', { level: 2, name: 'Programme' })).toBeTruthy()
    expect(screen.getByRole('heading', { level: 3, name: 'Matin' })).toBeTruthy()
  })

  it('keeps the size of the written level', () => {
    renderMd('## Programme\n\n### Matin')
    const programme = screen.getByRole('heading', { name: 'Programme' })
    expect(programme.style.getPropertyValue('--title-fz')).toContain('h2')
    const matin = screen.getByRole('heading', { name: 'Matin' })
    expect(matin.style.getPropertyValue('--title-fz')).toContain('h3')
  })

  it('starts at h3 under a section', () => {
    renderMd('# Un\n\n## Deux', { topHeadingLevel: 3 })
    expect(screen.getByRole('heading', { level: 3, name: 'Un' })).toBeTruthy()
    expect(screen.getByRole('heading', { level: 4, name: 'Deux' })).toBeTruthy()
  })

  it('ignores a # inside a code block', () => {
    renderMd('```\n# pas un titre\n```\n\n### Seul titre')
    expect(screen.getByRole('heading', { level: 2, name: 'Seul titre' })).toBeTruthy()
    expect(screen.getAllByRole('heading')).toHaveLength(1)
  })

  it('renders no heading in preview', () => {
    renderMd('# Un', { preview: true })
    expect(screen.queryByRole('heading')).toBeNull()
  })
})
