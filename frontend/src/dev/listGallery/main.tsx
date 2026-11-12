/**
 * Entry of the list gallery, `dev/lists.html` — an HTML entry that only the Vite dev server serves
 * (`pnpm dev`, then `/dev/lists.html?section=parcours&case=parcours-vide-filtre`). `pnpm build`
 * takes `index.html` (client) and `src/entry-server.tsx` (SSR) as its only inputs and nothing of
 * the app imports this folder, so none of it reaches `dist/`; no route, no sitemap, no
 * `contracts/routes.yaml` entry. Same arrangement as the card gallery (`../cardGallery/main.tsx`).
 */
// First, as in entry-client: Zod must not probe for eval (CSP).
import '@/lib/zodConfig'
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import i18n, { i18nReady } from '@/i18n'
import '@/index.css'
import { GalleryRoot } from '../cardGallery/GalleryRoot'
import { findCase, isOmittedCase } from './cases'
import { ListGallery } from './ListGallery'
import { seedListGallery } from './listContext'

async function start() {
  if (!import.meta.env.DEV) {
    throw new Error('[galerie] outil de développement : servi par `pnpm dev` seulement')
  }
  const search = new URLSearchParams(window.location.search)
  const sectionId = search.get('section')
  const caseId = search.get('case')
  const { entry } = findCase(sectionId, caseId)
  seedListGallery(entry && !isOmittedCase(entry) ? entry : undefined)
  await i18nReady
  if (i18n.language !== 'fr') await i18n.changeLanguage('fr')

  const root = document.getElementById('root')
  if (!root) throw new Error('[galerie] #root introuvable')
  createRoot(root).render(
    <StrictMode>
      <GalleryRoot i18n={i18n}>
        <ListGallery sectionId={sectionId} caseId={caseId} />
      </GalleryRoot>
    </StrictMode>
  )
}

void start()
