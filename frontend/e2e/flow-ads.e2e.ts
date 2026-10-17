import type { Page } from '@playwright/test'
import type {
  AdDto,
  AdEditDto,
  AdRequest,
  AssetDto,
  GeocodeResultDto,
  TeamDetailDto,
  TeamRole,
} from '../src/api/dto'
import {
  ApiError,
  apiDelete,
  apiGet,
  apiGetOrNull,
  apiPost,
  apiPut,
  type AuthResponse,
} from './support/api'
import { getAd, newAd, solidPng, uploadImage } from './support/ads'
import {
  addMember,
  markdownMedia,
  newTeam,
  newUser,
  roleSession,
  signIn,
  teamRequest,
} from './support/data'
import { addImage, richText } from './support/editor'
import { expect, test, unique } from './support/fixtures'
import {
  actionsMenu,
  entityCard,
  escapeRegExp,
  hydrated,
  openActionsMenu,
  pageHydrated,
  toasts,
} from './support/ui'

/**
 * Ads, the nominal journey through the UI: a plain member of a team writes an ad with the form
 * (type, price, description, two photos, a place), finds it in the team's list, edits its price and
 * swaps a photo, unpublishes it, deletes it.
 *
 * Browsing an existing ad (gallery, list filters) is ads-browse.e2e.ts, the contact relay
 * ad-contact.e2e.ts.
 *
 * There is no « vendu » state on the web: an ad is DRAFT or PUBLISHED (the form's « Statut »), and
 * the detail page's menu offers « Dépublier » — that is what « closing » an ad means here.
 */

interface Scene {
  team: TeamDetailDto
  /** A MEMBER of the team — not its admin — so the journey shows what any member may do. */
  member: AuthResponse
}

/** A team of its own, owned by someone else, and the member who writes the ads. */
async function scene(): Promise<Scene> {
  const [admin, owner, member] = await Promise.all([
    roleSession('admin'),
    newUser('Bureau annonces'),
    newUser('Vendeur annonces'),
  ])
  const team = await newTeam(owner, unique('Annonces parcours'))
  await addMember(admin, team.slug, member)
  return { team, member }
}

/** Another member of the team, to check what the rest of the team sees. */
async function anotherMember(team: TeamDetailDto): Promise<AuthResponse> {
  const [admin, other] = await Promise.all([roleSession('admin'), newUser('Lecteur annonces')])
  await addMember(admin, team.slug, other)
  return other
}

const listPath = (teamSlug: string) => `/equipes/${teamSlug}/annonces`
const adPath = (teamSlug: string, slug: string) => `/equipes/${teamSlug}/annonces/${slug}`

/** The names of the ads `reader` gets in the team's list. */
async function listedNames(reader: AuthResponse, teamSlug: string): Promise<string[]> {
  const list = await apiGet<{ ads: AdDto[] }>(reader, `/api/teams/${teamSlug}/classifieds`, {
    size: 100,
  })
  return list.ads.map((ad) => ad.name)
}

/**
 * The server's blur (backend CoarseLocation.blur): the centre of the ~1 km cell holding the point,
 * 0.01° of latitude high and 0.01°/cos(lat) wide, rounded to six decimals.
 */
function blurred(lon: number, lat: number): [number, number] {
  const snap = (value: number, step: number) =>
    Math.round((Math.floor(value / step) + 0.5) * step * 1e6) / 1e6
  const blurredLat = snap(lat, 0.01)
  const cos = Math.max(Math.cos((blurredLat * Math.PI) / 180), 0.05)
  return [snap(lon, 0.01 / cos), blurredLat]
}

const mainOf = (page: Page) => page.getByRole('main')

/** The ad's card in the team's list. */
const card = (page: Page, name: string) => entityCard(mainOf(page), name)

/** Adds a picture through the description editor's « Image » control; returns its asset. */
const addPhoto = (page: Page, name: string, colour: [number, number, number]) =>
  addImage(page, mainOf(page), name, colour)

/**
 * Rennes, as the address lookup answers it. GET /api/geocode/search is the backend's proxy to the
 * Stadia Maps geocoder — a paid third-party service the stack does not include, changing under us —
 * so the browser's lookup is answered here; what is under test is the form, the blur and the
 * sector, not the provider's data.
 */
const RENNES: GeocodeResultDto = {
  id: 'e2e-rennes',
  displayName: 'Rennes, Ille-et-Vilaine, Bretagne, France métropolitaine, France',
  lat: 48.1113387,
  lon: -1.6800198,
}

