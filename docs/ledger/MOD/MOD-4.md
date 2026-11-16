---
id: MOD-4
title: "Aucun signalant d'une rafale n'est notifié de son signalement"
status: done
done: 2026-09-30
---

## Livré

`MOD-4` **Aucun signalant d'une rafale n'est notifié de son signalement** (2026-09-30) —
`ContentReported` fusionne tant qu'il attend la diffusion (clé : équipe + cible), et le résolveur
ne lisait que le premier signalement : seul son auteur était exclu, et un organisateur qui avait
signalé en second recevait la notification de son propre signalement.
`NotificationRecipientResolver.resolveReport` exclut maintenant tous les auteurs d'un signalement
ouvert sur cette cible dans cette équipe (`ContentReportRepository.findOpenReporterIds`, une
requête quelle que soit la rafale), en plus du premier. Un signalant d'une rafale précédente encore
ouverte est exclu aussi : il connaît déjà le contenu. Couvert par
`ModerationNotificationTest.aBurstOfReports_notifiesNoneOfItsReporters_notOnlyTheFirst` (un
extérieur signale, puis l'organisateur : une notification, à l'admin et à l'admin plateforme,
aucune aux deux signalants). Ne pas revenir à l'exclusion du seul `report.getReporter()`.
