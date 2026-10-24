import type { Browser, Page } from '@playwright/test'
import type { AdDto, ErrorResponse, TeamDetailDto } from '../src/api/dto'
import type { AuthResponse } from './support/api'
import { contactAuthor, rawAd, setContactable } from './support/ad-contact'
import { newAd } from './support/ads'
import { addMember, newTeam, newUser, roleSession, signIn } from './support/data'
import { expect, test, unique } from './support/fixtures'
import { mailsTo } from './support/mailpit'
import { hydrated, toasts, watchToasts } from './support/ui'

/**
 * « Contacter le vendeur » — the classified-ad relay (docs/LEDGER_*.md WEB-15, and MOB-12 « Contact du
 * vendeur (32) » for the outcomes).
 *
 * The relay never discloses an address: the server mails the author with Reply-To set to the sender.
 * Its four outcomes render four distinct screens — 204 and AD_CONTACT_OPTED_OUT close the modal and
 * leave a persistent Alert on the page; 429 and 500 stay in the modal with the draft kept.
 *
 * Limits read from the code: message 10..2000 characters (contactAdAuthorBodyMessageMin/Max in
 * src/api/zod/ads/ads.zod.ts), quota 10 messages per sender per 60 minutes
 * (pedalons.ads.contact.* in backend application.properties).
 */

const DRAFT = 'Bonjour, le vélo est-il toujours disponible ? Je peux passer samedi.'
const CONTACT_URL = /\/api\/teams\/[^/]+\/classifieds\/[^/]+\/contact$/

interface Scene {
  team: TeamDetailDto
  seller: AuthResponse
  buyer: AuthResponse
  ad: AdDto
}

/** A team of its own, a seller with a published ad, and a buyer who is a member of the team. */
async function scene(): Promise<Scene> {
  const [admin, seller, buyer] = await Promise.all([
    roleSession('admin'),
    newUser('Vendeur E2E'),
    newUser('Acheteur E2E'),
  ])
  const team = await newTeam(seller, unique('Annonces E2E'))
  await addMember(admin, team.slug, buyer)
  const ad = await newAd(seller, team.slug, {
    name: unique('Vélo de route'),
    body: 'Vélo de route, taille 56.',
    price: 1200,
  })
  return { team, seller, buyer, ad }
}

async function openAd(browser: Browser, as: AuthResponse, s: Scene): Promise<Page> {
  const context = await browser.newContext()
  await signIn(context, as)
  const page = await context.newPage()
  await page.goto(`/equipes/${s.team.slug}/annonces/${s.ad.slug}`)
  // The page has loaded when the ad's title and its seller section are there.
  await expect(page.getByRole('heading', { name: s.ad.name })).toBeVisible()
  await expect(page.getByRole('heading', { name: 'Publiée par' })).toBeVisible()
  return page
}

const contactButton = (page: Page) => page.getByRole('button', { name: "Répondre à l'annonce" })
const dialog = (page: Page) => page.getByRole('dialog', { name: "Répondre à l'annonce" })
const messageBox = (page: Page) => dialog(page).getByRole('textbox', { name: 'Votre message' })
/** The relayed mails about this ad in the seller's mailbox (the sign-up mail does not name it). */
async function relayedAbout(s: Scene) {
  return (await mailsTo(s.seller.user.email)).filter((m) =>
    m.parts.some((part) => part.includes(s.ad.name))
  )
}

/** A state of the page, inside <main> — not a toast (portaled) nor the modal (portaled). */
const pageAlert = (page: Page) => page.getByRole('main').getByRole('alert')

async function openModal(page: Page) {
  // The button is server-rendered: a click that lands before hydration does nothing.
  await hydrated(contactButton(page))
  await contactButton(page).click()
  await expect(dialog(page)).toBeVisible()
}

/** Every call the page makes to the relay endpoint, to prove the client refuses without one. */
function recordContactCalls(page: Page): string[] {
  const calls: string[] = []
  page.on('request', (request) => {
    if (CONTACT_URL.test(new URL(request.url()).pathname)) calls.push(request.method())
  })
  return calls
}

