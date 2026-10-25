import type { Locator, Page } from '@playwright/test'
import { test } from '@playwright/test'
import type {
  AdminDomainAliasDto,
  AdminDomainDto,
  AdminDomainListResponse,
  AdminGpsCredentialDto,
  AdminTeamDto,
  AdminUserDto,
  AssignPlatformRoleRequest,
  CreateDomainRequest,
  CreateGpsCredentialRequest,
  TeamDetailDto,
  UpdateDomainRequest,
} from '../../src/api/dto'
import { apiDelete, apiGet, apiPost, apiPut } from './api'
import { roleSession } from './data'
import { originOf } from './domains'

/**
 * The platform administration journey (flow-platform-admin.e2e.ts): its screens' rows, and the
 * platform admin's reads and writes through the API. Every write goes to a team or an account the
 * test created — the seeded admin account is shared by every test running in parallel.
 */

export const ADMIN_TEAMS_PATH = '/plateforme/equipes'
export const ADMIN_USERS_PATH = '/plateforme/utilisateurs'

/**
 * The row of the platform team list holding `team`, found by its slug (unique, and printed in a
 * cell of its own). The list is the newest first, so a team the test just created is on page 1.
 */
export const adminTeamRow = (page: Page, team: Pick<TeamDetailDto, 'slug'>): Locator =>
  page
    .getByRole('main')
    .getByRole('row')
    .filter({ has: page.getByRole('cell', { name: team.slug, exact: true }) })

/** The row of the platform user list holding the account `email`. */
export const adminUserRow = (page: Page, email: string): Locator =>
  page
    .getByRole('main')
    .getByRole('row')
    .filter({ has: page.getByRole('cell', { name: email, exact: true }) })

/** The user list searched on `email` (`?q=`), so the account is on its first page. */
export const adminUsersSearch = (email: string) =>
  `${ADMIN_USERS_PATH}?q=${encodeURIComponent(email)}`

/** GET /api/admin/teams/{id} as the platform admin — archived teams included. */
export const adminTeam = async (team: Pick<TeamDetailDto, 'id'>) =>
  apiGet<AdminTeamDto>(await roleSession('admin'), `/api/admin/teams/${team.id}`)

/** GET /api/admin/users/{id} as the platform admin. */
export const adminUser = async (userId: string) =>
  apiGet<AdminUserDto>(await roleSession('admin'), `/api/admin/users/${userId}`)

/** POST …/toggle-deleted as the platform admin: archives a live team, restores an archived one. */
export const toggleTeamArchived = async (team: Pick<TeamDetailDto, 'id'>) =>
  apiPost<AdminTeamDto>(await roleSession('admin'), `/api/admin/teams/${team.id}/toggle-deleted`)

/** PUT …/platform-role as the platform admin — never on the seeded admin itself. */
export const setPlatformRole = async (userId: string, role: AssignPlatformRoleRequest['role']) =>
  apiPut<AdminUserDto>(await roleSession('admin'), `/api/admin/users/${userId}/platform-role`, {
    role,
  } satisfies AssignPlatformRoleRequest)

export const ADMIN_DOMAINS_PATH = '/plateforme/domaines'
/** ADMIN_PAGE_SIZE of src/hooks/filters/adminFilters.ts. */
const ADMIN_PAGE_SIZE = 20

/** Every domain, newest first — as the platform domain list orders them. */
const allDomains = async () =>
  (
    await apiGet<AdminDomainListResponse>(await roleSession('admin'), '/api/admin/domains', {
      size: 100,
    })
  ).domains

/** The domain of `host`, as the platform admin reads it. */
export async function adminDomain(host: string): Promise<AdminDomainDto> {
  const domain = (await allDomains()).find((d) => d.domain === host)
  if (!domain) throw new Error(`no domain ${host}`)
  return domain
}

/**
 * The page of the platform domain list holding `host` (`?p=`): the list is the newest first, and
 * the oldest — `localhost` — moves to a later page as domains pile up across runs.
 */
