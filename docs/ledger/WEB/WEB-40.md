---
id: WEB-40
title: "Tags d'équipe côté site"
status: done
group: "Tags d'équipe"
done: 2026-10-01
---

## Livré

`WEB-40` **Tags d'équipe côté site** (1er octobre 2026, API 10.1.0, plan archivé
[`2026-10-01-tags.md`](../../plans/archive/2026-10-01-tags.md) §5) — affichage, filtre, étiquetage et
admin du vocabulaire (D20).
- **Affichage** : `components/tag/TagList` (`TagChip` : pastille `TagDot` de la famille et libellé
  neutre, D10), en carte (3 tags, puis « +n » seulement si au moins deux seraient cachés — même
  règle que `PdlTagRow`) et en fiche (tous) ; rendu en SSR, visible des anonymes (D19).
- **Filtre** : `TagFilter`, synchronisé avec `?tags=<id>,<id>` (`tagIdsField`, D18), sur les
  listes d'équipe dédiées — publications restreintes à un type, parcours, annonces ; masqué quand
  l'équipe n'a aucun tag du type et sur le fil mixte (D13), où un `?tags=` d'URL n'est ni envoyé
  ni compté comme filtre actif (`PublicationListPage.hasNonSearchFilters`).
- **Étiquetage** : `TagPicker` dans les formulaires des cinq types et du modèle de sortie, parmi
  les tags existants seulement (D4) ; sans tag du type, un renvoi vers l'admin pour un admin. Un
  id que le vocabulaire chargé n'a plus est **retiré de la valeur du formulaire**, pas seulement
  masqué. La création d'une sortie depuis un modèle pré-remplit `tagIds` depuis
  `RideTemplateDto.tags` : c'est **la** copie D14, l'API n'en a pas d'autre. Les boutons de statut
  des fiches sortie et voyage passent par `rideStatusRequest`/`tripStatusRequest`, qui
  n'envoient pas `tagIds` (« inchangé » côté API).
- **Admin** : `pages/team/TeamTagsPage` (`/equipes/{slug}/admin/tags`, route `teamAdminTags`), un
  onglet par type, `TagFormModal` (libellé ≤ 32 après trim, 9 couleurs), suppression avec
  confirmation qui annonce le nombre de contenus détachés (D11) ; renommer, recolorer ou
  supprimer invalide aussi les contenus en cache (`lib/tagCacheInvalidation.ts`).

Tests : `TagList.test.tsx`, `TagPicker.test.tsx`, `hooks/filters/tagFilters.test.ts` (vitest
vert, 182 tests) ; e2e `tags.e2e.ts` « an admin creates a tag, a member puts it on an ad, the
list filtered by URL finds it » (plan §8). **À ne pas défaire** : aucun formulaire de contenu ne
crée de tag ; ne pas renvoyer depuis le cache des tags que le vocabulaire n'a plus (l'API refuse
la requête entière en `TAG_INVALID`) ; pas de filtre par tag hors d'une liste d'équipe d'un seul
type (D7, D13).
