import * as zod from 'zod'

/**
 * Start again the HD recomputation of the routes and GPX-tool previews whose request used up its attempts (they stay on the fast profile, state FAST). Their attempts are reset and their due times spread one minute apart, oldest first, so the worker is not flooded; the targets go back to PENDING. Idempotent: a second call finds nothing. Run it with dryRun first.
 * @summary Retry abandoned HD elevation recomputations
 */
export const AdminRetryElevationRefreshQueryParams = zod.object({
  domainId: zod.string().optional().describe("Target domain ID (defaults to the request's domain)"),
})

export const adminRetryElevationRefreshBodyLimitMax = 1000

export const AdminRetryElevationRefreshBody = zod
  .object({
    dryRun: zod.boolean().describe('List what would be retried, without changing anything'),
    limit: zod
      .int()
      .min(1)
      .max(adminRetryElevationRefreshBodyLimitMax)
      .optional()
      .describe('Retry at most this many targets, oldest first (default 100)'),
    kind: zod
      .enum(['ROUTE', 'PREVIEW'])
      .optional()
      .describe('Only this kind of target (default: both)'),
  })
  .describe(
    'Which abandoned HD elevation recomputations to start again: the routes and GPX-tool previews whose request used up its attempts and stay on the fast profile.'
  )

export const AdminRetryElevationRefreshResponse = zod
  .object({
    dryRun: zod.boolean().describe('Whether this was a dry run (nothing changed)'),
    matched: zod.int().describe('Number of abandoned targets in the domain, before the limit'),
    items: zod
      .array(
        zod
          .object({
            kind: zod.enum(['ROUTE', 'PREVIEW']).describe('Kind of target'),
            targetId: zod.string().describe('ID of the route or preview'),
            teamSlug: zod.string().optional().describe('Team slug (routes)'),
            routeSlug: zod.string().optional().describe('Route slug (routes)'),
            previewPublicId: zod.string().optional().describe('Public identifier (previews)'),
            attempts: zod.int().describe('Failed attempts before the retry'),
            lastError: zod.string().optional().describe('Last error recorded, before the retry'),
            firstRequestedAt: zod.iso
              .datetime({ offset: true })
              .describe('When the recomputation was first requested'),
          })
          .describe('One abandoned recomputation')
      )
      .describe('Targets listed, and retried unless dry run; at most the limit'),
  })
  .describe('Outcome of an HD elevation retry, one entry per target')