/** « 350,00 € » as Intl formats it in fr-FR (narrow no-break space before the sign). */
const euros = (amount: number) =>
  new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR' }).format(amount)

test.describe('ad journey', () => {
  test('a member publishes a sale ad with two photos and a place, shown as a sector', async ({
    page,
    context,
  }) => {
    const { team, member } = await scene()
    const name = unique('Vélo gravel')

    await signIn(context, member)
    await page.goto(listPath(team.slug))
    await expect(page.getByRole('heading', { level: 2, name: 'Annonces' })).toBeVisible()
    const create = page.getByRole('main').getByRole('link', { name: 'Créer une annonce' })
    await hydrated(create)
    await create.click()

    await expect(page.getByRole('heading', { level: 1, name: 'Nouvelle annonce' })).toBeVisible()
    const main = page.getByRole('main')
    const title = main.getByRole('textbox', { name: /^Titre/ })
    await hydrated(title)
    await title.fill(name)
    // Sale is the default type; checking it says the form offers it.
    await expect(main.getByRole('radio', { name: 'Vente' })).toBeChecked()
    await main.getByRole('textbox', { name: 'Prix' }).fill('350')

    await richText(main).click()
    await page.keyboard.type('Gravel en acier, taille M, pneus neufs.')
    const first = await addPhoto(page, 'gravel-profil.png', [200, 60, 40])
    const second = await addPhoto(page, 'gravel-detail.png', [40, 90, 200])

    await main.getByRole('textbox', { name: 'Description du lieu' }).fill('Rennes centre')
    // The point the member picks is the one the lookup's result carries.
    const lookups: string[] = []
    await page.route(
      (url) => url.pathname === '/api/geocode/search',
      (route) => {
        lookups.push(new URL(route.request().url()).searchParams.get('q') ?? '')
        return route.fulfill({ json: [RENNES] })
      }
    )
    await main.getByRole('textbox', { name: 'Localisation', exact: true }).fill('Rennes')
    const place = RENNES
    await main.getByRole('button', { name: place.displayName }).first().click()
    expect(lookups, 'the form looked the typed address up').toContain('Rennes')
    await expect(main.getByRole('button', { name: 'Supprimer la localisation' })).toBeVisible()

    await main.getByRole('radio', { name: 'Publié' }).check()
    await main.getByRole('button', { name: "Créer l'annonce" }).click()

    // The detail page of the new ad.
    await expect(page.getByRole('heading', { level: 2, name })).toBeVisible()
    await expect(page).toHaveURL(new RegExp(`/equipes/${team.slug}/annonces/(?!nouvelle$)[^/]+$`))
    const slug = new URL(page.url()).pathname.split('/').at(-1)!
    await expect(main.getByText(euros(350), { exact: true })).toBeVisible()
    await expect(main.getByText('Gravel en acier, taille M, pneus neufs.')).toBeVisible()
    await expect(main.getByText('Rennes centre', { exact: true })).toBeVisible()
    await expect(
      main.getByRole('button', { name: 'Ouvrir la photo 1 sur 2' }).first()
    ).toBeVisible()

    // A sector, never a pin: the captioned approximate map, and no marker anywhere on it.
    const sector = main.getByRole('img', {
      name: /^Localisation approximative, à environ 1 km près/,
    })
    await expect(sector).toBeVisible()
    await expect(sector.locator('canvas')).toBeVisible()
    await expect(page.locator('.maplibregl-marker')).toHaveCount(0)

    // What the API holds: the values typed in, both photos, and the blurred point only.
    const ad = await getAd(member, team.slug, slug)
    expect(ad).toMatchObject({
      name,
      adType: 'SALE',
      status: 'PUBLISHED',
      price: 350,
      locationDescription: 'Rennes centre',
    })
    expect(ad.images).toHaveLength(2)
    expect(ad.images[0]).toContain(first.id)
    expect(ad.images[1]).toContain(second.id)
    expect(ad.locationGeometry?.coordinates).toEqual(blurred(place.lon, place.lat))
    expect(ad.locationGeometry?.coordinates).not.toEqual([place.lon, place.lat])

    // And the team's list shows it, with its price and first photo.
    await page.goto(listPath(team.slug))
    await expect(page.getByRole('heading', { level: 2, name: 'Annonces' })).toBeVisible()
    const listed = card(page, name)
    await expect(listed).toBeVisible()
    await expect(listed).toContainText(euros(350))
    await expect(listed).toContainText('Publié')
    await expect(listed.getByRole('img', { name })).toHaveAttribute('src', new RegExp(first.id))
  })

  test('a rental priced per week, and a wanted ad left at « à négocier »', async ({
    page,
    context,
  }) => {
    const { team, member } = await scene()
    await signIn(context, member)
    const main = page.getByRole('main')

    const createAd = async (name: string, fill: () => Promise<void>) => {
      await page.goto(`${listPath(team.slug)}/nouvelle`)
      await expect(page.getByRole('heading', { level: 1, name: 'Nouvelle annonce' })).toBeVisible()
      const title = main.getByRole('textbox', { name: /^Titre/ })
      await hydrated(title)
      await title.fill(name)
      await fill()
      await main.getByRole('radio', { name: 'Publié' }).check()
      await main.getByRole('button', { name: "Créer l'annonce" }).click()
      await expect(page.getByRole('heading', { level: 2, name })).toBeVisible()
      return new URL(page.url()).pathname.split('/').at(-1)!
    }

    const rentalName = unique('Home-trainer à louer')
    const rentalSlug = await createAd(rentalName, async () => {
      await main.getByRole('radio', { name: 'Location' }).check()
      // A rental needs its period: the form refuses to submit without one.
      await expect(main.getByText('La période de location est requise')).toBeVisible()
      await expect(main.getByRole('button', { name: "Créer l'annonce" })).toBeDisabled()
      await main.getByRole('textbox', { name: 'Prix' }).fill('45')
      await main.getByRole('combobox', { name: /^Période de location/ }).click()
      await page.getByRole('option', { name: 'Semaine' }).click()
    })
    await expect(main.getByText(`${euros(45)} / semaine`, { exact: true })).toBeVisible()
    await expect(main.getByText('Location', { exact: true })).toBeVisible()
    expect(await getAd(member, team.slug, rentalSlug)).toMatchObject({
      adType: 'RENTAL',
      price: 45,
      rentalPeriod: 'WEEK',
    })

    const wantedName = unique('Cherche roue avant')
    const wantedSlug = await createAd(wantedName, async () => {
      await main.getByRole('radio', { name: 'Recherche' }).check()
      await expect(main.getByText('Laissez vide si le prix est à négocier')).toBeVisible()
    })
    await expect(main.getByText('Prix à négocier', { exact: true })).toBeVisible()
    const wanted = await getAd(member, team.slug, wantedSlug)
    expect(wanted.adType).toBe('WANTED')
    expect(wanted.price ?? null).toBeNull()
    // No place typed in: no location section, and no map.
    await expect(main.getByRole('heading', { name: 'Annonceur' })).toBeVisible()
    await expect(main.getByRole('heading', { name: 'Localisation' })).toHaveCount(0)

    await page.goto(listPath(team.slug))
    await expect(card(page, rentalName)).toContainText(`${euros(45)} / semaine`)
    await expect(card(page, wantedName)).toContainText('Prix à négocier')
  })

  test('the edit form changes the price and swaps a photo', async ({ page, context }) => {
    const { team, member } = await scene()
    const images: AssetDto[] = [
      await uploadImage(member, team.slug, 'avant.png', solidPng(320, 240, [220, 40, 40])),
      await uploadImage(member, team.slug, 'arriere.png', solidPng(320, 240, [40, 160, 60])),
    ]
    const ad = await newAd(member, team.slug, {
      name: unique('Vélo de route'),
      body: 'Cadre carbone.',
      price: 900,
      images,
    })

    await signIn(context, member)
    await page.goto(adPath(team.slug, ad.slug))
    const main = page.getByRole('main')
    await expect(page.getByRole('heading', { level: 2, name: ad.name })).toBeVisible()
    const edit = main.getByRole('link', { name: 'Modifier' })
    await hydrated(edit)
    await edit.click()

    await expect(page.getByRole('heading', { level: 1, name: "Modifier l'annonce" })).toBeVisible()
    const price = main.getByRole('textbox', { name: 'Prix' })
    await hydrated(price)
    await expect(price).toHaveValue('900')
    await price.fill('750')

    // Drop the first photo: select its node in the editor, delete it.
    const editor = richText(main)
    const photoIn = (asset: AssetDto) => editor.locator(`img[src*="${asset.id}"]`)
    await expect(photoIn(images[0])).toBeVisible()
    await expect(photoIn(images[1])).toBeVisible()
    await editor
      .locator('.asset-node-wrapper')
      .filter({ has: page.locator(`img[src*="${images[0].id}"]`) })
      .click()
    await page.keyboard.press('Delete')
    await expect(photoIn(images[0])).toHaveCount(0)
    await expect(photoIn(images[1])).toBeVisible()
    const replacement = await addPhoto(page, 'nouvelle.png', [40, 60, 200])

    await main.getByRole('button', { name: 'Enregistrer' }).click()
    await expect(page).toHaveURL(new RegExp(`${escapeRegExp(adPath(team.slug, ad.slug))}$`))
    await expect(main.getByText(euros(750), { exact: true })).toBeVisible()
    await expect(
      main.getByRole('button', { name: 'Ouvrir la photo 1 sur 2' }).first()
    ).toBeVisible()

    const saved = await getAd(member, team.slug, ad.slug)
    expect(saved.price).toBe(750)
    expect(saved.images).toHaveLength(2)
    expect(saved.images.some((url) => url.includes(images[0].id))).toBe(false)
    expect(saved.images[0]).toContain(images[1].id)
    expect(saved.images[1]).toContain(replacement.id)
  })

  test('unpublishing turns the ad back into a draft the rest of the team no longer sees', async ({
    page,
    context,
  }) => {
    const { team, member } = await scene()
    const other = await anotherMember(team)
    const ad = await newAd(member, team.slug, { name: unique('Casque'), price: 40 })
    expect(await listedNames(other, team.slug)).toContain(ad.name)

    await signIn(context, member)
    await page.goto(adPath(team.slug, ad.slug))
    const main = page.getByRole('main')
    await expect(page.getByRole('heading', { level: 2, name: ad.name })).toBeVisible()
    await expect(main.getByText('Publié', { exact: true })).toBeVisible()

    // The menu next to « Modifier » (support/ui.ts actionsMenu).
    await (await openActionsMenu(page)).getByRole('menuitem', { name: 'Dépublier' }).click()
    const dialog = page.getByRole('dialog', { name: 'Dépublier' })
    await expect(dialog).toContainText('Elle redeviendra un brouillon.')
    await dialog.getByRole('button', { name: 'Dépublier' }).click()
    await expect(dialog).toBeHidden()
    await expect(main.getByText('Brouillon', { exact: true })).toBeVisible()

    expect((await getAd(member, team.slug, ad.slug)).status).toBe('DRAFT')
    expect(await listedNames(other, team.slug)).not.toContain(ad.name)

    // And « Publier » brings it back.
    await (await openActionsMenu(page)).getByRole('menuitem', { name: 'Publier' }).click()
    await expect(main.getByText('Publié', { exact: true })).toBeVisible()
    expect(await listedNames(other, team.slug)).toContain(ad.name)
  })

  test('deleting the ad takes it out of the list', async ({ page, context }) => {
    const { team, member } = await scene()
    const other = await anotherMember(team)
    const ad = await newAd(member, team.slug, { name: unique('Pédalier'), price: 60 })

    await signIn(context, member)
    await page.goto(adPath(team.slug, ad.slug))
    const main = page.getByRole('main')
    await expect(page.getByRole('heading', { level: 2, name: ad.name })).toBeVisible()
    await (await openActionsMenu(page)).getByRole('menuitem', { name: 'Supprimer' }).click()
    const dialog = page.getByRole('dialog', { name: 'Supprimer' })
    await expect(dialog).toContainText('Voulez-vous vraiment supprimer cette annonce ?')
    await dialog.getByRole('button', { name: 'Supprimer' }).click()

    await expect(page).toHaveURL(new RegExp(`${escapeRegExp(listPath(team.slug))}$`))
    await expect(page.getByRole('heading', { level: 2, name: 'Annonces' })).toBeVisible()
    await expect(main.getByText("Aucune annonce n'est disponible pour le moment.")).toBeVisible()
    await expect(card(page, ad.name)).toHaveCount(0)

    expect(await listedNames(member, team.slug)).not.toContain(ad.name)
    expect(await listedNames(other, team.slug)).not.toContain(ad.name)
  })
})

