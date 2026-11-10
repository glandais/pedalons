# Mobile Flutter — écran de détail d'un PARCOURS (route)

Lecture seule du code, branche `feat/mobile-review`. Rien n'a été exécuté : pas de build, pas de
simulateur. Tous les chemins sont relatifs à `mobile/lib/`. Libellés FR tirés de
`mobile/assets/l10n/fr.json`. Abréviations : `RDP` = `features/routes/presentation/pages/route_detail_page.dart`,
`W/` = `features/routes/presentation/widgets/`.

---

## 1. Points d'entrée

**Route go_router**
- Déclarée dans `config/router.dart:628-641`, sous la branche équipe (`_underTeam(PathVariants.route(':teamSlug', ':routeSlug'), …)`).
  Elle est poussée sur le **navigateur racine** (`parentNavigatorKey: _rootNavigatorKey`), donc hors de la
  coquille : pas de barre d'onglets sous la fiche.
- Chemins (`config/paths.generated.dart:465-470`) : FR `/equipes/{teamSlug}/parcours/{routeSlug}`,
  EN `/teams/{teamSlug}/routes/{routeSlug}`. La sous-route d'édition est `…/modifier` / `…/edit`
  (`_routeEditRoute`, `router.dart:773`).
- La route `routeNew` (`…/parcours/nouveau`) est déclarée **avant** le détail (`router.dart:621-627`) : sinon
  « nouveau » serait lu comme un slug.
- Lien profond : la pile reconstruite est `Équipes → Équipe → Parcours de l'équipe` (`router.dart:325-328`).

**Fichier de page** : `RDP`, `RouteDetailPage(teamSlug, routeSlug)`, un `ConsumerStatefulWidget` (`RDP:57`).

**Providers et DTO**

| Provider | Fichier | Donnée | Rôle |
|---|---|---|---|
| `routeDetailProvider(RouteKey)` | `features/routes/providers/route_detail_provider.dart:36` | `RouteDetailDto` | **seule source** de la fiche : tracé, profil, stats, waypoints, médias |
| `routeUsagesProvider(RouteKey)` (autoDispose) | `route_detail_provider.dart:51` | `List<RouteUsageDto>` (`GET …/usages`) | section « Utilisée dans » |
| `routeElevationSamplesProvider` | `providers/route_elevation_provider.dart:27` | `ElevationSamples?`, dérivés de `tracks[].line` | profil |
| `routeSurfaceBarsProvider`, `routeClimbBarsProvider` | `route_elevation_provider.dart:41`, `:59+` | couleurs des barres du profil | mode Revêtement / Pente |
| `canManageRoutesProvider(teamSlug)` | `providers/route_editor_providers.dart:13` | `bool?` = `team.enableRoutes && (ORGANIZER \|\| ADMIN \|\| platformAdmin)` (`rides/domain/ride_permissions.dart:12-41`) | boutons de gestion |
| `authProvider` | — | `user.id`, `user.connectedServices` | signalement, bouton appareil |
| `unitSystemProvider`, `mapStyleProvider`, `defaultCenterProvider` | — | unités, fond de carte | — |

