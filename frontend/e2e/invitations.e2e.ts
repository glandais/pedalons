import type { Page, Response } from '@playwright/test'
import type { AcceptInvitationRequest, MemberDto, TeamInvitationDto } from '../src/api/dto'
import { apiContext, expectOk, loginWithPassword, type AuthResponse } from './support/api'
import { freshAddress, newTeam, newUser, signIn } from './support/data'
import { expect, test, unique } from './support/fixtures'
import { hydrated } from './support/ui'
import {
  invitationTokenIn,
  inviteByApi,
  membershipsOf,
  previewInvitation,
} from './support/invitations'
import { linkTokenIn, mailbox, waitForNewMail } from './support/mailpit'

/**
 * E-mail invitations, docs/LEDGER_*.md WEB-21 and WEB-22 — the organiser's screens (invite, pending list, resend,
 * revoke) and the invitee's (acceptance page, wrong account, replay, sign-up through the link).
 *
 * Every test builds its own owner and team: the inviter is rate-limited (20 per hour), and the
 * suite runs on two projects in parallel.
 */

// Only the template chosen differs between the two mails. Both languages are accepted: the
// account holder's mail follows their own language setting, not the inviter's.
const HAS_ACCOUNT = /Votre compte .* existe déjà|You already have an? .* account/
const NO_ACCOUNT = /Vous n'avez pas encore de compte|You do not have an account yet/

async function openMembersAdmin(page: Page, teamSlug: string) {
  await page.goto(`/equipes/${teamSlug}/admin/membres`)
  await expect(
    page.getByRole('heading', { name: 'Gestion des membres', exact: true })
  ).toBeVisible()
}

/** Invites through the members screen's modal; returns the POST's response. */
async function inviteThroughUi(page: Page, teamSlug: string, email: string): Promise<Response> {
  const invite = page.getByRole('button', { name: 'Inviter par e-mail' })
  await hydrated(invite)
  await invite.click()
  const dialog = page.getByRole('dialog', { name: 'Inviter par e-mail' })
  await dialog.getByRole('textbox', { name: 'Adresse e-mail' }).fill(email)
  const [response] = await Promise.all([
    page.waitForResponse(
      (r) =>
        r.request().method() === 'POST' && r.url().endsWith(`/api/teams/${teamSlug}/invitations`)
    ),
    dialog.getByRole('button', { name: "Envoyer l'invitation" }).click(),
  ])
  await expect(dialog).toBeHidden()
  return response
}

/** The pending-invitations table row holding `email`. */
function pendingRow(page: Page, email: string) {
  return page.getByRole('row').filter({ has: page.getByRole('cell', { name: email, exact: true }) })
}

/** Redeems `token` as `invitee`; the status, and the membership when it answered 2xx. */
async function acceptByApi(invitee: AuthResponse, token: string) {
  const api = await apiContext(invitee.accessToken)
  try {
    const request: AcceptInvitationRequest = { token }
    const response = await api.post('/api/invitations/accept', { data: request })
    return { status: response.status(), member: await expectOk<MemberDto>(response) }
  } finally {
    await api.dispose()
  }
}

