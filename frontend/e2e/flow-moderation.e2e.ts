import type { Page } from '@playwright/test'
import type { ModerationQueueResponse } from '../src/api/dto'
import { roleSession } from './support/data'
import { expect, test, unique } from './support/fixtures'
import {
  PLATFORM_QUEUE_PATH,
  blockedBy,
  commentRow,
  itemAbout,
  markDocument,
  moderationWorld,
  navigateInApp,
  openBlockedUsersInApp,
  platformQueue,
  queueCard,
  queueTab,
  report,
  teamQueue,
  teamQueuePath,
} from './support/moderation'
import { commentOnPost, findPost, newPost, postPath, readPostComments } from './support/posts'
import { entityCard, hydrated, pageAs } from './support/ui'

/**
 * Moderation, end to end: a member reports a post from its page, two more through the API, and the
 * third distinct reporter hides it from every member but the team's moderators
 * (ReportService.AUTO_HIDE_REPORTERS). The team's moderator decides from « Signalements » without
 * ever learning who reported; the platform admin sees the same reports with the team and the
 * reporters, and a decision there closes the team's card too. Blocking a comment's author hides
 * their comments from the blocker; unblocking from the profile brings them back, in the same app.
 *
 * The reporters' anonymity in the team queue is checked on the three layers a moderator can read:
 * the DOM, the server-rendered document (its dehydrated query state included), and the XHR the
 * queue refetches after a decision.
 *
 * Every test resolves the reports it filed: the platform queue is domain-wide and outlives a run.
 */

const REPORT_MESSAGE = 'Propos déplacés envers un membre du club.'

/**
 * The team's « Publications » (WEB-68), loaded — `visible` is on it, so an absence check that
 * follows is meaningful.
 */
async function openFeed(page: Page, teamSlug: string, visible: string) {
  await page.goto(`/equipes/${teamSlug}/articles`)
  await expect(entityCard(page.getByRole('main'), visible)).toBeVisible()
}