/** Consumes the sender's real quota: 10 relayed messages per 60 minutes, whoever they write to. */
async function exhaustQuota(s: Scene) {
  for (let i = 1; i <= 10; i++) {
    await contactAuthor(s.buyer, s.team.slug, s.ad.slug, `Message de quota numéro ${i}.`)
  }
}

/**
 * Mocked: mailpit accepts every message, so the real stack cannot make the SMTP relay fail. The
 * answer is exactly what AdService.contactAuthor sends when the relay throws.
 */
async function failDelivery(page: Page) {
  const failure: ErrorResponse = { code: 'AD_CONTACT_DELIVERY_FAILED' }
  await page.route(CONTACT_URL, (route) =>
    route.fulfill({ status: 500, contentType: 'application/json', body: JSON.stringify(failure) })
  )
}

test.describe('contacting the seller of an ad', () => {
  test('success: the modal closes, a confirmation replaces the button on the page, and the relayed mail hides the addresses', async ({
    browser,
  }) => {
    const s = await scene()
    const page = await openAd(browser, s.buyer, s)

    // The API carries no address of the author (root CLAUDE.md: AdDto has no contact field).
    expect(await rawAd(s.buyer, s.team.slug, s.ad.slug)).not.toContain(s.seller.user.email)

    await openModal(page)
    await expect(
      dialog(page).getByText(`Votre message part par e-mail à ${s.ad.createdByDisplayName}.`)
    ).toBeVisible()
    const toastTexts = await watchToasts(page)
    await messageBox(page).fill(DRAFT)
    const answered = page.waitForResponse((r) => CONTACT_URL.test(new URL(r.url()).pathname))
    await dialog(page).getByRole('button', { name: 'Envoyer' }).click()
    expect((await answered).status()).toBe(204)

    await expect(dialog(page)).toBeHidden()
    // A state of the page, inside <main> — not a toast that vanishes before it is read.
    await expect(pageAlert(page)).toHaveText(
      'Message envoyé, la réponse vous arrivera directement par e-mail.'
    )
    await expect(contactButton(page)).toHaveCount(0)
    expect(await toastTexts()).toEqual([])
    // The author's address never reaches the DOM (the buyer's own is in their session state).
    expect(await page.content()).not.toContain(s.seller.user.email)

    // The relayed mail: to the seller, Reply-To the buyer, and no part ever prints that address.
    await expect.poll(async () => (await relayedAbout(s)).length).toBe(1)
    const [relayed] = await relayedAbout(s)
    expect(relayed.parts.some((part) => part.includes(DRAFT))).toBe(true)
    expect(relayed.headers['reply-to']).toContain(s.buyer.user.email)
    expect(relayed.headers['from']).not.toContain(s.buyer.user.email)
    for (const part of relayed.parts) expect(part).not.toContain(s.buyer.user.email)
  })

  test('AD_CONTACT_OPTED_OUT: the modal closes, a persistent notice replaces the button, and nothing is mailed', async ({
    browser,
  }) => {
    const s = await scene()
    await setContactable(s.seller, false)
    const page = await openAd(browser, s.buyer, s)

    await openModal(page)
    await messageBox(page).fill(DRAFT)
    const answered = page.waitForResponse((r) => CONTACT_URL.test(new URL(r.url()).pathname))
    await dialog(page).getByRole('button', { name: 'Envoyer' }).click()
    const response = await answered
    expect(((await response.json()) as ErrorResponse).code).toBe('AD_CONTACT_OPTED_OUT')

    await expect(dialog(page)).toBeHidden()
    await expect(pageAlert(page)).toHaveText(
      'Ce membre a choisi de ne pas recevoir de messages au sujet de ses annonces.'
    )
    // Trying again would change nothing: the button is gone.
    await expect(contactButton(page)).toHaveCount(0)
    // Persistent: once any toast has timed out, the notice is still on the page.
    await expect(toasts(page)).toHaveCount(0, { timeout: 15_000 })
    await expect(pageAlert(page)).toBeVisible()
    expect(await relayedAbout(s)).toEqual([])
  })

  test('AD_CONTACT_RATE_LIMITED (429): the modal stays open with the draft and says when to retry', async ({
    browser,
  }) => {
    const s = await scene()
    await exhaustQuota(s)
    const page = await openAd(browser, s.buyer, s)

    await openModal(page)
    await messageBox(page).fill(DRAFT)
    const answered = page.waitForResponse((r) => CONTACT_URL.test(new URL(r.url()).pathname))
    await dialog(page).getByRole('button', { name: 'Envoyer' }).click()
    const response = await answered
    expect(response.status()).toBe(429)
    expect(((await response.json()) as ErrorResponse).code).toBe('AD_CONTACT_RATE_LIMITED')
    expect(response.headers()['retry-after']).toBe('3600')

    // Retry-After is used: 3600 s → 60 minutes.
    await expect(
      dialog(page).getByRole('alert').filter({ hasText: 'trop de messages' })
    ).toHaveText('Vous avez envoyé trop de messages récemment. Réessayez dans 60 minutes.')
    await expect(messageBox(page)).toHaveValue(DRAFT)
    await expect(dialog(page).getByRole('button', { name: 'Réessayer' })).toBeEnabled()
    // No success on the page; the button stays, since a later attempt may go through.
    await expect(pageAlert(page)).toHaveCount(0)
    await page.keyboard.press('Escape')
    await expect(dialog(page)).toBeHidden()
    await expect(contactButton(page)).toBeVisible()
    // The eleventh message was refused: only the ten of the quota reached the seller.
    expect(await relayedAbout(s)).toHaveLength(10)
  })

  test('AD_CONTACT_DELIVERY_FAILED (500): no success shown, the draft is kept, and a retry goes through', async ({
    browser,
  }) => {
    const s = await scene()
    const page = await openAd(browser, s.buyer, s)
    await failDelivery(page)

    await openModal(page)
    await messageBox(page).fill(DRAFT)
    await dialog(page).getByRole('button', { name: 'Envoyer' }).click()

    await expect(dialog(page).getByRole('alert').filter({ hasText: "n'est pas parti" })).toHaveText(
      "Le message n'est pas parti. Réessayez dans un moment."
    )
    await expect(messageBox(page)).toHaveValue(DRAFT)
    // « Aucun succès affiché sur un 500. »
    await expect(pageAlert(page)).toHaveCount(0)
    await expect(
      page.getByText('Message envoyé, la réponse vous arrivera directement par e-mail.')
    ).toHaveCount(0)

    // The relay is back: the kept draft goes out as is.
    await page.unroute(CONTACT_URL)
    const answered = page.waitForResponse((r) => CONTACT_URL.test(new URL(r.url()).pathname))
    await dialog(page).getByRole('button', { name: 'Réessayer' }).click()
    expect((await answered).status()).toBe(204)
    await expect(dialog(page)).toBeHidden()
    await expect(pageAlert(page)).toHaveText(
      'Message envoyé, la réponse vous arrivera directement par e-mail.'
    )
    await expect.poll(async () => (await relayedAbout(s)).length).toBe(1)
    expect((await relayedAbout(s))[0].parts.some((part) => part.includes(DRAFT))).toBe(true)
  })

  test('too short, blank or too long messages are refused client-side, with no network call', async ({
    browser,
  }) => {
    const s = await scene()
    const page = await openAd(browser, s.buyer, s)
    const calls = recordContactCalls(page)
    await openModal(page)
    const send = dialog(page).getByRole('button', { name: 'Envoyer' })

    await messageBox(page).fill('x'.repeat(9))
    await expect(dialog(page).getByText('9 / 2000')).toBeVisible()
    await expect(send).toBeDisabled()

    await messageBox(page).fill('x'.repeat(2001))
    await expect(dialog(page).getByText('2001 / 2000')).toBeVisible()
    await expect(send).toBeDisabled()

    // Ten spaces: long enough to enable the button, but blank — the submit is refused locally.
    await messageBox(page).fill(' '.repeat(10))
    await expect(send).toBeEnabled()
    await send.click()
    await expect(dialog(page).getByText('Le message ne peut pas être vide.')).toBeVisible()

    // The bounds themselves are accepted: the checks above are not a button that is always off.
    await messageBox(page).fill('x'.repeat(2000))
    await expect(send).toBeEnabled()
    await messageBox(page).fill('x'.repeat(10))
    await expect(send).toBeEnabled()

    expect(calls).toEqual([])
  })

  test('the button is absent on one’s own ad', async ({ browser }) => {
    const s = await scene()
    const page = await openAd(browser, s.seller, s)
    // The seller's view of a loaded ad: its edit action is there.
    await expect(page.getByRole('link', { name: 'Modifier' })).toBeVisible()
    await expect(contactButton(page)).toHaveCount(0)
  })

  test('the modal’s cancel button is labelled « Annuler » and closes without sending', async ({
    browser,
  }) => {
    // It once read « actions.cancel », a key missing from both locales, and the close cross had no
    // accessible name (fixed 2026-09-25).
    const s = await scene()
    const page = await openAd(browser, s.buyer, s)
    const calls = recordContactCalls(page)
    await openModal(page)
    await messageBox(page).fill(DRAFT)
    // Precondition: the modal is open, the draft in, and its footer rendered.
    await expect(
      dialog(page).getByRole('button', { name: 'Envoyer' }),
      'precondition: the modal is ready to send'
    ).toBeEnabled()
    await expect(dialog(page).getByRole('button', { name: 'Fermer la fenêtre' })).toBeVisible()
    await dialog(page).getByRole('button', { name: 'Annuler' }).click()
    await expect(dialog(page)).toBeHidden()
    await expect(contactButton(page)).toBeVisible()
    expect(calls).toEqual([])
  })

  // docs/LEDGER_*.md WEB-15: « pas de double message (l'Alert de la modale plus le toast global) ». The
  // contact call opts out of the global error toast (skipErrorToast); before that, every failure
  // below was announced twice (fixed 2026-09-25).
  test.describe('no double message', () => {
    test('429: the modal Alert is the only message', async ({ browser }) => {
      const s = await scene()
      await exhaustQuota(s)
      const page = await openAd(browser, s.buyer, s)
      await openModal(page)
      const toastTexts = await watchToasts(page)
      await messageBox(page).fill(DRAFT)
      await dialog(page).getByRole('button', { name: 'Envoyer' }).click()
      await expect(
        dialog(page).getByRole('alert').filter({ hasText: 'trop de messages' }),
        'precondition: the quota is spent and the modal says so'
      ).toBeVisible()
      expect(await toastTexts()).toEqual([])
    })

    test('500: the modal Alert is the only message', async ({ browser }) => {
      const s = await scene()
      const page = await openAd(browser, s.buyer, s)
      await failDelivery(page)
      await openModal(page)
      const toastTexts = await watchToasts(page)
      await messageBox(page).fill(DRAFT)
      await dialog(page).getByRole('button', { name: 'Envoyer' }).click()
      await expect(
        dialog(page).getByRole('alert').filter({ hasText: "n'est pas parti" }),
        'precondition: the delivery failed and the modal says so'
      ).toBeVisible()
      expect(await toastTexts()).toEqual([])
    })

    test('AD_CONTACT_OPTED_OUT: the page Alert is the only message', async ({ browser }) => {
      const s = await scene()
      await setContactable(s.seller, false)
      const page = await openAd(browser, s.buyer, s)
      await openModal(page)
      const toastTexts = await watchToasts(page)
      await messageBox(page).fill(DRAFT)
      await dialog(page).getByRole('button', { name: 'Envoyer' }).click()
      await expect(pageAlert(page), 'precondition: the opt-out notice is on the page').toHaveText(
        'Ce membre a choisi de ne pas recevoir de messages au sujet de ses annonces.'
      )
      expect(await toastTexts()).toEqual([])
    })
  })
})
