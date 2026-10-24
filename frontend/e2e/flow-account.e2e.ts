import { readFileSync } from 'node:fs'
import type { Browser, Page } from '@playwright/test'
import { ApiError, apiDelete, apiGetOrNull, apiPost, loginWithPassword } from './support/api'
import {
  addMember,
  freshAddress,
  getTeam,
  newTeam,
  newUser,
  roleSession,
  signIn,
} from './support/data'
import { expect, test, unique } from './support/fixtures'
import { wallTimeOf, clockText, frenchDateTime } from './support/dates'
import { stack } from './support/stack'
import {
  addPasskeyFromProfile,
  avatarImage,
  expectAvatarShown,
  calendarTokenOf,
  fetchFeed,
  headerControls,
  icsDateTime,
  mailLinkTo,
  meFromSession,
  parseIcs,
  passkeysOf,
  sessionCookie,
  sessionIsAlive,
  signOutFromHeader,
  virtualAuthenticator,
  wallClockIn,
  zipEntry,
} from './support/flow-account'
import { mailbox, mailsTo, otpCodeIn, waitForNewMail } from './support/mailpit'
import { solidPng } from './support/ads'
import { joinGroup, newRide, openRide, postComments, ridePath } from './support/rides'
import { newTrip, tripPath } from './support/routes'
import { rawDocument, sessionCookie as ssrCookie, ssrOutlet } from './support/ssr'
import { escapeRegExp, hydrated, pageAs, watchToasts } from './support/ui'

/**
 * The account journeys, through the UI only: sign-up with the form and the mail's link, sign-out,
 * password sign-in, sign-in by an e-mailed code, forgotten password, the profile and its immediate
 * preferences, passkeys, the personal calendar feed, and deleting the account.
 *
 * Every test signs up its own account: nothing here touches the seeded ones.
 */

const WELCOME = /^Bienvenue sur /

async function openLogin(page: Page) {
  await page.goto('/connexion')
  const main = page.getByRole('main')
  await expect(main.getByRole('heading', { name: WELCOME })).toBeVisible()
  return main
}

/** Fills and submits the login form (the page is already on /connexion). */
async function signInWithPassword(page: Page, email: string, password: string) {
  const main = page.getByRole('main')
  const submit = main.getByRole('button', { name: 'Se connecter', exact: true })
  await hydrated(submit)
  await main.getByRole('textbox', { name: 'Adresse e-mail' }).fill(email)
  await main.getByRole('textbox', { name: 'Mot de passe' }).fill(password)
  await submit.click()
}

/** The heading of the profile's overview. */
const PROFILE = { name: 'Profil', exact: true } as const

/** The profile's overview, signed in: its heading and the account's address. */
async function openProfile(page: Page, email: string) {
  await page.goto('/profil')
  const main = page.getByRole('main')
  await expect(main.getByRole('heading', PROFILE)).toBeVisible()
  await expect(main.getByText(email, { exact: true }).first()).toBeVisible()
  return main
}

/** A page of the profile (« Mon compte », « Connexion et sécurité »…), signed in, by its heading. */
async function openProfilePage(page: Page, path: string, heading: string) {
  await page.goto(path)
  const main = page.getByRole('main')
  await expect(main.getByRole('heading', { name: heading, exact: true })).toBeVisible()
  return main
}

/** A protected page sends an anonymous visitor to the login form. */
async function expectSignedOut(page: Page) {
  await page.goto('/profil')
  await expect(page.getByRole('main').getByRole('heading', { name: WELCOME })).toBeVisible()
  await expect(page.getByRole('main').getByRole('heading', PROFILE)).toHaveCount(0)
}

test('sign up with the form, verify through the mail, sign out from the header, sign in with the password', async ({
  page,
  context,
  isMobile,
}) => {
  const email = freshAddress('account signup')
  const displayName = unique('Inscrite')
  const password = 'e2e-signup-password'

  const main = await openLogin(page)
  const toRegister = main.getByRole('button', { name: 'Créer un compte' })
  await hydrated(toRegister)
  await toRegister.click()
  await expect(main.getByRole('heading', { name: 'Créer un compte' })).toBeVisible()

  await main.getByRole('textbox', { name: 'Adresse e-mail' }).fill(email)
  await main.getByRole('textbox', { name: 'Nom affiché' }).fill(displayName)
  // No password on the sign-up form: it is chosen on the page the link opens (SEC-24).
  await expect(main.getByRole('textbox', { name: 'Mot de passe', exact: true })).toHaveCount(0)
  await main.getByRole('checkbox').check()
  const seen = await mailbox(email)
  await main.getByRole('button', { name: 'Créer un compte' }).click()

  // Back on the login form, the address kept, told to open the mail.
  await expect(
    page.getByText(
      "Cliquez sur le lien dans l'e-mail pour choisir votre mot de passe et activer votre compte."
    )
  ).toBeVisible()
  await expect(main.getByRole('heading', { name: WELCOME })).toBeVisible()
  await expect(main.getByRole('textbox', { name: 'Adresse e-mail' })).toHaveValue(email)
  // Not usable before the address is verified.
  await expect(loginWithPassword(email, password)).rejects.toBeInstanceOf(ApiError)

  // The link shows the address and asks for the password; activating signs the new account in.
  // The passkey offer can wait.
  await page.goto(mailLinkTo(await waitForNewMail(email, seen), '/verify-email'))
  await expect(main.getByRole('heading', { name: 'Activer votre compte' })).toBeVisible()
  await expect(main.getByText(email)).toBeVisible()
  await main.getByRole('textbox', { name: 'Mot de passe', exact: true }).fill(password)
  await main.getByRole('textbox', { name: 'Confirmer le mot de passe' }).fill(password)
  await main.getByRole('button', { name: 'Activer mon compte' }).click()
  await expect(main.getByRole('heading', { name: 'Sécurisez votre compte' })).toBeVisible()
  const later = main.getByRole('button', { name: 'Plus tard' })
  await later.click()
  await expect(page).toHaveURL(/\/$/)

  const cookie = await sessionCookie(context)
  expect(cookie, 'the verification signed the browser in').toBeTruthy()
  const me = await meFromSession(context)
  expect(me).toMatchObject({ email, displayName, emailVerified: true })
  const profile = await openProfile(page, email)
  await expect(profile.getByText(displayName, { exact: true }).first()).toBeVisible()

  await signOutFromHeader(page, isMobile, displayName)
  await expect(page.getByRole('main').getByRole('heading', { name: WELCOME })).toBeVisible()
  expect(await sessionIsAlive(cookie!), 'the backend revoked the session').toBe(false)
  expect(await sessionCookie(context)).toBeUndefined()
  await expectSignedOut(page)

  // Signing in again with the password chosen at sign-up, from the login form the protected page
  // sent us to: it returns there.
  await signInWithPassword(page, email, password)
  await expect(page).toHaveURL(/\/profil$/)
  await expect(page.getByRole('main').getByRole('heading', PROFILE)).toBeVisible()
  expect((await meFromSession(context)).email).toBe(email)
})

test('a wrong password is refused and signs nobody in', async ({ page, context }) => {
  const user = await newUser(unique('Mauvais mot de passe'))
  await openLogin(page)
  await signInWithPassword(page, user.user.email, 'not-the-password')
  await expect(page.getByText('Adresse e-mail ou mot de passe incorrect')).toBeVisible()
  await expect(page).toHaveURL(/\/connexion$/)
  expect(await sessionCookie(context)).toBeUndefined()
})

/**
 * Sign-in by a code sent by e-mail (OtpLogin.tsx). Every test uses a fresh account: the backend
 * accepts 3 code requests per address per 5 minutes, and burns a code after 5 wrong guesses — a
 * burnt, an expired and a wrong code all answer the same 400 TOKEN_INVALID on purpose, so that
 * rule is checked by the backend tests (AuthServiceTest), not here.
 */
