import { useState, useMemo, useRef, useLayoutEffect } from 'react'
import { useTranslation } from 'react-i18next'
import { Group, Text, Box, Center, Image, Loader } from '@mantine/core'
import { IconPhoto } from '@tabler/icons-react'
import type { AssetDto } from '@/api/dto'
import {
  getImageSizeStyle,
  getImageSizeWidth,
  resolveAssetImageUrl,
  type ImageSize,
  DEFAULT_IMAGE_SIZE,
} from '../../lib/assetMarkdown'
import { densitySrcSet, widthSrcSet } from '@/lib/imageSrcSet'

/** A `full` picture spans the text column, at most a `Container size="md"` (960 px). */
const FULL_SIZES = '(min-width: 60em) 960px, 100vw'
const FULL_WIDTHS = [640, 1280, 1920] as const

export interface AssetImageProps {
  assetId: string
  images: AssetDto[]
  size?: ImageSize
  altText?: string
}

export function AssetImage({
  assetId,
  images,
  size = DEFAULT_IMAGE_SIZE,
  altText = '',
}: AssetImageProps) {
  const { t } = useTranslation()
  const [isLoading, setIsLoading] = useState(true)
  const [hasError, setHasError] = useState(false)
  const imgRef = useRef<HTMLImageElement>(null)

  const url = useMemo(() => resolveAssetImageUrl(assetId, images, size), [assetId, images, size])
  const asset = useMemo(() => images.find((img) => img.id === assetId), [assetId, images])

  const sizeStyle = getImageSizeStyle(size)
  const targetWidth = getImageSizeWidth(size)

  // With the asset's dimensions known, the frame is sized before the picture arrives — no text
  // jumping below it once it loads. Without them (a file the backfill has not reached), the
  // loader stands in, as it always did.
  const dims = asset?.imageDimensions
  const ratio = dims?.width && dims?.height ? `${dims.width} / ${dims.height}` : undefined
  const width =
    sizeStyle.w ?? (ratio && dims?.width ? Math.min(dims.width, targetWidth) : undefined)
  // That width is already capped at the size's own: only the column may narrow it further.
  const maxWidth = width !== undefined && sizeStyle.w === undefined ? '100%' : sizeStyle.maw
  const template = asset?.imageUrl
  const srcSet = template
    ? size === 'full'
      ? widthSrcSet(template, FULL_WIDTHS)
      : densitySrcSet(template, targetWidth)
    : undefined

  // SSR renders the <img> already pointing at its final src, so the browser can finish loading it
  // before React hydrates and attaches onLoad — the native load event fires and is missed, leaving
  // the loader stuck forever. Catch that case on mount by checking the already-loaded image.
  useLayoutEffect(() => {
    if (imgRef.current?.complete) {
      setIsLoading(false)
    }
  }, [url])

  // Missing image (asset not found in images array)
  if (!url) {
    return (
      <Group
        gap="xs"
        p="xs"
        bg="var(--mantine-color-default-hover)"
        style={{ borderRadius: 'var(--mantine-radius-sm)', display: 'inline-flex' }}
      >
        <IconPhoto size={16} color="var(--mantine-color-dimmed)" />
        <Text size="sm" c="dimmed">
          {altText || t('images.notFound')}
        </Text>
      </Group>
    )
  }

  // Error loading image
  if (hasError) {
    return (
      <Group
        gap="xs"
        p="xs"
        bg="var(--mantine-color-red-light)"
        style={{ borderRadius: 'var(--mantine-radius-sm)', display: 'inline-flex' }}
      >
        <IconPhoto size={16} color="var(--mantine-color-red-filled)" />
        <Text size="sm" c="red">
          {t('error.loading')}
        </Text>
      </Group>
    )
  }

  return (
    <Box display="inline-block">
      {isLoading && !ratio && (
        <Center
          p="md"
          bg="var(--mantine-color-default-hover)"
          style={{ borderRadius: 'var(--mantine-radius-md)' }}
        >
          <Loader size="sm" />
        </Center>
      )}
      <Image
        ref={imgRef}
        src={url}
        srcSet={srcSet}
        sizes={size === 'full' ? FULL_SIZES : undefined}
        alt={altText}
        w={width}
        h={sizeStyle.h}
        maw={maxWidth}
        fit={sizeStyle.fit}
        radius="md"
        loading="lazy"
        style={{
          display: isLoading && !ratio ? 'none' : 'block',
          aspectRatio: ratio,
          backgroundColor: isLoading ? 'var(--mantine-color-default-hover)' : undefined,
        }}
        onLoad={() => setIsLoading(false)}
        onError={() => {
          setIsLoading(false)
          setHasError(true)
        }}
      />
    </Box>
  )
}
