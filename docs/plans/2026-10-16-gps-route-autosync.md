# Envoi automatique des parcours de mes sorties vers mes services GPS

Écrit le 16 octobre 2026. **État : backend, contrat `11.5.0`, web (`WEB-92`) et mobile (`MOB-71`)
implémentés le 16 octobre 2026 (non commités, tests backend écrits mais pas lancés), puis repris
après revue le même jour (§12).** Ce qui a
changé du plan initial en l'implémentant est dit en place et récapitulé au §12 ; les envois manuels,
d'abord hors champ, passent finalement par la même table (§3.6). Ledger `API-120` (backend et
contrat), `WEB-92` (l'interrupteur et l'état sur le site), `MOB-71` (la même chose dans l'app).
Lié à `API-61` (Garmin OAuth 2.0, codes 401/429) et `API-62` (Garmin OAuth 1.0a).

Les faits sur le dépôt ont été relus dans le worktree `feat/gps-route-autosync` (HEAD `0ea379fd`) le
16 octobre 2026, avec leurs numéros de ligne à cette date ; la branche a ensuite été avancée sur
`develop` (`b15a0b38`, `API-118` « Prochaines sorties », contrat `11.4.0`). Les chemins Java sont relatifs à
`backend/src/main/java/fr/pedalons/`. Les faits sur les API externes sont sourcés au §5 ; ce qui y
est **supposé** l'est explicitement et se vérifie à l'étape 0 (§10).

---

## 1. Contexte et objectif

Aujourd'hui, un membre inscrit à une sortie doit envoyer lui-même le parcours de son groupe vers
Hammerhead, Wahoo ou Garmin (menu « Envoyer vers l'appareil », `GpsResource.uploadRoute`). Si
l'organisateur change la route du groupe ou corrige le GPX la veille, le membre roule avec
l'ancienne trace sans le savoir.

Objectif : **un membre qui l'a demandé reçoit automatiquement, sur chacun des services qu'il a
choisis, le parcours de chaque sortie à venir où il est inscrit, et ce parcours suit les
modifications** — nouvelle route, GPX corrigé, changement de groupe — puis disparaît du service
quand il n'a plus lieu d'y être (désinscription, sortie annulée ou supprimée, sortie passée,
interrupteur coupé, déconnexion).

### La question de départ : peut-on modifier ou supprimer un parcours déjà envoyé ?

**Oui, chez les trois services, mais pas avec le code actuel.**

- Hammerhead, Wahoo et Garmin documentent tous un `PUT` (remplacement) et un `DELETE` sur
  l'identifiant renvoyé à la création, et les droits déjà demandés suffisent (§5).
- Notre code ne sait que créer : `infrastructure/gps/GpsServiceClient.java:81` ne déclare que
  `uploadRoute`, et l'identifiant externe que renvoie le service (`RouteUploadResult.externalRouteId`)
  remonte jusqu'à la réponse HTTP **sans être stocké**. Sans cet identifiant, ni mise à jour ni
  suppression ne sont possibles : c'est la table de suivi du §3.2.
- Les envois manuels (web, mobile, synchro Karoo `POST /api/device/routes/{team}/{route}/sync`)
  passent désormais par la même table de suivi : un second envoi du même parcours le met à jour au
  lieu d'en empiler une copie (§3.6). Les envois faits avant cette version ne sont pas retrouvés.

### Hors périmètre, explicitement

- Les voyages (`TripParticipation`, étapes) : même mécanique possible plus tard, non demandée.
- Les envois manuels faits avant cette version : on ne les retrouve pas, on ne les supprime pas.
- Remonter les activités depuis les services (sens inverse) : sans rapport.

---

## 2. Décisions

| # | Question | Décision | Pourquoi |
|---|---|---|---|
| D1 | Opt-in global (sur `User`) ou par connexion ? | **Par connexion** : colonne `auto_sync` sur `gps_service_connections`, fausse par défaut | (1) Un Karoo appairé reçoit déjà les parcours de ses sorties par l'extension Pédalons (`DeviceRouteService`, J-1 à J+7) : l'envoi automatique vers le cloud Hammerhead ferait doublon pour certains, pas pour d'autres. (2) Les quotas diffèrent (Garmin en évaluation : 200 appels par utilisateur et par jour). (3) L'opt-in part de lui-même avec la connexion (`disconnect`, effacement de compte) et revient à `false` à une reconnexion depuis zéro. (4) Il s'expose dans `GpsServiceConnectionDto`, déjà lu par les deux clients via `UserDto.connectedServices` : pas de nouvel appel. |
| D2 | Quelle route pour un groupe sans route ? | **Route effective = la route vivante du groupe, à défaut la route vivante de la sortie** — exactement la sélection de `RideParticipationRepository.findUpcomingRegisteredGroups` (ce que charge un appareil, session sync-device) : une route de groupe supprimée retombe donc sur celle de la sortie. Si la route effective n'a pas de GPX, rien n'est envoyé (pas de repli sur l'autre) | *Révisé à l'implémentation.* Le plan prévoyait de ne pas retomber sur la route de la sortie ; mais l'appareil Karoo, lui, y retombe, et un membre ne doit pas voir deux traces différentes selon qu'elle arrive par l'extension ou par le cloud. Une seule sémantique, commentée des deux côtés. |
| D3 | Clé de la table de suivi | **`(connection_id, ride_id)`**, pas le groupe | Une seule inscription par sortie (`findByUserAndRide`, refus `ALREADY_REGISTERED`) ; changer de groupe = quitter puis rejoindre. Avec la sortie pour clé, un changement de groupe devient un `PUT` du même parcours externe (un appel, pas de doublon sur l'appareil) au lieu d'un `DELETE` + `POST`. |
| D4 | Empreinte de ce qui a été envoyé | **SHA-256 de `asset_id du GPX | nom envoyé`** | Pas de version de GPX sur `Route` (`route.dateTime` bouge à chaque modification de métadonnées). Un nouveau GPX crée de nouvelles lignes `Asset` (`RouteService.updateRoute` → `GpxProcessingService.persistGpxData`) : l'id d'asset change exactement quand la trace change. `GpxSanitizationBackfill` réécrit en place (même asset) : aucun renvoi, c'est voulu. Le nom (§3.5) contient la date et le groupe : les changer renvoie le parcours, ce qui est voulu aussi. |
| D5 | Fenêtre | **Sorties dont le groupe part entre maintenant et J+7** (`pedalons.gps-sync.horizon=P7D`), comme `DeviceRouteService` ; **suppression chez le service 24 h après le départ** (`pedalons.gps-sync.retention=P1D`) | Ne pas encombrer la bibliothèque du membre (Garmin ne synchronise que 50 parcours à la fois vers l'appareil) et borner les appels. 24 h laissent rouler une sortie qui commence tard ou déborde. |
| D6 | Couper l'interrupteur | **Retire les parcours à venir que Pédalons a envoyés** | Modèle mental simple : « Pédalons gère ces parcours pour moi ». Les jetons sont encore là, la suppression est possible. Dit dans le texte d'aide de l'interrupteur. |
| D7 | Déclencheurs : instrumenter les services ou réconcilier ? | **Réconciliation périodique** (modèle `service/weather/WeatherPlanner.java`), aucun hook dans `RideService` / `RouteService` | Trois des chemins concernés ne publient rien (`leaveGroup`, `deleteRide`, changement de route d'un groupe), deux passent par du JPQL bulk (`AccountErasureService.forgetFutureRegistrations`) ou de l'orphanRemoval (groupes retirés). Une réconciliation état voulu / état synchronisé couvre tous les cas, y compris ceux qu'on oublierait, sans toucher au métier. Latence : une minute de planification + le tick du worker, acceptable pour des sorties à J+0…J+7. |
| D8 | Pipeline de notifications ? | **Non** | Il sert à notifier des personnes (destinataires, canaux, préférences) ; les chemins utiles n'y publient pas (D7). |
| D9 | Déconnexion d'un service | **Nettoyage au mieux, synchrone, avant de supprimer la connexion** : un `DELETE` par ligne **automatique** suivie, chez les trois services (au plus une dizaine : fenêtre D5). *Révisé à l'implémentation* : pas de `deauthorize` Hammerhead, qui retirerait aussi les envois manuels — désormais suivis (§3.6) et que la déconnexion a toujours laissés en place ; un seul chemin pour les trois services | Une fois la ligne supprimée, les jetons sont perdus et plus rien n'est possible. Un état « déconnexion en cours » drainé par le worker a été écarté : la release précédente, pendant un déploiement, montrerait encore la connexion et pourrait en créer une seconde (pas d'unicité `(user, service)` en base). |
| D10 | Wahoo `external_id` | **Stable pour l'envoi automatique** : `pedalons-{domainId}-{rideId}` ; l'envoi manuel garde le SHA-256 du GPX | `external_id` ne se modifie pas par `PUT` (il n'est donc envoyé qu'à la création). Le commentaire de `WahooClient` (« Wahoo deduplicates on it ») n'était pas confirmé par la doc : corrigé. |

---

## 3. Modèle de données

### 3.1 `gps_service_connections` : trois colonnes (migration `V71`)

```sql
-- docs/LEDGER_*.md API-120 : envoi automatique des parcours de mes sorties.
-- Colonnes nullables ou avec défaut : la release précédente les ignore (déploiement start-first).
alter table gps_service_connections
    add column auto_sync boolean not null default false,
    -- posé sur 401 après rafraîchissement, ou 412 Garmin ; remis à null à la reconnexion
    add column sync_reconnect_required_at timestamptz,
    -- 429 : plus aucun appel pour cette connexion avant cet instant
    add column sync_paused_until timestamptz;
```

`GpsService.handleCallback` / `handleOAuth1Callback` réutilisent la connexion existante
(`findByUserAndService`, l.342) : une reconnexion garde son id, donc ses lignes de suivi et son
`auto_sync`, et doit remettre `sync_reconnect_required_at` à `null`.

### 3.2 Table de suivi `gps_route_syncs` (même migration `V71`)

Une ligne par connexion et par sortie. Elle porte à la fois **l'état voulu** (écrit par le
planificateur) et **l'état synchronisé** (écrit par le worker) ; le travail à faire, c'est la
différence entre les deux.

| Colonne | Type | Rôle |
|---|---|---|
| `id` | bigint (TSID) | |
| `domain_id` | bigint not null, FK `domains` | Toute requête filtre par domaine ; le worker travaille domaine par domaine (identifiants GPS par domaine). |
| `user_id` | bigint not null | Export, effacement, état dans le DTO. Pas de FK en cascade (voir ci-dessous). |
| `connection_id` | bigint not null, FK `gps_service_connections` **`on delete cascade`** | Le service est celui de la connexion. |
| `ride_id` | bigint, **sans FK** | Clé métier (D3). **Nul pour un envoi manuel** (§3.6). |
| `ride_group_id` | bigint, **sans FK** | Le groupe voulu, pour le nom et l'affichage. |
| `desired_route_id` | bigint, sans FK | Null = le parcours doit disparaître du service. |
| `desired_hash` | varchar(64) | Empreinte D4 de l'état voulu ; null avec `desired_route_id`. |
| `desired_name` | varchar(120) | Nom à envoyer (§3.5). |
| `group_start_at` | timestamptz | Pour la rétention (D5) et le tri ; nul pour un envoi manuel. |
| `external_route_id` | varchar(100) | Identifiant chez le service (chaîne Hammerhead, entier Wahoo, Long Garmin). Null = rien chez le service. |
| `synced_hash` | varchar(64) | Empreinte de ce qui est chez le service. |
| `synced_at` | timestamptz | Dernier envoi réussi. |
| `attempts` | int not null default 0 | Remis à 0 à chaque succès. |
| `next_attempt_at` | timestamptz | Backoff. |
| `claimed_until` | timestamptz | **Bail** du worker (modèle `V69__feedback_github_lease.sql`). |
| `last_error` | varchar(40) | Code d'erreur (enum Java `GpsSyncError`, contrainte `CHECK` alignée, cf. `API-72`). |
| `last_error_at` | timestamptz | |
| `created_at`, `updated_at` | timestamptz not null | |

Contraintes et index :

- `unique (connection_id, ride_id)` : le planificateur fait un upsert `on conflict` dessus (les
  `ride_id` nuls des envois manuels ne s'y heurtent pas).
- `unique (connection_id, desired_route_id) where ride_id is null` : un envoi manuel suivi par
  connexion et route ; recopié dans `import-test.sql` (Hibernate ne sait pas l'exprimer).
- Index partiel du travail en attente :
  `(domain_id, group_start_at) where ride_id is not null and desired_hash is distinct from synced_hash`.
- Index `(user_id)` (export, effacement, DTO) et `(desired_route_id)` (état par route, §3.6).
- `last_error` sous contrainte `CHECK` : `SERVICE_ERROR`, `UNAUTHORIZED`, `PERMISSION_REVOKED`,
  `RATE_LIMITED`, `NOT_CONFIGURED`, `ROUTE_UNAVAILABLE` (enum `GpsSyncError`).

Pourquoi **aucune FK sur `ride_id`, `ride_group_id`, `desired_route_id`** : un groupe retiré d'une
sortie est supprimé physiquement (orphanRemoval dans `RideService.updateRide`) ; une cascade
effacerait la ligne, donc l'identifiant externe, et le parcours resterait pour toujours chez le
service. Sans FK, le planificateur voit la sortie ou le groupe disparus et demande la suppression.

Pourquoi **la cascade sur `connection_id`** : la release précédente, pendant un déploiement
progressif, ne connaît pas la table ; sa `disconnect` et son effacement de compte suppriment la
connexion directement, et la FK ne doit pas les faire échouer. Côté nouvelle release, on **supprime
explicitement** les lignes avant la connexion (§4.6) et l'entité porte
`@OnDelete(action = CASCADE)`, parce que les tests construisent le schéma depuis les entités
(`%test.quarkus.flyway.migrate-at-start=false`, voir `API-72`).

Entité `domain/gps/GpsRouteSync.java`, **autonome** comme `GpsServiceConnection` (pas `BaseEntity`,
qui exige un `created_by_id`), **suppression physique**, sans `@Version` : toutes ses écritures sont
des upserts natifs ou des mises à jour conditionnelles (bail, colonnes disjointes). Repository
`repository/gps/GpsRouteSyncRepository.java`.

### 3.3 Les états, déduits (pas de colonne `status`)

| Condition | État |
|---|---|
| `desired_hash = synced_hash` | à jour |
| `desired_hash is not null and external_route_id is null` | **à créer** |
| `desired_hash is not null and external_route_id is not null and desired_hash <> synced_hash` | **à modifier** |
| `desired_hash is null and external_route_id is not null` | **à supprimer** |
| `desired_hash is null and external_route_id is null` | ligne à effacer (le worker ou le planificateur la supprime) |

### 3.4 L'état voulu, en une requête par domaine

Requête `RideParticipationRepository.findGpsSyncTargets(domainId, from, to)` — dans ce repository
et non dans `GpsRouteSyncRepository` comme prévu au §10, à la demande de la session sync-device,
placée **après** sa `findUpcomingRegisteredGroups` dont elle reprend exactement le filtrage (Javadoc
croisée ; une fusion à blanc avec le checkout principal passe sans conflit). Inscriptions telles
que :

- l'équipe est vivante et l'utilisateur en est encore membre (`UserTeam`) ;
- `ride.status = PUBLISHED`, `ride.deleted = false`, sortie non masquée par la modération, sauf pour
  les modérateurs de l'équipe (ORGANIZER, ADMIN) ;
- `group.startAt` dans `[now − retention, now + horizon]` (D5) ;
- une connexion de l'utilisateur a `auto_sync = true` (une connexion marquée
  `sync_reconnect_required_at` n'est pas planifiée du tout : ses lignes restent telles quelles
  jusqu'à la reconnexion, sinon elles basculeraient en « à supprimer » puis reviendraient) ;
- route effective (D2) vivante, avec un asset `ROUTE_FILTERED_GPX` ou à défaut `ROUTE_ORIGINAL_GPX`
  — le plus récent de son type, même choix partout (`GpsRouteGpx.pick`) ; les assets sont lus en
  une seconde requête pour toutes les routes.
- Pas d'équipe épinglée : l'épinglage appartient à un alias d'hôte, le job tourne hors requête.

Une seule requête jointe par domaine renvoie `(connection, ride, group, route, gpx_asset_id,
startAt, noms)` ; le calcul des noms et des empreintes est fait en Java. **Pas de requête par
inscription** (`GpsRouteSyncPlannerQueryCountTest`, §9).

Les lignes existantes de la connexion qui ne sont pas dans cet ensemble reçoivent
`desired_route_id = null, desired_hash = null` ; celles dont le départ a plus de `retention`
aussi. C'est ce qui couvre **sans aucun hook** : désinscription, sortie annulée, sortie supprimée,
groupe retiré, route supprimée, interrupteur coupé, inscriptions effacées par
`forgetFutureRegistrations`, sortie passée.

### 3.5 Nom envoyé

`{date locale du départ, AAAA-MM-JJ} · {groupe} · {route}`, tronqué à 80 caractères
(`GpsSyncNames.autoName`). La date en tête évite les collisions de préfixe signalées sur les
appareils Garmin (§5.3) et distingue deux sorties qui utilisent la même route. Le fuseau est celui
de la sortie (`ride.timezone`, Europe/Paris si invalide). Un nom de groupe vide est omis ; la règle
de `WEB-83` n'est pas appliquée (point ouvert, §12). Pour Hammerhead, le nom passe par le nom du
fichier multipart : accents retirés, « · » changé en tiret, tout ce qui n'est pas lettre ASCII,
chiffre, espace, point, tiret ou souligné remplacé (`HammerheadClient.fileName`, appliqué aussi à
l'envoi manuel, qui remplaçait jusqu'aux espaces).

### 3.6 Envois manuels et état par route

Les deux chemins d'envoi manuel — `GpsResource.uploadRoute` (web, mobile) et
`DeviceRoutesResource.syncRoute` (Karoo) — aboutissent à `GpsService.uploadRoute`, qui passe par
`GpsRouteSyncService.uploadManually` :

1. **Une ligne automatique de cette connexion veut déjà cette route** (`desired_route_id`) : l'étape
   du worker s'exécute tout de suite sur elle, sous son bail (`claimOne`) — mise à jour du parcours
   externe (`PUT`, recréé sur 404) ou création. Si le worker la tient à cet instant, rien n'est
   envoyé : réponse `success=true`, message « Automatic sync in progress », id externe connu.
2. **Sinon**, l'envoi manuel déjà enregistré pour cette (connexion, route) est mis à jour en place
   (`PUT`, recréé sur 404), ou un nouveau est créé ; l'id externe est enregistré dans une ligne
   **manuelle** (`ride_id` nul, empreintes voulue et envoyée égales, upsert sur l'index partiel).

**Règle de gestion** : une ligne manuelle n'est **jamais** mise sous gestion automatique par elle-même,
quel que soit l'opt-in — Pédalons ne la met pas à jour ni ne la supprime de son propre chef, et la
déconnexion la laisse chez le service, comme avant. Le worker ne la réclame jamais
(`ride_id is not null` dans le claim), le planificateur ne la voit pas. Seul cas de bascule : quand
l'envoi automatique est actif **et** qu'une sortie où le membre est inscrit utilise cette route, la
ligne automatique **reprend** l'envoi manuel au moment de créer (`takeManual` : dans la transaction de préparation, **avant**
l'appel au service et sous le bail, l'id externe est écrit sur la ligne automatique — empreinte
envoyée laissée nulle, la ligne reste en écart — puis la ligne manuelle est supprimée ; la ligne
automatique fait un `PUT` renommé au lieu d'un `POST`). Un appel qui échoue, un 429 ou un 401 laisse
donc l'id sur la ligne automatique, et l'essai suivant met à jour ce parcours au lieu d'en créer une
copie (*corrigé après revue* : la première version ne gardait l'id qu'en mémoire jusqu'au succès).
Dès lors le parcours vit et part avec la sortie (désinscription, interrupteur coupé…).

**État par route** : `GpsRouteSyncService.findRouteStatuses(domainId, userId, routeIds)` rend, en
**une** requête pour toute la liste (règle des lookups par page), pour chaque route et chaque
service de l'utilisateur : automatique ou manuel, état (`SENT`, `OUTDATED`, `PENDING`,
`FAILING`, `RECONNECT_REQUIRED`), id externe, dernier envoi. Plusieurs lignes d'une même route et d'un même
service (deux sorties sur la même route, un envoi manuel) fusionnent : automatique si l'une l'est,
le pire état, l'envoi le plus récent. `DeviceRegisteredGroupDto.syncStatuses` (« Prochaines
sorties » sur Karoo et Garmin, ledger `API-121`) le lit pour toute la liste en deux requêtes au plus, sous la
forme compacte `{ serviceType, state }` ; un envoi manuel, et toute ligne quand la synchronisation est
éteinte, sont comparés au GPX courant de la route (`OUTDATED` s'il a changé) au lieu de promettre
une mise à jour que rien ne fera ; l'énumération est sortie du service en
`fr.pedalons.enums.GpsRouteSyncState`, exposée au contrat.

---

## 4. Mécanisme asynchrone

Deux étages, comme la météo : un **planificateur** déterministe qui écrit l'état voulu, un
**worker** à bail qui fait les appels externes hors transaction.

### 4.1 Planificateur `service/gps/sync/GpsRouteSyncPlanner.java`

- `@Scheduled(every = "60s", concurrentExecution = SKIP)`, domaine par domaine, une transaction
  courte par domaine.
- Calcule l'état voulu (§3.4) et fait un upsert sur `(connection_id, ride_id)` qui **n'écrit que
  les colonnes `desired_*`, `ride_group_id`, `group_start_at`** — jamais les colonnes synchronisées
  ni le bail. Un tick rejoué, ou exécuté par les deux backends d'un déploiement progressif, écrit les
  mêmes lignes (même propriété que `WeatherPlanner`).
- Ne lit pas les lignes en bail et ne les verrouille pas : le worker et le planificateur touchent
  des colonnes disjointes. L'upsert passe par `insert … on conflict do update set desired_… where
  (desired_hash, …) is distinct from (excluded.desired_hash, …)` pour ne pas réécrire une ligne
  inchangée (pas de bump de `updated_at`, pas de contention).
- Efface les lignes sans rien chez le service et sans rien de voulu.
- Coût : ne part que des connexions `auto_sync = true` du domaine ; la plupart des domaines n'en ont
  aucune et coûtent une requête vide.

### 4.2 Worker `service/gps/sync/GpsRouteSyncWorker.java`

Modèle `service/feedback/FeedbackGithubWorker.java` et `service/weather/WeatherFetchWorker.java` :

1. `@Scheduled(every = "20s", concurrentExecution = SKIP)`, **pas** de `@Transactional`.
2. Claim dans `QuarkusTransaction.requiringNew()` : lignes où `desired_hash is distinct from
   synced_hash`, `next_attempt_at` passé ou null, `claimed_until` passé ou null, connexion sans
   `sync_paused_until` futur ni `sync_reconnect_required_at`, `for update skip locked`, au plus
   `batch` lignes (20), triées par `group_start_at` (la sortie la plus proche d'abord) ; puis
   `claimed_until = now + 5 min` sur ces lignes, valeur gardée comme **jeton de bail**. Cinq minutes
   couvrent le pire cas d'une étape — deux rafraîchissements de jeton et trois appels, chacun borné
   à 30 s, jetons compris (`.timeout` sur les requêtes de jeton aussi, *corrigé après revue*) : un
   bail qui expire en cours d'étape laisserait un autre worker créer le parcours une seconde fois.
3. Pour chaque ligne : lecture de la connexion, de la route et du GPX dans une transaction courte ;
   jeton à jour dans une **seconde transaction, à lui seul** (§4.3) ; appel `create` / `update` /
   `delete` (§4.4) hors transaction.
4. Écriture du résultat dans une nouvelle transaction, **conditionnée au bail** : `update … where
   id = :id and claimed_until = :lease`. Si zéro ligne (bail expiré et repris, ou ligne supprimée
   par une déconnexion), le résultat est perdu et journalisé : voir le cas de course du §4.6.
5. Budget de temps par tick (10 s) et nombre d'appels par tick, pour rester sous les quotas Wahoo
   (200 / 5 min en production) même avec plusieurs connexions.

À l'écriture, le worker recopie dans `synced_hash` **l'empreinte qu'il a envoyée** (lue au claim),
pas `desired_hash` relu : si l'organisateur a changé la route pendant l'appel, la ligne reste en
écart et repartira au tick suivant.

Double envoi pendant un déploiement progressif : le bail par ligne (`for update skip locked` +
`claimed_until`) empêche deux backends de créer le même parcours, ce qui compte chez Hammerhead et
Garmin qui n'ont aucune déduplication. Test de course dédié (§9).

### 4.3 Jetons et domaine hors requête HTTP

`GpsService.uploadGpx` est `@Logged`, lit `pedalonsContext.getUserId()` et ses clients obtiennent
leurs identifiants par `DomainGpsCredentialService.getCredentials` → `domainResolver.getDomainId()`
(`@RequestScoped`, lié à la requête). Refactoring proposé, sans changer le comportement des
endpoints :

- `DomainGpsCredentialService.getCredentials(domainId, serviceType)` : surcharge explicite ;
  l'actuelle la délègue avec `domainResolver.getDomainId()`.
- `service/gps/GpsConnectionTokens.java` : extrait de `GpsService` le rafraîchissement
  (`refreshAccessToken`, l.~447) et la vérification d'`oauthVersion`, en prenant `(connection,
  credential)`. `GpsService.uploadGpx` l'appelle ; le worker aussi.
- Les clients reçoivent le `DomainGpsCredential` en paramètre de leurs nouvelles méthodes (§4.4)
  au lieu de le résoudre eux-mêmes.
- Rafraîchissement concurrent (deux workers, les deux backends d'un déploiement progressif, un envoi
  manuel) : *révisé après revue*. Le rafraîchissement se fait dans une transaction qui ne fait rien
  d'autre et commite aussitôt — un fournisseur qui fait tourner ses refresh tokens (Wahoo) a déjà
  invalidé l'ancien, le perdre dans un rollback casserait la connexion. Il est **sérialisé par
  connexion** : `GpsConnectionTokens` verrouille la ligne (`SELECT … FOR UPDATE`, `em.refresh`) et
  revérifie l'expiration avant d'appeler le service, si bien que le second appelant attend puis
  prend le jeton déjà rafraîchi ; après un 401, `forceRefresh` compare de même, sous le verrou, le
  jeton chiffré à celui qu'il a utilisé. Un rafraîchissement **refusé** (400/401 du point de jeton,
  `invalid_grant` : `GpsTokenRefusedException`) demande la reconnexion, qu'il suive un 401 ou qu'il
  porte sur un jeton simplement expiré ; un échec réseau ou un 5xx compte comme un échec ordinaire
  (backoff), pour qu'une panne ne force pas une reconnexion.
- `sync_reconnect_required_at` et `sync_paused_until` ne sont écrits que par des `update` en masse
  (`updatable = false` sur l'entité) : une copie périmée de la connexion, rechargée avant un 429 ou
  un refus et écrite ensuite (interrupteur, rafraîchissement), ne peut plus remettre la valeur
  d'avant. La reconnexion les efface de même (`clearSyncBlocks`), et remet à zéro les essais de
  toutes les lignes automatiques de la connexion — sans quoi celles arrivées à `MAX_ATTEMPTS`
  pendant le refus n'auraient plus été reprises ; réactiver l'interrupteur fait de même. Une
  connexion qui attend une reconnexion peut relancer l'OAuth (`initiateOAuth` ne la refuse plus
  comme « déjà connectée ») : c'est le bouton « Reconnecter » des deux clients.

Écarté : poser `domainResolver.setDomainForTest` dans le worker comme le fait
`BiketeamLiveMigrationWorker` — ça marche, mais garde la dépendance cachée au contexte de requête.

### 4.4 Clients : créer, modifier, supprimer

Nouvelle interface (dans `GpsServiceClient`, implémentée par les trois clients) :

```java
GpsCallResult createRoute(GpsAuth auth, byte[] gpx, RouteMeta meta);
GpsCallResult updateRoute(GpsAuth auth, String externalId, byte[] gpx, RouteMeta meta);
GpsCallResult deleteRoute(GpsAuth auth, String externalId);
TokenResponse refreshToken(DomainGpsCredential credential, String refreshToken);
```

*Révisé à l'implémentation* : plutôt que des variantes dans `GarminOAuth1Client`, l'autorisation est
un type scellé `GpsAuth` — `Bearer(token)` ou `OAuth1(consumerKey, consumerSecret, token,
tokenSecret)`, qui signe la méthode et l'URL de chaque appel (`OAuth1Signer`) — que
`GpsConnectionTokens` construit d'après la connexion et le credential. `GarminClient` sert donc les
deux protocoles ; `GarminOAuth1Client.uploadRoute` (aperçus GPX) délègue à son `createRoute`.

`GpsCallResult` est un type scellé qui **garde le code HTTP** (aujourd'hui perdu dans
`RouteUploadResult.failure("Upload failed: <code>")`) :
`Ok(externalId)`, `NotFound`, `Unauthorized`, `PermissionRevoked` (412 Garmin),
`RateLimited(retryAt)`, `Failed(code, message)`. `RouteMeta` porte le nom, l'`external_id` Wahoo
(D10) et les champs que le `PUT` Wahoo exige. `uploadRoute` existant reste pour l'envoi manuel et
délègue à `createRoute`.

Traitement uniforme dans le worker :

| Résultat | Création | Modification | Suppression |
|---|---|---|---|
| `Ok` | stocker `external_route_id`, `synced_hash` | `synced_hash` | `external_route_id = null`, ligne effacée si rien de voulu |
| `NotFound` | — | **recréer** par `POST` dans le même passage, remplacer l'id (l'utilisateur a supprimé le parcours chez le service) | **succès** |
| `Unauthorized` | rafraîchir le jeton une fois et rejouer ; sinon `sync_reconnect_required_at = now` sur la connexion | idem | idem |
| `PermissionRevoked` | `sync_reconnect_required_at = now` | idem | idem |
| `RateLimited` | `sync_paused_until = retryAt` sur la **connexion** (pas sur la ligne : inutile d'épuiser le quota avec les autres lignes) | idem | idem |
| `Failed` | `attempts++`, backoff 1 min × 2^n plafonné à 6 h, `last_error` | idem | idem |

Après `MAX_ATTEMPTS` (8), la ligne n'est plus reprise tant que son état voulu ne change pas
(`attempts` remis à 0 par le planificateur quand `desired_hash` change).

### 4.5 Le détail par service

| Service | Créer | Modifier | Supprimer | Nettoyage à la déconnexion |
|---|---|---|---|---|
| **Hammerhead** (`HammerheadClient`) | `POST /v1/api/routes/file` (multipart, déjà là) | `PUT /v1/api/routes/{id}/file`, même multipart, réponse 200 `Route` | `DELETE /v1/api/routes/{id}` → 204 | un `DELETE` par ligne automatique (pas de `deauthorize`, D9) |
| **Wahoo** (`WahooClient`) | `POST /v1/routes` avec `external_id` stable (D10) | `PUT /v1/routes/{id}` : `file` (FIT base64), `provider_updated_at = now`, `name`, `start_lat`, `start_lng`, `distance`, `ascent` (obligatoires) ; une réponse `deleted: true` est traitée comme `NotFound` | `DELETE /v1/routes/{id}` | un `DELETE` par ligne suivie |
| **Garmin** OAuth 2 (`GarminClient`) et OAuth 1.0a (`GarminOAuth1Client`) | `POST …/courses/v1/course` (déjà là) | `PUT …/course/{courseId}`, JSON **complet** de `GarminCourseConverter` ; attendre 204 et accepter un corps vide | `DELETE …/course/{courseId}` → 204 ; 404 = succès | un `DELETE` par ligne suivie |

OAuth 1.0a : `OAuth1Signer.authorizationHeader(method, url, …)` prend déjà la méthode ; `PUT` et
`DELETE` signent l'URL qui contient le `courseId` (le corps JSON n'entre pas dans la signature,
comme pour le `POST`).

### 4.6 Déconnexion et effacement de compte

**`GpsService.disconnect`** devient, hors transaction englobante :

1. transaction 1 : `auto_sync = false` (le planificateur arrête de produire) ;
2. nettoyage au mieux (`GpsRouteSyncService.removeAutoSyncedRoutes`), timeout de 30 s par appel,
   erreurs journalisées et ignorées : un `DELETE` par ligne **automatique** qui a un
   `external_route_id`, en sautant les lignes en bail ; aucun appel s'il n'y en a pas ;
3. transaction 2 : suppression explicite des lignes `gps_route_syncs` de la connexion, puis de la
   connexion.

Cas de course accepté : une ligne en bail chez le worker pendant la déconnexion. Le worker finit son
appel, son écriture conditionnelle (§4.2 étape 4) ne trouve plus la ligne ; s'il venait de créer un
parcours Wahoo ou Garmin, celui-ci reste chez le service (Hammerhead est couvert par `deauthorize`).
Fenêtre de quelques secondes, documentée, non corrigée (le cas exige une déconnexion pile pendant un
envoi).

**Effacement de compte** (`service/user/AccountErasureService.java`) : avant la suppression bulk de
`OWNED_BY_USER` (l.~76), appel du même nettoyage au mieux pour chaque connexion de l'utilisateur
(le job tourne déjà hors requête, cron 4 h 45 ; il passe le domaine explicitement, §4.3), puis
`GpsRouteSync` ajouté à `OWNED_BY_USER` **avant** `GpsServiceConnection`. *Révisé après revue* : le
nettoyage (`AccountErasureService.removeSyncedRoutes`) est fait **hors de toute transaction**, avant
celle de l'effacement — appelé en tête par `UserService.deleteUser` (refus vérifiés dans une
première transaction, nettoyage, puis suppression des équipes et effacement dans une seconde) et
par `AccountErasureScheduler` avant `eraseById` — et borné à 20 s par compte. Fait en tête
d'`erase`, il gardait la transaction de l'effacement ouverte pendant les appels, avec ses verrous,
jusqu'à son délai de 60 s.

### 4.7 Déploiement progressif

- `V71` n'ajoute que des colonnes avec défaut ou nullables et une table nouvelle : la release
  précédente l'ignore.
- La cascade sur `connection_id` absorbe les suppressions de connexions faites par la release
  précédente.
- Planificateur idempotent (mêmes écritures sur deux backends), worker à bail par ligne : aucun
  double envoi.
- Rollback : la table et les colonnes restent, inertes ; les parcours déjà envoyés restent chez les
  services jusqu'au retour de la fonction (à dire dans la note de version).

---

## 5. Ce que permettent les API externes (recherche du 16 octobre 2026)

### 5.1 Hammerhead

Spec officielle `https://api.hammerhead.io/v1/docs/openapi.yml`, identique pour les Routes à notre
copie `docs/hammerhead-openapi.yml` (l.186-225 et 321-423).

- Documenté : `PUT /v1/api/routes/{routeId}/file` (200, objet `Route`), `DELETE
  /v1/api/routes/{routeId}` (204, « Can only delete routes created by your client »), `POST
  /v1/auth/oauth/deauthorize` (retire « all of their imported routes »). Scope `route:write` suffit
  (déjà demandé).
- **Supposé, à vérifier à l'étape 0** : 404 sur un parcours supprimé par l'utilisateur ; le `PUT`
  renomme d'après le nom du fichier ; aucune limite de débit documentée.

### 5.2 Wahoo

Doc https://cloud-api.wahooligan.com/.

- Documenté : `PUT /v1/routes/:id`, `DELETE /v1/routes/:id`, `GET /v1/routes?external_id=…` (ce
  dernier exige `routes_read`, **non demandé** : on ne l'ajoute pas, il forcerait tous les
  utilisateurs Wahoo à se reconnecter). `routes_write` suffit pour créer, modifier, supprimer.
- Quotas production : 200 / 5 min, 1000 / h, 5000 / jour (sandbox : 25, 100, 250), en-têtes
  `X-RateLimit-*`. **C'est la contrainte la plus serrée** : pas d'appel sans changement d'empreinte,
  budget par tick.
- **Supposé** : 404 (ou `deleted: true`) sur un parcours supprimé ; le comportement d'un second
  `POST` avec le même `external_id` n'est pas documenté.

### 5.3 Garmin Connect Courses API

Spec « Courses API 1.0.1 » (confidentielle, lue dans une copie publique non officielle, à confirmer
dans le portail développeur) ; PDF OAuth2 PKCE officiel ; une intégration réelle (PUT puis POST sur
404).

- `PUT …/course/{courseId}` : remplacement total, 204, 404 documenté. `DELETE` : 204 (404 non
  listé, traité comme succès). 401, **412 (permission `COURSE_IMPORT` retirée)**, 429.
- Quotas : évaluation 100 / min par partenaire et **200 / 24 h par utilisateur** ; production 6000.
- Retours d'utilisateurs : collisions de noms à préfixe commun sur les appareils (d'où §3.5) ; une
  suppression dans Connect ne remonte pas toujours jusqu'à l'appareil.
- Le programme développeur est en pause (`API-61`) : le développement se teste avec les
  applications OAuth 1.0a existantes (`API-62`).

---

## 6. Contrat d'API (`11.3.0` → **`11.5.0`**, ajout pur)

*`11.4.0` est pris par `API-118` (`DeviceRegisteredGroupDto`, commité sur `develop`) : ce plan prend
`11.5.0`, contrat régénéré après avoir avancé la branche sur `develop`.*

- `ConfigDto.gpsAutoSyncEnabled: boolean` (requis, *ajouté après revue*) : le drapeau
  `pedalons.gps-sync.enabled` exposé par `/api/config`. Faux, les deux clients n'affichent pas
  l'interrupteur, qui promettrait un envoi qui n'a pas lieu.

- `GpsServiceConnectionDto` gagne :
  - `autoSync: boolean` (requis) ;
  - `autoSyncState: GpsAutoSyncState` (requis) : `OFF`, `UP_TO_DATE`, `PENDING`, `FAILING`,
    `RECONNECT_REQUIRED` ;
  - `autoSyncRouteCount: int` (requis) : parcours actuellement chez le service grâce à l'envoi
    automatique ;
  - `lastAutoSyncAt: Instant` (nullable).

  Calcul : **une** requête groupée par connexion pour toutes les connexions de l'utilisateur, faite
  là où `UserDto.connectedServices` est construit (`UserService`), jamais une par connexion.
  `FAILING` = au moins une ligne avec `attempts > 0` ; `PENDING` = au moins une ligne en écart.
- Nouvel endpoint `PUT /api/gps/connections/{serviceType}/auto-sync` (operationId
  `setGpsAutoSync`), corps `GpsAutoSyncRequest { enabled: boolean }` (requis, 400 s'il manque),
  réponse `GpsServiceConnectionDto`. Dans `GpsResource`, utilisateur authentifié ; **400**
  `GPS_SERVICE_NOT_CONNECTED` si la connexion n'existe pas (*révisé* : comme `disconnect` et
  `upload`, plutôt qu'un 404). Seule la reconnexion (callback OAuth)
  efface `RECONNECT_REQUIRED`, pas l'interrupteur.
- Pas de champ sur `UserPreferencesRequest` (D1).
- Compétence `contract-first-api`, puis régénération des clients web et mobile ; bump de
  `pedalons.api.version`. Ajout pur : les anciennes apps mobiles ignorent les champs.
- Export de données (`service/user/UserExportBuilder.java`) : `autoSync` dans
  `account/gps-connections.json` (`AccountExport.GpsConnection::from`, l.~263), et un fichier
  `account/gps-route-syncs.json` (service, sortie, `external_route_id`, `synced_at`) ; texte du
  README de l'export (l.~571-600) mis à jour.

---

## 7. Web (`WEB-92`)

- `frontend/src/components/profile/GpsConnectionsManager.tsx` : pour chaque service connecté, sous
  la ligne existante, un `Switch` Mantine « Envoyer automatiquement les parcours de mes sorties »,
  avec une description `Text size="xs" c="dimmed"` qui dit la fenêtre (7 jours), le retrait après
  la sortie et à la désactivation (D5, D6). Quand `autoSync` est vrai, une ligne d'état d'après
  `autoSyncState` : « À jour · N parcours », « Envoi en cours », « Échec du dernier envoi »,
  « Reconnexion nécessaire » (avec le bouton Connecter, qui relance l'OAuth).
- Mutation par le client **généré** (`gps-services.ts`, après régénération), pas `AXIOS_INSTANCE`
  en direct ; `disabled={mutation.isPending}` ; invalidation de `getGetMeQueryKey()`.
- `ConfirmDialog` de déconnexion : une phrase de plus quand `autoSyncRouteCount > 0` (« les N
  parcours envoyés automatiquement seront retirés de …»).
- i18n : clés `gps.autoSync.*` dans `frontend/src/locales/fr/common.json` **et** `en/common.json`
  (`catalogues.test.ts`) ; reprendre `gps.description`, qui ne parle que d'envoi manuel.
- `profileStatus.ts` (`devicesLine`) : mentionner l'envoi automatique ; fixture `UserDto` de
  `profileStatus.test.ts` complétée.
- Test vitest `GpsConnectionsManager.test.tsx` (modèle `PairedDevicesManager.test.tsx`) :
  interrupteur rendu seulement pour un service connecté, appel de la mutation, chaque état.
- Composants Mantine seulement (compétence `mantine-ui`).

## 8. Mobile (`MOB-71`)

- `mobile/lib/features/profile/presentation/widgets/connected_services_section.dart`
  (`GpsServicesCard`) : sous chaque service connecté, une `PdlSettingRow` avec
  `PdlSwitch(key: keys.profile.gpsAutoSyncSwitch(type), …)` et l'état en sous-titre ; erreurs dans
  le `PdlBanner(tone: danger)` existant ; `profile.gps.hint` revu.
- `profile_repository.dart` : `setGpsAutoSync(type, enabled)` via `GpsServicesClient` généré, puis
  `refreshCurrentUser(ref)`. Mise à jour optimiste avec retour arrière, comme
  `setContactableByMembers` (`user_preferences_provider.dart`) ; **jamais miroité** en local.
- Clés de test dans `mobile/lib/features/profile/keys.dart` ; l10n `profile.gps.autoSync.*` dans
  `mobile/assets/l10n/fr.json` et `en.json`.
- Tests : `profile_subpages_test.dart` (interrupteur, valeur, appel du dépôt) ; fixtures
  `GpsServiceConnectionDto` / `UserDto` complétées des champs requis (`profile_subpages_test.dart`,
  `profile_overview_test.dart`, `profile_page_test.dart`, `ad_detail_page_test.dart`,
  `comment_thread_pagination_test.dart`).
- Republication de l'app : pas nécessaire pour le backend (ajout pur), nécessaire pour l'interrupteur.

---

## 9. Tests backend (à lancer par le propriétaire, jamais par l'agent)

| Test | Ce qu'il établit |
|---|---|
| `GpsRouteSyncPlannerTest` | Un cas par déclencheur : inscription → ligne voulue ; désinscription, annulation, suppression de sortie, groupe retiré (orphanRemoval), route supprimée → `desired_hash = null` ; nouvelle route de groupe, nouveau GPX, changement de groupe, changement de date → nouvelle empreinte, **même ligne** ; GPX réécrit en place par le backfill → empreinte inchangée ; sortie au-delà de J+7 ou passée de plus de 24 h ; groupe sans route → route de la sortie, route de groupe supprimée → rien (D2) ; brouillon, connexion `auto_sync = false`, `RECONNECT_REQUIRED` exclus ; isolation par domaine. Rejouer le tick n'écrit rien. |
| `GpsRouteSyncPlannerQueryCountTest` | Nombre de requêtes constant pour 1 et pour 50 inscriptions (modèle `CalendarQueryCountTest`). |
| `GpsRouteSyncWorkerTest` | Clients bouchonnés (`@InjectMock`, modèle `GpsServiceOAuth1Test`) : create, update, delete ; 404 sur update → `POST` ; 404 sur delete → succès ; 401 → refresh puis `RECONNECT_REQUIRED` ; 412 ; 429 → `sync_paused_until` ; backoff et `MAX_ATTEMPTS` ; route changée pendant l'appel → ligne toujours en écart. |
| `GpsRouteSyncWorkerDoubleUploadRaceTest` | Deux workers sur la même ligne → un seul `createRoute` (modèle `FeedbackGithubWorkerDoublePublishRaceTest`). |
| `GpsResourceTest` (étendu) | `PUT …/auto-sync` : activation, désactivation, 404 sans connexion, isolation par utilisateur ; `GET /api/users/me` porte l'état ; une seule requête pour l'état de toutes les connexions. |
| `GpsServiceTest` (étendu) | Déconnexion : `deauthorize` Hammerhead, `DELETE` Wahoo/Garmin, lignes supprimées avant la connexion, échec externe sans échec de la déconnexion. |
| `AccountErasureServiceTest`, export | Lignes de suivi supprimées ; nettoyage tenté ; `gps-route-syncs.json` présent. |
| Clients | Tests unitaires des requêtes construites (méthode, URL, signature OAuth 1 du `PUT`/`DELETE`, champs obligatoires du `PUT` Wahoo), à côté de `OAuth1SignerTest`. |

---

## 10. Étapes

0. **Vérifications externes** sur les comptes de test (sandbox Wahoo, compte Hammerhead, Garmin
   OAuth 1.0a) : code d'un `PUT`/`DELETE` sur un parcours supprimé par l'utilisateur, renommage par
   `PUT` Hammerhead, réponse du `PUT` Garmin, second `POST` Wahoo avec le même `external_id`, effet
   réel de `deauthorize`. Consigner les résultats ici ; ajuster le tableau du §4.4.
1. **Clients** : `GpsCallResult`, `createRoute`/`updateRoute`/`deleteRoute`, `deauthorize`
   Hammerhead, variantes OAuth 1.0a ; `uploadRoute` délègue. Corriger le commentaire de
   `WahooClient.java:261`.
2. **Jetons hors requête** : `GpsConnectionTokens`, surcharge de `getCredentials(domainId, …)`.
3. **`V71`**, entité, repository ; planificateur ; worker ; propriétés
   `pedalons.gps-sync.{enabled,horizon,retention,batch}` (`enabled=false` par défaut en prod
   jusqu'à la recette).
4. **Déconnexion, effacement, export.**
5. **Contrat** `11.5.0`, endpoint, DTO, régénération.
6. **Web** (`WEB-92`), **mobile** (`MOB-71`).
7. **Recette** en conditions réelles, un service à la fois : s'inscrire, changer la route du groupe,
   corriger le GPX, changer de groupe, se désinscrire, annuler la sortie, couper l'interrupteur, se
   déconnecter ; vérifier chez le service **et sur l'appareil**.

Conflit attendu : le checkout principal a des modifications non committées sur
`RideParticipationRepository` (`DeviceRegisteredGroupDto`, `RegisteredGroupRow`). *Résolu* : la
requête du §3.4 y est rangée **après** `findUpcomingRegisteredGroups`, sans import ajouté (types
qualifiés), si bien qu'une fusion à trois voies avec le checkout principal passe sans conflit
(vérifié avec `git merge-file` le 16 octobre).

---

## 11. Ce qui reste hors champ

- ~~Envois manuels~~ : finalement suivis, avec des lignes à `ride_id` nul que le planificateur ne
  voit pas (§3.6).
- **Voyages et étapes** (`TripParticipation`).
- **Déclenchement immédiat** (« nudge » dans la transaction métier) : la minute de latence du
  planificateur suffit pour des sorties à venir ; à rouvrir si la recette montre le contraire.
- **Retrouver un parcours Wahoo par `external_id`** quand l'identifiant est perdu : exigerait
  `routes_read`, donc une reconnexion de tous les utilisateurs Wahoo.
- **Webhooks de révocation** Garmin / Wahoo : restent dans `API-61` ; ici, la révocation se
  découvre au premier 401/412.
- **Membre retiré d'une équipe** : ses inscriptions restent (comportement actuel du métier), donc
  ses parcours aussi. Si le métier change, le planificateur suivra sans modification.
- **Politique de confidentialité** : l'envoi à un tiers à la demande de l'utilisateur existe déjà
  (envoi manuel) ; vérifier que la section des services GPS couvre un envoi automatique et ouvrir
  une entrée `LEGAL` si ce n'est pas le cas.

---

## 12. État de l'implémentation (16 octobre 2026)

*Mis à jour le 16 octobre 2026 au soir* : commité (`3b5df12e`, `f91a5264`), tests verts, déployé
(contrat `11.5.1`, `V71`). `GPS_SYNC_ENABLED=true` a été posé en prod et en staging **avant** la
recette de l'étape 7, qui reste à faire (`OPS-42`) ; la politique le décrit (`LEGAL-21`), le drapeau
est documenté dans `docs/OPERATIONS.md`. Premiers envois réels : 3 connexions, 5 parcours, aucune
erreur. Le texte ci-dessous est l'état au moment de l'implémentation.

| Étape | État |
|---|---|
| 0. Vérifications externes | **à faire** — rien n'a été appelé pour de vrai |
| 1. Clients | fait : `GpsAuth`, `GpsCallResult`, `RouteMeta`, `create/update/deleteRoute`, `refreshToken(credential, …)` ; pas de `deauthorize` (D9) |
| 2. Jetons hors requête | fait : `GpsConnectionTokens`, `DomainGpsCredentialService.getCredentials(domainId, …)` |
| 3. V71, planificateur, worker | fait : `V71__gps_route_autosync.sql`, `GpsRouteSync`, `GpsRouteSyncRepository`, `service/gps/sync/` (`GpsRouteSyncPlanner`, `GpsRouteSyncWorker`, `GpsRouteSyncExecutor`, `GpsSyncNames`) |
| 4. Déconnexion, effacement, export | fait (`account/gps-route-syncs.json`, `autoSync` dans `gps-connections.json`) |
| 5. Contrat | fait, `11.5.0` ; clients web et mobile régénérés, fixtures de type complétées (`profileStatus.test.ts`, `profile_overview_test.dart`) |
| 6. Web, mobile | fait (`WEB-92`, `MOB-71`) : interrupteur masqué tant que `ConfigDto.gpsAutoSyncEnabled` est faux, « Reconnecter » sur `RECONNECT_REQUIRED` ; `GpsConnectionsManager.test.tsx`, `gps_services_card_test.dart` |
| 7. Recette | à faire |

Tests écrits (non lancés) : `GpsRouteSyncPlannerTest`, `GpsRouteSyncPlannerQueryCountTest` (dont
l'état par route en une requête), `GpsRouteSyncWorkerTest`, `GpsRouteSyncWorkerDoubleUploadRaceTest`,
`GpsRouteSyncServiceTest` (envois manuels, reprise, état du profil, déconnexion, effacement),
`GpsResourceTest` (endpoint), `GpsRouteCallsTest` (requêtes des clients, signature OAuth 1.0a du
`DELETE`, champs du `PUT` Wahoo), `GpsSyncNamesTest` ; `UserExportBuilderTest` attend la nouvelle
section.

Revue du 16 octobre 2026, corrigée le même jour : reprise d'un envoi manuel écrite avant l'appel
(§3.6) ; rafraîchissement isolé, sérialisé, et son refus traité en reconnexion (§4.3) ; essais
remis à zéro à la reconnexion et à la réactivation ; colonnes d'arrêt écrites en masse seulement ;
bail de 5 min et délai sur les requêtes de jeton (§4.2) ; nettoyage de l'effacement hors
transaction (§4.6) ; même règle de visibilité des routes que `findUpcomingRegisteredGroups`
(brouillon ou masquée par la modération : jamais envoyée à un simple membre, retirée si elle le
devient) ; drapeau `ConfigDto.gpsAutoSyncEnabled` ; ID renuméroté `API-118` → `API-120`, l'ID
`API-118` étant pris sur `develop`. Tests ajoutés (non lancés) : `GpsRouteSyncWorkerTest`
(jeton expiré rafraîchi et gardé, refusé, en panne), `GpsRouteSyncServiceTest` (reprise dont le
premier `PUT` échoue, interrupteur réactivé), `GpsRouteSyncPlannerTest` (route brouillon, route
masquée, route de groupe brouillon), `GpsResourceTest` (reconnexion permise), `ConfigServiceTest`.

Points laissés ouverts, chacun au ledger :

- Libellé de groupe (règle `WEB-83`) et nom renvoyé par un envoi manuel d'une route tenue par la
  synchronisation : `API-120`, « Reste ».
- `docs/OPERATIONS.md` documente `GPS_SYNC_ENABLED` depuis le 16 octobre (`OPS-42`, dont reste la
  recette de l'étape 7).
- Politique de confidentialité (§11) : `LEGAL-21`, publiée le 16 octobre.