/**
 * Who may manage an ad. The backend lets its author and the team's admins update, delete or read
 * the edit shape of an ad (AdAccessChecker.hasRights, UPDATE / DELETE), and nobody else — an
 * ORGANIZER is no admin there. The web detail page and edit page, though, offer « Modifier » and the
 * « Options de gestion » menu to every member: whatever another member does with them ends in a 403.
 */
test.describe('ad rights', () => {
  interface RightsScene {
    team: TeamDetailDto
    author: AuthResponse
    ad: AdDto
  }

  /** A team owned by someone else, a MEMBER who wrote a published ad in it. */
  async function rightsScene(): Promise<RightsScene> {
    const { team, member: author } = await scene()
    const ad = await newAd(author, team.slug, { name: unique('Roues carbone'), price: 480 })
    return { team, author, ad }
  }

  /** Someone else in the team, with `role`. */
  async function teammate(team: TeamDetailDto, role: TeamRole): Promise<AuthResponse> {
    const [admin, user] = await Promise.all([roleSession('admin'), newUser(`Coéquipier ${role}`)])
    await addMember(admin, team.slug, user, role)
    return user
  }

  /** The status of what `call` threw, or 'ok' when it went through. */
  async function statusOf(call: Promise<unknown>): Promise<number | 'ok'> {
    try {
      await call
      return 'ok'
    } catch (error) {
      if (error instanceof ApiError) return error.status
      throw error
    }
  }

  const adRequest = (ad: AdDto, changes: Partial<AdRequest>): AdRequest => ({
    name: ad.name,
    status: ad.status,
    adType: ad.adType,
    price: ad.price,
    media: markdownMedia(),
    ...changes,
  })

  // The premise of the UI tests below: what the backend refuses a teammate who is not the author.
  for (const role of ['MEMBER', 'ORGANIZER'] as const) {
    test(`the API refuses to a non-author ${role} the edit shape, an update and a delete`, async () => {
      const { team, ad } = await rightsScene()
      const other = await teammate(team, role)
      const base = `/api/teams/${team.slug}/classifieds/${ad.slug}`

      // Reading the ad is fine: any member may.
      expect((await getAd(other, team.slug, ad.slug)).name).toBe(ad.name)
      expect(await statusOf(apiGet(other, `${base}/edit`))).toBe(403)
      expect(await statusOf(apiPut(other, base, adRequest(ad, { price: 1 })))).toBe(403)
      expect(await statusOf(apiDelete(other, base))).toBe(403)
      const unchanged = await getAd(other, team.slug, ad.slug)
      expect(unchanged.price).toBe(480)
      expect(unchanged.deleted).toBe(false)
    })
  }

  for (const role of ['MEMBER', 'ORGANIZER'] as const) {
    test(`a non-author ${role} sees « Contacter » but neither « Modifier » nor the management menu`, async ({
      page,
      context,
    }) => {
      const { team, ad } = await rightsScene()
      const other = await teammate(team, role)

      await signIn(context, other)
      await page.goto(adPath(team.slug, ad.slug))
      const main = mainOf(page)
      await expect(page.getByRole('heading', { level: 2, name: ad.name })).toBeVisible()
      // The contact button is the hydrated page's own: once it shows, so would the others.
      const contact = main.getByRole('button', { name: 'Contacter le vendeur' })
      await hydrated(contact)
      await expect(main.getByRole('link', { name: 'Modifier' })).toHaveCount(0)
      await expect(actionsMenu(page)).toHaveCount(0)
    })
  }

  test('the edit URL sends a non-author member away from the form', async ({ page, context }) => {
    const { team, ad } = await rightsScene()
    const other = await teammate(team, 'MEMBER')

    await signIn(context, other)
    await page.goto(`${adPath(team.slug, ad.slug)}/modifier`)
    // Today the member lands on the team's list, not on the ad: the edit shape answers 403, so
    // EditAdPage takes its « no ad » branch (src/pages/ad/EditAdPage.tsx:39-41) before its own
    // `canEdit` check, whose redirect to the detail page (:49-51) only a member who can already
    // read the edit shape — hence can edit — ever reaches. Either destination keeps the form away.
    const away = new RegExp(
      `(${escapeRegExp(listPath(team.slug))}|${escapeRegExp(adPath(team.slug, ad.slug))})$`
    )
    await expect(page).toHaveURL(away)
    await expect(
      page.getByRole('heading', { level: 2, name: /^(Annonces|Roues carbone .*)$/ }).first()
    ).toBeVisible()
    await expect(page.getByRole('heading', { level: 1, name: "Modifier l'annonce" })).toHaveCount(0)
    await expect(mainOf(page).getByRole('textbox', { name: /^Titre/ })).toHaveCount(0)
    await expect(mainOf(page).getByRole('button', { name: 'Enregistrer' })).toHaveCount(0)
  })

  test('a team admin who is not the author edits the price', async ({ page, context }) => {
    const { team, ad } = await rightsScene()
    const admin = await teammate(team, 'ADMIN')

    await signIn(context, admin)
    await page.goto(adPath(team.slug, ad.slug))
    const main = mainOf(page)
    await expect(page.getByRole('heading', { level: 2, name: ad.name })).toBeVisible()
    await expect(actionsMenu(page)).toBeVisible()
    const edit = main.getByRole('link', { name: 'Modifier' })
    await hydrated(edit)
    await edit.click()

    await expect(page.getByRole('heading', { level: 1, name: "Modifier l'annonce" })).toBeVisible()
    const price = main.getByRole('textbox', { name: 'Prix' })
    await hydrated(price)
    await expect(price).toHaveValue('480')
    await price.fill('420')
    await main.getByRole('button', { name: 'Enregistrer' }).click()

    await expect(page).toHaveURL(new RegExp(`${escapeRegExp(adPath(team.slug, ad.slug))}$`))
    await expect(main.getByText(euros(420), { exact: true })).toBeVisible()
    const saved = await getAd(admin, team.slug, ad.slug)
    expect(saved.price).toBe(420)
    expect(saved.name).toBe(ad.name)
  })
})

