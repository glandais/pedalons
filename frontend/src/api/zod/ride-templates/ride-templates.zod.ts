import * as zod from 'zod'

/**
 * Get paginated list of ride templates for a team
 * @summary List ride templates
 */
export const ListTemplatesParams = zod.object({
  teamSlug: zod.string().describe('Team URL slug'),
})

export const listTemplatesQueryPageDefault = 0
export const listTemplatesQuerySizeDefault = 20

export const ListTemplatesQueryParams = zod.object({
  page: zod.int().default(listTemplatesQueryPageDefault).describe('Page number'),
  search: zod.string().optional().describe('Search by name'),
  size: zod.int().default(listTemplatesQuerySizeDefault).describe('Page size'),
})

export const ListTemplatesResponse = zod
  .object({
    templates: zod
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
                    "URL template of the team's logo (with a {size} placeholder), when it has one. Same value as TeamDetailDto.logoUrl, so a publication can show its team's logo without loading the team."
                  ),
              })
              .describe('Team'),
            id: zod.string().describe('Template ID (TSID)'),
            slug: zod.string().describe('Template slug'),
            name: zod.string().describe('Template name'),
            markdown: zod.string().describe('Template description (markdown)'),
            visibility: zod
              .enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC'])
              .describe('Visibility level'),
            status: zod.enum(['DRAFT', 'PUBLISHED', 'CANCELLED']).describe('Default status'),
            createdAt: zod.iso.datetime({ offset: true }).describe('Creation timestamp'),
            updatedAt: zod.iso.datetime({ offset: true }).describe('Last update timestamp'),
            groupCount: zod.int().describe('Number of groups'),
            groups: zod
              .array(
                zod
                  .object({
                    id: zod.string().describe('Group ID (TSID)'),
                    name: zod.string().describe('Group name'),
                    time: zod.string().optional(),
                    averageSpeed: zod.number().optional().describe('Average speed in km/h'),
                    maxParticipants: zod.int().optional().describe('Maximum participants'),
                    sortOrder: zod.int().describe('Sort order'),
                  })
                  .describe('Ride template group information')
              )
              .describe('Template groups'),
            tags: zod
              .array(
                zod
                  .object({
                    id: zod.string().describe('Tag ID (TSID)'),
                    label: zod.string().describe('Label, at most 32 characters'),
                    color: zod
                      .enum([
                        'INDIGO',
                        'BLUE',
                        'GREEN',
                        'RED',
                        'YELLOW',
                        'ORANGE',
                        'GRAPE',
                        'TEAL',
                        'GRAY',
                      ])
                      .describe('Colour family'),
                  })
                  .describe('A team tag on a content')
              )
              .describe(
                "The team's RIDE tags of the template, sorted by label. Copied onto a ride created from it: a client prefills the ride's tagIds with them, editable before and after."
              ),
            nextNumber: zod
              .int()
              .optional()
              .describe(
                "The number the next ride created from this template takes: a client prefills the ride's name with « name #nextNumber » and sends RideRequest.templateId, which raises it by one. Null: the template numbers nothing."
              ),
          })
          .describe('Ride template response')
      )
      .describe('List of templates'),
    total: zod.int().describe('Total number of templates'),
    page: zod.int().describe('Current page number'),
    size: zod.int().describe('Page size'),
  })
  .describe('Paginated ride template list response')

/**
 * Create a new ride template. Requires organizer permissions.
 * @summary Create ride template
 */
export const CreateTemplateParams = zod.object({
  teamSlug: zod.string().describe('Team URL slug'),
})

export const createTemplateBodyNameMax = 200

export const createTemplateBodyNameRegExp = new RegExp('\\S')
export const createTemplateBodyMarkdownMax = 100000

export const createTemplateBodyGroupsItemNameMax = 200

export const createTemplateBodyGroupsItemNameRegExp = new RegExp('\\S')
export const createTemplateBodyNextNumberMin = 0

