import type { TagWithUsageDto } from '../src/api/dto'
import { getAd, newAd } from './support/ads'
import { apiGet } from './support/api'
import { addMember, newTeam, newUser, signIn } from './support/data'
import { expect, test, unique } from './support/fixtures'
import { entityCard, escapeRegExp, hydrated, pageAs } from './support/ui'

/**
 * Team tags (ledger `WEB-40`, plan docs/plans/archive/2026-10-01-tags.md): the team's admin creates a tag
 * from the admin screen — the only place a tag is created (D4) —, a member who is not an admin puts
 * it on their own ad from its edit form — the content's edit rights are enough (D5) —, and the ad
 * list filtered by `?tags=<id>` (D18) finds that ad and leaves the other one out.
 *
 * Ads, because any member may write one: the journey then needs no organizer.
 */

const listPath = (teamSlug: string) => `/equipes/${teamSlug}/annonces`
const adPath = (teamSlug: string, slug: string) => `/equipes/${teamSlug}/annonces/${slug}`

test('an admin creates a tag, a member puts it on an ad, the list filtered by URL finds it', async ({
  page,
  context,
  browser,
}) => {
  const [owner, member] = await Promise.all([
    newUser(unique('Bureau tags')),
    newUser(unique('Membre tags')),
  ])
  const team = await newTeam(owner, unique('Tags'))
  await addMember(team.slug, member)
  const label = unique('Pièces')
  const [tagged, untagged] = await Promise.all([
    newAd(member, team.slug, { name: unique('Roue arrière') }),
    newAd(member, team.slug, { name: unique('Selle') }),
  ])
  const main = page.getByRole('main')
  let tagId = ''

  await test.step('the team admin creates the tag on the admin screen', async () => {
    await signIn(context, owner)
    await page.goto(`/equipes/${team.slug}/admin/tags?type=ad`)
    await expect(main.getByRole('tab', { name: /^Annonces/, selected: true })).toBeVisible()
    const add = main.getByRole('button', { name: 'Créer un tag' }).first()
    await hydrated(add)
    await add.click()

    const dialog = page.getByRole('dialog', { name: 'Créer un tag' })
    await dialog.getByRole('textbox', { name: 'Libellé' }).fill(label)
    await dialog.getByRole('radio', { name: 'Vert' }).click()
    await dialog.getByRole('button', { name: 'Créer' }).click()
    await expect(dialog).toHaveCount(0)

    await expect(main.getByText(label, { exact: true })).toBeVisible()
    await expect(main.getByText('Inutilisé')).toBeVisible()
    const tags = await apiGet<TagWithUsageDto[]>(owner, `/api/teams/${team.slug}/tags`, {
      type: 'AD',
    })
    const created = tags.find((tag) => tag.label === label)
    expect(created, 'the tag is stored').toBeTruthy()
    expect(created!.color).toBe('GREEN')
    tagId = created!.id
  })

  // The member works in a browser of their own.
  const reader = await pageAs(browser, member)
  const memberMain = reader.page.getByRole('main')

  await test.step('a member who is not an admin puts the tag on their ad', async () => {
    await reader.page.goto(`${adPath(team.slug, tagged.slug)}/modifier`)
    await expect(
      reader.page.getByRole('heading', { level: 1, name: "Modifier l'annonce" })
    ).toBeVisible()
    const picker = memberMain.getByRole('combobox', { name: 'Tags' })
    await hydrated(picker)
    await picker.click()
    await reader.page.getByRole('option', { name: label }).click()
    await reader.page.keyboard.press('Escape')
    await memberMain.getByRole('button', { name: 'Enregistrer' }).click()

    await expect(reader.page).toHaveURL(
      new RegExp(`${escapeRegExp(adPath(team.slug, tagged.slug))}$`)
    )
    await expect(memberMain.getByRole('group', { name: 'Tags' }).getByText(label)).toBeVisible()
    const saved = await getAd(member, team.slug, tagged.slug)
    expect(saved.tags.map((tag) => tag.id)).toEqual([tagId])
  })

  await test.step('the ad list filtered by the tag id in the URL finds that ad only', async () => {
    // Both ads first, so the absence below means the filter, not an empty list.
    await reader.page.goto(listPath(team.slug))
    await expect(entityCard(memberMain, tagged.name)).toBeVisible()
    await expect(entityCard(memberMain, untagged.name)).toBeVisible()

    await reader.page.goto(`${listPath(team.slug)}?tags=${tagId}`)
    await expect(entityCard(memberMain, tagged.name)).toBeVisible()
    await expect(entityCard(memberMain, untagged.name)).toHaveCount(0)
    // The card shows the tag too.
    await expect(
      entityCard(memberMain, tagged.name).getByText(label, { exact: true })
    ).toBeVisible()
  })

  await test.step('the admin screen now counts one use', async () => {
    await page.reload()
    await expect(main.getByText('1 contenu', { exact: true })).toBeVisible()
  })

  await reader.context.close()
})
