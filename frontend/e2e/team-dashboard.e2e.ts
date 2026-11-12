import type { Page } from '@playwright/test'
import type { PostDto, RideDto, TeamDashboardDto, TeamDetailDto } from '../src/api/dto'
import { newAd } from './support/ads'
import { ApiError, apiGet, type AuthResponse } from './support/api'
import { addMember, newTeam, newUser, signIn } from './support/data'
import { expect, test, unique } from './support/fixtures'
import { report } from './support/moderation'
import { newPost } from './support/posts'
import { joinGroup, newRide } from './support/rides'

/**
 * The team dashboard (GET /api/teams/{slug}/dashboard): the team page for everyone (API-86), whose
 * blocks follow the viewer's role — the public part (upcoming rides, latest posts, new routes) for
 * a visitor, the member sections on top for a member, « À traiter » and the templates for
 * organizers and admins, « Administration » for admins only. The former feed gave way to the
 * « Agenda » and the « Publications » (WEB-68): its addresses redirect there.
 */

interface World {
  team: TeamDetailDto
  admin: AuthResponse & { password: string }
  organizer: AuthResponse & { password: string }
  member: AuthResponse & { password: string }
  outsider: AuthResponse & { password: string }
  reporter: AuthResponse & { password: string }
  fullRide: RideDto
  draftRide: RideDto
  post: PostDto
  adName: string
}

async function buildWorld(): Promise<World> {
  const admin = await newUser('dashboard admin')
  const organizer = await newUser('dashboard organizer')
  const member = await newUser('dashboard member')
  const outsider = await newUser('dashboard outsider')
  const reporter = await newUser('dashboard reporter')
  const team = await newTeam(admin, unique('Tableau de bord'), { addMemberAllowed: true })
  await addMember(admin, team.slug, organizer, 'ORGANIZER')
  await addMember(admin, team.slug, member, 'MEMBER')
  await addMember(admin, team.slug, reporter, 'MEMBER')

  // One seat: the member's registration fills the group, so the ride is on the « complet » tile,
  // in the member's « Vos prochaines sorties », and — having no route — on « sans parcours ».
  const fullRide = await newRide(admin, team.slug, unique('Sortie complète'), {
    groups: [{ name: 'Groupe A', maxParticipants: 1 }],
  })
  await joinGroup(member, team.slug, fullRide, 'Groupe A')
  const draftRide = await newRide(organizer, team.slug, unique('Sortie brouillon'), {
    status: 'DRAFT',
  })

  const post = await newPost(admin, team.slug, unique('Publication du tableau'))
  // Reported by a member of its own: the listings hide from a caller what they reported, so the
  // member, organizer and admin under test must not be the reporter.
  await report(reporter, team.slug, 'POST', post.id, 'SPAM')

  const adName = unique('Annonce sans prix')
  await newAd(member, team.slug, { name: adName, locationDescription: 'Croix-Rousse' })

  return { team, admin, organizer, member, outsider, reporter, fullRide, draftRide, post, adName }
}

const section = (page: Page, name: string) => page.getByRole('region', { name, exact: true })

let world: World
test.beforeAll(async () => {
  world = await buildWorld()
})

test.describe('the dashboard API', () => {
  test('gates each block on the caller role', async () => {
    const asMember = await apiGet<TeamDashboardDto>(
      world.member,
      `/api/teams/${world.team.slug}/dashboard`
    )
    expect(asMember.role).toBe('MEMBER')
    expect(asMember.organizer ?? null).toBeNull()
    expect(asMember.admin ?? null).toBeNull()
    expect(asMember.myUpcoming?.publications.map((p) => p.slug)).toContain(world.fullRide.slug)

    const asOrganizer = await apiGet<TeamDashboardDto>(
      world.organizer,
      `/api/teams/${world.team.slug}/dashboard`
    )
    expect(asOrganizer.role).toBe('ORGANIZER')
    expect(asOrganizer.organizer?.drafts.publications.map((p) => p.slug)).toContain(
      world.draftRide.slug
    )
    expect(asOrganizer.organizer?.ridesWithFullGroup?.publications.map((p) => p.slug)).toContain(
      world.fullRide.slug
    )
    expect(asOrganizer.organizer?.reports.openCount).toBeGreaterThanOrEqual(1)
    expect(asOrganizer.admin ?? null).toBeNull()

    const asAdmin = await apiGet<TeamDashboardDto>(
      world.admin,
      `/api/teams/${world.team.slug}/dashboard`
    )
    expect(asAdmin.role).toBe('ADMIN')
    expect(asAdmin.team.memberCountByRole).toEqual({ admins: 1, organizers: 1, members: 2 })
    expect(asAdmin.admin?.newestMembers.members.length).toBeGreaterThan(0)
  })

  test('refuses a non-member of a members-only team', async () => {
    const error = await apiGet(world.outsider, `/api/teams/${world.team.slug}/dashboard`).then(
      () => null,
      (e: unknown) => e
    )
    expect(error).toBeInstanceOf(ApiError)
    expect((error as ApiError).status).toBe(403)
  })
})

