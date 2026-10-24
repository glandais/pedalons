import type { Locator, Page } from '@playwright/test'
import { setContactable } from './support/ad-contact'
import { newTeam, newUser, signIn } from './support/data'
import { expect, test, unique } from './support/fixtures'
import { hydrated, startsWith } from './support/ui'

/**
 * The profile's tree (contracts/routes.yaml, « profile's sub-pages »; ProfileShell.tsx,
 * profileNav.ts): `/profil` is an overview — who is signed in, the teams (on a desktop), and one
 * shortcut per subject with its state line — and each subject is a page of its own.
 *
 * A desktop has the grouped sidebar, its current entry marked `aria-current`; a phone has the
 * overview's grouped list instead, and every page leads back by the breadcrumb (« Profil › … »).
 * There is no « ← Retour » link any more. « Se déconnecter » shows once in the profile: at the
 * foot of the sidebar, or of the phone's list.
 *
 * The two layouts are both in the markup and switched by CSS: `getByRole` only sees the one the
 * viewport shows, which is what each project asserts.
 */

const SIDEBAR = 'Profil'
const BREADCRUMB = "Fil d'Ariane"

const main = (page: Page) => page.getByRole('main')
const sidebar = (page: Page) => page.getByRole('navigation', { name: SIDEBAR })
const breadcrumb = (page: Page) => page.getByRole('navigation', { name: BREADCRUMB })

/** A shortcut of the overview that carries its state line: a desktop's card, or a phone's row. */
const shortcut = (scope: Locator, label: string, status: string) =>
  scope.getByRole('link').filter({ hasText: label }).filter({ hasText: status })

/** The way to a subject from the overview: the sidebar on a desktop, the grouped list on a phone. */
function entry(page: Page, isMobile: boolean, label: string) {
  return isMobile
    ? main(page).getByRole('link', { name: startsWith(label) })
    : sidebar(page).getByRole('link', { name: label, exact: true })
}

async function openOverview(page: Page) {
  await page.goto('/profil')
  await expect(main(page).getByRole('heading', { name: 'Profil', exact: true })).toBeVisible()
}

async function expectPage(page: Page, path: RegExp, heading: string) {
  await expect(page).toHaveURL(path)
  await expect(main(page).getByRole('heading', { name: heading, exact: true })).toBeVisible()
}

async function follow(link: Locator) {
  await hydrated(link)
  await link.click()
}

test('the overview sums up each subject in its state line', async ({ page, context, isMobile }) => {
  const user = await newUser(unique('Vue du profil'))
  const team = await newTeam(user, unique('Équipe du profil'))
  await setContactable(user, false)
  await signIn(context, user)

  await openOverview(page)
  const overview = main(page)

  // Who is signed in.
  await expect(overview.getByText(user.user.displayName, { exact: true }).first()).toBeVisible()
  await expect(overview.getByText(user.user.email, { exact: true })).toBeVisible()

  // One state line per subject, on both layouts.
  for (const [label, status] of [
    ['Préférences', 'Métrique'],
    ['Appareils et services', 'Aucun service ni appareil'],
    ['Connexion et sécurité', "Aucune clé d'accès"],
    ['Confidentialité', 'Non joignable par les membres'],
    ['Aide et à propos', 'Applications, aide, signaler un problème'],
  ])
    await expect(shortcut(overview, label, status), `${label}: ${status}`).toBeVisible()

  if (isMobile) {
    // The grouped list stands in for the sidebar, « Mon compte » at the head of « Réglages ».
    await expect(sidebar(page)).toHaveCount(0)
    for (const group of ['Réglages', 'Sécurité et confidentialité'])
      await expect(
        overview.getByText(group, { exact: true }).filter({ visible: true })
      ).toBeVisible()
    await expect(
      shortcut(overview, 'Mon compte', 'Photo, nom affiché, adresse e-mail')
    ).toBeVisible()
  } else {
    // The sidebar, the overview current; the teams in a card of their own, with the role.
    await expect(
      sidebar(page).getByRole('link', { name: "Vue d'ensemble", exact: true })
    ).toHaveAttribute('aria-current', 'page')
    await expect(shortcut(overview, team.name, 'Administrateur')).toBeVisible()
  }

  // « Se déconnecter », once in the profile whatever the layout.
  await expect(overview.getByRole('button', { name: 'Se déconnecter' })).toHaveCount(1)
})

test('from the overview to a page, and back to it by the breadcrumb', async ({
  page,
  context,
  isMobile,
}) => {
  const user = await newUser(unique('Navigation du profil'))
  await signIn(context, user)
  await openOverview(page)

  await follow(entry(page, isMobile, 'Connexion et sécurité'))
  await expectPage(page, /\/profil\/securite$/, 'Connexion et sécurité')

  // No « ← Retour » link: the breadcrumb is the way back.
  await expect(main(page).getByRole('link', { name: /^(←\s*)?Retour$/ })).toHaveCount(0)
  // The full trail from `sm`, its last two levels below: the same text twice, one of them hidden.
  await expect(
    breadcrumb(page).getByText('Connexion et sécurité', { exact: true }).filter({ visible: true })
  ).toBeVisible()
  if (isMobile) {
    // No sidebar, and no « Se déconnecter » outside the overview's list.
    await expect(sidebar(page)).toHaveCount(0)
    await expect(main(page).getByRole('button', { name: 'Se déconnecter' })).toHaveCount(0)
  } else {
    const current = sidebar(page).locator('[aria-current="page"]')
    await expect(current).toHaveCount(1)
    await expect(current).toHaveText('Connexion et sécurité')
    await expect(main(page).getByRole('button', { name: 'Se déconnecter' })).toHaveCount(1)
  }

  await follow(breadcrumb(page).getByRole('link', { name: 'Profil', exact: true }))
  await expectPage(page, /\/profil$/, 'Profil')
})

test('« Personnes bloquées » sits under « Confidentialité », in the sidebar and the breadcrumb', async ({
  page,
  context,
  isMobile,
}) => {
  const user = await newUser(unique('Bloqués du profil'))
  await signIn(context, user)
  await openOverview(page)

  await follow(entry(page, isMobile, 'Confidentialité'))
  await expectPage(page, /\/profil\/vie-privee$/, 'Confidentialité')
  await follow(main(page).getByRole('link', { name: startsWith('Personnes bloquées') }))
  await expectPage(page, /\/profil\/vie-privee\/bloques$/, 'Personnes bloquées')

  // A page of « Confidentialité »: the sidebar keeps it current.
  if (!isMobile)
    await expect(
      sidebar(page).getByRole('link', { name: 'Confidentialité', exact: true })
    ).toHaveAttribute('aria-current', 'page')

  // Back one level by the breadcrumb (« Confidentialité › Personnes bloquées » on a phone, the
  // whole trail from « Profil » on a desktop).
  await follow(breadcrumb(page).getByRole('link', { name: 'Confidentialité', exact: true }))
  await expectPage(page, /\/profil\/vie-privee$/, 'Confidentialité')
})

test('the notification settings and the inbox lead to each other', async ({ page, context }) => {
  const user = await newUser(unique('Réglages des notifications'))
  await signIn(context, user)

  await page.goto('/profil/notifications')
  await expectPage(page, /\/profil\/notifications$/, 'Notifications')
  await follow(main(page).getByRole('link', { name: 'Ouvrir mes notifications' }))
  await expect(page).toHaveURL(/:\/\/[^/]+\/notifications$/)

  await follow(main(page).getByRole('link', { name: 'Réglages', exact: true }))
  await expectPage(page, /\/profil\/notifications$/, 'Notifications')
})
