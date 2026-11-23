import * as zod from 'zod'

/**
 * Get a paginated list of all domains
 * @summary List all domains
 */
export const listDomainsQueryPageDefault = 0
export const listDomainsQuerySizeDefault = 20

export const ListDomainsQueryParams = zod.object({
  page: zod.int().default(listDomainsQueryPageDefault).describe('Page number (0-indexed)'),
  size: zod.int().default(listDomainsQuerySizeDefault).describe('Page size'),
})

export const ListDomainsResponse = zod
  .object({
    domains: zod
      .array(
        zod
          .object({
            id: zod.string().describe('Domain ID (TSID)'),
            domain: zod.string().describe('Domain hostname'),
            name: zod.string().describe('Domain display name'),
            baseUrl: zod.string().describe('Base URL for the domain'),
            singleTeam: zod.boolean().describe('Whether domain is single-team mode'),
            enableGpxPlanner: zod
              .boolean()
              .describe('Whether the interactive planner is open in the GPX tools'),
            androidFingerprints: zod
              .string()
              .optional()
              .describe(
                'Android app SHA-256 certificate fingerprints for passkey origin verification (comma-separated, colon-hex format)'
              ),
            active: zod.boolean().describe('Whether domain is active'),
            teamCount: zod.int().describe('Number of teams in this domain'),
            userCount: zod.int().describe('Number of users in this domain'),
            createdAt: zod.iso.datetime({ offset: true }).describe('Domain creation timestamp'),
          })
          .describe('Admin domain view with statistics')
      )
      .describe('List of domains'),
    total: zod.int().describe('Total number of domains'),
    page: zod.int().describe('Current page number'),
    size: zod.int().describe('Page size'),
  })
  .describe('Paginated admin domain list response')

/**
 * Create a new domain
 * @summary Create domain
 */
export const createDomainBodyDomainMax = 250

export const createDomainBodyDomainRegExp = new RegExp('\\S')
export const createDomainBodyNameMax = 250

export const createDomainBodyNameRegExp = new RegExp('\\S')
export const createDomainBodyBaseUrlMax = 500

export const createDomainBodyBaseUrlRegExp = new RegExp('\\S')
export const createDomainBodyAndroidFingerprintsMax = 1000

export const CreateDomainBody = zod
  .object({
    domain: zod
      .string()
      .max(createDomainBodyDomainMax)
      .regex(createDomainBodyDomainRegExp)
      .describe('Domain hostname'),
    name: zod
      .string()
      .max(createDomainBodyNameMax)
      .regex(createDomainBodyNameRegExp)
      .describe('Domain display name'),
    baseUrl: zod
      .string()
      .max(createDomainBodyBaseUrlMax)
      .regex(createDomainBodyBaseUrlRegExp)
      .describe('Base URL for the domain'),
    singleTeam: zod.boolean().optional().describe('Whether domain is single-team mode'),
    enableGpxPlanner: zod
      .boolean()
      .optional()
      .describe('Whether the interactive planner is open in the GPX tools'),
    androidFingerprints: zod
      .string()
      .max(createDomainBodyAndroidFingerprintsMax)
      .optional()
      .describe(
        'Android app SHA-256 certificate fingerprints for passkey origin verification (comma-separated, colon-hex format)'
      ),
  })
  .describe('Request to create a new domain')

export const CreateDomainResponse = zod
  .object({
    id: zod.string().describe('Domain ID (TSID)'),
    domain: zod.string().describe('Domain hostname'),
    name: zod.string().describe('Domain display name'),
    baseUrl: zod.string().describe('Base URL for the domain'),
    singleTeam: zod.boolean().describe('Whether domain is single-team mode'),
    enableGpxPlanner: zod
      .boolean()
      .describe('Whether the interactive planner is open in the GPX tools'),
    androidFingerprints: zod
      .string()
      .optional()
      .describe(
        'Android app SHA-256 certificate fingerprints for passkey origin verification (comma-separated, colon-hex format)'
      ),
    active: zod.boolean().describe('Whether domain is active'),
    teamCount: zod.int().describe('Number of teams in this domain'),
    userCount: zod.int().describe('Number of users in this domain'),
    createdAt: zod.iso.datetime({ offset: true }).describe('Domain creation timestamp'),
  })
  .describe('Admin domain view with statistics')