/** The status of what `call` threw, or 'ok' when it went through. */
async function statusOf(call: Promise<unknown>): Promise<number | 'ok'> {
  try {
    await call
    return 'ok'
  } catch (error) {
    if (error instanceof ApiError) return error.status
    throw error
  }
}

/** The captioned sector map of an ad's place (AdLocationMap) — never a pin. */
const sector = (page: Page) =>
  mainOf(page).getByRole('img', { name: /^Localisation approximative, à environ 1 km près/ })

/**
 * The place of an ad through an edit. The author's edit form reads the exact point (the edit shape,
 * GET …/edit) and sends it back with the rest; the server blurs it again for everyone else. A form
 * that dropped it, or sent the blurred point back as the exact one, would move or erase the place
 * of an ad whose title only was retouched.
 */
test.describe('ad place', () => {
  /** A published ad by the scene's member, placed in Rennes (as the lookup would have put it). */
  async function placedAd() {
    const { team, member } = await scene()
    const ad = await newAd(member, team.slug, {
      name: unique('Home trainer'),
      body: 'Peu servi.',
      price: 120,
      locationDescription: 'Rennes centre',
      locationGeometry: { type: 'Point', coordinates: [RENNES.lon, RENNES.lat] },
    })
    const editShape = () =>
      apiGet<AdEditDto>(member, `/api/teams/${team.slug}/classifieds/${ad.slug}/edit`)
    return { team, member, ad, editShape }
  }

  /** Opens the ad's edit form from its page. */
  async function openEditForm(page: Page, teamSlug: string, ad: AdDto) {
    await page.goto(adPath(teamSlug, ad.slug))
    await expect(page.getByRole('heading', { level: 2, name: ad.name })).toBeVisible()
    const edit = mainOf(page).getByRole('link', { name: 'Modifier' })
    await hydrated(edit)
    await edit.click()
    await expect(page.getByRole('heading', { level: 1, name: "Modifier l'annonce" })).toBeVisible()
    const title = mainOf(page).getByRole('textbox', { name: /^Titre/ })
    await hydrated(title)
    await expect(title).toHaveValue(ad.name)
    return title
  }

  test('editing only the title keeps the place: the same blurred sector, the same point underneath', async ({
    page,
    context,
  }) => {
    const { team, member, ad, editShape } = await placedAd()
    // Preconditions: the blurred point for readers, the exact one in the edit shape.
    expect(ad.locationGeometry?.coordinates).toEqual(blurred(RENNES.lon, RENNES.lat))
    const exactBefore = (await editShape()).locationGeometry?.coordinates
    expect(exactBefore).toEqual([RENNES.lon, RENNES.lat])

    await signIn(context, member)
    const title = await openEditForm(page, team.slug, ad)
    const main = mainOf(page)
    // The form holds the place: its written part, and a point (the clear button says so).
    await expect(main.getByRole('textbox', { name: 'Description du lieu' })).toHaveValue(
      'Rennes centre'
    )
    await expect(main.getByRole('button', { name: 'Supprimer la localisation' })).toBeVisible()
    const renamed = `${ad.name} (révisé)`
    await title.fill(renamed)
    await main.getByRole('button', { name: 'Enregistrer' }).click()

    await expect(page).toHaveURL(new RegExp(`${escapeRegExp(adPath(team.slug, ad.slug))}$`))
    await expect(page.getByRole('heading', { level: 2, name: renamed })).toBeVisible()
    await expect(main.getByText('Rennes centre', { exact: true })).toBeVisible()
    await expect(sector(page)).toBeVisible()
    await expect(sector(page).locator('canvas')).toBeVisible()
    await expect(page.locator('.maplibregl-marker')).toHaveCount(0)

    const saved = await getAd(member, team.slug, ad.slug)
    expect(saved.name).toBe(renamed)
    expect(saved.locationDescription).toBe('Rennes centre')
    expect(saved.locationGeometry?.coordinates, 'the blurred point').toEqual(
      ad.locationGeometry?.coordinates
    )
    expect((await editShape()).locationGeometry?.coordinates, 'the exact point').toEqual(
      exactBefore
    )
  })

  test('clearing the place takes the map off the ad, the written place stays', async ({
    page,
    context,
  }) => {
    const { team, member, ad, editShape } = await placedAd()

    await signIn(context, member)
    // Precondition: the ad shows its sector.
    await page.goto(adPath(team.slug, ad.slug))
    await expect(sector(page)).toBeVisible()

    await openEditForm(page, team.slug, ad)
    const main = mainOf(page)
    const clear = main.getByRole('button', { name: 'Supprimer la localisation' })
    await hydrated(clear)
    await clear.click()
    await expect(clear).toHaveCount(0)
    await expect(main.getByRole('textbox', { name: 'Localisation', exact: true })).toHaveValue('')
    await main.getByRole('button', { name: 'Enregistrer' }).click()

    await expect(page).toHaveURL(new RegExp(`${escapeRegExp(adPath(team.slug, ad.slug))}$`))
    await expect(page.getByRole('heading', { level: 2, name: ad.name })).toBeVisible()
    // The written place stands on its own, with its heading — no map centred on nothing.
    await expect(main.getByRole('heading', { level: 4, name: 'Localisation' })).toBeVisible()
    await expect(main.getByText('Rennes centre', { exact: true })).toBeVisible()
    await expect(sector(page)).toHaveCount(0)
    await expect(main.locator('canvas')).toHaveCount(0)

    const saved = await getAd(member, team.slug, ad.slug)
    expect(saved.locationGeometry, 'the blurred point').toBeUndefined()
    expect(saved.locationDescription).toBe('Rennes centre')
    expect((await editShape()).locationGeometry, 'the exact point').toBeUndefined()
  })
})

