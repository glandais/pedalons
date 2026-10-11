import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { ActionIcon, Box, Group, Image, Modal, Paper, UnstyledButton } from '@mantine/core'
import { IconChevronLeft, IconChevronRight } from '@tabler/icons-react'

/** Height of the main frame, and the thumbnail strip's edge. */
const MAIN_HEIGHT = 340
const THUMB_SIZE = 72

/** `{size}` templates ask for twice the rendered width, for HiDPI. */
const resolve = (template: string, width: number) => template.replace('{size}', String(width))

export interface AdGalleryProps {
  /** `AdDto.images` — URL templates in editor order, the first being the card's thumbnail. */
  images: string[]
  /** Ad name, used as the images' alternative text. */
  name: string
}

/**
 * The pictures of an ad: one large frame, a thumbnail strip, and a full-screen view on click.
 *
 * Fed by `AdDto.images` rather than `media.assets.images`, so it works identically on a list row
 * (where `media` is trimmed) and on the detail page. Renders nothing at all when the ad has no
 * picture — an empty frame would only claim there is something to look at.
 *
 * Composed from `Image` + `Group` on purpose: `@mantine/carousel` is not a dependency, and one
 * gallery is not a reason to add one.
 */
export function AdGallery({ images, name }: AdGalleryProps) {
  const { t } = useTranslation()
  const [index, setIndex] = useState(0)
  const [zoomed, setZoomed] = useState(false)

  if (images.length === 0) return null

  const current = images[Math.min(index, images.length - 1)]
  const step = (delta: number) => setIndex((i) => (i + delta + images.length) % images.length)

  return (
    <>
      <Paper withBorder p={0} mb="lg" style={{ overflow: 'hidden' }}>
        <Box pos="relative">
          <UnstyledButton
            onClick={() => setZoomed(true)}
            aria-label={t('ads.detail.openImage', { index: index + 1, total: images.length })}
            style={{ display: 'block', width: '100%' }}
          >
            <Image src={resolve(current, MAIN_HEIGHT * 2)} alt={name} h={MAIN_HEIGHT} fit="cover" />
          </UnstyledButton>

          {images.length > 1 && (
            <>
              <ActionIcon
                variant="default"
                size="lg"
                radius="xl"
                pos="absolute"
                top="50%"
                left={8}
                style={{ transform: 'translateY(-50%)' }}
                aria-label={t('ads.detail.previousImage')}
                onClick={() => step(-1)}
              >
                <IconChevronLeft size={18} />
              </ActionIcon>
              <ActionIcon
                variant="default"
                size="lg"
                radius="xl"
                pos="absolute"
                top="50%"
                right={8}
                style={{ transform: 'translateY(-50%)' }}
                aria-label={t('ads.detail.nextImage')}
                onClick={() => step(1)}
              >
                <IconChevronRight size={18} />
              </ActionIcon>
            </>
          )}
        </Box>

        {images.length > 1 && (
          <Group gap="xs" p="xs" wrap="nowrap" style={{ overflowX: 'auto' }}>
            {images.map((image, i) => (
              <UnstyledButton
                key={image}
                onClick={() => setIndex(i)}
                aria-label={t('ads.detail.openImage', { index: i + 1, total: images.length })}
                aria-current={i === index}
                style={{
                  flex: '0 0 auto',
                  borderRadius: 'var(--mantine-radius-sm)',
                  outline:
                    i === index ? '2px solid var(--mantine-primary-color-filled)' : undefined,
                  outlineOffset: 2,
                }}
              >
                <Image
                  src={resolve(image, THUMB_SIZE * 2)}
                  alt={name}
                  w={THUMB_SIZE}
                  h={THUMB_SIZE}
                  fit="cover"
                  radius="sm"
                />
              </UnstyledButton>
            ))}
          </Group>
        )}
      </Paper>

      <Modal
        opened={zoomed}
        onClose={() => setZoomed(false)}
        size="auto"
        centered
        padding="xs"
        title={t('ads.detail.gallery')}
      >
        <Image src={resolve(current, 1920)} alt={name} fit="contain" mah="80vh" />
      </Modal>
    </>
  )
}