test.describe('sign-in by e-mailed code', () => {
  /** The six digit boxes of the code (Mantine PinInput). */
  const codeBoxes = (page: Page) =>
    page.getByRole('main').locator('input[autocomplete="one-time-code"]')

  /** From the login page to the code step: the address typed, the code requested and read. */
  async function requestCode(page: Page, email: string) {
    const main = await openLogin(page)
    const byMail = main.getByRole('button', { name: 'Connexion par e-mail' })
    await hydrated(byMail)
    await byMail.click()
    await expect(main.getByRole('heading', { name: 'Code par e-mail' })).toBeVisible()
    await main.getByRole('textbox', { name: 'Adresse e-mail' }).fill(email)
    const seen = await mailbox(email)
    await main.getByRole('button', { name: 'Envoyer le code' }).click()
    await expect(main.getByRole('heading', { name: 'Entrez votre code' })).toBeVisible()
    await expect(codeBoxes(page)).toHaveCount(6)
    return otpCodeIn(await waitForNewMail(email, seen))
  }

  /** Types a code: the PinInput moves from box to box, and submits itself on the sixth digit. */
  async function typeCode(page: Page, code: string) {
    await codeBoxes(page).first().click()
    await page.keyboard.type(code)
  }

  test('the code from the mail signs in on its sixth digit', async ({ page, context }) => {
    const user = await newUser(unique('Code mail'))
    const code = await requestCode(page, user.user.email)
    // The code step says where the code went.
    await expect(page.getByRole('main').getByText(user.user.email)).toBeVisible()

    await typeCode(page, code)
    await expect(page).not.toHaveURL(/\/connexion/)
    const cookie = await sessionCookie(context)
    expect(cookie, 'a session was opened').toBeTruthy()
    expect((await meFromSession(context)).email).toBe(user.user.email)
  })

  test('a wrong code is refused with a message, and the right one still signs in', async ({
    page,
    context,
  }) => {
    const user = await newUser(unique('Code faux'))
    const code = await requestCode(page, user.user.email)
    const wrong = code === '000000' ? '111111' : '000000'

    await typeCode(page, wrong)
    const main = page.getByRole('main')
    await expect(main.getByRole('alert')).toHaveText('Code invalide ou expiré')
    await expect(page).toHaveURL(/\/connexion/)
    expect(await sessionCookie(context), 'no session for a wrong code').toBeUndefined()
    // The boxes are emptied for another try.
    await expect(codeBoxes(page).first()).toHaveValue('')

    await typeCode(page, code)
    await expect(page).not.toHaveURL(/\/connexion/)
    expect(await sessionCookie(context)).toBeTruthy()
  })

  test('a new code can be asked for after 60 s, and it replaces the first one', async ({
    page,
    context,
  }) => {
    await page.clock.install()
    const user = await newUser(unique('Code renvoyé'))
    const first = await requestCode(page, user.user.email)
    const main = page.getByRole('main')

    await expect(main.getByRole('button', { name: 'Renvoyer dans 60s' })).toBeDisabled()
    // The countdown is a chain of 1 s timeouts, each set after the previous render: step the clock
    // one second at a time so that each one gets scheduled.
    await page.clock.runFor(1_000)
    await expect(main.getByRole('button', { name: 'Renvoyer dans 59s' })).toBeDisabled()
    for (let second = 2; second <= 60; second++) await page.clock.runFor(1_000)
    const resend = main.getByRole('button', { name: 'Renvoyer le code', exact: true })
    await expect(resend).toBeEnabled()

    const seen = await mailbox(user.user.email)
    await resend.click()
    const second = otpCodeIn(await waitForNewMail(user.user.email, seen))
    await expect(main.getByRole('button', { name: /^Renvoyer dans \d+s$/ })).toBeDisabled()

    // Asking again invalidates the previous code (unless the two happen to be the same).
    if (first !== second) {
      await typeCode(page, first)
      await expect(main.getByRole('alert')).toHaveText('Code invalide ou expiré')
    }
    await typeCode(page, second)
    await expect(page).not.toHaveURL(/\/connexion/)
    expect(await sessionCookie(context)).toBeTruthy()
  })

  test('each code box is named for its place in the code', async ({ page }) => {
    // OtpLogin passed aria-label to PinInput, which put it on the wrapper, and Mantine named every
    // box « PinInput » (fixed 2026-09-25).
    const user = await newUser(unique('Code nommé'))
    await requestCode(page, user.user.email)
    for (let digit = 1; digit <= 6; digit++)
      await expect(codeBoxes(page).nth(digit - 1)).toHaveAccessibleName(
        `Chiffre ${digit} sur 6 du code`
      )
  })
})

test('forgotten password: the mail, a new password, then sign in with it', async ({
  page,
  context,
}) => {
  const user = await newUser(unique('Oublieuse'))
  const email = user.user.email
  const newPassword = 'e2e-new-password'

  const login = await openLogin(page)
  const forgot = login.getByRole('link', { name: 'Mot de passe oublié ?' })
  await hydrated(forgot)
  await forgot.click()
  const main = page.getByRole('main')
  await expect(main.getByRole('heading', { name: 'Mot de passe oublié' })).toBeVisible()
  await main.getByRole('textbox', { name: 'Adresse e-mail' }).fill(email)
  const seen = await mailbox(email)
  await main.getByRole('button', { name: 'Envoyer le lien' }).click()
  await expect(main.getByRole('heading', { name: 'E-mail envoyé' })).toBeVisible()

  await page.goto(mailLinkTo(await waitForNewMail(email, seen), '/reset-password'))
  await expect(main.getByRole('heading', { name: 'Réinitialiser le mot de passe' })).toBeVisible()
  const submit = main.getByRole('button', { name: 'Réinitialiser le mot de passe' })
  await hydrated(submit)
  await main.getByRole('textbox', { name: 'Nouveau mot de passe' }).fill(newPassword)
  await main.getByRole('textbox', { name: 'Confirmer le mot de passe' }).fill(newPassword)
  await submit.click()

  // The reset signs the browser in.
  await expect(page).toHaveURL(/\/$/)
  const profile = await openProfile(page, email)
  // The reset ended every session opened before it (docs/LEDGER_*.md SEC-12, audit L1) — the
  // one sign-up opened stands for a stolen one — but not the browser's, which the reset opened.
  expect(await sessionIsAlive(user.refreshToken), 'the session opened before the reset').toBe(false)
  expect(await sessionIsAlive(context), 'the reset’s own session').toBe(true)
  // The old password is gone, the new one works.
  await expect(loginWithPassword(email, user.password)).rejects.toBeInstanceOf(ApiError)
  expect((await loginWithPassword(email, newPassword)).user.email).toBe(email)

  // Sign out from the profile's own button (the sidebar's on a desktop, the foot of the list on a
  // phone: one of the two is hidden), then back in with the new password.
  const signOut = profile.getByRole('button', { name: 'Se déconnecter' })
  await hydrated(signOut)
  await signOut.click()
  await expect(page.getByRole('main').getByRole('heading', { name: WELCOME })).toBeVisible()
  expect(await sessionCookie(context)).toBeUndefined()
  await signInWithPassword(page, email, newPassword)
  await expect(page).toHaveURL(/\/$/)
  await openProfile(page, email)
})

test('the display name is edited from « Mon compte »', async ({ page, context, isMobile }) => {
  const user = await newUser(unique('Ancien nom'))
  const renamed = unique('Nouveau nom')
  await signIn(context, user)
  const main = await openProfilePage(page, '/profil/compte', 'Mon compte')

  // Always a field, saved by its own button: no « Modifier le profil » mode any more.
  const field = main.getByRole('textbox', { name: 'Nom affiché' })
  const save = main.getByRole('button', { name: 'Enregistrer' })
  await expect(field).toHaveValue(user.user.displayName)
  await expect(save, 'nothing to save before an edit').toBeDisabled()
  await expect(main.getByRole('textbox', { name: 'Adresse e-mail' })).toHaveAttribute('readonly')
  await hydrated(field)
  await field.fill(renamed)
  const saved = page.waitForResponse(
    (r) => r.request().method() === 'PUT' && r.url().endsWith('/api/users/me')
  )
  await save.click()
  expect((await saved).ok()).toBe(true)

  await expect(field).toHaveValue(renamed)
  await expect(save, 'saved: nothing left to save').toBeDisabled()
  if (!isMobile)
    await expect(page.getByRole('banner').getByRole('button', { name: renamed })).toBeVisible()
  expect((await meFromSession(user)).displayName).toBe(renamed)

  await page.reload()
  await expect(field).toHaveValue(renamed)
  // The overview's identity card says it too.
  const profile = await openProfile(page, user.user.email)
  await expect(profile.getByText(renamed, { exact: true }).first()).toBeVisible()
  await expect(profile.getByText(user.user.displayName, { exact: true })).toHaveCount(0)
})

/**
 * « Déconnecter tous les appareils » (ProfileSecurityPage.tsx, docs/LEDGER_*.md WEB-28): after the
 * confirmation, the browser lands on the login page, and a session opened elsewhere — the phone,
 * a Karoo — no longer refreshes either.
 */
test('signing out of every device from the profile closes the other sessions too', async ({
  page,
  context,
}) => {
  const user = await newUser(unique('Tous appareils'))
  const elsewhere = await loginWithPassword(user.user.email, user.password)
  await signIn(context, user)
  const main = await openProfilePage(page, '/profil/securite', 'Connexion et sécurité')

  const button = main.getByRole('button', { name: 'Déconnecter tous les appareils' })
  await hydrated(button)
  await button.click()
  const dialog = page.getByRole('dialog', { name: 'Déconnecter tous les appareils ?' })
  await expect(dialog).toBeVisible()
  const revoked = page.waitForResponse(
    (r) => r.request().method() === 'POST' && r.url().endsWith('/api/auth/logout-all')
  )
  const browserSession = await sessionCookie(context)
  await dialog.getByRole('button', { name: 'Déconnecter tous les appareils' }).click()
  expect((await revoked).status()).toBe(204)

  await expect(page.getByRole('main').getByRole('heading', { name: WELCOME })).toBeVisible()
  expect(await sessionIsAlive(browserSession!), 'this browser’s session').toBe(false)
  expect(await sessionIsAlive(user), 'the test’s own session').toBe(false)
  expect(await sessionIsAlive(elsewhere.refreshToken), 'the other device’s session').toBe(false)
  await expectSignedOut(page)
})

/**
 * The avatar sent from « Mon compte » (ProfileAccountPage.tsx, the camera button and its hidden file
 * input): the upload answers the updated user, which useAuth puts in the store — so the header's
 * account control changes at once — and comments resolve their author at read time, so one written
 * before the upload shows the new picture too.
 */