/**
 * Per sign-up week (ISO week, UTC) and domain: accounts created, verified, that joined a team and that signed up to a ride within 7 days. Counts only, computed on the data already stored — no person is named (ledger API-213).
 * @summary Activation of new accounts
 */
export const getActivationQueryWeeksDefault = 12

export const GetActivationQueryParams = zod.object({
  weeks: zod
    .int()
    .default(getActivationQueryWeeksDefault)
    .describe('Sign-up weeks back, the current one included (1 to 52)'),
})

export const GetActivationResponse = zod
  .object({
    weeks: zod
      .array(
        zod
          .object({
            domainId: zod.string().describe('Domain ID (TSID)'),
            domainName: zod.string().describe('Domain name'),
            weekStart: zod.iso.date().describe('Monday of the sign-up week (ISO week, UTC)'),
            complete: zod
              .boolean()
              .describe(
                'Whether every account of the week has had its 7 days: the counts of a week that is not complete can still grow'
              ),
            signedUp: zod.int().describe('Accounts created that week, deleted ones left out'),
            verified: zod.int().describe('Of those, accounts whose address is verified'),
            joinedTeam: zod
              .int()
              .describe(
                'Of those, accounts that joined a team (or created one) within 7 days of their creation, and still belong to it'
              ),
            joinedRide: zod
              .int()
              .describe(
                'Of those, accounts that signed up to a ride within 7 days of their creation, and are still signed up'
              ),
          })
          .describe(
            "Activation of the accounts created in one sign-up week on one domain: counts only, no person named. The rates are the client's to compute, over signedUp."
          )
      )
      .describe(
        'One row per week and domain that has at least one sign-up; a week without any is absent'
      ),
    weeksBack: zod.int().describe('How many weeks back the rows go'),
  })
  .describe(
    'Activation of new accounts per sign-up week and domain, newest week first (ledger API-213)'
  )

/**
 * Get overall platform statistics
 * @summary Get platform statistics
 */
export const GetStatsResponse = zod
  .object({
    totalDomains: zod.int().describe('Total number of domains'),
    totalTeams: zod.int().describe('Total number of teams'),
    totalUsers: zod.int().describe('Total number of users'),
  })
  .describe('Admin dashboard statistics')

/**
 * Update domain information
 * @summary Update domain
 */
export const UpdateDomainParams = zod.object({
  domainId: zod.string().describe('Domain ID'),
})

export const updateDomainBodyNameMax = 250

export const updateDomainBodyNameRegExp = new RegExp('\\S')
export const updateDomainBodyBaseUrlMax = 500

export const updateDomainBodyBaseUrlRegExp = new RegExp('\\S')
export const updateDomainBodyAndroidFingerprintsMax = 1000

export const UpdateDomainBody = zod
  .object({
    name: zod
      .string()
      .max(updateDomainBodyNameMax)
      .regex(updateDomainBodyNameRegExp)
      .describe('Domain display name'),
    baseUrl: zod
      .string()
      .max(updateDomainBodyBaseUrlMax)
      .regex(updateDomainBodyBaseUrlRegExp)
      .describe('Base URL for the domain'),
    singleTeam: zod.boolean().optional().describe('Whether domain is single-team mode'),
    enableGpxPlanner: zod
      .boolean()
      .optional()
      .describe('Whether the interactive planner is open in the GPX tools'),
    androidFingerprints: zod
      .string()
      .max(updateDomainBodyAndroidFingerprintsMax)
      .optional()
      .describe(
        'Android app SHA-256 certificate fingerprints for passkey origin verification (comma-separated, colon-hex format)'
      ),
  })
  .describe('Request to update a domain')

