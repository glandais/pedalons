# Audit d'homogénéité — axe « formats des valeurs »

## Synthèse

Les deux supports ont chacun **un** point d'entrée (`mobile/lib/core/utils/formatters.dart` ; `frontend/src/utils/unitFormat.ts` + `hooks/useUnits.ts` pour les nombres, `utils/dateFormat.ts` + `hooks/useRendezvousFormat.ts` pour les dates). Le format du départ (`BRAND-8`), l'heure 12 h / 24 h selon la langue, « Aujourd'hui / Demain » et la mention de fuseau suivent la même règle des deux côtés. L'écart principal est dans les **nombres** : le site formate au `toFixed`, sans tenir compte de la langue (« 92.4 km », « 1240 m » en français). Viennent ensuite la **date relative** (date-fns : « environ », jamais de date absolue, contre un seuil de 7 jours dans l'app), la **date des publications et annonces** (date longue avec année dans l'app, format court du départ sur le site) et la **météo** (plage « 9–13 °C » contre « 9 → 13 °C », pluie toujours affichée contre seulement en cas d'alerte). L'app a ses propres défauts : des dates assemblées à la main qui cassent l'anglais (« Monday 15 january »), « {count} membres » sans pluriel, une hauteur de pluie jamais convertie en impérial.

Légende : `M:` = `mobile/lib/`, `W:` = `frontend/src/`. « lu » = lu dans le code ; « déduit » = valeur reconstituée à partir du motif de la bibliothèque (intl / date-fns), non exécutée.

## 1. Distance, dénivelé, vitesse

| # | Sujet | Cartes concernées | App (valeur · fichier:ligne) | Site (valeur · fichier:ligne) | Verdict | Gravité |
|---|---|---|---|---|---|---|
| 1.1 | Séparateur décimal de la distance | toutes (fil, prochaine sortie, groupe, étape, parcours, agenda, tableau de bord) | « 92,4 km » en fr, « 92.4 km » en en : `NumberFormat.decimalPattern(locale)`, 1 décimale · `M:core/utils/formatters.dart:54-62,78-84` | « 92.4 km » **quelle que soit la langue** : `(meters * m).toFixed(1)` · `W:utils/unitFormat.ts:38-41`, gabarit `"{{distance}} km"` `W:locales/fr/common.json:562` | confirmé | moyenne |
| 1.2 | Séparateur de milliers du dénivelé | toutes cartes avec D+ | « 1 240 m » (espace fine insécable U+202F), « 1,240 m » en en · `formatters.dart:96-102` | « 1240 m », aucun séparateur, en fr comme en en : `Math.round(...).toString()` · `unitFormat.ts:43-46` | confirmé | moyenne |
| 1.3 | Espace entre valeur et unité | toutes | insécable U+00A0 (`withUnit`) · `formatters.dart:38,69` | espace ordinaire U+0020 (vérifié en octets) dans `"{{distance}} km"`, `"{{elevation}} m"`, `"{{speed}} km/h"`, `"{{temperature}} °C"` · `locales/fr/common.json:562,570,2247,2602` | nouveau | faible |
| 1.4 | Suffixe « D+ » sur le dénivelé d'une carte | groupe, étape | « 980 m D+ » (`formatElevationGain`) dans `PublicationStatsLine` · `M:core/widgets/publication_stats_line.dart:50-54`, utilisé par `ride_group_card.dart:142` et `stage_card.dart:137` | « 980 m » + icône flèche, sans D+ · `W:components/publication/ChildCard.tsx:163-169` | nouveau | faible |
| 1.5 | Ordre des chiffres d'un groupe ou d'une étape | groupe, étape | distance · D+ · vitesse · `publication_stats_line.dart:44-57` | vitesse · distance · dénivelé · `ChildCard.tsx:147-170` (`RideGroupCard.tsx:140`, `TripStageCard.tsx:56`) | confirmé | moyenne |
| 1.6 | Vitesse nulle | groupe, étape | affichée dès qu'elle est non nulle en base (`speedKmh != null`) · `publication_stats_line.dart:55-56` | masquée si `averageSpeed <= 0` · `ChildCard.tsx:147` | nouveau | faible |
| 1.7 | Vitesse : arrondi | toutes | entier : `formatNumber(units.speed(...))` · `formatters.dart:119-123` | entier : `Math.round` · `unitFormat.ts:48-51` | réfuté (identique) | — |
| 1.8 | Passage du m au km pour les petites distances | toutes | aucun : toujours en km, 1 décimale (« 0,4 km ») · `formatters.dart:78-84` | aucun : toujours en km, 1 décimale (« 0.4 km ») · `unitFormat.ts:38-41` | réfuté (même règle) | — |
| 1.9 | Unités impériales sur les cartes | toutes | `units` passé depuis `unitSystemProvider` à chaque appel (vérifié dans toutes les cartes du brief) ; aucun `'km'` en dur hors `lib/dev/` | `useUnits()` (`preferencesStore.unitSystem`) partout dans les cartes ; aucun `km` en dur dans les cartes | réfuté (respectées des deux côtés) | — |

## 2. Météo (ligne météo des cartes de sortie, voyage, étape, groupe)

| # | Sujet | Cartes concernées | App (valeur · fichier:ligne) | Site (valeur · fichier:ligne) | Verdict | Gravité |
|---|---|---|---|---|---|---|
| 2.1 | Plage de températures | sortie, voyage, étape, prochaine sortie | « 9–13 °C » (tiret demi-cadratin, unité une fois) ; une seule valeur si les deux arrondis sont égaux · `formatters.dart:139-151` | « 9 → 13 °C » (`rides.weather.summary.range` `"{{min}} → {{max}}"` `locales/fr/common.json:2010`) ; une seule valeur si égales · `W:components/weather/RideWeatherSummaryLine.tsx:57-66` | confirmé | moyenne |
| 2.2 | Probabilité de pluie | idem | toujours affichée : alerte « Pluie 60 % vers 11:00 » en ton d'alerte, sinon « Pluie 20 % » (probabilité max) · `ride_weather_summary_line.dart:140-157` | seulement en cas d'alerte, sous forme de badge « {condition} dès {time} » (« Averses dès 11:00 ») ; la probabilité n'apparaît que dans l'infobulle (`title`) · `RideWeatherSummaryLine.tsx:98-115`, `common.json:2009` | confirmé (« vers » contre « dès », nom de la précipitation sur le site seulement) | forte |
| 2.3 | Prévision pas encore ouverte | idem | « Météo dès le 15 janvier » (`formatDayMonth`, sans année ni jour de semaine) · `ride_weather_summary_line.dart:104-110` | « Météo disponible à partir du 15 janvier 2026 » (`formatDate` = `PPP`) · `RideWeatherSummaryLine.tsx:50`, `common.json:2008` | confirmé | moyenne |
| 2.4 | Vent | idem | flèche + « 18 km/h » · `ride_weather_summary_line.dart:183-201` | icône vent + flèche + « 18 km/h » · `RideWeatherSummaryLine.tsx:91-97` | nouveau (icône en plus) | faible |
| 2.5 | Pourcentage | ligne météo | « 20 % » avec espace insécable, **aussi en anglais** (« Rain 20 % ») · `formatters.dart:160-161` | « 20 % » en fr, « 20% » en en (gabarits) · `locales/en/common.json:1855,1861` | nouveau | faible |
| 2.6 | Hauteur de pluie en impérial | météo des écrans de détail (pas les cartes) | **toujours en mm**, même pour un utilisateur impérial : `formatPrecipitation(num mm)` ne prend pas d'unités · `formatters.dart:154-157`, appelé dans `rides/presentation/widgets/departure_weather_section.dart:83`, `weather_leg_sections.dart:285`, `ride_weather_map_markers.dart:382` | convertie en pouces (« 0.05 in ») · `unitFormat.ts:73-82`, `hooks/useUnits.ts` (`precipitation`) | nouveau (l'app ignore la préférence d'unités) | moyenne |

## 3. Dates et heures

| # | Sujet | Cartes concernées | App (valeur · fichier:ligne) | Site (valeur · fichier:ligne) | Verdict | Gravité |
|---|---|---|---|---|---|---|
| 3.1 | Format du départ (date + heure) | étape, « Utilisée dans », tableau de bord | « sam. 12 avr. · 09:00 », année seulement hors année courante, « Aujourd'hui · 09:00 » / « Demain · 09:00 » · `formatters.dart:669-704` | même règle et même gabarit (`dateFormats.departureDay` `"EEE d MMM"`, `dayAndTime` `"{{day}} · {{time}}"`) · `W:utils/dateFormat.ts:220-258`, `common.json:516-523` | réfuté (identique) | — |
| 3.2 | Heure 12 h / 24 h | toutes | selon la langue, motif `jm` (« 08:30 », « 8:30 AM ») · `formatters.dart:562-563` | selon la langue, motif `p` · `dateFormat.ts:136-146` | réfuté (identique) | — |
| 3.3 | Date d'une publication (post) dans le fil | fil, publication | « dimanche 8 novembre 2026 » : `formatLongDate`, toujours l'année, sans heure · `M:features/teams/presentation/widgets/publication_card.dart:506-507` | « dim. 8 nov. · 18:30 » : `<Rendezvous>` au format `dateTime`, année seulement hors année courante · `W:components/card/PublicationCard.tsx:89,140`, `common/Rendezvous.tsx:39-46` | confirmé | moyenne |
| 3.4 | Date d'une annonce | annonce | « jeudi 5 novembre 2026 » (`formatLongDate`) · `M:features/ads/presentation/widgets/ad_card.dart:128` | « jeu. 5 nov. · 18:42 » (`FormattedDateTime`) · `W:components/card/AdCard.tsx:76-78` | confirmé | moyenne |
| 3.5 | Plage d'un voyage | fil (voyage), « Utilisée dans » | « ven. 20 → dim. 22 nov. » (mois une seule fois s'il ne change pas, un seul jour si c'est le même) · `M:features/teams/domain/publication_timing.dart:143-175` | carte du fil : même règle (`formatPublicationSpan`) · `W:utils/publicationTiming.ts:61-71`. **« Utilisée dans » : « ven. 20 nov. → dim. 22 nov. »**, assemblée dans le composant, sans regrouper le mois ni le jour · `W:components/route/RouteUsages.tsx:110-120` | confirmé, mais l'écart est **interne au site** (l'app est cohérente) | moyenne |
| 3.6 | Heure de départ sur la carte d'un voyage | fil (voyage) | « Départ 09:00 » suivi de la plage en gris · `publication_card.dart:544-556,694-716` | la plage seule, **sans heure** (le libellé remplace « Départ 09:00 ») · `W:components/common/DepartureLine.tsx` (`PublicationDepartureLine`, branche `TRIP`) | nouveau | moyenne |
| 3.7 | Départ d'un groupe qui part un autre jour | groupe | « Départ 09:00 » + « sam. 12 avr. », jamais en relatif · `M:features/rides/presentation/widgets/ride_group_card.dart:285-293` | « sam. 12 avr. · 09:00 », ou « Demain · 09:00 » (`withDay` → `formatDeparture` en relatif) · `W:components/ride/RideGroupCard.tsx:210-214` | nouveau | faible |
| 3.8 | Pastille « Aujourd'hui / Demain » d'une sortie annulée ou passée | fil | masquée (`showRelative: !isPast && status != CANCELLED`) · `publication_card.dart:356-362,675-680` | toujours affichée si le jour correspond (`CardDayOverlay` ne teste pas le statut) · `W:components/card/common/CardDayOverlay.tsx` | nouveau | faible |
| 3.9 | Mention de fuseau sur une carte | fil, agenda, 7 jours | ligne de texte visible « heure de Tokyo (ven. 01:00 chez vous) » (`ZoneMentionLine`) · `M:core/widgets/zone_mention_line.dart` ; aucune mention sur la date d'un post (`publication_card.dart:473-474`) | icône globe, texte dans une infobulle seulement (`ZoneMentionIcon`) ; présente aussi sur la date d'un post · `W:components/common/Rendezvous.tsx` (`ZoneMentionIcon`) | nouveau (même texte, rendu différent) | moyenne |
| 3.10 | Heure seule (agenda, 7 jours) | agenda, 7 jours | heure seule, la date étant dans la boîte du jour · `M:features/calendar/presentation/widgets/agenda_card.dart:109`, `home/.../week_agenda_section.dart:174` | même chose · `W:components/home/WeekAgenda.tsx:181` | « trois formats de départ dans l'app » confirmé, mais **le site a les trois mêmes** (« Départ 09:00 », jour + heure, heure seule) : c'est un choix de conception, pas un écart | faible |
| 3.11 | Boîte du jour | fil, 7 jours, agenda | « sam. / 12 / avr. », année si ce n'est pas l'année courante · `M:core/widgets/day_box.dart` | « EEE / d / MMM », même règle pour l'année · `W:components/common/DayBox.tsx:55-84` | réfuté (identique) | — |
| 3.12 | Date d'appairage d'un appareil | appareil appairé | « Appairé le mardi 3 novembre 2026 » (`formatLongDate`) · `M:features/profile/presentation/widgets/paired_devices_section.dart:81` | « Appairé le 3 novembre 2026 » (`formatDate`, `PPP`) · `W:components/profile/PairedDevicesManager.tsx:103` | nouveau | faible |
| 3.13 | Date d'arrivée d'un membre | liste des membres | « Membre depuis mars 2024 » (mois + année) · `M:features/teams/presentation/pages/team_members_page.dart:359-366` | « A rejoint le 3 mars 2024 » (`PPP`) · `W:components/team/TeamMemberList.tsx:124-127` | confirmé | moyenne |
| 3.14 | Tableau de bord : date d'un post | tableau de bord | « 15 janvier » (`formatDayMonth`) · `M:features/teams/presentation/widgets/dashboard/dashboard_content.dart:74` | « 15 janvier 2026 » (`Rendezvous format="date"`) · `W:components/team/dashboard/ContentLists.tsx:58` | nouveau | faible |
| 3.15 | Tableau de bord : arrivée d'un membre, dernier envoi du webhook | tableau de bord (admin) | arrivée : relative (« il y a 3 jours ») · `dashboard_admin.dart:196-199` ; webhook : « 15 janvier » · `dashboard_admin.dart:344` | arrivée : `FormattedDate` « 3 mars 2024 » · `W:components/team/dashboard/AdminPanel.tsx:160` ; webhook : « 15 janvier 2026 » · `AdminPanel.tsx:232` | nouveau | faible |

## 4. Date relative

| # | Sujet | Cartes concernées | App (valeur · fichier:ligne) | Site (valeur · fichier:ligne) | Verdict | Gravité |
|---|---|---|---|---|---|---|
| 4.1 | Formulation | notification, commentaire, appareil appairé | « il y a 2 heures », « il y a 3 jours », « à l'instant » (< 60 s) : découpage maison, clés `dates.relative.*` · `formatters.dart:755-770,842-875` | `formatDistanceToNow` de date-fns : « il y a environ 2 heures », « il y a moins d'une minute », « il y a environ 1 mois » (déduit du format de date-fns) · `W:utils/dateFormat.ts:286-295` | confirmé | moyenne |
| 4.2 | Seuil de bascule vers une date absolue | idem | au-delà de 7 jours (`absoluteThresholdDays = 7`) → date longue « lundi 15 janvier 2026 » · `formatters.dart:762,837` | **aucun** : « il y a 3 mois », « il y a plus d'un an » · `dateFormat.ts:286-295` | nouveau | moyenne |
| 4.3 | Équipe + date dans une notification | notification | `'${teamName} · ${relative}'`, assemblé dans le widget · `M:features/notifications/presentation/widgets/notification_tile.dart:91-94` | clé `notifications.item.meta` `"{{team}} · {{when}}"` · `W:components/notification/NotificationItem.tsx:116-119` | nouveau (même rendu en français, assemblé à la main côté app) | faible |

## 5. Prix

| # | Sujet | Cartes concernées | App (valeur · fichier:ligne) | Site (valeur · fichier:ligne) | Verdict | Gravité |
|---|---|---|---|---|---|---|
| 5.1 | Montant | annonce, tableau de bord | « 1 200,00 € », **locale `fr_FR` imposée** (aussi en anglais), 2 décimales · `formatters.dart:205-212` | carte : `Intl.NumberFormat('fr-FR')`, 2 décimales, fr imposé · `W:components/card/AdCard.tsx:22-37` ; tableau de bord : locale de l'interface et 0 décimale pour un prix entier (« 1 200 € », « €1,200 » en en) · `W:components/team/dashboard/ContentLists.tsx:117-131` | nouveau (incohérence interne au site ; l'app et la carte du site ignorent la langue) | moyenne |
| 5.2 | Période de location | annonce | « 1 200,00 € / semaine », période dans un `TextSpan` séparé, atténué · `formatters.dart:224-237` | carte : « 1 200,00 € / semaine » (clé `ads.pricePerPeriod`) ; page de l'annonce : même texte assemblé dans le composant · `W:pages/ad/AdDetailPage.tsx:137-150` | réfuté (même texte) | — |
| 5.3 | Prix absent | annonce | « Prix à négocier » · `formatters.dart:225-229` | « Prix à négocier » · `AdCard.tsx:23-25` | réfuté | — |

## 6. Compteurs et pluriels

| # | Sujet | Cartes concernées | App (valeur · fichier:ligne) | Site (valeur · fichier:ligne) | Verdict | Gravité |
|---|---|---|---|---|---|---|
| 6.1 | Compteurs à zéro | fil (sortie, voyage, publication) | masqués : groupes et personnes seulement si `groupCount > 0`, commentaires seulement si `> 0` · `publication_card.dart:432-451,506-512` | affichés : « 0 groupe » toujours (`PublicationCard.tsx:120`), « 0 commentaire » dès que `commentCount` est défini (`:101-107`), « 0 personne » et « 0 étape » sur un voyage (`:129-132`) | confirmé | moyenne |
| 6.2 | Remplissage d'une sortie sur la carte du fil | fil (sortie) | « 11 personnes », sans maximum ni barre · `publication_card.dart:434-441` | même stat, plus une barre et « 8/12 places » / « Complet » · `W:components/card/PublicationCardProgress.tsx:15-33`, `common.json:2249-2250` | confirmé | moyenne |
| 6.3 | Remplissage d'un groupe | groupe, prochaine sortie | « 11/12 personnes » (accord sur le maximum) · `ride_group_card.dart:431-437`, `next_ride_card.dart:371-377` | « 11/12 personnes » (accord sur le maximum) · `RideGroupCard.tsx:90-95`, `NextRideCard.tsx:92-98`, `common.json:1802-1804` | réfuté (identique) | — |
| 6.4 | Remplissage dans le tableau de bord | tableau de bord | « 11 / 16 » (avec espaces), assemblé dans le widget · `M:features/teams/presentation/widgets/dashboard/dashboard_rides.dart:605-607` ; sans maximum : « N inscriptions » | « 11 / 16 » (clé `teams.dashboard.ride.fill`) · `W:components/team/dashboard/UpcomingRideCard.tsx:186-189`, `common.json:2395` ; « N inscriptions » | réfuté entre supports ; « 11 / 16 » contre « 11/12 » est une incohérence **interne à chaque support** | faible |
| 6.5 | Voyage : quels compteurs | fil (voyage) | étapes · distance · dénivelé · `publication_card.dart:620-640` | personnes · étapes · commentaires · `PublicationCard.tsx:125-135` | confirmé | moyenne |
| 6.6 | Nombre de membres d'une équipe | équipe (liste, découverte) | `teams.members` = « {count} membres », **sans pluriel** → « 1 membres » · `M:features/teams/presentation/pages/teams_page.dart:258`, `widgets/team_discovery_card.dart:119` | `memberCount_one/_other` → « 1 membre » · `W:components/card/TeamCard.tsx:37`, `common.json:1231-1233` | nouveau (bug de l'app) | moyenne |
| 6.7 | Séparateur de milliers dans un compteur | toutes | aucun (interpolation `'${n}'`) | aucun (interpolation i18next sans formatage) | réfuté (identique) | — |