Champs de `RouteDetailDto` (`api/generated/models/route_detail_dto.dart`) : `id, slug, team (TeamPublicationDto),
name, media (markdown, assets: gpx, fit, images, attachments), distance, elevationGain, elevationLoss (négatif
côté serveur), elevationState (PENDING/FAST/HD), surfaceType (ROAD/GRAVEL/MTB/MIXED), visibility
(TEAM/PUBLIC_UNLISTED/PUBLIC), createdAt, updatedAt, tracks[] (line, climbs[], surfaceState, spans),
waypoints[], deleted, tags[], start?, end?, createdBy? (PublicUserDto), commentCount?`.
Extensions calculées côté client : `allClimbs` (montées de toutes les pistes, dans l'ordre) et `hasGeometry`
(au moins une piste avec des coordonnées) — `route_detail_provider.dart:67-74`.

`RouteUsageDto` : `type (RIDE/TRIP/POST), slug, name, dateTime, timezone, teamSlug, referencedDirectly,
viaChildNames[], endDate?`.

Un poller (`ElevationRefreshPoller`, `RDP:107-125`) réinvalide le détail tant que `elevationState == PENDING`
**ou** que le revêtement est en cours de calcul (`trackSurfacesPending`) : la fiche se met à jour d'elle-même.

---

## 2. Disposition (de haut en bas, état chargé)

Modèle : **carte plein écran en fond + feuille à crans** (`Stack`, `RDP:163-213`). Il n'y a **ni AppBar, ni
sliver** : les commandes du haut flottent sur la carte et le contenu vit dans une `ListView` à l'intérieur
de la feuille. Crans `[0.18, 0.5, 0.92]`, ouverture au cran **0.5** (`RDP:72-73`).

### Couche 0 — CARTE (position : 1ᵉʳ enfant du Stack, sous tout le reste)
- `RouteMap` dans `Positioned.fill` (`RDP:168-182` → `W/route_map.dart:79`).
- **Hauteur : tout l'écran** (statut système compris). La feuille en couvre 18 / 50 / 92 %. Visible : environ
  82 % au cran bas, 50 % au cran initial, 8 % au cran haut.
- Cadrage : `fitPadding = LTRB(50, 50, 50, hauteurÉcran × cran)` (`RDP:175-180`). Le tracé se recadre **à
  chaque cran franchi**, jamais pendant le glissement (`RDP:79-83`, `onDetentChanged`).
- Contenu (`route_map.dart:210-343`) :
  - le tracé `PdlMapTrack`, coloré **par segment** : les montées à la teinte de leur pente, le reste en bleu
    neutre (`climbSegmentColors`). En mode Revêtement, `surfaceSegmentColors`, avec repli sur la pente ;
  - les marqueurs départ et arrivée (`route.start` / `route.end`, sinon les extrémités du tracé, `:328-329`) ;
  - les bornes kilométriques `computePdlKmMarkers` (`:333-335`) ;
  - les waypoints : couche `symbol` native. Un toucher ouvre la feuille du point (`:289-300`, `:330-332`) ;
  - le **réticule** synchronisé avec le profil (`RouteCursorController`, `W/route_cursor_controller.dart`). Un
    toucher sur la carte à moins de 300 m du tracé pose le réticule ; plus loin, il l'efface (`:44-48`) ;
  - la carte est **interactive** (`interactive: !allowFullscreen || fullscreen` → vrai ici, `:319`) ;
  - dans `PdlMapHero` (`core/pdl/map/pdl_map_hero.dart:294-355`), **un seul bouton**, « Choisir le fond de
    carte » (icône `layers`), centré verticalement sur le bord droit de la carte (`Positioned(right, top:0,
    bottom:0) → Center`). Il ouvre la feuille « Fond de carte » : fonds servis, « Ombrage du relief ». **Pas
    de bouton plein écran** (`showFullscreenButton: allowFullscreen || fullscreen` = faux) ;
  - la barre d'échelle en bas à gauche (`pdl_map_scale.dart:73`) et le crédit ⓘ en bas à droite
    (`pdl_map_attribution.dart:52`), **dans le repère de la carte plein écran**, donc sous la feuille (voir §6).
- Sans style de carte servi : fond `surfaceAlt` avec « Carte indisponible » ou un spinner (`route_map.dart:191-201`).

### Couche 1 — Barre flottante du haut (`_overlay`, `RDP:222-321`)
`SafeArea` + `Row`, marge 12 × 6 :
1. `PdlMapButton` retour, icône `back`, sémantique « Retour » → `context.pop()` (`:238-242`).
2. `PdlMapPill` (`Expanded`) avec le **nom du parcours** : opaque à 95 % et flou (`:244-249`).
3. Si `canManage` : `PdlMapButton` partager, icône `share`, « Partager » → `shareAppLink(Paths.route)` (`:253-268`).
4. Si `canManage && !deleted` : `PdlMapButton` crayon, icône `edit`, « Modifier le parcours » → push
   `Paths.routeEdit` (`:269-279`).
5. Si `canManage` : `PdlMapButton` `⋯`, icône `more`, « Gérer le parcours » → `showRouteManageMenu` (`:280-295`).
   **Sinon**, si une personne est connectée et n'est pas l'auteur (`createdBy?.id`) : un `⋯` « Plus
   d'actions » → `showDetailModerationMenu`, qui ne propose ici que « Signaler » (`:298-315`).

### Couche 2 — Feuille à crans `PdlDetentSheet` (`RDP:184-210` → `core/pdl/pdl_detent_sheet.dart`)
Surface `surfaceRaised`, coins hauts arrondis, ombre. Trois zones :

**2a. Poignée** `PdlSheetHandle` (`pdl_detent_sheet.dart`, dans `_sheet`). Poignée et en-tête entraînent la
feuille. Un toucher sur la carte visible au-dessus de la feuille la redescend d'un cran, **seulement
au-delà de 0.5** (sous ce cran, le toucher reste à la carte pour le réticule).

**2b. En-tête** `RouteSheetHeader` (`W/route_sheet_header.dart:30`), reconstruit à chaque pixel de glissement.
Il a deux compositions, seuil `extent < 0.34` (`:18`) :
- **Compacte (cran 0.18)**, `_compactBody` `:57-84` :
  - ligne 1 : le nom (style `cardTitle`, 1 ligne, ellipse) + `PdlBadge` de pratique (`surfaces.*` : « Route »,
    « Gravel », « VTT », « Mixte », teinte `SurfaceType`) ;
  - ligne 2 : `PdlStatRow(nowrap)` avec 3 stats **sans libellé** : icône `distance` + « 46,3 km » ; icône
    `elevationUp` + « 1 108 m » (tendance verte) ; icône `elevationDown` + « −1 108 m » (tendance rouge, signe
    « − » ajouté par le client sur `abs()`, `:140-162`).
- **Complète (crans 0.5 et 0.92)**, `_fullBody` `:87-133` :
  - `PdlTeamLine` : avatar 16 px + nom de l'équipe + chevron → push `Paths.team` (`:95-99`) ;
  - nom du parcours en `screenTitle` 20 px, sur plusieurs lignes, + `PdlBadgeStack` : badge de pratique et badge
    de visibilité (« Équipe » / « Non répertorié » / « Public », avec l'icône `visibilityTeam/Unlisted/Public`) ;
  - rangée `spaceBetween` de 3 grandes `PdlStat` libellées « Distance », « Dénivelé positif »,
    « Dénivelé négatif ».

**2c. Corps** : `ListView` contrôlée par la feuille (`_sheetBody`, `RDP:323-446`). Chaque bloc a des marges
16/0/16/16. Ordre réel :

| # | Bloc | Widget `fichier:ligne` | Condition | Contenu / actions |
|---|---|---|---|---|
| 1 | Bandeau « supprimé » | `PdlBanner` `RDP:336-350` | `route.deleted` | ton warn, icône `delete`, « Ce parcours est supprimé. Seul le rôle Administrateur de l'équipe le voit. » |
| 2 | Tags | `ContentTagRow` `RDP:354-358` (`features/tags/presentation/content_tags.dart:28`) | `tags.isNotEmpty` | rangée de `PdlTag` |
| 3 | Interrupteur de couleur | `RouteColorModeSwitch` `RDP:361-370` (`W/route_color_mode_switch.dart:109`) | `hasGeometry && modes.length > 1`, donc seulement si le revêtement est connu (`_modes`, `RDP:480`, `wind:false`) | segmenté « Pente \| Revêtement », 120 px par segment, aligné à gauche. Sémantique « Colorer le profil et le tracé selon ». Colore la carte **et** le profil |
| 4 | Profil altimétrique | `_profile` `RDP:371-375`, `:483-557` → `PdlElevationProfile` | `hasGeometry` ; rien du tout si `samples == null` (pas d'altitude) | **hauteur 140 px** (`PdlMetrics.elevationLarge`, `core/theme/pdl_tokens.dart:118`). Aire colorée par pente des montées, ou par revêtement. Axe : « 0,0 · 11,6 · … · 46,3 km » (unité sur la dernière graduation seulement). Info-bulle « 28,7 km · 74 m · 4,1 % » ou « … · Asphalte ». Crédit sous les graduations : « Données : IGN LiDAR HD, Mapterhorn et ses sources, © OpenStreetMap ». Repères de waypoints dans la bande haute : un toucher ouvre la feuille du point et y place le réticule (`:465-477`). Un glisser déplace le réticule partagé avec la carte. Si `elevationState == PENDING` : au-dessus, « Profil d'altitude provisoire » en xs `textDimmed` (`:582-597`). États « Chargement du profil altimétrique... » et « Profil indisponible » + « Réessayer » (`:546-555`) |
| 4′ | Vide « pas de tracé » | `PdlEmptyState` `RDP:376-382` | `!hasGeometry` (remplace 4) | icône `route`, « Aucune donnée de tracé » / « Ce parcours n'a pas de géométrie enregistrée. Seules ses informations sont disponibles. » |
| 5 | Revêtement | `RouteSurfaceSection` `RDP:385-391` (`W/route_surface_section.dart:105`) | `hasGeometry && (hasTrackSurfaces \|\| trackSurfacesPending)` | **sans titre de section**. Pendant le calcul : seulement « Revêtement en cours de calcul » (xs dimmed). Une fois prêt : `PdlSegmentBar` pleine largeur, puis légende `PdlLegendRow` « Asphalte 72 % · Compacté, gravier 20 % · Terre < 1 % … », puis le lien « © contributeurs OpenStreetMap » (cible 44 px) → openstreetmap.org/copyright. Classes : Asphalte, Revêtement dégradé, Compacté, gravier, Terre, Sentier, Hors réseau, Inconnu |
| 6 | Points du parcours | `RouteWaypointsSection` `RDP:392-400` (`W/route_waypoints_section.dart:20`) | `hasGeometry && waypoints.isNotEmpty` | en-tête « Points du parcours » + compteur. Lignes `PdlWaypointRow` triées le long du tracé, points hors tracé à la fin : pastille de type, distance (« 12,3 km » ou « Hors tracé »), titre = nom (sinon le type), sous-titre = type si nommé, description. Ligne surlignée si sélectionnée. Repli au-delà de 10 lignes : « Voir le point suivant » / « Voir les N autres points », puis « Réduire ». **Toucher** : si la feuille est au-dessus de 0.5, elle redescend à 0.5, puis la carte se centre sur le point (`RDP:452-463`). Pas de feuille modale depuis la liste |
| 7 | Cols et montées | `RouteClimbsSection` `RDP:401-411` (`W/route_climbs_section.dart:21`) | `allClimbs.isNotEmpty` | en-tête « Col ou montée (1) » / « Cols et montées (N) ». `PdlClimbRow` : badge de catégorie en aplat (« HC », « Cat. 1 »…« Cat. 4 », « Montée » sans catégorie), nom = `ClimbDto.name` ou « Montée N », plage « du 12,3 km au 18,9 km », trois chiffres « 540 m D+ », « 6,8 % moy. », « 11,2 % max. ». **Toucher** : réticule au début de la montée (carte et profil) |
| 8 | Utilisée dans | `RouteUsagesSection` `RDP:412-415` (`W/route_usages_section.dart:27`) | rendu seulement si la liste est chargée et non vide. Ni chargement ni erreur visibles (`:40-41`) ; **le Padding de 16 px reste posé même vide** | en-tête « Utilisée dans ». Une `PdlCard` serrée par usage : nom (15 px, 1 ligne), ligne date (icône `date` + date, voir §4), `ZoneMentionLine` éventuelle, « via les groupes : A, B » (sortie) ou « via l'étape J3 » (voyage), badge de type à droite « Sortie » / « Voyage » / « Publication ». Toucher → push `Paths.ride` / `Paths.trip` / `Paths.post` |
| 9 | Informations | `_information` `RDP:416-419`, `:599-650` | toujours | en-tête « Informations ». `PdlInfoLine` « Par » → `createdBy.displayName` (si non nul). « Créé le » → date longue (si `createdAt` lisible). « Équipe propriétaire » → avatar 20 px + nom de l'équipe (sans lien) |
| 10 | Description | `RDP:420-433` | `media.markdown.trim()` non vide | en-tête « Description » + `MarkdownContent` (images incluses) |
| 11 | Pièces jointes | `MediaAttachments` `RDP:436-443` (`core/widgets/media_attachments.dart:76`) | `media.assets.attachments` non vide | en-tête « Pièces jointes » + lignes de fichiers (une image s'ouvre dans `PdlImageViewer`) |
| — | Réserve basse | `padding.bottom = footerInset` | toujours | hauteur mesurée du pied, pour que le dernier bloc ne passe pas dessous |

**2d. Pied fixe** (barre d'actions collée au bas de la feuille, `Positioned` par-dessus le corps, présent à
**tous les crans**) : `SafeArea(top:false)` + marge 16/10/16/8, puis `RouteDownloadActions`
(`RDP:193-204` → `W/route_download_actions.dart:27`) :
- rien du tout si pas de GPX, pas de FIT et aucun service GPS connecté (`:54-56`) ;
- au-dessus de la rangée, le bandeau d'erreur (danger) ou de succès (info, « Fichier enregistré » ou
  « Parcours envoyé avec succès! »), refermable ;
- la rangée : `[Télécharger GPX]` (primaire, icône `gpx`, `Expanded`, « Téléchargement... » pendant
  l'opération) · `[FIT]` (outline, si `assets.fit`) · `[icône appareil]` (outline, sans libellé, si
  `user.connectedServices` non vide) · `[icône partager]` (outline, sans libellé, **toujours**).

### Feuilles modales (`PdlSheet.show`, au-dessus de tout)
- **Fiche d'un point** `WaypointDetails` (`W/waypoint_sheet.dart:44-101`), ouverte depuis la carte ou un repère
  du profil. En-tête : badge du type, petit libellé du type (si nommé), titre = nom ou type. Corps :
  description, puis « À 12,3 km du départ » / « Hors tracé » en mono dimmed. Le point reste allumé tant que
  la feuille est ouverte.
- **« Gérer le parcours »** (`W/route_manage_menu.dart:44-83`), `PdlSettingRow` :
  « Modifier le parcours » (`edit`) · « Remplacer le fichier GPX » (`gpx`, ouvre l'éditeur avec
  `replaceGpx`) · « Supprimer le parcours » (destructif, séparateur après lui si « Signaler » suit) ·
  « Signaler » (si `canReport` : pas l'auteur). Un parcours supprimé n'affiche que « Restaurer le parcours ».
  La suppression passe par une confirmation : « Supprimer le parcours ? » / « « {name} » disparaîtra des
  listes. Le rôle Administrateur de l'équipe pourra le restaurer. ». Ensuite un SnackBar « Parcours
  supprimé » et un pop (sinon `go(Paths.routes)`). La restauration affiche « Parcours restauré ».
- **Modération** « Plus d'actions » → « Signaler » → raison, puis envoi (`features/moderation/presentation/moderation_menu.dart:202`).
- **Destination du fichier** (Android seulement) : « Télécharger le fichier » → « Enregistrer sur le
  téléphone » / « Envoyer vers une autre app ». Sur iOS, la feuille de partage s'ouvre directement
  (`core/utils/share_file.dart:32-55`).
- **« Envoyer vers un appareil »** : la liste des services connectés (`features/routes/presentation/route_export.dart:21-34`).
- **Feuille de partage système** (partager).
- **« Fond de carte »** (PdlMapHero) : fonds et « Ombrage du relief ».

### États hors données
- **Chargement** (`RDP:656-673`) : un vrai `PdlAppBar` (retour seul), puis des squelettes 20×220, 48 et 140.
  **Pas de carte.**
- **Erreur** (`RDP:675-712`) : `PdlAppBar` + `PdlEmptyState`. Cas 404 : « Parcours introuvable » / « Ce
  parcours n'existe pas ou a été supprimé. » + « Retour aux parcours ». Autres cas : titre de l'erreur ou
  « Chargement impossible » + « Réessayer ». Dans les deux cas, `ReportProblemButton`.

---

## 3. Variantes, bloc par bloc

| Bloc | Avec altitude / sans | Waypoints oui / non | Revêtement prêt / en calcul / absent | Gestionnaire (org/admin) | Membre simple | Non-membre / anonyme | Utilisé / non | Supprimé |
|---|---|---|---|---|---|---|---|---|
| Carte | identique (le tracé se dessine en 2D). Sans géométrie : aucun tracé, centre par défaut | symboles présents / absents | Revêtement disponible au sélecteur / pente seule | = | = | = | = | = |
| Barre du haut | = | = | = | ← · pastille · partager · crayon · ⋯ (gestion) | ← · pastille · ⋯ (Signaler) si pas l'auteur ; pas de ⋯ si auteur | anonyme : ← · pastille seulement. Non-membre connecté : ⋯ Signaler (si pas l'auteur) | = | gestionnaire : le crayon disparaît, ⋯ ne propose que « Restaurer » |
| En-tête | stats toujours là ; sans altitude, D+/D− valent ce que dit le serveur (vraisemblablement « 0 m » / « −0 m », non vérifié) | = | = | = | = | = | = | = |
| Interrupteur | sans géométrie : absent | = | **visible seulement si prêt** ; en calcul ou absent : pas d'interrupteur | = | = | = | = | = |
| Profil | **absent sans altitude** (`samples == null` → `SizedBox.shrink`, la marge de 16 reste) ; « Profil d'altitude provisoire » si PENDING ; sans géométrie : état vide | repères présents / absents | aire colorée par revêtement en mode Revêtement | = | = | = | = | = |
| Revêtement | = (exige seulement la géométrie) | = | barre + légende + crédit / « Revêtement en cours de calcul » / rien | = | = | = | = | = |
| Points du parcours | = (exige la géométrie) | liste / rien | = | = | = | = | = | = |
| Cols et montées | dépend des `climbs` calculées par le serveur : probablement vide sans altitude (non vérifié) | les noms viennent des waypoints au sommet ; sinon « Montée N » | = | = | = | = | = | = |
| Utilisée dans | = | = | = | dépend de ce que renvoie `…/usages` (filtrage serveur non vérifié) | idem | idem | cartes / **rien** | — |
| Informations | = | = | = | « Par » présent | « Par » présent | **« Par » absent** (`createdBy` nul pour un non-membre, `RDP:614`) | = | = |
| Description, pièces jointes | = | = | = | = | = | = | = | = |
| Pied | = | = | = | partager **en double** (aussi dans la barre du haut) | = | anonyme : pas de bouton appareil. GPX/FIT selon `media.assets` (accès au fichier non vérifié) | = | = |
| Bandeau supprimé | — | — | — | visible | — | — | — | visible (texte : « Seul le rôle Administrateur… ») |

**États de la feuille**
- **0.18** : poignée + en-tête compact (nom + pratique + 3 stats sans libellé). Le corps est à peine visible,
  et le pied fixe s'y superpose (voir §6). Carte cadrée avec 18 % de marge basse.
- **0.5 (initial)** : en-tête complet (équipe, titre 20 px, deux badges, 3 grandes stats). Le corps commence
  par les tags et l'interrupteur, puis le profil, partiellement visible selon la hauteur.
- **0.92** : idem, liste défilante. Un toucher sur la bande de carte restante redescend d'un cran.

**Météo** : **aucune** sur la fiche parcours. Le mode « Météo » de l'interrupteur est explicitement exclu
(`wind: false`, `RDP:85-89`, `:479-481`). La météo existe seulement dans la version embarquée d'une étape (ci-dessous).

**Réutilisation ailleurs (sans détailler)**
- `EmbeddedRouteSheet` (`W/embedded_route_sheet.dart:41`) n'est utilisé **que** par le détail d'une étape
  (`features/trips/presentation/pages/stage_detail_page.dart:167`), avec les valeurs par défaut
  (`mapHeight: 240`, `showOpenFullAction: true`). Il passe `mapLayer` (vent), `colorBy` partagé avec la
  carte du voyage, `offersWind`, `windLeg` et **`beforeClimbs: StageWeatherCard`**. Son ordre diffère de
  l'écran 13 : en-tête figé `RouteSheetHeader(extent: 1)` → **carte 240 px** (vignette non interactive, bouton
  plein écran) → interrupteur **sous la carte** (Pente | Revêtement | Météo) → profil 140 px → revêtement →
  points → **actions de téléchargement (en ligne, pas collées)** → météo de l'étape → cols (non touchables :
  pas de `onTapClimb`) → « Voir la fiche complète ». Pas de tags, pas d'usages, pas d'informations, pas de
  description, pas de bandeau supprimé.
- Les sorties (`features/rides/…`) **ne réutilisent pas** `RouteMap` ni `EmbeddedRouteSheet`. Elles prennent
  des morceaux : `RouteColorModeSwitch` (`ride_detail_page.dart:644`, `ride_groups_map.dart:358`,
  `ride_group_overview_tab.dart:111`, `ride_elevation_section.dart:167`), `RouteSurfaceSection` et
  `RouteWaypointsSection` (`ride_elevation_section.dart:255-259`), plus la sélection et la fiche des points
  (`waypoint_selection.dart`, `waypoint_sheet.dart`).

---

## 4. Dates et heures

La fiche parcours affiche **deux familles** : la date de création, qui est un horodatage, et les dates des
usages, qui sont des rendez-vous. Elle n'affiche **aucune durée estimée**, aucune heure d'arrivée et aucun
`updatedAt`.

| Emplacement | Champ source | Formatage (`fichier:ligne`) | Format produit (exemple FR) | Fuseau | Cas particuliers |
|---|---|---|---|---|---|
| Informations · « Créé le » | `RouteDetailDto.createdAt` (ISO UTC) | `AppFormatters.tryParseDisplayTime` (`core/utils/formatters.dart:443`), puis `formatLongDate` (`:610`) = `formatFullDate` (`:598`, `DateFormat.EEEE` + jour + `MMMM` en minuscules) + année | « lundi 15 janvier 2026 » (sans heure) | **horodatage** : fuseau de l'utilisateur (`UserDto.timezone`), sinon celui de l'appareil (`toDisplayTime`, `:411`) | ligne absente si la date est illisible. Toujours absolue, jamais « il y a… » |
| — `updatedAt` | `RouteDetailDto.updatedAt` | **non affiché** (aucune lecture dans `features/routes`) | — | — | — |
| Utilisée dans · usage de type **sortie** (ou voyage sans `endDate`, ou publication) | `RouteUsageDto.dateTime` + `timezone` | `AppFormatters.formatDeparture` (`formatters.dart:710`) → `dates.departureAt` « {date} · {time} » ; date = `formatDepartureRelative` (`:669`) sinon `formatDepartureDate` (`:689`, `DateFormat.MMMEd`, ou `yMMMEd` hors de l'année en cours) ; heure = `formatTime` (`:586`, `Hm` ou `jm` selon le réglage 12/24 h du téléphone) | « sam. 11 oct. · 08:00 » ; « Aujourd'hui · 09:00 » ; « Demain · 09:00 » ; « sam. 10 avr. 2027 · 09:00 » ; en 12 h « … · 8:00 AM » | **rendez-vous** : fuseau de l'entité (`usage.timezone`, `toZoneTime` `:462`). « Aujourd'hui » et l'année en cours sont jugés dans ce fuseau | un usage **passé** s'affiche au même format, sans marque « passé » (aucun relatif pour hier) |
| Utilisée dans · usage de type **voyage** avec `endDate` | `dateTime`, `endDate`, `timezone` | `tripDaySpan` (`features/teams/domain/publication_timing.dart:41-67`) ; repli `formatDepartureDate` | même jour : « ven. 16 oct. » ; même mois : « ven. 16 → dim. 18 oct. » ; mois différents : « ven. 30 oct. → dim. 1 nov. » (**sans heure**) | fuseau de l'entité, le même pour le début et la fin (`endTimezone` non fourni) | pas de relatif « Aujourd'hui » dans une plage |
| Utilisée dans · mention de fuseau (2ᵉ ligne) | `dateTime`, `timezone` | `ZoneMentionLine.maybe` (`core/widgets/zone_mention_line.dart:19`) → `formatZoneMention` (`formatters.dart:557`) : `dates.zoneMentionWithLocal` « {zone} ({local}) », `zoneMention` « heure {ofCity} », `readerEquivalent` (`:542`) « {time} chez vous », préfixé de l'abréviation du jour si le jour diffère | « heure de Tokyo (ven. 01:00 chez vous) » | rien si les décalages UTC de l'entité et du lecteur sont égaux à cet instant (`sameOffsetAt`, `:512`) | calculée sur `dateTime` seul, y compris pour un voyage affiché en plage sans heure |
| Feuille de point, liste des points, montées | `WaypointDto.distance`, `ClimbDto.startDistance/endDistance` | `formatDistance` | — (des distances, pas des temps) | — | — |

Aucune autre date ni heure n'est rendue : pas de durée de parcours, pas de vitesse, pas de date de mise à jour,
pas de date du fichier GPX.

---

## 5. Wireframes ASCII (téléphone portrait, ≈ 440 × 956 pt)

### 5.1 Cran initial 0.5 — gestionnaire, parcours complet (revêtement prêt, waypoints, montées, usages)
```
┌──────────────────────────────────────────┐
│ [←] (  Boucle des Monts d'Arrée  ) [⇪][✎][⋯]│  ← barre flottante (couche 1)
│                                          │
│        ~~~ CARTE plein écran ~~~         │  ← couche 0 : tracé coloré, bornes km,
│      (S)───╮   ⚑waypoint                 │    départ/arrivée, symboles, réticule
│            ╰──(5)──╮                 [≡] │  ← bouton « Fond de carte », centré
│                    ╰─(10)──(A)           │    verticalement sur l'écran
├════════════════ ▬▬▬ ═════════════════════┤  ← poignée (feuille à 50 %)
│ (o) Les Rouleurs du Léon  ›              │  ← PdlTeamLine
│ Boucle des Monts d'Arrée      [Route]    │  ← titre 20 px + badges empilés
│                               [◎ Équipe] │
│ ↔ 46,3 km    ↗ 1 108 m    ↘ −1 108 m     │  ← 3 grandes stats
│ Distance     Dénivelé pos. Dénivelé nég. │
│ ─ ─ ─ ─ ─ ─ (corps défilant) ─ ─ ─ ─ ─ ─ │
│ #boucle #col                             │  ← tags
│ [ Pente | Revêtement ]                   │  ← interrupteur
│ ▁▂▃▅▇▆▄▂▁▂▄▆▇▅▃▁  (profil 140 px)        │  ← profil + repères + réticule
│ 0,0 · 11,6 · 23,2 · 34,7 · 46,3 km       │
│ Données : IGN LiDAR HD, …                │
├──────────────────────────────────────────┤  ← pied fixe (par-dessus le corps)
│ [⤓ Télécharger GPX ][FIT][⌚][⇪]          │
└──────────────────────────────────────────┘
```
### 5.2 Cran 0.92 (corps défilé) — même parcours
```
┌──────────────────────────────────────────┐
│ [←] (  Boucle des Monts d'Arrée  ) [⇪][✎][⋯]│  ← barre flottante sur ~8 % de carte
├════════════════ ▬▬▬ ═════════════════════┤
│ (o) Les Rouleurs du Léon  ›              │
│ Boucle des Monts d'Arrée   [Route][Équipe]│
│ ↔ 46,3 km    ↗ 1 108 m    ↘ −1 108 m     │
│ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │
│ [ Pente | Revêtement ]                   │
│ ▁▂▃▅▇▆▄▂▁▂▄▆▇▅▃▁  (profil)               │
│ ████████▓▓▓▓░░  (barre de revêtement)    │  ← Revêtement, sans titre
│ ● Asphalte 72 % ● Compacté, gravier 20 % │
│ © contributeurs OpenStreetMap            │
│ POINTS DU PARCOURS                    7  │
│ [☕] 12,3 km  Café du Roc · Café, pause  │
│ [⚠] 18,0 km  Danger                      │
│ …  Voir les 2 autres points              │
│ COLS ET MONTÉES (3)                      │
│ [Cat. 2] Roc'h Trévézel  du 12,3 au 18,9 km│
│          540 m D+ · 6,8 % moy. · 11,2 % max.│
│ UTILISÉE DANS                            │
│ ┌ Sortie du dimanche        [Sortie] ┐   │
│ │ 📅 sam. 11 oct. · 08:00           │   │
│ │ via les groupes : A, B            │   │
│ └───────────────────────────────────┘   │
│ INFORMATIONS                             │
│ Par                        Léa Martin    │
│ Créé le        lundi 15 janvier 2026     │
│ Équipe propriétaire  (o) Les Rouleurs…   │
│ DESCRIPTION                              │
│ Texte markdown…                          │
│ PIÈCES JOINTES                           │
│ roadbook.pdf                    [⤓]      │
├──────────────────────────────────────────┤
│ [⤓ Télécharger GPX ][FIT][⌚][⇪]          │
└──────────────────────────────────────────┘
```
### 5.3 Cran 0.18 — compact (membre simple, pas l'auteur)
```
┌──────────────────────────────────────────┐
│ [←] (  Boucle des Monts d'Arrée  )   [⋯] │  ← ⋯ = « Signaler »
│                                          │
│          ~~~ CARTE (≈82 %) ~~~           │
│                                      [≡] │
│                                          │
│                                          │
├════════════════ ▬▬▬ ═════════════════════┤  ← ~172 pt de feuille
│ Boucle des Monts d'Arrée        [Route]  │  ← en-tête compact
│ ↔ 46,3 km  ↗ 1 108 m  ↘ −1 108 m         │
│ [⤓ Télécharger GPX ][FIT][⇪]             │  ← pied fixe, superposé (voir §6)
└──────────────────────────────────────────┘
```
### 5.4 Anonyme, parcours sans revêtement, sans waypoints, sans altitude, non utilisé (cran 0.5)
```
┌──────────────────────────────────────────┐
│ [←] (  Boucle des Monts d'Arrée  )       │  ← aucun bouton à droite
│          ~~~ CARTE ~~~               [≡] │
├════════════════ ▬▬▬ ═════════════════════┤
│ (o) Les Rouleurs du Léon  ›              │
│ Boucle des Monts d'Arrée  [Route][Public]│
│ ↔ 46,3 km    ↗ 0 m (?)    ↘ −0 m (?)     │
│ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │
│ (pas d'interrupteur, pas de profil :     │
│  marge vide de 16 px)                    │
│ INFORMATIONS                             │
│ Créé le        lundi 15 janvier 2026     │  ← pas de « Par »
│ Équipe propriétaire  (o) Les Rouleurs…   │
├──────────────────────────────────────────┤
│ [⤓ Télécharger GPX ][⇪]                  │  ← si gpx servi ; pas d'appareil
└──────────────────────────────────────────┘
```
### 5.5 Sans géométrie
Même structure, mais : carte sans tracé (centre par défaut), pas d'interrupteur, et à la place du profil
l'état vide « Aucune donnée de tracé / Ce parcours n'a pas de géométrie enregistrée… ». Pas de revêtement ni
de points. Les cols s'affichent seulement s'il y a des `climbs`, ce qui est peu probable.

### 5.6 Supprimé (gestionnaire, cran 0.5)
Barre : `[←] (titre) [⇪] [⋯]` (pas de crayon). Premier bloc du corps : bandeau warn « Ce parcours est
supprimé. Seul le rôle Administrateur de l'équipe le voit. ». `⋯` → « Restaurer le parcours » seul.

### 5.7 Chargement / erreur
Une `PdlAppBar` classique `[←]`, puis des squelettes (20 × 220, 48, 140), ou l'état vide d'erreur. Pas de carte.

---

## 6. Étonnements

1. **Barre d'échelle et crédit ⓘ toujours masqués.** `PdlMapScaleBar` (bas gauche) et `PdlMapAttribution`
   (bas droite) sont alignés en bas de la carte, qui occupe tout l'écran. La feuille, au minimum à 18 %,
   couvre ce bas en permanence : sur l'écran 13, la barre d'échelle (ajoutée au commit `0fe23357a`) et
   l'accès au crédit des tuiles ne devraient **jamais** être visibles. C'est déduit de la mise en page, non
   vérifié à l'écran. Le crédit est une obligation de licence.
2. **Bouton « Fond de carte » centré sur la hauteur de l'écran** (`pdl_map_hero.dart:350-355`). Au cran initial
   0.5, son centre tombe exactement sur le bord haut de la feuille, qui est peinte par-dessus : il serait à
   moitié recouvert. À 0.92 il est entièrement caché. Déduit du code, non vérifié.
3. **Le pied fixe au cran 0.18.** La feuille fait environ 172 pt : poignée, en-tête compact (environ 90 pt),
   puis le pied (environ 10 + 44 + 8 + 34 pt de zone sûre). Le pied est un `Positioned(bottom:0)` qui
   **recouvre** le contenu au lieu de le pousser : il risque de chevaucher les stats compactes. À vérifier
   sur simulateur.
4. **Nom du parcours affiché deux fois** à tous les crans : dans la pastille de la carte et dans l'en-tête de la feuille.
5. **Équipe affichée deux fois** : `PdlTeamLine` cliquable dans l'en-tête (`MOB-90`) et « Équipe propriétaire »
   non cliquable dans « Informations ».
6. **Partager deux fois pour un gestionnaire** : bouton de la barre du haut et icône du pied (le commentaire
   `RDP:250-252` l'assume).
7. **Pas de commentaires sur le mobile.** Le DTO porte `commentCount`, et le site affiche une
   `CommentSection` aux membres (`frontend/src/pages/route/RouteDetailPage.tsx:190-193`). La fiche mobile n'a
   aucun fil de commentaires, alors que sortie, publication, voyage et étape en ont un (`CommentThread`).
8. **Carte en fond et non « au plus tôt dans la page »** : la disposition est inversée par rapport à une page
   qui défile. La carte n'est pas un bloc de la liste ; à 0.92 il en reste environ 8 %, et le profil n'est
   lisible qu'en remontant la feuille. Dans l'étape (`EmbeddedRouteSheet`), la carte est au contraire un bloc
   de 240 px sous l'en-tête. **Les deux présentations du même parcours diffèrent** : position de
   l'interrupteur (en tête de feuille ici, sous la carte dans l'étape), téléchargements collés ici et en
   ligne là-bas, cols touchables ici et pas là-bas, et pas de tags, usages, informations ni description dans
   l'étape. Le commentaire « toute divergence est un défaut » (`embedded_route_sheet.dart:35-37`) n'est donc
   plus vrai.
9. **Formats de date hétérogènes sur le même écran** : « lundi 15 janvier 2026 » (jour et mois complets en
   minuscules, sans heure) pour la création, contre « sam. 11 oct. · 08:00 » (abrégé, sans année dans
   l'année en cours, avec « Aujourd'hui »/« Demain ») pour les usages. Les deux fuseaux diffèrent aussi
   (lecteur pour l'un, entité pour l'autre), conformément à la règle.
10. **Mention de fuseau avec une heure sous une plage sans heure** : un voyage s'affiche « ven. 16 → dim.
    18 oct. », mais `ZoneMentionLine.maybe(usage.dateTime, …)` peut ajouter « heure de Tokyo (ven. 01:00
    chez vous) ». Cette ligne cite une heure de départ que la ligne au-dessus ne montre pas.
11. **Usages passés indiscernables** : aucune marque « passé » ; une sortie d'il y a deux ans s'affiche
    « sam. 10 avr. 2024 · 09:00 », au même rang que la prochaine. L'ordre est celui du serveur, non vérifié.
12. **`updatedAt` jamais affiché**, alors que le DTO le fournit et que le profil et le revêtement peuvent
    être recalculés.
13. **États du profil peu atteignables** : `routeElevationSamplesProvider` dérive du détail, qui est déjà
    chargé quand le profil se construit. Les états « Chargement du profil altimétrique... » et « Profil
    indisponible » ne devraient presque jamais apparaître. Le bouton « Réessayer » de ce dernier recharge
    tout le détail.
14. **Marges fantômes** : `RouteUsagesSection` (sans usage) et le profil (`samples == null`) rendent
    `SizedBox.shrink()` mais restent enveloppés dans un `Padding(bottom: 16)` (`RDP:371-375`, `:412-415`).
    Il reste donc 16 px vides, contrairement au revêtement, dont le commentaire `RDP:383-384` dit éviter
    justement ce cas.
15. **Revêtement sans titre de section**, alors que points, cols, usages, informations et description en ont
    un. La légende ne dit pas « Revêtement ». L'interrupteur, lui, n'apparaît qu'une fois le revêtement
    prêt : pendant le calcul, on lit « Revêtement en cours de calcul » sans interrupteur.
16. **Stats d'un parcours sans altitude** : le profil disparaît, mais l'en-tête affiche toujours D+ et D−
    (probablement « 0 m » / « −0 m », non vérifié côté serveur). Le signe « − » est ajouté par le client
    devant `abs()`, même pour zéro.
17. **Badge de pratique en double au cran compact → complet**, et le badge de visibilité n'existe qu'en
    composition complète. Un membre ne voit donc la visibilité qu'au-delà de 0.34.
18. **Le `⋯` disparaît pour l'auteur non gestionnaire** (rien à signaler à soi-même) : il n'a alors
    **aucune** action sur son propre parcours. Il ne peut ni le modifier ni le supprimer, ce qui est cohérent
    avec `canManage` mais peut surprendre.
19. **Toucher un point de la liste ≠ toucher un point de la carte** : la liste centre la carte sans ouvrir
    de feuille, alors que la carte et le profil ouvrent la fiche du point.
20. **`canManageRoutesProvider` renvoie `null` tant que l'équipe se charge** (`?? false`, `RDP:226-227`) : les
    boutons de gestion peuvent apparaître après coup. C'est déduit du type, non vérifié.
