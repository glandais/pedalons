import { expect, test, type Locator, type Page } from '@playwright/test'
import type {
  BlockedUsersResponse,
  ModerationItemDto,
  ModerationQueueResponse,
  ReportQueueStatus,
  ReportReason,
  ReportRequest,
  ReportTargetType,
  TeamDetailDto,
} from '../../src/api/dto'
import { apiGet, apiPost, type AuthResponse } from './api'
import { addMember, newTeam, newUser } from './data'
import { unique } from './fixtures'
import { escapeRegExp, hydrated } from './ui'

/**
 * The moderation journey's helpers (flow-moderation.e2e.ts): reports and blocks sent through the
 * REST API, the two moderation queues read back, and the locators of the queue's cards.
 */

/** POST /api/reports as `who`. Idempotent server side: a second report by the same member is a no-op. */
export const report = (
  who: AuthResponse,
  teamSlug: string,
  targetType: ReportTargetType,
  targetId: string,
  reason: ReportReason = 'SPAM',
  message?: string
) =>
  apiPost(who, '/api/reports', {
    teamSlug,
    targetType,
    targetId,
    reason,
    message,
  } satisfies ReportRequest)

export const blockedBy = (who: AuthResponse) =>
  apiGet<BlockedUsersResponse>(who, '/api/users/me/blocks')

/** The team's queue as `who` (an organizer or admin of the team, or a platform admin). */
export const teamQueue = (
  who: AuthResponse,
  teamSlug: string,
  status: ReportQueueStatus = 'OPEN'
) => apiGet<ModerationQueueResponse>(who, `/api/teams/${teamSlug}/reports`, { status })

/** The whole domain's queue — platform admins only. Shared by every test: filter it by target. */
export const platformQueue = (who: AuthResponse, status: ReportQueueStatus = 'OPEN') =>
  apiGet<ModerationQueueResponse>(who, '/api/admin/reports', { status })

/** The item of `queue` about `targetId`, or undefined. */
export const itemAbout = (queue: ModerationQueueResponse, targetId: string) =>
  queue.items.find((item: ModerationItemDto) => item.targetId === targetId)

export const teamQueuePath = (teamSlug: string, status: ReportQueueStatus = 'OPEN') =>
  `/equipes/${teamSlug}/admin/signalements${status === 'OPEN' ? '' : `?status=${status}`}`

export const PLATFORM_QUEUE_PATH = '/plateforme/signalements'

/**
 * A team whose moderator is not the author of what gets reported — a moderator never sees reports
 * about their own content (ModerationService#excludedTarget). The owner (team ADMIN) moderates; an
 * ORGANIZER writes the posts; three members report, and a fourth — the bystander — only reads.
 */
export interface ModerationWorld {
  team: TeamDetailDto
  moderator: AuthResponse
  author: AuthResponse
  reporters: [AuthResponse, AuthResponse, AuthResponse]
  bystander: AuthResponse
}

export async function moderationWorld(label: string): Promise<ModerationWorld> {
  const [moderator, author, r1, r2, r3, bystander] = await Promise.all([
    newUser(unique('Modératrice')),
    newUser(unique('Autrice')),
    newUser(unique('Signaleuse Un')),
    newUser(unique('Signaleuse Deux')),
    newUser(unique('Signaleuse Trois')),
    newUser(unique('Témoin')),
  ])
  const team = await newTeam(moderator, unique(label), { addMemberAllowed: true })
  await addMember(moderator, team.slug, author, 'ORGANIZER')
  for (const member of [r1, r2, r3, bystander]) await addMember(moderator, team.slug, member)
  return { team, moderator, author, reporters: [r1, r2, r3], bystander }
}

/**
 * The card of the queue item whose content is `name`. Cards carry no role of their own: a Mantine
 * Paper holding the content's name — unique per test, so the domain-wide platform queue, which
 * every parallel test feeds, still yields one card.
 */
export const queueCard = (page: Page, name: string) =>
  page.getByRole('main').locator('.mantine-Paper-root').filter({ hasText: name })

/** Switches a queue between « À traiter » and « Traités » (a SegmentedControl: radio inputs). */
export async function queueTab(page: Page, label: 'À traiter' | 'Traités') {
  const tab = page.getByRole('main').getByText(label, { exact: true })
  await hydrated(tab)
  await tab.click()
}

/**
 * The innermost block holding both `text` and a « Plus d'actions » button: a comment's own row,
 * not the post header's menu that also sits in `scope`.
 */
export const commentRow = (scope: Locator, text: string) =>
  scope
    .locator('div')
    .filter({ has: scope.page().getByText(text, { exact: true }) })
    .filter({ has: scope.page().getByRole('button', { name: "Plus d'actions" }) })
    .last()

/**
 * Opens the profile the way a member does — the account menu on desktop, the burger's drawer on a
 * phone — so the app is not reloaded and its query cache survives.
 */
export async function openProfileInApp(page: Page, displayName: string) {
  const banner = page.getByRole('banner')
  if (test.info().project.use.isMobile) {
    const burger = banner.getByRole('button', { name: 'Ouvrir le menu' })
    await hydrated(burger)
    await burger.click()
    const link = page.getByRole('navigation').getByRole('link', { name: displayName })
    await hydrated(link)
    await link.click()
  } else {
    const account = banner.getByRole('button', { name: displayName })
    await hydrated(account)
    await account.click()
    await page.getByRole('menuitem', { name: 'Profil' }).click()
  }
  await expect(page).toHaveURL(/\/profil$/)
}

/**
 * From the profile's overview to « Personnes bloquées », link by link — « Confidentialité », then
 * its row — so the app is not reloaded. Two client-side steps on top of {@link openProfileInApp}.
 */
export async function openBlockedUsersInApp(page: Page, displayName: string) {
  await openProfileInApp(page, displayName)
  const main = page.getByRole('main')
  // The sidebar's link on a desktop, the overview's row on a phone (named with its state line).
  const privacy = main.getByRole('link', { name: /^Confidentialité/ }).first()
  await hydrated(privacy)
  await privacy.click()
  await expect(page).toHaveURL(/\/profil\/vie-privee$/)
  const blocked = main.getByRole('link', { name: /^Personnes bloquées/ })
  await hydrated(blocked)
  await blocked.click()
  await expect(page).toHaveURL(/\/profil\/vie-privee\/bloques$/)
}

/**
 * Marks the current document; `stillSameDocument` then tells whether the page was reloaded since
 * (a full navigation starts a new window object, which drops the mark).
 */
export async function markDocument(page: Page) {
  await page.evaluate(() => {
    ;(window as unknown as { __e2eSameDocument: boolean }).__e2eSameDocument = true
  })
  return () =>
    page.evaluate(
      () => (window as unknown as { __e2eSameDocument?: boolean }).__e2eSameDocument === true
    )
}

/**
 * Moves the app to `path` the way one of its own links does — a history entry and a popstate the
 * router follows — without reloading the document, so the query cache (3 min staleTime) survives.
 * For a screen with no link to the next one; `page.goBack()` then returns in-app too.
 */
export async function navigateInApp(page: Page, path: string) {
  await page.evaluate((to) => {
    window.history.pushState(null, '', to)
    window.dispatchEvent(new PopStateEvent('popstate', { state: null }))
  }, path)
  await expect(page).toHaveURL(new RegExp(`${escapeRegExp(path)}$`))
}
