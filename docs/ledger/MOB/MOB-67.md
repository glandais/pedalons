---
id: MOB-67
title: "Page d'un groupe de sortie au mobile"
status: done
group: "Météo des sorties"
done: 2026-10-13
---

## Livré

`MOB-67` **Page d'un groupe de sortie au mobile** (13 octobre 2026, contrat inchangé). Route
`rideGroup` (commune avec `WEB-77`) imbriquée sous celle de la sortie dans `router.dart`, avec sa
hiérarchie de lien profond (`_rideAncestor`) et son motif dans `internalRouteTemplates` ;
`?tab=weather|overview|participants` (hors contrat, `RideGroupTab.fromQuery`) choisit l'onglet.
`RideGroupPage` : barre avec partage (`Paths.rideGroup`), puces de groupe, `PdlSegmented`
Aperçu · Météo · Participants, barre d'inscription en bas (`RideGroupActionBar` :
inscrits/max, places restantes, bouton de `rideGroupAction`, bandeau d'échec
`registrationFailureBanner` sorti de `RideGroupsSection`). Aperçu : carte des groupes avec le
groupe allumé et profil, statistiques (départ avant / avec / après par `groupStartRelation`,
arrivée estimée, allure, distance, dénivelé positif, chacune omise si absente), meneur, carte
résumé météo qui ouvre l'onglet Météo, avatars et « Voir tous les participants », « Parcours du
groupe » (GPX, FIT, envoi vers l'appareil, `ride_group_route_actions.dart`, partagé avec
`RideGroupsSection`). Météo : l'ancien contenu de `RideWeatherPage` sans sélecteur
(`DepartureWeatherSection`, sortie de `ride_weather_page.dart`, en-tête et corps du leg,
attribution), aucun appel pour une sortie terminée ou annulée. Participants :
`ParticipantListView`, sorti de `ParticipantsSheet` qui l'enveloppe. La page pose
`selectedRideGroupProvider` après la frame, et le détail en dessous retrouve le même groupe.
Un groupe inconnu affiche un état vide qui ramène à la sortie. `RideWeatherPage` et son test sont
**supprimés** : tout lien vers elle mène à l'onglet Météo de la page du groupe (capture des
stores `rideGroupWeather` dans `plan.json`, `seed.py`, `screenshot_mode.dart`). Sur le détail, la
carte météo devient `RideDepartureWeatherCard` (départ seulement, sans lien ni groupe) ; une
carte de groupe ouvre sa page et porte `RideGroupWeatherLine` (température, ciel, pluie en bleu
doux comme au web, Face / Dos colorés par `RelativeWind` généré, libellé toujours écrit). Une
inscription ou une désinscription réussie relit toutes les listes de participants
(`notifyParticipationChanged`), le pull-to-refresh de la page aussi. `weatherLegFor` et son repli
sont remplacés par le strict `weatherLegOfGroup`. Tests : `ride_group_page_test.dart`,
`ride_group_weather_line_test.dart`, `ride_detail_page_test.dart` (carte au départ seulement,
carte de groupe qui ouvre la page), `ride_weather_display_test.dart`, `ride_group_card_test.dart`,
`deep_link_hierarchy_test.dart`, `link_launcher_test.dart` ; Patrol `ride_group_page_test.dart`
et `ride_participants_map_test.dart` adaptés (`openGroup`, `selectGroup` = ouvrir puis revenir),
verts au 16 octobre 2026 (`MOB-68`). **À ne pas défaire** : la page du groupe remplace l'écran météo du
parcours ; la carte météo du détail est limitée au départ — **sauf pour une sortie sans groupe**
(`legs.length == 1 && groupId == null`), qui garde vent et alerte pluie sur le détail ; la ligne
météo d'une carte n'a pas de tap propre (la carte ouvre la page) ; le meneur n'apparaît que si
`group.leader != null`, **jamais de repli** ; inscrit dans un autre groupe, la barre écrit « Vous
êtes inscrit dans le groupe X. » avec un lien et n'offre pas « Rejoindre » (un groupe par sortie
côté serveur) — le changement de groupe (`switchGroup`) reste sur les cartes du détail ;
`WeatherForecastCard`, `weather_leg_sections.dart`, `keys.ride.weatherOpenButton` et
`rides.weather.viewRoute` restent pour l'étape de voyage (`stage_weather_card.dart`,
`stage_weather_page.dart`).
