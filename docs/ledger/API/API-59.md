---
id: API-59
title: "Tags d'équipe sur les cinq types de contenu"
status: done
group: "Vie privée : les métadonnées retirées à l'import"
done: 2026-10-01
---

## Livré

`API-59` **Tags d'équipe sur les cinq types de contenu** (2026-10-01, **API 10.1.0**, mineure,
migration `V55__tags.sql`, tables nouvelles seulement ; plan archivé
[`2026-10-01-tags.md`](../../plans/archive/2026-10-01-tags.md), décisions D1 à D23) —
- **Modèle** : `Tag` (`BaseEntity`, pas `TeamEntity` : pas de corbeille, D11) — équipe, `type`
  (`TagTarget` : `RIDE`, `POST`, `TRIP`, `ROUTE`, `AD`, D3), libellé, `color` (`TagColor`, les 9
  familles de `brand-colors.yaml`, D10) ; index unique `uk_tags_team_type_label` sur
  `(team_id, type, lower(label))` (D17). Liaisons `team_entity_tags` (les cinq types, tous dans
  `team_entities`) et `ride_template_tags` (D14), en cascade des deux côtés.
- **Vocabulaire** : `GET /api/teams/{teamSlug}/tags?type=` (qui voit l'équipe ; trié par libellé,
  `usageCount` par tag en une requête), `POST`, `PATCH /{tagId}` (libellé, couleur ; jamais le
  type), `DELETE /{tagId}` → `TagDeletedDto.detachedCount` — admins seulement (`TagAccessChecker`,
  D4, D12). Bornes vérifiées par `TagService` (D16) : libellé non vide et ≤ 32 caractères
  **après trim**, comptés en points de code comme le `varchar(32)` (`TAG_LABEL_INVALID` ; le
  `@Size(max = 255)` des requêtes n'est qu'un plafond brut), ≤ 100 tags par équipe et type
  (`TAG_LIMIT_REACHED`), unicité insensible à la casse (409 `TAG_LABEL_TAKEN`, y compris quand
  deux admins écrivent le même libellé au même instant : le `flush` dans `createTag`/`updateTag`
  fait remonter l'index en 409 et non en 500 à la validation).
- **Étiquetage** : `tagIds` sur les requêtes des cinq types et de `RideTemplateRequest` —
  `null`/absent laisse les tags tels quels (un client plus ancien ne les efface pas), `[]` les
  retire ; ≤ 10 (`TOO_MANY_TAGS`), tous de l'équipe et du type du contenu (`TAG_INVALID`). Droits
  = ceux d'édition du contenu, sans cas particulier (D5). `tags: TagDto[]` (`id`, `label`,
  `color`, triés par libellé) sur la liste et le détail de chaque type, et sur `RideTemplateDto`.
- **Filtre** : `?tags=<id>,<id>` (ou répété) en OU par `EXISTS` (`TagFilter.andTaggedWithAny`,
  pas de doublon, compte cohérent) sur `/api/teams/{t}/publications` **avec un `type`**, `/routes`
  (+ `count`, `bounds`, tuiles) et `/classifieds` (+ `count`) ; les ids inconnus, d'une autre équipe ou d'un autre
  type sont ignorés et un filtre sans id connu ne filtre rien (D18). Absent des listes
  multi-équipes et ignoré par le fil mixte (D7, D13).
- **Par page** : `TagLookup` résout les tags d'une page de liste (et d'un voyage avec les parcours
  de ses étapes) en une requête ; les constructeurs de lignes (`RideDto`/`TripDto.fromListItem`,
  `PublicationDto.from`, `TripStageDto.from`) n'ont plus de surcharge sans `ContentTags`, pour
  qu'un appelant de liste ne puisse pas rendre `tags: []` par oubli.
- **Migration biketeam** : voir `MIG-14`.

Tests (verts le 1er octobre 2026, suite backend complète comprise) :
`TagResourceTest` (droits admin, bornes après trim, unicité par casse, détachement à la
suppression), `ContentTaggingTest` (droits d'édition, type et équipe du tag, > 10, `tagIds`
absent vs `[]`, `aTemplatesTags_areAnswered_andARideCreatedWithThem_carriesThem` pour D14),
`TagFilterTest` (OU sans doublon, ids inconnus, fil mixte, listes multi-équipes),
`TagLookupQueryCountTest`. La course de deux créations simultanées n'est pas testable : les tests
construisent le schéma depuis les entités, sans l'index sur `lower(label)`. **À ne pas défaire** :
la copie modèle → sortie (D14) est celle du client — pas de « création depuis un modèle » côté
API ; le fil mixte ignore `?tags=` ; un id inconnu ne filtre rien plutôt que de vider la liste ;
un changement de tags ne notifie pas (D23 : ne pas l'ajouter à `RIDE_UPDATED`) ; les tags d'une
page se résolvent par page, jamais par ligne.