test('an avatar sent from the profile shows in the header and on the user’s comments', async ({
  page,
  context,
  isMobile,
}) => {
  const user = await newUser(unique('Avatar'))
  const name = user.user.displayName
  const team = await newTeam(user, unique('Équipe avatar'))
  const ride = await newRide(user, team.slug, unique('Sortie avatar'))
  const comment = unique('Commentaire avant avatar')
  await postComments(user, team.slug, ride.slug, [comment])
  await signIn(context, user)

  const main = await openProfilePage(page, '/profil/compte', 'Mon compte')
  await expect(avatarImage(main, name), 'no avatar yet: the initials').toHaveCount(0)
  const upload = main.getByRole('button', { name: 'Ajouter un avatar' })
  await hydrated(upload)
  const shown = await watchToasts(page)
  const chooser = page.waitForEvent('filechooser')
  await upload.click()
  const uploaded = page.waitForResponse(
    (r) => r.request().method() === 'POST' && r.url().endsWith('/api/users/me/avatar')
  )
  await (
    await chooser
  ).setFiles({
    name: 'avatar.png',
    mimeType: 'image/png',
    buffer: solidPng(300, 300, [200, 40, 90]),
  })
  expect((await uploaded).ok()).toBe(true)

  const me = await meFromSession(user)
  expect(me.avatarUrl, 'the account now has an avatar').toBeTruthy()
  const src = me.avatarUrl!
  await expectAvatarShown(avatarImage(main, name), src)
  await expect(main.getByRole('button', { name: "Supprimer l'avatar" })).toBeVisible()
  expect(await shown()).toEqual(['Avatar mis à jour avec succès'])

  // The header follows without a reload: the account menu on desktop, the drawer on mobile.
  await expectAvatarShown(avatarImage(await headerControls(page, isMobile), name), src)

  // The comment written before the upload now carries the picture.
  await openRide(page, team.slug, ride)
  const commentItem = page
    .getByRole('main')
    .locator('.mantine-Group-root')
    .filter({ has: page.getByText(comment, { exact: true }) })
    .filter({ has: page.getByRole('img', { name, exact: true }) })
    .last()
  await expectAvatarShown(avatarImage(commentItem, name), src)
  // …as a fresh load of the header does.
  await expectAvatarShown(avatarImage(await headerControls(page, isMobile), name), src)
})

test('units, theme, language and contact preferences apply at once and persist', async ({
  page,
  context,
  isMobile,
}) => {
  const user = await newUser(unique('Préférences'))
  await signIn(context, user)
  const main = await openProfilePage(page, '/profil/preferences', 'Préférences')
  const html = page.locator('html')
  await expect(html).toHaveAttribute('data-mantine-color-scheme', 'light')

  const before = await meFromSession(user)
  expect(before.unitSystem ?? 'METRIC').toBe('METRIC')
  expect(before.contactableByMembers).toBe(true)

  // Units: the segmented control saves the profile at once.
  const imperial = main.getByRole('radio', { name: 'Impérial (mi, ft)' })
  await hydrated(imperial)
  const unitsSaved = page.waitForResponse(
    (r) => r.request().method() === 'PUT' && r.url().endsWith('/api/users/me')
  )
  await main.getByText('Impérial (mi, ft)', { exact: true }).click()
  expect((await unitsSaved).ok()).toBe(true)
  await expect(imperial).toBeChecked()
  // Never chosen: the theme follows the device.
  await expect(main.getByRole('radio', { name: 'Système' })).toBeChecked()

  // Contactable, on « Confidentialité »: a partial PATCH of the preferences.
  await openProfilePage(page, '/profil/vie-privee', 'Confidentialité')
  const contactable = main.getByRole('switch', { name: 'Accepter les messages des membres' })
  await expect(contactable).toBeChecked()
  await hydrated(contactable)
  const contactSaved = page.waitForResponse(
    (r) => r.request().method() === 'PATCH' && r.url().endsWith('/api/users/me/preferences')
  )
  await contactable.click()
  expect((await contactSaved).ok()).toBe(true)
  await expect(contactable).not.toBeChecked()
  await expect(contactable).toBeEnabled()

  // Theme and language, from the header.
  await openProfilePage(page, '/profil/preferences', 'Préférences')
  const controls = await headerControls(page, isMobile)
  const themeSaved = page.waitForResponse(
    (r) => r.request().method() === 'PATCH' && r.url().endsWith('/api/users/me/preferences')
  )
  await controls.getByRole('button', { name: 'Changer le thème' }).click()
  expect((await themeSaved).ok()).toBe(true)
  await expect(html).toHaveAttribute('data-mantine-color-scheme', 'dark')

  const languageSaved = page.waitForResponse(
    (r) => r.request().method() === 'PATCH' && r.url().endsWith('/api/users/me/preferences')
  )
  await controls.getByRole('combobox', { name: 'Langue' }).selectOption('en')
  expect((await languageSaved).ok()).toBe(true)
  await expect(main.getByRole('heading', { name: 'Preferences', exact: true })).toBeVisible()
  // The page follows the header: the account answered, and it is what the page reads.
  await expect(main.getByRole('radio', { name: 'Dark' })).toBeChecked()
  await expect(main.getByRole('combobox', { name: 'Language' })).toHaveValue('en')

  expect(await meFromSession(user)).toMatchObject({
    unitSystem: 'IMPERIAL',
    theme: 'DARK',
    language: 'en',
    contactableByMembers: false,
  })

  // A reload renders every one of them from the account.
  await page.reload()
  await expect(main.getByRole('heading', { name: 'Preferences', exact: true })).toBeVisible()
  await expect(html).toHaveAttribute('data-mantine-color-scheme', 'dark')
  await expect(main.getByRole('radio', { name: 'Imperial (mi, ft)' })).toBeChecked()
  await expect(main.getByRole('radio', { name: 'Dark' })).toBeChecked()
  await openProfilePage(page, '/profile/privacy', 'Privacy')
  await expect(main.getByRole('switch', { name: 'Can be contacted by members' })).not.toBeChecked()

  // « System », from the profile's own control: the one choice the header's toggle cannot make.
  await openProfilePage(page, '/profile/preferences', 'Preferences')
  const system = main.getByRole('radio', { name: 'System' })
  await hydrated(system)
  const systemSaved = page.waitForResponse(
    (r) => r.request().method() === 'PATCH' && r.url().endsWith('/api/users/me/preferences')
  )
  await main.getByText('System', { exact: true }).click()
  const systemResponse = await systemSaved
  expect(systemResponse.ok()).toBe(true)
  expect(systemResponse.request().postDataJSON()).toEqual({ theme: 'SYSTEM' })
  await expect(system).toBeChecked()
  // Playwright's browser prefers a light scheme unless told otherwise: « System » follows it.
  await expect(html).toHaveAttribute('data-mantine-color-scheme', 'light')
  expect((await meFromSession(user)).theme).toBe('SYSTEM')
})

test('a passkey registered from the profile signs in from the login page', async ({
  page,
  context,
  isMobile,
}) => {
  const user = await newUser(unique('Passkey'))
  const authenticator = await virtualAuthenticator(page)
  await signIn(context, user)
  const main = await openProfilePage(page, '/profil/securite', 'Connexion et sécurité')
  const device = unique('Clé virtuelle')

  await expect(main.getByText("Aucune clé d'accès enregistrée.", { exact: false })).toBeVisible()
  await addPasskeyFromProfile(page, device)

  expect(await authenticator.credentials()).toHaveLength(1)
  const [passkey] = await passkeysOf(user.accessToken)
  expect(passkey).toMatchObject({ deviceName: device })
  expect(passkey.lastUsedAt).toBeFalsy()

  await signOutFromHeader(page, isMobile, user.user.displayName)
  const login = page.getByRole('main')
  await expect(login.getByRole('heading', { name: WELCOME })).toBeVisible()
  expect(await sessionCookie(context)).toBeUndefined()

  // No address typed: the authenticator offers the account's resident credential.
  const quick = login.getByRole('button', { name: 'Connexion rapide' })
  await hydrated(quick)
  await quick.click()
  await expect(page).toHaveURL(/\/$/)
  await openProfile(page, user.user.email)
  expect(await sessionCookie(context), 'a session was opened').toBeTruthy()
  expect((await meFromSession(context)).id).toBe(user.user.id)
  const [used] = await passkeysOf(user.accessToken)
  expect(used.lastUsedAt).toBeTruthy()
})

const FEED_URL = /\/api\/calendar\/ics\?token=[0-9a-f]+$/

/** « Régénérer le lien », confirmed, on /calendrier; returns once the backend answered. */
async function regenerateFeed(page: Page) {
  const regenerate = page.getByRole('main').getByRole('button', { name: 'Régénérer le lien' })
  await hydrated(regenerate)
  await regenerate.click()
  const dialog = page.getByRole('dialog', { name: 'Régénérer le lien du calendrier' })
  await expect(
    dialog.getByText("L'ancien lien ne fonctionnera plus.", { exact: false })
  ).toBeVisible()
  const regenerated = page.waitForResponse(
    (r) => r.request().method() === 'POST' && r.url().endsWith('/api/calendar/token/regenerate')
  )
  await dialog.getByRole('button', { name: 'Confirmer' }).click()
  expect((await regenerated).ok()).toBe(true)
  await expect(dialog).toBeHidden()
}

