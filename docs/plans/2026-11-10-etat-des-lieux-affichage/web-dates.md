# Dates et heures du frontend web : vue transversale

Lecture seule de `frontend/src` (worktree `feat/mobile-review`, API `pedalons.api.version=13.3.0`).
Chemins relatifs à `frontend/src/` sauf mention. Les sorties de date-fns ont été vérifiées sur les
tables de locale de date-fns 4.4.0, lues dans le `node_modules` du checkout principal
(`/Volumes/Data/code/perso/tribly/frontend`), parce que le worktree n'a pas de `node_modules`. Les
exemples en anglais viennent des patterns ou des tests (`utils/dateFormat.test.ts:128-130`).

Règle cadre, écrite dans `frontend/CLAUDE.md:202-203` :
- aucun `toLocale*String` ni `Intl.DateTimeFormat` brut : tout passe par `useFormattedDate()` ou `<FormattedDate*>` ;
- **un rendez-vous se lit dans le fuseau de son entité, un horodatage dans celui du lecteur** ;
- on n'affiche jamais le `time` brut d'un groupe (« 08:30:00 ») : on formate son `startAt`.

---

## 1. Modèle de données

### Trois types de chaîne (contrat `contracts/openapi.yaml`)

| Type TS | Schéma OpenAPI | Forme | Sens |
|---|---|---|---|
| `Instant` (`api/dto/instant.ts`) | `Instant`, `format: date-time` (l. 2970) | `2022-03-10T16:15:50Z` | Instant absolu, toujours en sortie (DTO) |
| `EventDateTime` (`api/dto/eventDateTime.ts`) | `EventDateTime` (l. 2328) | `2026-10-11T08:00:00`, **sans décalage** | Heure murale, en **entrée** seulement (requêtes). Un `Z` ou un décalage est refusé (400). Le backend la lit dans le fuseau qu'il résout pour l'entité. |
| `LocalTime` (`api/dto/localTime.ts`) | `LocalTime`, `format: local-time` (l. 3060) | `13:45:30.123456789` | Heure seule : `time` d'un groupe ou d'un groupe de modèle |

Asymétrie à retenir : **on envoie une heure murale, on reçoit un instant UTC accompagné du fuseau
IANA de l'entité** (champ `timezone`). Le client affiche cet instant dans ce fuseau.

### Champs par entité (DTO de sortie)

