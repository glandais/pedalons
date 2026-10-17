import * as zod from 'zod'

/**
 * Paginated list of team members. Administrators always see it; so do organisers, who need a member list to designate a ride group's leader. Everyone else needs the team to have set enableMemberDirectory. What is returned is graded too: 'role' and 'joinedAt' are null unless the caller is an administrator or the directory is open, 'search' only matches an e-mail address for an administrator, and 'role' is refused with a 403 to a caller who does not get the roles.
 * @summary Get team members
 */
export const GetMembersParams = zod.object({
  teamSlug: zod.string().describe('Team URL slug'),
})

export const getMembersQueryPageDefault = 0
export const getMembersQuerySizeDefault = 50

export const GetMembersQueryParams = zod.object({
  page: zod.int().default(getMembersQueryPageDefault).describe('Page number'),
  role: zod
    .enum(['MEMBER', 'ORGANIZER', 'ADMIN'])
    .optional()
    .describe(
      'Filter by role. Only for a caller who gets the roles (an administrator, or anyone once the directory is open): 403 otherwise.'
    ),
  search: zod
    .string()
    .optional()
    .describe('Search by display name. Also matches the e-mail address, for administrators only.'),
  size: zod.int().default(getMembersQuerySizeDefault).describe('Page size'),
  sortBy: zod
    .enum(['JOINED_AT'])
    .optional()
    .describe(
      'Order of the list. JOINED_AT is the join date, then the membership id; only for a caller who gets the join dates (an administrator, or anyone once the directory is open): 403 otherwise. Omitted, the order is unspecified.'
    ),
  sortDir: zod
    .enum(['ASC', 'DESC'])
    .optional()
    .describe('Direction of sortBy. Omitted is DESC — newest first.'),
})

export const GetMembersResponse = zod
  .object({
    members: zod
      .array(
        zod
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
      )
      .describe('List of members'),
    total: zod.int().describe('Total number of members'),
    page: zod.int().describe('Current page number'),
    size: zod.int().describe('Page size'),
  })
  .describe('Paginated member list response')

/**
 * Add a member to the team. Requires ADMIN role on team.
 * @summary Add team member
 */
export const AddMemberParams = zod.object({
  teamSlug: zod.string().describe('Team URL slug'),
})

export const AddMemberBody = zod
  .object({
    userId: zod.string().describe('User ID (TSID) to add'),
    role: zod
      .enum(['MEMBER', 'ORGANIZER', 'ADMIN'])
      .optional()
      .describe('Role to assign (defaults to MEMBER)'),
  })
  .describe('Request to add a member to the team')

export const AddMemberResponse = zod
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
 * Request to join a team
 * @summary Join team
 */
export const JoinTeamParams = zod.object({
  teamSlug: zod.string().describe('Team URL slug'),
})

export const JoinTeamResponse = zod
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
 * Leave a team
 * @summary Leave team
 */
export const LeaveTeamParams = zod.object({
  teamSlug: zod.string().describe('Team URL slug'),
})

export const LeaveTeamResponse = zod.void()

/**
 * Update a team member's role. Requires ADMIN role.
 * @summary Update member role
 */
export const UpdateMemberRoleParams = zod.object({
  memberId: zod.string().describe('Member user ID (TSID)'),
  teamSlug: zod.string().describe('Team URL slug'),
})

export const UpdateMemberRoleBody = zod
  .object({
    role: zod.enum(['MEMBER', 'ORGANIZER', 'ADMIN']).describe('New role'),
  })
  .describe("Request to update a member's role")

export const UpdateMemberRoleResponse = zod
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
 * Remove a member from the team. Requires ADMIN role.
 * @summary Remove team member
 */
export const RemoveMemberParams = zod.object({
  memberId: zod.string().describe('Member user ID (TSID)'),
  teamSlug: zod.string().describe('Team URL slug'),
})

export const RemoveMemberResponse = zod.void()
