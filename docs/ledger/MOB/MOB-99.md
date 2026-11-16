---
id: MOB-99
title: "La rangée des sections d'une équipe ne lève plus `RenderBox was not laid out`"
status: done
done: 2026-10-26
---

## Livré

`MOB-99` **La rangée des sections d'une équipe ne lève plus `RenderBox was not laid out`**
(26 octobre 2026, contrat inchangé) — le recentrage de la section ouverte
(`team_sections_bar.dart`, rappel de fin de frame) lisait la taille d'une puce jamais mise en
page quand la page d'équipe était recouverte par une route opaque : l'`Overlay` saute la mise en
page des routes hors scène. Trois tests Patrol iOS échouaient sur cette assertion
(`report_details_test`, `route_editor_member_test`, `team_pages_visibility_test`) ; ils la
couvrent. **À ne pas défaire** : le rappel ne touche la puce que si elle a une taille
(`hasSize`), sinon il ne fait rien.
