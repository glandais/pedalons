---
id: API-20
title: "Pagination du calendrier"
status: done
group: "Petites évolutions d'API"
done: 2026-10-09
---

## Livré

| ID | Livré | Écrans |
|---|---|---|
| `API-20` | **Pagination du calendrier** (relevé le 9 octobre 2026, livré le 27 juillet 2026) — sans changement de contrat depuis : `GET /api/calendar` et le calendrier d'équipe prennent `from` et `to` (`CalendarResource`, `TeamCalendarResource`, `QueryInstants.parse`), et `CalendarService.resolveFrom`/`resolveTo` ne retombent sur la fenêtre −30 j / +180 j que si le paramètre manque. Le mobile charge un mois par appel (`calendar_month_provider.dart`, `8a04d8f1`), le web passe la plage visible (`useCalendarDateRange`). L'entrée était restée ouverte faute d'avoir été relue. À ne pas défaire : la fenêtre par défaut reste celle du flux ICS (`generateIcs`, `generateIcsForTeam`), qu'un abonnement ne peut pas paginer. Aucune borne maximale sur l'écart `from`–`to` ; le filtre sur le départ plutôt que la fin reste ouvert sous `API-88` | 22 |
