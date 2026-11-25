import type { ReactNode } from 'react'
import { Anchor, Center, Group, Paper, Stack, Text, Title, type TitleOrder } from '@mantine/core'
import { IconArrowLeft } from '@tabler/icons-react'
import { PrefetchLink } from './PrefetchLink'

/**
 * The single back link of a transactional card: a route (`to`) or a step of the same card
 * (`onClick`). Always last, centred, with the arrow (plan 2026-11-25-en-tetes-de-pages §3 lot 5,
 * ledger `WEB-209`).
 */
export type TransactionalBackLink =
  | { label: ReactNode; to: string; onClick?: never }
  | { label: ReactNode; onClick: () => void; to?: never }

export interface TransactionalCardContentProps {
  title: ReactNode
  /** `1` when the card is the page (every transactional page); `2` inside the visitor home hero. */
  titleOrder?: TitleOrder
  /** One sentence under the title. */
  description?: ReactNode
  /** A `ThemeIcon` or an icon above the title, for a result step (sent, done, failed). */
  icon?: ReactNode
  /** The body: a form, a summary, an alert. */
  children?: ReactNode
  /** Full-width buttons, stacked — give each `fullWidth`. */
  actions?: ReactNode
  back?: TransactionalBackLink
}

/**
 * Inside of a transactional card: icon, title (h2-sized, whatever its level), one sentence, the
 * content, the full-width actions, the back link last. Used bare where the card already exists
 * (`LoginForm` in the visitor hero), otherwise through `TransactionalCard`.
 */
export function TransactionalCardContent({
  title,
  titleOrder = 1,
  description,
  icon,
  children,
  actions,
  back,
}: TransactionalCardContentProps) {
  return (
    <Stack>
      <Stack gap="xs" align="center" ta="center">
        {icon}
        <Title order={titleOrder} size="h2">
          {title}
        </Title>
        {description && <Text c="dimmed">{description}</Text>}
      </Stack>
      {children}
      {actions && <Stack gap="sm">{actions}</Stack>}
      {back && <TransactionalBack back={back} />}
    </Stack>
  )
}

function TransactionalBack({ back }: { back: TransactionalBackLink }) {
  const label = (
    <Group gap={4} justify="center" wrap="nowrap" component="span">
      <IconArrowLeft size={14} aria-hidden />
      {back.label}
    </Group>
  )
  return (
    <Center>
      {back.to !== undefined ? (
        <Anchor component={PrefetchLink} to={back.to} size="sm">
          {label}
        </Anchor>
      ) : (
        <Anchor component="button" type="button" size="sm" onClick={back.onClick}>
          {label}
        </Anchor>
      )}
    </Center>
  )
}

export interface TransactionalCardShellProps {
  children: ReactNode
  'data-testid'?: string
}

/** The frame alone: centred at 70 vh, 440 px, 16 px radius, `lg` shadow. */
export function TransactionalCardShell({
  children,
  'data-testid': testId,
}: TransactionalCardShellProps) {
  return (
    <Center mih="70vh">
      <Paper shadow="lg" radius="lg" p="xl" w="100%" maw={440} data-testid={testId}>
        {children}
      </Paper>
    </Center>
  )
}

export interface TransactionalCardProps extends Omit<TransactionalCardContentProps, 'titleOrder'> {
  'data-testid'?: string
}

/**
 * The common card of the sign-in, password, e-mail verification, invitation, OAuth and device
 * pages: one h1, one sentence, full-width actions, one back link. The biketeam migration keeps its
 * own 640 px card.
 */
export function TransactionalCard({ 'data-testid': testId, ...content }: TransactionalCardProps) {
  return (
    <TransactionalCardShell data-testid={testId}>
      <TransactionalCardContent {...content} />
    </TransactionalCardShell>
  )
}
