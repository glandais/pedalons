---
id: OPS-25
title: "Un health check lent ne coupe plus tout `/api`"
status: done
done: 2026-09-30
---

## Livré

`OPS-25` **Un health check lent ne coupe plus tout `/api`** (2026-09-30) — traefik retire un
serveur dès son **premier** check en échec, avec un délai par défaut de 5 s ; avec une seule
réplique, une réponse lente de `/q/health/ready` sous charge faisait répondre `503 no available
server` à tout `/api` jusqu'au check réussi suivant (pile e2e : `WRN Health check failed …
context deadline exceeded serviceName=quarkus`, trois fois dans une passe ; même configuration en
production, labels partagés). `docker-compose.yml` pose désormais
`loadbalancer.healthcheck.timeout=10s` sur le backend et le frontend. **Invariant à garder** :
intervalle + timeout (3 s + 10 s) sous le délai où la tâche se dit non prête avant de drainer,
sinon un check lent en vol au SIGTERM laisse router vers une tâche qui s'arrête —
`quarkus.shutdown.delay` passe à 15 s (`stop_grace_period` 40 s couvre 15 + 20), le drain de
`server.js` à 15 s (`stop_grace_period` 25 s). traefik n'a pas de seuil d'échecs : ne pas
raccourcir le timeout pour « détecter plus vite », une tâche qui draine répond DOWN tout de suite.
Vérifié : `docker compose config`. Pas de test automatisé ; à valider par la passe e2e suivante
et au prochain déploiement (`scripts/deploy.sh`, sans 5xx pendant le roulement).