export const UpdateDomainResponse = zod
  .object({
    id: zod.string().describe('Domain ID (TSID)'),
    domain: zod.string().describe('Domain hostname'),
    name: zod.string().describe('Domain display name'),
    baseUrl: zod.string().describe('Base URL for the domain'),
    singleTeam: zod.boolean().describe('Whether domain is single-team mode'),
    enableGpxPlanner: zod
      .boolean()
      .describe('Whether the interactive planner is open in the GPX tools'),
    androidFingerprints: zod
      .string()
      .optional()
      .describe(
        'Android app SHA-256 certificate fingerprints for passkey origin verification (comma-separated, colon-hex format)'
      ),
    active: zod.boolean().describe('Whether domain is active'),
    teamCount: zod.int().describe('Number of teams in this domain'),
    userCount: zod.int().describe('Number of users in this domain'),
    createdAt: zod.iso.datetime({ offset: true }).describe('Domain creation timestamp'),
  })
  .describe('Admin domain view with statistics')

/**
 * Get detailed domain information
 * @summary Get domain details
 */
export const GetDomainParams = zod.object({
  domainId: zod.string().describe('Domain ID'),
})

export const GetDomainResponse = zod
  .object({
    id: zod.string().describe('Domain ID (TSID)'),
    domain: zod.string().describe('Domain hostname'),
    name: zod.string().describe('Domain display name'),
    baseUrl: zod.string().describe('Base URL for the domain'),
    singleTeam: zod.boolean().describe('Whether domain is single-team mode'),
    enableGpxPlanner: zod
      .boolean()
      .describe('Whether the interactive planner is open in the GPX tools'),
    androidFingerprints: zod
      .string()
      .optional()
      .describe(
        'Android app SHA-256 certificate fingerprints for passkey origin verification (comma-separated, colon-hex format)'
      ),
    active: zod.boolean().describe('Whether domain is active'),
    teamCount: zod.int().describe('Number of teams in this domain'),
    userCount: zod.int().describe('Number of users in this domain'),
    createdAt: zod.iso.datetime({ offset: true }).describe('Domain creation timestamp'),
  })
  .describe('Admin domain view with statistics')

/**
 * Get all dedicated hostnames (aliases) pinned to teams of a domain
 * @summary List domain aliases
 */
export const ListDomainAliasesParams = zod.object({
  domainId: zod.string().describe('Domain ID'),
})

export const ListDomainAliasesResponseItem = zod
  .object({
    id: zod.string().describe('Alias ID (TSID)'),
    hostname: zod.string().describe('Alias hostname'),
    domainId: zod.string().describe('Parent domain ID (TSID)'),
    pinnedTeamId: zod.string().describe('Pinned team ID (TSID)'),
    pinnedTeamSlug: zod.string().describe('Pinned team slug'),
    name: zod.string().describe('Alias display name'),
    baseUrl: zod.string().describe('Base URL for the alias'),
    androidFingerprints: zod
      .string()
      .optional()
      .describe(
        'Android app SHA-256 certificate fingerprints for passkey origin verification (comma-separated, colon-hex format)'
      ),
    active: zod.boolean().describe('Whether alias is active'),
    createdAt: zod.iso.datetime({ offset: true }).describe('Alias creation timestamp'),
  })
  .describe('Admin view of a domain alias (dedicated hostname pinned to a team)')
export const ListDomainAliasesResponse = zod.array(ListDomainAliasesResponseItem)

/**
 * Create a dedicated hostname pinned to a team of the domain
 * @summary Create domain alias
 */
export const CreateDomainAliasParams = zod.object({
  domainId: zod.string().describe('Domain ID'),
})

export const createDomainAliasBodyHostnameMax = 250

export const createDomainAliasBodyHostnameRegExp = new RegExp('\\S')
export const createDomainAliasBodyTeamSlugRegExp = new RegExp('\\S')
export const createDomainAliasBodyNameMax = 250

export const createDomainAliasBodyNameRegExp = new RegExp('\\S')
export const createDomainAliasBodyBaseUrlMax = 500

export const createDomainAliasBodyBaseUrlRegExp = new RegExp('\\S')
export const createDomainAliasBodyAndroidFingerprintsMax = 1000

