---
id: SEC-19
title: "Le markdown d'un contenu est borné à 100 000 caractères"
status: done
done: 2026-09-30
---

## Livré

`SEC-19` **Le markdown d'un contenu est borné à 100 000 caractères** (2026-09-30, audit M6,
API 6.3.0, mineur : `maxLength` ajouté) — `MediaDto.markdown` (publications, sorties,
parcours, voyages et étapes, pages, annonces, équipes) et `RideTemplateRequest.markdown` portent
`@Size(max = MediaDto.MAX_MARKDOWN_LENGTH)` ; au-delà, `400 VALIDATION` sur le champ `markdown`.
Seul le corps de requête (100 Mo) bornait jusque-là ce que le filtre de publication et la lecture
des directives parcouraient : l'expression de `SEC-10` est linéaire, cette borne est la défense de
fond. Les réponses ne sont pas validées (ni côté serveur ni par les schémas zod du web, qui ne
servent qu'aux formulaires) : un contenu plus long déjà en base reste lisible, il ne se
réenregistre qu'une fois raccourci. Mesuré sur la base locale (restauration biketeam) : 4 342
caractères au plus — **à revérifier en production avant de déployer**
(`select max(length(markdown)) from team_entities` et `ride_templates`). Ne pas relever la borne
sans raison : elle est partagée par les deux champs via la constante. Tests :
`PostResourceTest.createPost_markdownPastTheBound_shouldReturn400` (la borne passe, un caractère
de plus est refusé) et `RideTemplateResourceTest.createTemplate_markdownPastTheBound_shouldReturn400`
— **écrits sans avoir été lancés**.