| DTO | Champ | Type | Sens (d'après la JSDoc du DTO) |
|---|---|---|---|
| `RideDto` | `dateTime` | Instant | Départ de la sortie. C'est aussi celui d'un groupe sans heure propre. Ce n'est pas la date de publication. |
| | `timezone` | string IANA | Fuseau de saisie et de lecture : celui du lieu de départ, sinon du parcours, sinon de l'équipe. `dateTime`, `publishAt`, `endDateTime` et les `startAt` des groupes sont des rendez-vous dans ce fuseau. |
| | `endDateTime` | Instant | Fin calculée par le serveur : groupe le plus tardif, départ + longueur ÷ vitesse, ou + 3 h. Lue par les listes UPCOMING/PAST et le calendrier. |
| | `publishAt`, `createdAt` | Instant | Publication programmée ; création |
| `RideGroupDto` | `startAt` | Instant, **toujours renseigné** | Départ du groupe. Vaut `ride.dateTime` quand le groupe part avec la sortie. |
| | `time` | LocalTime, **déprécié** | Heure murale propre au groupe, null s'il part avec la sortie. Seuls les éditeurs l'utilisent. |
| `RideGroupSummaryDto` (cartes) | `startAt`, `time` | idem | idem |
| `TripDto` | `dateTime` | Instant | Début du voyage |
| | `timezone` | IANA | Celui de la 1re étape, sinon du parcours, sinon de l'équipe |
| | `endDate` | Instant? | Date de la dernière étape, null sans étape |
| | `endDateTime` | Instant | Fin calculée : fin de la dernière étape, ou `dateTime` + 3 h |
| `TripStageDto` | `dateTime`, `timezone` | Instant, IANA | Départ de l'étape. Chaîne de fuseau : lieu, parcours, étape précédente, parcours du voyage, équipe. **Une étape peut avoir un autre fuseau que son voyage.** |
| `PostDto` | `dateTime`, `timezone`, `publishAt` | | Fuseau = celui de l'équipe au dernier enregistrement |
| `RouteDto` / `RouteDetailDto` | `createdAt`, `updatedAt` | Instant | **Un parcours ne porte aucun rendez-vous** : seulement des horodatages |
| `RouteUsageDto` | `dateTime`, `endDate`, `timezone` | | Sortie ou voyage qui utilise le parcours |
| `CalendarEventDto` | `start`, `end`, `timezone`, `allDay` | | `start` = départ **du groupe de l'appelant** s'il est inscrit, sinon celui de la sortie |
| `TeamDetailDto` | `timezone` | IANA | Fuseau de repli de l'équipe, modifiable par un administrateur (`TeamRequest.timezone`) |
| `UserDto` | `timezone?` | IANA | Préférence du lecteur. Null = jamais choisie : le client suit le navigateur. |
| Météo | `WeatherCheckpointDto.time`, `WeatherLegDto.startTime/arrivalTime`, `DepartureWeatherDto.sunrise/sunset/fetchedAt`, `WeatherRainAlertDto.time`, `availableFrom` | Instant | Passages estimés, horodatages des prévisions. `RideWeatherSummaryDto.timezone?` : sur une carte de voyage, le fuseau de la prochaine étape. |
| Notification | `subjectDateTime`, `subjectTimezone` | | Pas de `subjectTimezone` avant la 10.20.0 |

Côté requêtes (`RideRequest`, `TripRequest`, `StageRequest`, `PostRequest`), `dateTime` et
`publishAt` sont des `EventDateTime`, et `GroupRequest.time` est un `LocalTime`.

**Il n'y a pas d'« heure de RDV » distincte de l'« heure de départ ».** Aucun DTO ne porte un champ
de rendez-vous à part (grep `meeting|rdv|rendezvous` sur `api/dto` : seulement des commentaires du
type « meeting point »). Le `dateTime` de la sortie est à la fois l'heure où l'on se retrouve et
l'heure de départ, au lieu `startPlace`. Le seul second horaire est le `startAt` d'un groupe qui
part à une autre heure. Dans le code, « rendezvous » désigne la *catégorie* d'instant lue dans le
fuseau de l'entité, pas un champ.

### Fuseau du lecteur : `useEffectiveTimezone()` (`utils/dateFormat.ts:39-59`)

- Si `user.timezone` existe : on l'utilise, `isGuessed=false`.
- Sinon : le fuseau du navigateur, lu via `useSyncExternalStore`. Au rendu SSR et au rendu
  d'hydratation, c'est le substitut `'UTC'`, avec `isPlaceholder=true` et `isGuessed=true`.
- La préférence se règle dans `components/profile/TimezonePreference.tsx`, qui envoie un PATCH
  partiel `{ timezone }` puis invalide `getMe`. Si l'utilisateur n'a rien choisi, le champ est
  prérempli avec le fuseau du navigateur (`useBrowserTimezone`, null côté serveur).
- La liste des fuseaux proposés est `TIMEZONE_OPTIONS = Intl.supportedValuesOf('timeZone')`
  (`utils/timezones.ts`).
- Le fuseau d'équipe n'intervient jamais directement à l'affichage. Le backend s'en sert comme
  repli quand il résout `entity.timezone`. Il sert aussi aux formulaires (dates par défaut, mention)
  et à l'aperçu de changement de fuseau (`components/team/TimezoneChangePreview.tsx`).

---

## 2. Utilitaires

Abréviations utilisées dans la colonne « Fuseau » :
- **Fuseau de l'entité** : l'argument `timeZone` reçu, en pratique `entity.timezone`.
- **Fuseau du lecteur** : celui de `useEffectiveTimezone()`.
- **Repli `'UTC'`** : valeur par défaut des fonctions pures quand on ne leur passe pas de fuseau.

### `utils/dateFormat.ts` (date-fns 4 + `formatInTimeZone` de date-fns-tz)

Les locales sont `fr` et `enUS`. Toute langue autre que `fr` ou `en` tombe sur `enUS` (l. 70-72).

| Fonction | Signature | Pattern / sortie | Exemple FR | Exemple EN | Fuseau |
|---|---|---|---|---|---|
| `formatDate` | `(date, language='fr', tz='UTC')` | `PPP` | « 15 juin 2025 » (fr `long` = `d MMMM y`) | « June 15th, 2025 » (enUS `long` = `MMMM do, y`, avec ordinal ; **la JSDoc annonce « June 15, 2025 », à tort**) | argument |
| `formatTime` | `(date, language, tz)` | `p` | « 09:00 » (fr `short` = `HH:mm`, 24 h) | « 9:00 AM » (`h:mm a`, 12 h) | argument |
| `formatPattern` | `(date, pattern, language, tz)` | pattern date-fns libre | `EEE` → « sam. », `MMM` → « avr. » | « Sat », « Apr » | argument |
| `formatDepartureDay` | `(date, language, tz, t, now)` | `dateFormats.departureDay` = `EEE d MMM` (fr) / `EEE, MMM d` (en). Variante `…WithYear` hors de l'année en cours. | « sam. 12 avr. », « sam. 10 avr. 2027 » | « Sat, Apr 12 », « Sat, Apr 10, 2027 » | argument. L'année en cours est jugée dans ce fuseau. |
| `formatLongDay` | idem | `EEEE d MMMM` / `EEEE, MMMM d` (+ `yyyy`) | « samedi 12 avril » | « Saturday, April 12 » | argument |
| `formatDeparture` | `(date, language, tz, t, {now, relative=true})` | `dateFormats.dayAndTime` = `{{day}} · {{time}}`. Le jour vient de `formatRelativeDay`, sinon de `formatDepartureDay`. L'heure suit `p`. | « sam. 12 avr. · 09:00 », « Demain · 09:00 », « Aujourd'hui · 09:00 » | « Sat, Apr 12 · 9:00 AM », « Tomorrow · 9:00 AM » | argument. « Demain » est jugé dans le fuseau de l'entité. |
| `formatDateTime` | `(date, language, tz)` | `formatDeparture(…, {relative:false})` | « sam. 11 avr. · 09:00 » (test l. 128) | « Sat, Apr 11 · 9:00 AM » (test l. 130) | argument. **Format date + heure unique du site, horodatages compris** (JSDoc l. 103-107). |
| `relativeDay` | `(date, tz, now)` → `'today'`, `'tomorrow'` ou `null` | Compare des `yyyy-MM-dd`. Le passé ne devient jamais relatif. | | | argument |
| `formatRelativeDay` | `(date, tz, t, now)` | `dateFormats.today` / `tomorrow` | « Aujourd'hui », « Demain » | « Today », « Tomorrow » | argument |
| `isSameDay` | `(date, tz, now)` | booléen | | | argument |
| `formatRelative` | `(date, language)` | `formatDistanceToNow(addSuffix)` | « il y a environ 2 heures » (fr `aboutXHours` = « environ {{count}} heures ». **La JSDoc dit « il y a 2 heures »**) | « about 2 hours ago » | aucun (durée seulement) |
| `useEffectiveTimezone` | `() → {timezone, isGuessed, isPlaceholder}` | | | | lecteur (cf. §1) |
| `useFormattedDate` | hook | `formatDeparture`, `formatDepartureDay`, `formatRelativeDay`, `formatDate`, `formatDateTime`, `formatTime`, `formatRelative`, `formatPattern`, `isToday`, `isGuessedTimezone` | | | **lecteur** |

### Rendez-vous : `hooks/useRendezvousFormat.ts`, `components/common/Rendezvous.tsx`, `utils/rendezvous.ts`, `utils/zoneLabel.ts`

| Élément | Signature | Sortie | Fuseau |
|---|---|---|---|
| `useRendezvousFormat(zone)` | hook | `zone`, `formatDate`, `formatDateTime`, `formatTime`, `formatPattern`, `formatDeparture(d,{relative})`, `formatDepartureDay`, `formatLongDay`, `formatRelativeDay`, `relativeDay`, `samePeriod(a,b,pattern='yyyy-MM-dd')`, `mention(instant)`, `isGuessedText`, `isGuessedTimezone` | `supportedZone(zone)` (fuseau de l'entité), sinon **le lecteur, sans mention**. C'est aussi le cas d'une zone inconnue d'`Intl`. |
| `rendezvousMention(instant, zone, readerZone, language, t)` | → `{label, readerEquivalent, full}` ou `null` | « heure de Tokyo (ven. 01:00 chez vous) ». EN : « Tokyo time (Fri 1:00 AM your time) ». L'heure suit `p`, précédée de `EEE` quand le jour civil du lecteur diffère. | `null` si les **décalages** sont égaux à cet instant (Paris lu de Bruxelles : rien), si `readerZone` est null (substitut SSR) ou si la zone n'est pas prise en charge |
| `zoneCityName(tz, lang)` / `zoneCityOf(tz, lang)` | | Dernier segment IANA, `_` remplacé par une espace, plus une table FR (Londres, Bruxelles, Le Caire…). Élision : « de Tokyo », « d'Athènes », « du Caire », « des Açores ». `Etc/GMT-9` → « UTC+9 ». | La JSDoc demande que le mobile garde la même table |
| `sameOffsetAt(instant, a, b)` | booléen | | Compare les décalages, pas les identifiants |
| `isSupportedZone` / `supportedZone` | | Teste `new Intl.DateTimeFormat('en',{timeZone})`, résultat mis en cache | |
| `tripEndZone(trip)` | → zone | Fuseau de la dernière étape (`stages` triées par `dateTime`), sinon `trip.timezone` | |
| `<Rendezvous date zone format variant template>` | composant | `format` : `dateTime` (défaut, absolu), `departure` (relatif), `day`, `date` (`PPP`), `time`. `variant="detail"` : mention en ligne « … · heure de Tokyo (…) ». `variant="card"` (défaut) : icône globe (`IconWorld` 14 px) avec la mention en infobulle. | entité |
| `ZoneMentionText` / `ZoneMentionIcon` | composants | Rendu de la mention seule | |
| `hooks/useZoneMention(zone, wall?)` | formulaires | « heure de Tokyo », **sans l'équivalent lecteur** | |

### `utils/publicationTiming.ts`

| Fonction | Sortie |
|---|---|
| `spanStart(pub)` | Sortie : `startFor(ride)`, c'est-à-dire le `startAt` du groupe de l'inscrit, sinon `dateTime`. Voyage : `dateTime`. |
| `formatPublicationSpan(pub, mode, language, t, fallbackZone, now)` | **Sortie** : `mode='full'` → `formatDeparture(start, relative:false)`, soit « sam. 11 oct. · 08:30 » ; `mode='time'` → « 08:30 ». **Voyage** : un seul jour → « sam. 11 oct. » ; même mois → « ven. 16 → dim. 18 oct. » (`dateFormats.weekdayDay` = `EEE d`, puis `formatDepartureDay`) ; mois différents → « jeu. 30 avr. → dim. 3 mai ». L'année n'apparaît que hors de l'année en cours. Le premier jour est lu dans `trip.timezone`, le dernier dans `tripEndZone`, et la fin vient de **`endDateTime`** (pas d'`endDate`). |
| `isUnderWay(pub, now)` | `dateTime <= now < endDateTime`, et le statut n'est pas `CANCELLED` |

### `utils/groupStart.ts`

| Fonction | Règle |
|---|---|
| `groupLeavesAtOwnTime(startAt, rideDateTime)` | Compare les **instants** parsés (ni les chaînes ni `time`). Le mobile a l'équivalent `groupLeavesAtOwnTime`. |
| `someGroupLeavesAtOwnTime(groups, reference)` | Si un seul groupe part à une autre heure que la référence, **tous les groupes affichent leur heure** |
| `registeredGroupOf(ride)` / `startFor(ride, group?)` | Départ qui concerne le lecteur : celui de son groupe, sinon celui de la sortie. Le mobile a `myStartAt`. |

### Saisie : `utils/wallTime.ts`, `components/common/WallDateTimePicker.tsx`, `hooks/useEventTimezone.ts`

- `normalizeWallTime(v)` : `"YYYY-MM-DD HH:mm[:ss]"` → `"YYYY-MM-DDTHH:mm:ss"`. Mantine renvoie une
  espace, l'API exige le `T`.
- `instantToWallTime(instant, tz)`, `wallTimeToInstant(wall, tz)`, `optionalWallTime`.
- `addDaysToWallTime(wall, n)` : J+n à la même heure murale. Le calcul porte sur la chaîne, donc
  le changement d'heure n'a aucun effet.
- `nextWeekdayWallTime(isoWeekday, hour, tz, now)` : date par défaut d'un formulaire. Par exemple
  `CreateRidePage.tsx:85` donne « dimanche prochain 08:00 » dans le fuseau de l'équipe.
- `WallDateTimePicker` : un `DateTimePicker` Mantine sans aucune conversion. Il ajoute
  « · heure de Tokyo » à la description quand la zone diffère. Les formats affichés par le picker
  sont ceux de Mantine par défaut, avec la locale de `DatesProvider` (`AppProviders.tsx:20`) :
  **non vérifiés**.
- `hooks/useEventTimezone.ts` : `useZoneResolver` reproduit côté formulaire la chaîne
  `EventTimezoneResolver` du backend (lieu, parcours…), avec un appel
  `GET /api/teams/{slug}/timezone?lat&lon` après 400 ms d'inactivité. Il ne sert qu'à la mention et
  ne décale jamais une heure.
- L'heure d'un groupe se saisit avec un `TimeInput` brut (`RideEditor.tsx:462`, `RideTemplateEditor.tsx:187`).

### Autres

- `hooks/useCalendarDateRange.ts` : fenêtre de requête du calendrier. Elle va du 1er du mois UTC
  précédent moins 7 jours jusqu'au 1er du mois UTC + 7, à partir de `hourAlignedNow()`
  (`utils/nowIso.ts`, arrondi à l'heure UTC). Aucun affichage.
- `components/common/FormattedDate.tsx` : `<FormattedDate>` (`PPP`), `<FormattedDateTime>` et
  `<FormattedTime>`, dans le fuseau du **lecteur**, avec `suppressHydrationWarning` quand ce fuseau
  est deviné.
- `components/common/DayBox.tsx` : boîte du jour sur 3 lignes, `EEE` / `d` / `MMM`, plus une 4e
  ligne `yyyy` hors de l'année en cours. Exemple : « sam. / 10 / oct. ». Fuseau de l'entité
  (`zone`), sinon celui du lecteur. Variantes `flat` et `posed`, taille `lg` pour les pages détail.
- `components/common/DepartureLine.tsx` : icône horloge et texte en 700 :
  - par défaut : « Départ 09:00 » (`departure.block.time`) ;
  - `withDay` : `formatDeparture`, donc « sam. 12 avr. · 09:00 » ou « Demain · 09:00 » ;
  - `label` : texte libre (étendue d'un voyage) ;
  - suivi de `ZoneMentionIcon`, puis éventuellement de « · détail » ;
  - `announceDay` : `formatLongDay` en `VisuallyHidden`, pour les lecteurs d'écran.
- `PublicationDepartureLine` : un voyage affiche `formatPublicationSpan(…,'full')` avec la tonalité
  teal ; une sortie affiche `DepartureLine(spanStart)`.
- `components/common/DepartureBlock.tsx` (pages détail), en trois zones :
  - à gauche : `DayBox lg` ;
  - au centre : « Départ 09:00 » (24 px, 700), une pastille « Aujourd'hui » / « Demain » (Badge),
    puis une ligne grise avec `dayLine` (l'étendue d'un voyage) et la mention, ou la mention seule ;
    enfin le lieu ;
  - à droite, si le prop `group` est fourni : « Votre groupe » puis « Groupe B · 09:30 »
    (`departure.block.group`).
- `components/card/common/CardDayOverlay.tsx` : `DayBox` posée en haut à gauche de l'image, et une
  pastille blanche « Aujourd'hui » / « Demain » en haut à droite, seulement pour ces deux jours.

---

## 3. Règles d'affichage (telles qu'appliquées)

1. **Rendez-vous ou horodatage.** Se lisent dans le **fuseau de l'entité** :
   - le départ d'une sortie, d'un groupe (`startAt`) ou d'une étape ;
   - l'arrivée estimée et tous les passages météo ;
   - les dates d'un voyage ;
   - la publication programmée ;
   - la date d'un post ;
   - le jour de la `DayBox` ;
   - « Aujourd'hui » / « Demain ».

   Se lisent dans le **fuseau du lecteur** : création, commentaires, « il y a… », `fetchedAt`,
   `availableFrom`, membres, invitations, appareils, la grille du calendrier, le bandeau des 7 jours
   de `WeekAgenda` et le regroupement par jour.
2. **Mention de fuseau** : « heure de Tokyo (ven. 01:00 chez vous) ». Elle n'apparaît que si le
   décalage du fuseau de l'entité diffère de celui du lecteur *à cet instant*, que le fuseau du
   lecteur est connu (pas le substitut SSR) et qu'`Intl` connaît la zone. Le jour du lecteur n'est
   ajouté que s'il change.
   - Pages détail (`DepartureBlock`, post, publication programmée) : texte en ligne.
   - Cartes, lignes, calendrier, agenda : icône globe avec infobulle.
   - Mention absente : passages météo (`useRendezvousFormat` sans appel à `mention`), lignes de
     groupe, `StatsCard`. Le docstring de `RideWeatherSummaryDto.timezone` dit d'ailleurs « as
     rendezvous with no zone mention ».
3. **12 h / 24 h** : le web suit la langue, via le pattern `p` de date-fns : FR « 09:00 » en 24 h,
   EN « 9:00 AM » en 12 h. Aucune préférence utilisateur. BRANDING §8.3 : « 09:00 », jamais
   « 09h00 » ; le mobile suit le réglage du téléphone. **Exception** : `config/routeMeta.ts`
   (titres et aperçus SEO) utilise `Intl` `en-GB`, donc du 24 h en anglais (§5).
4. **Format unique du départ** (BRANDING §8.3, ledger `BRAND-8`) : « sam. 12 avr. · 09:00 ».
   - Jour de semaine et mois abrégés, séparés de l'heure par « · ».
   - L'année seulement hors de l'année en cours, jugée dans le fuseau de l'entité.
   - `formatDateTime` (horodatages) reprend exactement ce format, sans relatif.
5. **Relatif** :
   - Pour un rendez-vous : seulement « Aujourd'hui » et « Demain », jugés dans le fuseau de
     l'entité. Jamais « hier », jamais « dans 2 h » : aucun appel de `formatRelative` sur un départ.
   - Pour un horodatage : `formatRelative` (« il y a environ 2 heures »), utilisé uniquement pour les
     commentaires, notifications, appareils appairés, la vérification d'appareil et les aperçus GPX.
6. **Plages** : seul le voyage en a une, via `formatPublicationSpan`.
   - même jour : « sam. 11 oct. » ;
   - même mois : « ven. 16 → dim. 18 oct. » ;
   - sinon : « jeu. 30 avr. → dim. 3 mai ».

   Une sortie n'affiche **pas d'heure de retour** (BRANDING : « pas d'heure de retour »). Seule
   l'arrivée estimée d'un groupe apparaît : « Arrivée estimée 12:30 » dans `StatsCard`, et
   « Départ 09:00 → arrivée vers 12:30 · 42 km » dans `LegWeather`.
7. **RDV et départ** : c'est le même champ (§1). Le lieu (`startPlace`) est affiché à côté.
8. **Groupes à heures différentes** (`utils/groupStart.ts`) :
   - L'en-tête d'une page de sortie montre **le départ de la sortie** (`ride.dateTime`). Le bloc
     ajoute à droite « Votre groupe · Groupe B · 09:30 » si le groupe du lecteur part à une autre
     heure.
   - Sur une carte, une ligne ou l'agenda, le départ affiché est **celui du groupe du lecteur**
     (`startFor`), DayBox et « Demain » compris.
   - Dans la liste des groupes, dès qu'**un** groupe part à une autre heure que la sortie, **tous**
     affichent leur heure (`someGroupLeavesAtOwnTime`) : « Départ 09:30 » dans un encadré, avec le
     jour si ce n'est pas celui de la sortie (`samePeriod`).
   - Sur la carte du tableau de bord, les groupes affichent « · départ 09:30 » (en minuscules) dans
     les mêmes conditions, mais par rapport au départ affiché dans l'en-tête (`start`).
9. **Hydratation SSR** : le texte dans le fuseau de l'entité est identique côté serveur et client.
   Seules la mention et les formats dans le fuseau du lecteur portent `suppressHydrationWarning`.

---

## 4. Usages par entité

Les fonctions sans préfixe sont celles de `useRendezvousFormat` (fuseau de l'entité). « Lecteur » =
`useFormattedDate` ou `<Formatted*>`.

### Sortie (ride)

| Emplacement | Fonction | Format | Exemple |
|---|---|---|---|
| `pages/ride/RideDetailPage.tsx:192` | `DepartureBlock(ride.dateTime, ride.timezone, group=ownTimeGroup)` | DayBox lg + « Départ {p} » + pastille relative + mention + « Votre groupe · {nom} · {p} » | « Départ 09:00 » [Demain] / « heure de Tokyo (ven. 01:00 chez vous) » / « Votre groupe · Groupe B · 09:30 » |
| `pages/ride/RideDetailPage.tsx:229` (sortie solo) | `GroupStats` → `StatsCard` | Tuile « Départ » = `<Rendezvous format="time">` (+ icône), et « Arrivée estimée {p} » | « 09:00 », « Arrivée estimée 12:30 » |
| `components/ride/RideGroupCard.tsx:210` | `DepartureLine(group.startAt, withDay = !samePeriod)` si `showStartTime` | « Départ {p} », ou `formatDeparture` | « Départ 09:30 », « dim. 13 avr. · 07:00 » |
| `components/publication/PublicationHeader.tsx:169` | `<Rendezvous publishAt variant=detail template>` | `formatDateTime` + mention en ligne | « Publication programmée pour le sam. 12 avr. · 09:00 » |
| `components/card/PublicationCard.tsx:197` | `CardDayOverlay(spanStart)` | DayBox posée + pastille | « sam./12/avr. », « Demain » |
| `components/card/PublicationCard.tsx:219` | `PublicationDepartureLine` | « Départ {p} » + icône | « Départ 09:00 » |
| `components/home/NextRideCard.tsx:126,154` | `CardDayOverlay` + `DepartureLine(start, announceDay)` | « Départ {p} », jour long masqué | « Départ 09:30 » (lu « samedi 12 avril, Départ 09:30 ») |
| `components/team/dashboard/UpcomingRideCard.tsx:63` | `DepartureLine(start, withDay)` | `formatDeparture` | « sam. 12 avr. · 09:00 », « Demain · 09:00 » |
| `components/team/dashboard/UpcomingRideCard.tsx:178` | `formatTime(group.startAt)` | « départ {p} » | « Groupe B 25 km/h · départ 09:30 » |
| `components/team/dashboard/MyUpcomingList.tsx:54,62` | `DayBox` + `DepartureLine(startAt)` | « Départ {p} » | idem |
| `components/agenda/AgendaRow.tsx:34,65` | `DayBox(spanStart)` + `PublicationDepartureLine` | « Départ {p} » | idem |
| `components/team/dashboard/TodoBand.tsx:57` | `formatDepartureDay(ride.dateTime, ride.timezone)` pur, sinon lecteur | `EEE d MMM` | « Boucle de la vallée, sam. 12 avr. » |
| `components/home/WeekAgenda.tsx:161,181` | `DayBox(event.start, zone)` + `formatTime` pur + `rendezvousMention` | `p` + icône | « 09:00 · Équipe · Groupe A » |
| `components/calendar/CalendarView.tsx:171,184` | `formatTime` pur (fuseau de l'entité), grille dans `tz` du lecteur | « équipe · {p} · lieu », ou « Toute la journée » | « Pédalons · 09:00 · Place du marché » |
| `components/notification/NotificationItem.tsx:54,68` | `formatDeparture(subjectDateTime)` + `mention.full` ; `formatRelative(createdAt)` (lecteur) | « Départ : Demain · 09:00 · heure de Tokyo (…) », « Équipe · il y a environ 2 heures » | |
| `config/routeMeta.ts:301,335,356` (SEO) | `Intl.DateTimeFormat` fr-FR / en-GB | `day numeric, month long, year numeric` ; `HH:mm` | « 12 avril 2026 », « Départ 08:30 » ; EN « 12 April 2026 », « 08:30 » |

### Groupe (page commune groupe / étape)

| Emplacement | Fonction | Format | Exemple |
|---|---|---|---|
| `pages/ride/RideGroupPage.tsx:205` | `DepartureBlock(startFor(ride, group), ride.timezone)`, sans prop `group` | Bloc détail sur le départ **du groupe** | « Départ 09:30 » [Demain] |
| `pages/ride/RideGroupPage.tsx:258` | `GroupStats(showDeparture=false)` | Seulement « Arrivée estimée {p} » | « Arrivée estimée 12:30 » |

### Voyage (trip)

| Emplacement | Fonction | Format | Exemple |
|---|---|---|---|
| `pages/trip/TripDetailPage.tsx:164` | `DepartureBlock(trip.dateTime, trip.timezone, tone=teal, dayLine=formatPublicationSpan('full'))` | « Départ {p} » + étendue + mention | « Départ 08:00 » / « ven. 16 → dim. 18 oct. · heure de… » |
| `components/card/PublicationCard.tsx:219`, `MyUpcomingList.tsx:105`, `AgendaRow.tsx:65` | `PublicationDepartureLine` (TRIP) | étendue | « ven. 16 → dim. 18 oct. » |
| `components/route/RouteUsages.tsx:118` | `formatDepartureDay(dateTime) → formatDepartureDay(endDate)` | **les deux jours en entier** | « ven. 16 oct. → dim. 18 oct. » (cf. §5) |
| `config/routeMeta.ts:392` | Intl | « départ 16 octobre 2026 » | |

### Étape (stage)

| Emplacement | Fonction | Format | Exemple |
|---|---|---|---|
| `pages/trip/StageDetailPage.tsx:175` | `DepartureBlock(stage.dateTime, stage.timezone)` | Bloc détail | « Départ 08:00 » |
| `pages/trip/StageDetailPage.tsx:189` | `StatsCard` **sans `departure`** | « Arrivée estimée {p} » | |
| `components/trip/TripStageCard.tsx:52` | `DepartureLine(withDay)` | `formatDeparture` | « sam. 17 oct. · 08:00 », « Demain · 08:00 » |
| `components/team/TimezoneChangePreview.tsx:41-42` | `formatDepartureDay` + `formatTime` purs, dans `preview.from` | phrase | « l'étape « X » du voyage « Y », le sam. 17 oct., restera à 08:00, désormais heure de Tokyo. » |

### Parcours (route)

| Emplacement | Fonction | Format | Exemple |
|---|---|---|---|
| `components/route/RouteDetailView.tsx:229` | `<FormattedDate createdAt>` (lecteur) | `PPP` | « Créé le : 3 mars 2026 » |
| `components/route/RouteUsages.tsx:83` | `DepartureLine(usage.dateTime, withDay)` | `formatDeparture` | « sam. 12 avr. · 09:00 » |
| `components/route/RouteFullscreenView.tsx:180` | `DepartureLine(withDay, truncate)` | idem | |
| `components/gpxtool/GpxPreviewView.tsx:195`, `pages/gpxtool/MyGpxPreviewsPage.tsx:106,126` | `DepartureLine(departureTime, departureTimezone, withDay)` ; `formatRelative(createdAt)` | | |

### Météo (toujours dans le fuseau de l'entité, sauf indication)

| Emplacement | Fonction | Exemple |
|---|---|---|
| `components/weather/DepartureWeather.tsx:54` | `formatTime(time)` | « 09:00 · 12 °C » |
| `components/weather/DepartureWeather.tsx:89,94` | **`<FormattedTime>` (lecteur)** pour lever / coucher du soleil | « 07:42 » (cf. §5) |
| `components/weather/RouteVerdicts.tsx:225-229` | `formatTime` (entité) pour lever / coucher et arrivée | « Arrivée estimée 12:30. » |
| `components/weather/LegWeather.tsx:51-52` | `formatTime` | « Départ 09:00 → arrivée vers 12:30 · 42 km » |
| `components/weather/RouteWeather.tsx:94-98,475,609,674,682,891` | `formatTime` (l. 475 : les espaces sont remplacées par `\n` pour « 9:00↵AM ») | « Vent de face de 09:40 à 10:15 » |
| `components/weather/WeatherCheckpointStrip.tsx:90`, `WeatherCheckpointMarkers.tsx:234,444,483` | `formatTime`, `formatDepartureDay` | « Col de X · 10:15 », « Étape 3, sam. 3 mai — … » |
| `components/weather/GroupWeatherLine.tsx:71`, `RideWeatherSummaryLine.tsx:111`, `WeatherRainBanner.tsx:36` | `formatTime(rainAlert.time)` | « Pluie probable (60 %) vers 11:00 » |
| `components/weather/RideWeatherSummaryLine.tsx:50`, `WeatherStatusNotice.tsx:52` | lecteur `formatDate(availableFrom)` | « Météo disponible à partir du 5 avril 2026 » |
| `components/weather/WeatherAttribution.tsx:26-30` | lecteur `isToday` → `formatTime`, sinon `formatDate` + `formatTime` | « Mise à jour à 14:05 », « Mise à jour le 9 novembre 2026 à 14:05 » |
| `components/weather/useRouteLabels.ts:66-75` | durée faite à la main | « 29 min », « 1 h 05 » |

### Posts (pour comparaison)

| Emplacement | Format | Exemple |
|---|---|---|
| `pages/post/PostDetailPage.tsx:101` | `<Rendezvous variant=detail>` → `formatDateTime` + mention | « sam. 12 avr. · 09:00 · heure de… » |
| `components/card/PublicationCard.tsx:89,140` | `<Rendezvous>` → `formatDateTime` + icône | « sam. 12 avr. · 09:00 » |
| `components/team/dashboard/ContentLists.tsx:58` | `<Rendezvous format="date">` → `PPP` | « 12 avril 2026 » |

### Horodatages (lecteur)

`FormattedDate` (`PPP`) :
- `AdminPanel.tsx:160,232`, `TeamInvitationList.tsx:113`, `TeamAboutPage.tsx:127`, `AdminUsersPage.tsx:164` ;
- `formatDate` : `PasskeyManager`, `GpsConnectionsManager:137`, `PairedDevicesManager:103`, `TeamMemberList`.

`FormattedDateTime` (format départ, absolu) :
- `AdCard.tsx:78`, `AdDetailPage.tsx:137`, `TeamWebhookSettings.tsx:220`, `ElevationRetryCard.tsx:174` ;
- `formatDateTime` : `ModerationQueue`, `DataExportManager`, `GpsConnectionsManager:88`, `BiketeamMigrationPage:390`.

`formatRelative` : `CommentItem.tsx:97`, `NotificationItem.tsx:118`, `PairedDevicesManager.tsx:105`,
`DeviceVerifyPage`, `MyGpxPreviewsPage.tsx:126`.

`FactsStrip` ne contient **aucune date** (distances et dénivelés seulement, `components/publication/FactsStrip.tsx`).

---

## 5. Écarts internes

### Formatages hors des utilitaires

- `pages/home/MemberHome.tsx:41` : `formatInTimeZone(new Date(), timezone, t('home.member.dateFormat'), {locale: i18n.language==='fr'?fr:enUS})`.
  Le pattern (`EEEE d MMMM` en FR, `EEEE, MMMM d` en EN) est identique à `dateFormats.longDay`,
  mais l'appel passe directement par date-fns-tz et duplique le choix de locale au lieu d'appeler
  `formatLongDay`. Fuseau du lecteur, ce qui est correct pour « aujourd'hui ».
- `config/routeMeta.ts:93-135` : `Intl.DateTimeFormat` brut, en `fr-FR` ou **`en-GB`**.
  - EN donne « 12 April 2026 » et « 08:30 » en **24 h**, quand le site écrit « April 12th, 2026 » /
    « 9:00 AM ».
  - FR donne « 12 avril 2026 », comme `PPP`.
  - Le fuseau de repli est `Europe/Paris` (`META_FALLBACK_TIME_ZONE`), alors que les utilitaires
    replient sur `UTC`.
  - Ce choix est délibéré et documenté (le SSR tourne en UTC, voir WEB-70), mais il contourne la
    règle de `frontend/CLAUDE.md:202`.
- `components/calendar/CalendarView.tsx`, `calendarRange.ts` : dayjs (utc + timezone) sert à placer
  les évènements dans la grille, en conversion dans `tz`. L'affichage des heures sur les évènements
  passe bien par `formatTime`. **Les en-têtes et créneaux de la grille Mantine `Schedule` utilisent
  les formats par défaut de Mantine** (`locale={i18n.language}`) : non vérifiés.
- `components/weather/useRouteLabels.ts:66-75` : durées « 1 h 05 » construites à la main
  (`padStart`). Ce n'est pas une date et aucun utilitaire n'existe pour ça.
- Le seul autre `Intl` est `lib/feedback/clientContext.ts:26`, qui lit le fuseau du navigateur sans
  rien afficher.

### Même information, formats différents

1. **Étendue d'un voyage** :
   - `formatPublicationSpan` (cartes, agenda, page détail) : « ven. 16 → dim. 18 oct. », mois
     factorisé, fin lue dans `endDateTime` et dans le fuseau de la dernière étape ;
   - `RouteUsages.tsx:118` : « ven. 16 oct. → dim. 18 oct. », sans factorisation, fin lue dans
     `endDate` et dans le seul fuseau `usage.timezone`.
2. **Lever / coucher du soleil** : dans le fuseau du **lecteur** dans `DepartureWeather.tsx:89,94`
   (`<FormattedTime>`), dans celui de l'**entité** dans `RouteVerdicts.tsx:225-226`. Pour une sortie
   lue d'un autre fuseau, les deux blocs météo d'une même page divergent.
3. **Date d'un post** : `formatDateTime` (« sam. 12 avr. · 09:00 ») sur la carte et la page détail,
   `PPP` (« 12 avril 2026 ») dans `ContentLists.tsx:58`.
4. **Date longue** : `formatDate` = `PPP` (« 15 juin 2025 », sans jour de semaine) et `formatLongDay`
   (« samedi 12 avril », sans année) coexistent. Il n'existe pas de format « date longue complète ».
5. **Heure d'un groupe** (tous pertinents mais à reproduire) :
   - « Départ 09:30 » (`RideGroupCard`, en 700) ;
   - « · départ 09:30 » (minuscule, gris, `UpcomingRideCard`) ;
   - « Groupe B · 09:30 » (`DepartureBlock`) ;
   - « Départ 09:30 » (SEO).
6. **Référence pour afficher les heures de groupe** : `RideDetailPage` compare à `ride.dateTime`,
   `UpcomingRideCard` à `startFor(ride)`, c'est-à-dire au groupe du lecteur.
7. **Repli sans zone** :
   - les utilitaires purs replient sur `'UTC'` ;
   - `useRendezvousFormat` replie sur le fuseau du lecteur ;
   - `TodoBand.tsx:56-58` réimplémente ce repli à la main (`isSupportedZone ? … : reader…`), comme
     `DayBox.tsx:45-48` ;
   - `routeMeta` replie sur `Europe/Paris`.
8. **WeekAgenda** : les lignes sont filtrées et regroupées par jour du lecteur (`dayKey`, l. 57),
   mais leur `DayBox` montre le jour dans le fuseau de l'entité. Un évènement peut donc tomber sous
   un jour du bandeau et afficher un autre jour (choix commenté l. 158-160).
9. **Documentation fausse** : la JSDoc de `formatDate` annonce « June 15, 2025 » alors que date-fns
   enUS `PPP` produit « June 15th, 2025 » ; celle de `formatRelative` annonce « il y a 2 heures »
   alors que date-fns produit « il y a environ 2 heures ».
10. **Champs dépréciés** : `RideGroupDto.time` n'est plus affiché nulle part (grep : seulement les
    éditeurs et `rideFormData.ts:171`). C'est conforme.

---

## 6. « Référence web » : formats normatifs à reproduire

Langue FR, sauf mention. L'heure suit `p` : « 09:00 » en FR (24 h), « 9:00 AM » en EN. Le mobile
peut suivre le réglage 12 / 24 h du téléphone (BRANDING §8.3).

1. **Fuseau.** Un rendez-vous (départ de sortie, groupe ou étape, arrivée estimée, passage météo,
   dates de voyage, `publishAt`, date de post) s'affiche dans `entity.timezone`. Un horodatage
   s'affiche dans le fuseau du lecteur : `user.timezone`, sinon celui de l'appareil. Si une zone est
   inconnue, utiliser le fuseau du lecteur, sans mention.
2. **Départ avec jour** : `EEE d MMM · HH:mm` → « sam. 12 avr. · 09:00 ». Année en plus si ce n'est
   pas l'année en cours, jugée dans le fuseau de l'entité : « sam. 10 avr. 2027 · 09:00 ».
   EN : « Sat, Apr 12 · 9:00 AM ».
3. **Relatif** : seulement « Aujourd'hui · 09:00 » et « Demain · 09:00 », jugés dans le fuseau de
   l'entité. Jamais « hier », jamais « dans 2 h » pour un rendez-vous. Les pastilles « Aujourd'hui »
   et « Demain » se placent sur l'image d'une carte et dans le bloc de départ.
4. **Départ sans jour**, quand une boîte du jour est à côté : « Départ 09:00 ».
5. **Boîte du jour** : `EEE` / `d` / `MMM` (+ `yyyy` hors de l'année en cours), dans le fuseau de
   l'entité : « sam. / 12 / avr. ».
6. **Jour seul** : « sam. 12 avr. » (`EEE d MMM`, + année). **Jour long** (accessibilité, accueil) :
   « samedi 12 avril ».
7. **Étendue d'un voyage** :
   - même jour : « sam. 11 oct. » ;
   - même mois : « ven. 16 → dim. 18 oct. » ;
   - sinon : « jeu. 30 avr. → dim. 3 mai ».

   Premier jour dans `trip.timezone`, dernier dans le fuseau de la dernière étape. La fin vient de
   `endDateTime`.
8. **Pas d'heure de retour** pour une sortie. L'arrivée estimée d'un groupe ou d'une étape s'écrit
   « Arrivée estimée 12:30 ».
9. **Groupes** :
   - Départ affiché sur cartes, listes et agenda : celui du groupe de l'inscrit (`startAt`), sinon
     la sortie.
   - Page sortie : en-tête sur `ride.dateTime`, plus « Votre groupe · Groupe B · 09:30 » si ce
     groupe part à une autre heure.
   - Liste des groupes : si **un** groupe a un `startAt` ≠ `ride.dateTime` (comparaison
     d'instants), **tous** affichent « Départ HH:mm », avec le jour s'il diffère de celui de la
     sortie.
   - Ne jamais afficher `time` brut.
10. **Mention de fuseau** : « heure de Tokyo (ven. 01:00 chez vous) », avec élision (« d'Athènes »,
    « du Caire ») et la table de noms FR de `utils/zoneLabel.ts`. Elle ne s'affiche que si les
    **décalages** diffèrent à cet instant. Le jour du lecteur n'est ajouté que s'il change.
    En ligne sur une page détail, en icône globe avec infobulle sur carte, ligne et calendrier.
    Pas de mention sur les passages météo ni sur les lignes de groupe.
11. **Horodatages** :
    - date : « 15 juin 2025 » (`PPP`) ;
    - date + heure : même format que le départ, sans relatif : « sam. 11 avr. · 09:00 » ;
    - relatif : « il y a environ 2 heures » (commentaires, notifications, appareils) ;
    - mise à jour météo : « Mise à jour à 14:05 », ou « Mise à jour le 9 novembre 2026 à 14:05 ».
12. **Durée** : « 29 min », « 1 h 05 ». **Calendrier** : « équipe · 09:00 · lieu », ou « Toute la
    journée ». La grille suit le fuseau du lecteur, l'heure affichée celui de l'entité.

À trancher avant d'aligner le mobile, parce que le web lui-même diverge (§5) :
- l'étendue d'un voyage dans `RouteUsages` ;
- le fuseau du lever / coucher du soleil ;
- la date d'un post dans `ContentLists` ;
- le 24 h en anglais du SEO.
