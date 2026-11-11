import { Visibility } from '@/api/dto'
import type { ContentPermissionsDto, ContentVisibilitiesDto, TeamDetailDto } from '@/api/dto'

/** The label key of a visibility (« Équipe uniquement », « Non répertorié », « Public »). */
export function visibilityLabelKey(visibility: Visibility) {
  return `visibility.${visibility.toLowerCase() as Lowercase<Visibility>}` as const
}

/** A kind of content that carries a visibility of its own, as `ContentVisibilitiesDto` names it. */
export type VisibilityKind = Exclude<keyof ContentVisibilitiesDto, 'ad'>

/**
 * What an editor offers, as the backend computes it (docs/LEDGER_*.md WEB-166, decision D7): the
 * entity's own `permissions.allowedVisibilities` when editing one — it can be narrower than the
 * team's, a route used publicly losing `TEAM` — and the team's list for its kind otherwise
 * (creation, and the types whose edit DTO carries no list, the ride templates).
 */
export function allowedVisibilitiesFor(
  team: Pick<TeamDetailDto, 'allowedContentVisibilities'>,
  kind: VisibilityKind,
  permissions?: Pick<ContentPermissionsDto, 'allowedVisibilities'>
): Visibility[] {
  return permissions?.allowedVisibilities ?? team.allowedContentVisibilities[kind]
}
