---
id: MOB-78
title: "Gérer les modèles de sortie dans l'app (17 octobre 2026, contrat d'API inchangé)"
status: done
group: "Tableau de bord d'équipe"
done: 2026-10-17
---

## Livré

### `MOB-78` Gérer les modèles de sortie dans l'app (17 octobre 2026, contrat d'API inchangé)

`MOB-78` **Liste, création, modification et suppression des modèles de sortie, à parité avec le
site** — détaché de `MOB-24`. Mêmes droits que le serveur (`RideTemplateAccessChecker`) :
organisateur ou administrateur de l'équipe pour **toutes** les actions, lecture comprise, modules
sorties **et** parcours actifs, tranchés par `RideTemplateAccessGate`
(`…/rides/presentation/widgets/templates/ride_template_gate.dart`). `RideTemplateListPage`
(`…/pages/ride_template_list_page.dart`) : recherche, pagination par décalage
(`RideTemplateListNotifier`), compteur, une carte par modèle (« 3 groupes · prochaine sortie
#42 » / « sans numéro »), un `⋯` qui ouvre `ride_template_menu.dart` (créer une sortie depuis ce
modèle, modifier, supprimer après confirmation) ; état vide avec « Nouveau modèle ».
`RideTemplateEditorPage` : nom, numéro de la prochaine sortie, description markdown (sans bouton
image : un modèle n'a pas de médias), tags, visibilité (masquée pour une équipe `TEAM`), statut,
groupes (nom, vitesse, places, heure, ordre ; ni meneur ni parcours, qui se choisissent sur
chaque sortie), confirmation avant d'abandonner. `RideTemplateForm`
(`…/rides/domain/ride_template_form.dart`), `RideTemplateRepository` et
`notifyRideTemplatesChanged` (`ride_template_providers.dart`) portent les données.
`RideGroupEditor`, `MarkdownEditorField`, `SearchPickerSheet` (pied) et `EditorSection` sont
partagés avec l'éditeur de sortie. `rideTemplates`, `rideTemplateNew` et `rideTemplateEdit` sont
devenus des écrans de l'app et des deeplinks dans `contracts/routes.yaml` (hiérarchie Équipe ›
Modèles : la liste sous l'équipe, le formulaire sous la liste). Le tableau de bord ouvre la liste
dans l'app (« Gérer les modèles », lignes « 3 groupes · prochaine #42 ») et la feuille « Charger
un modèle » de l'éditeur de sortie porte le même lien en pied. Tests :
`ride_template_form_test.dart`, `ride_template_list_page_test.dart`,
`ride_template_editor_page_test.dart`, `ride_editor_page_test.dart`, `team_dashboard_test.dart`,
`link_launcher_test.dart`, `deep_link_hierarchy_test.dart`, `team_web_paths_test.dart` ;
`flutter analyze` sans remarque, `flutter test` vert (1 120 tests). Tests Patrol
`ride_templates_test` et `ride_templates_member_test`, verts sur le simulateur iOS et l'émulateur
Android (un état vide s'attend présent, pas visible : Patrol ne le tient jamais pour visible).
**À ne pas défaire** : `RideGroupEditor` est partagé et ne rend **aucune** ligne meneur ni
parcours quand ses callbacks sont nuls (ses clés viennent de `fieldKeys` : deux éditeurs peuvent
coexister dans la pile) ; le refus est tranché **avant** de lire le modèle, sinon un simple
membre lirait un 403 au lieu du refus ; `tagIds` part toujours, `[]` compris (« plus aucun
tag ») ; les groupes repartent au PUT avec leur id, sinon le serveur les supprime et les recrée ;
`notifyRideChanged` invalide aussi les listes et détails de modèles, parce qu'une sortie créée
depuis un modèle en avance le `nextNumber`.