test.describe('restoring', () => {
  test('a team admin who is not the author deletes an ad, then restores it whole', async ({
    page,
    context,
  }) => {
    const { team, member: author } = await scene()
    const [admin, other] = await Promise.all([newUser('Bureau annonces'), anotherMember(team)])
    await addMember(await roleSession('admin'), team.slug, admin, 'ADMIN')
    const photo = await uploadImage(
      author,
      team.slug,
      'selle.png',
      solidPng(320, 240, [200, 60, 40])
    )
    const ad = await newAd(author, team.slug, {
      name: unique('Selle cuir'),
      body: 'Selle **en cuir**, bien faite à la forme.',
      price: 80,
      images: [photo],
      locationDescription: 'Rennes centre',
      locationGeometry: { type: 'Point', coordinates: [RENNES.lon, RENNES.lat] },
    })

    await signIn(context, admin)
    await page.goto(adPath(team.slug, ad.slug))
    const main = mainOf(page)
    await expect(page.getByRole('heading', { level: 2, name: ad.name })).toBeVisible()
    await (await openActionsMenu(page)).getByRole('menuitem', { name: 'Supprimer' }).click()
    const dialog = page.getByRole('dialog', { name: 'Supprimer' })
    await dialog.getByRole('button', { name: 'Supprimer' }).click()
    await expect(toasts(page).filter({ hasText: 'Annonce supprimée avec succès' })).toBeVisible()
    await expect(page).toHaveURL(new RegExp(`${escapeRegExp(listPath(team.slug))}$`))

    // Gone for the author as for the rest of the team; the team's admins still reach it.
    const adApi = `/api/teams/${team.slug}/classifieds/${ad.slug}`
    expect(await apiGetOrNull(author, adApi), 'the author gets a 404').toBeNull()
    expect(await listedNames(other, team.slug)).not.toContain(ad.name)
    expect((await getAd(admin, team.slug, ad.slug)).deleted).toBe(true)

    await page.goto(adPath(team.slug, ad.slug))
    await expect(page.getByRole('heading', { level: 2, name: ad.name })).toBeVisible()
    await (await openActionsMenu(page)).getByRole('menuitem', { name: 'Restaurer' }).click()
    await expect(toasts(page).filter({ hasText: 'Annonce restaurée avec succès' })).toBeVisible()
    const again = await openActionsMenu(page)
    await expect(again.getByRole('menuitem', { name: 'Supprimer' })).toBeVisible()
    await expect(again.getByRole('menuitem', { name: 'Restaurer' })).toHaveCount(0)
    await page.keyboard.press('Escape')
    await expect(main.getByText('Rennes centre', { exact: true })).toBeVisible()
    await expect(sector(page)).toBeVisible()

    // Back for everyone, as it was written.
    const restored = await getAd(author, team.slug, ad.slug)
    expect(restored).toMatchObject({
      deleted: false,
      status: 'PUBLISHED',
      name: ad.name,
      price: 80,
      locationDescription: 'Rennes centre',
    })
    expect(restored.media.markdown).toContain('Selle **en cuir**, bien faite à la forme.')
    expect(restored.images).toHaveLength(1)
    expect(restored.images[0]).toContain(photo.id)
    expect(restored.locationGeometry?.coordinates).toEqual(blurred(RENNES.lon, RENNES.lat))
    expect(await listedNames(other, team.slug)).toContain(ad.name)
  })
})

