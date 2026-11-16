---
id: WEB-95
title: "Le chargement initial ne tire plus Tiptap, Chart.js, le calendrier ni l'autre langue"
status: done
group: "Outillage"
done: 2026-10-16
---

## Livré

`WEB-95` **Le chargement initial ne tire plus Tiptap, Chart.js, le calendrier ni l'autre langue**
(2026-10-16, sans changement de contrat) — audit Lighthouse mobile de
`/equipes/n-peloton/sorties/raymond-ride-300` : score 8, LCP 9,9 s, TBT 3 s. Le `manualChunks`
ordonné de `vite.config.ts` ne faisait pas ce qu'il disait : Rolldown fait capter à chaque groupe
les dépendances de ses modules (`includeDependenciesRecursively`, actif par défaut), si bien que
`react` atterrissait dans `chart-vendor` (via `react-chartjs-2`) et `use-sync-external-store` dans
`editor-vendor` (via `@tiptap/react`) ; `react-vendor`, `mantine-vendor`, `router-vendor` et
`i18n-vendor` importaient donc ces deux chunks et `index.html` les préchargeait sur toutes les
pages. Fait : `output.codeSplitting.groups` à priorités (le cœur à 30–40, Mantine à 20, les
fonctionnalités à 10–12, `vendor` à 0) ; l'affichage du markdown (`markdown-vendor`) séparé de
l'éditeur (`editor-vendor`, avec `@mantine/tiptap`) ; `@mantine/schedule` et `rrule` dans
`schedule-vendor`. Le navigateur ne charge plus que le catalogue de sa langue : un backend i18next
(`catalogueBackend`, `src/i18n/index.ts`) importe `locale-<lang>`, les deux catalogues restant
embarqués côté serveur (`createServerI18n`, instance globale derrière `import.meta.env.SSR`) ;
`server.js` lit le manifest Vite (`dist/client/.vite/manifest.json`, jamais servi : 404) et
précharge en `modulepreload` le catalogue de la page puis le français (repli).
Mesuré (build local, gzip) : chargement initial 836 → 406 Ko, plus 40 Ko de catalogue français ;
page sortie complète 876 → ~536 Ko. Lighthouse mobile sur `server.js` local devant l'API de prod,
3 passes chacun : FCP 6,1 → 4,1 s, LCP 6,1–10,7 → 4,2 s, TTI 10,3 → 9,0 s, 1 243 → 1 013 Ko
transférés ; TBT inchangé (`WEB-96`), CLS inchangé (`WEB-97`). Hydratation, langue (fr, en,
bascule à chaud qui charge `locale-en`) et console vérifiées sous Playwright. Test :
`server/cataloguePreload.test.js`. **À ne pas défaire** : un paquet importé par le shell d'une
page (React et ses dépendances directes, Mantine) doit avoir une priorité supérieure à tout
groupe de fonctionnalité, sans quoi il retombe dans celui qui l'atteint en premier ; vérifier la
liste `modulepreload` d'`index.html` après toute retouche des groupes. `entriesAware` sur
Mantine a été essayé et écarté : −14 Ko sur la page sortie pour 18 chunks de plus, aux noms qui
listent les pages (admin comprises) et dont les hashes bougent à chaque page ajoutée.
