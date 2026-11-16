---
id: WEB-53
title: "Le crawl SSR manuel retiré, `routes-render` sur des données de vraie équipe"
status: done
group: "Outillage"
done: 2026-10-04
---

## Livré

`WEB-53` **Le crawl SSR manuel retiré, `routes-render` sur des données de vraie équipe**
(2026-10-04) — `scripts/ssr-audit.mjs`, `scripts/routes-ssr.yml` et les scripts `pnpm ssr-audit*`
sont supprimés : `routes-render.e2e.ts` (`WEB-52`) les remplace, chaque nuit, sans comptes réels.
La seule chose que le crawl voyait encore, des requêtes qui ne partent que si la donnée existe,
est couverte en enrichissant `buildDataset()` (`e2e/support/routes-render.ts`) : équipe avec logo,
description illustrée et position ; un lieu ; un tag par type ; deux parcours ; une sortie avec son
parcours, ses lieux de départ et d'arrivée, deux groupes (l'un avec parcours et meneur) et un
inscrit ; un voyage à deux étapes avec parcours (et lieux sur la première) et un inscrit ; une
publication et une page d'équipe illustrées ; une annonce avec photo et position ; un modèle à deux
groupes ; un commentaire sur chaque contenu commentable. Trou révélé et fermé : le parcours propre
de la sortie, lu par l'aperçu de `RideEditor` (`rideFormRouteSlug`, `rideFormData.ts`) ; le même
aperçu dans `TripEditor` est préchargé par symétrie (`tripFormRouteSlug`, `tripFormData.ts`) mais
**n'est couvert par aucun test permanent** : un voyage avec parcours propre n'affiche plus sur sa
carte ceux des étapes, et le jeu de données garde la branche des étapes (vérifié une fois à la
main, 18/18). `frontend/docs/SSR-BUGS.md` est dissous : son défaut ouvert accepté devient `WEB-54`
(« Délibérément dehors »), ses leçons encore vraies la section « Reading a prefetch gap » de
`frontend/docs/SSR-data-loading.md`, et `frontend/e2e/README.md` décrit le contrôle (image à
reconstruire après le passage de l'audit à `true`, filtre d'une route, date d'un vert).
Le fichier de mots de passe des comptes du crawl, `scripts/.env.users`, est supprimé des checkouts
avec sa ligne de `.gitignore`. Tests : `routes-render.e2e.ts` 898/898 (desktop et mobile) après la dernière reconstruction
de l'image ; `pnpm typecheck`, `pnpm lint`, `pnpm e2e:typecheck`, `npx vitest run` (217) passent.
À ne pas défaire : **`routes-render` n'échoue pas sur une `console.error`** quelconque, seulement
sur `[hydration]` (décidé le 2026-10-04 : le bruit qu'ajouterait le reste n'est pas mesuré) ; un
écran qui se met à lire un nouveau champ donne ce champ au jeu de données plutôt que de laisser
sa requête hors audit ; pas de second outil d'audit SSR à maintenir à côté de la suite e2e.
