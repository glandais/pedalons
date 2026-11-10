# Dates et heures dans le mobile Flutter : vue transversale

Lecture seule du worktree `feat/mobile-review` (commit `ef1fc9a99`), faite le 2026-11-10. Les chemins sont relatifs à `mobile/lib/`, sauf ceux qui commencent par `frontend/`.
Les exemples sont calculés à partir des motifs `intl` 0.20.3, la version du `pubspec.lock` : en `fr`, `MMMEd` = `EEE d MMM`, `yMMMEd` = `EEE d MMM y`, `Hm` = `HH:mm` et **`jm` = `HH:mm`** ; en `en`, `MMMEd` = `EEE, MMM d` et `jm` = `h:mm a`. Je n'ai rien exécuté : aucun rendu n'a été observé à l'écran.

Sources des règles : `mobile/CLAUDE.md` (puce « Timestamps render in the user's timezone… »), puis l'en-tête de la section dates de `core/utils/formatters.dart` (l. 295-319). `mobile/RULES.md` ne dit rien des dates.

---

## 1. Modèle de données

### Types du client généré (`api/generated/models/`)

| Type | Définition | Sens |
|---|---|---|
| `EventDateTime` | `typedef EventDateTime = String;` (`event_date_time.dart`) | heure murale **sans offset**, `2026-10-11T08:00:00`. Elle n'apparaît que dans les requêtes ; les DTO déclarent `String` |
| `LocalTime` | `typedef LocalTime = String;` (`local_time.dart`) | « HH:mm[:ss] » ; sert à `GroupRequest.time`, `RideTemplateGroupRequest.time` et `RideTemplateGroupDto.time` |
| `Instant` | `typedef Instant = DateTime;` (`instant.dart`) | défini, mais les DTO lus ici transportent les instants en `String` ISO UTC |

Le client ne parse aucune date à la désérialisation : chaque écran reçoit des `String` et les parse lui-même (`DateTime.tryParse`, `AppFormatters.tryParse*`).

### Champs datés par entité

| DTO | Champ | Nature (doc du contrat) |
|---|---|---|
| `RideDto` / `PublicationDtoRide` | `dateTime` (requis) | départ de la sortie, l'instant de RDV : c'est aussi l'heure des groupes qui n'ont pas d'heure propre |
| | `timezone` (requis) | IANA ; résolu par le lieu de départ, sinon le parcours, sinon l'équipe ; `dateTime`, `publishAt`, `endDateTime` et les `startAt` des groupes se lisent dans ce fuseau |
| | `endDateTime` (requis) | fin calculée par le serveur (dernier groupe, au rythme de son allure ; +3 h quand elle est inconnue) |
| | `finished` (requis) | départ passé |
| | `publishAt`, `createdAt` | publication programmée ; horodatage |
| `RideGroupDto` | `startAt` (requis) | départ du groupe : l'heure propre du groupe, sinon `ride.dateTime` |
| | `time` (déprécié) | heure murale du fuseau de la sortie, nulle si le groupe part avec la sortie. Seul l'éditeur la lit |
| `RideGroupSummaryDto` | `startAt` (requis), `time` (déprécié) | idem, sur les lignes de liste |
| `TripDto` / `PublicationDtoTrip` | `dateTime`, `timezone` (fuseau de la 1ʳᵉ étape, sinon du parcours, sinon de l'équipe), `endDateTime`, `endDate` (date de la dernière étape, nulle sans étape), `publishAt`, `createdAt`, `finished` | |
| `TripStageDto` | `dateTime`, `timezone` (propre à l'étape, il peut différer de celui du voyage), `stageIndex`, `stageCount` | |
| `PostDto` | `dateTime` (date de publication), `timezone` (celui de l'équipe à la dernière sauvegarde), `publishAt`, `createdAt` | traité comme un RDV |
| `CalendarEventDto` | `start` (pour une sortie où l'on est inscrit : le `startAt` de son groupe), `end`, `allDay`, `timezone`, `finished` | |
| `RouteUsageDto` | `dateTime`, `timezone`, `endDate` (voyages seulement) | |
| `NotificationDto` | `createdAt` (horodatage), `subjectDateTime`, `subjectTimezone` (absent avant 10.20.0) | |
| `RideWeatherSummaryDto` | `availableFrom`, `timezone` (sur la carte d'un voyage, celui de la prochaine étape) | |
| `DepartureWeatherDto` | `sunrise`, `sunset` (« at the meeting point ») | |
| `UserDto` | `timezone` (nullable : null signifie « suivre l'appareil »), `createdAt` | |
| `TeamDetailDto` | `timezone` (requis) | fuseau par défaut de l'équipe |
| `TeamTimezoneDto` | `timezone` | fuseau d'un point, sinon celui de l'équipe (`getTeamTimezone`) |
| Requêtes `RideRequest`, `TripRequest`, `StageRequest` | `dateTime`, `publishAt` | heures murales sans offset, lues par le serveur dans le fuseau résolu |

**Heure de RDV ou heure de départ ?** Le contrat ne connaît **aucun champ « heure de rendez-vous » distinct** (recherche de `meeting|meetAt|gathering` sur les modèles : seuls `sunrise`/`sunset`, « at the meeting point », et des commentaires sortent). Il n'existe qu'un départ : celui de la sortie (`dateTime`) et celui de chaque groupe (`startAt`).

---

## 2. Utilitaires

### Réglages globaux (`core/utils/formatters.dart`)

| Fonction | Rôle | Appelée depuis |
|---|---|---|
| `setDisplayTimezone(String? name)` (l. 365) | pose le fuseau d'affichage ; `null` = appareil. Un nom inconnu retombe sur l'appareil | `app.dart:71`, avec `authState.user?.timezone` |
| `setUse24HourFormat(bool)` (l. 338) | 24 h ou 12 h ; vaut 24 h par défaut | `app.dart:75`, avec `MediaQuery.alwaysUse24HourFormat` |
| `timezoneNames()` (l. 342) | noms IANA contenant `/`, plus `UTC`, triés | `timezone_sheet.dart` |

### Conversions de fuseau

| Fonction | Signature | Comportement |
|---|---|---|
| `toDisplayTime` (l. 411) | `DateTime → DateTime` | un instant UTC devient l'heure murale du fuseau d'affichage, rendue sous forme de `DateTime` local. **Une date non UTC est rendue telle quelle** : c'est ce qui empêche la double conversion. Sans préférence de fuseau : `.toLocal()` |
| `tryParseDisplayTime` (l. 443) | `String? → DateTime?` | parse puis `toDisplayTime` |
| `displayNow` (l. 421) | `→ DateTime` | « maintenant » à l'heure murale du lecteur |
| `displayWallClockToUtc` (l. 425) | `DateTime → DateTime` | inverse : bornes de mois envoyées à l'API (`calendar_repository.dart:31-33`) |
| `toZoneTime` (l. 462) | `(DateTime, String? zone) → DateTime` | heure murale du fuseau de l'entité. Un fuseau inconnu retombe sur le fuseau d'affichage ; une date non UTC est rendue telle quelle |
| `tryParseZoneTime` (l. 471) | `(String?, String?) → DateTime?` | |
| `zoneWallClockToUtc` (l. 481) | `(DateTime, String?) → DateTime` | inverse, pour l'éditeur |
| `sameOffsetAt` (l. 512) | `(DateTime, String?) → bool` | compare des **décalages** à l'instant donné, pas des identifiants. Un fuseau inconnu compte comme identique |

### Formateurs de date et d'heure

Les exemples supposent `fr`, l'année en cours 2026 et un téléphone en 24 h.

| Fonction | Fuseau appliqué | Format FR | Format EN |
|---|---|---|---|
| `formatTime(d)` (l. 586) | `toDisplayTime(d)` : sans effet sur une heure murale déjà convertie | `Hm` ou `jm` : « 08:30 ». **En `fr`, `jm` vaut aussi `HH:mm`, donc le réglage 12 h ne change rien** | 24 h → « 08:30 » ; 12 h → « 8:30 AM » |
| `formatDayMonth(d)` (l. 592) | affichage | « 15 janvier », assemblé à la main | « 15 january » : `monthLower` met le mois en minuscules, même en anglais (déduit du code, non observé) |
| `formatFullDate(d)` (l. 598) | affichage | « lundi 15 janvier », **jamais d'année** | « Monday 15 january » : l'ordre jour-mois français est imposé et le mois passe en minuscules (déduit du code) |
| `formatMonthYear(d)` (l. 604) | affichage | « Janvier 2026 » | « January 2026 » |
| `formatLongDate(d)` (l. 610) | affichage | « lundi 15 janvier 2026 », **toujours l'année** | « Monday 15 january 2026 » (déduit) |
| `formatLongDateTime(d)` (l. 614) | affichage | « lundi 15 janvier 2026 à 08:30 » (`dates.at`) | « Monday 15 january 2026 at 8:30 AM » |
| `dayAbbrev(w)` / `dayFull(w)` | — | « lun. » / « lundi » | « Mon » / « Monday » |
| `monthAbbrev(m)` / `monthLower` / `monthCapitalized` | — | « janv. » / « janvier » / « Janvier » | « Jan » / « january » / « January » |
| `today` / `tomorrow` | — | « Aujourd'hui » / « Demain » | « Today » / « Tomorrow » |
| **`formatDepartureRelative(i, zone)`** (l. 669) | entité ; « maintenant » pris dans le fuseau de l'entité | « Aujourd'hui », « Demain », sinon `null` (hier compris) | |
| **`formatDepartureDate(i, zone)`** (l. 689) | entité | « sam. 12 avr. » ; « sam. 10 avr. 2027 » hors de l'année en cours (année jugée dans le fuseau de l'entité) | « Sat, Apr 12 » ; « Sat, Apr 10, 2027 » |
| **`formatDeparture(i, zone)`** (l. 710) | entité | « sam. 12 avr. · 09:00 », « Demain · 09:00 » (`dates.departureAt`) ; la mention de fuseau reste à la charge de l'appelant | « Sat, Apr 12 · 9:00 AM » |
| `formatRendezvous(i, zone)` (l. 574) | entité | `formatDeparture` + « · heure de Tokyo (ven. 01:00 chez vous) » | « … · Tokyo time (Fri 1:00 AM your time) » |
| `zoneMention(i, zone)` (l. 529) | — | « heure de Tokyo », « heure d'Athènes », « heure du Caire », ou `null` quand le décalage est le même | « Tokyo time » |
| `readerEquivalent(i, zone)` (l. 542) | lecteur | « 01:00 » ; « ven. 01:00 » quand le jour du lecteur diffère de celui de l'entité | « Fri 1:00 AM » |
| `formatZoneMention(i, zone)` (l. 557) | — | « heure de Tokyo (ven. 01:00 chez vous) » ou `null` | « Tokyo time (Fri 1:00 AM your time) » |
| `formatRelative(d)` (l. 730) | affichage | « à l'instant » (moins de 60 s), « il y a 5 minutes », « il y a 2 heures », « il y a 3 jours », « dans 2 jours » ; **au-delà de 7 jours : `formatLongDate`** (« lundi 15 janvier 2026 ») | « just now », « 2 hours ago », « in 2 days » |

Le commentaire de `CLAUDE.md` et de `formatters.dart:726` annonce « il y a 2 h » et « dans 2 h ». Le catalogue réel (`assets/l10n/fr.json` → `dates.relative.*`) écrit en toutes lettres : « il y a 2 heures ».

### Autres helpers

| Fonction | Emplacement | Format / comportement |
|---|---|---|
| `zoneCityName(tz, lang)` / `zoneCityOf(tz, lang)` | `core/utils/zone_label.dart` | `Asia/Tokyo` → « Tokyo » / « de Tokyo » ; `Europe/London` → « Londres » en fr ; `Etc/GMT-9` → « UTC+9 ». Portage de `frontend/src/utils/zoneLabel.ts` : les deux tables doivent évoluer ensemble |
| `ZoneMentionLine(instant, zone)` / `ZoneMentionLine.maybe(iso, zone)` | `core/widgets/zone_mention_line.dart` | seconde ligne en `xs` atténué, avec une icône `otherTimezone`, porteuse de `formatZoneMention` ; ne rend rien quand le décalage est le même |
| `dayBoxFor(wall, …)` | `core/widgets/day_box.dart:15` | boîte « sam. / 12 / avr. », plus l'année quand `wall.year` diffère de **`displayNow().year`** (l'année du lecteur, voir §5) |
| `myStartAt(rideDateTime, joined)` | `features/rides/domain/group_start.dart:13` | `joined?.startAt ?? rideDateTime` : « mon heure » (MOB-112) |
| `groupLeavesAtOwnTime(startAt, rideDateTime)` | idem l. 23 | compare des **instants**, pas des chaînes |
| `someGroupLeavesAtOwnTime(startAts, ref)` | idem l. 35 | dès qu'un groupe part à son heure propre, tous les groupes affichent la leur (même règle qu'au web) |
| `formatGroupStart(startAt, tz)` | idem l. 40 | `formatTime(tryParseZoneTime(startAt, tz))` → « 08:30 », ou « — » |
| `formatGroupTime(String time)` | `features/rides/presentation/widgets/editor/ride_group_editor.dart:21` | `LocalTime` « HH:mm[:ss] » → `formatTime` (éditeur) |
| `formatWeatherTime(iso, zone)` | `features/rides/domain/ride_weather_display.dart:185` | `formatTime(toZoneTime(…))`, **sans mention** ; « — » si illisible |
| `formatRainAlert(alert, units, zone)` | idem l. 193 | « Pluie probable (60 %) vers 14:00. » |
| `tripDaySpan(dateTime, endDateTime, timezone:, endTimezone:)` | `features/teams/domain/publication_timing.dart:42` | « ven. 16 oct. » sur un seul jour ; « ven. 16 → dim. 18 oct. » dans le même mois ; « ven. 30 oct. → dim. 1 nov. » sur deux mois ; année seulement hors de l'année en cours (formatage dans les fuseaux de début et de fin) |
| `isUnderWay(...)` | idem l. 15 | « En cours », comparé en UTC |
| `calendarDayLabel(day)` | `features/calendar/presentation/widgets/agenda_card.dart:63` | « Aujourd'hui · samedi 12 avril », « Demain · … », « lundi 14 avril » (jour du lecteur) |
| `subjectDateLine()` | `features/notifications/presentation/notification_display.dart:65` | « Départ : sam. 12 avr. · 09:00 · heure de Tokyo (…) » ou « Nouvelle date : … » |
| `wallTimeOf` / `parseWallTime` / `instantToWallTime` / `nextWeekdayWallTime` | `features/rides/domain/ride_form.dart:24-72` | aller-retour avec l'API (`yyyy-MM-ddTHH:mm:ss`). Ce ne sont pas des formats d'affichage |

### Préférence de fuseau

- `features/profile/presentation/widgets/timezone_sheet.dart` : une recherche, qui ignore la casse et les `_`, puis la liste de `AppFormatters.timezoneNames()`. Les libellés sont le nom IANA avec `_` remplacé par une espace (« America/New York »), **sans décalage ni nom de ville traduit**.
- `preferences_section.dart:121-136` : la ligne affiche `user.timezone`, ou « fuseau de l'appareil » (`profile.status.deviceTimezone`).
- Le fuseau d'équipe n'intervient que dans l'éditeur de sortie. `ride_editor_page.dart:265-303` résout le fuseau dans cet ordre : lieu de départ (`getTeamTimezone(lat, lon)` via `ride_editor_repository.dart:161`), puis départ du parcours, puis `widget.team.timezone`. À l'affichage, il n'est jamais lu directement : il arrive déjà résolu dans `RideDto.timezone`, `PostDto.timezone`, etc.
- **Le mobile n'a pas d'éditeur de voyage ni d'étape** : `features/trips` ne contient aucun éditeur.

---

## 3. Règles d'affichage (telles que le code les applique)

1. **Horodatage ou rendez-vous.**
   - Un horodatage (création, commentaire, notification reçue, annonce, appareil appairé, passkey, adhésion, webhook) se lit dans le fuseau du profil, sinon dans celui de l'appareil, via `toDisplayTime`.
   - Un rendez-vous (départ de sortie, de groupe ou d'étape, dates d'un voyage, date d'un post, sujet d'une notification, événement de calendrier) se lit dans le fuseau de l'entité, via `toZoneTime`.
2. **Mention de fuseau.** Elle ne s'affiche que si le **décalage** de l'entité diffère de celui du lecteur à cet instant. Elle prend deux formes :
   - en seconde ligne, avec `ZoneMentionLine` : cartes, blocs de départ, agendas ;
   - en ligne, après « · », avec `formatRendezvous` : notifications.

   Les heures météo n'ont jamais de mention. Le nom du fuseau, sa ville ou son décalage n'apparaissent jamais en dehors de cette mention.
3. **24 h ou 12 h** : réglé par le téléphone (`alwaysUse24HourFormat`). Mais en pratique, en `fr`, `DateFormat.jm()` produit déjà `HH:mm`, donc **le français est toujours en 24 h** ; seul l'anglais varie (« 9:00 AM » ou « 09:00 »). Déduit des motifs `intl` ; aucun test ne le vérifie à ma connaissance.
4. **Relatifs.**
   - Pour un départ, seuls « Aujourd'hui » et « Demain » existent (BRAND-8). Ils sont jugés **dans le fuseau de l'entité** et masqués pour une sortie passée ou annulée (`showRelative`, `trip.isPast || trip.isCancelled`).
   - Pour un horodatage, `formatRelative` produit « il y a… » ou « dans… » jusqu'à 7 jours, puis la date longue.
   - L'agenda préfixe ses en-têtes de jour par « Aujourd'hui · » ou « Demain · », dans le jour du lecteur.
5. **Année.** `formatDepartureDate` ne la donne que hors de l'année en cours. `dayBoxFor` aussi, mais il juge l'année du lecteur. `formatLongDate` la donne toujours, `formatFullDate` et `formatDayMonth` jamais.
6. **Plages (voyages).** `tripDaySpan` :
   - un seul jour : « ven. 16 oct. » ;
   - même mois : « ven. 16 → dim. 18 oct. » ;
   - deux mois : « ven. 30 oct. → dim. 1 nov. ».

   Le même jour et le même mois se jugent sur les heures murales de l'entité (début dans `timezone`, fin dans `endTimezone`). Les cartes de liste n'ont pas les étapes : la fin se lit alors dans le fuseau du voyage.
7. **RDV ou départ.** Le contrat ne distingue pas les deux (§1). « Départ 09:00 » (`rides.departureBlock.departs`) est le titre unique de toutes les lignes et de tous les blocs de départ.
8. **Groupes à des heures différentes.**
   - Sur le détail d'une sortie, le bloc donne **l'heure de la sortie**, puis « Votre groupe : B · 09:30 » quand le groupe rejoint part à son heure propre (`ride_departure_block.dart:72-80`).
   - Sur une carte de groupe, le bandeau « Départ 22:30 » apparaît quand `showDeparture` est vrai, c'est-à-dire dès qu'un groupe de la sortie part à son heure. Le jour (« mer. 30 juil. ») s'ajoute quand il diffère du jour de la sortie (`ride_group_card.dart:208-247`).
   - Sur les listes, l'accueil et le tableau de bord, l'heure affichée est celle **du groupe de la personne** (`myStartAt`).
   - Dans le calendrier, `CalendarEventDto.start` est déjà l'heure du groupe, calculée par le serveur.
   - La ligne de groupe du tableau de bord donne « B · 25 km/h · départ 08:30 » (`dashboard_rides.dart:663-670`).
9. **Agrégations par jour.** La grille du calendrier, le regroupement par jour et la semaine de l'accueil suivent le **jour du lecteur** (`CalendarMonth.dayOf` : `toDisplayTime`). En revanche, la boîte du jour et l'heure de chaque carte sont dans le fuseau de l'entité. Une sortie à Tokyo peut donc se ranger sous le vendredi du lecteur tout en affichant « sam. » dans sa boîte. C'est voulu (commentaires de `agenda_card.dart:89-93` et `week_agenda_section.dart:159-162`).

---

## 4. Usages par entité

« Mention » désigne `ZoneMentionLine` en seconde ligne. Les exemples supposent `fr`, 24 h et l'année en cours.

### Sortie / groupe

| Emplacement | Fonction(s) | Rendu | Exemple |
|---|---|---|---|
| `features/rides/presentation/widgets/ride_departure_block.dart:46-104` (détail de la sortie et page de groupe) | `toZoneTime`, `formatTime`, `formatDepartureRelative`, `formatDepartureDate` (lecteur d'écran seulement), `dayBoxFor`, `formatGroupStart`, `formatZoneMention` | boîte du jour, « Départ 09:00 », pastille relative, sans ligne de date ; groupe : « Votre groupe : B · 09:30 » ; page de groupe : heure du groupe, puis « Arrivée estimée 13:10 » ; mention | « [sam./12/avr.] Départ 09:00 · Demain » |
| `features/rides/presentation/widgets/ride_group_card.dart:208-247` | `toZoneTime`, `formatTime`, `formatDepartureDate` | bandeau « Départ 22:30 » + « mer. 30 juil. » quand le jour diffère de celui de la sortie ; **jamais relatif** ; mention | « Départ 22:30 · mer. 30 juil. » |
| `features/rides/presentation/widgets/ride_group_stats.dart:24,66-68` | `formatGroupStart`, `formatWeatherTime` | stat « 08:30 » + mention ; arrivée du leg | « 08:30 » |
| `features/rides/presentation/widgets/departure_weather_section.dart:93,156,163` | `formatWeatherTime` | heure de départ, lever, coucher (sans mention) | « 07:42 » |
| `features/rides/presentation/widgets/weather_leg_sections.dart:61,585` | `formatLongDateTime` (affichage) | prévision périmée, attribution | « Prévision de lundi 15 janvier 2026 à 08:30 » |
| `weather_leg_sections.dart:170-171,333` | `formatWeatherTime` | début et arrivée d'un leg, frise | « 09:00 → 12:40 » |
| `ride_weather_map_markers.dart:140,334`, `ride_group_weather_line.dart:72` | `formatWeatherTime` | passages, alerte pluie | « vers 14:00 » |
| `ride_weather_summary_line.dart:82,122` | `formatDayMonth` (affichage), `formatWeatherTime` | « Prévision à partir du 12 avril » ; alerte | « 12 avril » |
| `ride_weather_widgets.dart:219` | `formatFullDate` | « Prévision disponible à partir du samedi 12 avril » | |
| `features/rides/presentation/pages/ride_editor_page.dart:967,975,978,1119` | `formatLongDate`, `formatTime`, `ZoneMentionLine`, `formatLongDateTime` | lignes Date et Heure de l'éditeur, publication programmée | « samedi 12 avril 2026 », « 09:00 », « samedi 12 avril 2026 à 09:00 » |
| `features/rides/presentation/widgets/editor/ride_group_editor.dart:30,260` | `formatGroupTime` | heure propre d'un groupe | « 09:30 » |

### Accueil

| Emplacement | Fonction(s) | Rendu | Exemple |
|---|---|---|---|
| `features/home/presentation/widgets/next_ride_card.dart:73-80,141,264,280-296` | `myStartAt`, `formatDepartureRelative`, `dayBoxFor(toZoneTime)`, `formatTime`, `ZoneMentionLine.maybe` | boîte du jour posée sur l'image, pastille « Aujourd'hui »/« Demain », « Départ 09:00 » en grand, mention, nom du groupe | « Départ 09:00 » + pastille « Demain » |
| `features/home/presentation/widgets/week_agenda_section.dart:163-206` | `toZoneTime`, `formatTime`, `dayBoxFor` (compacte), `ZoneMentionLine.maybe` | « 09:00 · Équipe » (pas d'heure pour un événement sur la journée) | « 09:00 · Les Pédaleurs » |
| `features/home/providers/week_events_provider.dart:27` | `displayNow` | fenêtre de la semaine (lecteur) | — |

### Fil / cartes de publication (équipe)

| Emplacement | Fonction(s) | Rendu | Exemple |
|---|---|---|---|
| `features/teams/presentation/widgets/publication_card.dart:344-363` (sortie) et `664-720` (`_Departure`) | `myStartAt`, `formatDepartureRelative`, `dayBoxFor`, `formatTime`, `formatZoneMention` | boîte du jour sur l'image, pastille relative, « Départ 09:00 », mention | « Départ 09:00 » |
| `publication_card.dart:539-556` (voyage) | `_Departure.of` + `tripDaySpan` en `trailing` | « Départ 09:00 · ven. 16 → dim. 18 oct. » | |
| `publication_card.dart:475,507` (post) | `tryParseZoneTime`, **`formatLongDate`** | stat avec l'icône date ; **pas d'heure ni de mention** | « samedi 11 octobre 2026 » |
| `features/teams/presentation/widgets/dashboard/dashboard_rides.dart:105-110` | `tryParseZoneTime(myStartAt)` | jour de la carte « mes prochaines » | — |
| `dashboard_rides.dart:269-315` (`_departure`) | `formatTime`, `formatDepartureRelative ?? formatDepartureDate` (lecteur d'écran), `tripDaySpan` | « Départ 09:00 » ; voyage : « Départ 09:00 · ven. 16 → dim. 18 oct. » ; mention | |
| `dashboard_rides.dart:482,533-535` (prochaines sorties) | **`formatDeparture`** | « sam. 12 avr. · 09:00 » / « Demain · 09:00 » + mention | |
| `dashboard_rides.dart:663-670` | `formatGroupStart` | « B · 25 km/h · départ 08:30 » | |
| `dashboard/dashboard_todo.dart:223` | `formatDeparture` | « Sortie du samedi, sam. 12 avr. · 09:00 » (pas de mention) | |
| `dashboard/dashboard_content.dart:64-74` (posts) | `tryParseZoneTime`, **`formatDayMonth`** | « 11 octobre · Auteur · 3 commentaires » | |
| `dashboard/dashboard_admin.dart:197-198` | `tryParseDisplayTime`, `formatRelative` | adhésion d'un membre | « il y a 3 jours » |
| `dashboard_admin.dart:315,344` | `formatDayMonth` | dernier envoi d'un webhook | « 15 janvier » |
| `features/teams/presentation/pages/team_members_page.dart:346,364` | `tryParseDisplayTime` + **interpolation** `monthCapitalized(...).toLowerCase() + year` | « Membre depuis avril 2026 » | |

### Voyage / étape

| Emplacement | Fonction(s) | Rendu | Exemple |
|---|---|---|---|
| `features/trips/presentation/pages/trip_detail_page.dart:473-508` | `toZoneTime`, `formatTime`, `formatDepartureRelative`, `tripDaySpan` (avec `endTimezone`), `formatZoneMention`, `dayBoxFor` (turquoise) | boîte du jour, « Départ 09:00 », pastille, ligne de plage, mention | « Départ 09:00 / ven. 16 → dim. 18 oct. » |
| `features/trips/presentation/pages/stage_detail_page.dart:345` (rail des étapes) | `formatDepartureDate(s.dateTime, s.timezone)` | sous-libellé de chaque étape | « mar. 12 août » |
| `stage_detail_page.dart:438-470` (bloc de départ de l'étape) | `formatTime`, `formatDepartureRelative` (masqué si le **voyage** est passé), **`formatDepartureDate` + allure en ligne de détail**, mention | « Départ 09:00 / sam. 12 avr. · 22 km/h » | |
| `features/trips/presentation/widgets/stage_card.dart:59-121` | `stage.startsAt` (`tryParseZoneTime`), `formatTime`, `formatDepartureDate`, `formatDeparture` (lecteur d'écran) | « **09:00** sam. 12 avr. » (heure en 700, date atténuée), jamais relatif ; mention | |
| `features/trips/presentation/widgets/trip_summary_card.dart:118-130` | `startsAt` / `endsAt` | durée « 3 jours » (jours civils de l'entité) | |
| `features/trips/providers/trip_detail_provider.dart:60,84,109` | `tryParseZoneTime` | getters `startsAt` / `endsAt` | — |

### Parcours

| Emplacement | Fonction(s) | Rendu | Exemple |
|---|---|---|---|
| `features/routes/presentation/widgets/route_usages_section.dart:70-130` | sortie : `formatDeparture` ; voyage : `tripDaySpan` ; mention | « sam. 12 avr. · 09:00 » ; « ven. 16 → dim. 18 oct. » | |
| `features/routes/presentation/pages/route_detail_page.dart:601,623` | `tryParseDisplayTime`, `formatLongDate` | création du parcours | « lundi 15 janvier 2026 » |

### Posts, annonces, commentaires, notifications, profil, calendrier

| Emplacement | Fonction(s) | Rendu | Exemple |
|---|---|---|---|
| `features/posts/presentation/pages/post_detail_page.dart:249-261` | `tryParseZoneTime`, `dates.at` + `formatFullDate` + `formatTime`, `ZoneMentionLine.maybe` | « samedi 11 octobre à 08:00 » (jamais d'année) + mention | |
| `features/ads/presentation/widgets/ad_card.dart:38,128` | `tryParseDisplayTime`, `formatLongDate` | « samedi 12 avril 2026 » | |
| `features/ads/presentation/pages/ad_detail_page.dart:124,199` | `formatFullDate` | « samedi 12 avril » (sans année) | |
| `features/comments/presentation/widgets/comment_thread.dart:272` | `formatRelative` | « il y a 2 heures » | |
| `features/notifications/presentation/widgets/notification_tile.dart:93` | `formatRelative(DateTime.parse(createdAt))` | « Équipe · il y a 5 minutes » | |
| `features/notifications/presentation/notification_display.dart:65-84` | `formatRendezvous(subjectDateTime, subjectTimezone)` | « Départ : Demain · 09:00 · heure de Tokyo (ven. 01:00 chez vous) » | |
| `features/profile/.../passkeys_section.dart:107-110`, `connected_services_section.dart:248-267`, `data_and_account_section.dart:78-104`, `paired_devices_section.dart:73-85` | `formatLongDate`, `formatRelative` | « Appairé le lundi 15 janvier 2026 · utilisé il y a 2 jours » | |
| `features/device/presentation/pages/device_verify_page.dart:559` | `formatRelative` | | |
| `features/calendar/presentation/widgets/agenda_card.dart:63-76,94,112,199` | `calendarDayLabel` (`formatFullDate`), `toZoneTime`, `formatTime`, mention | en-tête « Demain · dimanche 13 avril » ; carte « **09:00** » puis « Équipe · Lieu » | |
| `features/calendar/presentation/pages/calendar_page.dart:397,538,546` ; `calendar_toolbar.dart:77` | `formatMonthYear`, `dayAbbrev`, `formatFullDate` | « Avril 2026 », en-têtes « lun. », jour sélectionné « samedi 12 avril » | |

**`core/pdl`** ne formate aucune date : `PdlDepartureLine`, `PdlDepartureBlock` et `PdlDayBox` reçoivent des chaînes déjà formatées. La recherche de `DateFormat` et `AppFormatters.format*` ne donne rien dans `core/pdl`.

---

## 5. Écarts internes au mobile

### `DateFormat` ou interpolation hors de `AppFormatters`

| Emplacement | Ce qui est fait | Remarque |
|---|---|---|
| `features/teams/domain/publication_timing.dart:70-72` (`_shortDay`) | `'${dayAbbrev(w.weekday)} ${w.day}'` et `DateFormat.MMM()` | « ven. 16 » construit à la main. En `en` cela donne « Fri 16 → Sun, Oct 18 », alors que le web emploie `dateFormats.weekdayDay` = « EEE d » dans les deux langues : même résultat. La branche `withMonth: true` n'est jamais appelée (code mort) |
| `features/teams/presentation/pages/team_members_page.dart:364` | `monthCapitalized(m).toLowerCase() + ' ' + year` | réimplémente `monthLower` ; il n'existe pas d'helper « mois année » en minuscules |
| `core/utils/formatters.dart:592-611` | `formatDayMonth`, `formatFullDate`, `formatLongDate` assemblent `jour + mois` à la main | ordre français imposé quelle que soit la locale, et mois en minuscules même en anglais (« Monday 15 january »). Le reste du fichier passe par les motifs `intl` |
| `features/rides/domain/ride_form.dart:19-20,71` ; `ride_editor_page.dart:635` ; `ride_template_editor_page.dart:250` | `DateFormat("yyyy-MM-dd'T'HH:mm:ss")`, `padLeft` | sérialisation pour l'API, pas de l'affichage : acceptable |
| `features/rides/presentation/pages/ride_editor_page.dart:625-631` | parse `g.time` (« HH:mm ») avec `split(':')` | lecture du champ déprécié `time`, que l'éditeur renvoie ; pas d'affichage |

### `DateTime.now()` au lieu de `displayNow()`

`ride_form.dart:63,361`, `ride_editor_page.dart:449`, `publication_timing.dart:25`, `next_ride_provider.dart:46` et `formatters.dart:652` appellent `DateTime.now()`, mais toujours `.toUtc()` puis `toZoneTime`, ou pour une comparaison en UTC. Aucun ne viole la règle de `CLAUDE.md`. La recherche de `toLocal()` ne trouve rien hors de `formatters.dart`.

### Même information, formats différents

| Information | Rendus coexistants |
|---|---|
| **Date d'un post** | carte du fil : `formatLongDate` « samedi 11 octobre 2026 » (sans heure ni mention) · détail : « samedi 11 octobre à 08:00 » (sans année) + mention · tableau de bord : `formatDayMonth` « 11 octobre ». Trois formats, aucun n'est le « format unique » `formatDepartureDate` |
| **Départ d'une sortie** | fil, accueil et « mes prochaines » : « Départ 09:00 » + boîte du jour · « prochaines sorties » du tableau de bord, usages d'un parcours, todo : `formatDeparture` « sam. 12 avr. · 09:00 » sans boîte · calendrier et agenda de l'accueil : « 09:00 » nu |
| **Départ d'une étape** | carte d'étape : « 09:00 » + « sam. 12 avr. », jamais relatif · bloc de détail : « Départ 09:00 » + boîte + pastille + **ligne « sam. 12 avr. · 22 km/h »**, alors que le bloc de sortie retire la date parce que la boîte la porte (`ride_departure_block.dart:67-69`). La date est donc répétée sur le détail d'une étape |
| **Pastille relative d'une étape** | masquée quand le **voyage** est passé (`stage_detail_page.dart:447`), et non quand l'étape l'est |
| **Jour d'un groupe** | carte de groupe : `formatDepartureDate`, jamais « Demain » · le relatif est pourtant permis ailleurs pour un départ |
| **Date d'une annonce** | carte : `formatLongDate` (avec année) · détail : `formatFullDate` (sans année) |
| **« Prévision disponible à partir du »** | ligne de synthèse : `formatDayMonth` « 12 avril » · avis : `formatFullDate` « samedi 12 avril » |
| **Adhésion d'un membre** | liste des membres : « Membre depuis avril 2026 » · panneau d'administration : `formatRelative` « il y a 3 jours » |
| **Horodatage d'administration** | webhook : `formatDayMonth` « 15 janvier » · météo : `formatLongDateTime` « lundi 15 janvier 2026 à 08:30 » |
| **Année de la boîte du jour ou de la date** | `dayBoxFor` compare à `displayNow().year` (le lecteur) ; `formatDepartureDate` compare dans le fuseau de l'entité. Les deux ne divergent qu'autour du Nouvel An, pour un lecteur d'un autre fuseau |
| **Mention** | en seconde ligne (`ZoneMentionLine`) partout, sauf dans les notifications, où elle est en ligne après « · » (`formatRendezvous`) |
| **24 h / 12 h** | la doc dit « le téléphone, pas la langue », mais en `fr` le format 12 h est inopérant (`jm` = `HH:mm`) |

---

## 6. Écarts mobile ↔ web constatés

Côté web, j'ai lu `frontend/src/utils/dateFormat.ts`, `wallTime.ts`, `hooks/useRendezvousFormat.ts`, `utils/rendezvous.ts` et `publicationTiming.ts`, ainsi que les composants `DepartureLine`, `DepartureBlock`, `Rendezvous`, `RideGroupCard`, `RouteUsages`, `TodoBand`, `WeatherAttribution` et `NotificationItem`. Les clés de locale sont dans `frontend/src/locales/*/common.json` (`dateFormats.*`, `timezone.*`).

### Ce qui est aligné

- Le « format unique » du départ : `formatDeparture` et `formatDepartureDay` (« sam. 12 avr. · 09:00 », année hors de l'année en cours, « Aujourd'hui »/« Demain » jugés dans le fuseau de l'entité). Les motifs `EEE d MMM` et `EEE, MMM d` sont identiques à ceux de `intl`.
- La mention : « heure {ofCity} » et « {time} chez vous », comparaison par décalage, jour préfixé quand il diffère. La table des villes est commune (`zoneLabel.ts`, `zone_label.dart`).
- Le fuseau d'affichage : préférence utilisateur, sinon navigateur ou appareil.
- La plage d'un voyage dans `tripDaySpan`, comme `formatPublicationSpan`.
- La règle `someGroupLeavesAtOwnTime`.
- `myStartAt`, qui correspond au `spanStart` du web.
- Le bloc de départ d'une sortie : sans ligne de date, puisque la boîte du jour la porte.

### Différences

| Donnée | Web | Mobile |
|---|---|---|
| **12 h / 24 h** | suivant la **langue** (`p` de date-fns) : fr « 09:00 », en « 9:00 AM » | suivant le **téléphone**, mais fr reste toujours en 24 h ; en anglais avec un téléphone en 24 h → « 09:00 » |
| **Date « longue » d'un horodatage** (`formatDate`, `PPP`) | « 15 juin 2025 » (sans jour de semaine) / « June 15, 2025 » | `formatLongDate` « dimanche 15 juin 2025 » / « Sunday 15 june 2025 » |
| **Date et heure d'un horodatage** (`formatDateTime`) | = `formatDeparture` non relatif : « sam. 12 avr. · 09:00 » | `formatLongDateTime` « samedi 12 avril 2026 à 09:00 » |
| **Jour long d'un RDV** (`formatLongDay`) | « samedi 12 avril », **année hors de l'année en cours** | `formatFullDate` « samedi 12 avril », **jamais d'année** ; pas d'équivalent conditionnel |
| **Relatif d'un horodatage** (`formatRelative`) | `formatDistanceToNow` de date-fns : « il y a environ 2 heures », « il y a 3 mois », sans seuil (formulation date-fns : non vérifiée à l'exécution) | « il y a 2 heures », puis date longue au-delà de 7 jours |
| **Carte d'un post** | `<Rendezvous>` au format `dateTime` : « sam. 11 oct. · 08:00 » + icône de mention | « samedi 11 octobre 2026 », sans heure ni mention |
| **Détail d'un post** | `variant="detail"` : « sam. 11 oct. · 08:00 · heure de Tokyo (…) » en ligne | « samedi 11 octobre à 08:00 » + mention en seconde ligne |
| **Post dans le tableau de bord** (`ContentLists`) | `format="date"` → `PPP` « 11 octobre 2026 » + icône de mention | `formatDayMonth` « 11 octobre », sans mention |
| **Annonce** (carte et détail) | `FormattedDateTime` : « sam. 12 avr. · 09:00 » | carte « samedi 12 avril 2026 » ; détail « samedi 12 avril » |
| **Création d'un parcours** | `FormattedDate` : « 15 janvier 2026 » | « lundi 15 janvier 2026 » |
| **Membre depuis** (`TeamMemberList`) | `formatDate` : « 12 avril 2026 » | « avril 2026 » (mois et année) |
| **Adhésion dans le panneau d'administration** (`AdminPanel`) | `FormattedDate` : « 12 avril 2026 » | `formatRelative` : « il y a 3 jours » |
| **Webhook, dernier envoi** | `FormattedDate` (AdminPanel) | `formatDayMonth` « 15 janvier » |
| **Passkey, dernière utilisation** | `formatDate` « 12 avril 2026 » | `formatLongDate` « samedi 12 avril 2026 » |
| **Météo, « mise à jour »** | « Mise à jour à 08:30 » le jour même, sinon date + heure (`updatedOn`) | toujours « Prévision de lundi 15 janvier 2026 à 08:30 » (`formatLongDateTime`) |
| **Prévision disponible à partir du** | `formatDate` « 12 avril 2026 » | « 12 avril » (ligne) ou « samedi 12 avril » (avis) |
| **Carte de groupe, heure propre** | `DepartureLine` ; un autre jour : `withDay` → `formatDeparture` « Demain · 22:30 » ou « mer. 30 juil. · 22:30 » (sans « Départ », relatif permis) | « Départ 22:30 » + « mer. 30 juil. » (jamais relatif) |
| **Carte d'étape** (`TripStageCard`) | `DepartureLine withDay` : « sam. 12 avr. · 09:00 » / « Demain · 09:00 » | « 09:00 » + « sam. 12 avr. » atténué, jamais relatif |
| **Bloc de départ d'une étape** (`StageDetailPage`) | `DepartureBlock` sans `dayLine` : pas de ligne de date | ligne « sam. 12 avr. · 22 km/h » |
| **Voyage dans les usages d'un parcours** (`RouteUsages`) | « sam. 16 oct. → dim. 18 oct. » (`formatDepartureDay` des deux côtés, sans regroupement du mois) | `tripDaySpan` : « sam. 16 → dim. 18 oct. » |
| **Todo du tableau de bord** (`TodoBand`) | « Sortie, sam. 12 avr. » (jour seul) | « Sortie, sam. 12 avr. · 09:00 » (jour + heure) |
| **« Votre groupe »** dans le bloc de départ | colonne à droite : « Votre groupe » / « Groupe B · 09:30 » (`departure.block.group`) | ligne sous le bloc : « Votre groupe : B · 09:30 » |
| **Mention sur une carte** | icône avec info-bulle (`ZoneMentionIcon`) | texte en seconde ligne (`ZoneMentionLine`) : inévitable sans survol, mais à noter |
| **Fuseau inconnu** | `supportedZone` → retombe sur le lecteur, sans mention | `toZoneTime` → retombe sur le fuseau d'affichage, sans mention : **aligné** |
| **SSR / hydratation** | pas de mention tant que le fuseau du lecteur est le placeholder `UTC` | sans objet |

### Points que je n'ai pas vérifiés côté web

Le calendrier et l'agenda web (`CalendarPage` et suivants), le format de la notification complète (assemblage des clauses et de la mention), et `DayBox.tsx` (règle de l'année : lecteur ou entité ?). Les autres agents qui inventorient écran par écran devraient les confronter aux lignes correspondantes du §4.
