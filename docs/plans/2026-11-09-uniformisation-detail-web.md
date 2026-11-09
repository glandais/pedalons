# Uniformisation web sortie / voyage — conception technique (ledger `WEB-155`, `API-161`)

## Context

L'état des lieux a montré que les pages web sortie et voyage, groupe et étape ont dérivé : en-têtes copiés, mises
en page différentes, deux cartes enfant sans rien en commun, une page étape avec double en-tête, rail
d'onglets, `RouteDetailView` empilée et une météo réduite (`LegWeather`). Le canevas
« Uniformisation sortie / voyage (web) » (https://claude.ai/artifact/8jJNyL97EjdPKmgS4LD24e) fixe la cible :
un gabarit parent (sortie, voyage), un gabarit enfant (groupe, étape), une `ChildCard`. Web uniquement.

Décisions prises avec le propriétaire (9 novembre 2026) :
- **Météo d'étape** = la « Météo du parcours » du groupe (`RouteWeather`, verdicts, tableau, synchro carte).
  Le contrat gagne `TripStageWeatherDto.departure` pour garder l'encadré « Jour » et la température au départ.
- **Montées** : supprimées de la page étape (pas ajoutées au groupe) ; elles restent sur la page parcours.
- **Inscription au voyage** : refusée une fois le voyage **terminé** (`trip.finished`), backend + front.
- **Pas de bloc « Météo des étapes »** sur la page voyage : lignes des cartes + mode Météo de la carte suffisent.
- Retours du canevas : consignes d'étape sans titre ; pas de bloc personnes sur l'étape ; pas de bloc
  commentaires sur le groupe ; fourchettes « 62 à 92 km » et « D+ : 700 à 1 350 m » sur la sortie.

Livraison en plusieurs lots → branche `feat/uniformisation-detail` (mémoire « commits directs sur develop »).
Entrées ledger : `WEB-155` (ce plan) et `API-161` (le contrat, lot 0).

## Lot 0 — Backend et contrat (MINOR, `pedalons.api.version` 13.2.1 → 13.3.0)

1. **`TripStageWeatherDto.departure`** (nullable `DepartureWeatherDto`) :
   - `service/weather/TripWeather.StageLeg` gagne `@Nullable DepartureWeather departure`.
   - `TripWeatherService` (~l.50-90) : ajouter la cellule du **premier échantillon** de chaque étape à `keys`, puis
     `RideWeatherCalculator.departure(cache.get(firstCell), leg.start(), now)` — la fonction existe déjà
     (`RideWeatherCalculator.java:289`) ; étape partie (`isGone`) → `DepartureWeather.of(OUT_OF_RANGE)`.
   - `TripStageWeatherDto.from` mappe `DepartureWeatherDto.from(...)`. Nullable : rien ne casse côté mobile.
2. **Refus d'inscription à un voyage terminé** : `TripService.joinTrip` (`TripService.java:496-516`) lève un
   `ConflictException(ErrorCode.TRIP_FINISHED)` quand `(endDate ?: dateTime) < now` — extraire le calcul de
   `TripDto.finished` (`TripDto.java:253`) dans un helper partagé (`Trip.isFinished(now)`) pour une seule règle.
   Le départ reste libre (comme `leaveGroup`).
3. Tests backend à écrire (le propriétaire les lance) : `TripWeatherResourceTest` (departure présent / OUT_OF_RANGE),
   `TripResourceTest#join_finishedTrip_conflict`.
4. Skill `contract-first-api` → `pnpm generate-api` (frontend) et client mobile ; clé
   `errors.api.TRIP_FINISHED` fr/en (« Ce voyage est terminé. ») — sinon `pnpm typecheck` casse (`ErrorCode`).

## Lot 1 — En-tête et actions partagés (pages parentes)

Nouveau dossier `frontend/src/components/publication/` :
- **`usePublicationStatusActions(kind, teamSlug, slug, dto)`** : les 6 handlers (publier, dépublier, annuler,
  rétablir, supprimer, restaurer) + l'état des 4 `ConfirmDialog`, en appelant les mutations orval de chaque type ;
  invalidations : celles de `RideDetailPage.invalidateRideQueries` (l.222) et leur pendant voyage
  (`getGetTripQueryKey`, `invalidateTripWeather`, publications) ; suppression → dashboard + `paths.teamAgenda`.
  Réutilise `rideStatusRequest` / `tripStatusRequest` (`rideFormData.ts`, `tripFormData.ts`).
- **`PublicationHeader`** : logo (`EntityLogo`), titre (ellipsis), badge statut `variant="light"`
  (`STATUS_COLORS`), badge « Terminé » (`dto.finished`, clé commune), slot `joinActions`, Modifier ▾, `ShareButton`,
  `ContentActionsMenu`, puis `DepartureBlock` (+ `tone="teal"` / `dayLine` pour le voyage), `PlacesLine`,
  `FactsStrip`, `TagList`, publication programmée (`Rendezvous`).
- **`PlacesLine`** (départ/arrivée, nom + adresse) : remplace les 4 rendus d'arrivée. Sur l'en-tête de sortie le
  départ reste dans `DepartureBlock.place` ; `PlacesLine` ne montre que ce qui n'y est pas.
- **`FactsStrip`** : sortie = n groupes · n personnes · fourchette distance · « D+ : a à b m » calculées par
  `rideFacts(ride)` (min/max de `groups[].distance|elevationGain`, valeur unique si égales) ;
  voyage = n étapes · n personnes · `totalDistance` · `totalElevationGain`.
- **`AccessAlerts`** (non-membre / non connecté) avec un `kind` qui choisit le texte « sorties » / « voyages ».
- **`useTripMembership`** (`hooks/`) calqué sur `useRideGroupMembership.ts` : mise à jour optimiste de
  `registered`/`participantCount`, rollback + erreur, toast `trips.notifications.joined|left`, invalidations trip +
  participants (`getGetTripParticipantsQueryKey`) + `invalidateTripWeather` + `invalidateRideRegistration`
  (`lib/rideRegistration.ts`, à renommer `invalidateRegistration` : il couvre feeds, agenda, dashboard).
  `canJoinTrip` ajoute `!trip.finished`.

i18n : pas de clés génériques ; les composants prennent `kind: 'ride' | 'trip'` et lisent des tables typées de
`TranslationKey` (règle `AUTH_ERROR_KEYS`, pas de clé construite sur un sous-ensemble).

## Lot 2 — Mise en page parente

- CSS `index.css:261-292` : `.ride-detail-layout`/`.ride-detail-side` → `.detail-layout`/`.detail-side` (même
  grille 380-440 px + carte collante `--fill`, WEB-134). `TripDetailPage` quitte le `SimpleGrid` 1/2/3 et
  `TripLayout` (`showStageNav={false}`).
- Consignes du voyage : sorties de l'en-tête vers un `Paper` comme la sortie ; `hasMediaContent` et
  `INSTRUCTIONS_IMAGE_SIZES` (`RideDetailPage.tsx:96-101`) passent dans `components/publication/`.
- **`ParticipantsSection`** : `GroupParticipantsSection` généralisé en prenant `source: ParticipantSource`
  (`ParticipantList.tsx:17-19`, déjà `trip`), aperçu et total ; la sortie garde son appel, le voyage remplace son
  `Paper` + `ParticipantListModal` (`TripDetailPage.tsx:505-534, 580-588`). Prefetch : `prefetchTripDetail`
  ajoute les participants pour qui lit les noms (même condition que `prefetchRideDetail`) — sinon l'audit SSR casse.
- `TripOverviewMap` : `variant="sticky"`, et `selectedItemId` / `onItemSelect` relayés à `RoutesMapView` pour la
  même synchro survol + clic que la sortie (`RideDetailPage.tsx:114-159`).

## Lot 3 — `ChildCard`

`components/publication/ChildCard.tsx` : lien étiré sur le nom (`classes.stretchedLink` / `aboveLink` de
`RideGroupCard.module.css`), slots `marker` (barre couleur | numéro/logo), `corner` (actions d'inscription |
`DepartureLine withDay`), `extra` (heure décalée + capitaine | lieux), méta (allure · km · D+ · personnes), ligne
météo, `RideGroupRouteActions`, alerte d'erreur, style de mise en évidence unique.
- `RideGroupCard` devient une composition de `ChildCard` (props inchangées → `RideGroupCard.test.tsx` garde ses
  test-ids `group-track-color`, `group-own-time`, `route-actions`, `group-weather-line`).
- `TripStageCard` : plus de `MediaDisplay`, plus d'`UnstyledButton` imbriqué ; ajoute l'allure et les actions de
  parcours. `RideGroupRouteActions` élargit `route` à `Pick<RouteDto, 'media'>` (il ne lit que
  `media.assets.gpx|fit`, l.59-74) pour accepter `stage.route`.
- Ligne météo : `GroupWeatherLine(leg)` et `RideWeatherSummaryLine(summary)` restent (données différentes),
  posées au même slot.

## Lot 4 — Page enfant (groupe, étape)

- **`ChildDetailShell`** (`components/publication/`) : `BackLink`, **`SiblingNav`** (‹ › + `SegmentedControl` ≤ 4,
  `Select` au-delà — logique actuelle de `RideGroupPage.tsx:219-261`, avec le `blur()` iOS), en-tête unique
  (nom du parent, titre, badges, actions, partage), `DepartureBlock` + `PlacesLine`, `AccessAlerts`, puis la grille
  `.detail-layout` (colonne + `detail-map--fill --solo`) et la section météo pleine largeur `#meteo`.
- **`RideGroupPage`** : migre sur le shell (pas de bloc commentaires, comme aujourd'hui) ; bouton « Modifier »
  (organisateur) vers `paths.rideEdit`. Le titre du bloc parcours devient le nom du parcours (h3).
- **`StageDetailPage`** réécrite sur le shell :
  - carte `GroupRouteMap` (déplacé en `components/route/RouteMapPanel.tsx`, nom générique) avec
    `route` de `useStageDetailData` (lecture **single** conservée, `useElevationRefetchInterval` aussi),
    `leg = stageWindLeg(...)`, `selectedCheckpoint`/`onSelectCheckpoint`, `fullscreenPath` → `paths.stageMap`.
    `RouteMapPanel` reçoit `subject` (`'group' | 'stage'`) pour la légende (`ColorModeControls`) et reprend la
    note « dénivelé en cours d'affinage » de `RouteDetailView.tsx:105-109` (`elevationState === PENDING`).
  - colonne : `StatsCard` (le `StatTile` de `GroupStats.tsx:11-40` extrait ; allure, distance, D+, arrivée estimée
    `leg.arrivalTime`), consignes de l'étape **sans titre**, carte « Parcours » (h3 = nom du parcours +
    `RideGroupRouteActions` + lien parcours). Pas de personnes, pas de montées.
  - commentaires d'étape inchangés (`CommentSection entityType="stages"`).
  - supprimés : `TripLayout.tsx`, `StageTabs.tsx`, le second en-tête, `RouteDetailView` sur cette page.
- **Météo** : `GroupWeatherSection` → `RouteWeatherSection` générique, props `{offered, status, leg, departure,
  availableFrom, attribution, fetchedAt, timezone, subject, isLoading, isFetching, onRetry, canEdit, selection,
  onSelectionChange}` ; le groupe passe `ride.finished`/CANCELLED, `weather.status`, `weather.departure` ;
  l'étape passe `tripOffersWind` (`lib/tripWeatherOnMap.ts:11`), `stage.leg.status`, `stage.departure`,
  `stage.leg.availableFrom|fetchedAt`. `RouteWeather.subject` gagne `'stage'`. `StageWeatherSection` disparaît.
- Fullscreen : inchangé (déjà `MapColorFullscreenView`) → « Délibérément dehors » au ledger.

## Lot 5 — Nettoyage, docs, design

- Clés i18n mortes supprimées des deux catalogues (`trips.tabs.overview`, `trips.stage.viewRouteDetails`,
  `trips.detail.participants.*` si plus lues…) après `grep` des littéraux **et** des clés construites (WEB-62).
- Ledger : `WEB-155` → `LEDGER_DONE.md` avec la version de contrat ; décisions à ne pas défaire (montées hors
  pages enfant, refus `TRIP_FINISHED`, une seule `ChildCard`).
- **Synchroniser le canevas** avec les décisions : bloc « Météo des étapes » retiré de la page voyage ; note de la
  page étape (montées supprimées, encadré « Jour » via `departure`) ; note voyage (refus une fois terminé) ;
  table du Main mise à jour (`RouteWeatherSection`, `RouteMapPanel`, `StatsCard`, `useTripMembership`).

## Fichiers critiques

`pages/ride/RideDetailPage.tsx`, `RideGroupPage.tsx`, `pages/trip/TripDetailPage.tsx`, `StageDetailPage.tsx`,
`stageDetailData.ts`, `tripDetailData.ts`, `components/ride/RideGroupCard.tsx`, `components/trip/TripStageCard.tsx`,
`components/ride/group/GroupRouteMap.tsx`, `components/weather/GroupWeatherSection.tsx`, `RouteWeather.tsx`,
`components/trip/TripOverviewMap.tsx`, `hooks/useRideGroupMembership.ts`, `index.css`,
backend `TripWeatherService.java`, `TripStageWeatherDto.java`, `TripService.java`, `ErrorCode.java`.

## Vérification

- `pnpm typecheck`, `pnpm lint`, `pnpm test` (Vitest) — à adapter : `StageDetailPage.test.tsx` (ne mocke plus
  `RouteDetailView` mais `RouteMapPanel`, vérifie `leg`, `fullscreenPath`, synchro), `GroupWeatherSection.test.tsx`
  → `RouteWeatherSection` (+ cas étape), `RideGroupPage.test.tsx`, `RideGroupCard.test.tsx`,
  `DepartureLine.test.tsx` (cas `TripStageCard`), nouveaux tests `rideFacts`, `useTripMembership`, `SiblingNav`.
- `pnpm i18n:check`, `./format.sh`.
- Backend : instructions au propriétaire (`mvn test -Dtest=TripResourceTest,TripWeatherResourceTest`).
- e2e sur la pile `tribly-e2e` (feu vert demandé avant) : `route-maps.e2e.ts` (étape : h3 nom du parcours,
  lecture `single`), `routes-render.e2e.ts -g 'stage /'` et `-g 'trip /'` (prefetch des participants),
  `flow-trips.e2e.ts` (inscription, refus terminé, commentaires d'étape), `rides.e2e.ts`.
- À l'œil (`pnpm dev`) : sortie multi-groupes, sortie solo (inchangée), voyage 3 étapes, étape avec et sans
  parcours, ≤ 4 et > 4 voisins, largeur téléphone (carte au-dessus, `SiblingNav` sans débordement), mode sombre.
