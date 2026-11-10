# Web — page de détail d'un PARCOURS (route)

Périmètre : `frontend/` (React/Mantine), lecture seule du code, rien n'a été exécuté. Chemins relatifs à
`frontend/src/`. Les libellés FR viennent de `locales/fr/common.json`.

**À retenir d'abord : la page parcours n'affiche aucune météo.** Ni `RouteWeather*`, ni `RouteVerdicts`,
ni le mode « Météo » de la carte. Il n'y a ni heure de départ ni sélecteur. Le client n'appelle aucun
endpoint météo de parcours (`api/endpoints/routes/routes.ts` n'en contient pas). La météo sur un tracé
n'existe que sur un groupe, une sortie solo, une étape ou un voyage (tracé d'un événement daté), et dans
l'aperçu GPX (`components/gpxtool/GpxPreviewWeatherSection.tsx`, qui demande une `departureTime`).
Voir §2 « Réutilisations » et §6.

---

## 1. Points d'entrée

| Élément | Valeur |
|---|---|
| Route web détail | id `route-detail`, `contracts/routes.yaml:726` : FR `/equipes/{teamSlug}/parcours/{routeSlug}`, EN `/teams/{teamSlug}/routes/{routeSlug}` (`web`, `mobile`, `deeplink` à true) |
| Déclaration | `config/routes.config.ts:981-993` : `auth: 'public'`, `parentId: 'routes'` (lui-même enfant de `team-detail`), fil d'Ariane dynamique `entity: 'route'`, `meta: routeMeta` (OG) |
| Page | `pages/route/RouteDetailPage.tsx` |
| Route plein écran | id `route-map`, `contracts/routes.yaml:736` : FR `/equipes/{teamSlug}/parcours/{routeSlug}/carte`, `web` seulement (pas de mobile ni de deeplink). `routes.config.ts:994-1004`, `layout: 'bare'` (sans AppShell) ; page `pages/route/RouteFullscreenMapPage.tsx` |
| Paramètre d'URL | `?color=grade\|surface\|wind` (`hooks/filters/mapColorFilters`), lu par `useWindColorMode` (page) et `MapColorFullscreenView` (plein écran). Le lien plein écran le reprend : `withMapColor(paths.routeMap(...), colorBy)` (`RouteDetailPage.tsx:186`) |

**Données** (`pages/route/routeDetailData.ts`) :
- `useGetTeam(teamSlug)` → `TeamDto`. La page en lit `slug`, `name`, `about` (bandeau) et `role` (droits, via `teamAccess`).
- `useGetRoute(teamSlug, routeSlug)` → `RouteDetailDto`, relu toutes les 30 s tant que `elevationState === PENDING`, 15 min au plus (`hooks/useElevationRefetchInterval.ts`).
- Chargés par les enfants :
  - `useGetRouteUsages` (`RouteUsages`) → `RouteUsagesResponse.usages: RouteUsageDto[]` ;
  - les commentaires (`CommentSection`, membres seulement) ;
  - les services GPS connectés (`useGpsConnections`, connecté seulement).
- Prefetch SSR (`prefetchRouteDetail`) : team, route, usages, services GPS si connecté, puis commentaires si membre.
- Plein écran : team + route seulement (`prefetchRouteMap`).

`RouteDetailDto` (`api/dto/routeDetailDto.ts`) contient :
- identité : `id, slug, team, name, media` ;
- chiffres : `distance, elevationGain, elevationLoss, elevationState (PENDING|HD|FAST), surfaceType, visibility` ;
- `start?, end?, createdBy?, createdAt, updatedAt` ;
- `tracks[] (line, climbs[], surfaceState?, surfaces?)`, `waypoints[]` ;
- `deleted, commentCount?, tags[]`.

`RouteUsageDto` contient `type (RIDE|TRIP), slug, name, dateTime, timezone, endDate?, teamSlug,
referencedDirectly, viaChildNames[]`.

## 2. Disposition

Il n'existe **qu'une seule colonne, à toutes les largeurs**. La page entière est une `Box maw={1280} mx="auto" px="md" py="xl"`
(`RouteDetailPage.tsx:111`). Il n'y a ni grille à colonnes, ni bloc sticky, ni onglets. Ce qui change en étroit est
signalé dans la colonne « Étroit ».

### Desktop (ordre réel, de haut en bas)

