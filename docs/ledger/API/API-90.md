---
id: API-90
title: "iCal : les dates des étapes « journée entière » étaient calculées en UTC"
status: done
group: "Défauts relevés"
done: 2026-10-06
---

## Livré

`API-90` **iCal : les dates des étapes « journée entière » étaient calculées en UTC** (2026-10-06,
sans changement de contrat, lot 0 du plan [fuseau des événements](../../plans/archive/2026-10-06-event-timezones.md))
— une étape partant avant 02:00 heure de Paris commençait la veille dans l'agenda, une finissant
après 22:00 y perdait son dernier jour. `IcsGenerationService` date `DTSTART` et `DTEND` des
événements `allDay` dans le fuseau de l'étape, que `StageTimezones` résout : lieu de départ →
1er point du parcours (non supprimé) → `Europe/Paris`. `TimezoneService.findZoneId` rend un
`Optional` pour ce repli (`getZoneId` garde son repli UTC pour la météo). `allDayEnd` compte
désormais en `LocalDate` dans ce fuseau. Les flux d'abonnement (`CalendarService.Feed`) et
l'ICS d'un voyage (`PublicationIcsService`) passent la table id → fuseau ; les sorties restent en
UTC avec `Z`. `X-WR-TIMEZONE:Europe/Paris` reste en dur, le fuseau d'équipe d'`API-60` le
remplacera. Couvert par `StageTimezonesTest` et `IcsGenerationServiceTest`
(`allDayEnd_countsDaysInTheStageZone`, `generateIcs_allDayStage_isDatedInParisByDefault`,
`generateIcs_allDayStage_isDatedInItsOwnZone`). **À ne pas défaire** : une date d'événement
journée entière se calcule dans un fuseau de lieu, jamais en UTC ni dans celui du serveur.
