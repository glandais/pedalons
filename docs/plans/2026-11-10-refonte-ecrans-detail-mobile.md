# Refonte des écrans de détail mobiles (sortie, groupe, voyage, étape, parcours)

> **État (2026-11-10)** : lots 0 à 12 exécutés, sauf la recette (Patrol iOS et Android, captures, passe sur
> appareil), ouverte sous ledger `MOB-135` — ce plan reste dans `docs/plans/` jusqu'à ce qu'elle soit faite.
> Livré : `MOB-134`, `API-169` à `API-172`, `WEB-164` ; restes : `API-173`, `MOB-136`, et `WEB-165` hors périmètre.

## Contexte

L'état des lieux du 2026-11-10 ([2026-11-10-etat-des-lieux-affichage/](2026-11-10-etat-des-lieux-affichage/SYNTHESE.md)) a montré que les cinq écrans de
détail mobiles n'ont ni la même ossature ni les mêmes formats, et s'écartent du web. Dix maquettes cibles et une
feuille « GPS » ont été dessinées et validées écran par écran ; leurs règles sont dans `maquettes/KIT.md` §8.
Ce plan les implémente dans l'app Flutter, par lots, chaque lot étant confié à un sous-agent **Opus**.

Résultat attendu : cinq pages qui défilent, même ordre de blocs, mêmes formats, un bouton « GPS » unique,
une inscription lisible, la météo en section.

Plan validé le 2026-11-10. Entrée de ledger : `MOB-134`. Maquettes et règles : [maquettes/](2026-11-10-etat-des-lieux-affichage/maquettes/README.md), rendus PNG dans `maquettes/png/`.

## Décisions déjà prises (à ne pas rouvrir)

- Règles d'écran : `maquettes/KIT.md` §8 fait foi. `SYNTHESE.md` §6 reste valable, sauf deux points amendés ci-dessous.
- API : quatre modifications retenues (météo par groupe, groupe plus tardif, changement de groupe atomique, arrivée par groupe).
- Web : le strict nécessaire (libellé « Vitesse moyenne », client régénéré, rien qui casse). Pas de refonte.
- « En cours » sans vitesse : la fin reste **départ + 3 h** (`PublicationEndCalculator`, déjà stocké) — amende `SYNTHESE` §6.5.
- « Quitter le groupe » et « Changer pour A » : pas de confirmation.
- PNG des maquettes versionnés ; recette par captures sur simulateur, pile backend sur optiplex.

Hypothèses que je prends (recommandations du sous-agent de conception, non contestées) :
- Itinéraire vers un lieu : lien `https` de cartes (Plans sur iOS, Google Maps sur Android), coordonnées d'abord, adresse sinon ; ni l'une ni l'autre : texte non cliquable. Aucun schéma à déclarer.
- Page groupe sans onglet Inscriptions : « Voir toutes les personnes inscrites » ouvre `ParticipantsSheet`. `?tab=weather` reste toléré et fait défiler jusqu'à la météo.
- Pièces jointes (non dessinées) : gardées sous Description.
- Pas de goldens : la carte native n'existe pas en test, et il n'y a aucune infrastructure.

## Architecture Flutter (réutiliser avant de créer)

Pas de nouvelle coquille : `PdlScreenScaffold` avec `actionBar: null`. Chemins relatifs à `mobile/lib/`.

