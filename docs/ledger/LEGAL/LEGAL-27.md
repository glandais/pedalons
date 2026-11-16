---
id: LEGAL-27
title: "Les étapes de voyage dans l'envoi automatique, dans la politique"
status: done
done: 2026-11-10
---

## Livré

`LEGAL-27` **Les étapes de voyage dans l'envoi automatique, dans la politique** (2026-11-10, contrat `13.4.0` par ailleurs, `API-163`) — depuis `API-162`, l'envoi automatique dépose aussi chez le service GPS le parcours des étapes des voyages où la personne est inscrite, sous un nom fait de la date, du nom du voyage et de celui de l'étape ; la section écrite par `LEGAL-21` ne parlait que des sorties. En parité FR/EN, `privacy/privacy-policy.{fr,en}.md`, trois passages : ce que nous envoyons (l'itinéraire de chaque étape des voyages auxquels vous participez qui part dans les 7 jours, son nom, et « si la sortie ou le voyage est annulé » parmi les cas de retrait), les données transmises aux services GPS (pour une étape, le nom envoyé est fait de la date, du nom du voyage et de celui de l'étape) et la ligne des transferts hors UE. Date d'en-tête : 10 novembre 2026 (la convention : pas de journal des versions, la date en tête fait foi). Pas de test automatisé (texte statique) ; l'app mobile embarque le texte comme asset, il n'y paraît qu'à la build suivante. Formulaires des stores inchangés (l'envoi part du serveur, comme pour `LEGAL-21`). Pas d'e-mail aux membres : l'envoi automatique reste un opt-in. **À ne pas défaire** : la règle de `LEGAL-21` vaut pour les étapes — toute évolution de ce qui part chez un service GPS se relit d'abord contre cette section.
