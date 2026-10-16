import { Image, Box, Center } from '@mantine/core'
import { IconBike, IconArticle, IconRoute, IconUsersGroup, IconTag } from '@tabler/icons-react'
import type { MediaDto } from '@/api/dto'
import { FALLBACK_GRADIENTS } from '@/lib/badgeColors.generated'
import { CARD_GRID_SIZES, CARD_WIDTHS, sizedUrl, widthSrcSet } from '@/lib/imageSrcSet'

type CardType = keyof typeof FALLBACK_GRADIENTS

interface CardImageProps {
  media: MediaDto
  alt: string
  height?: number
  type?: CardType
  /**
   * Server-computed URL template of the picture a card header shows, `{size}` token included.
   * Present whatever the list `view`, so it is read before `media.assets`, which a compact row
   * does not carry.
   */
  thumbnailUrl?: string
  /** Rendered width, as a `sizes` attribute: a card of the lists' three-column grid by default. */
  sizes?: string
  /**
   * The likely largest picture of the first screen (LCP): loaded at once and fetched first rather
   * than lazily. Only for a card at the very top of a page.
   */
  priority?: boolean
}

const typeIcons: Record<CardType, typeof IconBike> = {
  RIDE: IconBike,
  POST: IconArticle,
  TRIP: IconRoute,
  TEAM: IconUsersGroup,
  AD: IconTag,
}

export function CardImage({
  media,
  alt,
  height = 160,
  type,
  thumbnailUrl,
  sizes = CARD_GRID_SIZES,
  priority = false,
}: CardImageProps) {
  const { assets } = media

  // Priority 1: the compact-safe thumbnail, else the first image from the asset inventory
  // (actual photos). Both are `{size}`-templated: `src` asks for ×2 the height for HiDPI, and the
  // `srcSet` lets the browser pick by the card's rendered width.
  const imageUrl = thumbnailUrl ?? assets.images?.[0]?.imageUrl
  if (imageUrl) {
    return (
      <Image
        src={sizedUrl(imageUrl, height * 2)}
        srcSet={widthSrcSet(imageUrl, CARD_WIDTHS)}
        sizes={sizes}
        alt={alt}
        h={height}
        fit="cover"
        loading={priority ? 'eager' : 'lazy'}
        fetchPriority={priority ? 'high' : undefined}
      />
    )
  }

  // Priority 2: Gradient background with type icon
  // Logos are shown inline with titles via EntityLogo, not as headers
  // Route thumbnails are shown via RouteThumbnail component
  if (type) {
    const Icon = typeIcons[type]
    const gradient = FALLBACK_GRADIENTS[type]

    return (
      <Box
        h={height}
        style={{
          background: gradient,
        }}
      >
        <Center h="100%">
          <Icon size={48} color="white" opacity={0.8} />
        </Center>
      </Box>
    )
  }

  // No fallback available - don't render anything
  return null
}
