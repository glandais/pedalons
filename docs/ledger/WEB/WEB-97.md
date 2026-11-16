---
id: WEB-97
title: "Les images réservent leur place, chargent à la demande et à la bonne taille"
status: done
group: "Outillage"
done: 2026-10-16
---

## Livré

`WEB-97` **Les images réservent leur place, chargent à la demande et à la bonne taille**
(2026-10-16, sans changement de contrat) — CLS 0,57 sur la page sortie mobile : l'image
`…/448` d'un média (`AssetImage`, via `MediaDisplay` → `MarkdownDisplay`) n'avait pas de
hauteur avant son chargement, et le loader qu'elle remplaçait n'avait pas la sienne. Un audit des
images de `src/` a relevé le même défaut sur `RouteCard`, aucun `loading` explicite hors
`CardImage`, aucun `srcSet` et aucune priorité sur l'image LCP. Fait :
- `AssetImage` lit `AssetDto.imageDimensions`, déjà au contrat : `aspect-ratio`, largeur
  `min(naturelle, taille)` et `max-width: 100%`, fond neutre pendant le chargement, plus de loader
  — qui reste quand les dimensions manquent (fichier pas encore rattrapé par le backfill) ;
- `RouteCard` : miniature carrée en `aspect-ratio: 1 / 1`, rien quand le parcours n'en a pas ;
- `loading="lazy"` sur les miniatures de parcours (`RouteThumbnail`, `RoutePickerModal`), les
  vignettes d'`AdGallery`, les images du markdown et `AssetImage` ;
- `fetchPriority="high"` + `eager` sur l'image principale d'`AdGallery` et, par la prop
  `priority` de `CardImage`/`PublicationCard`, sur `NextRideCard` et la première carte de
  `TeamPostsPage` et `MyRidesPage` ; jamais sur le fil de l'accueil anonyme, sous le bandeau ;
- `srcSet` tirés des gabarits `{size}` (`lib/imageSrcSet.ts`) : largeurs + `sizes` pour les
  cartes, l'image principale d'annonce et `AssetImage` en `full` (qui demandait 1920 px à un
  téléphone), 1x/2x pour les petites tailles. Le format n'avait pas à changer : imgproxy négocie
  déjà WebP/AVIF (`IMGPROXY_AUTO_*`).
Vérifié dans Chrome sur `pnpm dev` devant l'API de prod : une image neuve de « Raymond Ride #300 »
réserve 448×593 avant chargement, une `RouteCard` 365×365 (0 px avant), la LCP de
`/teams/n-peloton/posts` est la première carte, désormais prioritaire ; carte de 365 px servie
en 480. `AdGallery`, `NextRideCard` et `MyRidesPage` non vus en navigateur (connexion requise).
Tests : `AdGallery.test.tsx`, `AssetImage.test.tsx`. **À ne pas défaire** : `CARD_GRID_SIZES`
suit le `Container size="lg"` (1140 px) de `Layout` — à revoir si la grille ou le conteneur
change, sinon le navigateur prend une variante trop grande ; `priority` seulement pour une
image visible au premier écran, sans quoi elle retarde le reste.
