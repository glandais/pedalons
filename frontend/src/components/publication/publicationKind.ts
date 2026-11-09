import type { TranslationKey } from '@/lib/i18nUtils'

/**
 * The two kinds of dated publication whose detail pages share one layout (docs/LEDGER_*.md
 * WEB-155): a ride with its groups, a trip with its stages.
 */
export type PublicationKind = 'ride' | 'trip'

/** What a shared component says differently for a ride and for a trip. */
interface KindLabels {
  finished: TranslationKey
  scheduledPublish: TranslationKey
  published: TranslationKey
  unpublished: TranslationKey
  cancelled: TranslationKey
  uncancelled: TranslationKey
  deleted: TranslationKey
  restored: TranslationKey
  cancelAction: TranslationKey
  uncancelAction: TranslationKey
  confirmUnpublish: TranslationKey
  confirmCancel: TranslationKey
  confirmUncancel: TranslationKey
  confirmDelete: TranslationKey
  nonMemberMessage: TranslationKey
  nonMemberViewTeam: TranslationKey
  notAuthenticatedMessage: TranslationKey
  notAuthenticatedSignIn: TranslationKey
}

/**
 * A typed table rather than a key built from the kind: only some keys exist under both prefixes,
 * and a built key would let i18next-cli scaffold the missing ones (frontend/CLAUDE.md, WEB-84).
 */
export const KIND_LABELS: Record<PublicationKind, KindLabels> = {
  ride: {
    finished: 'rides.detail.finished',
    scheduledPublish: 'rides.detail.scheduledPublish',
    published: 'rides.notifications.published',
    unpublished: 'rides.notifications.unpublished',
    cancelled: 'rides.notifications.cancelled',
    uncancelled: 'rides.notifications.uncancelled',
    deleted: 'rides.notifications.deleted',
    restored: 'rides.notifications.restored',
    cancelAction: 'rides.detail.actions.cancel',
    uncancelAction: 'rides.detail.actions.uncancel',
    confirmUnpublish: 'rides.detail.confirmations.unpublish',
    confirmCancel: 'rides.detail.confirmations.cancel',
    confirmUncancel: 'rides.detail.confirmations.uncancel',
    confirmDelete: 'rides.detail.confirmations.delete',
    nonMemberMessage: 'rides.detail.nonMember.message',
    nonMemberViewTeam: 'rides.detail.nonMember.viewTeam',
    notAuthenticatedMessage: 'rides.detail.notAuthenticated.message',
    notAuthenticatedSignIn: 'rides.detail.notAuthenticated.signIn',
  },
  trip: {
    finished: 'trips.detail.finished',
    scheduledPublish: 'trips.detail.scheduledPublish',
    published: 'trips.notifications.published',
    unpublished: 'trips.notifications.unpublished',
    cancelled: 'trips.notifications.cancelled',
    uncancelled: 'trips.notifications.uncancelled',
    deleted: 'trips.notifications.deleted',
    restored: 'trips.notifications.restored',
    cancelAction: 'trips.detail.actions.cancel',
    uncancelAction: 'trips.detail.actions.uncancel',
    confirmUnpublish: 'trips.detail.confirmations.unpublish',
    confirmCancel: 'trips.detail.confirmations.cancel',
    confirmUncancel: 'trips.detail.confirmations.uncancel',
    confirmDelete: 'trips.detail.confirmations.delete',
    nonMemberMessage: 'trips.detail.nonMember.message',
    nonMemberViewTeam: 'trips.detail.nonMember.viewTeam',
    notAuthenticatedMessage: 'trips.detail.notAuthenticated.message',
    notAuthenticatedSignIn: 'trips.detail.notAuthenticated.signIn',
  },
}
