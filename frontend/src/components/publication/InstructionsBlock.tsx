import { useTranslation } from 'react-i18next'
import { Paper } from '@mantine/core'
import type { MediaDto } from '@/api/dto'
import { MediaDisplay } from '@/components/common/MediaDisplay'

/** The side column is at most 440 px on md+ (`.detail-layout`): no 960 px picture. */
const INSTRUCTIONS_IMAGE_SIZES = '(min-width: 64em) 440px, 100vw'

/**
 * Whether the « Consignes » block would draw anything: a text or an attachment. Images do not count
 * on their own — MediaDisplay only draws those the text references.
 */
function hasMediaContent(media: MediaDto): boolean {
  return media.markdown.trim() !== '' || media.assets.attachments.length > 0
}

/**
 * What the organiser wrote — a ride's, a trip's or a stage's — in a block of its own at the head of
 * the side column, never in the header (docs/LEDGER_*.md WEB-134, WEB-155), and only when there is
 * something to read. No title: the text speaks for itself.
 */
export function InstructionsBlock({ media, testId }: { media: MediaDto; testId?: string }) {
  const { t } = useTranslation()
  if (!hasMediaContent(media)) return null
  return (
    <Paper
      withBorder
      p="lg"
      component="section"
      aria-label={t('rides.detail.instructions.title')}
      data-testid={testId}
    >
      <MediaDisplay media={media} imageSizes={INSTRUCTIONS_IMAGE_SIZES} />
    </Paper>
  )
}
