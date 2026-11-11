import { useState, type ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { notifications } from '@mantine/notifications'
import { List, Stack, Text } from '@mantine/core'
import type { IncompatibleRouteDto, IncompatibleRouteUsageDto } from '@/api/dto'
import { ConfirmDialog } from '@/components/common/ConfirmDialog'
import { paths } from '@/config/paths'
import { incompatibleVisibilityOf } from './incompatibleVisibility'
import { visibilityLabelKey } from './visibilityLabels'
import { RefusalDialog } from './RefusalDialog'

/** What is being saved when its routes are in the way. */
export type AlignedKind = 'ride' | 'trip'

export interface VisibilityRefusalHandler {
  /**
   * Takes a failed call: an `INCOMPATIBLE_VISIBILITY` refusal opens the dialog and returns true,
   * anything else returns false and is the caller's (the generic toast already said it).
   */
  offer: (error: unknown, replay: (routes: IncompatibleRouteDto[]) => void) => boolean
  /** The dialog, to render once in the page. */
  dialog: ReactNode
}

/** No list to show (an older backend, a refusal of the other direction): its message alone. */
function showBareRefusal(message: string) {
  notifications.show({ message, color: 'red' })
}

/**
 * Decision D5 (docs/LEDGER_*.md WEB-166): a ride or a trip saved outside the team with routes that
 * are still « Équipe » is refused with the list; this asks whether to raise them, then replays the
 * same request with `alignVisibility = true`, which raises them in the same transaction.
 *
 * The replay is handed the routes it raises, for the caller to refresh them once saved.
 * `isPending` is the mutation's, so the dialog shows the replay's progress.
 */
export function useVisibilityAlignment(
  kind: AlignedKind,
  isPending = false
): VisibilityRefusalHandler {
  const { t } = useTranslation()
  const [pending, setPending] = useState<{
    routes: IncompatibleRouteDto[]
    replay: (routes: IncompatibleRouteDto[]) => void
  } | null>(null)

  const offer = (error: unknown, replay: (routes: IncompatibleRouteDto[]) => void) => {
    const details = incompatibleVisibilityOf(error)
    if (!details) return false
    if (details.routes.length === 0) {
      showBareRefusal(t('errors.api.INCOMPATIBLE_VISIBILITY'))
      return true
    }
    setPending({ routes: details.routes, replay })
    return true
  }

  const dialog = (
    <ConfirmDialog
      isOpen={!!pending}
      onClose={() => setPending(null)}
      onConfirm={() => {
        if (!pending) return
        setPending(null)
        pending.replay(pending.routes)
      }}
      title={t('visibility.align.title')}
      message={
        <Stack gap="sm" data-testid="visibility-align-dialog">
          <Text size="sm">
            {kind === 'ride'
              ? t('visibility.align.message.ride')
              : t('visibility.align.message.trip')}
          </Text>
          <List size="sm" spacing={4}>
            {(pending?.routes ?? []).map((route) => (
              <List.Item key={route.slug} data-testid="visibility-align-route">
                {t('visibility.align.route', {
                  name: route.name,
                  from: t(visibilityLabelKey(route.visibility)),
                  to: t(visibilityLabelKey(route.proposedVisibility)),
                })}
              </List.Item>
            ))}
          </List>
        </Stack>
      }
      confirmText={t('visibility.align.confirm')}
      variant="info"
      isLoading={isPending}
    />
  )

  return { offer, dialog }
}

/**
 * Restoring a deleted ride or trip whose routes went « Équipe » meanwhile is refused with the list
 * (plan §4.4): no request body to carry `alignVisibility`, so the routes are opened first. Lists
 * them, each linked to its page.
 */
export function useRestoreRefusal(teamSlug: string, kind: AlignedKind): VisibilityRefusalHandler {
  const { t } = useTranslation()
  const [routes, setRoutes] = useState<IncompatibleRouteDto[] | null>(null)

  const offer = (error: unknown) => {
    const details = incompatibleVisibilityOf(error)
    if (!details) return false
    if (details.routes.length === 0) {
      showBareRefusal(t('errors.api.INCOMPATIBLE_VISIBILITY'))
      return true
    }
    setRoutes(details.routes)
    return true
  }

  const dialog = (
    <RefusalDialog
      opened={!!routes}
      onClose={() => setRoutes(null)}
      title={t('visibility.restoreBlocked.title')}
      message={
        kind === 'ride'
          ? t('visibility.restoreBlocked.message.ride')
          : t('visibility.restoreBlocked.message.trip')
      }
      links={(routes ?? []).map((route) => ({
        key: route.slug,
        label: route.name,
        to: paths.route(teamSlug, route.slug),
      }))}
      testId="visibility-restore-blocked"
    />
  )

  return { offer, dialog }
}

/** The page of a ride or a trip that uses a route. */
function usagePath(teamSlug: string, usage: IncompatibleRouteUsageDto): string {
  return usage.type === 'TRIP' ? paths.trip(teamSlug, usage.slug) : paths.ride(teamSlug, usage.slug)
}

/**
 * Decision D6: a route used by a ride or a trip visible outside the team cannot go « Équipe » —
 * refused with those usages, never closed with it. Lists them, each linked to its page; nothing to
 * align in this direction.
 */
export function useRouteUsagesRefusal(teamSlug: string): VisibilityRefusalHandler {
  const { t } = useTranslation()
  const [usages, setUsages] = useState<IncompatibleRouteUsageDto[] | null>(null)

  const offer = (error: unknown) => {
    const details = incompatibleVisibilityOf(error)
    if (!details) return false
    if (details.usages.length === 0) {
      showBareRefusal(t('errors.api.INCOMPATIBLE_VISIBILITY'))
      return true
    }
    setUsages(details.usages)
    return true
  }

  const dialog = (
    <RefusalDialog
      opened={!!usages}
      onClose={() => setUsages(null)}
      title={t('visibility.routeInUse.title')}
      message={t('visibility.routeInUse.message')}
      links={(usages ?? []).map((usage) => ({
        key: `${usage.type}-${usage.slug}`,
        label: t('visibility.routeInUse.usage', {
          name: usage.name,
          kind:
            usage.type === 'TRIP'
              ? t('visibility.routeInUse.trip')
              : t('visibility.routeInUse.ride'),
          visibility: t(visibilityLabelKey(usage.visibility)),
        }),
        to: usagePath(teamSlug, usage),
      }))}
      testId="visibility-route-in-use"
    />
  )

  return { offer, dialog }
}
