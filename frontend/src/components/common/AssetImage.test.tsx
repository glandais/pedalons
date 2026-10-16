import { describe, it, expect, vi, afterEach } from 'vitest'
import { render, screen, cleanup } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import type { AssetDto } from '@/api/dto'

vi.mock('react-i18next', () => ({
  useTranslation: () => ({ t: (key: string) => key }),
}))

import { AssetImage } from './AssetImage'

function asset(overrides: Partial<AssetDto>): AssetDto {
  return {
    id: 'a1',
    fileName: 'photo.jpg',
    contentType: 'image/jpeg',
    url: '/api/raw/a1',
    imageUrl: '/api/img/a1/{size}',
    ...overrides,
  } as AssetDto
}

function renderImage(images: AssetDto[], size?: 'medium' | 'full') {
  render(
    <MantineProvider>
      <AssetImage assetId="a1" images={images} size={size} altText="Photo" />
    </MantineProvider>
  )
  return screen.getByAltText('Photo')
}

describe('AssetImage', () => {
  afterEach(cleanup)

  it('reserves the frame from the dimensions before the picture loads', () => {
    const img = renderImage([asset({ imageDimensions: { width: 396, height: 600 } })])

    expect(img.style.aspectRatio).toBe('396 / 600')
    expect(img.style.display).toBe('block')
    expect(img.style.maxWidth).toBe('100%')
    expect(img.getAttribute('loading')).toBe('lazy')
    expect(img.getAttribute('srcset')).toBe('/api/img/a1/448 1x, /api/img/a1/896 2x')
    expect(screen.queryByRole('img', { name: 'Photo' })).not.toBeNull()
  })

  it('keeps the loader when the dimensions are unknown', () => {
    const img = renderImage([asset({})])

    expect(img.style.aspectRatio).toBe('')
    expect(img.style.display).toBe('none')
  })

  it('offers width candidates for a full-width picture', () => {
    const img = renderImage([asset({ imageDimensions: { width: 4000, height: 3000 } })], 'full')

    expect(img.getAttribute('srcset')).toContain('/api/img/a1/1920 1920w')
    expect(img.getAttribute('sizes')).toBeTruthy()
  })
})
