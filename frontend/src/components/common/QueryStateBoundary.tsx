import type { ReactNode } from 'react'
import { Alert, Box, Button, Center, Stack, Text, Title } from '@mantine/core'
import { IconLock, IconMoodEmpty, IconWifiOff, IconXboxX } from '@tabler/icons-react'
import { useTranslation } from 'react-i18next'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { apiErrorStatus, isNetworkError } from '@/lib/apiError'
import { EmptyState } from './EmptyState'

interface NotFoundConfig {
  title: string
  message?: string
  /** Where to go back to — e.g. the team feed. */
  backTo?: string
  backLabel?: string
}

/** What a refusal (403) says, and the way out it offers — « À propos de l'équipe ». */
export interface ForbiddenConfig {
  title: string
  message: string
  action?: ReactNode
}

interface QueryStateBoundaryProps {
  isLoading: boolean
  isError?: boolean
  error?: unknown
  /** The query succeeded but returned nothing — rendered as `notFound` too. */
  isNotFound?: boolean
  /** The query succeeded and returned an empty collection. */
  isEmpty?: boolean
  onRetry?: () => void
  skeleton?: ReactNode
  empty?: ReactNode
  notFound?: NotFoundConfig
  /** A 403: the reader may not see this. Without it, a generic « Contenu réservé ». */
  forbidden?: ForbiddenConfig
  /**
   * A list's previous answer stands in while the next one loads (`placeholderData`, after a filter
   * or a page change): it stays, dimmed, until the new one replaces it (RL11). Passing the prop —
   * `false` included — wraps the children in the box that dims, so the tree never changes shape.
   */
  isRefreshing?: boolean
  children: ReactNode
}

/**
 * A refusal: not a failure to retry — retrying earns the same answer — so no red and no « Réessayer »,
 * but a way out (docs/LEDGER_*.md WEB-175, RL11).
 */
export function AccessRefusedState({ title, message, action }: ForbiddenConfig) {
  return (
    <EmptyState
      icon={<IconLock size={48} />}
      title={title}
      description={message}
      actions={action}
    />
  )
}

/**
 * Discriminates the outcomes of a detail/list query: loading, *recoverable* error (5xx — offers a
 * retry), no connection (the network, not the server — offers a retry too), refusal (403 — not an
 * error), 404 (the resource genuinely does not exist), and empty. Before this component, pages
 * collapsed error and 404 into a single "introuvable", which lied on a 500.
 *
 * The single error form of every list of the site (docs/LEDGER_*.md WEB-175, RL11): a list that
 * renders it reads its query with `LIST_REQUEST` (`lib/listQuery.ts`), so no toast repeats it.
 */
export function QueryStateBoundary({
  isLoading,
  isError,
  error,
  isNotFound,
  isEmpty,
  onRetry,
  skeleton,
  empty,
  notFound,
  forbidden,
  isRefreshing,
  children,
}: QueryStateBoundaryProps) {
  const { t } = useTranslation()

  if (isLoading) {
    return <>{skeleton}</>
  }

  // An error wins over `isNotFound`: callers derive the latter from `!data`, which is also
  // true on a 500 — treating that as "not found" is exactly the lie this component exists
  // to stop. Only a genuine 404, or a successful-but-empty response, is "not found".
  const status = apiErrorStatus(error)
  const missing = isError ? status === 404 : isNotFound

  if (isError && status === 403) {
    return (
      <AccessRefusedState
        title={forbidden?.title ?? t('query.forbidden.title')}
        message={forbidden?.message ?? t('query.forbidden.message')}
        action={forbidden?.action}
      />
    )
  }

  if (isError && !missing) {
    const offline = isNetworkError(error)
    return (
      <Alert
        icon={offline ? <IconWifiOff size={16} /> : <IconXboxX size={16} />}
        title={offline ? t('query.offline.title') : t('query.error.title')}
        color="red"
      >
        <Text size="sm">{offline ? t('query.offline.message') : t('query.error.message')}</Text>
        {onRetry && (
          <Button variant="subtle" color="red" size="xs" mt="sm" onClick={onRetry}>
            {t('generic.retry')}
          </Button>
        )}
      </Alert>
    )
  }

  if (missing) {
    return (
      <Center py="xl">
        <Stack align="center" gap="md">
          <IconMoodEmpty size={48} color="var(--mantine-color-dimmed)" />
          <Title order={3} ta="center">
            {notFound?.title ?? t('query.notFound.title')}
          </Title>
          <Text c="dimmed" ta="center" maw={400}>
            {notFound?.message ?? t('query.notFound.message')}
          </Text>
          {notFound?.backTo && (
            <Button component={PrefetchLink} to={notFound.backTo} variant="light">
              {notFound.backLabel ?? t('errors.notFound.backHome')}
            </Button>
          )}
        </Stack>
      </Center>
    )
  }

  const content = isEmpty && empty ? empty : children

  if (isRefreshing === undefined) return <>{content}</>

  return (
    <Box
      aria-busy={isRefreshing}
      data-refreshing={isRefreshing || undefined}
      style={{
        opacity: isRefreshing ? 0.5 : 1,
        transition: 'opacity 150ms ease',
        pointerEvents: isRefreshing ? 'none' : undefined,
      }}
    >
      {content}
    </Box>
  )
}
