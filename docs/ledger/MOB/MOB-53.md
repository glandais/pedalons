---
id: MOB-53
title: "Tableau de bord d'équipe, parité avec le web"
status: done
group: "Tableau de bord d'équipe"
done: 2026-10-06
---

## Livré

`MOB-53` **Tableau de bord d'équipe, parité avec le web** (6 octobre 2026, **API 10.8.0**,
`API-79`, `WEB-63`). Pour un membre, l'adresse de l'équipe ouvre le tableau de bord
(`team_dashboard_page.dart`, `widgets/dashboard/`, `teamDashboardProvider`) ; le fil est à
`?tab=publications`, comme au web, pour que les liens du site ouvrent la même vue. Mêmes sections
et mêmes variations par rôle qu'au web, modes clair et sombre, sans débordement à 320 px. Les
actions d'édition, de modération et d'administration ouvrent le site dans le navigateur intégré
(`team_web_paths.dart`), l'app n'ayant pas ces écrans (`MOB-24`). Tests :
`team_dashboard_test.dart`, `team_web_paths_test.dart` ; suite complète verte (809 tests) avant
les dernières retouches, `test/features/teams` (55) après. **À ne pas défaire** : les blocs
organisateur et admin ne s'affichent que si l'API les envoie, l'écran ne déduit pas le rôle ;
`notifyParticipationChanged` invalide `teamDashboardProvider` ; « Inviter » n'apparaît qu'avec
`team.addMemberAllowed` ; la barre de remplissage d'un groupe est lue comme une seule phrase.
