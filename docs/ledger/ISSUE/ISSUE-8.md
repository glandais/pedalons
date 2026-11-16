---
id: ISSUE-8
title: "`FeedbackGithubWorker` réserve la ligne avant d'appeler GitHub"
status: done
done: 2026-10-11
---

## Livré

`ISSUE-8` **`FeedbackGithubWorker` réserve la ligne avant d'appeler GitHub** (2026-10-11, contrat inchangé, migration `V69__feedback_github_lease.sql`, constat de la modélisation formelle TLA+/Lean). Avant, `ConcurrentExecution.SKIP` ne protégeait qu'une JVM. Le worker relisait PENDING dans une transaction courte, appelait `createIssue` hors transaction et n'écrivait CREATED qu'après. Pendant la minute d'un déploiement start-first, le second backend relisait donc la ligne en PENDING et ouvrait une seconde issue, celle du dernier écrivain gagnant et l'autre restant orpheline (même course sur `reopen` et sur le résumé de 07:00). Désormais chaque ligne (`error_signatures`, `feedback_reports`) est louée avant ses appels GitHub, comme dans `WeatherFetchWorker` : colonne nullable `github_claimed_until`, `claim` est un update conditionnel (libre ou bail expiré), `release` est en `finally` et ne libère que son propre bail, et le bail dure 5 min. La publication d'une signature ou d'un signalement, la réouverture d'une régression et le résumé quotidien passent tous sous ce bail, puis relisent la ligne. Couvert par `FeedbackGithubWorkerDoublePublishRaceTest` (deux ticks qui se chevauchent : un seul `createIssue`, pour une signature comme pour un signalement). **À ne pas défaire** : ne pas remplacer le bail par un statut PUBLISHING (l'ancienne release ne sait pas mapper la valeur et `reportError` y casse), ne pas tenir de transaction ni de `FOR UPDATE` pendant l'appel GitHub, et ne pas appeler GitHub pour une ligne sans avoir pris son bail. L'ancienne release ignore le bail : la course reste possible une dernière fois, pendant le déploiement qui livre ce correctif.
