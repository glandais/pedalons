# Les outils GPX dans l'application mobile

Plan du 22 novembre 2026, ledger `MOB-178`. Branche `feat/mobile-outils-gpx`, un commit par lot.

## 1. En une page

Le site a sept écrans « Outils GPX » (`/outils-gpx/…`) : un accueil, la liste de ses fichiers, la
fiche d'un aperçu, sa carte plein écran, la création de zéro, la modification, et une carte sans
tracé. L'app n'en a aucun ; le client `gpx_previews_client.dart` et ses DTO sont générés et jamais
appelés. Ce plan porte les sept écrans dans l'app, **sans changement de contrat d'API**. Le seul
changement hors de `mobile/` est le pont du planificateur embarqué, où `teamSlug` devient
facultatif (un aperçu n'a pas d'équipe).

## 2. Décisions (22 novembre 2026, avec le propriétaire)

| # | Décision |
|---|---|
| D1 | L'entrée est dans l'**onglet Parcours** (la parcothèque « Explorer »), pas dans le profil. |
| D2 | **Connexion obligatoire**, y compris pour la fiche d'un aperçu, publique au site : le `redirect` du routeur s'en charge déjà (toute route hors `isAuthAdjacent`), puis `resumeAfterSignIn` rouvre le lien. Rien n'est ajouté à `_authAdjacentPaths`. |
| D3 | La fiche d'un aperçu **réutilise `RouteSection`** par une abstraction « parcours affiché » (§4), pas une conversion de l'aperçu en `RouteDetailDto` : une conversion inventerait une équipe et un slug, vers lesquels partiraient le GPS et la relecture du profil. |
| D4 | La **carte sans tracé** est dans le périmètre ; « Me localiser » y reste éteint tant que `MOB-131` n'est pas tranché (même règle que `kPlannerLocate`). |

## 3. État des lieux

### 3.1 Le site

| Route | Page | Contenu |
|---|---|---|
| `gpxTools` | `GpxToolsPage` | Voir un fichier (envoyé dès le choix), fusionner 2 à 10 fichiers, tracer de zéro (si `enableGpxPlanner` et quota personnel non épuisé), carte sans tracé, mes fichiers, mention de conservation |
| `gpxToolsList` | `MyGpxPreviewsPage` | Liste paginée : nom, départ, distance, D+, D−, âge ; voir, supprimer après confirmation |
| `gpxToolsView` | `GpxPreviewView` | Carte, Pente/Revêtement/Météo, distance et dénivelés, départ et vitesse (ou « Ajouter un départ » au propriétaire), météo du cache relue toutes les 15 s pendant 3 min, points du parcours, GPS, enregistrer en parcours d'équipe, dupliquer, modifier, supprimer, partager, mention « altitude en cours d'affinage » |
| `gpxToolsMap` | `GpxPreviewFullscreenMapPage` | La carte en plein écran |
| `gpxToolsNew` | `CreateGpxPreviewPage` | Planificateur sur carte vide, nom, départ ; un fichier importé dans le planificateur et laissé tel quel part par l'envoi de fichier puis un renommage |
| `gpxToolsEdit` | `EditGpxPreviewPage` | Réservé au propriétaire : nom, tracé (planificateur si une seule trace, ou nouveau fichier), départ |
| `gpxToolsBlankMap` | `GpxBlankMapPage` | Fonds, relief, recherche, plein écran |

### 3.2 L'app

Réutilisable tel quel : `PlannerBridge` et `RoutePlannerScreen` (`MOB-170`), `planner_quota.dart`
(la portée `PERSONAL` est déjà lue), `PlannerPreviewCard`, `gpx_check.dart` et le choix de fichier,
la feuille GPS et `GpsExportRunner`, les widgets météo des sorties (le point d'accès météo d'un
aperçu renvoie un `RideWeatherDto`), `track_wind_bars`, `PdlDepartureLine`, la section des points
du parcours, la pagination, `share_link`.

Couplé à un parcours d'équipe : `RouteSection`, `RouteMap` (et `RouteMapLayerBuilder`), les quatre
providers de `route_elevation_provider.dart`, `weather_map_layer.dart` et `GpsExportTarget` prennent
un `RouteDetailDto` ou une `RouteKey(teamSlug, routeSlug)`.

## 4. Socle (lot 1) : le parcours affiché

- `ShownRoute` (`features/routes/domain/shown_route.dart`) : ce que la carte et le profil lisent
  — `id`, `name`, `distance`, `tracks`, `waypoints`, `elevationState`, `start`, `end` — avec
  `hasGeometry`, `lines`, `elevationSamples()`, `firstPoint`/`lastPoint`. Obtenu par
  `RouteDetailDto.shown` et `GpxPreviewDto.shown`, **mémorisé par DTO** (`Expando`) : les mémoires
  des couleurs du vent comparent le parcours par identité, et un `ShownRoute` neuf à chaque `build`
  les viderait.
