---
id: AUD-19
title: "Lien d'évitement"
status: done
done: 2026-09-30
---

## Livré

| ID | Thème | Audit | Gravité | Livré |
|---|---|---|---|---|
| `AUD-19` | Web | F7 | Important | **Lien d'évitement** (2026-09-30) — premier élément focalisable de `Layout.tsx`, libellé `nav.skipToContent` (« Aller au contenu principal » / « Skip to main content »), hors écran jusqu'au focus (`Layout.module.css`, au-dessus de l'en-tête), il cible `<main id="main-content" tabIndex={-1}>`, sans anneau puisqu'il n'est pas un contrôle. Le clic appelle `focus()` sur la cible au lieu de suivre l'ancre : un changement de hash serait lu par React Router comme une navigation POP, et `useScrollRestoration` avec. Garder le lien **premier** dans le DOM, avant l'en-tête. Couvert par `frontend/e2e/smoke.e2e.ts` (« the first Tab reaches the skip link… » : premier Tab sur le lien, Entrée met le focus sur `main`), écrit sans avoir pu être lancé — la pile e2e tourne sur des images. L'anneau de focus lui-même est `WEB-2` |
