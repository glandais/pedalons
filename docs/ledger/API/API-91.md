---
id: API-91
title: "`from` / `to` malformés donnaient une 500"
status: done
group: "Défauts relevés"
done: 2026-10-06
---

## Livré

`API-91` **`from` / `to` malformés donnaient une 500** (2026-10-06, sans changement de contrat)
— `Instant.parse` lève une `DateTimeParseException`, que `GlobalExceptionMapper` ne traite pas en
400. Les six ressources (`CalendarResource`, `TeamCalendarResource`, `PublicationResource`,
`TeamPublicationResource`, `AdResource`, `UserResource`) lisent leurs bornes par
`QueryInstants.parse`, qui lève `BadRequestException`. Décision : pas de `format: date-time` au
contrat — il changerait le type des paramètres dans les clients générés pour un gain nul —, ni de
traduction globale de `DateTimeParseException` en 400, qui ferait passer pour l'erreur de
l'appelant une donnée invalide lue en base. Couvert par
`CalendarResourceTest.getEvents_withMalformedBound_shouldReturn400` et
`listPublications_withMalformedBound_shouldReturn400`.
