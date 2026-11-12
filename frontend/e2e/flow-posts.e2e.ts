import type { Locator, Page } from '@playwright/test'
import type { CommentListResponse, MediaDto, PostRequest } from '../src/api/dto'
import { solidPng, uploadImage } from './support/ads'
import { ApiError, apiDelete, apiGet, apiPut } from './support/api'
import { addMember, markdownMedia, newTeam, newUser, signIn } from './support/data'
import { wallTimeOf, frenchDateTime, parisDaysAhead, parisInstant } from './support/dates'
import {
  addImage,
  caretToBlockEnd,
  KEY,
  richText,
  toolbarButton,
  typeRichText,
} from './support/editor'
import { expect, test, unique } from './support/fixtures'
import {
  about,
  expectNoNotification,
  listNotifications,
  waitForNotification,
} from './support/notifications'
import {
  commentOnPost,
  fetchPost,
  findPost,
  newPost,
  postPath,
  readPostComments,
} from './support/posts'
import {
  pastPublishInstant,
  pickIntoEmptyPicker,
  waitForAutoPublish,
} from './support/scheduled-publication'
import { entityCard, hydrated, openActionsMenu, pageAs, toasts } from './support/ui'

/**
 * Publications (posts), the nominal journey through the UI only: a team admin writes a post in the
 * rich-text editor (heading, bold, link, list, uploaded image), publishes it; it shows in the team
 * feed and on a member's home feed; the member opens it and comments; the author edits the post,
 * deletes the comment, then deletes the post.
 *
 * The rendered page is checked element by element (a heading is a heading, the link a link with its
 * href, the image an <img> that actually loaded), and the stored markdown through the API.
 */

const LINK_URL = 'https://example.com/parcours-e2e'
const IMAGE_NAME = 'photo-e2e-sortie.png'
const IMAGE_ALT = 'photo-e2e-sortie'

/** Each locator's (single) element comes after the previous one's in the document. */
async function expectInDocumentOrder(locators: Locator[]) {
  const handles = await Promise.all(locators.map((l) => l.elementHandle()))
  for (let i = 1; i < handles.length; i++) {
    const follows = await handles[i - 1]!.evaluate(
      (previous, next) =>
        !!(previous.compareDocumentPosition(next as Node) & Node.DOCUMENT_POSITION_FOLLOWING),
      handles[i]!
    )
    expect(follows, `block ${i} comes after block ${i - 1}`).toBe(true)
  }
}

/** An <img> the browser really decoded — not a broken-image placeholder. */
async function expectImageLoaded(image: Locator) {
  await expect(image).toBeVisible()
  await expect
    .poll(() =>
      image.evaluate(
        (el) => (el as HTMLImageElement).complete && (el as HTMLImageElement).naturalWidth
      )
    )
    .toBeGreaterThan(0)
}