## 7. Durées

| # | Sujet | Cartes concernées | App (valeur · fichier:ligne) | Site (valeur · fichier:ligne) | Verdict | Gravité |
|---|---|---|---|---|---|---|
| 7.1 | Durée en heures et minutes | détail d'un groupe ou d'une étape (aucune carte) | « 3 h 18 », « 3 h », « 45 min » ; en anglais « 3 h 18 min » · `formatters.dart:730-749` | « 3 h 18 », mais **« 3 h 00 »** pour une heure ronde (aucune variante heures seules), « 45 min » ; seulement dans les verdicts météo · `W:components/weather/useRouteLabels.ts:65-77`, `common.json:1937-1938` | nouveau | faible |

---

## Incohérences internes à l'app

| # | Sujet | Variante (valeur · fichier:ligne) | Gravité |
|---|---|---|---|
| A1 | Date assemblée à la main, qui ignore l'ordre et la casse de la langue | `formatFullDate` / `formatDayMonth` / `formatLongDate` = `'${dayFull} ${day} ${monthLower}'`, mois passé en minuscules · `formatters.dart:566-585` (et `monthLower` `:266-269`). En anglais : « Monday 15 january 2026 » (déduit). Touche l'agenda, la carte d'annonce, la carte de post, les appareils, le tableau de bord, la météo « dès le … » | moyenne |
| A2 | « Membre depuis » assemblé dans la page | `'${monthCapitalized(m).toLowerCase()} ${year}'` · `team_members_page.dart:363-365` → « Member since march 2024 » en anglais | faible |
| A3 | Date d'une annonce, carte contre détail | carte : « jeudi 5 novembre 2026 » (`formatLongDate`) · `ad_card.dart:128` ; détail : « jeudi 5 novembre », sans année (`formatFullDate`) · `ads/presentation/pages/ad_detail_page.dart:199` | faible |
| A4 | Date d'un post, carte contre détail contre tableau de bord | carte : `formatLongDate` (avec année) · `publication_card.dart:507` ; détail : `formatFullDate` (sans année) · `posts/presentation/pages/post_detail_page.dart:264` ; tableau de bord : `formatDayMonth` (« 15 janvier ») · `dashboard_content.dart:74`. Aucune ne suit la règle `BRAND-8` « l'année seulement hors année courante » | moyenne |
| A5 | D+ suffixé ou non | « 980 m D+ » sur les cartes de groupe et d'étape (`publication_stats_line.dart:53`) ; « 980 m » + icône ailleurs (`publication_card.dart:633`, `route_card.dart:126`, `agenda_card.dart:128`, `next_ride_card.dart:336`) | faible |
| A6 | Remplissage « 11 / 16 » assemblé dans le widget, contre « 11/12 personnes » ailleurs | `dashboard_rides.dart:607` contre `ride_group_card.dart:431` | faible |
| A7 | Libellé anglais du D+ | `units.elevationGain` en = « elev. + » → « 980 m elev. + » (`mobile/assets/l10n/en.json`) | faible |
| A8 | Clé morte avec typographie fautive | `dates.departure` = « Départ: {time} » (pas d'espace avant « : »), aucune référence dans `lib/` | faible |

## Incohérences internes au site

| # | Sujet | Variante (valeur · fichier:ligne) | Gravité |
|---|---|---|---|
| S1 | Plage d'un voyage, deux règles | carte du fil : « ven. 20 → dim. 22 nov. » (`utils/publicationTiming.ts:61-71`) ; « Utilisée dans » : « ven. 20 nov. → dim. 22 nov. », assemblée dans le composant (`components/route/RouteUsages.tsx:118`) | moyenne |
| S2 | Trois formateurs de prix | `AdCard.tsx:22-37` (fr-FR, 2 décimales, clé) ; `pages/ad/AdDetailPage.tsx:137-150` (fr-FR, 2 décimales, concaténation) ; `team/dashboard/ContentLists.tsx:117-131` (langue de l'interface, 0 décimale si entier) | moyenne |
| S3 | Nombres formatés à la main hors `useUnits` | pentes `toFixed(1)}%` → « 6.5% » (`components/route/RouteDetailView.tsx:300,308`, `ElevationChart.tsx:364,407,420`) ; l'app rend « 6,5 % » (`formatGrade`) | faible |
| S4 | Aperçus de lien (pas des cartes) | `config/routeMeta.ts:121-160` : `Intl.DateTimeFormat` avec `en-GB` (24 h en anglais, contre la règle 12 h), et `formatKm` maison en km, quelle que soit la préférence d'unités · `:165` | faible |
| S5 | Format du dénivelé dans les faits d'une publication | « D+ : 1240 m » (`publication.facts.elevation`, préfixe) · `locales/fr/common.json:1731` ; « 1240 m » + icône sur les cartes | faible |
| S6 | `formatDate` en anglais | `PPP` donne « November 3rd, 2026 » (ordinal, déduit de date-fns) ; le commentaire mobile `formatters.dart:587-591` prétend s'aligner sur « November 3, 2026 » | faible |
| S7 | Date du jour sur l'accueil | `formatInTimeZone` appelé directement, avec un motif tiré d'une clé (`pages/home/MemberHome.tsx:41-43`) au lieu de `useFormattedDate` ; le fuseau est bien passé | faible |

## Non vérifié

- **Rendus réels** : les valeurs « déduites » (motifs `MMMEd` / `yMMMEd` d'intl pour fr et en, `PPP` et `formatDistanceToNow` de date-fns, « Monday 15 january ») n'ont pas été exécutées. Les motifs sont lus, pas le texte produit.
- **Pages de détail** : seules les briques communes ont été suivies (durée, tuiles de statistiques, faits d'une publication). Les écrans de détail ne sont pas couverts ligne par ligne : leurs formats de date (« dès le … », « Prévision du … ») ne sont relevés que lorsqu'ils passent par un formateur partagé.
- **`CalendarView` (site)** contre `calendar_subscription_card.dart` : la carte d'abonnement ne contient pas de valeur formatée qui relève de cet axe. Le résumé d'un événement du calendrier du site (« équipe · heure · lieu », `CalendarView.tsx:147-175`) suit les mêmes formateurs que le reste.
- **Mes équipes** : l'app affiche des compteurs (membres, sorties à venir, posts récents) que `MyTeamsCard.tsx` n'affiche pas. C'est un écart de contenu plutôt que de format, laissé à l'axe concerné.
- **SSR / hydratation** de la date relative du site (calculée à l'heure du serveur) : hors axe, non examiné.
