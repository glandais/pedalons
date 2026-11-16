---
id: WEB-71
title: "Calculs de jours hors du fuseau effectif"
status: done
group: "Défauts d'interface"
done: 2026-10-06
---

## Livré

`WEB-71` **Calculs de jours hors du fuseau effectif** (2026-10-06, lot 0 du plan
[fuseau des événements](../../plans/archive/2026-10-06-event-timezones.md)) — trois endroits comptaient les
jours dans le fuseau du navigateur ou par pas de 24 h. `WeekAgenda` construit ses sept jours en
jours calendaires (midi UTC de la date du fuseau effectif, relu en UTC) : `now + i × 24 h` sautait
un jour le soir du passage à l'heure d'été. `getVisibleRange` (`components/calendar/calendarRange.ts`)
prend le fuseau effectif et rend les minuits de ce fuseau, en comptant les jours sur des dates
UTC ; `CalendarView` le lui passe. « Ajouter une étape » (`TripEditor.handleAddStage`) passe par
`addCalendarDays` : J+n à la même heure murale du fuseau effectif, au lieu de `setDate` dans
celui du navigateur — remplacée depuis par `addDaysToWallTime` (`utils/wallTime.ts`), qui
compte sur la chaîne d'heure murale (`API-60`, lot 2). `toDateTimeLocalValue` / `fromDateTimeLocalValue`,
sans appelant, sont supprimées. Couvert par `calendarRange.test.ts` (minuits de Tokyo, semaine du
passage à l'heure d'été), `useCalendarDateRange.test.ts` (grille dans la fenêtre préchargée, à
Honolulu et Kiritimati), `wallTime.test.ts` (`addDaysToWallTime`) ; `WeekAgenda` n'a pas de test.
**À ne pas défaire** : un jour se compte en arithmétique de calendrier, jamais en millisecondes
ni sur un `Date` local.
