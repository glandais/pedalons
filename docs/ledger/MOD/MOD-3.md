---
id: MOD-3
title: "Seuil de masquage tenu sous concurrence"
status: done
done: 2026-09-30
---

## Livré

`MOD-3` **Seuil de masquage tenu sous concurrence** (2026-09-30) — le nombre de signalants était
compté dans la transaction de chaque signalement : deux signalements validés au même instant
pouvaient chacun voir 2 signalants, et le contenu n'était pas masqué avant un 4e.
`ReportService.hideIfReportedEnough` verrouille maintenant la ligne de la publication ou du
commentaire signalé avant de compter (`ContentReportRepository.lockReported`,
`refresh(…, PESSIMISTIC_WRITE)`, soit un `SELECT … FOR UPDATE`) : le second signalement attend le
commit du premier, et son comptage, une nouvelle instruction en `READ COMMITTED`, voit alors le
signalement de l'autre. Un `refresh` et non un `lock()` : la ligne a pu être masquée par la
transaction qui tenait le verrou, et `lock()` échouerait sur la vérification de version là où le
`refresh` relit cet état. Un signalement de membre ne verrouille rien (rien n'est masqué). Pas de
test de concurrence, qui serait instable : le chemin séquentiel reste couvert par
`ModerationResourceTest.thirdDistinctReporter_hidesTheContentFromMembers_butNotFromModerators` et
`thirdDistinctReporter_hidesACommentFromMembers`, qui passent par le verrou ; l'exclusion
elle-même repose sur la sémantique de PostgreSQL. Garder le verrou **avant** le comptage.
