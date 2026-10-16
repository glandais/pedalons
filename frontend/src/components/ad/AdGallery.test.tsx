import { describe, it, expect, vi, afterEach } from 'vitest'
import { render, screen, cleanup } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'

vi.mock('react-i18next', () => ({
  useTranslation: () => ({ t: (key: string) => key }),
}))

import { AdGallery } from './AdGallery'

const images = ['/api/img/a/{size}', '/api/img/b/{size}']

describe('AdGallery', () => {
  afterEach(cleanup)

  it('fetches the main picture first, with width candidates', () => {
    render(
      <MantineProvider>
        <AdGallery images={images} name="Vélo" />
      </MantineProvider>
    )

    const [main, ...thumbs] = screen.getAllByRole('img', { name: 'Vélo' })
    expect(main.getAttribute('loading')).toBe('eager')
    expect(main.getAttribute('fetchpriority')).toBe('high')
    expect(main.getAttribute('srcset')).toContain('/api/img/a/960 960w')
    expect(main.getAttribute('sizes')).toBeTruthy()

    expect(thumbs).toHaveLength(2)
    for (const thumb of thumbs) {
      expect(thumb.getAttribute('loading')).toBe('lazy')
      expect(thumb.getAttribute('fetchpriority')).toBeNull()
    }
    expect(thumbs[1].getAttribute('srcset')).toBe('/api/img/b/72 1x, /api/img/b/144 2x')
  })
})