- `TrackKey`, classe scellée : `RouteKey` (inchangée pour ses appelants) et `GpxPreviewKey(id)`.
  `shownRouteProvider(TrackKey)` lit `routeDetailProvider` ou `gpxPreviewProvider`. Les quatre
  providers du profil prennent une `TrackKey`.
- `RouteMap.route`, `RouteMapLayerBuilder` et les fonctions de `weather_map_layer.dart` prennent un
  `ShownRoute`.
- `RouteSection(trackKey:)` ; ce qui ne vaut que pour un parcours d'équipe (« Détails ») reste
  conditionné à une `RouteKey`.
- `GpsExportTarget` gagne une destination scellée : `GpsSendRoute(teamSlug, routeSlug)` ou
  `GpsSendPreview(previewId)` ; `RouteExportOperations` gagne `uploadPreview`
  (`uploadToGpsService`). Les fichiers d'un aperçu sont des `AssetDto` construits sur `gpxUrl` et
  `fitUrl`, avec leur vrai type MIME.

Aucun changement visible : les tests de la fiche parcours, de l'étape et des sorties restent verts.

## 5. Lecture (lot 2)

- `contracts/routes.yaml` : les sept routes passent à `mobile: true` ; `gpxToolsView` et
  `gpxToolsMap` à `deeplink: true` (le lien partagé). `pnpm generate-routes`.
- Routeur : les écrans sur le navigateur racine, au-dessus du shell, comme les fiches ;
  `_deepLinkHierarchies` pose la parcothèque puis l'accueil des outils sous une fiche ouverte par
  lien. `gpxToolsMap` ouvre la fiche puis la carte en plein écran.
- Onglet Parcours : une entrée « Outils GPX » dans la barre d'outils de la parcothèque (pas dans la
  section Parcours d'une équipe).
- Accueil (`features/gpxtools/presentation/pages/gpx_tools_page.dart`) : les cinq cartes du site ;
  « Voir un fichier » et « Fusionner » choisissent puis envoient (`createPreview`,
  `mergePreviews`, bornes 2..10 vérifiées avant l'envoi), et poussent la fiche.
- Mes fichiers : `PagedListNotifier` sur `listMyPreviews`, ligne avec départ, stats et âge, voir,
  supprimer après confirmation.
- Fiche d'un aperçu, l'ossature commune des fiches (KIT §8) : titre et partage, `DetailStatTiles`,
  départ (`PdlDepartureBlock` dans `departureTimezone`) et vitesse, `RouteSection` avec Météo si le
  leg a du vent, `WeatherSection` (cache relu comme au site : 15 s, 3 min, « Réessayer »), points
  du parcours, mention de conservation. Relecture tant que l'altitude est `PENDING`.
- Actions : supprimer (propriétaire), partager (`Paths.gpxToolsView`, lien du site).
- Déclarations des stores : ligne d'inventaire « Outils GPX » (fichier GPX envoyé, nom, départ)
  dans `mobile/store-metadata/data-safety.md`, commentaires de `PrivacyInfo.xcprivacy` ; aucun
  type de donnée nouveau (le GPX est déjà déclaré par `MOB-79`).

## 6. Actions (lot 3)

- Dupliquer (`copyGpxPreview`, toute personne connectée) : feuille de nom comme pour un parcours.
- Enregistrer en parcours d'équipe : feuille de choix d'équipe (`minRole: ORGANIZER`,
  `enableRoutes`, grisée avec sa raison si l'aperçu est tracé et que l'équipe a fermé le
  planificateur), `createRouteFromPreview`, refus de quota d'équipe (`planner_quota.dart`),
  `notifyRouteChanged`, puis la fiche du parcours.

## 7. Écriture (lot 4)

- Pont : `teamSlug` facultatif dans `frontend/src/embed/mobile-planner/` (`load` et les appels de
  routage) ; bundle reconstruit, `tool/planner_bundle.sha256` mis à jour.
- Formulaire natif d'un aperçu : nom (3 caractères au moins), tracé (planificateur, ou fichier en
  modification), départ (date dans le fuseau du départ, bornée par la purge, et vitesse moyenne) ;
  le planificateur plein écran comme pour un parcours.
- Création : `createPreviewFromPoints`, ou `createPreview` puis renommage pour un fichier importé
  dans le planificateur et laissé tel quel (le site : « renameFailed » si le renommage échoue).
- Modification : réservée au propriétaire, relit l'aperçu et son `planner-state` à l'ouverture.
- Quota personnel : la carte « Tracer » de l'accueil est inactive avec sa raison quand il est épuisé ;
  un refus à l'enregistrement ouvre la feuille de quota.

## 8. Carte sans tracé, tests, ledger (lot 5)

- Carte sans tracé : `PdlMap` plein écran sur `defaultCenter`, fonds, relief, recherche de lieu ;
  pas de « Me localiser » (D4).
- Patrol : accueil → voir un fichier → fiche → supprimer ; tracer de zéro (points posés en ligne
  droite, comme `route_planner_test.dart`).
- Ledger : `MOB-178` livré, `MOB-154` corrigé (« ni éditeur de parcours ni aperçus GPX »), une
  entrée de recette sur appareil si elle reste ouverte.