export const CreateTemplateBody = zod
  .object({
    name: zod
      .string()
      .min(1)
      .max(createTemplateBodyNameMax)
      .regex(createTemplateBodyNameRegExp)
      .describe('Template name'),
    markdown: zod
      .string()
      .max(createTemplateBodyMarkdownMax)
      .describe('Template description (markdown)'),
    visibility: zod.enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC']).describe('Visibility level'),
    status: zod
      .enum(['DRAFT', 'PUBLISHED', 'CANCELLED'])
      .describe('Default status for rides created from this template'),
    groups: zod
      .array(
        zod
          .object({
            id: zod.string().optional().describe('Group ID (TSID) - only for updates'),
            name: zod
              .string()
              .min(1)
              .max(createTemplateBodyGroupsItemNameMax)
              .regex(createTemplateBodyGroupsItemNameRegExp)
              .describe('Group name'),
            time: zod.string().optional(),
            averageSpeed: zod.number().optional().describe('Average speed in km/h'),
            maxParticipants: zod.int().optional().describe('Maximum participants'),
          })
          .describe('Ride template group request')
      )
      .describe('Template groups'),
    tagIds: zod
      .array(zod.string())
      .optional()
      .describe(
        "IDs (TSID) of the team's RIDE tags the template carries (copied onto the rides created from it), replacing the whole set — at most 10, each a tag of this team and of kind RIDE, else 400 (TAG_INVALID, TOO_MANY_TAGS). An empty list removes them all. Omitted: none on a creation, left as they are on an update."
      ),
    nextNumber: zod
      .int()
      .min(createTemplateBodyNextNumberMin)
      .optional()
      .describe(
        'The number the next ride created from this template takes: a client titles it « name #nextNumber » and the creation of that ride (RideRequest.templateId) raises it by one. Null: the template numbers nothing.'
      ),
  })
  .describe('Ride template request')

export const CreateTemplateResponse = zod
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
            "URL template of the team's logo (with a {size} placeholder), when it has one. Same value as TeamDetailDto.logoUrl, so a publication can show its team's logo without loading the team."
          ),
      })
      .describe('Team'),
    id: zod.string().describe('Template ID (TSID)'),
    slug: zod.string().describe('Template slug'),
    name: zod.string().describe('Template name'),
    markdown: zod.string().describe('Template description (markdown)'),
    visibility: zod.enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC']).describe('Visibility level'),
    status: zod.enum(['DRAFT', 'PUBLISHED', 'CANCELLED']).describe('Default status'),
    createdAt: zod.iso.datetime({ offset: true }).describe('Creation timestamp'),
    updatedAt: zod.iso.datetime({ offset: true }).describe('Last update timestamp'),
    groupCount: zod.int().describe('Number of groups'),
    groups: zod
      .array(
        zod
          .object({
            id: zod.string().describe('Group ID (TSID)'),
            name: zod.string().describe('Group name'),
            time: zod.string().optional(),
            averageSpeed: zod.number().optional().describe('Average speed in km/h'),
            maxParticipants: zod.int().optional().describe('Maximum participants'),
            sortOrder: zod.int().describe('Sort order'),
          })
          .describe('Ride template group information')
      )
      .describe('Template groups'),
    tags: zod
      .array(
        zod
          .object({
            id: zod.string().describe('Tag ID (TSID)'),
            label: zod.string().describe('Label, at most 32 characters'),
            color: zod
              .enum(['INDIGO', 'BLUE', 'GREEN', 'RED', 'YELLOW', 'ORANGE', 'GRAPE', 'TEAL', 'GRAY'])
              .describe('Colour family'),
          })
          .describe('A team tag on a content')
      )
      .describe(
        "The team's RIDE tags of the template, sorted by label. Copied onto a ride created from it: a client prefills the ride's tagIds with them, editable before and after."
      ),
    nextNumber: zod
      .int()
      .optional()
      .describe(
        "The number the next ride created from this template takes: a client prefills the ride's name with « name #nextNumber » and sends RideRequest.templateId, which raises it by one. Null: the template numbers nothing."
      ),
  })
  .describe('Ride template response')