export const CreateDomainAliasBody = zod
  .object({
    hostname: zod
      .string()
      .max(createDomainAliasBodyHostnameMax)
      .regex(createDomainAliasBodyHostnameRegExp)
      .describe('Alias hostname'),
    teamSlug: zod
      .string()
      .regex(createDomainAliasBodyTeamSlugRegExp)
      .describe('Slug of the team to pin (must belong to the domain)'),
    name: zod
      .string()
      .max(createDomainAliasBodyNameMax)
      .regex(createDomainAliasBodyNameRegExp)
      .describe('Alias display name'),
    baseUrl: zod
      .string()
      .max(createDomainAliasBodyBaseUrlMax)
      .regex(createDomainAliasBodyBaseUrlRegExp)
      .describe('Base URL for the alias'),
    androidFingerprints: zod
      .string()
      .max(createDomainAliasBodyAndroidFingerprintsMax)
      .optional()
      .describe(
        'Android app SHA-256 certificate fingerprints for passkey origin verification (comma-separated, colon-hex format)'
      ),
  })
  .describe('Request to create a domain alias (dedicated hostname pinned to a team)')

export const CreateDomainAliasResponse = zod
  .object({
    id: zod.string().describe('Alias ID (TSID)'),
    hostname: zod.string().describe('Alias hostname'),
    domainId: zod.string().describe('Parent domain ID (TSID)'),
    pinnedTeamId: zod.string().describe('Pinned team ID (TSID)'),
    pinnedTeamSlug: zod.string().describe('Pinned team slug'),
    name: zod.string().describe('Alias display name'),
    baseUrl: zod.string().describe('Base URL for the alias'),
    androidFingerprints: zod
      .string()
      .optional()
      .describe(
        'Android app SHA-256 certificate fingerprints for passkey origin verification (comma-separated, colon-hex format)'
      ),
    active: zod.boolean().describe('Whether alias is active'),
    createdAt: zod.iso.datetime({ offset: true }).describe('Alias creation timestamp'),
  })
  .describe('Admin view of a domain alias (dedicated hostname pinned to a team)')

/**
 * Update a dedicated hostname's pinned team or branding
 * @summary Update domain alias
 */
export const UpdateDomainAliasParams = zod.object({
  aliasId: zod.string().describe('Alias ID'),
  domainId: zod.string().describe('Domain ID'),
})

export const updateDomainAliasBodyTeamSlugRegExp = new RegExp('\\S')
export const updateDomainAliasBodyNameMax = 250

export const updateDomainAliasBodyNameRegExp = new RegExp('\\S')
export const updateDomainAliasBodyBaseUrlMax = 500

export const updateDomainAliasBodyBaseUrlRegExp = new RegExp('\\S')
export const updateDomainAliasBodyAndroidFingerprintsMax = 1000

export const UpdateDomainAliasBody = zod
  .object({
    teamSlug: zod
      .string()
      .regex(updateDomainAliasBodyTeamSlugRegExp)
      .describe('Slug of the team to pin (must belong to the domain)'),
    name: zod
      .string()
      .max(updateDomainAliasBodyNameMax)
      .regex(updateDomainAliasBodyNameRegExp)
      .describe('Alias display name'),
    baseUrl: zod
      .string()
      .max(updateDomainAliasBodyBaseUrlMax)
      .regex(updateDomainAliasBodyBaseUrlRegExp)
      .describe('Base URL for the alias'),
    androidFingerprints: zod
      .string()
      .max(updateDomainAliasBodyAndroidFingerprintsMax)
      .optional()
      .describe(
        'Android app SHA-256 certificate fingerprints for passkey origin verification (comma-separated, colon-hex format)'
      ),
  })
  .describe('Request to update a domain alias')

export const UpdateDomainAliasResponse = zod
  .object({
    id: zod.string().describe('Alias ID (TSID)'),
    hostname: zod.string().describe('Alias hostname'),
    domainId: zod.string().describe('Parent domain ID (TSID)'),
    pinnedTeamId: zod.string().describe('Pinned team ID (TSID)'),
    pinnedTeamSlug: zod.string().describe('Pinned team slug'),
    name: zod.string().describe('Alias display name'),
    baseUrl: zod.string().describe('Base URL for the alias'),
    androidFingerprints: zod
      .string()
      .optional()
      .describe(
        'Android app SHA-256 certificate fingerprints for passkey origin verification (comma-separated, colon-hex format)'
      ),
    active: zod.boolean().describe('Whether alias is active'),
    createdAt: zod.iso.datetime({ offset: true }).describe('Alias creation timestamp'),
  })
  .describe('Admin view of a domain alias (dedicated hostname pinned to a team)')

