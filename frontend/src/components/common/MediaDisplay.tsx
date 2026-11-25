import { memo } from 'react'
import { useTranslation } from 'react-i18next'
import { Stack, Paper, Group, Text, Anchor, Image } from '@mantine/core'
import { IconPaperclip, IconDownload } from '@tabler/icons-react'
import { MediaDto, AssetDto } from '@/api/dto'
import { MarkdownDisplay } from './MarkdownDisplay'
import { getImageSizeWidth } from '@/lib/assetMarkdown'
import { formatFileSize } from '@/utils/unitFormat'

export interface MediaDisplayProps {
  media: MediaDto
  /** The `sizes` of a full-width picture, where the text sits in a narrower column than the page's. */
  imageSizes?: string
  /** See MarkdownDisplay: 2 where the page's title is already an h2 under the team's h1. */
  headingOffset?: 0 | 1 | 2
}

export const MediaDisplay = memo(function MediaDisplay({
  media,
  imageSizes,
  headingOffset,
}: MediaDisplayProps) {
  const { t, i18n } = useTranslation()
  const attachments = media.assets.attachments
  const images = media.assets.images

  return (
    <Stack>
      <MarkdownDisplay
        markdown={media.markdown}
        preview={false}
        images={images}
        imageSizes={imageSizes}
        headingOffset={headingOffset}
      />

      {attachments.length > 0 && (
        <Paper withBorder p="sm" bg="var(--mantine-color-body)">
          <Group gap="xs" mb="xs">
            <IconPaperclip size={16} />
            <Text size="sm" fw={500}>
              {t('attachments.title')}
            </Text>
          </Group>
          <Stack gap="xs">
            {attachments.map((attachment: AssetDto) => {
              const thumbnailUrl = attachment.imageUrl?.replace(
                '{size}',
                String(getImageSizeWidth('thumbnail'))
              )
              return (
                <Anchor
                  key={attachment.id}
                  href={attachment.url}
                  target="_blank"
                  rel="noopener noreferrer"
                  size="sm"
                >
                  <Group gap="xs">
                    {thumbnailUrl ? (
                      <Image
                        src={thumbnailUrl}
                        alt={attachment.fileName}
                        w={getImageSizeWidth('thumbnail')}
                        h={getImageSizeWidth('thumbnail')}
                        fit="cover"
                        radius="sm"
                      />
                    ) : (
                      <IconPaperclip size={14} color="var(--mantine-color-dimmed)" />
                    )}
                    <Text truncate style={{ flex: 1 }}>
                      {attachment.fileName}
                    </Text>
                    {/* Unknown until the backfill reached it (docs/LEDGER_*.md API-7): then nothing. */}
                    {attachment.size != null && (
                      <Text size="xs" c="dimmed" style={{ whiteSpace: 'nowrap' }}>
                        {formatFileSize(attachment.size, i18n.resolvedLanguage ?? i18n.language)}
                      </Text>
                    )}
                    <IconDownload size={14} />
                  </Group>
                </Anchor>
              )
            })}
          </Stack>
        </Paper>
      )}
    </Stack>
  )
})
