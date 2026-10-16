import { Image, Box } from '@mantine/core'
import { IconRoute } from '@tabler/icons-react'
import { useTranslation } from 'react-i18next'
import { useResolvedColorScheme } from '@/hooks/useResolvedColorScheme'

interface RouteThumbnailProps {
  thumbnailLightUrl?: string
  thumbnailDarkUrl?: string
  /** `RouteDto.thumbnailUrl` — light-else-dark, used when no themed variant is available. */
  fallbackUrl?: string
  size?: 'xs' | 'sm' | 'md' | 'lg'
}

const sizes = {
  xs: 56,
  sm: 80,
  md: 120,
  lg: 160,
}

export function RouteThumbnail({
  thumbnailLightUrl,
  thumbnailDarkUrl,
  fallbackUrl,
  size = 'sm',
}: RouteThumbnailProps) {
  const { t } = useTranslation()
  const colorScheme = useResolvedColorScheme()

  // Pick the right thumbnail based on color scheme, with fallback to legacy
  const selectedUrl = (colorScheme === 'dark' ? thumbnailDarkUrl : thumbnailLightUrl) ?? fallbackUrl

  if (!selectedUrl) {
    return null
  }

  const pixelSize = sizes[size]
  // Request 2x size for high-DPI displays
  const requestSize = pixelSize * 2
  const imageUrl = selectedUrl.replace('{size}', String(requestSize))

  return (
    <Box
      style={{
        width: pixelSize,
        height: pixelSize,
        borderRadius: 'var(--mantine-radius-md)',
        overflow: 'hidden',
        flexShrink: 0,
        border: '1px solid var(--mantine-color-default-border)',
      }}
    >
      <Image
        src={imageUrl}
        alt={t('routes.thumbnail.alt')}
        w={pixelSize}
        h={pixelSize}
        fit="cover"
        loading="lazy"
        fallbackSrc={undefined}
      />
    </Box>
  )
}

// Placeholder component for when route data is being loaded
export function RouteThumbnailPlaceholder({ size = 'sm' }: { size?: 'xs' | 'sm' | 'md' | 'lg' }) {
  const pixelSize = sizes[size]

  return (
    <Box
      style={{
        width: pixelSize,
        height: pixelSize,
        borderRadius: 'var(--mantine-radius-md)',
        backgroundColor: 'var(--mantine-color-default-hover)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        flexShrink: 0,
      }}
    >
      <IconRoute size={24} color="var(--mantine-color-dimmed)" />
    </Box>
  )
}
