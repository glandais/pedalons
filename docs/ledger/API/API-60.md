---
id: API-60
title: "Fuseau horaire des événements — livré du 6 au 7 octobre 2026 (contrats `10.17.0` → `11.0.0`)"
status: done
group: "Vie privée : les métadonnées retirées à l'import"
done: 2026-10-07
---

## Livré

### `API-60` Fuseau horaire des événements — livré du 6 au 7 octobre 2026 (contrats `10.17.0` → `11.0.0`)

**Clos le 7 octobre 2026**, les lots 0 à 7 en production. Une heure de rendez-vous (départ de
sortie, de groupe, d'étape, publication programmée) se saisit en heure murale, se stocke en instant
avec le fuseau de saisie que le backend résout (lieu de départ → parcours → étape précédente →
équipe), et se lit dans le fuseau de l'entité, avec la mention « heure de Tokyo (… chez vous) »
quand le décalage du lecteur diffère. Plan archivé :
[`2026-10-06-event-timezones.md`](../../plans/archive/2026-10-06-event-timezones.md).

Historique tel que le ledger l'a suivi :

Une heure de départ est saisie dans le fuseau de celui qui la tape, affichée dans le fuseau de celui
qui la lit, sans jamais nommer ni l'un ni l'autre ; l'heure d'un groupe (`LocalTime`) n'en a aucun.
Consulter la sortie de son équipe parisienne depuis Tokyo affiche 16:30 pour la sortie et 09:30 pour
son groupe ; préparer une étape au Japon depuis Paris oblige à convertir de tête. Le plan
[`2026-10-06-event-timezones.md`](../../plans/archive/2026-10-06-event-timezones.md) donne un fuseau obligatoire à
l'équipe (`Europe/Paris` à la migration), stocke sur chaque entité son *fuseau de saisie* résolu par
le backend (lieu de départ → parcours → étape précédente → équipe), fait passer
`ride_groups.time` en instant, saisit en heure murale et affiche les rendez-vous dans le fuseau de
l'entité avec une mention quand il diffère de celui du lecteur. Les instants restent la vérité
stockée, la fin stockée d'`API-85` comprise. Contrat en deux versions (ancien format de requête
toléré une version).
**Rouvert le 6 octobre 2026** : écarté le 2 octobre au profit de la préférence `UserDto.timezone`
(`API-15`), avec pour condition de réouverture « des voyages à l'étranger qui rendent l'heure locale
de l'étape nécessaire » — c'est le cas qui a déclenché l'audit. Le fuseau résolu est bien celui du
lieu de départ, comme la note d'alors le demandait ; celui de l'équipe n'est que le repli.
Plan validé le 6 octobre 2026 (décisions au §12). **Lot 0 livré le 6 octobre 2026** (`API-90`,
`API-91`, `API-92`, `WEB-70`, `WEB-71`).

**Lot 1 (backend) livré le 6 octobre 2026, contrat `10.17.0`** (mineure : l'ancien format de
requête est toléré). Livré :

- **Colonnes** (`V64__event_timezones.sql`) : `teams.timezone varchar(64) NOT NULL DEFAULT
  'Europe/Paris'`, `team_entities.timezone` et `ride_groups.start_at` nullables le temps d'une
  version, `users.timezone` élargie à 64 ; remplissage SQL du §8.2 (fuseau de l'équipe, `start_at`
  depuis `time` sur la date locale de la sortie). Les lignes que l'ancienne version écrit pendant la
  bascule sont remplies au démarrage par `EventTimezoneBackfill` (modèle de
  `PublicationEndBackfill`) ; les lectures retombent sur l'équipe et sur `legStart` en attendant.