test.describe('the dashboard page', () => {
  test('a member sees the member blocks only', async ({ context, page }) => {
    await signIn(context, world.member)
    await page.goto(`/equipes/${world.team.slug}`)

    const mine = section(page, 'Vos prochaines sorties')
    await expect(mine.getByText(world.fullRide.name)).toBeVisible()
    await expect(section(page, 'Sorties à venir').getByText(world.fullRide.name)).toBeVisible()
    await expect(section(page, 'Dernières publications').getByText(world.post.name)).toBeVisible()
    const ads = section(page, 'Annonces')
    await expect(ads.getByText(world.adName)).toBeVisible()
    await expect(ads.getByText('Prix à négocier')).toBeVisible()
    await expect(ads.getByText('Secteur Croix-Rousse')).toBeVisible()

    await expect(section(page, 'À traiter')).toHaveCount(0)
    await expect(section(page, 'Administration')).toHaveCount(0)
    await expect(section(page, 'Créer depuis un modèle')).toHaveCount(0)
  })

  test('an organizer also sees « À traiter », not the administration', async ({
    context,
    page,
  }) => {
    await signIn(context, world.organizer)
    await page.goto(`/equipes/${world.team.slug}`)

    const todo = section(page, 'À traiter')
    await expect(todo.getByText(world.draftRide.name)).toBeVisible()
    await expect(todo.getByText('Signalement', { exact: true })).toBeVisible()
    await expect(section(page, 'Créer depuis un modèle')).toBeVisible()
    await expect(section(page, 'Administration')).toHaveCount(0)
  })

  test('an admin also sees the administration panel', async ({ context, page }) => {
    await signIn(context, world.admin)
    await page.goto(`/equipes/${world.team.slug}`)

    await expect(section(page, 'À traiter')).toBeVisible()
    const admin = section(page, 'Administration')
    await expect(admin.getByText('1 organisateur')).toBeVisible()
    await expect(admin.getByText(world.member.user.displayName)).toBeVisible()
  })

  test('a visitor of a public team gets the public part of the dashboard (API-86)', async ({
    page,
  }) => {
    // An owner of its own: world.admin already holds the one team a user may create
    // (USER_TEAM_LIMIT_REACHED).
    const owner = await newUser(unique('Propriétaire publique'))
    const team = await newTeam(owner, unique('Équipe publique'), { visibility: 'PUBLIC' })
    const ride = await newRide(owner, team.slug, unique('Sortie publique'), {
      visibility: 'PUBLIC',
    })
    const hidden = await newRide(owner, team.slug, unique('Sortie des membres'))
    const post = await newPost(owner, team.slug, unique('Publication publique'), {
      visibility: 'PUBLIC',
    })

    await page.goto(`/equipes/${team.slug}`)

    await expect(section(page, 'Sorties à venir').getByText(ride.name)).toBeVisible()
    await expect(page.getByText(hidden.name)).toHaveCount(0)
    await expect(section(page, 'Dernières publications').getByText(post.name)).toBeVisible()
    await expect(section(page, 'Vos prochaines sorties')).toHaveCount(0)
    await expect(section(page, 'Annonces')).toHaveCount(0)
    await expect(section(page, 'À traiter')).toHaveCount(0)
    // No calendar for a visitor: the agenda offers its two lists only.
    await page
      .getByRole('navigation', { name: "Navigation de l'équipe" })
      .getByRole('link', { name: 'Agenda', exact: true })
      .click()
    await expect(page.getByText(ride.name).first()).toBeVisible()
    await expect(page.getByRole('radio', { name: 'Calendrier' })).toHaveCount(0)
    await expect(page.getByRole('radio', { name: 'Je participe' })).toHaveCount(0)
  })

  test('the « Agenda » tab lists the rides, not the posts, on its own route', async ({
    context,
    page,
  }) => {
    await signIn(context, world.member)
    await page.goto(`/equipes/${world.team.slug}`)

    const tabs = page.getByRole('navigation', { name: "Navigation de l'équipe" })
    await tabs.getByRole('link', { name: 'Agenda', exact: true }).click()
    await expect(page).toHaveURL(new RegExp(`/equipes/${world.team.slug}/agenda$`))
    await expect(tabs.getByRole('link', { name: 'Agenda', exact: true })).toHaveAttribute(
      'aria-current',
      'page'
    )
    await expect(page.getByRole('heading', { level: 2, name: 'Agenda', exact: true })).toBeVisible()
    await expect(page.getByRole('radio', { name: 'Toutes les dates' })).toBeChecked()
    await expect(page.getByText(world.fullRide.name).first()).toBeVisible()
    await expect(page.getByText(world.post.name)).toHaveCount(0)
  })

  test('the « Publications » tab lists the posts alone', async ({ context, page }) => {
    await signIn(context, world.member)
    await page.goto(`/equipes/${world.team.slug}`)

    const tabs = page.getByRole('navigation', { name: "Navigation de l'équipe" })
    await tabs.getByRole('link', { name: 'Publications', exact: true }).click()
    await expect(page).toHaveURL(new RegExp(`/equipes/${world.team.slug}/articles$`))
    await expect(page.getByText(world.post.name).first()).toBeVisible()
    await expect(page.getByText(world.fullRide.name)).toHaveCount(0)
  })

  test("the dashboard's « Voir tout » open the agenda and the posts", async ({ context, page }) => {
    await signIn(context, world.member)
    await page.goto(`/equipes/${world.team.slug}`)

    await section(page, 'Sorties à venir').getByRole('link', { name: 'Voir tout' }).click()
    await expect(page).toHaveURL(new RegExp(`/equipes/${world.team.slug}/agenda$`))
    await expect(page.getByText(world.fullRide.name).first()).toBeVisible()

    await page.goto(`/equipes/${world.team.slug}`)
    await section(page, 'Vos prochaines sorties').getByRole('link', { name: 'Voir tout' }).click()
    await expect(page).toHaveURL(new RegExp(`/equipes/${world.team.slug}/agenda\\?w=me$`))
    await expect(page.getByRole('radio', { name: 'Je participe' })).toBeChecked()
    await expect(page.getByText(world.fullRide.name).first()).toBeVisible()

    await page.goto(`/equipes/${world.team.slug}`)
    await section(page, 'Dernières publications').getByRole('link', { name: 'Voir tout' }).click()
    await expect(page).toHaveURL(new RegExp(`/equipes/${world.team.slug}/articles$`))
  })

  test('the former feed addresses redirect (WEB-68, plan §5)', async ({ context, page }) => {
    await signIn(context, world.member)
    const team = `/equipes/${world.team.slug}`

    await page.goto(`${team}?tab=publications`)
    await expect(page).toHaveURL(new RegExp(`${team}$`))
    await expect(section(page, 'Vos prochaines sorties')).toBeVisible()

    await page.goto(`${team}?tab=publications&type=post`)
    await expect(page).toHaveURL(new RegExp(`${team}/articles$`))

    await page.goto(`${team}?tab=publications&type=ride&w=me`)
    await expect(page).toHaveURL(new RegExp(`${team}/agenda\\?type=ride&w=me$`))

    await page.goto(`${team}/sorties?w=upcoming`)
    await expect(page).toHaveURL(new RegExp(`${team}/agenda$`))

    await page.goto(`${team}/voyages`)
    await expect(page).toHaveURL(new RegExp(`${team}/agenda\\?type=trip$`))
  })
})
