---
id: AUD-18
title: "Zoom rendu"
status: done
done: 2026-09-30
---

## Livré

| ID | Thème | Audit | Gravité | Livré |
|---|---|---|---|---|
| `AUD-18` | Web | F1 | Critique | **Zoom rendu** (2026-09-30) — `maximum-scale=1.0` retiré du viewport de `frontend/index.html`, seul gabarit HTML du frontend : le SSR (`server.js`) injecte son rendu dans ce même fichier, bâti en `dist/client/index.html`. Ne pas le remettre, ni `user-scalable=no` (WCAG 1.4.4). Conséquence connue et acceptée : iOS Safari zoome sur un champ dont la police fait moins de 16 px, ce qui est le cas des champs Mantine `sm` ; la parade est une taille de police, pas un viewport bloqué. Pas de test : aucune assertion ne lit le viewport ; `pnpm typecheck`, `pnpm lint` et `npx vitest run` passent |
