---
id: MOB-31
title: "Calendrier"
status: done
group: "Couverture e2e Patrol"
done: 2026-09-29
---

## Livré

`MOB-31` **Calendrier** (29 septembre 2026) — l'onglet Calendrier d'un membre de deux équipes montre les sorties des deux, jamais la sortie publique d'une équipe publique dont il n'est pas ; chaque carte nomme son équipe, « Inscrit · Groupe A » sur la seule sortie rejointe ; un événement ouvre sa sortie. La section Calendrier de l'équipe ne montre que cette équipe ; « Copier le lien » met au presse-papiers l'URL du flux d'équipe (`teamFeedUrlTemplate`, slug inséré, chemin `/api/teams/{slug}/calendar/ics`), « Régénérer le lien » change le jeton (vérifié par l'API) et la copie suivante donne la nouvelle URL — `calendar_test.dart`. *Non couvert : « S'abonner » (`webcal://`, rien pour le recevoir sur le simulateur), le contenu du flux ICS lui-même (déjà couvert côté web), les étapes de voyage et les filtres de type du calendrier.*