| # | Bloc | Composant `fichier:ligne` | Condition | Contenu exact | Actions | Étroit |
|---|---|---|---|---|---|---|
| 0 | Fil d'Ariane (layout) | `components/common/Layout.tsx:360` → `Breadcrumb.tsx:97-108` | toujours (layout normal) | chaîne `parentId` : … équipe › « Parcours » (`nav.routes`) › nom du parcours. Les libellés exacts des niveaux supérieurs n'ont pas été vérifiés | liens | < `sm` : seulement les 2 derniers niveaux (`compactItems`, `hiddenFrom="sm"`) |
| 1 | Bandeau équipe | `TeamContextBanner` `RouteDetailPage.tsx:113` (`components/team/TeamContextBanner.tsx`) | toujours | `Paper` bordé : avatar d'équipe (`TeamAvatar` sm), nom d'équipe (1 ligne), chevron droit `IconChevronRight`. aria « Voir la page de l'équipe {{name}} » | lien vers `paths.team` | identique |
| 2 | En-tête : logo + titre | `RouteDetailPage.tsx:118-122` | toujours. Logo seulement si `media.assets.logo` (`EntityLogo` n'a pas de repli) | `EntityLogo size="lg"` + `Title order=1` = `route.name` | — | le groupe d'actions (bloc 4) passe dessous (`wrap="wrap"`, `mt={{ base: 'md', sm: 0 }}`) |
| 3 | Description (sous le titre, même colonne gauche de l'en-tête) | `MediaDisplay` `RouteDetailPage.tsx:123` (`components/common/MediaDisplay.tsx`) | toujours monté. Rendu vide si pas de markdown | Markdown avec images. Puis, si `attachments.length > 0` : cadre « Pièces jointes » (icône trombone), une ligne par fichier (vignette ou trombone, nom, taille si connue, `IconDownload`) | liens de téléchargement des PJ (nouvel onglet) | identique |
| 4 | Actions d'en-tête (à droite) | `RouteDetailPage.tsx:125-166` | voir ci-dessous | Dans l'ordre : **Modifier** (`variant=default`, si `canEdit`) ; **Restaurer** (outline vert, si `canEdit && deleted`) **ou** **Supprimer** (outline `danger`, si `canEdit && !deleted`) ; **Partager** (`ShareButton`, `ActionIcon` `IconShare`, toujours) ; menu **⋯** (`ContentActionsMenu`, `IconDots`) contenant « Signaler » (`IconFlag`), seulement si connecté et non créateur | Modifier → `paths.routeEdit` (balise `<a href>`, rechargement complet) ; Supprimer → `ConfirmDialog` « Supprimer le parcours » / « Voulez-vous vraiment supprimer ce parcours ? Cette action est irréversible. », puis redirection vers la liste et toast « Parcours supprimé avec succès » ; Restaurer → toast « Parcours restauré avec succès » ; Partager → `navigator.share` ou copie avec toast « Lien copié » ; Signaler → modale, puis redirection vers la liste | passe sous le titre |
| 5 | Carte + profil altimétrique | `RouteDetailView.tsx:92-103` → `RouteMapView.tsx:149-214` → `RouteTrackMap.tsx` + `ElevationChart.tsx` | toujours. Sans points : encart gris « Aucune donnée de tracé disponible pour ce parcours » (`RouteMapView.tsx:117-127`) | `Paper` bordé. **Carte** de hauteur `clamp(300px, 52svh, 560px)` (`hooks/useResponsive.ts:93`, variante `full`) : tracé épais (8 px, opacité 0,8) coloré par la pente ou le revêtement, chevrons de sens, marqueurs départ (vert) et arrivée (rouge), pastilles km, waypoints (symboles typés, étiquettes à partir d'un certain zoom), marqueur bleu de survol. Contrôles en colonne en haut à gauche : zoom/boussole, sélecteur de fond de carte (+ relief/3D si une source existe), masquer le tracé (touche « h »), bouton « Carte plein écran » (`IconArrowsMaximize`). Barre d'échelle et attribution (`PedalonsMap`). **Profil** *sous* la carte, bande de 160 px (`profilePlacement='below'`, `RouteMapView.tsx:202-212`) : courbe remplie colorée, axes « Distance (km) » / « Elevation (m) », marqueurs des waypoints sur le tracé, crédit en haut à droite « Données : IGN LiDAR HD, Mapterhorn et ses sources, © OpenStreetMap ». Info-bulle du profil : titre = distance ; ligne = altitude (+ « (x.x%) ») ; lignes « Montée (i/n) : {gain} / {dist} ({pente}%) » ou « {nom} (i/n) : … », puis « Partie (j/m) : … » ; pied = waypoints proches, « {type} : {nom} » | survol croisé carte ↔ profil ; zoom/pan du profil synchronisé avec la carte (`useMapChartZoomSync`) ; clic sur un waypoint (carte ou profil) → popup `WaypointDetails` ; plein écran | même rendu ; seule la hauteur varie via `svh` |
| 5a | Popup waypoint (sur la carte) | `components/map/WaypointLayer.tsx:147-158` → `WaypointDetails.tsx` | waypoint sélectionné | pastille d'icône typée colorée, libellé du type (ex. « Ravitaillement »), nom en gras, description (sauts de ligne gardés), « À 12.3 km du départ » ou « Hors tracé ». Largeur max 280 px | fermer | identique |
| 6 | Mention profil provisoire | `RouteDetailView.tsx:105-109` | `elevationState === PENDING` | texte xs atténué « Profil d'altitude provisoire » | — | identique |
| 7 | Contrôles de couleur + revêtement | `ColorModeControls` `RouteDetailView.tsx:112-117` → `ColorByControl.tsx` + `RouteSurfaceSummary.tsx` | sélecteur seulement si ≥ 2 modes, donc si le revêtement est prêt. Résumé : prêt → barre + légende ; en calcul → « Revêtement en cours de calcul » ; sinon rien | `SegmentedControl` xs « Pente \| Revêtement » (aria « Colorer le profil et le tracé selon »). Barre `Progress` segmentée par classe (info-bulle « Asphalte 72 % »). Légende en traits de couleur : Asphalte, Revêtement dégradé, Compacté, gravier, Terre, Sentier, Inconnu, Hors réseau, avec « N % » ou « < 1 % ». Lien « © contributeurs OpenStreetMap » | change `?color=` | identique |
| 8 | Téléchargements / envoi | `RouteDetailView.tsx:120-172` | `showDownload` (true ici) **et** (`assets.gpx` ou `assets.fit`) | boutons `default sm` : « Télécharger GPX » et « Télécharger FIT » (`IconDownload`), selon présence. Menu « Envoyer vers l'appareil » (`IconDeviceMobile`, loader pendant l'envoi) → « Garmin Connect » / « Wahoo » / « Hammerhead » | liens directs vers les fichiers ; upload vers le service | `wrap` |
| 9 | Statistiques | `RouteDetailView.tsx:175-211` | toujours | 3 couples icône + libellé atténué xs + valeur lg grasse : `IconMap` (couleur primaire) « Distance » `123.4 km` ; `IconArrowUp` (vert) « Dénivelé positif » `1850 m` ; `IconArrowDown` (rouge) « Dénivelé négatif » `1850 m` | — | `wrap` |
| 10 | Infos : badges + date | `RouteDetailView.tsx:214-232` | `showInfo` (true ici) | badge vert light lg du type de revêtement déclaré (« Route », « Gravel », « VTT », « Mixte »), si `surfaceType` ; badge gris de visibilité (« Public », « Non répertorié », « Équipe uniquement ») ; texte sm atténué « Créé le: 3 novembre 2026 » | — | `wrap` |
| 11 | Tags | `TagList` `RouteDetailView.tsx:235` (`components/tag/TagList.tsx`) | `showInfo` et `tags.length > 0` | puces `Badge variant="dot"` couleur de famille, libellé dans sa casse, tous les tags | — | `wrap` |
| 12 | Points du parcours | `RouteWaypointList.tsx:36-120` (appelé `RouteDetailView.tsx:237`) | `waypoints.length > 0` | `Title order=4` « Points du parcours (N) ». Liste triée (sur le tracé par distance, hors tracé à la fin). Chaque ligne : distance (78 px, chiffres tabulaires) ou « Hors tracé » ; pastille d'icône typée ; nom en 500 + type atténué xs (ou type seul si pas de nom) ; description sur 2 lignes max. Repli après 10 : « Voir le point suivant » / « Voir les N autres points » / « Réduire » | clic → sélectionne le point (popup sur la carte) + défile jusqu'à la carte (`useWaypointSelection`) | identique |
| — | `beforeClimbs` | `RouteDetailView.tsx:243` | jamais fourni par `RouteDetailPage` | — | — | — |
| 13 | Cols et montées | `RouteDetailView.tsx:246-319` | au moins 1 montée sur l'ensemble des tracks | `Title order=4` « Cols et montées (N) ». Par montée (ligne séparée) : badge de catégorie (« Hors Catégorie », « 1ère Catégorie »… « 4ème Catégorie », couleurs `CLIMB_CATEGORY_COLORS`), nom (`climb.name`, sinon « Montée N »), « De 12.3 km à 18.9 km », puis « Dénivelé: 540 m », « Pente moyenne: 6.2% », « Pente maximale: 11.0% » | — | `wrap` |
| 14 | Commentaires | `CommentSection` `RouteDetailPage.tsx:191-201` | `isMember \|\| isPlatformAdmin` | « Commentaires (N) », formulaire, fil (avatar, nom, date relative, texte, Répondre, Supprimer, ⋯), « Charger plus » | commenter, répondre, supprimer (selon droits), signaler | identique |
| 15 | Utilisée dans | `RouteUsages.tsx:62-103` (appelé `RouteDetailPage.tsx:206`) | chargement : titre + 2 squelettes ; **0 usage → rien** | `Title order=2` « Utilisée dans ». Grille de cartes `SimpleGrid cols={{ base: 1, sm: 2 }}`. Chaque carte : nom (tronqué) + `TypeBadge` « Sortie » ou « Voyage » ; puis `DepartureLine` (horloge `IconClock` indigo pour une sortie, turquoise pour un voyage, texte gras) : sortie « sam. 14 nov. · 08:30 », voyage « ven. 16 mai → dim. 18 mai » ; icône globe (`IconWorld`) avec info-bulle de zone si le fuseau diffère de celui du lecteur ; ligne atténuée « via les groupes : A, B » ou « via les étapes : … » | carte cliquable → sortie ou voyage | 1 colonne < `sm` |

Note : `DetailPageSkeleton` s'affiche pendant le chargement. Une 404 affiche « Parcours introuvable » / « Le parcours que vous recherchez n'existe
pas. » + « Retour aux parcours » (`RouteDetailPage.tsx:87-108`).

### Viewport étroit

Même ordre, même colonne. Les seules différences :
- le fil d'Ariane est raccourci ;
- les actions d'en-tête passent sous le titre ;
- les groupes `wrap` (téléchargements, statistiques, badges, montées) passent à la ligne ;
- « Utilisée dans » passe à 1 colonne ;
- la carte suit `52svh` (300 à 560 px) ; le profil reste à 160 px sous la carte.

### Plein écran `/carte` (`RouteFullscreenView.tsx`, coque `components/map/MapFullscreenShell.tsx`)

1. Barre d'outils de 48 px :
   - « Retour » (`IconArrowLeft`), qui revient dans l'historique ou remplace l'URL avec `?color=` ;
   - nom du parcours tronqué. **Pas de sous-titre** : `departure` n'est pas passé (`RouteFullscreenMapPage.tsx:41-45`) ;
   - stats `IconRoute` distance, `IconArrowUp` D+ et `IconArrowDown` D− (**D+ et D− masqués sous `sm`**, `MapFullscreenShell.tsx:76-87`) ;
   - `ColorByControl` « Pente \| Revêtement » (si le revêtement est prêt).
2. Carte plein écran (100dvh moins la barre et le profil), mêmes couches et contrôles, sans bouton plein écran.
3. Profil de 160 px épinglé en bas (`filled`).

Il n'y a jamais de légende vent ici : pas de `windLeg`.

### Réutilisations (sans détail)

- `RouteDetailView` n'est **utilisé que par `RouteDetailPage`** (grep `<RouteDetailView` : une seule occurrence). Sa docstring (`RouteDetailView.tsx:56-59`) et ses props `windLeg/windAttribution/timezone/beforeClimbs` parlent encore de `StageDetailPage`, mais cette page utilise désormais `RouteMapPanel`.
- `RouteMapPanel` (`components/route/RouteMapPanel.tsx`) sert à `RideGroupPage.tsx:289`, `RideDetailPage.tsx:344` (sortie solo) et `StageDetailPage.tsx:205`. Il contient :
  - la carte, avec le profil **superposé** (`profilePlacement="overlay"`) ;
  - « Profil d'altitude provisoire » ;
  - `ColorModeControls` avec le mode Météo si `leg` ;
  - `RouteWaypointList` ;
  - un cadre « routeTitle » + `RideGroupRouteActions` (voir, GPX, FIT, envoi).

  Il n'a **pas** les stats, les badges, la date de création, les tags ni les montées.
- La météo de tracé (`RouteWeatherSection` → `RouteWeather` → `RouteVerdicts`) est utilisée par `GroupWeatherSection`, `StageDetailPage.tsx:225`, `TripDetailPage.tsx:242` et l'aperçu GPX (`GpxPreviewWeatherSection.tsx:93`).
- `MapColorFullscreenView`/`RouteFullscreenView` servent aussi aux pleins écrans de sortie, de groupe, d'étape et d'aperçu GPX.
- `RouteMapView`, `ColorModeControls` et `RouteWaypointList` sont repris par `components/gpxtool/GpxPreviewView.tsx:162/173/222`.
- `RoutePreview` (vignette 64 px clair/sombre, nom, `IconArrowsMaximize` distance, `IconArrowUp` D+) et `RoutePreviewCompact` (« nom (distance, D+) ») servent seulement aux formulaires `RideEditor.tsx:401/582` et `TripEditor.tsx:474/626`.

## 3. Variantes

| Variante | Effet bloc par bloc |
|---|---|
| **Altitude** | Le front n'a **aucune branche « sans altitude »** : le profil est toujours tracé à partir de `coordinates[i][2]`. Côté backend, `ElevationState` (PENDING/HD/FAST, `backend/.../enums/ElevationState.java`) suppose une altitude toujours calculée : profil rapide d'abord, HD ensuite. Je n'ai pas vérifié ce que donne un GPX sans altitude si le calcul échoue. `PENDING` → mention « Profil d'altitude provisoire » + relecture toutes les 30 s ; le profil se remplace sans recadrer la carte (`RouteTrackMap.tsx:141-154`). Sans montée, le bloc 13 disparaît et l'info-bulle n'a plus de lignes « Montée ». Sans aucun point de tracé, la carte est remplacée par l'encart « Aucune donnée de tracé… » et le profil disparaît avec elle. Les stats restent affichées |
| **Waypoints** | Aucun → pas de bloc 12, pas de symboles sur la carte, pas de marqueurs sur le profil. Hors tracé (`distance == null`) : sur la carte et dans la liste (en fin, « Hors tracé »), absents du profil. Plus de 10 → repli « Voir les N autres points » |
| **Revêtement** (`tracks[].surfaceState`/`surfaces`) | Prêt → sélecteur « Pente \| Revêtement » (bloc 7 et plein écran) + barre, légende et crédit OSM ; profil et tracé colorés par revêtement si `?color=surface`. En calcul (`PENDING`) → seulement « Revêtement en cours de calcul », pas de sélecteur. Absent → rien (le bloc 7 est vide). Un `?color=surface` ou `?color=wind` impossible se lit comme la pente. Le badge « Route/Gravel/VTT/Mixte » (bloc 10) est indépendant : c'est le type **déclaré** `surfaceType`, pas l'analyse OSM |
| **Organisateur / admin d'équipe / admin plateforme** (`teamAccess(...).isOrganizer`) | Modifier + Supprimer, ou Restaurer si `deleted`. Commentaires visibles avec `isOrganizer` pour modérer |
| **Créateur du parcours** | Il n'y a **pas** de notion de propriétaire pour l'édition : `canEdit` = rôle ORGANIZER/ADMIN ou admin plateforme seulement. Un créateur simple MEMBER ne peut ni modifier ni supprimer. `isOwn` (`createdBy.id === me`) ne sert qu'à masquer « Signaler » (le menu ⋯ disparaît alors : `author` n'est pas passé, donc pas de « Bloquer ») |
| **Membre simple** | Pas de Modifier/Supprimer ; Partager, ⋯ Signaler, commentaires, usages |
| **Connecté non membre** | Pas de commentaires ; Partager, ⋯ Signaler ; « Envoyer vers l'appareil » si un service est connecté ; usages (filtrés par le serveur) |
| **Anonyme** | Pas de commentaires, pas de menu ⋯ (`ContentActionsMenu` renvoie `null`), pas d'envoi vers l'appareil. Téléchargements GPX/FIT, carte, stats et usages restent visibles. Accès aux parcours `TEAM` : comportement serveur non vérifié (404 probable, qui donnerait « Parcours introuvable ») |
| **Supprimé** (`deleted`) | Bouton Restaurer à la place de Supprimer (organisateur). Aucun autre marqueur visuel de suppression dans la page (aucun badge « supprimé » trouvé) |
| **Fichiers** | Les boutons GPX et FIT n'apparaissent que si `media.assets.gpx/fit` existent ; tout le bloc 8 disparaît si les deux manquent, y compris « Envoyer vers l'appareil » (imbriqué dedans) |
| **Usages** | 0 → bloc 15 absent. Sortie → une date-heure de départ. Voyage avec `endDate` → plage de jours. Utilisation via un groupe ou une étape → ligne « via les groupes / étapes : … » |
| **Description / PJ / logo / tags** | Chacun disparaît s'il est vide (le markdown vide ne rend rien ; logo seulement si `assets.logo`) |
| **Météo** | Aucune variante : jamais affichée sur cette page (voir l'en-tête) |

## 4. Dates et heures

| Emplacement | Champ source | Formatage `fichier:ligne` | Format produit (exemple FR) | Fuseau | Remarques |
|---|---|---|---|---|---|
| Bloc 10 « Créé le » | `RouteDetailDto.createdAt` (Instant) | `<FormattedDate>` `RouteDetailView.tsx:229` → `components/common/FormattedDate.tsx:14` → `formatDate` `utils/dateFormat.ts:91` (date-fns `PPP`) | « Créé le: 3 novembre 2026 » (`PPP` fr = « d MMMM yyyy » ; deux-points collé, codé en dur dans le JSX) | Lecteur : `user.timezone`, sinon le fuseau du navigateur ; UTC pendant le SSR anonyme, avec `suppressHydrationWarning` (`dateFormat.ts:39-59`) | horodatage, donc fuseau du lecteur (règle API-60) |
| — | `RouteDetailDto.updatedAt` | — | **jamais affiché** | — | |
| Usage « Sortie » (bloc 15) | `RouteUsageDto.dateTime` + `timezone` | `DepartureLine withDay` `RouteUsages.tsx:83-90` → `components/common/DepartureLine.tsx:60-64` → `useRendezvousFormat(zone).formatDeparture` (`hooks/useRendezvousFormat.ts:51`) → `formatDeparture` `dateFormat.ts:220` | « sam. 14 nov. · 08:30 ». Année ajoutée hors année courante : « sam. 10 avr. 2027 · 08:30 ». **Relatif** pour aujourd'hui et demain : « Aujourd'hui · 08:30 », « Demain · 08:30 » (motifs `dateFormats.departureDay` = `EEE d MMM`, `dayAndTime` = `{{day}} · {{time}}`, heure `p`) | Zone de l'**entité** (`usage.timezone`) ; repli sur celle du lecteur si inconnue. Si les décalages diffèrent : icône globe + info-bulle « heure de Tokyo (ven. 01:00 chez vous) » (`ZoneMentionIcon`, `components/common/Rendezvous.tsx:84`), absente pendant le SSR et l'hydratation | heure de **départ de la sortie** (`dateTime`), pas d'un groupe particulier ; un usage « via les groupes » affiche l'heure de la sortie |
| Usage « Voyage » avec `endDate` | `dateTime`, `endDate`, `timezone` | `UsageRange` `RouteUsages.tsx:110-121` → `formatDepartureDay` (`dateFormat.ts:241`) | « ven. 16 mai → dim. 18 mai » (sans heure ; chaque bout reprend le mois ; année hors année courante) | zone de l'entité, une seule mention de zone pour la plage (calculée sur `dateTime`) | un voyage sans `endDate` passe par la branche « Sortie » (date + heure) |
| Commentaires | `comment.createdAt` | `formatRelative` `components/comment/CommentItem.tsx:97` → `dateFormat.ts:286` (`formatDistanceToNow`) | « il y a 2 heures » | sans objet (relatif) ; `suppressHydrationWarning` | |
| Info-bulle du profil, popups waypoints, liste des points | — | — | aucune date ni heure : distances seulement | — | |
| Plein écran | — | `RouteFullscreenView.tsx:178-182` | aucun sous-titre de départ pour un parcours | — | les autres pleins écrans (groupe, étape) affichent « sam. 12 avr. · 09:00 » |
| Météo : heure de départ, heures de passage, durée estimée | — | — | **absent** de la page parcours ; aucun sélecteur de date ou d'heure | — | les heures de passage n'existent que dans `WeatherCheckpointMarkers`/`RouteWeather` des pages d'événement (`timezone` de la sortie ou de l'étape) |

Aucune durée estimée n'est affichée sur la page parcours : pas de vitesse, pas de « durée ».

## 5. Wireframe ASCII

### Desktop (≥ sm, colonne unique ≤ 1280 px)

```
┌──────────────────────────────────────────────────────────────────────┐
│ Équipe › Parcours › Tour du Vercors                    [0 fil Ariane]│
├──────────────────────────────────────────────────────────────────────┤
│ [avatar] Les Rouleurs du Dimanche                          >  [1]   │
├──────────────────────────────────────────────────────────────────────┤
│ [logo] Tour du Vercors (H1)          [Modifier][Supprimer] (⇪) (⋯)  │ [2]+[4]
│ Description markdown… images…                                [3]    │
│ ┌ Pièces jointes ─────────────┐                                     │
│ │ 📎 roadbook.pdf  1,2 Mo  ⤓   │                                     │
│ └─────────────────────────────┘                                     │
├──────────────────────────────────────────────────────────────────────┤
│ ┌────────────────────── CARTE (300–560 px) ───────────────────────┐ │ [5]
│ │[+][-][⌖]                                                         │ │
│ │[fond]      ▲ départ ───tracé coloré─── ■ arrivée   (km)  ☕ ⛰   │ │
│ │[h ]                                                              │ │
│ │[⤢ Carte plein écran]                         échelle · ©attrib   │ │
│ ├──────────────────── PROFIL (160 px) ────────────────────────────┤ │
│ │ Elevation (m)                       Données : IGN LiDAR HD, …   │ │
│ │   ▁▂▄▆█▆▄▂▁▂▃▅▇▅▃▁   ◆ marqueurs waypoints                       │ │
│ │                  Distance (km)                                   │ │
│ └──────────────────────────────────────────────────────────────────┘ │
│ Profil d'altitude provisoire   (si PENDING)                    [6]  │
│ ( Pente | Revêtement )                                         [7]  │
│ ████████████▒▒▒▒░░  barre revêtement                                │
│ ━ Asphalte 72 %  ━ Compacté, gravier 20 %  ━ Terre 8 %              │
│ © contributeurs OpenStreetMap                                       │
│ [⤓ Télécharger GPX] [⤓ Télécharger FIT] [📱 Envoyer vers l'appareil▾]│ [8]
│ 🗺 Distance      ↑ Dénivelé positif   ↓ Dénivelé négatif         [9]│
│   123.4 km        1850 m               1850 m                       │
│ (Route) (Public)  Créé le: 3 novembre 2026                     [10] │
│ ● Montagne  ● Gravel-friendly                                  [11] │
│ Points du parcours (12)                                        [12] │
│ 0.0 km   (⚑) Départ réel                                            │
│ 42.1 km  (☕) Café du Port  Café, pause                              │
│          description sur 2 lignes…                                  │
│ …  [Voir les 2 autres points]                                       │
│ Cols et montées (3)                                            [13] │
│ [1ère Catégorie] Col de Rousset  De 30.2 km à 48.0 km               │
│                  Dénivelé: 740 m  Pente moyenne: 4.2%  Pente max…   │
├──────────────────────────────────────────────────────────────────────┤
│ Commentaires (4)    (membres / admin plateforme)               [14] │
│ [ zone de saisie ]                                                  │
│ (av) Léa · il y a 2 heures                               (⋯)        │
├──────────────────────────────────────────────────────────────────────┤
│ Utilisée dans  (si ≥ 1)                                        [15] │
│ ┌ Sortie du samedi  [SORTIE] ┐ ┌ Vercors 3 jours  [VOYAGE] ┐       │
│ │ 🕓 sam. 14 nov. · 08:30 🌐  │ │ 🕓 ven. 16 mai → dim. 18 mai│       │
│ │ via les groupes : A, B      │ │ via les étapes : J1         │       │
│ └─────────────────────────────┘ └─────────────────────────────┘       │
└──────────────────────────────────────────────────────────────────────┘
```

### Étroit (< sm)

```
┌──────────────────────────────┐
│ Parcours › Tour du Vercors   │ [0] (2 derniers niveaux)
│ [av] Les Rouleurs…        >  │ [1]
│ [logo] Tour du Vercors       │ [2]
│ Description…                 │ [3]
│ [Modifier][Supprimer](⇪)(⋯)  │ [4] passe sous le titre
│ ┌ CARTE 52svh (≥300) ──────┐ │ [5]
│ ├ PROFIL 160 px ───────────┤ │
│ └──────────────────────────┘ │
│ Profil provisoire            │ [6]
│ (Pente|Revêtement) barre…    │ [7]
│ [⤓ GPX] [⤓ FIT]              │ [8] passe à la ligne
│ [📱 Envoyer…]                │
│ Distance  D+                 │ [9] passe à la ligne
│ D−                           │
│ (Route)(Public) Créé le: …   │ [10]
│ ● tags                       │ [11]
│ Points du parcours (N)       │ [12]
│ Cols et montées (N)          │ [13]
│ Commentaires                 │ [14]
│ Utilisée dans                │ [15]
│ ┌ carte usage 1 ───────────┐ │ 1 colonne
│ ┌ carte usage 2 ───────────┐ │
└──────────────────────────────┘
```

### Plein écran `/carte`

```
┌─[←] Tour du Vercors ········ ⤳123.4 km ↑1850 m ↓1850 m (Pente|Revêtement)┐  (↑↓ masqués < sm)
│                                                                         │
│                       CARTE (reste du 100dvh)                           │
│                                                                         │
├──────────────────────── PROFIL 160 px ──────────────────────────────────┤
└─────────────────────────────────────────────────────────────────────────┘
```

## 6. Étonnements

1. **Aucune météo sur la page parcours**, alors que les blocs (`RouteWeather`, `RouteVerdicts`, mode « Météo ») existent et que l'aperçu GPX, lui, propose une météo avec une heure de départ. `RouteDetailView` accepte `windLeg/windAttribution/timezone` mais `RouteDetailPage` ne les passe jamais. Ce sont des props mortes, tout comme `beforeClimbs`.
2. **Docstring périmée** : `RouteDetailView.tsx:56-59` (et le commentaire de `beforeClimbs`, l. 52) dit qu'il sert aussi à `StageDetailPage`, qui utilise maintenant `RouteMapPanel`. `subject="stage"` est codé en dur dans `RouteDetailView.tsx:116`.
3. **Deux dispositions de carte pour le même tracé** :
   - page parcours : profil **sous** la carte (160 px) ;
   - groupe, sortie solo, étape (`RouteMapPanel`) : profil **superposé** à la carte.

   Les blocs annexes diffèrent aussi : le parcours a stats, badges, tags et montées ; le panneau d'événement a seulement un cadre d'actions.
4. **Ordre surprenant** : les téléchargements (bloc 8) passent *avant* les statistiques (bloc 9). Les contrôles de revêtement (7) se glissent entre la carte et les téléchargements. Les points du parcours (12) arrivent après les tags, loin de la carte, d'où le défilement automatique vers la carte au clic.
5. **Doublon de stats** : la distance, le D+ et le D− du bloc 9 sont aussi dans la barre du plein écran. Les montées du bloc 13 se retrouvent dans l'info-bulle du profil (« Montée (i/n) : … »).
6. **Deux notions de « revêtement »** côte à côte : le badge déclaré `surfaceType` (« Route/Gravel/VTT/Mixte », bloc 10) et l'analyse OSM (bloc 7). Les deux peuvent se contredire, et rien ne les relie visuellement.
7. **Libellés non traduits dans le profil** : titres d'axes en anglais codés en dur, `Distance (${unit})` et `Elevation (${unit})` (`ElevationChart.tsx:479` et `:500`). Le dataset s'appelle aussi « Elevation ».
8. **Décimale à point en français** : `formatDistance` fait `toFixed(1)` (`utils/unitFormat.ts:38-41`), d'où « 123.4 km ». Même chose pour les pentes : « 6.2% », sans espace avant %, alors que le revêtement écrit « 72 % ». « Créé le: » a un deux-points sans espace insécable, codé dans le JSX (`RouteDetailView.tsx:229`).
9. **`updatedAt` jamais affiché**, ni l'auteur (`createdBy`). La seule date propre au parcours est « Créé le ».
10. **Droits** : le créateur, s'il est simple membre, ne peut ni modifier ni supprimer son parcours. Seuls ORGANIZER, ADMIN et admin plateforme le peuvent (`teamAccess`).
11. **« Modifier » est un `<a href>`** (`RouteDetailPage.tsx:128-133`), donc un rechargement complet, alors que la règle front impose `PrefetchLink`.
12. **« Envoyer vers l'appareil » dépend des fichiers** : il est imbriqué dans le bloc téléchargements, donc caché s'il n'y a ni GPX ni FIT, même avec un service connecté.
13. **Un parcours supprimé n'est signalé par rien** : aucun badge ni bandeau ; seul le bouton Restaurer le trahit, et seulement pour un organisateur.
14. **« Utilisée dans » est en dernier**, après les commentaires (choix assumé dans le commentaire l. 203-205). Une sortie y affiche l'heure de la *sortie*, même quand le parcours ne sert qu'à un groupe qui part à une autre heure : « via les groupes » n'a pas d'heure de groupe. Les dates des usages suivent le format rendez-vous, relatif « Aujourd'hui/Demain » ; « Créé le » suit le format long `PPP`. Ce sont deux styles de date sur la même page.
15. Le plein écran du parcours n'a pas de sous-titre, alors que ceux des événements affichent le départ. C'est cohérent (pas de date), mais la barre est plus pauvre.