test.describe('organiser side', () => {
  test('an address with an account and one without get the same response and screen; only the mail differs', async ({
    page,
    context,
  }) => {
    const owner = await newUser('Inviting owner')
    const team = await newTeam(owner, unique('Invitations identiques'), { addMemberAllowed: true })
    const holder = await newUser('Account holder')
    const stranger = freshAddress('no-account')

    await signIn(context, owner)
    await openMembersAdmin(page, team.slug)

    const observed: {
      email: string
      status: number
      body: TeamInvitationDto
      toast: string
      row: string
      mail: string
    }[] = []
    for (const email of [holder.user.email, stranger]) {
      const seen = await mailbox(email)
      const response = await inviteThroughUi(page, team.slug, email)
      const toast = page.getByText(`Invitation envoyée à ${email}.`, { exact: true })
      await expect(toast).toBeVisible()
      const row = pendingRow(page, email)
      await expect(row).toBeVisible()
      observed.push({
        email,
        status: response.status(),
        body: (await response.json()) as TeamInvitationDto,
        toast: (await toast.innerText()).replace(email, '<email>'),
        row: (await row.innerText()).replace(email, '<email>'),
        mail: await waitForNewMail(email, seen),
      })
    }
    const [withAccount, withoutAccount] = observed

    // The API: same status, same body once the per-invitation values are set aside.
    expect(withAccount.status).toBe(201)
    expect(withoutAccount.status).toBe(withAccount.status)
    const neutral = (o: (typeof observed)[number]) => ({
      ...o.body,
      id: '<id>',
      email: o.body.email === o.email ? '<email>' : o.body.email,
      createdAt: '<createdAt>',
      expiresAt: '<expiresAt>',
    })
    expect(neutral(withoutAccount)).toEqual(neutral(withAccount))
    expect(withAccount.body.status).toBe('PENDING')

    // The screen: the same confirmation and the same pending row, address aside.
    expect(withoutAccount.toast).toBe(withAccount.toast)
    expect(withoutAccount.row).toBe(withAccount.row)

    // The mail is the only place the two differ.
    expect(withAccount.mail).toMatch(HAS_ACCOUNT)
    expect(withAccount.mail).not.toMatch(NO_ACCOUNT)
    expect(withoutAccount.mail).toMatch(NO_ACCOUNT)
    expect(withoutAccount.mail).not.toMatch(HAS_ACCOUNT)
    invitationTokenIn(withAccount.mail)
    invitationTokenIn(withoutAccount.mail)

    // Both wait in the pending list — after a reload too, so it is the server's list, not a cache.
    await page.reload()
    await expect(page.getByRole('heading', { name: 'Invitations en attente' })).toBeVisible()
    await expect(pendingRow(page, holder.user.email)).toBeVisible()
    await expect(pendingRow(page, stranger)).toBeVisible()
  })

  test('« Renvoyer » replaces the token: the old link stops working, the new one works', async ({
    page,
    context,
  }) => {
    const owner = await newUser('Resending owner')
    const team = await newTeam(owner, unique('Invitations renvoi'), { addMemberAllowed: true })
    const email = freshAddress('resend')
    const first = await inviteByApi(owner, team.slug, email)
    expect((await previewInvitation(first.token)).redeemable).toBe(true)

    await signIn(context, owner)
    await openMembersAdmin(page, team.slug)
    const row = pendingRow(page, email)
    await expect(row).toBeVisible()

    const seen = await mailbox(email)
    await hydrated(row.getByRole('button', { name: 'Renvoyer' }))
    await row.getByRole('button', { name: 'Renvoyer' }).click()
    await expect(page.getByText(`Invitation envoyée à ${email}.`, { exact: true })).toBeVisible()
    const second = invitationTokenIn(await waitForNewMail(email, seen))
    expect(second).not.toBe(first.token)

    // Still one pending invitation for the address: replaced, not duplicated.
    await expect(pendingRow(page, email)).toHaveCount(1)

    const old = await previewInvitation(first.token)
    expect(old.redeemable).toBe(false)
    expect(old.status).toBe('REVOKED')
    expect((await previewInvitation(second)).redeemable).toBe(true)

    // And what the invitee sees on each link.
    await context.clearCookies()
    await page.goto(`/invitation?token=${first.token}`)
    await expect(page.getByRole('heading', { name: new RegExp(team.name) })).toBeVisible()
    await expect(
      page.getByText("Cette invitation n'est plus valide.", { exact: false })
    ).toBeVisible()
    await expect(page.getByRole('main').getByRole('link', { name: 'Se connecter' })).toHaveCount(0)

    await page.goto(`/invitation?token=${second}`)
    await expect(page.getByRole('heading', { name: new RegExp(team.name) })).toBeVisible()
    await expect(page.getByRole('main').getByRole('link', { name: 'Se connecter' })).toBeVisible()
    await expect(
      page.getByText("Cette invitation n'est plus valide.", { exact: false })
    ).toHaveCount(0)
  })

  test('« Annuler » removes the invitation from the pending list and kills its link', async ({
    page,
    context,
  }) => {
    const owner = await newUser('Revoking owner')
    const team = await newTeam(owner, unique('Invitations annulation'), { addMemberAllowed: true })
    const kept = freshAddress('kept')
    const revoked = freshAddress('revoked')
    await inviteByApi(owner, team.slug, kept)
    const { token } = await inviteByApi(owner, team.slug, revoked)

    await signIn(context, owner)
    await openMembersAdmin(page, team.slug)
    await expect(pendingRow(page, kept)).toBeVisible()
    const revoke = pendingRow(page, revoked).getByRole('button', { name: "Annuler l'invitation" })
    await hydrated(revoke)
    await revoke.click()

    const dialog = page.getByRole('dialog')
    await expect(dialog.getByText(`Annuler l'invitation envoyée à ${revoked} ?`)).toBeVisible()
    await dialog.getByRole('button', { name: "Annuler l'invitation" }).click()

    await expect(page.getByText('Invitation annulée.', { exact: true })).toBeVisible()
    await expect(pendingRow(page, revoked)).toHaveCount(0)
    await expect(pendingRow(page, kept)).toBeVisible()

    await page.reload()
    await expect(pendingRow(page, kept)).toBeVisible()
    await expect(pendingRow(page, revoked)).toHaveCount(0)

    const preview = await previewInvitation(token)
    expect(preview.status).toBe('REVOKED')
    expect(preview.redeemable).toBe(false)
  })
})