| Besoin | Décision | Emplacement |
|---|---|---|
| Rythme des sections | fonction `detailSection(titre, compte, enfant)` au-dessus de `PdlSectionHeader` | `core/widgets/detail_section.dart` |
| Bloc repliable | **nouveau** `PdlDisclosure` (aucun accordéon n'existe) | `core/pdl/` + galerie |
| Bloc de départ | **étendre** `PdlDepartureBlock` : `trailing`, `places`, `footnote` | `core/pdl/pdl_departure_block.dart` |
| Lieux cliquables | **étendre** `PdlPlaceRow` ; utilitaire `openDirections` au-dessus de `openLink` | `core/utils/directions.dart` |
| Tuiles | `DetailStatTiles` sur `PdlStatCellRow` / `PdlMetaGrid` (ordre fixe : Distance, Dénivelé / Durée, Vitesse ou Étapes) | `core/widgets/` |
| Hauteur de carte | sortir la règle 44 % (260–460) de `ride_groups_map.dart` vers un jeton ; profil 110 px | `core/theme/pdl_tokens.dart` |
| Section Parcours (un parcours) | **nouveau** `RouteSection`, fait des sous-widgets d'`EmbeddedRouteSheet` | `features/routes/presentation/widgets/` |
| Section Parcours (sortie) | **extraire** `RideRouteSection` du doublon `_mapAndProfile` / `RideGroupOverviewTab` | `features/rides/presentation/widgets/` |
| Section Météo | **nouveau** `WeatherSection` : recompose `DepartureConditionsBlock`, vent, frise, `WeatherAttributionBlock` | `features/rides/presentation/widgets/` |
| Lignes de carte | `RideWeatherSummaryLine` au format cible ; nouveau `PublicationStatsLine` (distance · D+ · vitesse) | `features/rides/…`, `core/widgets/` |
| Feuille GPS | **nouveau** `showGpsSheet` + `GpsButton` + un contrôleur d'export qui remplace `RouteExportRunner` et ses 4 copies ; réutilise `deliverAsset`, `uploadRouteToService` | `features/routes/presentation/gps_sheet.dart` |
| Inscription | **nouveau** `RideRegistrationControl` ; `RideGroupAction` gagne `switchTo` | `features/rides/…` |
| Phase | `PublicationPhase` (à venir, en cours, terminé) à côté d'`isUnderWay` | `features/teams/domain/publication_timing.dart` |
| Formats | durée « 3 h 18 », « Prévision du … », date longue sans jour, 12 h/24 h par langue | `core/utils/formatters.dart` |

## Modifications d'API (lot 1, contrat 13.4.0 → 13.5.0, champs ajoutés seulement)

| Entrée | Changement | Fichiers backend |
|---|---|---|
| `API-169` Météo par groupe | `WeatherLegDto` gagne `summary` (réutilise `RideWeatherCalculator.legSummary`, aujourd'hui réservé aux étapes) et `departure` (conditions au point de rendez-vous à `group.startAt`, avec lever et coucher) | `service/weather/RideWeatherPlans.java`, `RideWeatherService.java`, `RideWeatherCalculator.java`, `WeatherLegDto` |
| `API-170` Jugé par groupe, jusqu'à la fin | météo servie jusqu'à la fin (`PublicationEndCalculator`), plus coupée à `ride.dateTime` ; `joinGroup` refuse `RIDE_PAST` sur `group.startAt` | `RideWeatherService.java:109`, `RideWeatherLookup.java`, `TripWeatherService.java`, `service/ride/RideService.java:567-575` |
| `API-171` Changement de groupe | `POST …/rides/{rideSlug}/groups/{groupId}/switch` → `RideParticipationDto`, une transaction, mêmes contrôles et même verrou que `join` | `RideService.java`, `api/rides/RideResource.java` |
| `API-172` Arrivée par groupe et par étape | `RideGroupDto` et `TripStageDto` gagnent `estimatedArrival` et `estimatedDurationMinutes` (distance / vitesse, absents sans distance ou sans vitesse), servis hors fenêtre de prévision | `PublicationEndCalculator.java`, DTO sortie et étape |

Tests backend à écrire dans le même lot (`RideWeatherResourceTest`, `RideWeatherCalculatorTest`, `TripWeatherResourceTest`,
`RideServiceTest`, `RideResourceTest`, un cas de course près de `RideJoinTwoGroupsRaceTest`, `PublicationEndCalculatorTest`).
**Je ne les lance pas** : je donne la commande, vous la lancez. Régénération par le skill `contract-first-api`.

## Lots

| # | But | Fichiers principaux | Dépend de | Taille |
|---|---|---|---|---|
| 0 | Plan dans `docs/plans/`, entrées de ledger, **PNG des 12 maquettes** (Chrome sans fenêtre, hauteur lue dans `$preview`, `support.js` vide local ignoré par git), liste des artboards tronqués | `docs/plans/…`, `maquettes/png/`, script à côté de `gen_canvas.py` | — | S |
| 1 | API (ci-dessus) + régénération des clients | backend, contrat, clients générés | — | M |
| 2 | Formats, domaine (`PublicationPhase`, `switchTo`), clés l10n du chantier (fr, en), « Vitesse moyenne » web | `formatters.dart`, `publication_timing.dart`, `assets/l10n/*.json`, `frontend/src/locales/` | — | M |
| 3 | Composants Pdl et itinéraire | `core/pdl/*`, `core/utils/directions.dart`, galerie | — | M |
| 4 | Feuille GPS partout | `gps_sheet.dart`, `route_export.dart`, `route_download_actions.dart`, `ride_group_route_actions.dart`, `ride_group_card.dart`, `next_ride_card.dart`, `dashboard_rides.dart` | — | M |
| 5 | `WeatherSection` et lignes de carte, branchées sur les écrans existants | `weather_leg_sections.dart`, `departure_weather_section.dart`, `ride_weather_summary_line.dart`, `ride_group_weather_line.dart` | 1, 2, 3 | M |
| 6 | **Page groupe** (écran pilote) : plus d'onglets, inscription dans le bloc de départ, météo en section | `ride_group_page.dart` ; suppression des deux onglets ; `router.dart:804` ; `rides/keys.dart` | 2–5 | L |
| 7 | Sortie solo et sans groupe ; badge « En cours » | `ride_detail_page.dart` ; suppression de `ride_solo_group_section.dart`, `ride_weather_card.dart`, `ride_group_action_bar.dart` | 6 | M |
| 8 | Sortie à plusieurs groupes : mon heure en gros, « Votre groupe : B », cartes refaites, « Changer pour A », « Quitter le groupe » | `ride_detail_page.dart`, `ride_group_card.dart`, `ride_groups_section.dart`, `ride_departure_block.dart`, `ride_registration_controller.dart` | 7, 1 | L |
| 9 | Voyage, une ou plusieurs étapes (même écran) | `trip_detail_page.dart`, `stage_card.dart`, `trip_map.dart` ; suppression de `trip_summary_card.dart` | 2–5 | M |
| 10 | Fiche parcours en page qui défile, commentaires | `route_detail_page.dart`, `route_section.dart` ; `route_sheet_header.dart` retiré | 3, 4 | M |
| 11 | Étape sur `RouteSection`, météo en section, arrivée estimée | `stage_detail_page.dart` ; suppression de `stage_weather_page.dart`, `stage_weather_card.dart`, `embedded_route_sheet.dart` | 9, 10 | M |
| 12 | Nettoyage (clés et l10n mortes, captures des stores, `mobile/CLAUDE.md`), recette, ledgers vers `LEDGER_DONE` | transverse | tous | M |

Ordre d'exécution : 0, puis 1 à 4 (indépendants, lancés l'un après l'autre pour garder un dépôt lisible), 5,
puis la chaîne sorties 6 → 7 → 8, le voyage 9, le parcours 10, l'étape 11, enfin 12.

Risque transverse : `isPast` est lu une cinquantaine de fois ; chaque lot écran choisit usage par usage entre
« parti » et « terminé », sans remplacement de masse.

## Déroulé d'un lot

1. Je rédige le brief : maquette PNG et `.dc.html` de référence, règles du KIT concernées, fichiers, widgets à réutiliser, tests à écrire ou adapter, critères d'acceptation.
2. Un sous-agent **Opus** implémente (`Agent`, `model: opus`), dans ce worktree.
3. Je relis le diff, je lance `flutter analyze`, `flutter test`, `./format.sh mobile`.
4. Capture sur simulateur comparée au PNG (voir Vérification), puis commit « … (MOB-134, lot n) » sur `feat/mobile-review`, sans pousser.
5. Je m'arrête et vous montre le résultat avant le lot suivant pour les lots 6, 8 et 10 (les plus risqués).

## Ledger

- `MOB-134` : la refonte entière, un seul ID, lié au plan ; `MOB-135` : recette sur appareil.
- `API-169` à `API-172` : ci-dessus.
- `WEB-164` : « Vitesse moyenne » et client régénéré ; `WEB-165` : aligner le web sur KIT §8 (hors périmètre, noté pour ne pas le perdre).
- Numéros à revérifier au moment de les créer (`grep -ohE 'MOB-[0-9]+' docs/LEDGER_*.md | sort -t- -k2 -n | tail -1`).

## Vérification

- **Chaque lot** : `flutter analyze`, `flutter test`, `./format.sh mobile`. Un test widget par maquette cible, qui vérifie l'ordre des sections par leurs clés (dix cas, nommés comme les fichiers de maquette).
- **Captures** : pile e2e sur optiplex (skill `pedalons-e2e-optiplex`), un test Patrol « visuel » par écran qui défile et capture, données semées selon KIT §6. Avant tout usage de la pile ou d'un simulateur, je demande le feu vert des autres sessions (`ListAgents` / `SendMessage`) ; un seul simulateur à la fois, celui déjà démarré.
- **Limite connue** : je n'ai pas vérifié que la pile e2e sert une prévision météo. Si elle n'en sert pas, la section Météo se vérifie par tests widget et sur staging.
- **Backend** : commandes de test fournies, lancées par vous.
- **Recette finale (lot 12)** : `bash check.sh`, Patrol iOS puis Android, puis sur appareil — petit écran, texte à 130 %, mode sombre, impérial, anglais en 12 h, fuseau différent, feuille GPS Android (enregistrer, envoyer) et iOS (partager), « Connecter un compteur » → `/profil/appareils`.
