import { afterEach, beforeAll, describe, expect, it } from 'vitest'
import { act, cleanup, render } from '@testing-library/react'
import type { i18n as I18nInstance } from 'i18next'
import i18n, { createServerI18n, i18nReady } from '@/i18n'
import { GalleryRoot, seedGalleryContext } from './GalleryRoot'
import { CardGallery, GALLERY_SECTIONS } from './CardGallery'
import { unservedRequests } from './fakeApi'

/**
 * The brief's sections and cases, copied from
 * `docs/plans/2026-11-10-etat-des-lieux-affichage/audit-cartes/galerie.md` (« Sections et cas »),
 * in its order. The app's gallery is built from the same table: a case is mounted, or listed as
 * omitted with its reason — never silently dropped.
 */
const BRIEF: Record<string, string[]> = {
  fil: [
    'fil-sortie',
    'fil-sortie-inscrite',
    'fil-sortie-demain',
    'fil-sortie-en-cours',
    'fil-sortie-terminee',
    'fil-sortie-annulee',
    'fil-sortie-brouillon',
    'fil-sortie-sans-groupe',
    'fil-sortie-alerte-pluie',
    'fil-sortie-meteo-a-venir',
    'fil-sortie-photo',
    'fil-sortie-lien',
    'fil-voyage',
    'fil-voyage-termine',
    'fil-voyage-non-membre',
    'fil-voyage-inscrit-en-cours',
    'fil-voyage-annule',
    'fil-publication',
    'fil-publication-brouillon',
    'fil-supprime',
  ],
  accueil: [
    'prochaine-sortie',
    'prochaine-sortie-sans-maximum',
    'prochaine-sortie-vide',
    'semaine',
    'semaine-vide',
    'mes-equipes',
    'mes-equipes-vide',
  ],
  agenda: ['agenda-sortie', 'agenda-inscrite', 'agenda-annulee', 'agenda-etape', 'agenda-passee'],
  groupes: [
    'groupes-inscrite-b',
    'groupes-non-inscrite',
    'groupe-erreur',
    'groupe-non-membre',
    'groupe-sans-parcours',
    'groupe-sans-meteo',
  ],
  // `etape-lieux`, `commentaire-markdown` and `equipe-decouverte-membre`: the app's cases for R11,
  // R12 and R13, added after the brief; `equipe-sur-invitation`, the R13 board's second case.
  etapes: ['etapes', 'etape-inscrite', 'etape-lieux', 'etape-sans-parcours', 'etape-alerte-pluie'],
  parcours: ['parcours', 'parcours-sans-vignette', 'parcours-supprime', 'parcours-ligne', 'usages'],
  annonces: ['annonce-vente', 'annonce-location', 'annonce-recherche', 'annonce-brouillon'],
  equipes: [
    'equipe',
    'equipe-admin',
    'equipe-decouverte',
    'equipe-decouverte-membre',
    'equipe-sur-invitation',
    'equipe-photo',
    'invitations',
    'membre',
    'membre-admin',
    'inscrits',
  ],
  tableau: [
    'a-traiter',
    'mes-sorties',
    'sortie-a-venir',
    'sortie-a-venir-inscrite',
    'sortie-a-venir-complet',
    'sortie-a-venir-sans-parcours',
    'dernieres-publications',
    'nouveaux-parcours',
    'annonces-tableau',
  ],
  divers: [
    'notification-non-lue',
    'notification-lue',
    'notification-modification',
    'modele',
    'modele-brouillon',
    'appareils',
    'commentaires',
    'commentaire-markdown',
  ],
}

/** Cases the site has no card for, each listed in the gallery with its reason. */
const OMITTED = ['agenda-etape']

/** What a case shows once its data — fixtures, or the fake API — has arrived. */
const CONTENT: Record<string, string> = {
  'fil-sortie': 'Boucle des Monts d’Arrée',
  'fil-publication': 'Bilan de la saison',
  'prochaine-sortie-vide': 'Mes équipes',
  'mes-equipes': 'Gravel Bretagne',
  usages: 'Traversée du Morvan',
  invitations: 'Inès Roche',
  inscrits: 'Malo Guérin',
  modele: 'Sortie du dimanche',
  'modele-brouillon': 'Sortie d’hiver',
  commentaires: 'café avant le départ',
  'commentaire-markdown': 'café **avant le départ** ?',
  'etape-lieux': 'Autun → Château-Chinon',
  'equipe-decouverte': "Rejoindre l'équipe",
  'equipe-sur-invitation': 'Sur invitation',
  'annonce-vente': 'Vélo de route carbone taille M',
}

let frenchI18n: I18nInstance

beforeAll(async () => {
  // `paths` reads the global instance's language; the cards read the provider's.
  await i18nReady
  await i18n.changeLanguage('fr')
  frenchI18n = await createServerI18n('fr')
  seedGalleryContext()
})

afterEach(cleanup)

const settle = () => act(() => new Promise((resolve) => setTimeout(resolve, 50)))

describe('card gallery (WEB-167)', () => {
  it('follows the brief: same sections, same order', () => {
    expect(GALLERY_SECTIONS.map((s) => s.id)).toEqual(Object.keys(BRIEF))
    for (const section of GALLERY_SECTIONS) {
      expect(section.entries.map((e) => e.id)).toEqual(BRIEF[section.id])
    }
  })

  it.each(Object.keys(BRIEF))('mounts section « %s » without a render error', async (id) => {
    unservedRequests.length = 0
    const { container } = render(
      <GalleryRoot i18n={frenchI18n}>
        <CardGallery sectionId={id} />
      </GalleryRoot>
    )
    await settle()
    await settle()

    for (const caseId of BRIEF[id]) {
      const omitted = OMITTED.includes(caseId)
      const node = container.querySelector(
        omitted ? `[data-gallery-omitted="${caseId}"]` : `[data-gallery-case="${caseId}"]`
      )
      expect(node, caseId).not.toBeNull()
      const expected = CONTENT[caseId]
      if (expected) expect(node?.textContent, caseId).toContain(expected)
    }
    expect(container.querySelectorAll('[data-gallery-error]')).toHaveLength(0)
    expect(unservedRequests).toEqual([])
  })

  it('renders the table of contents without a section', () => {
    const { container } = render(
      <GalleryRoot i18n={frenchI18n}>
        <CardGallery />
      </GalleryRoot>
    )
    for (const id of Object.keys(BRIEF)) {
      expect(container.querySelector(`a[href="?section=${id}"]`), id).not.toBeNull()
    }
  })
})
