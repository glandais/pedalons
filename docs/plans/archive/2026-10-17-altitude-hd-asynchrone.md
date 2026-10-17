# Altitude rapide à l'enregistrement, rattrapage HD en arrière-plan

Écrit le 17 octobre 2026. **État : livré le 17 octobre 2026, archivé.** Le livré est dans `LEDGER_DONE.md` (`API-131`, `WEB-102`), les restes dans `LEDGER_NEXT.md` (`MOB-76`). Ledger `API-131`, plus `WEB-102`
pour l'indicateur web. Migration `V74`, contrat `11.8.0`. Numéros vérifiés libres le 17 octobre
2026 sur `develop` (`304ba765` : `V73`, `11.7.0`, `API-130`, `WEB-100`) et dans les autres
worktrees (`WEB-101` pris par `feat/routing-web-mobile`).

Chemins relatifs à `backend/src/main/java/fr/pedalons/` sauf mention contraire. Lu sur `develop`
à `dfc0cc88` (liens stables des fichiers d'un parcours, `API-128`).

---

## 1. En une page

Le calcul d'altitude lit IGN LiDAR HD (MNT + MNS à z15, 20 req/s par processus) **dans la requête
HTTP**, à chaque segment tracé dans le planificateur comme à chaque enregistrement. Sur 130 km à
froid : IGN 264 tuiles, 66 Mo, 19 s ; Mapterhorn 16 tuiles, 2,3 Mo, 3 s (`docs/guides/elevation.md`
de vcyclist). L'écart entre les deux : 2 m en moyenne, p95 4,6 m, D+ à ~1,2 % ; ce que l'IGN apporte
en plus, ce sont les tabliers de pont et la queue des grosses erreurs (gorges, routes en déblai).

On sépare donc :

- **Chemin rapide (FAST)** : Mapterhorn seul, partout où un utilisateur attend — segments du
  planificateur, aperçus de l'outil GPX, enregistrement d'un parcours, migration biketeam.
- **Rattrapage HD** : le backend reprend en arrière-plan, avec IGN LiDAR HD, **seulement les
  tracés enregistrés en FAST** — parcours d'équipe **et aperçus de l'outil GPX** —, après un délai
  de calme (debounce), puis remplace le profil, le GPX filtré et le FIT **sans changer leurs URL**
  (`API-128` pour les parcours, §4.6 pour les aperçus).

Mapterhorn et l'IGN ne sont pas sur le même hôte, donc pas sous le même pacer vcyclist : un
utilisateur qui trace n'attend plus derrière le budget IGN que consomme le rattrapage.

Décisions prises avec l'utilisateur le 17 octobre 2026 :

| # | Question | Décision |
|---|---|---|
| D1 | Parcours calculés avant `API-104` (pipeline v1, Mapterhorn) | **Laissés en l'état** — pas de backfill |
| D2 | Migration biketeam | **FAST + rattrapage**, comme une création |
| D3 | Debounce | **90 s de calme, 10 min au plus** après la première demande |
| D4 | Seconde poussée vers les GPS quand le HD arrive | **Acceptée** |
| D5 | Fichiers remplacés | Ligne `Asset` gardée, `fileId` changé (`API-128`) — liens stables |
| D6 | Aperçus de l'outil GPX | **Rattrapés aussi** : ils sont enregistrés et téléchargeables (GPX, FIT, envoi GPS) |
| D7 | Tests backend | **Hors réseau** : provider d'altitude factice pour tous les tests (§6) |

---

## 2. Moteur d'élévation

### 2.1 Deux providers

`infrastructure/gpx/VcyclistProducer.java` produit aujourd'hui un seul `@Singleton
ElevationProvider` (IGN, avec Mapterhorn en secours). Il en produit deux, qualifiés, sur le **même**
`DemTileStore` (le niveau `mapterhorn/` du cache disque est commun) :

- `@ElevationTier(FAST)` — `newElevationProvider(ElevationSource.MAPTERHORN, store)` : z12, pas de
  modèle de surface (les tabliers de pont sont signalés « indisponibles », les tunnels restent).
- `@ElevationTier(HD)` — l'actuel, inchangé.

Pas de fetcher ni de client HTTP à nous (règles `API-104`, `API-105`) : on choisit seulement la
source vcyclist.

### 2.2 Pipeline

`service/route/GpxPipeline.java` : `process(Path source, String name, ElevationQuality quality)`.
Tout le reste est inchangé (lissage 150 m, D+ annoté avant Douglas-Peucker, DP 3/3). L'enum
`ElevationQuality { FAST, HD }` vit dans `enums/`.

Le rapport `Path.getElevationCorrections().getTerrain()` (km IGN, km Mapterhorn,
`fallbackAfterErrorKm`, tuiles en échec), aujourd'hui seulement loggé, sert au rattrapage pour
savoir si le HD a vraiment été obtenu (§4.4).

`GpxPipeline.VERSION` **reste à 2** : le résultat final d'un parcours rattrapé est celui de la v2 ;
le bumper ferait rejouer toute la migration biketeam pour rien.

`computeGpx(GpxDocument)` prend la qualité en paramètre et la propage.

---

## 3. Qui calcule quoi

| Point d'entrée | Aujourd'hui | Demain |
|---|---|---|
| `POST /api/router` (`RouterService.java:120`) | IGN par segment | **FAST**, rien en file |
| Aperçus outil GPX (`GpxPreviewService` : création, fusion, depuis points, mise à jour avec tracé) | IGN | **FAST** + demande de rattrapage (§4.6) |
| Aperçu renommé seulement | — | rien |
| Création d'un parcours (`RouteService.createRoute`), y compris promotion d'un aperçu | IGN | **FAST** + demande de rattrapage |
| Mise à jour avec nouveau tracé (`RouteService.updateRoute` avec fichier ou points) | IGN | **FAST** + demande de rattrapage |
| Mise à jour sans nouveau tracé (titre, texte…) | — | rien |
| Migration biketeam (`BiketeamMigrationService.migrateOneMap`, via create/update) | IGN | **FAST** + rattrapage (D2) |

Interrupteur `pedalons.elevation.async-hd.enabled` (défaut `true`) : à `false`, l'enregistrement
calcule en HD synchrone comme aujourd'hui et ne met rien en file. Sert de retour arrière sans
redéploiement de code, et aux tests qui veulent un parcours directement HD.

---

## 4. Rattrapage HD

### 4.1 La file

Migration `V74__elevation_refresh.sql`, une table pour les deux cibles (on n'élargit pas
`team_entities` avec de l'état de travail), une clé étrangère par cible pour que la suppression
d'un parcours ou la purge d'un aperçu (30 jours) emporte sa demande :

```sql
create table elevation_refresh (
  id                 bigint primary key,
  route_id           bigint references team_entities(id) on delete cascade,
  preview_id         bigint references gpx_previews(id)  on delete cascade,
  source_revision    bigint      not null,  -- jeton du tracé demandé (§4.3)
  first_requested_at timestamptz not null,
  due_at             timestamptz not null,
  attempts           int         not null default 0,
  claimed_until      timestamptz,
  last_error         text,
  check ((route_id is null) <> (preview_id is null))
);
create unique index elevation_refresh_route   on elevation_refresh (route_id)   where route_id is not null;
create unique index elevation_refresh_preview on elevation_refresh (preview_id) where preview_id is not null;
create index elevation_refresh_due on elevation_refresh (due_at);
```

Et sur les cibles, nullable, **`null` = héritage = HD** (pipeline v2) — c'est aussi ce qu'écrit la
release précédente pendant un déploiement rolling :

- `alter table team_entities add column elevation_quality varchar(8);`
- `alter table gpx_previews add column elevation_quality varchar(8), add column files_revision bigint;`
  (`files_revision` : §4.6).

### 4.2 Demande et debounce

Dans la transaction qui enregistre le tracé FAST (après `persistGpxData`) :

```sql
insert into elevation_refresh (id, route_id, source_revision, first_requested_at, due_at)
values (:tsid, :routeId, :revision, now(), now() + :quiet)
on conflict (route_id) where route_id is not null do update set
  source_revision = excluded.source_revision,
  due_at = least(now() + :quiet, elevation_refresh.first_requested_at + :maxWait),
  attempts = 0, last_error = null;
```

(Même chose avec `preview_id` pour un aperçu.)

`:quiet` = 90 s, `:maxWait` = 10 min (D3), en propriétés `pedalons.elevation.async-hd.quiet` et
`…max-wait`. Des enregistrements rapprochés repoussent l'échéance, jamais au-delà de 10 min après
le premier. Une ligne n'existe que pour un parcours enregistré en FAST : il n'y a **jamais** de
balayage de tous les parcours.

### 4.3 Le jeton d'un parcours : le `fileId` de l'original

(Pour un aperçu, le jeton est `files_revision` : §4.6.) Depuis `API-128`, la ligne `Asset` d'un fichier de parcours garde son id ; seul son `fileId` change
à chaque modification du tracé, et rien d'autre ne le change (`GpxSanitizationBackfill` réécrit sous
la même clé, les vignettes ne touchent pas l'original). **Le `fileId` du `ROUTE_ORIGINAL_GPX`**
(ligne d'id max, même règle que `putStoredFile`) identifie donc la version du tracé : une
modification de titre ne l'annule pas, une modification de tracé si. Ni l'id de la ligne (stable),
ni `Route.version` (bouge à chaque édition de métadonnées) ne conviennent.

### 4.4 Le worker

`service/elevation/ElevationRefreshWorker`, `@Scheduled(every = "30s",
concurrentExecution = SKIP)`, modèle `GpsRouteSyncWorker`. Une seule file, deux branches
d'écriture : ci-dessous celle d'un parcours, §4.6 celle d'un aperçu.

1. **Prise** (`QuarkusTransaction.requiringNew()`) : une ligne
   `where due_at <= now() and (claimed_until is null or claimed_until < now()) order by due_at
   limit 1 for update skip locked`, puis bail de 10 min (`claimed_until`).
2. **Calcul, sans transaction** : relire l'original depuis S3 (`fileId` = `source_file_id`),
   `computeGpx(doc, HD)`, téléverser le GPX filtré et le FIT sous de nouveaux `fileId`. Les vignettes
   ne bougent pas (tracé 2D identique), l'original non plus.
3. **Écriture** (transaction courte), dans cet ordre :
   1. verrouiller le parcours, relire le `fileId` de son original ;
   2. **si différent de `source_file_id`** : le tracé a changé entre-temps. On supprime les objets
      tout juste téléversés, et on **réaligne** la ligne (`source_file_id` = courant, `due_at` =
      maintenant + `quiet`) au lieu de la supprimer — ce qui couvre aussi le parcours modifié par
      l'ancienne release pendant un déploiement rolling, qui n'aurait pas mis de demande ;
   3. sinon : `assetService.putStoredFile(…, ROUTE_FILTERED_GPX, …, newContent = true)` et idem
      `ROUTE_FIT` — même ligne, nouveau `fileId`, `contentRevision` mis à jour, ancienne clé
      supprimée après commit (`API-128`) ;
   4. mettre à jour **en place** les `GpxTrack` (même nombre, même ordre, puisque même original) :
      `track_points`, `climbs`, `elevation_gain`, `elevation_loss`, `distance` — pas de `clear()`
      puis ré-ajout, donc pas de piège `orphanRemoval` (HHH90032003) ; un nombre de pistes différent
      fait échouer la tentative ;
   5. mettre à jour `Route` : D+, D−, hilliness, distance (si elle a bougé :
      `publicationEndCalculator.refreshUsersOf(route)`), `elevation_quality = HD` ;
   6. supprimer la ligne de file.
4. **Échec** (IGN injoignable, `fallbackAfterErrorKm > 0`, exception) : `attempts + 1`, `due_at` =
   maintenant + backoff (2 min, 10 min, 1 h, 6 h), `last_error`, bail relâché. Après 5 tentatives la
   ligne reste (diagnostic), le parcours reste FAST, et l'on logge en `WARN`.
   Hors couverture IGN, vcyclist répond depuis Mapterhorn (en cache, donc quasi gratuit) : le parcours
   passe HD au sens « meilleure source disponible ».

**Débit** : un parcours à la fois, budget de temps par tick. Pendant un déploiement rolling deux
backends tournent, soit 2 × 20 req/s : c'est déjà le plafond d'aujourd'hui (`API-105`).

**Idempotence** : `skip locked` + bail empêchent deux backends de prendre la même ligne ; un rejeu
qui perd le contrôle du jeton n'écrit rien. La file elle-même est la seule réclamation de travail.

### 4.6 Aperçus de l'outil GPX

Un aperçu n'a pas de lignes `Asset` (pas d'équipe) : `GpxPreviewService` écrit ses fichiers
directement sous `gpx-previews/{publicId}/` à **noms fixes** (`original.gpx`, `filtered.gpx`,
`route.fit`, `thumbnail-light.png`), réécrits sur place à chaque mise à jour, *avant* la transaction
(`updatePreview`, `GpxPreviewService.java:302-331`). Les liens de téléchargement passent par le
`publicId` (`/api/gpx-previews/{id}/gpx|fit`) : ils sont déjà stables.

Mais réécrire sur place ne permet pas un contrôle de jeton : une mise à jour qui téléverse son
nouvel original pendant que le rattrapage calcule, puis le rattrapage qui écrase `filtered.gpx` avec
le HD de l'**ancien** tracé, et rien ne le détecte. (Deux mises à jour concurrentes ont déjà ce
défaut aujourd'hui.) D'où le même principe qu'`API-128` :

- **`files_revision`** (TSID, nullable) : les trois fichiers de tracé vivent sous
  `gpx-previews/{publicId}/{files_revision}/…` ; `null` = disposition actuelle à plat (aperçus
  existants, ou écrits par la release précédente pendant un déploiement). La vignette reste à plat :
  le HD ne la change pas.
- **Création et mise à jour avec tracé** : téléversent sous une révision neuve, puis basculent
  `files_revision` dans la transaction finale ; l'ancienne révision est supprimée après commit, la
  neuve si la transaction échoue. Elles posent `elevation_quality = FAST` et la demande de rattrapage
  avec `source_revision = files_revision`.
- **Limite acceptée (déploiement rolling, à ne pas défaire)** : la release précédente ne connaît pas
  `files_revision`. Pendant la minute de recouvrement, elle lit à plat (404 sur un aperçu créé par la
  nouvelle) et une mise à jour de sa part écrit à plat sans toucher la révision ; le rattrapage peut
  alors recalculer l'ancien tracé. Fenêtre d'une minute, aperçus à durée de vie de 30 jours : pas de
  détection (pas de comparaison de `@Version`). Les fichiers à plat laissés derrière sont balayés à
  la suppression, à la purge et à l'effacement de compte, qui suppriment tout le préfixe
  `gpx-previews/{publicId}/`.
- **Rattrapage** : lit l'original de la révision `R` demandée, calcule en HD, téléverse original
  (mêmes octets), GPX filtré et FIT sous une révision neuve `R2`, puis, dans une transaction courte,
  verrouille l'aperçu : si `files_revision = R`, bascule sur `R2`, remplace `tracks` (jsonb), D+, D−,
  distance, hilliness, passe `elevation_quality = HD`, supprime `R` après commit ; sinon supprime
  `R2` et réaligne la demande (comme §4.4, étape 3.2).
- **À suivre** : `deleteFiles` (suppression, purge à 30 jours) et la liste des fichiers pour l'export
  RGPD (`GpxPreviewService.java:591`) passent par la révision courante, plus la disposition à plat
  pour un aperçu `null`.
- **Promotion en parcours** (`GpxPreviewService.createRoute`) : inchangée, elle relit l'original et
  crée un parcours FAST, rattrapé comme un parcours. Réutiliser le HD d'un aperçu déjà rattrapé est
  possible plus tard, hors de ce plan.

### 4.7 Effets en aval

- **Synchro GPS** : `putStoredFile(newContent = true)` sur le GPX filtré change sa
  `contentRevision`, donc la clé de contenu, donc l'empreinte (`GpsSyncNames.contentKey`) : le
  planificateur renvoie le parcours au tour suivant. Seconde poussée voulue (D4). Rien à ajouter.
- **Liens** : stables, le `?v=` change avec le `fileId` (`API-128`).
- **Météo** (bandes d'altitude de 100 m) : se recale seule au replanification (5 min).
- **Tuiles MVT** : cache privé de 300 s, rien à faire.
- **Notifications** : aucune. Un D+ qui bouge d'environ 1 % ne mérite pas d'être signalé.
- **Biketeam** : l'empreinte reste `…@p2` (VERSION inchangé), aucun rejeu.

---

## 5. Contrat et clients

### 5.1 Contrat `11.8.0` (ajout, rétrocompatible)

`RouteDto` (et les DTO de parcours qui portent D+ : à recenser au moment du lot) et
`GpxPreviewDto` gagnent `elevationQuality: FAST | HD`, **non nul** dans le DTO (`null` en base →
`HD`). Bump de
`pedalons.api.version`, skill `contract-first-api`.

### 5.2 Web — `WEB-102`

- Page parcours (`useGetRoute`) : si `elevationQuality === 'FAST'`, `refetchInterval` de 30 s
  jusqu'au passage en HD, sur le modèle de `hooks/useDataExport.ts:28`, avec un plafond (arrêt
  après 15 min).
- Même chose sur la page d'un aperçu de l'outil GPX (`GpxPreviewView.tsx`,
  `getGetPreviewQueryKey`).
- Mention discrète sous le profil : « Profil précis en cours de calcul » (i18n fr/en). Sur un
  aperçu, la même mention près des boutons de téléchargement : un GPX ou un FIT pris tout de suite
  porte l'altitude rapide.
- Rien dans le planificateur : il devient simplement rapide. Pour la décision Q5 du plan
  [éditeur de parcours](../2026-10-17-editeur-parcours-web.md) (D+ affiché pendant l'édition) : le
  `ascend` serveur des segments sera FAST, comme le parcours juste enregistré ; l'écart avec le HD
  final reste de l'ordre du pourcent.

### 5.3 Mobile et Karoo

Rien d'obligatoire : ils lisent le HD au chargement suivant. Un badge mobile pourrait suivre
(`MOB-76`), hors de ce plan.

---

## 6. Tests backend et altitude : l'existant

Vérifié le 17 octobre 2026 :

- **Aucun test ne remplace le provider** : pas de `@InjectMock`, `QuarkusMock` ni `@Alternative` sur
  `ElevationProvider` ou `GpxPipeline`. Les tests qui traitent un GPX (`GpxProcessingServiceTest`,
  `RouteServiceTest`, `RouteResourceTest`, `BiketeamLiveMigrationTest`, `GpxTrackMergerTest`…)
  passent par le **vrai** vcyclist et donc **le réseau** : IGN `data.geopf.fr` et
  `tiles.mapterhorn.com`. Les GPX de test sont autour de Nantes (47,2 N ; −1,5 E), dans la
  couverture IGN.
- Cache disque `%test.pedalons.data.cache=/tmp/pedalons-data-cache-test` : il n'existe pas en ce
  moment sur la machine (vidé avec `/tmp`), donc le prochain run est **à froid**. La CI
  (`.github/workflows/ci.yml`, `mvn -B test`) ne le met pas en cache : chaque run CI télécharge.
- Les assertions sont lâches (`elevationGain() >= 0`, `elevationLoss() <= 0`, sommes de pistes) et
  `GpxPipeline.process` retombe sur les altitudes d'origine si Mapterhorn échoue aussi : **hors
  réseau, les tests passent quand même**, sans rien vérifier de l'altitude.

Conséquence pour ce plan : les tests du rattrapage doivent vérifier une **transition FAST → HD**, et
le worker traite un `fallbackAfterErrorKm > 0` comme un échec. Contre le vrai réseau, ils seraient
lents et instables (CI sans réseau vers l'IGN, quota). Proposé :

- un `@Mock` CDI de test (`src/test/java`) qui produit les deux providers par
  `ElevationProviderJvm.newElevationProvider(config, fetcher)` avec un **fetcher factice** renvoyant
  des tuiles Terrarium synthétiques et **distinctes** par niveau (par exemple FAST plat à 100 m, HD
  plat à 200 m), sans réseau. Ce n'est pas le « fetcher à côté de vcyclist » interdit par `API-104`
  et `API-105` : il ne sert que les tests, sans HTTP ;
- effet de bord à accepter : tous les tests existants deviennent hors réseau, plus rapides et
  déterministes ; leurs assertions lâches restent vraies (profil plat : D+ = 0). Un éventuel test qui
  dépendrait d'un vrai relief (montées détectées, D+ > 0) serait à recenser au début du lot 1 et à
  doter d'un relief synthétique, ou d'un profil de test dédié (au prix d'un redémarrage de Quarkus).

## 7. Questions ouvertes

Aucune. Le fake provider global en test (§6) est accepté (D7).

---

## 8. Découpage

1. **Backend, moteur** : deux providers, `GpxPipeline.process(…, quality)`, `computeGpx(…, quality)`,
   `/api/router` en FAST, fake provider de test (§6). Aucun changement de schéma ni de contrat.
   Livrable seul : il accélère déjà le planificateur.
2. **Backend, rattrapage des parcours** : `V74`, enregistrement FAST + demande, worker, interrupteur,
   contrat `11.8.0`.
3. **Backend, rattrapage des aperçus** : `files_revision`, écriture par révision, branche aperçu du
   worker (§4.6). Peut partir avec le lot 2 (même migration, même contrat).
4. **Web** : `WEB-102`.

### Tests (à lancer par l'utilisateur)

- Création et mise à jour avec tracé → `elevation_quality = FAST`, une ligne en file ;
  mise à jour de titre → ni ligne, ni changement de jeton.
- Debounce : deux enregistrements rapprochés repoussent `due_at`, jamais au-delà de
  `first_requested_at + maxWait`.
- Worker nominal → `HD`, mêmes ids d'`Asset`, `fileId` et `contentRevision` du GPX filtré et du FIT
  changés, original et vignettes intacts, ligne supprimée, empreinte GPS changée.
- Tracé modifié pendant le calcul → rien d'écrit, objets téléversés supprimés, ligne réalignée.
- Échec → `attempts`, backoff, parcours resté FAST.
- Interrupteur à `false` → HD synchrone, rien en file.
- Aperçu : création → FAST, révision posée, demande en file ; renommage → rien ; rattrapage →
  HD, nouvelle révision, ancienne supprimée, téléchargement par `publicId` qui sert le HD ; mise à
  jour du tracé pendant le calcul → rien d'écrit, révision neuve supprimée ; aperçu `null`
  (disposition à plat) toujours lisible, supprimable, exportable.
- Suppression d'un parcours (douce : `deleted = true`) → demande ignorée par le worker (jointure sur `deleted = false`) ; suppression physique ou purge d'un aperçu → demande supprimée en cascade.

### À ne pas défaire (à reporter dans `LEDGER_DONE` à la livraison)

- Le jeton est le `fileId` de l'original, jamais l'id de ligne ni `Route.version`.
- Un aperçu n'écrit jamais ses fichiers de tracé sur place : révision neuve, bascule en
  transaction, ancienne supprimée après commit.
- Les pistes sont mises à jour en place par le rattrapage, jamais `clear()` puis ré-ajout.
- `null` en base pour `elevation_state` veut dire HD (voir « Évolution avant merge »).
- Le rattrapage ne bumpe pas `GpxPipeline.VERSION`.

## Évolution avant merge

Le plan stockait `elevation_quality` (`FAST | HD`) et le web sondait tant que la valeur était `FAST`,
ce qui laissait un profil abandonné après 5 échecs sondé et signalé « provisoire » pour toujours
(une entrée de suite, repliée dans `API-131` avant d'atteindre `develop`). Le modèle livré porte
l'état sur la cible : `elevation_state` (`PENDING | HD | FAST`, `null` = `HD`) sur `team_entities`
et `gpx_previews`, `V74` modifiée sur place (rien n'était fusionné), contrat `11.8.0` inchangé en
numéro. `PENDING` : profil rapide, rattrapage prévu (posé par toute sauvegarde asynchrone, par un
réalignement et par la relance) ; `HD` : écrit par le worker ; `FAST` : posé à la 5e tentative, dans
la transaction de l'échec. Le web ne sonde et n'affiche que `PENDING`. `ElevationQuality` ne désigne
plus que la source d'un calcul. Une commande d'administration,
`POST /api/admin/elevation-refresh/retry`, relance les abandonnés d'un domaine. Détail dans
`LEDGER_DONE.md` (`API-131`).
