---
id: AUD-2
title: "Retour arrière par version"
status: done
done: 2026-09-29
---

## Livré

| ID | Thème | Audit | Gravité | Livré |
|---|---|---|---|---|
| `AUD-2` | CI/CD | I4 | Critique | **Retour arrière par version** (2026-09-29) — les hôtes passent en Docker Swarm mono-nœud. `./build.sh` tague chaque image `${ENV_NAME}-<sha12>`, jamais déplacé, en plus de l'alias `${ENV_NAME}` du poste (depuis un arbre modifié, l'alias seul) ; `scripts/deploy.sh` déploie le tag du commit extrait (`--rev` pour un build antérieur), garde les cinq derniers builds par image et attend la fin du rollout, en erreur sur un rollback ou au bout de `DEPLOY_TIMEOUT`. backend et frontend roulent en start-first avec healthcheck et `failure_action: rollback` ; `docker service rollback` revient à la spec précédente. Pas de registry : sur un seul nœud, les images locales suffisent. Conséquence à ne pas défaire : pendant une minute deux backends partagent la base — migrations Flyway rétrocompatibles, tâches planifiées idempotentes ou réclamant leur travail en base (`PublicationPublishScheduler` réclame chaque brouillon par un update conditionnel sur la version, `AllPublicationRepositoryTest`). Procédure dans [`OPERATIONS.md`](../../OPERATIONS.md#rolling-updates-and-rollback) |