/**
 * Delete a dedicated hostname
 * @summary Delete domain alias
 */
export const DeleteDomainAliasParams = zod.object({
  aliasId: zod.string().describe('Alias ID'),
  domainId: zod.string().describe('Domain ID'),
})

export const DeleteDomainAliasResponse = zod.void()

/**
 * Enable or disable a dedicated hostname
 * @summary Toggle domain alias active status
 */
export const ToggleDomainAliasActiveParams = zod.object({
  aliasId: zod.string().describe('Alias ID'),
  domainId: zod.string().describe('Domain ID'),
})

export const ToggleDomainAliasActiveResponse = zod
  .object({
    id: zod.string().describe('Alias ID (TSID)'),
    hostname: zod.string().describe('Alias hostname'),
    domainId: zod.string().describe('Parent domain ID (TSID)'),
    pinnedTeamId: zod.string().describe('Pinned team ID (TSID)'),
    pinnedTeamSlug: zod.string().describe('Pinned team slug'),
    name: zod.string().describe('Alias display name'),
    baseUrl: zod.string().describe('Base URL for the alias'),
    androidFingerprints: zod
      .string()
      .optional()
      .describe(
        'Android app SHA-256 certificate fingerprints for passkey origin verification (comma-separated, colon-hex format)'
      ),
    active: zod.boolean().describe('Whether alias is active'),
    createdAt: zod.iso.datetime({ offset: true }).describe('Alias creation timestamp'),
  })
  .describe('Admin view of a domain alias (dedicated hostname pinned to a team)')

/**
 * Get all GPS credentials for a domain
 * @summary List GPS credentials
 */
export const ListDomainGpsCredentialsParams = zod.object({
  domainId: zod.string().describe('Domain ID'),
})

export const ListDomainGpsCredentialsResponseItem = zod
  .object({
    id: zod.string().describe('Credential ID (TSID)'),
    serviceType: zod.enum(['HAMMERHEAD', 'GARMIN', 'WAHOO']).describe('GPS service type'),
    clientId: zod.string().describe('OAuth client ID (consumer key for OAuth 1.0a)'),
    oauthVersion: zod
      .enum(['OAUTH1', 'OAUTH2'])
      .describe('OAuth protocol of the client ID and secret'),
    active: zod.boolean().describe('Whether credential is active'),
    createdAt: zod.iso.datetime({ offset: true }).describe('Credential creation timestamp'),
  })
  .describe('Admin GPS credential view (without secret)')
export const ListDomainGpsCredentialsResponse = zod.array(ListDomainGpsCredentialsResponseItem)

/**
 * Create a new GPS credential for a domain
 * @summary Create GPS credential
 */
export const CreateDomainGpsCredentialParams = zod.object({
  domainId: zod.string().describe('Domain ID'),
})

export const createDomainGpsCredentialBodyClientIdMax = 255

export const createDomainGpsCredentialBodyClientIdRegExp = new RegExp('\\S')
export const createDomainGpsCredentialBodyClientSecretMax = 500

export const CreateDomainGpsCredentialBody = zod
  .object({
    serviceType: zod.enum(['HAMMERHEAD', 'GARMIN', 'WAHOO']).describe('GPS service type'),
    clientId: zod
      .string()
      .max(createDomainGpsCredentialBodyClientIdMax)
      .regex(createDomainGpsCredentialBodyClientIdRegExp)
      .describe('OAuth client ID'),
    clientSecret: zod
      .string()
      .max(createDomainGpsCredentialBodyClientSecretMax)
      .optional()
      .describe('OAuth client secret, or consumer secret for OAuth 1.0a (required then)'),
    active: zod.boolean().optional().describe('Whether credential is active'),
    oauthVersion: zod
      .enum(['OAUTH1', 'OAUTH2'])
      .optional()
      .describe(
        'OAuth protocol of the client ID and secret (null = OAUTH2). OAUTH1 is accepted for GARMIN only; the client ID is then the consumer key'
      ),
  })
  .describe('Request to create a new GPS credential')

