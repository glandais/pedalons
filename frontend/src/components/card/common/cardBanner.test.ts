import { describe, expect, it } from 'vitest'
import { cardBanner } from './cardBanner'

const media = (images: { imageUrl?: string }[] = []) =>
  ({ markdown: '', assets: { images, attachments: [] } }) as never

// docs/LEDGER_*.md WEB-167, R10: photo, else the route's map in the reader's scheme, else gradient.
describe('cardBanner', () => {
  const maps = { thumbnailLightUrl: 'light', thumbnailDarkUrl: 'dark' }

  it('takes the first photo first', () => {
    expect(cardBanner({ media: media([{ imageUrl: 'photo' }]), ...maps }, 'light')).toEqual({
      kind: 'photo',
      url: 'photo',
    })
  })

  it('then the map of the reader’s scheme, else the other one', () => {
    expect(cardBanner({ media: media(), ...maps }, 'dark')).toEqual({ kind: 'map', url: 'dark' })
    expect(cardBanner({ media: media(), ...maps }, 'light')).toEqual({ kind: 'map', url: 'light' })
    expect(cardBanner({ media: media(), thumbnailLightUrl: 'light' }, 'dark')).toEqual({
      kind: 'map',
      url: 'light',
    })
  })

  it('else the gradient', () => {
    expect(cardBanner({ media: media() }, 'light')).toEqual({ kind: 'gradient' })
  })
})
