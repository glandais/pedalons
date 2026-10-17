import * as zod from 'zod'

/**
 * Joins the team the token names. Requires a session: accepting is consenting, and a consent attaches to an account — a public accept handing back a session would make the invitation link a login credential. Idempotent: replaying it, or accepting when already a member, returns the existing membership without changing its role, so an invitation as MEMBER never demotes an administrator.
 * @summary Accept an invitation
 */
export const acceptBodyTokenMax = 200

export const acceptBodyTokenRegExp = new RegExp('\\S')

export const AcceptBody = zod
  .object({
    token: zod
      .string()
      .max(acceptBodyTokenMax)
      .regex(acceptBodyTokenRegExp)
      .describe(
        'The token from the invitation e-mail. Sent in the body rather than in the path, because a bearer secret in a URL path ends up in access logs and in the Referer of anything the page loads.'
      ),
  })
  .describe('Redeem an invitation token')

export const AcceptResponse = zod
  .object({
    team: zod
      .object({
        id: zod.string().describe('Team ID (TSID)'),
        name: zod.string().describe('Team name'),
        slug: zod.string().describe('Team URL slug'),
        visibility: zod
          .enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC'])
          .describe('Whether the team is public'),
        logoUrl: zod
          .string()
          .optional()
          .describe(
            "URL template of the team's logo (with a {size} placeholder), when it has one. Same value as TeamDetailDto.logoUrl, so a publication can show its team's logo without loading the team. Opaque URL: may carry a query string; substitute {size} only."
          ),
      })
      .describe('Team'),
    id: zod.string().describe('Membership ID (TSID)'),
    user: zod
      .object({
        id: zod.string().describe('User ID (TSID)'),
        displayName: zod.string().describe('User display name'),
        avatarUrl: zod.string().optional().describe('User avatar URL'),
      })
      .describe('User'),
    role: zod
      .enum(['MEMBER', 'ORGANIZER', 'ADMIN'])
      .optional()
      .describe(
        'Member role. Null when the caller is not entitled to it: an organiser reading the roster of a team that has not opened its member directory gets the names and nothing else.'
      ),
    joinedAt: zod.iso
      .datetime({ offset: true })
      .optional()
      .describe('When the user joined the team'),
  })
  .describe('Team member information')

/**
 * What the invitation says, for whoever holds its token. Public, because an invitation opened in a signed-out browser has to be able to name the team and the person inviting — otherwise the page can only show a bare login form with no explanation of why. Nothing here goes beyond what the e-mail already said, and the invited address comes back masked.
 * @summary Read an invitation
 */
export const previewBodyTokenMax = 200

export const previewBodyTokenRegExp = new RegExp('\\S')

export const PreviewBody = zod
  .object({
    token: zod
      .string()
      .max(previewBodyTokenMax)
      .regex(previewBodyTokenRegExp)
      .describe(
        'The token from the invitation e-mail. Sent in the body rather than in the path, because a bearer secret in a URL path ends up in access logs and in the Referer of anything the page loads.'
      ),
  })
  .describe('Redeem an invitation token')

export const PreviewResponse = zod
  .object({
    teamName: zod.string().describe('Team name'),
    teamSlug: zod.string().describe('Team URL slug'),
    inviterName: zod.string().describe('Display name of whoever sent the invitation'),
    maskedEmail: zod.string().describe('Invited address, masked (a***@example.com)'),
    role: zod.enum(['MEMBER', 'ORGANIZER', 'ADMIN']).describe('Role granted on acceptance'),
    status: zod
      .enum(['PENDING', 'ACCEPTED', 'REVOKED', 'EXPIRED'])
      .describe('Where the invitation stands'),
    redeemable: zod
      .boolean()
      .describe(
        'Whether the invitation can still be redeemed. False for anything but a live PENDING one.'
      ),
  })
  .describe('What an invitation says, readable by whoever holds its token')

/**
 * Live invitations addressed to the current user, newest first. Teams they already belong to are left out.
 * @summary My pending invitations
 */
export const ListMyInvitationsResponse = zod
  .object({
    invitations: zod
      .array(
        zod
          .object({
            id: zod.string().describe('Invitation ID (TSID)'),
            team: zod
              .object({
                id: zod.string().describe('Team ID (TSID)'),
                name: zod.string().describe('Team name'),
                slug: zod.string().describe('Team URL slug'),
                visibility: zod
                  .enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC'])
                  .describe('Whether the team is public'),
                logoUrl: zod
                  .string()
                  .optional()
                  .describe(
                    "URL template of the team's logo (with a {size} placeholder), when it has one. Same value as TeamDetailDto.logoUrl, so a publication can show its team's logo without loading the team. Opaque URL: may carry a query string; substitute {size} only."
                  ),
              })
              .describe('Team being offered'),
            inviterName: zod.string().describe('Display name of whoever sent it'),
            role: zod.enum(['MEMBER', 'ORGANIZER', 'ADMIN']).describe('Role granted on acceptance'),
            expiresAt: zod.iso
              .datetime({ offset: true })
              .describe('When it stops being redeemable'),
          })
          .describe('An invitation waiting for the current user')
      )
      .describe('Invitations, newest first'),
  })
  .describe('The invitations waiting for the current user')

/**
 * Same effect as redeeming the token, for an invitation reached from this list.
 * @summary Accept one of my invitations
 */
export const AcceptMyInvitationParams = zod.object({
  invitationId: zod.string().describe('Invitation ID (TSID)'),
})

export const AcceptMyInvitationResponse = zod
  .object({
    team: zod
      .object({
        id: zod.string().describe('Team ID (TSID)'),
        name: zod.string().describe('Team name'),
        slug: zod.string().describe('Team URL slug'),
        visibility: zod
          .enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC'])
          .describe('Whether the team is public'),
        logoUrl: zod
          .string()
          .optional()
          .describe(
            "URL template of the team's logo (with a {size} placeholder), when it has one. Same value as TeamDetailDto.logoUrl, so a publication can show its team's logo without loading the team. Opaque URL: may carry a query string; substitute {size} only."
          ),
      })
      .describe('Team'),
    id: zod.string().describe('Membership ID (TSID)'),
    user: zod
      .object({
        id: zod.string().describe('User ID (TSID)'),
        displayName: zod.string().describe('User display name'),
        avatarUrl: zod.string().optional().describe('User avatar URL'),
      })
      .describe('User'),
    role: zod
      .enum(['MEMBER', 'ORGANIZER', 'ADMIN'])
      .optional()
      .describe(
        'Member role. Null when the caller is not entitled to it: an organiser reading the roster of a team that has not opened its member directory gets the names and nothing else.'
      ),
    joinedAt: zod.iso
      .datetime({ offset: true })
      .optional()
      .describe('When the user joined the team'),
  })
  .describe('Team member information')
