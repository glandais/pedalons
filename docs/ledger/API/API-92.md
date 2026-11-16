---
id: API-92
title: "Mail d'export : date en heure de Paris et au format français pour tout le monde"
status: done
group: "Défauts relevés"
done: 2026-10-06
---

## Livré

`API-92` **Mail d'export : date en heure de Paris et au format français pour tout le monde**
(2026-10-06, sans changement de contrat) — l'expiration du lien suit la langue et le fuseau du
destinataire par `NotificationTexts.formatDateTime` (« dimanche 11 octobre à 08h30 », « Sunday,
October 11 at 3:30 PM »), le formateur des notifications rendu public ; `ExportJobContext` porte
`user.timezone`, lu au chargement du job. Les quinze `@Scheduled(cron = …)` déclarent
`timeZone = Crons.ZONE` (`UTC`) : comportement inchangé en production, où la JVM est en UTC, mais
plus dépendant du fuseau de la machine. Couvert par
`NotificationTextsTest.formatDateTime_followsTheReadersLanguageAndZone`. **À ne pas défaire** :
un nouveau cron prend `timeZone = Crons.ZONE` ; les heures des tâches de nuit sont des heures UTC.