- **Résolution** : `EventTimezoneResolver` (chaînes du §4, jamais UTC ; en mer, `timeshape` rend le
  fuseau nautique `Etc/GMT±n`, pas l'équipe). Sorties, voyages, étapes et articles stockent le
  fuseau de leur enregistrement ; `ride_groups.start_at` est écrit à chaque enregistrement de la
  sortie.
- **Contrat** : `dateTime` et `publishAt` des requêtes sont un `EventDateTime` (chaîne sans
  `format: date-time`) — heure murale lue dans le fuseau résolu, ou instant avec `Z`/offset gardé
  tel quel (ancien SPA) ; `TeamRequest.timezone` / `TeamDetailDto.timezone` ; `timezone` sur
  `RideDto`, `TripDto`, `TripStageDto`, `PostDto`, `RouteUsageDto`, `CalendarEventDto` ; `startAt`
  sur `RideGroupDto` et `RideGroupSummaryDto` (`time` servi, déprécié) ; nouvel appel
  `GET /api/teams/{teamSlug}/timezone?lat=&lon=` (organisateur au minimum).
- **Changement de fuseau d'équipe** (§9) : `TeamTimezoneChange`, dans la même transaction —
  entités à venir, sans lieu, stockées dans l'ancien fuseau, réécrites à heure murale constante ;
  seuls les instants encore à venir bougent ; la fin stockée est recalculée.
- **Tests** (écrits, à lancer) : `EventTimezoneResolverTest`, `EventDateTimeTest`,
  `RideTimezoneTest`, `TripTimezoneTest`, `PostTimezoneTest`, `TeamTimezoneResourceTest`,
  `TeamTimezoneChangeTest`, `EventTimezoneBackfillTest`, `PublicationEndStoredTest` étendu
  (changement de lieu, de fuseau d'équipe ; remplacement de GPX qui ne touche ni le fuseau ni le
  départ).

**Lot 2 (web) livré le 6 octobre 2026, contrat `10.18.0`** (mineure : un appel d'aperçu). Les
éditeurs de sortie, de voyage et de publication saisissent et renvoient des heures murales
(`WallDateTimePicker`, fin d'`InstantDateTimePicker`), y compris les menus publier / dépublier /
annuler (`rideToRequest`, `tripToRequest`, `postToRequest`) ; la mention « heure de Tokyo »
(`zoneLabel.ts`, `useZoneMention`) n'apparaît que si les décalages diffèrent ; pendant l'édition,
`useEventTimezone` suit la chaîne du §4 et interroge `…/timezone` (délai, un appel par point
distinct, aucun à l'ouverture d'une entité existante) ; « Ajouter une étape » = étape précédente
J+1 sur la chaîne (`addDaysToWallTime`, qui remplace `addCalendarDays` de `WEB-71`). Réglage du
fuseau d'équipe dans `TeamForm` (`TimezoneSelect`, villes nommées par la règle du §7), pré-rempli
avec le fuseau du navigateur à la création ; un changement passe par une confirmation qui montre
l'aperçu du §9, calculé par `GET /api/teams/{teamSlug}/timezone/change-preview` (admin, sans
écriture) : `TeamTimezoneChange.plan()` est la sélection que `apply()` réécrit, les deux ne
peuvent pas diverger. Vitest tourne en `Europe/Paris`. Tests : `wallTime.test.ts`,
`zoneLabel.test.ts`, `useEventTimezone.test.ts`, `useZoneMention.test.tsx`,
`TimezoneChangePreview.test.tsx`, `TeamTimezoneChangeTest` (aperçu = ce que le changement
réécrit, 403, 400). **À ne pas défaire** : le front ne calcule jamais le fuseau d'une donnée — il
envoie des heures murales et le backend résout ; le fuseau qu'il demande ou déduit ne sert qu'à
l'étiquette (et au contrôle « publication dans le futur »), et l'aperçu du §9 vient du backend, pas
d'un calcul client. Le scénario Playwright du §11 a suivi le 7 octobre 2026 :
`event-timezones.e2e.ts` (une équipe à Paris lue depuis un navigateur à Tokyo — heure de Paris,
mention avec le jour qui change, absente du rendu serveur et sans erreur d'hydratation, heure du
groupe seulement quand il part à la sienne, saisie de l'éditeur rendue telle quelle ; et l'inverse,
une équipe à Tokyo lue depuis Paris).

**Lot 3 (web) livré le 7 octobre 2026** (sans changement de contrat). Les rendez-vous se lisent dans
le fuseau de l'entité, les horodatages restent dans celui du lecteur : `useRendezvousFormat(zone)`
(formateurs dans le fuseau de l'entité, mention à l'instant de l'événement), `rendezvousMention`
(`utils/rendezvous.ts` : « heure de Tokyo (sam. 23:00 chez vous) », le jour seulement quand il
change, rien quand les décalages sont égaux) et `<Rendezvous>` (`detail` : mention en ligne ;
`card` : icône `IconWorld` + infobulle ; `ZoneMentionIcon` pour une plage ou un texte composé).
Appliqué aux détails (sortie, voyage et sa fin dans le fuseau de la dernière étape — `tripEndZone`,
étape, article, publication programmée), aux cartes et lignes (`PublicationCard`, tableau de bord,
`NextRideCard`, `RouteUsages`, profil, onglets d'étape), aux plages de l'Agenda
(`formatPublicationSpan`, une seule icône ; `DayBox` prend le fuseau de l'entité à côté d'une plage
en mode `time`), à l'heure des groupes (`startAt`, fin du « 08:30:00 » brut et de `shortTime`), au
calendrier (heure de l'événement en `p` selon la langue au lieu de `HH:mm` figé, mention dans
l'infobulle et en seconde ligne sur téléphone ; la grille reste celle du lecteur) et à la semaine de
l'accueil (jour et heure de la ligne dans le fuseau de l'entité ; bandeau, points et « aujourd'hui »
du lecteur). Décidé au passage : les heures de la météo (départ, passages, alerte pluie) suivent le
fuseau de la sortie ou de l'étape, sans mention (l'en-tête du détail la porte) ; la date SEO /
`og:` (`routeMeta.ts`) passe au fuseau de l'entité (une ligne, prise sur le lot 4). Tests :
`rendezvous.test.ts` (Paris lu depuis Bruxelles muet, Tokyo lu depuis Paris avec le jour qui change,
Londres/UTC selon l'heure d'été, plages et voyage multi-fuseaux), `Rendezvous.test.tsx`,
`routeMeta.test.ts` étendu. **À ne pas défaire** : la mention compare des décalages à l'instant de
l'événement, jamais des identifiants ; le texte dans le fuseau de l'entité est identique côté
serveur et client, seule la mention dépend du lecteur.

**Lot 3 (mobile) livré le 7 octobre 2026** (sans changement de contrat). Même règle que le web :
`zone_label.dart` reprend la table des villes françaises et la règle « de / d' / du / des » de
`zoneLabel.ts` (à garder en phase), les rendez-vous passent par `AppFormatters` dans le fuseau de
l'entité avec la mention (en ligne au détail, en seconde ligne sur les cartes), l'heure d'un groupe
vient de `startAt`, et l'heure suit le réglage 12 h / 24 h du téléphone
(`MediaQuery.alwaysUse24HourFormat`) au lieu de `DateFormat.Hm`. Un fuseau inconnu se lit dans
celui du lecteur, sans mention. Les heures de la météo restaient dans le fuseau du lecteur
(passées au fuseau de l'entité par le lot 4) ; la grille du calendrier y reste, journées entières
comprises. Tests : `display_timezone_test.dart` étendu
(Paris lu depuis Bruxelles muet, Tokyo lu depuis Paris avec le jour qui change), détail d'article,
fin de voyage par l'étape la plus tardive.

Arbitré à la relecture du lot 3 (web et mobile) : **pas de mention tant que le fuseau du lecteur
est le substitut du serveur** (`useEffectiveTimezone().isPlaceholder` : rendu SSR anonyme et rendu
d'hydratation) — calculée contre `UTC`, elle affirmait un « 06:00 chez vous » faux à tout visiteur
d'une équipe européenne ; elle apparaît au rendu qui suit l'hydratation (`Rendezvous.test.tsx`,
`renderToString`). **Un fuseau que l'`Intl` du navigateur ignore** (la base tz du JDK peut le
devancer : `Europe/Kyiv` sur un vieux Safari) se lit dans le fuseau du lecteur, sans mention, au
lieu de lever pendant le rendu (`isSupportedZone`, `zoneLabel.ts`) — la règle du mobile. **La date
d'un article est un rendez-vous complet sur les deux clients** : date et heure dans le fuseau de
l'article, puis la mention (`post_detail_page.dart` rejoint le détail web). **L'heure d'un groupe**
ne s'affiche que si `startAt` est un autre instant que le départ de la sortie
(`groupLeavesAtOwnTime`, web et mobile, jamais le `time` déprécié) et porte sa mention sur les deux
clients (icône à infobulle, focalisable au clavier, sur le web ; seconde ligne sur mobile). La fin
d'un voyage se lit dans le fuseau de l'étape **la plus tardive par instant**, pas la dernière par
ordre, sur les deux clients (`tripEndZone`, `TripTiming.endTimezone`).

**Lot 4 (consommateurs backend) livré le 7 octobre 2026** (contrat 10.19.0 → 10.21.0). **Une
seule source de départ** : la météo (détail et liste en SQL), les appareils
(`DeviceRouteService.departureZone`) et `PublicationEndCalculator` partent de `ride_groups.start_at`
via `EventTimezoneResolver.startAt` (repli, pour une ligne d'une version antérieure : `time` à la
date locale de la sortie dans son fuseau stocké, sinon celui de l'équipe) ; `legStart`,
`RideWeatherPlans.departure()` et `TimezoneService.getZoneId` (repli UTC) disparaissent, le fuseau de
`weather_cells` ne date plus que ses lignes journalières. `V65__ride_end_from_group_start.sql` vide
la fin stockée des sorties à venir ayant un groupe à l'heure, recalculée au démarrage par
`PublicationEndBackfill`. **10.19.0** : `DeviceRideDto.timezone` (Karoo et Garmin peuvent l'ignorer).
**10.20.0** : `NotificationDto.subjectTimezone`, figé au fan-out dans
`notification_events.subject_timezone` (`V66`, nullable sans défaut ni rattrapage : sûr en
déploiement start-first) ; `NotificationTexts` écrit l'heure du sujet dans son fuseau, nommé
(« heure de Tokyo », `ZoneLabels`) avec l'équivalent du lecteur quand il a un fuseau et qu'il
diffère. Les webhooks d'équipe écrivent dans le fuseau du sujet (plus Paris en dur), nommé quand ce
n'est pas celui de l'équipe, et le `subject.timezone` du format `GENERIC`. iCal : les étapes
« journée entière » sont datées dans le fuseau de `CalendarEventDto.timezone` (fin de
`StageTimezones`), `X-WR-TIMEZONE` vaut le fuseau de l'équipe pour un flux d'équipe, celui de la
sortie ou du voyage pour un ICS unitaire, et disparaît du flux personnel (plusieurs équipes). **10.21.0** :
`RideWeatherSummaryDto.timezone`, posé sur la carte d'un voyage — le fuseau de sa prochaine étape,
calculé dans la même requête de page (`findTripNextLegHours`), qui n'est pas `TripDto.timezone`
(la première) ; les deux clients le préfèrent au fuseau de la carte. Clients : `NotificationItem`
(web) et `subjectDateLine` (mobile) lisent la date du sujet dans `subjectTimezone` avec la mention ;
les heures de la météo mobile (départ, arrivée, passages, alerte pluie, chronologie, lever et
coucher du soleil) dans le fuseau de la sortie ou de l'étape, sans mention. Tests :
`NotificationTextsTest` (`rendezvousAbroad_readsInItsZone_withTheReadersEquivalent`,
`subjectWithoutAZone_readsInParis`…), `ZoneLabelsTest`, `NotificationPipelineTest`
(`publishedRide_freezesItsZone_andTheInboxCarriesIt`), `NotificationPhase5Test`
(`webhook_writesTheRideInItsZone_namedWhenNotTheTeams`), `IcsGenerationServiceTest`,
`CalendarServiceTest` (`icsFeeds_dateAnAllDayStage_inItsStoredZone`), `EventTimezoneResolverTest`
(`startAt_*`), `PublicationEndCalculatorTest`, `PublicationEndStoredTest`, `RideWeatherCalculatorTest`,
`WeatherCacheTest` (`forRides_aTimedGroup_startsWhereTheDetailStartsIt`),
`DeviceRoutesResourceTest`, `PublicationQueryCountTest` (le fuseau de la prochaine étape sur la
carte d'un voyage), `NotificationItem.test.tsx`, `RideWeatherSummaryLine.test.tsx`,
`ride_weather_summary_line_test.dart`, `notifications_page_test.dart`. Arbitré à la relecture : la
**grille** du calendrier reste celle du lecteur sur les deux clients, journées entières comprises
(plan §7 : une grille ne porte qu'un fuseau) — seule la date iCal d'une journée entière suit le
fuseau de l'étape (`calendar_month_test.dart`).

**Rattrapage du §8.3 mesuré le 7 octobre 2026, inutile** : en production comme en staging (V66,
`8fa64c44`), aucun `team_entities.timezone` ni `ride_groups.start_at` nul, et aucune sortie ni étape
à venir n'a de lieu de départ ou de parcours hors de la France métropolitaine (197 sorties et 18
étapes en production) : la requête en commentaire à la fin de `V64__event_timezones.sql` ne trouve
rien à ré-résoudre. Le rattrapage Java n'a pas été écrit.

**Lot 5 (version N+1) livré le 7 octobre 2026, contrat `11.0.0`** (majeure : l'ancien format de
requête est refusé). `V67__event_timezones_not_null.sql` refait le remplissage SQL de V64 (filet de
sécurité, zéro ligne attendue) puis pose `NOT NULL` sur `team_entities.timezone` et
`ride_groups.start_at` ; `EventTimezoneBackfill` et tous les replis disparaissent (`TeamEntity.zone()`
sans l'équipe, `EventTimezoneResolver.startAt` et `applyGroupStarts` retirés : chaque lecteur prend
`RideGroup.startAt`, que la météo SQL lit sans `coalesce`). `EventDateTime.parse` n'accepte plus
qu'une heure murale (`ISO_LOCAL_DATE_TIME`) : un instant avec `Z` ou un offset est un 400. Retirés :
les surcharges `Instant` de `RideRequest`, `TripRequest`, `PostRequest` et du builder de
`StageRequest`, les constructeurs de compatibilité de `TeamRequest` et `CalendarEventDto` (les tests
passent par `WallTimes.wall`). Le départ d'un groupe s'écrit au moment où la requête le donne
(`EventTimezoneResolver.setStart`, dans `RideService.setProperties`) ; l'heure propre d'un groupe se
relit depuis `startAt` (`EventTimezoneResolver.ownTime` : nulle quand le groupe part avec la sortie)
pour `RideGroupDto.time`, `RideGroupSummaryDto.time` et l'export RGPD (qui gagne `startAt`) ; un
changement de fuseau d'équipe garde l'heure propre de chaque groupe d'une sortie à venir.
**Écart au plan** : `ride_groups.time` n'est **pas** supprimée par ce lot. La version précédente la
mappe encore pendant la minute de bascule start-first (la supprimer ferait échouer chacune de ses
requêtes sur `ride_groups`) et après un retour arrière : elle est écrite (`RideGroup.legacyTime`) et
jamais lue, jusqu'au lot 6. Conséquence acceptée : un groupe dont l'heure saisie égale le départ de
la sortie se relit « part avec la sortie », et suit donc la sortie si son heure change ensuite (le
test de migration biketeam le dit). Tests (lancés le 7 octobre 2026, suite backend verte) : `EventDateTimeTest` (Z, offset et
`[Europe/Paris]` refusés, JSON en `InvalidFormatException`), `RideTimezoneTest`
(`anInstantWithZ_is400`, `anInstantWithAnOffset_is400`), `EventTimezoneResolverTest` (`setStart`,
`ownTime`, aller-retour), `PublicationEndCalculatorTest`, `WeatherCacheTest`, `WeatherPlannerTest`,
`TeamTimezoneChangeTest`, `BiketeamLiveMigrationTest` ; supprimés : `EventTimezoneBackfillTest` et
les tests des replis (groupe sans `start_at`, entité sans fuseau).

**Lot 5 vérifié en production et en staging le 7 octobre 2026** (`5fb6003e`, `/api/version`
`11.0.0`, V67 appliquée : les deux colonnes `NOT NULL`, aucune erreur au démarrage).

**Lot 6 livré le 7 octobre 2026** (sans changement de contrat ni migration) : `RideGroup.legacyTime`
retiré, Hibernate ne lit ni n'écrit plus `ride_groups.time` ; `EventTimezoneResolver.setStart` ne
pose plus que `startAt`, et `TeamTimezoneChange.rewriteRide` ne touche plus aux groupes d'une sortie
passée. La colonne reste en base, nullable et ignorée : un retour au lot 5 la retrouve (il ne la
lit pas non plus). Sa suppression est le lot 7, dans un déploiement suivant.

**Reste du lot 4 livré le 7 octobre 2026** (sans changement de contrat : l'export RGPD n'est pas
au contrat) : `notifications/inbox.json` porte `subjectTimezone` à côté de `subjectDateTime`
(`NotificationExport.InboxEntry`), nul pour une entrée antérieure à `V66`, comme dans la boîte de
réception. Test : `UserExportBuilderTest.build_shouldIncludeTheNotificationInboxWithItsDeliveries`.

**Lot 7 livré le 7 octobre 2026** (sans changement de contrat) : `V68__drop_ride_groups_time.sql`
supprime `ride_groups.time`, déployé seulement après le lot 6 — la version en service ne mappait
plus la colonne. Le départ d'un groupe n'existe plus que dans `ride_groups.start_at`.

À ne pas défaire :

- **Un seul départ d'un groupe** : `RideGroup.startAt` (`NOT NULL` depuis V67), écrit par
  `EventTimezoneResolver.setStart`, lu par la météo, les appareils, la fin stockée et le détail —
  jamais un fuseau tiré du point de départ ni un repli UTC, sans quoi la fin, la météo et l'heure
  affichée divergent. L'heure d'un groupe se relit de `startAt` (`ownTime`) ; `time` n'existe plus (V68).
- **Une requête ne porte que des heures murales** : `EventDateTime` refuse `Z` et les offsets
  (400) ; le client ne décide jamais du fuseau d'un rendez-vous.
- **`X-WR-TIMEZONE` seulement sur un flux d'équipe ou un ICS unitaire**, jamais sur le flux
  personnel, qui mêle des équipes de fuseaux différents.
- **`subject_timezone` nul se lit à Paris dans les textes du serveur** (toutes les équipes l'étaient
  avant `V66`), dans le fuseau de l'équipe pour un webhook, dans celui du lecteur côté client ; ne
  pas le rattraper ni lui donner de défaut (sûreté du déploiement start-first).
- **`ZoneLabels` est la troisième copie de la table des villes**, après `zoneLabel.ts` et
  `zone_label.dart` : les trois restent en phase.
- **La ligne météo d'un voyage se lit dans le fuseau de sa prochaine étape**
  (`RideWeatherSummaryDto.timezone`), pas dans `TripDto.timezone`.
- **La grille du calendrier est dans le fuseau du lecteur**, journées entières comprises, sur le
  web comme sur mobile ; la date de l'étape dans son propre fuseau ne vaut que pour iCal.
- **Le fuseau stocké est un fuseau de saisie, pas un cache** : figé à l'enregistrement de l'entité,
  recalculé seulement par un nouvel enregistrement (ou un changement de fuseau d'équipe, §9) ;
  jamais par effet de bord — un GPX remplacé, un lieu modifié ne déplacent ni fuseau ni départ
  (`PublicationEndStoredTest#replacingARoutesTrack_movesTheEnd_butNeitherTheZoneNorTheStart`).
- **Le backend est la seule autorité du fuseau** : les clients envoient des heures murales et
  n'en calculent aucun ; `…/timezone` ne sert qu'à étiqueter un champ.
