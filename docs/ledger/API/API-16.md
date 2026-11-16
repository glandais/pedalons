---
id: API-16
title: "« Terminée » dite par le serveur"
status: done
group: "Petites évolutions d'API"
done: 2026-09-30
---

## Livré

| ID | Livré | Écrans |
|---|---|---|
| `API-16` | **« Terminée » dite par le serveur** (2026-09-30) — **API 7.3.0** : un booléen `finished`, obligatoire, calculé au moment où la réponse est construite, sur `RideDto` (départ passé), `TripDto` (dernière étape commencée : `endDate`, sinon `dateTime`) et `CalendarEventDto` (fin passée, sinon début). **Tranché avec le propriétaire : pas de valeur `TERMINÉE` dans `Status`**, ni stockée ni calculée. `Status` est le cycle de publication, partagé par tous les contenus, lu et écrit par les formulaires et les filtres `status=` ; « terminée » est une autre dimension — une sortie annulée et passée est les deux. Une valeur stockée aurait demandé une tâche planifiée idempotente et une migration, et aurait été en retard sur l'horloge ; une valeur calculée dans l'enum aurait changé le sens du filtre `status=PUBLISHED` et demandé un enum de réponse distinct. Aucune requête de plus : le calcul ne lit que des champs du DTO, `PublicationDto` (le fil) en hérite par `RideDto` et `TripDto`. `CalendarEventDto` est un record : `finished` y est un accesseur dérivé (`@JsonProperty`), pas un composant, pour ne pas changer ses constructeurs. Les clients lisent le champ au lieu de l'horloge : web `RideDetailPage` et `CalendarView` (même réponse au rendu serveur et à l'hydratation), mobile `RideTiming.isPast`, `TripTiming.isPast`, `AgendaCard` et la carte du fil. À ne pas défaire : ne pas réintroduire de dérivation locale, et ne pas « compléter » `Status`. Tests : `RideResourceTest.getRide_finished_followsTheStartTime` (**écrit, non lancé**), `CalendarView.test.tsx`, `mobile/check.sh` (685 tests, fixtures calculant `finished` selon la règle du serveur) | 11, 12, 22 |
