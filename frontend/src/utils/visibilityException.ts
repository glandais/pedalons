import type { Visibility } from '@/api/dto'

/**
 * Whether a card says the visibility of a content: only when it is an exception, that is when it
 * differs from the visibility of its team (docs/LEDGER_*.md WEB-167, R1; KIT §9 « Badges d'état »).
 * A private team's content read « Équipe uniquement » on every card, a public team's « Public »:
 * neither told the reader anything. A private team's ride readable by link (`PUBLIC`), or a public
 * team's ride kept to its members (`TEAM`), still does.
 *
 * The one place the rule lives on the site; the app's is the same comparison — content visibility
 * against `team.visibility` of the same payload, nothing else.
 */
export function visibilityIsException(
  visibility: Visibility | undefined,
  team: { visibility: Visibility } | undefined
): boolean {
  if (!visibility || !team) return false
  return visibility !== team.visibility
}
