import { signIn } from './support/data'
import { expect, test } from './support/fixtures'
import { directoryTeam, listMembers, setMemberDirectory } from './support/member-directory'

/**
 * The member directory, role × setting (docs/LEDGER_*.md WEB-20, « Trombinoscope, la matrice rôle ×
 * réglage »).
 *
 * The matrix is asserted where both clients get it from, the `GET /api/teams/{slug}/members`
 * endpoint, with one real account per role. The web surfaces that depend on it (the members'
 * directory page `/equipes/{slug}/membres` — docs/LEDGER_*.md WEB-1 —, the ride editor's leader
 * picker, the admin member screen, the team navigation) are driven through the browser.
 *
 * None of the actors is the seeded platform admin: a platform admin bypasses the access checker.
 */

test.describe('member directory — API matrix', () => {
  test('closed directory: a plain member is refused with 403, the team admin is not', async () => {
    const t = await directoryTeam(false)

    // The endpoint answers for this team — the 403 below is about the caller, not a broken team.
    const asAdmin = await listMembers(t.admin, t.team.slug)
    expect(asAdmin.status).toBe(200)

    const asMember = await listMembers(t.member, t.team.slug)
    expect(asMember.status).toBe(403)
  })

  test('closed directory: an organizer gets the names, without roles nor join dates', async () => {
    const t = await directoryTeam(false)

    const { status, body } = await listMembers(t.organizer, t.team.slug)
    expect(status).toBe(200)
    const ids = body!.members.map((m) => m.user.id)
    expect(ids).toEqual(
      expect.arrayContaining([t.admin.user.id, t.organizer.user.id, t.member.user.id])
    )
    expect(ids).toContain(t.teammate.user.id)
    for (const m of body!.members) {
      expect(m.role ?? null, `role of ${m.user.displayName}`).toBeNull()
      expect(m.joinedAt ?? null, `joinedAt of ${m.user.displayName}`).toBeNull()
    }

    // The team admin, on the same closed team, does get them — so the nulls above are a
    // redaction, not missing data.
    const asAdmin = await listMembers(t.admin, t.team.slug)
    const teammate = asAdmin.body!.members.find((m) => m.user.id === t.teammate.user.id)
    expect(teammate?.role).toBe('MEMBER')
    expect(teammate?.joinedAt).toBeTruthy()
  })

  test('opening the directory lets a plain member see everything', async () => {
    const t = await directoryTeam(false)
    expect((await listMembers(t.member, t.team.slug)).status).toBe(403)

    await setMemberDirectory(t.admin, t.team, true)

    const { status, body } = await listMembers(t.member, t.team.slug)
    expect(status).toBe(200)
    const byId = new Map(body!.members.map((m) => [m.user.id, m]))
    expect(byId.get(t.admin.user.id)?.role).toBe('ADMIN')
    expect(byId.get(t.organizer.user.id)?.role).toBe('ORGANIZER')
    expect(byId.get(t.teammate.user.id)?.role).toBe('MEMBER')
    for (const m of body!.members)
      expect(m.joinedAt, `joinedAt of ${m.user.displayName}`).toBeTruthy()
  })

  test('?search= with a teammate’s exact e-mail finds nothing for a member or an organizer, and finds them for a team admin', async () => {
    const t = await directoryTeam(true)
    const email = t.teammate.user.email
    const found = (r: Awaited<ReturnType<typeof listMembers>>) =>
      r.body!.members.map((m) => m.user.id)

    // Search itself works for the member: the teammate's display name finds them. Without this,
    // an empty result for the e-mail would prove nothing.
    const byName = await listMembers(t.member, t.team.slug, t.teammate.user.displayName)
    expect(byName.status).toBe(200)
    expect(found(byName)).toContain(t.teammate.user.id)

    const asMember = await listMembers(t.member, t.team.slug, email)
    expect(asMember.status).toBe(200)
    expect(asMember.body!.members).toEqual([])
    expect(asMember.body!.total).toBe(0)

    const asOrganizer = await listMembers(t.organizer, t.team.slug, email)
    expect(asOrganizer.status).toBe(200)
    expect(asOrganizer.body!.members).toEqual([])
    expect(asOrganizer.body!.total).toBe(0)

    const asAdmin = await listMembers(t.admin, t.team.slug, email)
    expect(asAdmin.status).toBe(200)
    expect(found(asAdmin)).toEqual([t.teammate.user.id])
  })

  test('?search= by e-mail stays closed to an organizer on a closed directory', async () => {
    const t = await directoryTeam(false)
    const email = t.teammate.user.email

    // The organizer can list (and search) this closed roster at all…
    const byName = await listMembers(t.organizer, t.team.slug, t.teammate.user.displayName)
    expect(byName.status).toBe(200)
    expect(byName.body!.members.map((m) => m.user.id)).toContain(t.teammate.user.id)

    // …but the address matches nothing.
    const byEmail = await listMembers(t.organizer, t.team.slug, email)
    expect(byEmail.status).toBe(200)
    expect(byEmail.body!.total).toBe(0)
  })
})

