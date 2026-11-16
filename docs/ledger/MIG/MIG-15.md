---
id: MIG-15
title: "Un reset relancé après un échec de `setTargetTeam` reconnaît l'équipe qu'il vient de créer"
status: done
done: 2026-10-11
---

## Livré

`MIG-15` **Un reset relancé après un échec de `setTargetTeam` reconnaît l'équipe qu'il vient de créer** (2026-10-11, contrat inchangé, constat de la modélisation formelle TLA+/Lean) — la mise de côté de l'ancienne équipe, la nouvelle équipe et sa ligne de correspondance `TEAM` sont validées dans une même transaction (`ensureLiveTargetTeam`), mais `target_team_id` est écrit ensuite dans une transaction à part (`BiketeamMigrationJobService.setTargetTeam`). Si cette écriture était perdue (SIGKILL d'un déploiement, coupure base, job perdu au profit de `recoverStuck`), l'essai suivant mettait de côté l'équipe tout juste créée. Il la renommait en `<slug>-reset-<jobTsid>`, déjà pris par la première, butait sur `uk_teams_domain_slug` à chaque essai et finissait en FAILED INTERNAL_ERROR. Pour une équipe renommée sur Pédalons, il la jetait et en créait une troisième. Désormais `BiketeamLiveMigrationWorker.prepareTarget` ne rejoue pas le reset quand une équipe **à la corbeille** du domaine porte déjà le suffixe de mise de côté de ce job (`setAsideByThisJob`, `TeamRepository.existsTrashedBySlugSuffixAndDomain` — une équipe mise de côté l'est toujours dans la transaction qui la renomme, si bien qu'une équipe vivante renommée à la main ne peut pas se faire passer pour elle) : l'équipe migrée est alors son résultat, et l'essai la reprend. Couvert par `BiketeamResetRetryAfterLostTargetRaceTest` (même slug et équipe renommée). **À ne pas défaire** : le suffixe `-reset-<jobTsid>` sert de marqueur durable du reset, donc `setAsideSlug` doit garder le tsid du job en entier. La mise de côté doit rester dans la transaction qui crée l'équipe qui lui succède et sa ligne `TEAM` : c'est ce qui garantit que l'équipe pointée par la correspondance est celle de ce job.