export const CreateDomainGpsCredentialResponse = zod
  .object({
    id: zod.string().describe('Credential ID (TSID)'),
    serviceType: zod.enum(['HAMMERHEAD', 'GARMIN', 'WAHOO']).describe('GPS service type'),
    clientId: zod.string().describe('OAuth client ID (consumer key for OAuth 1.0a)'),
    oauthVersion: zod
      .enum(['OAUTH1', 'OAUTH2'])
      .describe('OAuth protocol of the client ID and secret'),
    active: zod.boolean().describe('Whether credential is active'),
    createdAt: zod.iso.datetime({ offset: true }).describe('Credential creation timestamp'),
  })
  .describe('Admin GPS credential view (without secret)')

/**
 * Update a GPS credential for a domain
 * @summary Update GPS credential
 */
export const UpdateDomainGpsCredentialParams = zod.object({
  credentialId: zod.string().describe('Credential ID'),
  domainId: zod.string().describe('Domain ID'),
})

export const updateDomainGpsCredentialBodyClientIdMax = 255

export const updateDomainGpsCredentialBodyClientIdRegExp = new RegExp('\\S')
export const updateDomainGpsCredentialBodyClientSecretMax = 500

export const UpdateDomainGpsCredentialBody = zod
  .object({
    clientId: zod
      .string()
      .max(updateDomainGpsCredentialBodyClientIdMax)
      .regex(updateDomainGpsCredentialBodyClientIdRegExp)
      .describe('OAuth client ID'),
    clientSecret: zod
      .string()
      .max(updateDomainGpsCredentialBodyClientSecretMax)
      .optional()
      .describe('OAuth client secret (null = keep current)'),
    active: zod.boolean().optional().describe('Whether credential is active'),
    oauthVersion: zod
      .enum(['OAUTH1', 'OAUTH2'])
      .optional()
      .describe(
        'OAuth protocol of the client ID and secret (null = keep current). OAUTH1 is accepted for GARMIN only. Switching it leaves existing connections unusable: each is dropped at its next upload and must be reconnected'
      ),
  })
  .describe('Request to update a GPS credential')

export const UpdateDomainGpsCredentialResponse = zod
  .object({
    id: zod.string().describe('Credential ID (TSID)'),
    serviceType: zod.enum(['HAMMERHEAD', 'GARMIN', 'WAHOO']).describe('GPS service type'),
    clientId: zod.string().describe('OAuth client ID (consumer key for OAuth 1.0a)'),
    oauthVersion: zod
      .enum(['OAUTH1', 'OAUTH2'])
      .describe('OAuth protocol of the client ID and secret'),
    active: zod.boolean().describe('Whether credential is active'),
    createdAt: zod.iso.datetime({ offset: true }).describe('Credential creation timestamp'),
  })
  .describe('Admin GPS credential view (without secret)')

/**
 * Delete a GPS credential for a domain
 * @summary Delete GPS credential
 */
export const DeleteDomainGpsCredentialParams = zod.object({
  credentialId: zod.string().describe('Credential ID'),
  domainId: zod.string().describe('Domain ID'),
})

export const DeleteDomainGpsCredentialResponse = zod.void()

/**
 * Enable or disable a domain
 * @summary Toggle domain active status
 */
export const ToggleDomainActiveParams = zod.object({
  domainId: zod.string().describe('Domain ID'),
})

export const ToggleDomainActiveResponse = zod
  .object({
    id: zod.string().describe('Domain ID (TSID)'),
    domain: zod.string().describe('Domain hostname'),
    name: zod.string().describe('Domain display name'),
    baseUrl: zod.string().describe('Base URL for the domain'),
    singleTeam: zod.boolean().describe('Whether domain is single-team mode'),
    enableGpxPlanner: zod
      .boolean()
      .describe('Whether the interactive planner is open in the GPX tools'),
    androidFingerprints: zod
      .string()
      .optional()
      .describe(
        'Android app SHA-256 certificate fingerprints for passkey origin verification (comma-separated, colon-hex format)'
      ),
    active: zod.boolean().describe('Whether domain is active'),
    teamCount: zod.int().describe('Number of teams in this domain'),
    userCount: zod.int().describe('Number of users in this domain'),
    createdAt: zod.iso.datetime({ offset: true }).describe('Domain creation timestamp'),
  })
  .describe('Admin domain view with statistics')
