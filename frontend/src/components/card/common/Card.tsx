import { PrefetchLink } from '@/components/common/PrefetchLink'
import { ReactNode } from 'react'
import { Paper, Title, Box, Text } from '@mantine/core'
import { MarkdownDisplay } from '../../common/MarkdownDisplay'
import { MediaDto } from '@/api/dto'
import classes from './Card.module.css'

interface CardProps {
  to: string
  children: ReactNode
  /**
   * A `⋯` menu (`CardActionsMenu`) pinned to the top-right corner. It is a sibling of the link,
   * not a child: a button inside an `<a>` is invalid HTML, and its clicks would open the card.
   */
  actions?: ReactNode
  /**
   * A row at the card's foot — the team card's « Rejoindre l'équipe ». Outside the link for the same
   * reason as `actions`: its clicks act, they do not open the card.
   */
  footer?: ReactNode
}

export function Card({ to, children, actions, footer }: CardProps) {
  const link = footer ? (
    <Paper withBorder radius="md" className={`${classes.card} ${classes.withFooter}`}>
      <PrefetchLink to={to} className={classes.footerLink}>
        {children}
      </PrefetchLink>
      <Box px="md" pb="md">
        {footer}
      </Box>
    </Paper>
  ) : (
    <Paper component={PrefetchLink} to={to} withBorder radius="md" className={classes.card}>
      {children}
    </Paper>
  )
  if (!actions) {
    return link
  }
  return (
    <Box className={classes.withActions}>
      {link}
      <Box className={classes.actions}>{actions}</Box>
    </Box>
  )
}

interface CardContentProps {
  children: ReactNode
}

export function CardContent({ children }: CardContentProps) {
  return (
    <Box p="md" style={{ flex: 1, display: 'flex', flexDirection: 'column' }}>
      {children}
    </Box>
  )
}

interface CardHeaderProps {
  children: ReactNode
}

export function CardHeader({ children }: CardHeaderProps) {
  return (
    <Box style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between' }}>
      {children}
    </Box>
  )
}

interface CardTitleProps {
  children: ReactNode
  truncate?: boolean
}

export function CardTitle({ children, truncate = false }: CardTitleProps) {
  return (
    <Title order={4} lineClamp={truncate ? 1 : undefined}>
      {children}
    </Title>
  )
}

interface CardDescriptionProps {
  media: MediaDto
  /**
   * Server-computed plain-text opening of the body. Present whatever the list `view`, so a card
   * reads it first and never has to carry `media.markdown` just to show two lines.
   */
  excerpt?: string
  markdown?: boolean
  maxLength?: number
}

export function CardDescription({
  media,
  excerpt,
  markdown = false,
  maxLength = 150,
}: CardDescriptionProps) {
  if (excerpt && excerpt.trim().length > 0) {
    return (
      <Text size="sm" c="dimmed" lineClamp={2}>
        {excerpt}
      </Text>
    )
  }

  // Fallback for payloads that carry no excerpt (older rows, or an entity whose excerpt is null
  // while the body still holds renderable content).
  if (markdown && media.markdown) {
    return <MarkdownDisplay markdown={media.markdown} preview={true} maxLength={maxLength} />
  }

  return null
}
