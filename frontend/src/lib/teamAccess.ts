import type { TeamRole } from '@/api/dto'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'

/**
 * What the reader may do in a team, from their real role and their platform role.
 *
 * `team.role` is the reader's real membership, null for a non-member — a platform admin included
 * (docs/LEDGER_*.md API-137). The rights a platform admin holds everywhere (edit, delete, create,
 * administer, moderate) come from `/me`'s `platformRole`, combined here; what is personal
 * (joining, leaving, registering, the role badge, the member home's shortcuts) stays on `isMember`
 * and the raw `team.role`.
 */
export interface TeamAccess {
  /** A real member of the team, whatever the platform role. */
  isMember: boolean
  /** May act as an organizer: a team ORGANIZER or ADMIN, or a platform admin. */
  isOrganizer: boolean
  /** May act as an administrator: a team ADMIN, or a platform admin. */
  isAdmin: boolean
}

export function teamAccess(
  team: { role?: TeamRole | null } | null | undefined,
  isPlatformAdmin: boolean
): TeamAccess {
  const role = team?.role ?? null
  return {
    isMember: !!role,
    isOrganizer: isPlatformAdmin || role === 'ADMIN' || role === 'ORGANIZER',
    isAdmin: isPlatformAdmin || role === 'ADMIN',
  }
}

/** {@link teamAccess} for the signed-in reader. */
export function useTeamAccess(team: { role?: TeamRole | null } | null | undefined): TeamAccess {
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  return teamAccess(team, isPlatformAdmin)
}