/**
 * Update ride template information. Requires organizer permissions.
 * @summary Update ride template
 */
export const UpdateTemplateParams = zod.object({
  teamSlug: zod.string().describe('Team URL slug'),
  templateSlug: zod.string().describe('Template URL slug'),
})

export const updateTemplateBodyNameMax = 200

export const updateTemplateBodyNameRegExp = new RegExp('\\S')
export const updateTemplateBodyMarkdownMax = 100000

export const updateTemplateBodyGroupsItemNameMax = 200

export const updateTemplateBodyGroupsItemNameRegExp = new RegExp('\\S')
export const updateTemplateBodyNextNumberMin = 0

export const UpdateTemplateBody = zod
  .object({
    name: zod
      .string()
      .min(1)
      .max(updateTemplateBodyNameMax)
      .regex(updateTemplateBodyNameRegExp)
      .describe('Template name'),
    markdown: zod
      .string()
      .max(updateTemplateBodyMarkdownMax)
      .describe('Template description (markdown)'),
    visibility: zod.enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC']).describe('Visibility level'),
    status: zod
      .enum(['DRAFT', 'PUBLISHED', 'CANCELLED'])
      .describe('Default status for rides created from this template'),
    groups: zod
      .array(
        zod
          .object({
            id: zod.string().optional().describe('Group ID (TSID) - only for updates'),
            name: zod
              .string()
              .min(1)
              .max(updateTemplateBodyGroupsItemNameMax)
              .regex(updateTemplateBodyGroupsItemNameRegExp)
              .describe('Group name'),
            time: zod.string().optional(),
            averageSpeed: zod.number().optional().describe('Average speed in km/h'),
            maxParticipants: zod.int().optional().describe('Maximum participants'),
          })
          .describe('Ride template group request')
      )
      .describe('Template groups'),
    tagIds: zod
      .array(zod.string())
      .optional()
      .describe(
        "IDs (TSID) of the team's RIDE tags the template carries (copied onto the rides created from it), replacing the whole set — at most 10, each a tag of this team and of kind RIDE, else 400 (TAG_INVALID, TOO_MANY_TAGS). An empty list removes them all. Omitted: none on a creation, left as they are on an update."
      ),
    nextNumber: zod
      .int()
      .min(updateTemplateBodyNextNumberMin)
      .optional()
      .describe(
        'The number the next ride created from this template takes: a client titles it « name #nextNumber » and the creation of that ride (RideRequest.templateId) raises it by one. Null: the template numbers nothing.'
      ),
  })
  .describe('Ride template request')

export const UpdateTemplateResponse = zod
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
            "URL template of the team's logo (with a {size} placeholder), when it has one. Same value as TeamDetailDto.logoUrl, so a publication can show its team's logo without loading the team."
          ),
      })
      .describe('Team'),
    id: zod.string().describe('Template ID (TSID)'),
    slug: zod.string().describe('Template slug'),
    name: zod.string().describe('Template name'),
    markdown: zod.string().describe('Template description (markdown)'),
    visibility: zod.enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC']).describe('Visibility level'),
    status: zod.enum(['DRAFT', 'PUBLISHED', 'CANCELLED']).describe('Default status'),
    createdAt: zod.iso.datetime({ offset: true }).describe('Creation timestamp'),
    updatedAt: zod.iso.datetime({ offset: true }).describe('Last update timestamp'),
    groupCount: zod.int().describe('Number of groups'),
    groups: zod
      .array(
        zod
          .object({
            id: zod.string().describe('Group ID (TSID)'),
            name: zod.string().describe('Group name'),
            time: zod.string().optional(),
            averageSpeed: zod.number().optional().describe('Average speed in km/h'),
            maxParticipants: zod.int().optional().describe('Maximum participants'),
            sortOrder: zod.int().describe('Sort order'),
          })
          .describe('Ride template group information')
      )
      .describe('Template groups'),
    tags: zod
      .array(
        zod
          .object({
            id: zod.string().describe('Tag ID (TSID)'),
            label: zod.string().describe('Label, at most 32 characters'),
            color: zod
              .enum(['INDIGO', 'BLUE', 'GREEN', 'RED', 'YELLOW', 'ORANGE', 'GRAPE', 'TEAL', 'GRAY'])
              .describe('Colour family'),
          })
          .describe('A team tag on a content')
      )
      .describe(
        "The team's RIDE tags of the template, sorted by label. Copied onto a ride created from it: a client prefills the ride's tagIds with them, editable before and after."
      ),
    nextNumber: zod
      .int()
      .optional()
      .describe(
        "The number the next ride created from this template takes: a client prefills the ride's name with « name #nextNumber » and sends RideRequest.templateId, which raises it by one. Null: the template numbers nothing."
      ),
  })
  .describe('Ride template response')

