import { afterEach, beforeAll, describe, expect, it } from 'vitest'
import { act, cleanup, fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import { notifications } from '@mantine/notifications'
import type { i18n as I18nInstance } from 'i18next'
import i18n, { createServerI18n, i18nReady } from '@/i18n'
import { GalleryRoot } from '../cardGallery/GalleryRoot'
import { LIST_SECTIONS, findCase, isOmittedCase, type ClickStep, type ListCase } from './cases'
import { ListGallery } from './ListGallery'
import { seedListGallery } from './listContext'
import { unservedRequests } from './listFakeApi'

/**
 * The brief's sections and cases, copied from
 * `docs/plans/2026-11-10-etat-des-lieux-affichage/audit-listes/galerie.md` (« Cas, par liste »),
 * in its order. The app's gallery is built from the same table: a case is mounted, or listed as
 * omitted with its reason — never silently dropped.
 */
const BRIEF: Record<string, string[]> = {
  accueil: [
    'accueil-repos',
    'accueil-filtre',
    'accueil-criteres',
    'accueil-vide',
    'accueil-vide-filtre',
    'accueil-erreur',
    'accueil-chargement',
  ],
  publications: [
    'publications-repos',
    'publications-filtre',
    'publications-vide',
    'publications-vide-filtre',
    'publications-erreur',
    'publications-lecture',
  ],
  agenda: [
    'agenda-repos',
    'agenda-filtre',
    'agenda-criteres',
    'agenda-passees',
    'agenda-vide',
    'agenda-vide-filtre',
    'agenda-erreur',
    'agenda-lecture',
  ],
  calendrier: [
    'calendrier-repos',
    'calendrier-filtre',
    'calendrier-equipe',
    'calendrier-vide',
    'calendrier-vide-filtre',
    'calendrier-erreur',
    'calendrier-chargement',
  ],
  parcours: [
    'parcours-repos',
    'parcours-lignes',
    'parcours-carte',
    'parcours-filtre',
    'parcours-criteres',
    'parcours-tri',
    'parcours-vide',
    'parcours-vide-filtre',
    'parcours-erreur',
    'parcours-lecture',
  ],
  explorer: [
    'explorer-repos',
    'explorer-filtre',
    'explorer-criteres',
    'explorer-vide-filtre',
    'explorer-erreur',
  ],
  annonces: [
    'annonces-repos',
    'annonces-filtre',
    'annonces-criteres',
    'annonces-tri',
    'annonces-vide',
    'annonces-vide-filtre',
    'annonces-erreur',
  ],
  equipes: [
    'equipes-repos',
    'equipes-decouvrir',
    'equipes-filtre',
    'equipes-vide',
    'equipes-vide-filtre',
    'equipes-erreur',
  ],
  membres: ['membres-repos', 'membres-filtre', 'membres-vide-filtre', 'membres-erreur'],
  inscrits: [
    'inscrits-repos',
    'inscrits-filtre',
    'inscrits-vide',
    'inscrits-vide-filtre',
    'inscrits-erreur',
  ],
  notifications: [
    'notifications-repos',
    'notifications-filtre',
    'notifications-vide',
    'notifications-vide-filtre',
    'notifications-erreur',
  ],
  modeles: [
    'modeles-repos',
    'modeles-filtre',
    'modeles-vide',
    'modeles-vide-filtre',
    'modeles-erreur',
  ],
}

/** Cases of the brief the site cannot show, each listed in the gallery with its reason. */
const OMITTED: string[] = []

/** What a case shows once its answers have arrived: proof the state is the announced one. */
const CONTENT: Record<string, string> = {
  'accueil-repos': 'Bilan de la saison',
  'accueil-filtre': 'Gravel du Menez-Hom',
  'accueil-vide-filtre': 'Rien ne correspond à : « monts » · Voyages.',
  'publications-repos': 'Assemblée générale de décembre',
  'publications-filtre': 'Les photos des Monts d’Arrée',
  'agenda-repos': 'Traversée du Morvan',
  'agenda-passees': 'Tour du lac du Drennec',
  'agenda-vide-filtre': 'Aucun voyage pour ces filtres',
  'publications-vide-filtre': 'Rien ne correspond à : « monts ».',
  'calendrier-repos': 'Sortie récupération',
  'calendrier-equipe': 'Vélo Club des Monts',
  'calendrier-vide': 'Aller au prochain mois avec une sortie',
  'calendrier-vide-filtre': 'Aucun événement pour ces filtres',
  'parcours-vide-filtre': 'Aucun parcours pour ces filtres',
  'explorer-vide-filtre': 'Aucun parcours pour ces filtres',
  'annonces-vide-filtre': 'Aucune annonce pour ces filtres',
  'equipes-vide-filtre': 'Aucune équipe pour ces filtres',
  'membres-vide-filtre': 'Aucun membre pour ces filtres',
  'inscrits-vide-filtre': 'Aucune personne pour ces filtres',
  'notifications-vide-filtre': 'Aucune notification pour ces filtres',
  'modeles-vide-filtre': 'Aucun modèle pour ces filtres',
  'parcours-repos': 'Boucle des Monts d’Arrée — groupe C',
  'parcours-lignes': 'Boucle des Monts d’Arrée — groupe B',
  'explorer-repos': 'Gravel du Menez-Hom',
  'annonces-repos': 'Remorque enfant',
  'equipes-repos': 'triées par nom',
  'equipes-decouvrir': 'triées par nombre de membres',
  'membres-repos': 'Karim Benali',
  'inscrits-repos': 'Malo Guérin',
  'inscrits-filtre': 'Léa Martin',
  'notifications-repos': 'Sortie récupération',
  'modeles-repos': 'Gravel du samedi',
  'modeles-filtre': 'Sortie du dimanche',
}

let frenchI18n: I18nInstance

beforeAll(async () => {
  // `paths` reads the global instance's language; the pages read the provider's.
  await i18nReady
  await i18n.changeLanguage('fr')
  frenchI18n = await createServerI18n('fr')
  // jsdom has no layout: Mantine's open dropdowns scroll their selected option into view.
  Element.prototype.scrollIntoView ??= () => {}
})

afterEach(cleanup)

const settle = () => act(() => new Promise((resolve) => setTimeout(resolve, 60)))

function clickTarget(container: HTMLElement, step: ClickStep): HTMLElement {
  const scope = within(container)
  if ('placeholder' in step) return scope.getAllByPlaceholderText(step.placeholder)[0]
  return scope.getAllByRole(step.role, { name: step.name })[0]
}

const cases = LIST_SECTIONS.flatMap((section) =>
  section.entries.map((entry) => [section.id, entry.id] as const)
)

describe('list gallery', () => {
  it('follows the brief: same sections, same cases, same order', () => {
    expect(LIST_SECTIONS.map((s) => s.id)).toEqual(Object.keys(BRIEF))
    for (const section of LIST_SECTIONS) {
      expect(section.entries.map((e) => e.id)).toEqual(BRIEF[section.id])
      for (const entry of section.entries) {
        expect(isOmittedCase(entry), entry.id).toBe(OMITTED.includes(entry.id))
      }
    }
  })

  it.each(cases)('mounts %s / %s', { timeout: 30_000 }, async (sectionId, caseId) => {
    const { entry } = findCase(sectionId, caseId)
    seedListGallery(entry && !isOmittedCase(entry) ? entry : undefined)
    unservedRequests.length = 0
    notifications.clean()
    const { container } = render(
      <GalleryRoot i18n={frenchI18n}>
        <ListGallery sectionId={sectionId} caseId={caseId} />
      </GalleryRoot>
    )
    // The page's chunk, then its answers.
    await waitFor(
      () =>
        expect(
          container.querySelector('[data-gallery-case] main, [data-gallery-omitted]')
        ).not.toBeNull(),
      { timeout: 15_000 }
    )
    for (let i = 0; i < 6; i++) await settle()

    if (OMITTED.includes(caseId)) {
      expect(container.querySelector(`[data-gallery-omitted="${caseId}"]`)).not.toBeNull()
      return
    }
    const node = container.querySelector<HTMLElement>(`[data-gallery-case="${caseId}"]`)
    expect(node, caseId).not.toBeNull()
    // The page itself, not the router's or a route's error screen.
    expect(node!.querySelector('main'), caseId).not.toBeNull()
    expect(node!.textContent).not.toContain('Une erreur est survenue')
    const expected = CONTENT[caseId]
    if (expected) expect(node!.textContent, caseId).toContain(expected)
    if (caseId.endsWith('-erreur')) {
      expect(node!.textContent).toContain('Chargement impossible')
      // The block says it once: no toast over it (RL11).
      expect(document.body.textContent).not.toContain('Erreur interne du serveur')
    }
    for (const step of (entry as ListCase).clicks ?? []) {
      fireEvent.click(clickTarget(node!, step))
      await settle()
    }
    if ((entry as ListCase).scrollTo) {
      expect(node!.querySelector((entry as ListCase).scrollTo!), caseId).not.toBeNull()
    }
    expect(unservedRequests).toEqual([])
  })

  it('lists every case in its table of contents', () => {
    seedListGallery()
    render(
      <GalleryRoot i18n={frenchI18n}>
        <ListGallery />
      </GalleryRoot>
    )
    for (const [sectionId, caseId] of cases) {
      if (OMITTED.includes(caseId)) continue
      const link = screen.getByText(caseId)
      expect(link.getAttribute('href')).toBe(`?section=${sectionId}&case=${caseId}`)
    }
  })
})