test.describe('the personal calendar feed', () => {
  test('the feed URL is shown and copied, serves the upcoming ride as iCalendar, and a new link retires the old one', async ({
    context,
    page,
  }) => {
    const user = await newUser(unique('Abonnée ICS'))
    const team = await newTeam(user, unique('Équipe ICS'))
    const ride = await newRide(user, team.slug, unique('Sortie ICS'))
    await joinGroup(user, team.slug, ride, 'Groupe A')
    // A team the user is not in: its ride has no business in their feed.
    const stranger = await newUser(unique('Étrangère ICS'))
    const otherTeam = await newTeam(stranger, unique('Autre équipe ICS'))
    const otherRide = await newRide(stranger, otherTeam.slug, unique('Sortie étrangère'))
    await context.grantPermissions(['clipboard-read', 'clipboard-write'])
    await signIn(context, user)

    // The feed settings live under the personal calendar, /calendrier.
    await page.goto('/calendrier')
    const main = page.getByRole('main')
    await expect(main.getByRole('heading', { name: 'Calendrier', level: 2 })).toBeVisible()
    const field = main.getByRole('textbox', { name: 'URL du flux global' })
    await expect(field).toHaveValue(FEED_URL)
    const url = await field.inputValue()
    expect(url, 'the URL shown is the account’s').toBe((await calendarTokenOf(user)).globalFeedUrl)
    await expect(main.getByRole('link', { name: "S'abonner" })).toHaveAttribute(
      'href',
      url.replace(/^https?:\/\//, 'webcal://')
    )

    const copy = main.getByRole('button', { name: 'Copier le lien' })
    await hydrated(copy)
    await copy.click()
    await expect.poll(() => page.evaluate(() => navigator.clipboard.readText())).toBe(url)

    // A calendar application fetches it with nothing but the URL.
    const feed = await fetchFeed(url)
    expect(feed.status).toBe(200)
    expect(feed.contentType).toMatch(/^text\/calendar\b/)
    const calendar = parseIcs(feed.body)
    const event = calendar.events.find((e) => e.SUMMARY === ride.name)
    expect(event, `the feed lists « ${ride.name} »`).toBeDefined()
    expect(event).toMatchObject({
      DTSTART: icsDateTime(ride.dateTime),
      DESCRIPTION: team.name,
      CATEGORIES: 'RIDE',
    })
    expect(calendar.events.map((e) => e.SUMMARY)).not.toContain(otherRide.name)

    // The event's link opens the ride.
    await openRide(page, team.slug, ride)
    await page.goto(event!.URL)
    await expect(page.getByRole('heading', { level: 2, name: ride.name })).toBeVisible()

    // A new link: the old one stops working at once.
    await page.goto('/calendrier')
    await expect(field).toHaveValue(url)
    await regenerateFeed(page)
    expect((await fetchFeed(url)).status, 'the old URL is refused').toBe(403)

    // The page shows the new link, still after a reload, and it serves the feed.
    await page.reload()
    await expect(field).not.toHaveValue(url)
    await expect(field).toHaveValue(FEED_URL)
    const renewed = await field.inputValue()
    expect(renewed).toBe((await calendarTokenOf(user)).globalFeedUrl)
    const again = await fetchFeed(renewed)
    expect(again.status).toBe(200)
    expect(parseIcs(again.body).events.map((e) => e.SUMMARY)).toContain(ride.name)
  })

  test('the new link replaces the old one on screen as soon as it is regenerated', async ({
    context,
    page,
  }) => {
    // useRegenerateToken() used to leave the token query alone, so the field and the copy button
    // kept the dead URL until a reload (fixed 2026-09-25: it updates useGetToken's cache).
    const user = await newUser(unique('Régénère ICS'))
    await signIn(context, user)
    await page.goto('/calendrier')
    const field = page.getByRole('main').getByRole('textbox', { name: 'URL du flux global' })
    await expect(field).toHaveValue(FEED_URL)
    const url = await field.inputValue()
    await regenerateFeed(page)
    const renewed = (await calendarTokenOf(user)).globalFeedUrl
    expect(renewed, 'precondition: the backend issued a new link').not.toBe(url)
    expect((await fetchFeed(url)).status, 'precondition: the old one is dead').toBe(403)

    await expect(field).toHaveValue(renewed, { timeout: 2_000 })
  })
})

test.describe('deleting the account', () => {
  /**
   * The profile's danger zone, its delete button hydrated. The confirmation reads
   * GET /api/users/me/deletion-impact each time it opens and says, before anything is confirmed,
   * which teams block the deletion and which go with the account.
   */
  async function openDangerZone(page: Page, email: string) {
    const main = await openProfile(page, email)
    // « Mon compte », from the overview's identity card: where the danger zone lives.
    const account = main.getByRole('link', { name: 'Mon compte', exact: true }).first()
    await hydrated(account)
    await account.click()
    await expect(main.getByRole('heading', { name: 'Mon compte', exact: true })).toBeVisible()
    await expect(main.getByText('Zone de danger', { exact: true })).toBeVisible()
    const remove = main.getByRole('button', { name: 'Supprimer le compte' })
    await hydrated(remove)
    const dialog = page.getByRole('dialog', { name: 'Zone de danger' })
    const confirm = dialog.getByRole('button', { name: 'Oui, supprimer mon compte' })
    /** Opens the confirmation and waits for its impact to be read. */
    const open = async () => {
      const impact = page.waitForResponse((r) => r.url().endsWith('/api/users/me/deletion-impact'))
      await remove.click()
      await expect(dialog).toBeVisible()
      expect((await impact).status()).toBe(200)
      await expect(dialog.getByText('Vérification de vos équipes…')).toHaveCount(0)
    }
    return { dialog, confirm, open }
  }

  /** The team's public page, as an anonymous visitor sees it: its status code. */
  const anonymousStatus = async (teamSlug: string) =>
    (await fetch(`${stack.baseURL}/api/teams/${teamSlug}`)).status

  test('the sole admin of a team with other members is stopped before confirming, until another admin is named', async ({
    page,
    context,
  }) => {
    const user = await newUser(unique('Seule admin'))
    const member = await newUser(unique('Coéquipière'))
    const team = await newTeam(user, unique('Équipe à garder'))
    const admin = await roleSession('admin')
    await addMember(admin, team.slug, member)
    await signIn(context, user)
    const { dialog, confirm, open } = await openDangerZone(page, user.user.email)
    const cookie = await sessionCookie(context)
    expect(cookie, 'precondition: signed in').toBeTruthy()

    // The confirmation names the team that blocks it, linked to its members, and cannot be
    // confirmed. A team created here is not one migrated from biketeam: it blocks for its members,
    // not for its old addresses.
    await open()
    await expect(
      dialog.getByText('Vous ne pouvez pas encore supprimer votre compte', { exact: true })
    ).toBeVisible()
    await expect(
      dialog.getByText(
        "Vous êtes la seule personne à administrer cette équipe, qui compte d'autres membres :"
      )
    ).toBeVisible()
    await expect(dialog.getByText('venue de biketeam', { exact: false })).toHaveCount(0)
    const blocking = dialog.getByRole('link', { name: team.name, exact: true })
    await expect(blocking).toHaveAttribute('href', `/equipes/${team.slug}/admin/membres`)
    await expect(confirm).toBeDisabled()
    await dialog.getByRole('button', { name: 'Annuler' }).click()
    await expect(dialog).toBeHidden()

    // The server refuses it too, called directly.
    const refused = await apiDelete(user, '/api/users/me').catch((error: unknown) => error)
    expect(refused).toBeInstanceOf(ApiError)
    expect((refused as ApiError).code).toBe('SOLE_TEAM_ADMIN')
    expect(await sessionIsAlive(context), 'the session is untouched').toBe(true)
    expect(await getTeam(user, team.slug)).toMatchObject({ role: 'ADMIN', memberCount: 2 })

    // Another admin named, the impact is read again when the confirmation reopens: the account
    // goes, and the team stays with its members.
    const successor = await newUser(unique('Relève'))
    await addMember(admin, team.slug, successor, 'ADMIN')
    await open()
    await expect(
      dialog.getByText('Vous ne pouvez pas encore supprimer votre compte', { exact: true })
    ).toHaveCount(0)
    const deleted = page.waitForResponse(
      (r) => r.request().method() === 'DELETE' && r.url().endsWith('/api/users/me')
    )
    await confirm.click()
    expect((await deleted).status()).toBe(204)
    await expect(page).toHaveURL(/\/connexion$/)
    expect(await getTeam(successor, team.slug)).toMatchObject({ role: 'ADMIN', memberCount: 2 })
  })

  test('an admin alone in their team is told the team goes too, then signed out for good', async ({
    page,
    context,
  }) => {
    const user = await newUser(unique('Partante'))
    const team = await newTeam(user, unique('Équipe solitaire'), { visibility: 'PUBLIC' })
    expect(await anonymousStatus(team.slug), 'precondition: the team is public').toBe(200)
    await signIn(context, user)
    const { dialog, confirm, open } = await openDangerZone(page, user.user.email)
    const cookie = await sessionCookie(context)
    expect(cookie, 'precondition: signed in').toBeTruthy()

    // Said before confirming: the team is deleted with the account.
    await open()
    await expect(
      dialog.getByText(
        "Vous êtes l'unique membre de cette équipe : elle sera supprimée avec votre compte."
      )
    ).toBeVisible()
    await expect(dialog.getByRole('listitem').filter({ hasText: team.name })).toBeVisible()
    await expect(confirm).toBeEnabled()

    const deleted = page.waitForResponse(
      (r) => r.request().method() === 'DELETE' && r.url().endsWith('/api/users/me')
    )
    await confirm.click()
    expect((await deleted).status()).toBe(204)

    // Signed out, on the login form.
    await expect(page).toHaveURL(/\/connexion$/)
    await expect(page.getByRole('main').getByRole('heading', { name: WELCOME })).toBeVisible()
    expect(await sessionIsAlive(cookie!), 'the session no longer refreshes').toBe(false)
    await expectSignedOut(page)

    // The address and password open nothing any more — neither through the form nor the API.
    await signInWithPassword(page, user.user.email, user.password)
    await expect(page.getByText('Adresse e-mail ou mot de passe incorrect')).toBeVisible()
    await expect(page).toHaveURL(/\/connexion/)
    const refused = await loginWithPassword(user.user.email, user.password).catch(
      (error: unknown) => error
    )
    expect(refused).toBeInstanceOf(ApiError)
    expect((refused as ApiError).code).toBe('INVALID_CREDENTIALS')

    // And the team went with it.
    expect(await anonymousStatus(team.slug), 'the team is gone').toBe(404)
  })
})

test.describe('mobile header', () => {
  test.skip(({ isMobile }) => !isMobile, 'the burger only exists on the mobile layout')

  test('the menu button has an accessible name', async ({ page }) => {
    // Layout.tsx rendered <Burger> without aria-label, while nav.openMenu / nav.closeMenu existed
    // in every locale and were used nowhere (fixed 2026-09-25).
    await openLogin(page)
    const banner = page.getByRole('banner')
    await expect(banner.getByRole('link', { name: /Pédalons/ })).toBeVisible()
    await expect(banner.getByRole('button')).toHaveCount(1)
    const burger = banner.getByRole('button', { name: 'Ouvrir le menu' })
    await expect(burger).toBeVisible({ timeout: 2_000 })
    await hydrated(burger)
    await burger.click()
    await expect(banner.getByRole('button', { name: 'Fermer le menu' })).toBeVisible()
  })
})

test('a deleted passkey is gone from the profile and no longer signs in', async ({
  page,
  context,
  isMobile,
}) => {
  const user = await newUser(unique('Passkey supprimée'))
  const authenticator = await virtualAuthenticator(page)
  await signIn(context, user)
  const main = await openProfilePage(page, '/profil/securite', 'Connexion et sécurité')
  const device = unique('Clé à supprimer')
  await addPasskeyFromProfile(page, device)
  expect(await passkeysOf(user.accessToken)).toHaveLength(1)

  await main.getByRole('button', { name: "Supprimer cette clé d'accès" }).click()
  const dialog = page.getByRole('dialog', { name: "Supprimer la clé d'accès ?" })
  await expect(
    dialog.getByText("Cette clé d'accès ne pourra plus être utilisée pour vous connecter.")
  ).toBeVisible()
  const deleted = page.waitForResponse(
    (r) => r.request().method() === 'DELETE' && r.url().includes('/api/auth/passkeys/')
  )
  await dialog.getByRole('button', { name: 'Supprimer', exact: true }).click()
  expect((await deleted).ok()).toBe(true)
  await expect(dialog).toBeHidden()
  await expect(main.getByText(device, { exact: true })).toHaveCount(0)
  await expect(main.getByText("Aucune clé d'accès enregistrée.", { exact: false })).toBeVisible()
  expect(await passkeysOf(user.accessToken)).toEqual([])

  // The browser's authenticator still holds the credential — deleting it on the server is what
  // must stop it from opening a session.
  expect(await authenticator.credentials()).toHaveLength(1)
  await signOutFromHeader(page, isMobile, user.user.displayName)
  const login = page.getByRole('main')
  await expect(login.getByRole('heading', { name: WELCOME })).toBeVisible()
  const quick = login.getByRole('button', { name: 'Connexion rapide' })
  await hydrated(quick)
  const refused = page.waitForResponse((r) => r.url().endsWith('/api/auth/passkeys/authenticate'))
  await quick.click()
  expect((await refused).ok(), 'the server refuses the deleted credential').toBe(false)
  await expect(page.getByText("Échec de l'authentification par clé d'accès")).toBeVisible()
  await expect(page).toHaveURL(/\/connexion$/)
  expect(await sessionCookie(context)).toBeUndefined()
})

/**
 * Links that were good once, and addresses the site must not reveal. A consumed or unknown token
 * says the same thing; an unknown address gets the very screen a known one gets, and no mail.
 */
test.describe('replayed links, unknown addresses, sign-up checks', () => {
  /**
   * A reset link used once from the form (which signs `page` in), then opened again from a browser
   * with no session — a second click in the mail — and submitted with another password. Returns
   * that second browser, and the server's answer to the replay.
   */
  async function replayResetLink(page: Page, browser: Browser) {
    const user = await newUser(unique('Lien rejoué'))
    const email = user.user.email
    const seen = await mailbox(email)
    await apiPost(undefined, '/api/auth/forgot-password', { email })
    const link = mailLinkTo(await waitForNewMail(email, seen), '/reset-password')

    /** Opens the link in `target` and submits `password` as the new one; the server's answer. */
    async function resetWith(target: Page, password: string) {
      await target.goto(link)
      const form = target.getByRole('main')
      await expect(
        form.getByRole('heading', { name: 'Réinitialiser le mot de passe' })
      ).toBeVisible()
      const submit = form.getByRole('button', { name: 'Réinitialiser le mot de passe' })
      await hydrated(submit)
      await form.getByRole('textbox', { name: 'Nouveau mot de passe' }).fill(password)
      await form.getByRole('textbox', { name: 'Confirmer le mot de passe' }).fill(password)
      const answered = target.waitForResponse((r) => r.url().endsWith('/api/auth/reset-password'))
      await submit.click()
      return answered
    }
    expect((await resetWith(page, 'e2e-first-reset')).ok()).toBe(true)
    await expect(page).toHaveURL(/\/$/)

    const other = await pageAs(browser, undefined)
    const replay = await resetWith(other.page, 'e2e-second-reset')
    return { user, email, other, replay }
  }

  test('a password reset link works once: replayed, the server refuses it and the password stays', async ({
    page,
    browser,
  }) => {
    const { user, email, other, replay } = await replayResetLink(page, browser)
    try {
      expect(replay.status()).toBe(400)
      expect((await replay.json()).code).toBe('TOKEN_INVALID')
      // The page says it itself (c153bb6f), rather than the API's « Le jeton est invalide » toast.
      await expect(
        other.page.getByRole('main').getByRole('heading', { name: 'Lien invalide' })
      ).toBeVisible()
      await expect(other.page.getByText('Le jeton est invalide')).toHaveCount(0)
      await expect(other.page).toHaveURL(/\/reset-password\?token=/)
      expect(await sessionCookie(other.context), 'no session for a spent link').toBeUndefined()
    } finally {
      await other.context.close()
    }
    expect((await loginWithPassword(email, 'e2e-first-reset')).user.id).toBe(user.user.id)
    await expect(loginWithPassword(email, 'e2e-second-reset')).rejects.toBeInstanceOf(ApiError)
  })

  // Regression (c153bb6f): ResetPasswordPage reads the code from the ApiClientError — before, a
  // replayed link never showed « Lien invalide », only two contradicting toasts.
  test('a replayed reset link shows « Lien invalide » and offers a new one', async ({
    page,
    browser,
  }) => {
    const { other } = await replayResetLink(page, browser)
    try {
      const form = other.page.getByRole('main')
      await expect(form.getByRole('heading', { name: 'Lien invalide' })).toBeVisible()
      await expect(
        form.getByText('Ce lien de réinitialisation est invalide ou a expiré.')
      ).toBeVisible()
      await expect(form.getByRole('link', { name: 'Demander un nouveau lien' })).toHaveAttribute(
        'href',
        '/mot-de-passe-oublie'
      )
    } finally {
      await other.context.close()
    }
  })

  /** Chooses `password` on the activation page a sign-up link opened, and activates. */
  async function activate(page: Page, password: string) {
    const main = page.getByRole('main')
    await expect(main.getByRole('heading', { name: 'Activer votre compte' })).toBeVisible()
    await main.getByRole('textbox', { name: 'Mot de passe', exact: true }).fill(password)
    await main.getByRole('textbox', { name: 'Confirmer le mot de passe' }).fill(password)
    await main.getByRole('button', { name: 'Activer mon compte' }).click()
  }

  // Audit M5 (SEC-9): loading someone else's sign-up link signed its reader into that account.
  test('a sign-up link opened while signed in shows its address, warns, and changes nothing until clicked', async ({
    browser,
  }) => {
    const reader = await newUser(unique('Lectrice du lien'))
    const email = freshAddress('lien transmis')
    const seen = await mailbox(email)
    await apiPost(undefined, '/api/auth/register', {
      email,
      displayName: unique('Autre compte'),
      acceptTerms: true,
    })
    const link = mailLinkTo(await waitForNewMail(email, seen), '/verify-email')

    const { context, page } = await pageAs(browser, reader)
    try {
      await page.goto(link)
      const main = page.getByRole('main')
      await expect(main.getByRole('heading', { name: 'Activer votre compte' })).toBeVisible()
      await expect(main.getByText(email).first()).toBeVisible()
      await expect(main.getByText('Votre session est ouverte en tant que')).toBeVisible()
      await expect(main.getByText(reader.user.email)).toBeVisible()

      const cookie = await sessionCookie(context)
      expect(cookie, 'still the reader’s session').toBeTruthy()
      expect((await meFromSession(context)).id).toBe(reader.user.id)
    } finally {
      await context.close()
    }
  })

  test('a verification link replayed in a fresh browser is refused and opens no session', async ({
    page,
    browser,
  }) => {
    const email = freshAddress('verification rejouee')
    const seen = await mailbox(email)
    await apiPost(undefined, '/api/auth/register', {
      email,
      displayName: unique('Vérifiée'),
      acceptTerms: true,
    })
    const link = mailLinkTo(await waitForNewMail(email, seen), '/verify-email')

    await page.goto(link)
    await activate(page, 'e2e-password')
    await expect(
      page.getByRole('main').getByRole('heading', { name: 'Sécurisez votre compte' })
    ).toBeVisible()

    const other = await pageAs(browser, undefined)
    try {
      await other.page.goto(link)
      const main = other.page.getByRole('main')
      await expect(main.getByRole('heading', { name: 'Lien invalide' })).toBeVisible()
      await expect(main.getByText('Ce lien de vérification est invalide.')).toBeVisible()
      await expect(main.getByRole('heading', { name: 'Sécurisez votre compte' })).toHaveCount(0)
      expect(await sessionCookie(other.context), 'no session for a spent link').toBeUndefined()
      // The login button leads to the form, nothing else.
      await main.getByRole('link', { name: 'Se connecter' }).click()
      await expect(main.getByRole('heading', { name: WELCOME })).toBeVisible()
    } finally {
      await other.context.close()
    }
  })

  test('a forgotten password for an unknown address shows the same screen and sends nothing', async ({
    page,
  }) => {
    const known = await newUser(unique('Oubli connu'))
    const unknown = freshAddress('oubli inconnu')

    /** Asks for a reset link from the form; returns the text of the screen that follows. */
    async function ask(email: string) {
      await page.goto('/mot-de-passe-oublie')
      const main = page.getByRole('main')
      const submit = main.getByRole('button', { name: 'Envoyer le lien' })
      await hydrated(submit)
      await main.getByRole('textbox', { name: 'Adresse e-mail' }).fill(email)
      const answered = page.waitForResponse((r) => r.url().endsWith('/api/auth/forgot-password'))
      await submit.click()
      expect((await answered).status()).toBe(200)
      await expect(main.getByRole('heading', { name: 'E-mail envoyé' })).toBeVisible()
      return main.innerText()
    }

    const seen = await mailbox(known.user.email)
    const forKnown = await ask(known.user.email)
    const forUnknown = await ask(unknown)
    expect(forUnknown, 'nothing on screen tells the two apart').toBe(forKnown)
    // The known address got its mail — sent in the same request as the unknown one's would have
    // been — so an empty mailbox for the unknown one is not a matter of waiting.
    await waitForNewMail(known.user.email, seen)
    expect(await mailsTo(unknown)).toEqual([])
  })

  test('a code for an unknown address leads to the same code step and sends nothing', async ({
    page,
  }) => {
    const known = await newUser(unique('Code connu'))
    const unknown = freshAddress('code inconnu')

    async function ask(email: string) {
      const main = await openLogin(page)
      const byMail = main.getByRole('button', { name: 'Connexion par e-mail' })
      await hydrated(byMail)
      await byMail.click()
      await main.getByRole('textbox', { name: 'Adresse e-mail' }).fill(email)
      const answered = page.waitForResponse((r) => r.url().endsWith('/api/auth/otp'))
      await main.getByRole('button', { name: 'Envoyer le code' }).click()
      expect((await answered).status()).toBe(200)
      await expect(main.getByRole('heading', { name: 'Entrez votre code' })).toBeVisible()
      return (await main.innerText()).replace(email, '<address>')
    }

    const seen = await mailbox(known.user.email)
    const forKnown = await ask(known.user.email)
    const forUnknown = await ask(unknown)
    expect(forUnknown, 'nothing on screen tells the two apart').toBe(forKnown)
    otpCodeIn(await waitForNewMail(known.user.email, seen))
    expect(await mailsTo(unknown)).toEqual([])
  })

  /** From the login page to the sign-up form, filled but for the terms. */
  async function fillSignUp(page: Page, email: string) {
    const main = await openLogin(page)
    const toRegister = main.getByRole('button', { name: 'Créer un compte' })
    await hydrated(toRegister)
    await toRegister.click()
    await expect(main.getByRole('heading', { name: 'Créer un compte' })).toBeVisible()
    await main.getByRole('textbox', { name: 'Adresse e-mail' }).fill(email)
    await main.getByRole('textbox', { name: 'Nom affiché' }).fill(unique('Inscription'))
    return main
  }

  test('sign-up needs the terms accepted: without them nothing is sent', async ({ page }) => {
    const email = freshAddress('sans cgu')
    const main = await fillSignUp(page, email)
    const terms = main.getByRole('checkbox', { name: /j'accepte les Conditions d'utilisation/ })
    await expect(terms).not.toBeChecked()
    let registrations = 0
    page.on('request', (r) => {
      if (r.url().endsWith('/api/auth/register')) registrations++
    })

    await main.getByRole('button', { name: 'Créer un compte' }).click()
    await expect(
      main.getByText(
        "Confirmez votre âge et acceptez les conditions d'utilisation pour créer un compte"
      )
    ).toBeVisible()
    await expect(main.getByRole('heading', { name: 'Créer un compte' })).toBeVisible()
    expect(registrations, 'the form stopped before the API').toBe(0)

    // Accepted, the same form goes through.
    await terms.check()
    const registered = page.waitForResponse((r) => r.url().endsWith('/api/auth/register'))
    await main.getByRole('button', { name: 'Créer un compte' }).click()
    expect((await registered).ok()).toBe(true)
    await expect(main.getByRole('heading', { name: WELCOME })).toBeVisible()
  })

  test('the server refuses a sign-up that does not accept the terms', async () => {
    const refused = await apiPost(undefined, '/api/auth/register', {
      email: freshAddress('api sans cgu'),
      displayName: unique('Sans CGU'),
      password: 'e2e-password',
      acceptTerms: false,
    }).catch((error: unknown) => error)
    expect(refused).toBeInstanceOf(ApiError)
    expect((refused as ApiError).status).toBe(400)
  })

  // Regression (c153bb6f): the auth pages read the code from the ApiClientError and pass
  // skipErrorToast — before, the mutator's toast and the page's own contradicted each other.
  test('a refused sign-up says why in one message', async ({ page }) => {
    const user = await newUser(unique('Déjà là'))
    const main = await fillSignUp(page, user.user.email)
    await main.getByRole('checkbox').check()
    const shown = await watchToasts(page)
    await main.getByRole('button', { name: 'Créer un compte' }).click()
    await expect(page.getByText('Un compte existe déjà avec cette adresse e-mail')).toBeVisible()
    expect(await shown()).toEqual(['Un compte existe déjà avec cette adresse e-mail'])
  })

  test('signing up with an address that has an account says so and sends no mail', async ({
    page,
  }) => {
    const user = await newUser(unique('Déjà inscrite'))
    const main = await fillSignUp(page, user.user.email)
    await main.getByRole('checkbox').check()
    const before = (await mailsTo(user.user.email)).length
    const registered = page.waitForResponse((r) => r.url().endsWith('/api/auth/register'))
    await main.getByRole('button', { name: 'Créer un compte' }).click()
    expect((await registered).status()).toBe(400)
    await expect(page.getByText('Un compte existe déjà avec cette adresse e-mail')).toBeVisible()
    // Still on the sign-up form, nothing lost.
    await expect(main.getByRole('heading', { name: 'Créer un compte' })).toBeVisible()
    await expect(main.getByRole('textbox', { name: 'Adresse e-mail' })).toHaveValue(user.user.email)
    expect((await mailsTo(user.user.email)).length).toBe(before)
    // The account is untouched.
    expect((await loginWithPassword(user.user.email, user.password)).user.id).toBe(user.user.id)
  })

  /**
   * The SMTP relay timing out (836fb72c): the backend answers 500 EMAIL_NOT_SENT and has created
   * nothing, so trying again works. The e2e mailer never fails, so the first answer is simulated;
   * the retry goes to the real backend. LoginPage.tsx (handleRegister) passes skipErrorToast and
   * shows the code's own message — one toast, and the form as it was.
   */
  test('a verification mail that cannot leave is said in one message, the form kept, and a retry goes through', async ({
    page,
  }) => {
    const email = freshAddress('mail non parti')
    const main = await fillSignUp(page, email)
    const displayName = await main.getByRole('textbox', { name: 'Nom affiché' }).inputValue()
    const terms = main.getByRole('checkbox')
    await terms.check()
    let refused = 0
    await page.route('**/api/auth/register', (route) => {
      if (refused > 0) return route.fallback()
      refused++
      return route.fulfill({
        status: 500,
        contentType: 'application/json',
        body: JSON.stringify({ code: 'EMAIL_NOT_SENT' }),
      })
    })
    const shown = await watchToasts(page)
    const create = main.getByRole('button', { name: 'Créer un compte' })
    await create.click()

    const message = "L'e-mail de vérification n'a pas pu partir. Réessayez dans un instant."
    await expect(page.getByText(message)).toBeVisible()
    expect(await shown()).toEqual([message])
    // Still the sign-up form, every field as typed.
    await expect(main.getByRole('heading', { name: 'Créer un compte' })).toBeVisible()
    await expect(main.getByRole('textbox', { name: 'Adresse e-mail' })).toHaveValue(email)
    await expect(main.getByRole('textbox', { name: 'Nom affiché' })).toHaveValue(displayName)
    await expect(terms).toBeChecked()

    // The same click again, now answered by the backend: the mail leaves, the login form follows.
    const seen = await mailbox(email)
    const registered = page.waitForResponse((r) => r.url().endsWith('/api/auth/register'))
    await create.click()
    expect((await registered).ok()).toBe(true)
    await expect(
      page.getByText(
        "Cliquez sur le lien dans l'e-mail pour choisir votre mot de passe et activer votre compte."
      )
    ).toBeVisible()
    await expect(main.getByRole('heading', { name: WELCOME })).toBeVisible()
    await expect(main.getByRole('textbox', { name: 'Adresse e-mail' })).toHaveValue(email)
    mailLinkTo(await waitForNewMail(email, seen), '/verify-email')
    expect(refused).toBe(1)
  })
})

/**
 * « Se connecter » from a page an anonymous visitor can read should bring them back to it once
 * signed in — as a protected page already does (ProtectedRoute passes `state.from`, LoginPage reads
 * it). These links go to a bare `/login`, so the visitor lands on the home feed instead.
 */
test.describe('back to the page after signing in', () => {
  /** A PUBLIC team with a PUBLIC ride and trip, and a visitor with an account. */
  async function publicContent(label: string) {
    const owner = await newUser(unique(`Organisatrice ${label}`))
    const team = await newTeam(owner, unique(`Équipe ouverte ${label}`), { visibility: 'PUBLIC' })
    const ride = await newRide(owner, team.slug, unique(`Sortie ouverte ${label}`), {
      visibility: 'PUBLIC',
    })
    const trip = await newTrip(
      owner,
      team.slug,
      unique(`Voyage ouvert ${label}`),
      [{ name: unique('Étape') }],
      { visibility: 'PUBLIC' }
    )
    const visitor = await newUser(unique(`Visiteuse ${label}`))
    return { team, ride, trip, visitor }
  }

  // Regression (ef9e2c3b): the notice's « Se connecter » passes `state.from`.
  test('from a ride, the notice’s « Se connecter » returns to the ride', async ({ page }) => {
    const { team, ride, visitor } = await publicContent('sortie')
    await openRide(page, team.slug, ride)
    const main = page.getByRole('main')
    const signInLink = main.getByRole('link', { name: 'Se connecter', exact: true })
    await expect(
      main.getByText('Connectez-vous et rejoignez cette équipe pour participer aux sorties.')
    ).toBeVisible()
    await hydrated(signInLink)
    await signInLink.click()
    await expect(main.getByRole('heading', { name: WELCOME })).toBeVisible()
    await signInWithPassword(page, visitor.user.email, visitor.password)
    await expect(page).toHaveURL(new RegExp(`${escapeRegExp(ridePath(team.slug, ride.slug))}$`))
    await expect(page.getByRole('heading', { level: 2, name: ride.name })).toBeVisible()
  })

  // Regression (ef9e2c3b): the notice's « Se connecter » passes `state.from`.
  test('from a trip, the notice’s « Se connecter » returns to the trip', async ({ page }) => {
    const { team, trip, visitor } = await publicContent('voyage')
    await page.goto(tripPath(team.slug, trip.slug))
    const main = page.getByRole('main')
    await expect(main.getByRole('heading', { level: 2, name: trip.name })).toBeVisible()
    await expect(
      main.getByText('Connectez-vous et rejoignez cette équipe pour participer aux voyages.')
    ).toBeVisible()
    const signInLink = main.getByRole('link', { name: 'Se connecter', exact: true })
    await hydrated(signInLink)
    await signInLink.click()
    await expect(main.getByRole('heading', { name: WELCOME })).toBeVisible()
    await signInWithPassword(page, visitor.user.email, visitor.password)
    await expect(page).toHaveURL(new RegExp(`${escapeRegExp(tripPath(team.slug, trip.slug))}$`))
  })

  // Regression (ef9e2c3b): the header's and the drawer's « Se connecter » pass `state.from`.
  test('from a ride, the header’s « Se connecter » returns to the ride', async ({
    page,
    isMobile,
  }) => {
    const { team, ride, visitor } = await publicContent('en-tête')
    await openRide(page, team.slug, ride)
    const controls = await headerControls(page, isMobile)
    const signInLink = controls.getByRole('link', { name: 'Se connecter', exact: true })
    await hydrated(signInLink)
    await signInLink.click()
    const main = page.getByRole('main')
    await expect(main.getByRole('heading', { name: WELCOME })).toBeVisible()
    await signInWithPassword(page, visitor.user.email, visitor.password)
    await expect(page).toHaveURL(new RegExp(`${escapeRegExp(ridePath(team.slug, ride.slug))}$`))
  })
})

/**
 * `?next=` on the login page (LoginPage.tsx → safeNextPath.ts): the path to load once signed in, by
 * `location.assign` — so a value the browser reads as another origin would be an open redirect,
 * one crafted link away from a phishing page that follows a genuine sign-in. It was (bug 44, fixed
 * by 9665d15e): the old prefix check let `/\t/evil.example` through, and the URL parser drops the
 * tab. A refused `next` falls back to the home feed. `evil.example` answers from `page.route`, so a
 * regression lands on a page the URL assertion names instead of on a DNS error.
 */
test.describe('?next= after signing in stays on the site', () => {
  const EVIL = 'evil.example'
  /** Every way off the site a `next` has been written, as the query string decodes it. */
  const HOSTILE: [string, string][] = [
    ['a tab after the slash', `/\t/${EVIL}`],
    ['a newline after the slash', `/\n/${EVIL}`],
    ['a backslash', `/\\${EVIL}`],
    ['a protocol-relative URL', `//${EVIL}/`],
    ['an absolute URL', `https://${EVIL}/`],
    ['a javascript: URL', 'javascript:alert(document.domain)'],
  ]

  const loginWithNext = (next: string) => `/connexion?next=${encodeURIComponent(next)}`

  /** Records every request to evil.example (answered by a stub page) and every dialog. */
  async function watchEscape(page: Page) {
    const escaped: string[] = []
    await page.route(
      (url) => url.hostname === EVIL,
      (route) => {
        escaped.push(route.request().url())
        return route.fulfill({ contentType: 'text/html', body: '<h1>evil</h1>' })
      }
    )
    page.on('dialog', (dialog) => {
      escaped.push(`dialog: ${dialog.message()}`)
      return dialog.dismiss()
    })
    return escaped
  }

  for (const [label, next] of HOSTILE)
    test(`signing in with ${label} as next lands on the home feed`, async ({ page }) => {
      const user = await newUser(unique('Next hostile'))
      const escaped = await watchEscape(page)
      await page.goto(loginWithNext(next))
      await expect(page.getByRole('main').getByRole('heading', { name: WELCOME })).toBeVisible()
      await signInWithPassword(page, user.user.email, user.password)
      await expect(page).toHaveURL(`${stack.baseURL}/`)
      // Signed in, on the site's own feed.
      await expect(
        page.getByRole('link', { name: 'Calendrier', exact: true }).first()
      ).toBeVisible()
      expect(escaped).toEqual([])
    })

  // The login route is `unauthenticated` (routes.config.ts): a signed-in visitor never reaches
  // LoginPage and is sent home whatever the `next` — a crafted link sent to a member included.
  test('a signed-in visitor following a crafted login link stays on the site', async ({
    page,
    context,
  }) => {
    const user = await newUser(unique('Next connectée'))
    await signIn(context, user)
    const escaped = await watchEscape(page)
    for (const [label, next] of HOSTILE) {
      await page.goto(loginWithNext(next))
      await expect(page, label).toHaveURL(`${stack.baseURL}/`)
    }
    expect(escaped).toEqual([])
  })

  test('signing in with a valid next returns to that path, query string included', async ({
    page,
  }) => {
    const user = await newUser(unique('Next valide'))
    await page.goto(loginWithNext('/profil?onglet=1'))
    await expect(page.getByRole('main').getByRole('heading', { name: WELCOME })).toBeVisible()
    await signInWithPassword(page, user.user.email, user.password)
    await expect(page).toHaveURL(`${stack.baseURL}/profil?onglet=1`)
    await expect(page.getByRole('main').getByRole('heading', PROFILE)).toBeVisible()
  })

  // The data export's download link sends a visitor without a session to exactly this (the full
  // round trip, with a real export, is in « personal data export »): an API path, loaded as a
  // document from the server rather than routed by the app — here a forged token, so the backend's
  // 404, on this origin.
  test('signing in with an API path as next loads it from the server', async ({ page }) => {
    const user = await newUser(unique('Next API'))
    const download = '/api/export/download?token=not-a-real-token'
    await page.goto(loginWithNext(download))
    await expect(page.getByRole('main').getByRole('heading', { name: WELCOME })).toBeVisible()
    const answered = page.waitForResponse((r) => r.url() === `${stack.baseURL}${download}`)
    await signInWithPassword(page, user.user.email, user.password)
    const response = await answered
    expect(response.status()).toBe(404)
    // A document load of the page itself — not a fetch by the app. (Chrome then shows its own error
    // page for the empty 404, so the URL is not asserted.)
    expect(response.request().isNavigationRequest()).toBe(true)
    expect(response.request().frame()).toBe(page.mainFrame())
  })
})

test.describe('time zone', () => {
  const ZONE = 'Asia/Tokyo'
  // TimezoneSelect names each zone by its city first (API-60): « Tokyo · Asia/Tokyo ».
  const PARIS_LABEL = 'Paris · Europe/Paris'
  const ZONE_LABEL = `Tokyo · ${ZONE}`

  /**
   * The timezone picker of « Préférences » (a searchable combobox), found through the text that stands
   * for its label — it has no accessible name, see the test below.
   */
  const zoneField = (page: Page) =>
    page
      .getByRole('main')
      .getByText('Fuseau horaire', { exact: true })
      .locator('xpath=following-sibling::*[1]/descendant-or-self::input')

  test('the chosen zone sets the times shown, in the browser and in the server-rendered page', async ({
    page,
    context,
  }) => {
    const user = await newUser(unique('Fuseau'))
    const team = await newTeam(user, unique('Équipe fuseau'))
    // 08:30 UTC two days ahead: 10:30 or 09:30 in Paris, 17:30 in Tokyo — never the same text.
    // A departure reads in the ride's zone, the team's Paris, whatever the reader's (API-60): the
    // preference shows in the « chez vous » mention that follows it.
    const start = new Date(Date.now() + 2 * 24 * 3600 * 1000)
    start.setUTCHours(8, 30, 0, 0)
    const ride = await newRide(user, team.slug, unique('Sortie fuseau'), {
      dateTime: wallTimeOf(start),
    })
    const inParis = frenchDateTime(wallClockIn(ride.dateTime, 'Europe/Paris'))
    const tokyo = wallClockIn(ride.dateTime, ZONE)
    const mention = `${inParis} · heure de Paris (${clockText(tokyo)} chez vous)`
    const path = ridePath(team.slug, ride.slug)
    await signIn(context, user)

    // No preference yet: the browser's own zone (Europe/Paris, playwright.config.ts).
    expect((await meFromSession(user)).timezone ?? null).toBeNull()
    await openRide(page, team.slug, ride)
    const main = page.getByRole('main')
    await expect(main.getByText(inParis, { exact: true }).first()).toBeVisible()
    await expect(main.getByText('chez vous')).toHaveCount(0)

    // Chosen from the profile: a partial PATCH of the preferences.
    await openProfilePage(page, '/profil/preferences', 'Préférences')
    const field = zoneField(page)
    await expect(field).toHaveValue(PARIS_LABEL)
    await hydrated(field)
    await field.click()
    await field.fill(ZONE)
    const saved = page.waitForResponse(
      (r) => r.request().method() === 'PATCH' && r.url().endsWith('/api/users/me/preferences')
    )
    await page.getByRole('option', { name: ZONE_LABEL, exact: true }).click()
    const response = await saved
    expect(response.ok()).toBe(true)
    expect(response.request().postDataJSON()).toEqual({ timezone: ZONE })
    await expect(field).toHaveValue(ZONE_LABEL)
    expect((await meFromSession(user)).timezone).toBe(ZONE)

    // The ride still reads in Paris time, now with its Tokyo equivalent, in a browser that is still
    // in Paris…
    await openRide(page, team.slug, ride)
    await expect(main.getByText(mention, { exact: true })).toBeVisible()
    // …and already in the server's markup, before any JavaScript.
    const document = await rawDocument(path, { cookie: ssrCookie(user) })
    expect(document.status).toBe(200)
    const markup = ssrOutlet(document.html)
    expect(markup).toContain(ride.name)
    // A chosen zone is no guess: the server states the mention too.
    expect(markup).toContain(inParis)
    expect(markup).toContain(`heure de Paris (${clockText(tokyo)} chez vous)`)
  })

  // Regression (02bd4525): the time zone Select carries its `label`.
  test('the time zone field is named by its label', async ({ page, context }) => {
    const user = await newUser(unique('Fuseau nommé'))
    await signIn(context, user)
    await openProfilePage(page, '/profil/preferences', 'Préférences')
    await expect(zoneField(page)).toBeVisible()
    await expect(
      page.getByRole('main').getByRole('combobox', { name: 'Fuseau horaire' })
    ).toHaveValue(PARIS_LABEL, { timeout: 2_000 })
  })
})

/**
 * « Demander mes données » (DataExportManager.tsx, on « Confidentialité »): the archive is built in the background — the
 * backend's scheduler takes one pending export per 30 s tick — and its link arrives by mail. Since
 * 7028b868 the link alone is not enough (UserExportDownloadResource.java): the token proves the
 * mailbox, the owner's session the account. A visitor without a session is sent (303) to the login
 * page, which brings them back (`?next=`); another account gets the 404 of an unknown token.
 */
test.describe('personal data export', () => {
  test('requested from the profile, mailed as a link, downloaded by its owner only, holding the owner’s data', async ({
    page,
    context,
    browser,
  }) => {
    // One export per scheduler tick, and other runs may have queued theirs.
    test.setTimeout(240_000)
    const user = await newUser(unique('Export RGPD'))
    const other = await newUser(unique('Pas mon export'))
    await signIn(context, user)
    const main = await openProfilePage(page, '/profil/vie-privee', 'Confidentialité')
    await expect(main.getByRole('heading', { name: 'Mes données' })).toBeVisible()

    const request = main.getByRole('button', { name: 'Demander mes données' })
    await hydrated(request)
    const seen = await mailbox(user.user.email)
    const requested = page.waitForResponse(
      (r) => r.request().method() === 'POST' && r.url().endsWith('/api/users/me/export')
    )
    await request.click()
    expect((await requested).status()).toBe(202)
    await expect(
      page.getByText("Export demandé. Vous recevrez un e-mail dès qu'il sera prêt.")
    ).toBeVisible()

    // One at a time: the button waits, and the API refuses a second one.
    const refused = await apiPost(user, '/api/users/me/export').catch((error: unknown) => error)
    expect(refused).toBeInstanceOf(ApiError)
    expect((refused as ApiError).status).toBe(429)
    // Another account has no export of its own, and sees nothing of this one.
    expect(await apiGetOrNull(other, '/api/users/me/export')).toBeFalsy()

    const mail = await waitForNewMail(user.user.email, seen, 200_000)
    // The token is a query parameter, which the access log masks (docs/LEDGER_*.md API-45).
    const link = mailLinkTo(mail, '/api/export/download')

    // The profile follows the export to its end.
    await expect(
      main.getByText(/^Votre export est prêt\. Le lien envoyé par e-mail est valable jusqu'au /)
    ).toBeVisible({ timeout: 15_000 })
    await expect(main.getByText('Préparation en cours')).toHaveCount(0)
    await expect(request).toBeEnabled()

    // Opened from the mail in a browser with no session: the login page, which will come back.
    const anonymous = await pageAs(browser, undefined)
    try {
      await anonymous.page.goto(link)
      await expect(anonymous.page).toHaveURL(
        (url) =>
          /^\/(login|connexion)$/.test(url.pathname) &&
          url.searchParams.get('next') === new URL(link).pathname + new URL(link).search
      )
      // Signing in there brings the owner back to the link: the archive downloads.
      const downloaded = anonymous.page.waitForEvent('download')
      await signInWithPassword(anonymous.page, user.user.email, user.password)
      expect((await downloaded).suggestedFilename()).toMatch(/^pedalons-export-.+\.zip$/)
    } finally {
      await anonymous.context.close()
    }

    // Another account, signed in: the 404 of an unknown token — nothing tells the export exists.
    const stranger = await pageAs(browser, other)
    try {
      expect((await stranger.context.request.get(link, { maxRedirects: 0 })).status()).toBe(404)
    } finally {
      await stranger.context.close()
    }

    // The owner, signed in: a ZIP of their account.
    const download = page.waitForEvent('download')
    await page.goto(link).catch(() => {
      // Navigating to an attachment aborts the navigation: the download is the answer.
    })
    const file = await download
    expect(file.suggestedFilename()).toMatch(/^pedalons-export-.+\.zip$/)
    const archive = readFileSync(await file.path())
    const profile = JSON.parse(zipEntry(archive, 'account/profile.json').toString('utf8'))
    expect(profile).toMatchObject({ id: user.user.id, email: user.user.email })
    expect(archive.includes(Buffer.from(other.user.email)), 'nothing of another account').toBe(
      false
    )

    // A forged token opens nothing, even for the owner.
    const forged = link.replace(/.$/, (c) => (c === 'A' ? 'B' : 'A'))
    expect((await context.request.get(forged, { maxRedirects: 0 })).status()).toBe(404)
  })
})