export async function adminDomainsPathOf(host: string): Promise<string> {
  const index = (await allDomains()).findIndex((d) => d.domain === host)
  if (index < 0) throw new Error(`no domain ${host}`)
  const page = Math.floor(index / ADMIN_PAGE_SIZE) + 1
  return page === 1 ? ADMIN_DOMAINS_PATH : `${ADMIN_DOMAINS_PATH}?p=${page}`
}

/** The row of a platform table (domains, aliases, GPS credentials…) holding `cell`, exactly. */
export const rowWithCell = (scope: Locator, cell: string): Locator =>
  scope
    .getByRole('row')
    // `has` resolves from the row: a page-rooted locator, not one under `scope`.
    .filter({ has: scope.page().getByRole('cell', { name: cell, exact: true }) })

/**
 * A GPS credential's row in the domain form, by its client id. Not {@link rowWithCell}: a Garmin
 * cell also names its protocol under the client id (docs/LEDGER_*.md API-62).
 */
export const credentialRow = (scope: Locator, clientId: string): Locator =>
  scope.getByRole('row').filter({ has: scope.page().getByText(clientId, { exact: true }) })

/** A hostname under `.localhost` nobody else uses — Chromium resolves it to the loopback. */
export const uniqueLocalHost = (label: string) =>
  `${label}-${Date.now().toString(36)}${Math.random().toString(36).slice(2, 6)}.localhost`

export const aliasesPath = (domain: Pick<AdminDomainDto, 'id'>) =>
  `/api/admin/domains/${domain.id}/aliases`

/** The aliases of `domain` (soft-deleted ones excluded), as the platform admin. */
export const aliasesOf = async (domain: Pick<AdminDomainDto, 'id'>) =>
  apiGet<AdminDomainAliasDto[]>(await roleSession('admin'), aliasesPath(domain))

/** DELETE of an alias as the platform admin — a cleanup, whatever the test left. */
export const deleteAlias = async (domain: Pick<AdminDomainDto, 'id'>, aliasId: string) =>
  apiDelete(await roleSession('admin'), `${aliasesPath(domain)}/${aliasId}`)

export const gpsCredentialsOf = async (domain: Pick<AdminDomainDto, 'id'>) =>
  apiGet<AdminGpsCredentialDto[]>(
    await roleSession('admin'),
    `/api/admin/domains/${domain.id}/gps-credentials`
  )

/**
 * A domain for this test alone to edit — domains cannot be deleted, so it is one per project and
 * parallel slot (`renomme-e2e-desktop-0.localhost`), created on first use, and put back to a known
 * state each time: the given `settings`, and exactly the GPS `credentials` given.
 */
export async function scratchDomain(
  settings: Omit<UpdateDomainRequest, 'baseUrl'>,
  credentials: CreateGpsCredentialRequest[]
): Promise<{ domain: AdminDomainDto; credentials: AdminGpsCredentialDto[] }> {
  const admin = await roleSession('admin')
  const { project, parallelIndex } = test.info()
  const host = `renomme-e2e-${project.name}-${parallelIndex}.localhost`
  const baseUrl = originOf(host)
  let domain = (await allDomains()).find((d) => d.domain === host)
  domain ??= await apiPost<AdminDomainDto>(admin, '/api/admin/domains', {
    domain: host,
    ...settings,
    baseUrl,
  } satisfies CreateDomainRequest)
  domain = await apiPut<AdminDomainDto>(admin, `/api/admin/domains/${domain.id}`, {
    ...settings,
    baseUrl,
  } satisfies UpdateDomainRequest)
  const credentialsPath = `/api/admin/domains/${domain.id}/gps-credentials`
  for (const old of await gpsCredentialsOf(domain))
    await apiDelete(admin, `${credentialsPath}/${old.id}`)
  const created: AdminGpsCredentialDto[] = []
  for (const credential of credentials)
    created.push(await apiPost<AdminGpsCredentialDto>(admin, credentialsPath, credential))
  return { domain, credentials: created }
}
