---
id: MOB-54
title: "Adresses du site du tableau de bord générées depuis `routes.yaml`"
status: done
group: "Tableau de bord d'équipe"
done: 2026-10-06
---

## Livré

`MOB-54` **Adresses du site du tableau de bord générées depuis `routes.yaml`** (6 octobre 2026,
sans changement de contrat d'API). Les pages du site qu'ouvre le tableau de bord (`rideNew`,
`rideEdit`, `postNew`, `postEdit`, `tripEdit`, `rideTemplates`, `teamAdminReports`,
`teamAdminMembers`, `teamSettings`) sont déclarées `mobile: true` + **`appScreen: false`** dans
`contracts/routes.yaml` — un nouveau champ de `scripts/generate-routes.mjs`, documenté dans
`docs/APP_LINKS.md` : le builder Dart est émis, mais la route n'a pas d'écran dans l'app, ne
peut pas être un deeplink, et son nom rejoint l'ensemble `webOnlyRouteIds` désormais **généré**
dans `paths.generated.dart` (il était écrit à la main dans `link_launcher.dart`, avec `features`
seul). `team_web_paths.dart` ne fait plus que déléguer à `Paths.*` et ajouter les paramètres de
requête (`?template=`, `?invite=1`) ; `NotificationDisplay.webPath` passe aussi par
`Paths.teamAdminReports`. Les chemins suivent donc la langue de l'app (`/equipes/…` en
français), que le site sert comme l'anglais. Tests : `team_web_paths_test.dart` (les deux
langues, et chaque page du tableau de bord dans `webOnlyRouteIds`), `link_launcher_test.dart`
(« couvre toutes les entrées de PathVariants »), `notifications_page_test.dart`. **À ne pas
défaire** : une adresse du site ouverte depuis l'app vient de `Paths`, jamais d'une chaîne ;
une page sans écran est `appScreen: false`, pas ajoutée à la main à `webOnlyRouteIds` ni à
`internalRouteTemplates` (la pousser sur le routeur mènerait à une route inconnue). La
reconnexion que peut demander le navigateur intégré n'est pas traitée ici : ledger `MOB-58`.
*Note du 15 novembre 2026* : les chemins d'administration d'équipe que cette entrée déclarait
`appScreen: false` sont tous devenus des **écrans de l'app** (`teamSettings` — `MOB-166` —,
`teamAdminMembers` — `MOB-167` —, `teamAdminReports` et `teamAdminPlaces` — `MOB-168` —,
`teamAdminTags`, `teamAdminPages` et l'éditeur d'une page — `MOB-169` ; les éditeurs de
sortie, de publication, de voyage et les modèles l'étaient déjà). `team_web_paths.dart` et
son test ont disparu avec le dernier (`MOB-169`), et `webOnlyRouteIds` ne compte plus que
`features` et `support` (la page d'assistance, qu'ouvre le lien de contact d'une équipe
pleine). Le mécanisme `appScreen: false` et sa règle (« À ne pas défaire ») restent, pour
ces deux pages et les suivantes.
