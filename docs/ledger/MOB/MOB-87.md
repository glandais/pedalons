---
id: MOB-87
title: "Sélecteur d'équipe dans l'en-tête d'équipe"
status: done
group: "Navigation à deux niveaux : analyse du 24 octobre 2026 (contrat d'API inchangé)"
done: 2026-10-24
---

## Livré

`MOB-87` **Sélecteur d'équipe dans l'en-tête d'équipe** (24 octobre 2026, contrat inchangé) —
toucher le nom dans `team_header.dart` (suivi d'un chevron) ouvre la feuille « Mes équipes »
(`my_teams_sheet.dart`, `myTeamsProvider`) : les mêmes règles que `WEB-111` (ordre du serveur,
équipe courante cochée et annoncée `selected` aux lecteurs d'écran, « Toutes les équipes »,
même section sinon tableau de bord, calculé par `team_sections.dart`). L'en-tête reçoit sa
section (`section`, aussi depuis la vue calendrier de l'agenda). Sans menu, toucher le nom ramène
au tableau de bord comme avant (`keys.team.headerIdentity` inchangée). Tests :
`team_switch_target_test.dart`, groupe « Mes équipes » de `team_home_page_test.dart`. Mêmes
décisions à ne pas défaire que `WEB-111` (en-tête seulement, 20 équipes).
