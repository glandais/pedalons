---
id: OPS-44
title: "Un test automatisé pour « `AdDto` ne porte aucun champ de contact »"
status: done
group: "Recette du backend en conditions réelles"
done: 2026-11-17
---

## Livré

`OPS-44` **« `AdDto` ne porte aucun champ de contact »** — la règle est écrite dans la Javadoc du
record `AdDto` (`backend/src/main/java/fr/pedalons/dto/ads/response/AdDto.java`), là où un champ
serait ajouté : aucun e-mail, téléphone, adresse ni lien pour joindre l'auteur, ni dans `AdDto` ni
dans les records qu'il porte ; un acheteur écrit par `POST …/classifieds/{adSlug}/contact`, relayé par
e-mail (`AdContactEmailService`). Elle reste aussi dans le CLAUDE.md racine (invariant des annonces).
Décidé le 17 novembre 2026 avec le propriétaire : un commentaire plutôt qu'un test automatisé qui
lirait les noms des composants ou le schéma OpenAPI — pas de garde de build, donc ; le `grep` et le
script du §5.3 du [document d'API](../../plans/archive/2026-07-26-api-v2-livraison-et-suites.md)
restent le moyen de le revérifier.
