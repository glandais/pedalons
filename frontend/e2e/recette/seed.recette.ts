import { mkdirSync } from 'node:fs'
import { dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { test } from '@playwright/test'
import type { TeamDetailDto } from '../../src/api/dto'
import {
  ApiError,
  apiGetOrNull,
  loginWithPassword,
  register,
  writeFileAtomic,
  type AuthResponse,
} from '../support/api'
import { loginAs } from '../support/data'
import { buildDataset, type DatasetAccounts } from '../support/routes-render'
import { stack } from '../support/stack'

/**
 * The data of a manual (or agent-driven) recette on the e2e stack — `scripts/recette.sh seed`.
 *
 * Unlike the suite's throwaway users, these accounts are stable: the same address and password on
 * every run, so whoever tests can sign in by hand, on the web, in Chrome on a phone or in the app.
 * They live on the reserved `.test` domain and mail only ever reaches mailpit, so nothing here is
 * a secret. The platform admin is the stack's bootstrap one (global-setup gives it a password).
 *
 * Idempotent: accounts are signed in when they exist, the team and its content are built once —
 * a later run only rewrites the accounts file. `scripts/e2e.sh reset` empties everything.
 */

const PASSWORD = 'recette-pedalons'
const TEAM_NAME = 'Équipe Recette'
// What the backend derives from TEAM_NAME: how a previous run's team is found.
const TEAM_SLUG = 'equipe-recette'

const ACCOUNTS = {
  owner: { email: 'fondation@recette.test', displayName: 'Camille Fondation' },
  teamAdmin: { email: 'admin-equipe@recette.test', displayName: 'Dominique Admin' },
  organizer: { email: 'organisation@recette.test', displayName: 'Sacha Organisation' },
  member: { email: 'membre@recette.test', displayName: 'Alex Membre' },
  outsider: { email: 'hors-equipe@recette.test', displayName: 'Charlie Hors-Équipe' },
} as const

/** Where scripts/recette.sh reads the accounts back: the gitignored `.e2e/` of the repository. */
const OUTPUT = fileURLToPath(new URL('../../../.e2e/recette.json', import.meta.url))

test('recette: comptes et équipe', async () => {
  test.setTimeout(180_000)
  const sessions = Object.fromEntries(
    await Promise.all(
      Object.entries(ACCOUNTS).map(async ([role, account]) => [role, await signedIn(account)])
    )
  ) as Record<keyof typeof ACCOUNTS, AuthResponse>
  const admin = await loginAs('admin')
  const accounts: DatasetAccounts = { ...sessions, platformAdmin: admin }

  let team = await apiGetOrNull<TeamDetailDto>(sessions.owner, `/api/teams/${TEAM_SLUG}`)
  let built = false
  if (!team) {
    const dataset = await buildDataset('Recette', { accounts, teamName: TEAM_NAME })
    team = dataset.team
    built = true
  }

  const roles = {
    platformAdmin: { email: stack.adminEmail, password: admin.password, role: 'admin plateforme' },
    owner: { ...ACCOUNTS.owner, password: PASSWORD, role: "fondation de l'équipe (ADMIN)" },
    teamAdmin: { ...ACCOUNTS.teamAdmin, password: PASSWORD, role: 'admin de l’équipe' },
    organizer: { ...ACCOUNTS.organizer, password: PASSWORD, role: 'organisation (ORGANIZER)' },
    member: { ...ACCOUNTS.member, password: PASSWORD, role: 'membre (MEMBER)' },
    outsider: { ...ACCOUNTS.outsider, password: PASSWORD, role: 'connecté, hors équipe' },
  }
  mkdirSync(dirname(OUTPUT), { recursive: true })
  writeFileAtomic(
    OUTPUT,
    JSON.stringify(
      {
        app: stack.baseURL,
        mailpit: stack.mailpitURL,
        team: { name: team.name, slug: team.slug, url: `${stack.baseURL}/equipes/${team.slug}` },
        accounts: roles,
      },
      null,
      2
    ) + '\n'
  )
  console.log(
    `recette: équipe ${team.slug} ${built ? 'créée' : 'déjà là'} — comptes dans ${OUTPUT}`
  )
})

/** Signed in by password; signed up first (register + mailed link) when the address is new. */
async function signedIn(account: { email: string; displayName: string }): Promise<AuthResponse> {
  try {
    return await loginWithPassword(account.email, PASSWORD)
  } catch (e) {
    if (!(e instanceof ApiError) || e.status !== 400) throw e
  }
  return register({ ...account, password: PASSWORD })
}