/** Whether `html` names any of `names` — literally, or JSON- or HTML-escaped as SSR writes them. */
function namesIn(html: string, names: string[]) {
  return names.filter(
    (name) =>
      html.includes(name) ||
      html.includes(JSON.stringify(name).slice(1, -1)) ||
      html.includes(name.replace(/'/g, '&#x27;'))
  )
}

test.describe('team moderation', () => {
  test('three reports hide a post from members; the moderator sees them anonymously and dismisses them', async ({
    browser,
  }) => {
    const world = await moderationWorld('Modération rejet')
    const { team, moderator, author, reporters, bystander } = world
    const [first, second, third] = reporters
    const reporterNames = reporters.map((r) => r.user.displayName)
    const reported = await newPost(author, team.slug, unique('Post signalé'))
    const control = await newPost(author, team.slug, unique('Post témoin'))

    await test.step('a member reports the post from its page, and stops seeing it', async () => {
      const { context, page } = await pageAs(browser, first)
      const main = page.getByRole('main')
      await page.goto(postPath(team.slug, reported.slug))
      await expect(main.getByRole('heading', { level: 2, name: reported.name })).toBeVisible()
      // No comment on the post: the page's only moderation menu is the header's.
      const menu = main.getByRole('button', { name: "Plus d'actions" })
      await hydrated(menu)
      await menu.click()
      await page.getByRole('menuitem', { name: 'Signaler' }).click()

      const dialog = page.getByRole('dialog', { name: 'Signaler ce post' })
      await expect(dialog).toBeVisible()
      await expect(dialog.getByText(`Transmis à qui organise ${team.name}`)).toBeVisible()
      const send = dialog.getByRole('button', { name: 'Envoyer' })
      // A reason is required.
      await expect(send).toBeDisabled()
      await dialog.getByRole('radio', { name: 'Harcèlement' }).check()
      await dialog.getByRole('textbox', { name: 'Précisions (facultatif)' }).fill(REPORT_MESSAGE)
      await send.click()

      await expect(page.getByText('Merci. Ce contenu est masqué pour vous.')).toBeVisible()
      await expect(dialog).toBeHidden()
      // Back on the team's feed, where the post no longer is — for the reporter alone.
      await expect(page).toHaveURL(new RegExp(`/equipes/${team.slug}$`))
      await expect(entityCard(main, control.name)).toBeVisible()
      await expect(entityCard(main, reported.name)).toHaveCount(0)
      await context.close()

      const item = itemAbout(await teamQueue(moderator, team.slug), reported.id)
      expect(item?.reportCount).toBe(1)
      expect(item?.hidden).toBe(false)
      expect(item?.reasons).toEqual(['HARASSMENT'])
      expect(item?.messages).toEqual([REPORT_MESSAGE])
    })

    await test.step('two reporters leave it visible; the third hides it from every member', async () => {
      await report(second, team.slug, 'POST', reported.id, 'SPAM')
      expect(
        await findPost(bystander, team.slug, reported.slug),
        'two reports hide nothing'
      ).not.toBeNull()
      // A second report by the same member is a no-op: still two distinct reporters.
      await report(second, team.slug, 'POST', reported.id, 'SPAM')
      expect(await findPost(bystander, team.slug, reported.slug)).not.toBeNull()

      await report(third, team.slug, 'POST', reported.id, 'SPAM')
      expect(await findPost(bystander, team.slug, reported.slug), 'hidden, by link too').toBeNull()
      expect(await findPost(first, team.slug, reported.slug)).toBeNull()
      // The team's moderators still read it: they have to, to decide.
      expect(await findPost(moderator, team.slug, reported.slug)).not.toBeNull()

      const { context, page } = await pageAs(browser, bystander)
      await openFeed(page, team.slug, control.name)
      await expect(entityCard(page.getByRole('main'), reported.name)).toHaveCount(0)
      await context.close()
    })

    const { context, page } = await pageAs(browser, moderator)
    const main = page.getByRole('main')
    const card = queueCard(page, reported.name)

    await test.step('the moderator sees three reports, the post hidden, and no reporter', async () => {
      const response = await page.goto(teamQueuePath(team.slug))
      const html = await response!.text()
      // The server rendered the queue — the post is in the document — but no reporter's name,
      // neither in the markup nor in the dehydrated query state.
      expect(html).toContain(reported.name)
      expect(namesIn(html, reporterNames), 'reporters named in the server document').toEqual([])

      await expect(card).toHaveCount(1)
      await expect(card.getByText('Post', { exact: true })).toBeVisible()
      await expect(card.getByText('3 signalements', { exact: true })).toBeVisible()
      await expect(card.getByText('Masqué aux membres', { exact: true })).toBeVisible()
      await expect(card.getByText(`Auteur : ${author.user.displayName}`)).toBeVisible()
      await expect(card.getByText('Harcèlement', { exact: true })).toBeVisible()
      await expect(card.getByText('Spam ou publicité', { exact: true })).toBeVisible()
      await expect(card.getByText(REPORT_MESSAGE, { exact: true })).toBeVisible()
      await expect(card.getByRole('link', { name: reported.name })).toHaveAttribute(
        'href',
        postPath(team.slug, reported.slug)
      )
      await expect(card.getByText('Signalé par')).toHaveCount(0)
      for (const name of reporterNames) await expect(main.getByText(name)).toHaveCount(0)

      const item = itemAbout(await teamQueue(moderator, team.slug), reported.id)
      expect(item?.reportCount).toBe(3)
      expect(item?.hidden).toBe(true)
      expect(item?.reporters ?? null, 'the team queue carries no reporter').toBeNull()
    })

    await test.step('« Rejeter le signalement » shows the post again to members', async () => {
      const dismiss = card.getByRole('button', { name: 'Rejeter le signalement' })
      await hydrated(dismiss)
      const refetched = page.waitForResponse(
        (r) =>
          r.request().method() === 'GET' &&
          new URL(r.url()).pathname === `/api/teams/${team.slug}/reports`
      )
      await dismiss.click()
      await expect(page.getByText('Signalement rejeté : le contenu reste visible.')).toBeVisible()
      // The XHR the queue refetches names no reporter either.
      const queue = (await (await refetched).json()) as ModerationQueueResponse
      expect(queue.items.every((i) => i.reporters == null)).toBe(true)
      expect(namesIn(JSON.stringify(queue), reporterNames)).toEqual([])
      await expect(card).toHaveCount(0)
      await expect(main.getByText('Aucun signalement en attente')).toBeVisible()

      await queueTab(page, 'Traités')
      await expect(page).toHaveURL(/status=RESOLVED/)
      await expect(card.getByText('Rejeté', { exact: true })).toBeVisible()
      await expect(card.getByText('Masqué aux membres')).toHaveCount(0)
      await expect(card.getByRole('button', { name: 'Rejeter le signalement' })).toHaveCount(0)

      expect(await findPost(bystander, team.slug, reported.slug)).not.toBeNull()
      const reader = await pageAs(browser, bystander)
      await openFeed(reader.page, team.slug, control.name)
      await expect(entityCard(reader.page.getByRole('main'), reported.name)).toBeVisible()
      await reader.context.close()
    })
    await context.close()
  })

  test('« Supprimer le contenu » deletes the reported post for everyone', async ({ browser }) => {
    const { team, moderator, author, reporters, bystander } =
      await moderationWorld('Modération suppression')
    const reported = await newPost(author, team.slug, unique('Post supprimé'))
    for (const reporter of reporters) await report(reporter, team.slug, 'POST', reported.id, 'HATE')

    const { context, page } = await pageAs(browser, moderator)
    const card = queueCard(page, reported.name)
    await page.goto(teamQueuePath(team.slug))
    await expect(card.getByText('3 signalements', { exact: true })).toBeVisible()
    await expect(card.getByText('Propos haineux', { exact: true })).toBeVisible()

    const remove = card.getByRole('button', { name: 'Supprimer le contenu' })
    await hydrated(remove)
    await remove.click()
    const confirm = page.getByRole('dialog', { name: 'Supprimer ce contenu ?' })
    await expect(confirm).toBeVisible()
    await confirm.getByRole('button', { name: 'Supprimer le contenu' }).click()
    await expect(page.getByText('Contenu supprimé.', { exact: true })).toBeVisible()
    await expect(card).toHaveCount(0)

    await queueTab(page, 'Traités')
    await expect(card.getByText('Supprimé', { exact: true })).toBeVisible()

    // Deleted, not merely hidden: a dismissal can no longer bring it back.
    expect(await findPost(bystander, team.slug, reported.slug)).toBeNull()
    expect(await findPost(reporters[0], team.slug, reported.slug)).toBeNull()
    const kept = await findPost(moderator, team.slug, reported.slug)
    expect(kept === null || kept.deleted, 'the moderator reads it deleted, or not at all').toBe(
      true
    )
    expect(itemAbout(await teamQueue(moderator, team.slug), reported.id)).toBeUndefined()
    expect(itemAbout(await teamQueue(moderator, team.slug, 'RESOLVED'), reported.id)?.status).toBe(
      'REMOVED'
    )
    await context.close()
  })
})

test.describe('platform moderation', () => {
  test('the platform admin sees the team and the reporters, and its decision closes the team card', async ({
    browser,
  }) => {
    const { team, moderator, author, reporters, bystander } =
      await moderationWorld('Modération plateforme')
    const reporterNames = reporters.map((r) => r.user.displayName)
    const reported = await newPost(author, team.slug, unique('Post plateforme'))
    // A free text each — never the reporter's name, which only the platform queue may show.
    for (const [index, reporter] of reporters.entries())
      await report(reporter, team.slug, 'POST', reported.id, 'SPAM', `Précision n° ${index + 1}`)

    const admin = await roleSession('admin')
    const { context, page } = await pageAs(browser, admin)
    const card = queueCard(page, reported.name)

    await test.step('the team queue, even read by a platform admin, names no reporter', async () => {
      await page.goto(teamQueuePath(team.slug))
      await expect(card.getByText('3 signalements', { exact: true })).toBeVisible()
      await expect(card.getByText('Signalé par')).toHaveCount(0)
      await expect(card.getByText(`Équipe : ${team.name}`)).toHaveCount(0)
    })

    const sameDocument = await markDocument(page)

    await test.step('the platform queue shows the team and who reported', async () => {
      await navigateInApp(page, PLATFORM_QUEUE_PATH)
      await expect(card).toHaveCount(1)
      await expect(card.getByText(`Équipe : ${team.name}`, { exact: true })).toBeVisible()
      await expect(card.getByText('Signalé par', { exact: true })).toBeVisible()
      for (const name of reporterNames)
        await expect(card.getByText(name, { exact: true }).first()).toBeVisible()
      await expect(card.getByText('Masqué aux membres', { exact: true })).toBeVisible()

      const item = itemAbout(await platformQueue(admin), reported.id)
      expect(item?.teamSlug).toBe(team.slug)
      expect(item?.reporters?.map((r) => r.id).sort()).toEqual(
        reporters.map((r) => r.user.id).sort()
      )
    })

    await test.step('its decision removes the post and empties the team queue', async () => {
      const remove = card.getByRole('button', { name: 'Supprimer le contenu' })
      await hydrated(remove)
      await remove.click()
      const confirm = page.getByRole('dialog', { name: 'Supprimer ce contenu ?' })
      await confirm.getByRole('button', { name: 'Supprimer le contenu' }).click()
      await expect(page.getByText('Contenu supprimé.', { exact: true })).toBeVisible()
      await expect(card).toHaveCount(0)

      // Back to the team queue the admin read first, in the same app: the decision was taken
      // elsewhere, and the card that was cached must not come back.
      await page.goBack()
      await expect(page).toHaveURL(new RegExp(`${teamQueuePath(team.slug)}$`))
      await expect(page.getByRole('main').getByText('Aucun signalement en attente')).toBeVisible()
      await expect(card).toHaveCount(0)
      expect(await sameDocument(), 'the app was not reloaded').toBe(true)
    })
    await context.close()

    await test.step('the team moderator finds it decided', async () => {
      expect(itemAbout(await teamQueue(moderator, team.slug), reported.id)).toBeUndefined()
      const item = itemAbout(await teamQueue(moderator, team.slug, 'RESOLVED'), reported.id)
      expect(item?.status).toBe('REMOVED')
      expect(item?.reporters ?? null).toBeNull()

      const mod = await pageAs(browser, moderator)
      const modCard = queueCard(mod.page, reported.name)
      await mod.page.goto(teamQueuePath(team.slug, 'RESOLVED'))
      await expect(modCard.getByText('Supprimé', { exact: true })).toBeVisible()
      for (const name of reporterNames)
        await expect(mod.page.getByRole('main').getByText(name)).toHaveCount(0)
      await mod.context.close()
      expect(await findPost(bystander, team.slug, reported.slug)).toBeNull()
    })
  })
})

test.describe('blocking', () => {
  test('blocking a comment author hides their comments; unblocking from the profile brings them back without a reload', async ({
    browser,
  }) => {
    const { team, author, reporters } = await moderationWorld('Modération blocage')
    // Two plain members: one writes, the other reads and blocks.
    const [writer, reader] = reporters
    const writerName = writer.user.displayName
    const post = await newPost(author, team.slug, unique('Post commenté'))
    const controlComment = unique('Commentaire de l’autrice')
    const blockedComment = unique('Commentaire à bloquer')
    await commentOnPost(author, team.slug, post.slug, controlComment)
    await commentOnPost(writer, team.slug, post.slug, blockedComment)

    const { context, page } = await pageAs(browser, reader)
    const main = page.getByRole('main')

    await test.step('the reader blocks the author of a comment from the comment itself', async () => {
      await page.goto(postPath(team.slug, post.slug))
      await expect(main.getByText(controlComment, { exact: true })).toBeVisible()
      await expect(main.getByText(blockedComment, { exact: true })).toBeVisible()

      const menu = commentRow(main, blockedComment).getByRole('button', { name: "Plus d'actions" })
      await hydrated(menu)
      await menu.click()
      await page.getByRole('menuitem', { name: `Bloquer ${writerName}` }).click()
      const confirm = page.getByRole('dialog', { name: `Bloquer ${writerName} ?` })
      await expect(confirm).toBeVisible()
      await confirm.getByRole('button', { name: 'Bloquer', exact: true }).click()
      await expect(page.getByText(`Vous avez bloqué ${writerName}.`, { exact: true })).toBeVisible()

      await expect(main.getByText(blockedComment, { exact: true })).toHaveCount(0)
      await expect(main.getByText(controlComment, { exact: true })).toBeVisible()
      const comments = await readPostComments(reader, team.slug, post.slug)
      expect(comments.items.map((c) => c.content)).toEqual([controlComment])
      expect((await blockedBy(reader)).users.map((u) => u.id)).toEqual([writer.user.id])
      // Silent and one-way: the author still reads both comments.
      const seenByWriter = await readPostComments(writer, team.slug, post.slug)
      expect(seenByWriter.items.map((c) => c.content).sort()).toEqual(
        [controlComment, blockedComment].sort()
      )
    })

    await test.step('unblocking from the profile brings the comment back in the same app', async () => {
      const sameDocument = await markDocument(page)
      await openBlockedUsersInApp(page, reader.user.displayName)
      await expect(main.getByRole('heading', { name: 'Personnes bloquées' })).toBeVisible()
      const unblock = main.getByRole('button', { name: 'Débloquer' })
      await expect(unblock).toHaveCount(1)
      await expect(main.getByText(writerName, { exact: true })).toBeVisible()
      await hydrated(unblock)
      await unblock.click()
      await expect(page.getByText(`${writerName} est débloqué.`, { exact: true })).toBeVisible()
      await expect(main.getByText("Vous n'avez bloqué personne.")).toBeVisible()
      expect((await blockedBy(reader)).users).toEqual([])

      // Back through « Confidentialité » and the overview, to the post.
      for (let step = 0; step < 3; step++) await page.goBack()
      await expect(page).toHaveURL(new RegExp(`${postPath(team.slug, post.slug)}$`))
      await expect(main.getByText(blockedComment, { exact: true })).toBeVisible()
      await expect(main.getByText(controlComment, { exact: true })).toBeVisible()
      expect(await sameDocument(), 'the app was not reloaded').toBe(true)
    })
    await context.close()
  })
})
