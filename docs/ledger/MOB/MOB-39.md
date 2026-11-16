---
id: MOB-39
title: "Tags d'équipe dans l'application"
status: done
group: "Tags d'équipe"
done: 2026-10-01
---

## Livré

`MOB-39` **Tags d'équipe dans l'application** (1er octobre 2026, API 10.1.0, plan archivé
[`2026-10-01-tags.md`](../../plans/archive/2026-10-01-tags.md) §6) — affichage et filtre, ni
étiquetage ni admin (D20). Les tags d'un contenu sont rendus par `PdlTagRow` (`core/pdl/pdl_tag.dart`)
via `ContentTagRow` (`features/tags/presentation/content_tags.dart`) : en carte (sortie, post,
voyage du fil d'équipe, parcours, annonce) les `kCardTagLimit` = 3 premiers puis « +n », en fiche
tous. Filtre par tag (`tag_filter.dart`, feuille multi-sélection, OU) sur les listes d'équipe
dédiées : sorties, posts et voyages (le fil restreint à un type), parcours (`route_filter_chips_bar`),
annonces (`ads_toolbar`) ; pas de chip quand l'équipe n'a aucun tag du type, ni sur le fil mixte
(D13). Tests : `pdl_tag_test.dart`, `tag_filter_test.dart`, `team_list_tag_filter_test.dart` —
`flutter test` vert (724 tests). **À ne pas défaire** : un tag est une **pastille** de la famille
et un libellé neutre, jamais un `PdlBadge` (D10, un tag vert ne doit pas se lire « Publié ») ; la
troncature est la même que sur le web — « +n » seulement quand au moins **deux** tags seraient
cachés (4 tags pour une limite de 3 : les 4 montrés), pour qu'un contenu ait la même carte partout.
