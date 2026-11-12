import type { MediaDto } from '@/api/dto'

/** What opens a ride's or a trip's card: its photo, its route's map, or the type's gradient. */
export type CardBanner =
  { kind: 'photo'; url: string } | { kind: 'map'; url: string } | { kind: 'gradient' }

interface BannerSource {
  media: MediaDto
  thumbnailLightUrl?: string
  thumbnailDarkUrl?: string
  /** Light-else-dark, for a payload without themed variants. */
  thumbnailUrl?: string
}

/**
 * The header of a ride's or a trip's card (docs/LEDGER_*.md WEB-167, R10; KIT §9 « Image
 * d'en-tête »): the content's first photo when it has one — a list row carries it even in COMPACT
 * (`media.assets.images`, one at most) —, else the map of its route in the reader's scheme, else
 * the type's gradient. The card shows the route's 160 px thumbnail only beside a photo: under a map
 * banner it would say the same thing twice.
 */
export function cardBanner(source: BannerSource, colorScheme: 'light' | 'dark'): CardBanner {
  const photo = source.media.assets.images?.[0]?.imageUrl
  if (photo) return { kind: 'photo', url: photo }
  const map =
    (colorScheme === 'dark' ? source.thumbnailDarkUrl : source.thumbnailLightUrl) ??
    source.thumbnailLightUrl ??
    source.thumbnailDarkUrl ??
    source.thumbnailUrl
  return map ? { kind: 'map', url: map } : { kind: 'gradient' }
}
