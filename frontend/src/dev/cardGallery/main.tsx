/**
 * Entry of the card gallery, `dev/cards.html` — a second HTML entry that only the Vite dev server
 * serves (`pnpm dev`, then `/dev/cards.html?section=fil`). `pnpm build` takes `index.html` (client)
 * and `src/entry-server.tsx` (SSR) as its only inputs and nothing of the app imports this folder,
 * so none of it reaches `dist/`; no route, no sitemap, no `contracts/routes.yaml` entry.
 */
// First, as in entry-client: Zod must not probe for eval (CSP).
import '@/lib/zodConfig'
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import i18n, { i18nReady } from '@/i18n'
import '@/index.css'
import { GalleryRoot, seedGalleryContext } from './GalleryRoot'
import { CardGallery } from './CardGallery'

async function start() {
  if (!import.meta.env.DEV) {
    throw new Error('[galerie] outil de développement : servi par `pnpm dev` seulement')
  }
  seedGalleryContext()
  await i18nReady
  if (i18n.language !== 'fr') await i18n.changeLanguage('fr')

  const root = document.getElementById('root')
  if (!root) throw new Error('[galerie] #root introuvable')
  const sectionId = new URLSearchParams(window.location.search).get('section')
  createRoot(root).render(
    <StrictMode>
      <GalleryRoot i18n={i18n}>
        <CardGallery sectionId={sectionId} />
      </GalleryRoot>
    </StrictMode>
  )
}

void start()
