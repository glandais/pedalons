import * as zod from 'zod'

/**
 * The nightly pass, by hand: for each team (or the one given), compares the digest of its tracks with the one the engine holds and deposits it again when it differs, is absent, stale or about to expire (or always with force); deletes the overlay of a deleted team, or one whose planner is off. Idempotent. With dryRun the answer (200) lists what would be done; otherwise the pass runs in the background (202, started=false if one already runs on this instance). Run it with dryRun first; use force after a key rotation or a new graph.
 * @summary Prepare the teams' roads for the route generator now
 */
export const AdminRefreshRouteGeneratorOverlaysBody = zod
  .object({
    teamId: zod
      .string()
      .optional()
      .describe('Only this team (default: every team of every domain)'),
    force: zod
      .boolean()
      .describe(
        'Deposit every team again, whatever its overlay: after a key rotation or a new graph'
      ),
    dryRun: zod
      .boolean()
      .describe('Say what would be done, without depositing or deleting anything'),
  })
  .describe(
    'Which team overlays of the route generator to prepare now: the nightly pass, by hand. Without force, only the teams whose overlay is absent, stale, changed or about to expire.'
  )

export const AdminRefreshRouteGeneratorOverlaysResponse = zod
  .object({
    started: zod
      .boolean()
      .describe(
        'False when nothing started: the generator is off or unconfigured, or a pass is already running'
      ),
    graphId: zod.string().optional().describe('Identity of the graph the engine serves'),
    items: zod
      .array(
        zod
          .object({
            teamId: zod.string().describe('ID of the team'),
            teamSlug: zod.string().describe('Slug of the team'),
            action: zod.enum(['DEPOSIT', 'DELETE', 'KEEP']).describe('What is done'),
            reason: zod
              .enum([
                'ABSENT',
                'STALE',
                'CHANGED',
                'EXPIRING',
                'FORCED',
                'CURRENT',
                'TEAM_GONE',
                'PLANNER_OFF',
              ])
              .describe('Why'),
            state: zod
              .string()
              .optional()
              .describe('State of the overlay at the engine: absent, ready or stale'),
            depositedAt: zod.iso
              .datetime({ offset: true })
              .optional()
              .describe('When it was deposited'),
            expiresAt: zod.iso
              .datetime({ offset: true })
              .optional()
              .describe('When the engine drops it if it is not deposited again'),
          })
          .describe("One team's overlay")
      )
      .describe(
        'One entry per team that is deposited, deleted, or kept (dry run only: a started pass answers 202 with no entries, it runs in the background)'
      ),
  })
  .describe("What the pass over the teams' overlays did, or would do (dry run)")
