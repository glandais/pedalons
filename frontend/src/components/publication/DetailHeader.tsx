import { useRef, useState, type ReactNode } from 'react'
import { Alert, Group, Paper, Stack, Text, Title, Tooltip } from '@mantine/core'
import { ShareButton } from '@/components/common/ShareButton'

interface DetailHeaderProps {
  /** Above everything: the siblings' picker of a group or a stage. */
  top?: ReactNode
  /** A small dimmed line over the title: the parent's name on a group or a stage. */
  context?: ReactNode
  /** Left of the title. */
  logo?: ReactNode
  /** The page's name: its single `h1`. */
  title: string
  /** After the title: status, « Vous participez », « Terminé ». */
  badges?: ReactNode
  /** Join, leave, or the page's main action. */
  primary?: ReactNode
  /** « GPS ». */
  gps?: ReactNode
  /** « Modifier », alone or as the split button. */
  edit?: ReactNode
  /** « Retoucher ». */
  retouch?: ReactNode
  /** Renders the share button, with this title. */
  shareTitle?: string
  /** The `⋯` menu (report, block). */
  more?: ReactNode
  /** Why the last action failed, under the title. */
  error?: string | null
  /** Under the title row: the departure, the facts, the tags. */
  children?: ReactNode
}

/**
 * The one header of every detail page (docs/LEDGER_*.md WEB-206, docs/plans/2026-11-25-en-tetes-de-pages.md §1):
 *
 * 1. the title is the page's single `h1`, wrapping on two lines then ending with an ellipsis, with
 *    its full text in a tooltip when (and only when) it is cut;
 * 2. the actions sit on the right, in one fixed order that belongs to this component, never to the
 *    page: primary, GPS, edit, retouch, share, `⋯`;
 * 3. a page gives each action by name; an absent one leaves no hole;
 * 4. on a phone the actions wrap under the title instead of squeezing it.
 */
export function DetailHeader({
  top,
  context,
  logo,
  title,
  badges,
  primary,
  gps,
  edit,
  retouch,
  shareTitle,
  more,
  error,
  children,
}: DetailHeaderProps) {
  const titleRef = useRef<HTMLHeadingElement>(null)
  const [clamped, setClamped] = useState(false)
  // Measured when the pointer or the focus arrives: jsdom has no layout, so tests never see a tooltip.
  const measure = () => {
    const el = titleRef.current
    setClamped(!!el && el.scrollHeight > el.clientHeight)
  }

  const hasActions = !!(primary || gps || edit || retouch || shareTitle || more)

  return (
    <Paper shadow="xs" p="lg" mb="lg" withBorder component="header">
      <Stack gap="md">
        {top}

        <Group justify="space-between" align="flex-start" wrap="wrap">
          <Stack gap={4} style={{ minWidth: 0, flex: '1 1 18rem' }}>
            {context && (
              <Text size="sm" c="dimmed">
                {context}
              </Text>
            )}
            <Group gap="sm" wrap="nowrap" align="flex-start">
              {logo}
              <Group gap="sm" wrap="wrap" style={{ minWidth: 0 }}>
                <Tooltip
                  label={title}
                  multiline
                  w={320}
                  disabled={!clamped}
                  events={{ hover: true, focus: true, touch: true }}
                >
                  <Title
                    order={1}
                    size="h2"
                    ref={titleRef}
                    lineClamp={2}
                    style={{ overflowWrap: 'anywhere' }}
                    onMouseEnter={measure}
                    onFocus={measure}
                    onTouchStart={measure}
                  >
                    {title}
                  </Title>
                </Tooltip>
                {badges}
              </Group>
            </Group>
          </Stack>

          {hasActions && (
            <Group gap="xs" wrap="wrap" data-testid="detail-header-actions">
              {primary}
              {gps}
              {edit}
              {retouch}
              {shareTitle && <ShareButton title={shareTitle} />}
              {more}
            </Group>
          )}
        </Group>

        {error && (
          <Alert color="red" variant="light">
            {error}
          </Alert>
        )}

        {children}
      </Stack>
    </Paper>
  )
}