/**
 * Get detailed ride template information
 * @summary Get ride template
 */
export const GetTemplateParams = zod.object({
  teamSlug: zod.string().describe('Team URL slug'),
  templateSlug: zod.string().describe('Template URL slug'),
})

export const GetTemplateResponse = zod
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
            "URL template of the team's logo (with a {size} placeholder), when it has one. Same value as TeamDetailDto.logoUrl, so a publication can show its team's logo without loading the team."
          ),
      })
      .describe('Team'),
    id: zod.string().describe('Template ID (TSID)'),
    slug: zod.string().describe('Template slug'),
    name: zod.string().describe('Template name'),
    markdown: zod.string().describe('Template description (markdown)'),
    visibility: zod.enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC']).describe('Visibility level'),
    status: zod.enum(['DRAFT', 'PUBLISHED', 'CANCELLED']).describe('Default status'),
    createdAt: zod.iso.datetime({ offset: true }).describe('Creation timestamp'),
    updatedAt: zod.iso.datetime({ offset: true }).describe('Last update timestamp'),
    groupCount: zod.int().describe('Number of groups'),
    groups: zod
      .array(
        zod
          .object({
            id: zod.string().describe('Group ID (TSID)'),
            name: zod.string().describe('Group name'),
            time: zod.string().optional(),
            averageSpeed: zod.number().optional().describe('Average speed in km/h'),
            maxParticipants: zod.int().optional().describe('Maximum participants'),
            sortOrder: zod.int().describe('Sort order'),
          })
          .describe('Ride template group information')
      )
      .describe('Template groups'),
    tags: zod
      .array(
        zod
          .object({
            id: zod.string().describe('Tag ID (TSID)'),
            label: zod.string().describe('Label, at most 32 characters'),
            color: zod
              .enum(['INDIGO', 'BLUE', 'GREEN', 'RED', 'YELLOW', 'ORANGE', 'GRAPE', 'TEAL', 'GRAY'])
              .describe('Colour family'),
          })
          .describe('A team tag on a content')
      )
      .describe(
        "The team's RIDE tags of the template, sorted by label. Copied onto a ride created from it: a client prefills the ride's tagIds with them, editable before and after."
      ),
    nextNumber: zod
      .int()
      .optional()
      .describe(
        "The number the next ride created from this template takes: a client prefills the ride's name with « name #nextNumber » and sends RideRequest.templateId, which raises it by one. Null: the template numbers nothing."
      ),
  })
  .describe('Ride template response')

/**
 * Soft delete a ride template. Requires organizer permissions.
 * @summary Delete ride template
 */
export const DeleteTemplateParams = zod.object({
  teamSlug: zod.string().describe('Team URL slug'),
  templateSlug: zod.string().describe('Template URL slug'),
})

export const DeleteTemplateResponse = zod.void()
