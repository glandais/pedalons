---
id: WEB-52
title: "Le préchargement SSR vérifié chaque nuit par la suite e2e"
status: done
group: "Outillage"
done: 2026-10-04
---

## Livré

`WEB-52` **Le préchargement SSR vérifié chaque nuit par la suite e2e** (2026-10-04) — l'audit
`[prefetch-audit]` n'était lu que par le crawl `scripts/ssr-audit.mjs`, lancé à la main, pas
relancé depuis le 2026-08-04 : toutes les pages d'un visiteur connecté, et quinze écrans de plus,
avaient pris des trous depuis sans que rien ne le dise. L'image e2e est désormais construite avec `FRONTEND_PREFETCH_AUDIT=true` (`.env.e2e`), et
`routes-render.e2e.ts` exige le verdict `covered` pour chaque écran rendu sur son propre chemin,
pour chacun des six rôles (`watchPrefetchAudit`, `e2e/support/ui.ts`) ; une redirection ou le
repli d'un refus ne sont pas mesurés. Trous fermés : le compteur de la cloche
(`/api/notifications/unread-count`, toutes les pages d'un visiteur connecté, préchargé par
`entry-server.tsx` avec la session, comme `/api/version`) ; le `TagPicker` des douze
formulaires de création et d'édition (`prefetchCreate…Form` / `prefetchEdit…Form` des modules
`pages/*/…FormData.ts`) ; la liste `/notifications` (`prefetchNotificationList`) ; les préférences
de notification et les appareils appairés du profil (`profileData.ts`) ; le webhook des réglages
d'équipe, pour un admin seulement (`prefetchTeamSettings`). Après rebase, la carte de fin de l'accueil membre
(`FeaturesPromoCard`, `WEB-51`) lisait les appareils appairés hors préchargement : ajoutés à
`prefetchHomeFeed`. `routes-render.e2e.ts` reçoit la
route `features`, qui y manquait, et l'accueil anonyme y attend désormais la présentation visiteur (`seesAs`) : sur
`develop`, `home` échouait en anonyme depuis le nouvel accueil. `ads-browse.e2e.ts` (« the exact
point of an ad… ») ouvre l'annonce depuis la liste : ouvertes par leur URL, les deux pages ne
lisent plus rien après hydratation, et son contrôle « au moins une réponse API » tombait à vide.
Tests : `routes-render.e2e.ts` 898/898 (desktop et mobile) ; suite complète avec l'audit actif,
1 628 réussis, 4 échecs, dont 2 `ads-browse` corrigés depuis (repassés) et 2
`gpx-planner.e2e.ts`, faute de Valhalla et de tileserver sur le poste (exclu en CI,
`E2E_NO_ROUTING`) ; `pnpm typecheck`, `pnpm lint`, `npx vitest run` passent. À ne pas défaire : l'audit actif dans l'image
e2e (son seul autre effet : pas de préchargement au survol pendant les 5 premières secondes d'une
page) ; un écran nouveau ou modifié qui lit une requête au premier affichage la précharge dans son
module de données, il ne s'exempte pas du test.
