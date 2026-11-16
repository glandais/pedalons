---
id: MOB-33
title: "Signalement au-delà des publications et commentaires, suppression par un modérateur"
status: done
group: "Couverture e2e Patrol"
done: 2026-09-29
---

## Livré

`MOB-33` **Signalement au-delà des publications et commentaires, suppression par un modérateur** (29 septembre 2026) — un membre signale une sortie, un voyage, un parcours et une annonce depuis leur `⋯` (`showDetailModerationMenu`) : chaque page se ferme derrière le signalement et l'administrateur de l'équipe trouve chacun dans la file ouverte (`/api/teams/{slug}/reports`) — `report_details_test.dart` ; il signale un coéquipier depuis la section « Membres » (le menu propose aussi de le bloquer) et un participant depuis la feuille des participants d'une sortie, les deux signalements de membre arrivant dans la file — `report_members_test.dart` ; un organisateur (pas l'auteur de l'article) supprime le commentaire d'un membre depuis son `⋯`, qui le retire du fil et de l'API — `comment_moderator_delete_test.dart`. *Non couvert : le signalement depuis une étape de voyage et depuis la feuille des participants d'un voyage, ce que le modérateur voit de la file dans l'app (elle n'a pas d'écran de file : vérifié par l'API).*