test.describe('invitee side', () => {
  test('accepting from another account: dedicated message, and no membership for either', async ({
    page,
    context,
  }) => {
    const owner = await newUser('Owner mismatch')
    const team = await newTeam(owner, unique('Invitations mauvais compte'), {
      addMemberAllowed: true,
    })
    const invitee = await newUser('Invited one')
    const intruder = await newUser('Someone else')
    const { token } = await inviteByApi(owner, team.slug, invitee.user.email)

    await signIn(context, intruder)
    await page.goto(`/invitation?token=${token}`)
    await expect(
      page.getByRole('heading', { name: `Owner mismatch vous invite à rejoindre ${team.name}` })
    ).toBeVisible()
    await hydrated(page.getByRole('button', { name: "Rejoindre l'équipe" }))
    await page.getByRole('button', { name: "Rejoindre l'équipe" }).click()

    await expect(page.getByRole('heading', { name: 'Invitation indisponible' })).toBeVisible()
    await expect(
      page
        .getByRole('main')
        .getByText("Cette invitation est adressée à quelqu'un d'autre.", { exact: false })
    ).toBeVisible()

    expect(await membershipsOf(owner, team.slug, intruder.user.id)).toHaveLength(0)
    expect(await membershipsOf(owner, team.slug, invitee.user.id)).toHaveLength(0)
    // The stranger's attempt did not consume the invitation.
    expect((await previewInvitation(token)).redeemable).toBe(true)
  })

  test('accepting from another account: « se déconnecter » leads back to the invitation, which the invited account then accepts', async ({
    page,
    context,
  }) => {
    // The error state offers « Se déconnecter et utiliser un autre compte », and signing out
    // reloads the invitation itself — logout() used to reload the login page, without the
    // invitation to come back to (fixed 2026-09-25).
    const owner = await newUser('Owner switch')
    const team = await newTeam(owner, unique('Invitations deconnexion'), { addMemberAllowed: true })
    const invitee = await newUser('Invited two')
    const intruder = await newUser('Someone other')
    const { token } = await inviteByApi(owner, team.slug, invitee.user.email)

    await signIn(context, intruder)
    await page.goto(`/invitation?token=${token}`)
    await expect(
      page.getByRole('heading', { name: `Owner switch vous invite à rejoindre ${team.name}` }),
      'precondition: the invitation page is ready'
    ).toBeVisible()
    await hydrated(page.getByRole('button', { name: "Rejoindre l'équipe" }))
    await page.getByRole('button', { name: "Rejoindre l'équipe" }).click()
    await expect(
      page
        .getByText("Cette invitation est adressée à quelqu'un d'autre.", { exact: false })
        .first(),
      'precondition: the accept was refused as addressed to someone else'
    ).toBeVisible()

    await page
      .getByRole('main')
      .getByRole('button', { name: /se déconnecter/i })
      .click()
    // Signed out, back on the same invitation, now offered a login…
    await expect(page).toHaveURL(new RegExp(`/invitation\\?token=${token}$`))
    const signInLink = page.getByRole('main').getByRole('link', { name: 'Se connecter' })
    await expect(signInLink).toBeVisible()
    expect((await context.cookies()).some((c) => c.name === 'refresh_token' && c.value)).toBe(false)

    // …which returns there once signed in with the invited address.
    await hydrated(signInLink)
    await signInLink.click()
    await page.getByLabel('Adresse e-mail').fill(invitee.user.email)
    await page.getByLabel('Mot de passe').fill(invitee.password)
    await page.getByRole('main').getByRole('button', { name: 'Se connecter', exact: true }).click()
    await expect(page).toHaveURL(new RegExp(`/invitation\\?token=${token}$`))
    await page.getByRole('button', { name: "Rejoindre l'équipe" }).click()
    await expect(page).toHaveURL(new RegExp(`/equipes/${team.slug}$`))
    expect(await membershipsOf(owner, team.slug, invitee.user.id)).toHaveLength(1)
    expect(await membershipsOf(owner, team.slug, intruder.user.id)).toHaveLength(0)
  })

  test('accepting twice through the API: no error, a single membership', async () => {
    const owner = await newUser('Owner twice')
    const team = await newTeam(owner, unique('Invitations deux fois'), { addMemberAllowed: true })
    const invitee = await newUser('Invited twice')
    const { token } = await inviteByApi(owner, team.slug, invitee.user.email)

    const { member: first } = await acceptByApi(invitee, token)
    // expectOk inside acceptByApi throws on any error status: the replay must be a plain 200.
    const { status, member: second } = await acceptByApi(invitee, token)
    expect(status).toBe(200)

    expect(second.id).toBe(first.id)
    expect(second.role).toBe('MEMBER')
    const memberships = await membershipsOf(owner, team.slug, invitee.user.id)
    expect(memberships).toHaveLength(1)
    expect(memberships[0].id).toBe(first.id)
  })

  test('joining through the link, then replaying its token: the same single membership', async ({
    page,
    context,
  }) => {
    // What the replayed link *shows* is the next test; this one is about the data.
    const owner = await newUser('Owner replay')
    const team = await newTeam(owner, unique('Invitations rejeu'), { addMemberAllowed: true })
    const invitee = await newUser('Invited replay')
    const { token } = await inviteByApi(owner, team.slug, invitee.user.email)

    await signIn(context, invitee)
    await page.goto(`/invitation?token=${token}`)
    await hydrated(page.getByRole('button', { name: "Rejoindre l'équipe" }))
    await page.getByRole('button', { name: "Rejoindre l'équipe" }).click()
    await expect(page).toHaveURL(new RegExp(`/equipes/${team.slug}$`))
    const joined = await membershipsOf(owner, team.slug, invitee.user.id)
    expect(joined).toHaveLength(1)

    // The token redeemed again, as the member it made: a plain 200 with that same membership.
    const { status, member } = await acceptByApi(invitee, token)
    expect(status).toBe(200)
    expect(member.id).toBe(joined[0].id)
    expect(await membershipsOf(owner, team.slug, invitee.user.id)).toHaveLength(1)
  })

  test('the replayed link tells an existing member they are in, not that the invitation is invalid', async ({
    page,
    context,
  }) => {
    // The preview of an ACCEPTED invitation answers redeemable=false; the page used to render it
    // as « Cette invitation n'est plus valide » even to the member it made, while the server treats
    // the replay as a success (fixed 2026-09-25: the page checks the membership).
    const owner = await newUser('Owner replay ui')
    const team = await newTeam(owner, unique('Invitations rejeu ecran'), { addMemberAllowed: true })
    const invitee = await newUser('Invited replay ui')
    const { token } = await inviteByApi(owner, team.slug, invitee.user.email)
    await acceptByApi(invitee, token)
    expect(
      await membershipsOf(owner, team.slug, invitee.user.id),
      'precondition: the invitee is a member'
    ).toHaveLength(1)

    await signIn(context, invitee)
    await page.goto(`/invitation?token=${token}`)
    await expect(
      page.getByRole('heading', { name: new RegExp(team.name) }),
      'precondition: the invitation page is rendered'
    ).toBeVisible()
    await expect(page.getByText(`Vous faites déjà partie de ${team.name}.`)).toBeVisible()
    await expect(
      page.getByText("Cette invitation n'est plus valide.", { exact: false })
    ).toHaveCount(0)
    await page.getByRole('main').getByRole('link', { name: "Voir l'équipe" }).click()
    await expect(page).toHaveURL(new RegExp(`/equipes/${team.slug}$`))
  })

  test('an address without an account: sign up through the link, verify, not a member until accepted on /equipes', async ({
    page,
  }) => {
    const owner = await newUser('Owner signup')
    const team = await newTeam(owner, unique('Invitations inscription'), { addMemberAllowed: true })
    const email = freshAddress('newcomer')
    const { token, mail } = await inviteByApi(owner, team.slug, email)
    expect(mail).toMatch(NO_ACCOUNT)

    // Signed out, the link says who invites to what, and offers a login.
    await page.goto(`/invitation?token=${token}`)
    await expect(
      page.getByRole('heading', { name: `Owner signup vous invite à rejoindre ${team.name}` })
    ).toBeVisible()
    await page.getByRole('main').getByRole('link', { name: 'Se connecter' }).click()
    await expect(page).toHaveURL(/\/connexion/)

    // Sign up from there.
    await page.getByRole('button', { name: 'Créer un compte' }).click()
    await page.getByRole('textbox', { name: 'Adresse e-mail' }).fill(email)
    await page.getByRole('textbox', { name: 'Nom affiché' }).fill('Nouvelle recrue')
    await page.getByRole('checkbox').check()
    const seen = await mailbox(email)
    await page.getByRole('button', { name: 'Créer un compte' }).click()
    await expect(
      page.getByText(
        "Cliquez sur le lien dans l'e-mail pour choisir votre mot de passe et activer votre compte."
      )
    ).toBeVisible()

    // Verify the address from the mail: the password is chosen there (SEC-24).
    const verification = linkTokenIn(await waitForNewMail(email, seen))
    await page.goto(`/verifier-email?token=${verification}`)
    const main = page.getByRole('main')
    await expect(main.getByRole('heading', { name: 'Activer votre compte' })).toBeVisible()
    await main.getByRole('textbox', { name: 'Mot de passe', exact: true }).fill('e2e-password')
    await main.getByRole('textbox', { name: 'Confirmer le mot de passe' }).fill('e2e-password')
    await main.getByRole('button', { name: 'Activer mon compte' }).click()
    const verified = page.getByRole('heading', { name: 'Compte activé !' })
    const passkeyPrompt = page.getByRole('heading', { name: 'Sécurisez votre compte' })
    await expect(verified.or(passkeyPrompt)).toBeVisible()
    if (await passkeyPrompt.isVisible())
      await page.getByRole('button', { name: 'Plus tard' }).click()

    // Signed up and verified — and still not a member.
    const me = (await loginWithPassword(email, 'e2e-password')).user.id
    expect(await membershipsOf(owner, team.slug, me)).toHaveLength(0)

    // The invitation waits on /equipes.
    await page.goto('/equipes')
    const banner = page
      .getByRole('alert')
      .filter({ hasText: 'Vous avez une invitation en attente' })
    await expect(banner).toBeVisible()
    await expect(
      banner.getByText(`Owner signup vous invite à rejoindre ${team.name}.`, { exact: true })
    ).toBeVisible()
    await hydrated(banner.getByRole('button', { name: 'Accepter' }))
    await banner.getByRole('button', { name: 'Accepter' }).click()

    await expect(page.getByText(`Vous avez rejoint ${team.name}.`, { exact: true })).toBeVisible()
    await expect(banner).toBeHidden()
    const memberships = await membershipsOf(owner, team.slug, me)
    expect(memberships).toHaveLength(1)
    expect(memberships[0].role).toBe('MEMBER')
    expect((await previewInvitation(token)).status).toBe('ACCEPTED')
  })
})