test.describe('member directory — web', () => {
  test('closed directory: a plain member has no « Membres » entry and is sent away from the member screen', async ({
    browser,
  }) => {
    const t = await directoryTeam(false)
    const context = await browser.newContext()
    try {
      await signIn(context, t.member)
      const page = await context.newPage()

      await page.goto(`/equipes/${t.team.slug}`)
      await expect(page.getByRole('heading', { level: 1, name: t.team.name })).toBeVisible()
      const teamNav = page.getByRole('navigation', { name: /équipe/i })
      await expect(teamNav.getByRole('link').first()).toBeVisible()
      await expect(teamNav.getByRole('link', { name: 'Membres' })).toHaveCount(0)

      // Forcing the admin member screen lands back on the team, without the roster.
      await page.goto(`/equipes/${t.team.slug}/admin/membres`)
      await expect(page).toHaveURL(new RegExp(`/equipes/${t.team.slug}$`))
      await expect(page.getByRole('heading', { level: 1, name: t.team.name })).toBeVisible()
      await expect(page.getByText(t.teammate.user.displayName)).toHaveCount(0)
    } finally {
      await context.close()
    }
  })

  test('closed directory: the ride editor’s leader picker still offers an organizer the team’s members', async ({
    browser,
  }) => {
    const t = await directoryTeam(false)
    const context = await browser.newContext()
    try {
      await signIn(context, t.organizer)
      const page = await context.newPage()
      await page.goto(`/equipes/${t.team.slug}/sorties/nouvelle`)

      const picker = page.getByPlaceholder("Rechercher un membre de l'équipe...").first()
      await expect(picker).toBeVisible()
      const option = page.getByText(t.teammate.user.displayName, { exact: true })
      // Typed again until the suggestion shows: a keystroke before hydration is lost.
      await expect(async () => {
        await picker.fill('', { timeout: 3_000 })
        await picker.fill(t.teammate.user.displayName, { timeout: 3_000 })
        await expect(option).toBeVisible({ timeout: 3_000 })
      }).toPass()

      await option.click()
      // Picked: the leader row now names them and offers to clear the choice.
      await expect(page.getByRole('button', { name: 'Retirer' })).toBeVisible()
      await expect(option).toBeVisible()
      await expect(picker).toHaveCount(0)
    } finally {
      await context.close()
    }
  })

  test('a team admin finds a teammate by exact e-mail on the member screen, where the others are filtered out', async ({
    browser,
  }) => {
    const t = await directoryTeam(false)
    const context = await browser.newContext()
    try {
      await signIn(context, t.admin)
      const page = await context.newPage()
      await page.goto(`/equipes/${t.team.slug}/admin/membres`)
      await expect(
        page.getByRole('heading', { name: 'Gestion des membres', level: 2 })
      ).toBeVisible()
      // The whole roster first — the filtered view below is then a narrowing, not an empty page.
      await expect(page.getByText(t.member.user.displayName, { exact: true })).toBeVisible()

      const search = page.getByRole('searchbox', { name: 'Rechercher' })
      await expect(async () => {
        await search.fill(t.teammate.user.email, { timeout: 3_000 })
        await expect(page).toHaveURL(/[?&]q=/, { timeout: 3_000 })
      }).toPass()
      await expect(page.getByText(t.member.user.displayName, { exact: true })).toHaveCount(0)
      await expect(page.getByText(t.organizer.user.displayName, { exact: true })).toHaveCount(0)
      await expect(page.getByText(t.teammate.user.displayName, { exact: true })).toBeVisible()
    } finally {
      await context.close()
    }
  })

  test('closed directory: the « À propos » count is not a link for a plain member, and the directory page shows the refusal', async ({
    browser,
  }) => {
    const t = await directoryTeam(false)
    const context = await browser.newContext()
    try {
      await signIn(context, t.member)
      const page = await context.newPage()

      await page.goto(`/equipes/${t.team.slug}/a-propos`)
      await expect(page.getByRole('heading', { name: "À propos de l'équipe" })).toBeVisible()
      await expect(page.getByRole('link', { name: /Membres/ })).toHaveCount(0)

      // Typed by hand: the page renders the server's 403, and no name leaks around it.
      await page.goto(`/equipes/${t.team.slug}/membres`)
      await expect(page.getByText('Liste des membres non partagée')).toBeVisible()
      await expect(page.getByText(t.teammate.user.displayName, { exact: true })).toHaveCount(0)
    } finally {
      await context.close()
    }
  })

  test('closed directory: an organizer follows the « À propos » link to the names, without roles nor a role filter', async ({
    browser,
  }) => {
    const t = await directoryTeam(false)
    const context = await browser.newContext()
    try {
      await signIn(context, t.organizer)
      const page = await context.newPage()

      await page.goto(`/equipes/${t.team.slug}/a-propos`)
      // The count of « À propos » (it carries a number), not the « Membres » tab of the team row
      // (WEB-112), which sits in the same landmark.
      await page
        .getByRole('link', { name: /Membres/ })
        .filter({ hasText: /\d/ })
        .click()
      await expect(page).toHaveURL(new RegExp(`/equipes/${t.team.slug}/membres$`))
      await expect(page.getByRole('heading', { name: 'Membres', level: 2 })).toBeVisible()
      await expect(page.getByText(t.teammate.user.displayName, { exact: true })).toBeVisible()

      // The API sent no role: no badge, no join date, no filter on what cannot be seen.
      await expect(page.getByText('Organisateur', { exact: true })).toHaveCount(0)
      await expect(page.getByText(/^A rejoint le/)).toHaveCount(0)
      await expect(page.getByRole('textbox', { name: 'Rôle' })).toHaveCount(0)
      // And none of the admin screen's actions.
      await expect(page.getByRole('button', { name: 'Retirer' })).toHaveCount(0)
      await expect(page.getByRole('button', { name: 'Inviter par e-mail' })).toHaveCount(0)
    } finally {
      await context.close()
    }
  })

  test('open directory: a plain member reads every member with their role', async ({ browser }) => {
    const t = await directoryTeam(true)
    const context = await browser.newContext()
    try {
      await signIn(context, t.member)
      const page = await context.newPage()

      await page.goto(`/equipes/${t.team.slug}/a-propos`)
      // An open directory earns a plain member the « Membres » tab too (WEB-112).
      const teamNav = page.getByRole('navigation', { name: /équipe/i })
      await expect(teamNav.getByRole('link', { name: 'Membres', exact: true })).toBeVisible()
      // The count of « À propos » (it carries a number), not the « Membres » tab of the team row
      // (WEB-112), which sits in the same landmark.
      await page
        .getByRole('link', { name: /Membres/ })
        .filter({ hasText: /\d/ })
        .click()
      await expect(page).toHaveURL(new RegExp(`/equipes/${t.team.slug}/membres$`))
      await expect(page.getByText(t.organizer.user.displayName, { exact: true })).toBeVisible()
      await expect(page.getByText('Organisateur', { exact: true }).first()).toBeVisible()
      await expect(page.getByRole('button', { name: 'Retirer' })).toHaveCount(0)
    } finally {
      await context.close()
    }
  })
})