test('a post goes from the editor to the feeds, gets a comment, is edited, then deleted', async ({
  page,
  context,
  browser,
}) => {
  // The author owns the team, so is its ADMIN: a deleted post stays listed to them, flagged.
  const author = await newUser(unique('Autrice'))
  const member = await newUser(unique('Lectrice'))
  // Rides off: the feed's create button then opens the post editor directly.
  const team = await newTeam(author, unique('Publications'), {
    addMemberAllowed: true,
    enableRides: false,
  })
  await addMember(author, team.slug, member)

  const title = unique('Sortie du dimanche')
  const main = page.getByRole('main')
  let postSlug = ''
  await signIn(context, author)
  // The member reads in a browser of their own.
  const reader = await pageAs(browser, member)
  const memberMain = reader.page.getByRole('main')
  const feedCard = (name: string, scope: Locator = main) => entityCard(scope, name)

  await test.step('the author writes the post in the rich-text editor and publishes it', async () => {
    await page.goto(`/equipes/${team.slug}/articles`)
    await expect(
      main.getByRole('heading', { level: 2, name: 'Publications', exact: true })
    ).toBeVisible()
    const create = main.getByRole('link', { name: 'Nouvelle publication' })
    await hydrated(create)
    await create.click()
    await expect(
      main.getByRole('heading', { level: 1, name: 'Nouvelle publication' })
    ).toBeVisible()

    const titleInput = main.getByRole('textbox', { name: 'Titre' })
    await hydrated(titleInput)
    await titleInput.fill(title)

    const editor = richText(main)
    await editor.click()
    // Heading
    await toolbarButton(main, 'Heading 2').click()
    await page.keyboard.type('Au programme')
    await page.keyboard.press('Enter')
    // Bold, in the middle of a paragraph
    await page.keyboard.type('Rendez-vous ')
    await toolbarButton(main, 'Bold').click()
    await page.keyboard.type('à 8 h précises')
    await toolbarButton(main, 'Bold').click()
    await page.keyboard.type(' devant le club.')
    await page.keyboard.press('Enter')
    // Link: type the words, select them, then the link control
    const linkText = 'Voir le parcours'
    await page.keyboard.type(linkText)
    // Not Shift+Home: on macOS, Chromium maps it to « select to the start of the document ».
    for (let i = 0; i < linkText.length; i++) await page.keyboard.press('Shift+ArrowLeft')
    await toolbarButton(main, 'Link').click()
    const urlInput = page.getByRole('textbox', { name: 'Enter URL' })
    await urlInput.fill(LINK_URL)
    await page.getByRole('button', { name: 'Save', exact: true }).click()
    // Saving hands the focus back to the editor, the linked words still selected.
    await expect(urlInput).toBeHidden()
    await expect(editor).toBeFocused()
    await expect(editor.getByRole('link', { name: linkText, exact: true })).toBeVisible()
    // The linked words are still selected: Enter now would replace them.
    const selection = () => page.evaluate(() => window.getSelection()?.toString() ?? '')
    await expect.poll(selection).toBe(linkText)
    await caretToBlockEnd(page, editor, KEY.lineEnd)
    await page.keyboard.press('Enter')
    // Bullet list
    await toolbarButton(main, 'Bullet list').click()
    await page.keyboard.type('Casque')
    await page.keyboard.press('Enter')
    await page.keyboard.type('Gilet jaune')
    await page.keyboard.press('Enter')
    await page.keyboard.press('Enter')

    // Image, through the editor's own upload control; the editor shows it in place.
    await addImage(page, main, IMAGE_NAME, [30, 120, 200], [96, 64])
    await expectImageLoaded(editor.getByRole('img', { name: IMAGE_ALT }))

    // Formatting is visible in the editor itself.
    await expect(editor.locator('h2')).toHaveText('Au programme')
    await expect(editor.locator('strong')).toHaveText('à 8 h précises')
    await expect(editor.locator('a')).toHaveAttribute('href', LINK_URL)
    await expect(editor.locator('ul > li')).toHaveText(['Casque', 'Gilet jaune'])

    await main.getByRole('radio', { name: 'Publié' }).check()
    const submit = main.getByRole('button', { name: 'Créer la publication' })
    await expect(submit).toBeEnabled()
    await submit.click()

    await expect(page.getByText('Publication créée avec succès')).toBeVisible()
    // The form lives on /articles/nouveau, which the pattern must not take for the new post.
    await expect(page).toHaveURL(new RegExp(`/equipes/${team.slug}/articles/(?!nouveau$)[^/]+$`))
    postSlug = new URL(page.url()).pathname.split('/').pop()!
  })

  await test.step('the post page renders the formatting, the link and the image', async () => {
    await expect(main.getByRole('heading', { level: 2, name: title })).toBeVisible()
    await expect(main.getByText('Publié', { exact: true })).toBeVisible()
    await expect(main.getByRole('heading', { level: 2, name: 'Au programme' })).toBeVisible()
    await expect(main.locator('strong', { hasText: 'à 8 h précises' })).toBeVisible()
    // Markdown syntax must not leak into the page.
    await expect(main.getByText('**', { exact: false })).toHaveCount(0)
    await expect(main.getByText('## Au programme')).toHaveCount(0)
    const link = main.getByRole('link', { name: 'Voir le parcours' })
    await expect(link).toHaveAttribute('href', LINK_URL)
    await expect(link).toHaveAttribute('target', '_blank')
    await expect(main.getByRole('listitem')).toHaveText(['Casque', 'Gilet jaune'])
    await expectImageLoaded(main.getByRole('img', { name: IMAGE_ALT }))
    // In the order they were written.
    await expectInDocumentOrder([
      main.getByRole('heading', { level: 2, name: 'Au programme' }),
      main.locator('strong', { hasText: 'à 8 h précises' }),
      link,
      main.getByRole('list'),
      main.getByRole('img', { name: IMAGE_ALT }),
    ])

    // What was stored: the markdown the editor wrote, and the picture it references.
    const post = await fetchPost(author, team.slug, postSlug)
    expect(post.name).toBe(title)
    expect(post.status).toBe('PUBLISHED')
    expect(post.deleted).toBe(false)
    const { markdown, assets } = post.media
    expect(markdown).toMatch(/^## Au programme$/m)
    expect(markdown).toContain('Rendez-vous **à 8 h précises** devant le club.')
    expect(markdown).toContain(`[Voir le parcours](${LINK_URL})`)
    expect(markdown).toMatch(/^- Casque\n- Gilet jaune$/m)
    expect(assets.images).toHaveLength(1)
    expect(assets.images[0].fileName).toBe(IMAGE_NAME)
    expect(markdown).toContain(`::asset{id="${assets.images[0].id}"`)
  })

  await test.step('it shows in the team feed', async () => {
    await page.goto(`/equipes/${team.slug}/articles`)
    const card = feedCard(title)
    await expect(card).toBeVisible()
    await expect(card.getByText('Publication', { exact: true })).toBeVisible()
    // No counter at zero on a card (docs/LEDGER_*.md WEB-167, R4): « 0 commentaire » is gone.
    await expect(card.getByText('0 commentaire', { exact: true })).toHaveCount(0)
  })

  await test.step('a member finds it on the home feed, opens it and comments', async () => {
    const { page: memberPage } = reader
    await memberPage.goto('/')
    await expect(memberMain.getByRole('heading', { name: 'Dernières publications' })).toBeVisible()
    const card = feedCard(title, memberMain)
    await expect(card).toBeVisible()
    await hydrated(card)
    // By its title: on the mobile layout the card's centre can fall on its team row, a button of
    // its own that leads to the team.
    await card.getByText(title, { exact: true }).click()

    await expect(memberPage).toHaveURL(new RegExp(`/equipes/${team.slug}/articles/${postSlug}$`))
    await expect(memberMain.getByRole('heading', { level: 2, name: title })).toBeVisible()
    await expectImageLoaded(memberMain.getByRole('img', { name: IMAGE_ALT }))
    // A plain member has no edit controls.
    await expect(memberMain.getByRole('link', { name: 'Modifier' })).toHaveCount(0)

    await expect(memberMain.getByRole('heading', { name: 'Commentaires (0)' })).toBeVisible()
    const box = memberMain.getByRole('textbox', { name: 'Écrivez un commentaire...' })
    await hydrated(box)
    await box.fill('Je viens, avec le gilet !')
    await memberMain.getByRole('button', { name: 'Envoyer le commentaire' }).click()
    await expect(memberMain.getByRole('heading', { name: 'Commentaires (1)' })).toBeVisible()
    await expect(memberMain.getByText('Je viens, avec le gilet !', { exact: true })).toBeVisible()
    await expect(memberMain.getByText(member.user.displayName, { exact: true })).toBeVisible()
    await expect(box).toHaveValue('')

    const comments = await apiGet<CommentListResponse>(
      member,
      `/api/teams/${team.slug}/posts/${postSlug}/comments`
    )
    expect(comments.total).toBe(1)
    expect(comments.items[0].content).toBe('Je viens, avec le gilet !')
    expect(comments.items[0].author.id).toBe(member.user.id)

    // The count on the feed card follows.
    await memberPage.goto(`/equipes/${team.slug}/articles`)
    await expect(
      feedCard(title, memberMain).getByText('1 commentaire', { exact: true })
    ).toBeVisible()
  })

  const newTitle = `${title} (modifiée)`
  await test.step('the author edits the post', async () => {
    await page.goto(`/equipes/${team.slug}/articles/${postSlug}`)
    await expect(main.getByRole('heading', { level: 2, name: title })).toBeVisible()
    const edit = main.getByRole('link', { name: 'Modifier' })
    await hydrated(edit)
    await edit.click()
    await expect(
      main.getByRole('heading', { level: 1, name: 'Modifier la publication' })
    ).toBeVisible()

    const titleInput = main.getByRole('textbox', { name: 'Titre' })
    await expect(titleInput).toHaveValue(title)
    await hydrated(titleInput)
    await titleInput.fill(newTitle)
    // The saved body comes back into the editor, image included.
    const editor = richText(main)
    await expect(editor.locator('h2')).toHaveText('Au programme')
    await expectImageLoaded(editor.getByRole('img', { name: IMAGE_ALT }))
    // The heading is short enough not to wrap on a phone, so the line's end is the end of its text.
    await editor.locator('h2').click()
    await caretToBlockEnd(page, editor, KEY.lineEnd)
    await page.keyboard.type(' du dimanche')
    await expect(editor.locator('h2')).toHaveText('Au programme du dimanche')

    await main.getByRole('button', { name: 'Enregistrer' }).click()
    await expect(page.getByText('Publication mise à jour avec succès')).toBeVisible()
    await expect(page).toHaveURL(new RegExp(`/equipes/${team.slug}/articles/${postSlug}$`))
    await expect(main.getByRole('heading', { level: 2, name: newTitle })).toBeVisible()
    await expect(
      main.getByRole('heading', { level: 2, name: 'Au programme du dimanche', exact: true })
    ).toBeVisible()
    // Nothing else was lost on the way.
    await expect(main.locator('strong', { hasText: 'à 8 h précises' })).toBeVisible()
    await expect(main.getByRole('listitem')).toHaveText(['Casque', 'Gilet jaune'])
    await expect(main.getByRole('link', { name: 'Voir le parcours' })).toHaveAttribute(
      'href',
      LINK_URL
    )
    await expectImageLoaded(main.getByRole('img', { name: IMAGE_ALT }))

    const post = await fetchPost(author, team.slug, postSlug)
    expect(post.name).toBe(newTitle)
    expect(post.media.markdown).toMatch(/^## Au programme du dimanche$/m)
    expect(post.media.markdown).toContain('Rendez-vous **à 8 h précises** devant le club.')
    expect(post.media.markdown).toContain(`[Voir le parcours](${LINK_URL})`)
    expect(post.media.assets.images).toHaveLength(1)
    expect(post.status).toBe('PUBLISHED')
  })

  await test.step("the author deletes the member's comment", async () => {
    await expect(main.getByRole('heading', { name: 'Commentaires (1)' })).toBeVisible()
    const remove = main.getByRole('button', { name: 'Supprimer', exact: true })
    await hydrated(remove)
    await remove.click()
    const dialog = page.getByRole('dialog', { name: 'Supprimer le commentaire' })
    await dialog.getByRole('button', { name: 'Supprimer' }).click()
    await expect(dialog).toBeHidden()
    await expect(main.getByRole('heading', { name: 'Commentaires (0)' })).toBeVisible()
    await expect(main.getByText('Je viens, avec le gilet !')).toHaveCount(0)

    const comments = await apiGet<CommentListResponse>(
      author,
      `/api/teams/${team.slug}/posts/${postSlug}/comments`
    )
    expect(comments.total).toBe(0)
  })

  await test.step('the author deletes the post', async () => {
    const menu = await openActionsMenu(page)
    await menu.getByRole('menuitem', { name: 'Supprimer' }).click()
    const dialog = page.getByRole('dialog', { name: 'Supprimer' })
    await expect(
      dialog.getByText('Voulez-vous vraiment supprimer cette publication ?', { exact: false })
    ).toBeVisible()
    await dialog.getByRole('button', { name: 'Supprimer' }).click()

    await expect(page.getByText('Publication supprimée avec succès')).toBeVisible()
    await expect(page).toHaveURL(new RegExp(`/equipes/${team.slug}/articles$`))
    // A team admin still sees it in the feed, flagged — deletion is soft, and restorable.
    await expect(feedCard(newTitle).getByText('Supprimé', { exact: true })).toBeVisible()
    expect((await fetchPost(author, team.slug, postSlug)).deleted).toBe(true)
  })

  await test.step('for the member it is gone', async () => {
    const { page: memberPage } = reader
    await memberPage.goto('/')
    await expect(memberMain.getByRole('heading', { name: 'Dernières publications' })).toBeVisible()
    // The member's only team has nothing else: its feed is loaded, and empty.
    await expect(memberMain.getByText('Aucune publication pour le moment')).toBeVisible()
    await expect(feedCard(newTitle, memberMain)).toHaveCount(0)

    await memberPage.goto(`/equipes/${team.slug}/articles/${postSlug}`)
    // The page retries the 404 three times before saying so (defect pinned in flow-trips.e2e.ts).
    await expect(memberMain.getByRole('heading', { name: 'Publication introuvable' })).toBeVisible({
      timeout: 15_000,
    })
    expect(await findPost(member, team.slug, postSlug), 'the API answers 404').toBeNull()
  })
  await reader.context.close()
})

test('a post saved as a draft is hidden from members until it is published from its page', async ({
  page,
  browser,
}) => {
  const author = await newUser(unique('Autrice'))
  const member = await newUser(unique('Lectrice'))
  // Rides off: the feed's create button then opens the post editor directly.
  const team = await newTeam(author, unique('Brouillons'), {
    addMemberAllowed: true,
    enableRides: false,
  })
  await addMember(author, team.slug, member)
  const title = unique('Compte rendu à relire')
  const body = 'Merci à tous pour la sortie de dimanche.'
  const main = page.getByRole('main')

  await signIn(page.context(), author)
  await page.goto(`/equipes/${team.slug}/articles`)
  await expect(
    main.getByRole('heading', { level: 2, name: 'Publications', exact: true })
  ).toBeVisible()
  const create = main.getByRole('link', { name: 'Nouvelle publication' })
  await hydrated(create)
  await create.click()
  await expect(main.getByRole('heading', { level: 1, name: 'Nouvelle publication' })).toBeVisible()
  const titleInput = main.getByRole('textbox', { name: 'Titre' })
  await hydrated(titleInput)
  await titleInput.fill(title)
  await typeRichText(main, body)
  // A draft is the editor's default.
  await expect(main.getByRole('radio', { name: 'Brouillon' })).toBeChecked()
  await main.getByRole('button', { name: 'Créer la publication' }).click()
  await expect(toasts(page).filter({ hasText: 'Publication créée avec succès' })).toBeVisible()
  await expect(page).toHaveURL(new RegExp(`/equipes/${team.slug}/articles/(?!nouveau$)[^/]+$`))
  const postSlug = new URL(page.url()).pathname.split('/').pop()!
  await expect(main.getByRole('heading', { level: 2, name: title })).toBeVisible()
  await expect(main.getByText('Brouillon', { exact: true })).toBeVisible()
  expect((await fetchPost(author, team.slug, postSlug)).status).toBe('DRAFT')

  const reader = await pageAs(browser, member)
  const memberMain = reader.page.getByRole('main')
  const openMemberFeed = async () => {
    await reader.page.goto(`/equipes/${team.slug}/articles`)
    await expect(
      memberMain.getByRole('heading', { level: 2, name: 'Publications', exact: true })
    ).toBeVisible()
    await expect(memberMain.getByText(/^\d+ publications?$/)).toBeVisible()
  }
  try {
    // --- A draft: members see nothing of it.
    expect(await findPost(member, team.slug, postSlug), 'a draft is 404 to a member').toBeNull()
    await openMemberFeed()
    await expect(memberMain.getByText('0 publication', { exact: true })).toBeVisible()
    await expect(entityCard(memberMain, title)).toHaveCount(0)

    // --- Published from the post page's menu.
    const menu = await openActionsMenu(page)
    await menu.getByRole('menuitem', { name: 'Publier' }).click()
    await expect(
      toasts(page).filter({ hasText: 'Publication mise à jour avec succès' })
    ).toBeVisible()
    await expect(main.getByText('Publié', { exact: true })).toBeVisible()
    await expect(main.getByText('Brouillon', { exact: true })).toHaveCount(0)
    const published = await fetchPost(author, team.slug, postSlug)
    expect(published.status).toBe('PUBLISHED')
    expect(published.name).toBe(title)
    expect(published.media.markdown.trim()).toBe(body)

    // --- The member finds it in the feed and reads it.
    await openMemberFeed()
    const card = entityCard(memberMain, title)
    await expect(card).toBeVisible()
    await hydrated(card)
    await card.click()
    await expect(reader.page).toHaveURL(new RegExp(`/equipes/${team.slug}/articles/${postSlug}$`))
    await expect(memberMain.getByRole('heading', { level: 2, name: title })).toBeVisible()
    await expect(memberMain.getByText(body, { exact: true })).toBeVisible()
  } finally {
    await reader.context.close()
  }
})

/**
 * A scheduled post: a draft that says when it will go out, published by the scheduler — which then
 * announces it in the team's name, since nobody pressed « Publier » (NotificationItem.tsx:35-39).
 */
test.describe('scheduled publication', () => {
  test('a post scheduled in the editor is published by the scheduler and announced in the team’s name', async ({
    page,
    browser,
  }) => {
    // The scheduler runs once a minute, then the notification dispatcher every 15 s.
    test.setTimeout(240_000)
    const author = await newUser(unique('Autrice'))
    const member = await newUser(unique('Lectrice'))
    const team = await newTeam(author, unique('Publications programmées'), {
      addMemberAllowed: true,
      enableRides: false,
    })
    await addMember(author, team.slug, member)
    const title = unique('Article programmé')
    const publishOn = parisDaysAhead(1, 7, 15)
    const main = page.getByRole('main')

    await test.step('the author schedules a draft in the editor', async () => {
      await signIn(page.context(), author)
      await page.goto(`/equipes/${team.slug}/articles/nouveau`)
      await expect(
        main.getByRole('heading', { level: 1, name: 'Nouvelle publication' })
      ).toBeVisible()
      const titleInput = main.getByRole('textbox', { name: 'Titre' })
      await hydrated(titleInput)
      await titleInput.fill(title)
      await typeRichText(main, 'Rendez-vous samedi.')
      // Only a draft offers a scheduled publication.
      await expect(main.getByRole('radio', { name: 'Brouillon' })).toBeChecked()
      await pickIntoEmptyPicker(
        page,
        main.getByRole('button', { name: 'Publication programmée' }),
        publishOn
      )
      await main.getByRole('button', { name: 'Créer la publication' }).click()
      await expect(toasts(page).filter({ hasText: 'Publication créée avec succès' })).toBeVisible()
      await expect(page).toHaveURL(new RegExp(`/equipes/${team.slug}/articles/(?!nouveau$)[^/]+$`))
    })
    const postSlug = new URL(page.url()).pathname.split('/').pop()!

    await test.step('before the date: a draft that says when, hidden from members', async () => {
      await expect(main.getByRole('heading', { level: 2, name: title })).toBeVisible()
      await expect(main.getByText('Brouillon', { exact: true })).toBeVisible()
      await expect(
        main.getByText(`Publication programmée pour le ${frenchDateTime(publishOn)}`, {
          exact: true,
        })
      ).toBeVisible()
      const saved = await fetchPost(author, team.slug, postSlug)
      expect(saved.status).toBe('DRAFT')
      expect(new Date(saved.publishAt!).toISOString()).toBe(parisInstant(publishOn))
      expect(await findPost(member, team.slug, postSlug), 'a draft is 404 to a member').toBeNull()
    })

    const due = pastPublishInstant()
    const publishAt = wallTimeOf(due)
    await test.step('the date comes: the scheduler publishes it, dated then', async () => {
      const saved = await fetchPost(author, team.slug, postSlug)
      await apiPut(author, `/api/teams/${team.slug}/posts/${postSlug}`, {
        name: saved.name,
        media: saved.media,
        dateTime: wallTimeOf(saved.dateTime, saved.timezone),
        status: saved.status,
        visibility: saved.visibility,
        publishAt,
      } satisfies PostRequest)
      await waitForAutoPublish(() => findPost(author, team.slug, postSlug))
      const published = await fetchPost(author, team.slug, postSlug)
      expect(published.publishAt, 'the schedule is spent').toBeUndefined()
      // A post, unlike a ride or a trip, takes its publication date as its own
      // (PublicationPublishScheduler).
      expect(new Date(published.dateTime).toISOString()).toBe(due)

      await page.reload()
      await expect(main.getByText('Publié', { exact: true })).toBeVisible()
      await expect(main.getByText(/^Publication programmée/)).toHaveCount(0)
    })

    await test.step('the members are told in the team’s name; the author is not told', async () => {
      const found = await waitForNotification(
        member,
        about('POST_PUBLISHED', postSlug),
        'the POST_PUBLISHED notification'
      )
      expect(found.actorName, 'nobody pressed « Publier »').toBeUndefined()
      expect(found).toMatchObject({ teamName: team.name, subjectName: title })
      // The scheduler passes the author as the actor, who is spared their own announcement.
      await expectNoNotification(author, about('POST_PUBLISHED', postSlug), 'the author')

      const reader = await pageAs(browser, member)
      try {
        await reader.page.goto('/notifications')
        await expect(
          reader.page.getByRole('main').getByRole('link').filter({ hasText: title })
        ).toContainText(`Nouvelle publication de ${team.name}`)
      } finally {
        await reader.context.close()
      }
    })
  })
})

test.describe('regressions', () => {
  test('the words typed right before saving a post are saved', async ({ page }) => {
    // MarkdownEditor handed the text to the form through a 150 ms debounce that submitting never
    // flushed: words typed within 150 ms of saving were lost, in every form using the editor
    // (fixed 2026-09-25: flushed on blur and on unmount).
    const author = await newUser(unique('Autrice'))
    const team = await newTeam(author, unique('Publications pressées'))
    const post = await newPost(author, team.slug, unique('Publication pressée'), {
      media: markdownMedia('Premier jet.'),
    })
    await signIn(page.context(), author)
    await page.clock.install()
    await page.goto(`/equipes/${team.slug}/articles/${post.slug}/modifier`)
    const main = page.getByRole('main')
    await expect(main.getByRole('textbox', { name: 'Titre' })).toHaveValue(post.name)
    const save = main.getByRole('button', { name: 'Enregistrer' })
    await hydrated(save)
    const editor = richText(main)
    await expect(editor).toHaveText('Premier jet.')

    // The author types the last words and clicks « Enregistrer » straight away: the clock stands
    // still, so the click lands inside the debounce whatever the machine's speed.
    await editor.click()
    await caretToBlockEnd(page, editor, KEY.documentEnd)
    await page.clock.pauseAt(Date.now() + 60_000)
    await page.keyboard.type(' Relu.')
    await expect(editor, 'the editor shows the typed words').toHaveText('Premier jet. Relu.')
    const saved = page.waitForResponse(
      (r) => r.request().method() === 'PUT' && r.url().endsWith(`/posts/${post.slug}`)
    )
    await save.click()
    expect((await saved).ok(), 'the update was accepted').toBe(true)
    await page.clock.resume()
    await expect(main.getByRole('heading', { level: 2, name: post.name })).toBeVisible()
    await expect(main.getByText('Premier jet. Relu.', { exact: true })).toBeVisible()
    expect((await fetchPost(author, team.slug, post.slug)).media.markdown).toContain(
      'Premier jet. Relu.'
    )
  })
})

/**
 * Undoing from the post page's menu: « Dépublier » (back to a draft), « Annuler » and « Réactiver »,
 * and « Restaurer » once deleted. The menu sends the PostDto back as the request with a new status
 * — so each step is checked to keep the text and its picture, not only to move the badge.
 */
test.describe('restoring', () => {
  const MARKDOWN = '## Programme\n\nDépart **à 8 h** devant le club.'

  test('a post is unpublished, cancelled, reactivated, deleted and restored, its text and picture intact', async ({
    page,
    browser,
  }) => {
    const author = await newUser(unique('Autrice'))
    const member = await newUser(unique('Lectrice'))
    const team = await newTeam(author, unique('Publications réversibles'), {
      addMemberAllowed: true,
      enableRides: false,
    })
    await addMember(author, team.slug, member)
    const image = await uploadImage(
      author,
      team.slug,
      'affiche.png',
      solidPng(96, 64, [30, 120, 200])
    )
    const media: MediaDto = {
      markdown: `${MARKDOWN}\n\n::asset{id="${image.id}"}`,
      assets: { images: [image], attachments: [] },
    }
    const post = await newPost(author, team.slug, unique('Article réversible'), { media })
    const main = page.getByRole('main')

    /** The stored post: its status, and the text and picture it was written with. */
    async function expectStored(status: string, deleted = false) {
      const stored = await fetchPost(author, team.slug, post.slug)
      expect(stored).toMatchObject({ status, deleted, name: post.name })
      expect(stored.media.markdown, 'the text').toContain(MARKDOWN)
      expect(stored.media.markdown, 'the picture').toContain(`::asset{id="${image.id}"`)
      expect(stored.media.assets.images.map((i) => i.id)).toEqual([image.id])
    }
    const updated = () =>
      expect(toasts(page).filter({ hasText: 'Publication mise à jour avec succès' }).first())

    await signIn(page.context(), author)
    await page.goto(postPath(team.slug, post.slug))
    await expect(main.getByRole('heading', { level: 2, name: post.name })).toBeVisible()
    await expect(main.getByText('Publié', { exact: true })).toBeVisible()

    await test.step('« Dépublier » turns it back into a draft the member no longer reads', async () => {
      await (await openActionsMenu(page)).getByRole('menuitem', { name: 'Dépublier' }).click()
      const dialog = page.getByRole('dialog', { name: 'Dépublier' })
      await expect(dialog).toContainText('Elle redeviendra un brouillon.')
      await dialog.getByRole('button', { name: 'Dépublier' }).click()
      await expect(dialog).toBeHidden()
      await updated().toBeVisible()
      await expect(main.getByText('Brouillon', { exact: true })).toBeVisible()
      await expectStored('DRAFT')
      expect(await findPost(member, team.slug, post.slug), 'a draft is 404 to a member').toBeNull()

      await (await openActionsMenu(page)).getByRole('menuitem', { name: 'Publier' }).click()
      await expect(main.getByText('Publié', { exact: true })).toBeVisible()
      await expectStored('PUBLISHED')
    })

    await test.step('« Annuler » marks it cancelled; « Réactiver » publishes it again', async () => {
      // The menu item says « Annuler »; its dialog and confirmation, « Annuler la publication ».
      await (
        await openActionsMenu(page)
      )
        .getByRole('menuitem', { name: 'Annuler', exact: true })
        .click()
      const cancel = page.getByRole('dialog', { name: 'Annuler la publication' })
      await expect(cancel).toContainText('Voulez-vous annuler cette publication ?')
      await cancel.getByRole('button', { name: 'Annuler la publication' }).click()
      await expect(cancel).toBeHidden()
      await expect(main.getByText('Annulé', { exact: true })).toBeVisible()
      await expectStored('CANCELLED')
      // Cancelled is not hidden: a member still reads it, marked so — as a ride or a trip.
      expect((await fetchPost(member, team.slug, post.slug)).status).toBe('CANCELLED')

      await (await openActionsMenu(page)).getByRole('menuitem', { name: 'Réactiver' }).click()
      const reactivate = page.getByRole('dialog', { name: 'Réactiver' })
      await expect(reactivate).toContainText('Elle sera à nouveau publiée.')
      await reactivate.getByRole('button', { name: 'Réactiver' }).click()
      await expect(reactivate).toBeHidden()
      await expect(main.getByText('Publié', { exact: true })).toBeVisible()
      await expect(main.getByText('Annulé', { exact: true })).toHaveCount(0)
      await expectStored('PUBLISHED')
    })

    await test.step('deleted, then « Restaurer » from its page', async () => {
      await (await openActionsMenu(page)).getByRole('menuitem', { name: 'Supprimer' }).click()
      const dialog = page.getByRole('dialog', { name: 'Supprimer' })
      await dialog.getByRole('button', { name: 'Supprimer' }).click()
      await expect(
        toasts(page).filter({ hasText: 'Publication supprimée avec succès' })
      ).toBeVisible()
      await expect(page).toHaveURL(new RegExp(`/equipes/${team.slug}/articles$`))
      await expect(entityCard(main, post.name).getByText('Supprimé', { exact: true })).toBeVisible()
      expect(await findPost(member, team.slug, post.slug)).toBeNull()

      await page.goto(postPath(team.slug, post.slug))
      await expect(main.getByRole('heading', { level: 2, name: post.name })).toBeVisible()
      await (await openActionsMenu(page)).getByRole('menuitem', { name: 'Restaurer' }).click()
      await expect(
        toasts(page).filter({ hasText: 'Publication restaurée avec succès' })
      ).toBeVisible()
      const again = await openActionsMenu(page)
      await expect(again.getByRole('menuitem', { name: 'Supprimer' })).toBeVisible()
      await expect(again.getByRole('menuitem', { name: 'Restaurer' })).toHaveCount(0)
      await page.keyboard.press('Escape')
      await expectStored('PUBLISHED')
    })

    await test.step('the member reads it again, as it was written', async () => {
      const reader = await pageAs(browser, member)
      try {
        const memberMain = reader.page.getByRole('main')
        await reader.page.goto(postPath(team.slug, post.slug))
        await expect(memberMain.getByRole('heading', { level: 2, name: post.name })).toBeVisible()
        await expect(memberMain.getByRole('heading', { level: 2, name: 'Programme' })).toBeVisible()
        await expect(memberMain.locator('strong', { hasText: 'à 8 h' })).toBeVisible()
        const picture = memberMain.locator(`img[src*="${image.id}"]`)
        await expect(picture).toBeVisible()
        await expect
          .poll(() => picture.evaluate((img) => (img as HTMLImageElement).naturalWidth))
          .toBeGreaterThan(0)
      } finally {
        await reader.context.close()
      }
    })
  })
})

/**
 * Replies: one level of threading under a comment, a reply notifies whom it answers, and a member
 * deletes nothing of anyone else's.
 */
test.describe('comment replies', () => {
  /** A team owned by the post's author, with two plain members: the commenter and the replier. */
  async function thread(label: string) {
    const author = await newUser(unique('Autrice'))
    const [writer, replier] = await Promise.all([
      newUser(unique('Commentatrice')),
      newUser(unique('Répondeur')),
    ])
    const team = await newTeam(author, unique(label), {
      addMemberAllowed: true,
      enableRides: false,
    })
    await addMember(author, team.slug, writer)
    await addMember(author, team.slug, replier)
    const post = await newPost(author, team.slug, unique('Article discuté'))
    return { author, writer, replier, team, post }
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

  /**
   * The comment block of `text`: the element CommentItem renders around a comment and its replies.
   * A reply's block is the one drawn with a left border, inside its parent's.
   */
  const replyBlock = (text: ReturnType<Page['getByText']>) =>
    text.locator('xpath=ancestor::div[contains(@style, "border-left")]')

  test('a member replies under a comment: one level only, the commenter is notified, nobody deletes another’s comment', async ({
    page,
  }) => {
    // The dispatcher runs every 15 s (support/notifications.ts).
    test.setTimeout(120_000)
    const { author, writer, replier, team, post } = await thread('Discussions')
    const rootText = 'Qui vient dimanche ?'
    const replyText = 'Moi, avec le gilet jaune.'
    const root = await commentOnPost(writer, team.slug, post.slug, rootText)

    await signIn(page.context(), replier)
    await page.goto(postPath(team.slug, post.slug))
    const main = page.getByRole('main')
    await expect(main.getByRole('heading', { name: 'Commentaires (1)' })).toBeVisible()
    await expect(main.getByText(rootText, { exact: true })).toBeVisible()

    await test.step('the reply form opens under the comment and posts a nested reply', async () => {
      const reply = main.getByRole('button', { name: 'Répondre' })
      await hydrated(reply)
      await reply.click()
      const box = main.getByRole('textbox', { name: 'Écrivez une réponse...' })
      await expect(box).toBeFocused()
      await box.fill(replyText)
      await main
        .locator('form')
        .filter({ has: page.getByRole('textbox', { name: 'Écrivez une réponse...' }) })
        .getByRole('button', { name: 'Envoyer le commentaire' })
        .click()
      await expect(box).toBeHidden()
      await expect(main.getByRole('heading', { name: 'Commentaires (2)' })).toBeVisible()

      const replied = main.getByText(replyText, { exact: true })
      await expect(replied).toBeVisible()
      // Nested under the comment it answers, which is itself top-level.
      await expect(replyBlock(replied)).toHaveCount(1)
      await expect(replyBlock(replied).locator('xpath=../..')).toContainText(rootText)
      await expect(replyBlock(main.getByText(rootText, { exact: true }))).toHaveCount(0)
      // No third level: only the top-level comment offers « Répondre ».
      await expect(main.getByRole('button', { name: 'Répondre' })).toHaveCount(1)
      await expect(replyBlock(replied).getByRole('button', { name: 'Répondre' })).toHaveCount(0)
    })

    const stored = await readPostComments(writer, team.slug, post.slug)
    expect(stored.total).toBe(2)
    expect(stored.items).toHaveLength(1)
    expect(stored.items[0]).toMatchObject({ id: root.id, replyCount: 1 })
    const reply = stored.items[0].replies[0]
    expect(reply).toMatchObject({ content: replyText, parentId: root.id })
    expect(reply.author.id).toBe(replier.user.id)

    await test.step('nor through the API: a reply to a reply is refused', async () => {
      expect(
        await statusOf(commentOnPost(writer, team.slug, post.slug, 'Troisième niveau', reply.id))
      ).toBe(400)
      expect((await readPostComments(writer, team.slug, post.slug)).total).toBe(2)
    })

    await test.step('the replier deletes only their own reply', async () => {
      // One « Supprimer »: on the reply, not on the comment it answers.
      const remove = main.getByRole('button', { name: 'Supprimer', exact: true })
      await expect(remove).toHaveCount(1)
      await expect(replyBlock(main.getByText(replyText, { exact: true }))).toContainText(
        'Supprimer'
      )
      const base = `/api/teams/${team.slug}/posts/${post.slug}/comments`
      expect(await statusOf(apiDelete(replier, `${base}/${root.id}`))).toBe(403)
      expect((await readPostComments(writer, team.slug, post.slug)).total).toBe(2)
    })

    await test.step('the commenter is notified of the reply, the post author is not', async () => {
      const notification = await waitForNotification(
        writer,
        about('COMMENT_REPLY', post.slug),
        'the COMMENT_REPLY notification'
      )
      expect(notification).toMatchObject({
        actorName: replier.user.displayName,
        teamSlug: team.slug,
        excerpt: replyText,
      })
      // The comment's event was queued before the reply's, and events are dispatched oldest
      // first: once the reply's is in, the author has heard of the comment — and of nothing else.
      const authorInbox = (await listNotifications(author)).items.filter(
        (n) => n.subjectSlug === post.slug
      )
      expect(authorInbox.map((n) => n.type)).toEqual(['COMMENT_ON_MY_PUBLICATION'])
      const replierInbox = (await listNotifications(replier)).items
      expect(replierInbox.filter(about('COMMENT_REPLY', post.slug))).toEqual([])
    })
  })

  test('a thread the page does not embed opens on « Voir les N réponses »', async ({ page }) => {
    // The backend embeds every reply of a page of comments (CommentService.rootPage), so
    // `replyCount` never exceeds the replies carried and the button never shows from real data.
    // The client is written for a page that embeds fewer (CommentItem.tsx:65-76): this test takes
    // the replies out of the list responses the browser receives — the thread endpoint it then
    // calls is the real one.
    const { author, writer, replier, team, post } = await thread('Fils repliés')
    const root = await commentOnPost(writer, team.slug, post.slug, 'Le parcours est-il roulant ?')
    const replies = ['Oui, tout en asphalte.', 'Une côte à 8 % au milieu.']
    await commentOnPost(replier, team.slug, post.slug, replies[0], root.id)
    await commentOnPost(author, team.slug, post.slug, replies[1], root.id)

    const listEndpoint = `/api/teams/${team.slug}/posts/${post.slug}/comments`
    const threadReads: string[] = []
    await page.route(
      (url) => url.pathname === listEndpoint,
      async (route) => {
        const url = new URL(route.request().url())
        if (url.searchParams.has('parentId')) {
          threadReads.push(url.searchParams.get('parentId')!)
          return route.continue()
        }
        const response = await route.fetch()
        const body = (await response.json()) as CommentListResponse
        body.items = body.items.map((comment) => ({ ...comment, replies: [] }))
        return route.fulfill({ response, json: body })
      }
    )

    // Reached from the team feed, so that the browser reads the comments itself: the server's
    // prefetch of a page opened by URL would embed the replies.
    await signIn(page.context(), writer)
    await page.goto(`/equipes/${team.slug}/articles`)
    const main = page.getByRole('main')
    const card = entityCard(main, post.name)
    await hydrated(card)
    await card.click()
    await expect(page).toHaveURL(new RegExp(`${postPath(team.slug, post.slug)}$`))
    await expect(main.getByRole('heading', { name: 'Commentaires (3)' })).toBeVisible()
    await expect(main.getByText(root.content, { exact: true })).toBeVisible()
    for (const reply of replies) await expect(main.getByText(reply, { exact: true })).toHaveCount(0)

    const expand = main.getByRole('button', { name: 'Voir les 2 réponses' })
    await hydrated(expand)
    await expand.click()
    for (const reply of replies) {
      const shown = main.getByText(reply, { exact: true })
      await expect(shown).toBeVisible()
      await expect(replyBlock(shown)).toHaveCount(1)
    }
    await expect(expand).toBeHidden()
    expect(threadReads).toEqual([root.id])
    await expect(main.getByRole('button', { name: 'Répondre' })).toHaveCount(1)
  })
})

test.describe('app defects', () => {
  test('the confirmation of « Annuler » tells its two buttons apart, and says the post stays readable', async ({
    page,
  }) => {
    // Regression (8aa4a225): the dialog and its confirm button say « Annuler la publication » — before,
    // both said « Annuler », the very label of ConfirmDialog's dismiss button.
    const author = await newUser(unique('Autrice'))
    const team = await newTeam(author, unique('Publications annulées'))
    const post = await newPost(author, team.slug, unique('Article à annuler'))
    await signIn(page.context(), author)
    await page.goto(postPath(team.slug, post.slug))
    await expect(
      page.getByRole('main').getByRole('heading', { level: 2, name: post.name })
    ).toBeVisible()
    await (await openActionsMenu(page)).getByRole('menuitem', { name: /^Annuler/ }).click()
    const dialog = page.getByRole('dialog', { name: /^Annuler/ })
    await expect(dialog).toBeVisible()
    // The dismiss button and the confirmation: one of them only may say « Annuler ».
    await expect(dialog.getByRole('button', { name: 'Annuler', exact: true })).toHaveCount(1)
    await expect(
      dialog.getByRole('button', { name: 'Annuler la publication', exact: true })
    ).toBeVisible()
    // Same commit: the message said « Elle ne sera plus visible », while a cancelled post stays
    // readable to the members, marked « Annulé » — as the « restoring » test shows.
    await expect(
      dialog.getByText(
        'Voulez-vous annuler cette publication ? Elle restera lisible, marquée « Annulé ».',
        { exact: true }
      )
    ).toBeVisible()
  })
})
