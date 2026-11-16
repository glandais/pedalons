---
id: AUD-11
title: "Métriques"
status: done
done: 2026-09-29
---

## Livré

| ID | Thème | Audit | Gravité | Livré |
|---|---|---|---|---|
| `AUD-11` | Observabilité | I6 | Critique | **Métriques** (2026-09-29) — une stack `pedalons-monitoring` (`docker-compose.monitoring.yml`), déployée depuis `~/shared` par `scripts/deploy.sh --monitoring` : Prometheus (15 jours, 4 Go au plus), node-exporter, cAdvisor, Grafana et son tableau de bord « Pédalons — vue d'ensemble » provisionné depuis le dépôt (`services/monitoring/grafana/`). Le backend expose `/q/metrics` (`quarkus-micrometer-registry-prometheus`, pool Agroal compris par `quarkus.datasource.metrics.enabled`) ; Prometheus trouve chaque tâche backend de chaque environnement par l'API Swarm, sur `pedalons-shared`, étiquetée `env` du nom de la stack — un nouvel environnement ne demande aucun changement. Le trafic se mesure chez **Caddy** (`metrics { per_host }`, site `:2020`), seul point d'entrée de tous les environnements, pas chez traefik. À ne pas défaire : `/q` n'est pas routé par traefik, ce qui garde `/q/metrics` privé — ne pas y ajouter de route ; Grafana n'est publié que derrière la règle `DOCKER-USER` de `MONITORING_PORTS` (Swarm publie sur toutes les interfaces), et le port de métriques de Caddy derrière celle d'`HOST_PORTS` — jamais l'admin `:2019`, qui réécrit la configuration. Pas de test automatisé du déploiement : configurations validées par `promtool check config`, `amtool check-config`, `loki -verify-config`, `alloy validate` et `docker stack config`, et la chaîne Loki/Alloy/Grafana essayée hors Swarm. Mise en service sur l'hôte : `OPS-22` ; ce qui reste hors champ (PostgreSQL, frontend, erreurs client) : `OPS-21`. Procédure dans [`OPERATIONS.md`](../../OPERATIONS.md#monitoring) |