/**
 * A team whose ads module is turned off (`enableAds=false`, the team settings' switch) after ads
 * were posted: the API refuses them to everyone (AdAccessChecker), and the team's navigation drops
 * the tab (useNavItems). What is left to check is the ad URLs someone kept.
 */
test.describe('ads module off', () => {
  async function switchedOff() {
    const { team, member } = await scene()
    const ad = await newAd(member, team.slug, {
      name: unique('Porte-vélos'),
      body: 'Pour deux vélos.',
      price: 150,
    })
    // The settings' switch, flipped by the platform admin (the owner may too).
    await apiPut(
      await roleSession('admin'),
      `/api/teams/${team.slug}`,
      teamRequest(team.name, { enableAds: false })
    )
    const urls = {
      list: listPath(team.slug),
      detail: adPath(team.slug, ad.slug),
      create: `${listPath(team.slug)}/nouvelle`,
      edit: `${adPath(team.slug, ad.slug)}/modifier`,
    }
    return { team, member, ad, urls }
  }

  test('the API refuses the ads, and none of their URLs shows one', async ({ page, context }) => {
    const { team, member, ad, urls } = await switchedOff()
    const base = `/api/teams/${team.slug}/classifieds`
    // The author themself: no list, no ad, no edit shape, no new ad.
    expect(await statusOf(apiGet(member, base))).toBe(403)
    expect(await statusOf(apiGet(member, `${base}/${ad.slug}`))).toBe(403)
    expect(await statusOf(apiGet(member, `${base}/${ad.slug}/edit`))).toBe(403)
    expect(
      await statusOf(
        apiPost(member, base, {
          name: unique('Annonce refusée'),
          status: 'PUBLISHED',
          adType: 'SALE',
          media: markdownMedia(),
        } satisfies AdRequest)
      )
    ).toBe(403)

    await signIn(context, member)
    const bodies: Promise<string>[] = []
    page.on('response', (response) => {
      if (new URL(response.url()).pathname.startsWith('/api/'))
        bodies.push(response.text().catch(() => ''))
    })
    for (const [label, url] of Object.entries(urls)) {
      await page.goto(url)
      await pageHydrated(page)
      await expect(page.getByRole('heading', { level: 1, name: "Modifier l'annonce" })).toHaveCount(
        0
      )
      const text = await page.locator('body').innerText()
      expect.soft(text.includes(ad.name), `${label}: the ad on screen`).toBe(false)
      expect.soft(text.includes('Pour deux vélos.'), `${label}: its text on screen`).toBe(false)
    }
    for (const body of await Promise.all(bodies))
      expect.soft(body.includes(ad.name), 'an API response carries the ad').toBe(false)
  })

  for (const which of ['list', 'detail', 'create', 'edit'] as const) {
    test(`the ${which} URL leads a member back to the team, as a disabled trip's does`, async ({
      page,
      context,
    }) => {
      // Regression (caad90d2): the four ad pages lead back to the team when the module is off, as
      // TripDetailPage does — before, they ignored `enableAds`.
      const { team, member, urls } = await switchedOff()
      await signIn(context, member)
      await page.goto(urls[which])
      await expect(page).toHaveURL(new RegExp(`/equipes/${team.slug}$`), { timeout: 10_000 })
      await expect(
        page.getByRole('main').getByRole('link', { name: 'Créer une annonce' })
      ).toHaveCount(0)
    })
  }
})
