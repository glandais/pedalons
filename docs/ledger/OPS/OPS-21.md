---
id: OPS-21
title: "Ce que le monitoring ne voit pas encore"
status: done
group: "Exploitation"
done: 2026-11-17
---

## Livré

`OPS-21` **Ce que le monitoring ne voit pas encore** — PostgreSQL et ses requêtes lentes sont
livrés ci-dessous ; le reste est écarté : le frontend SSR sous `OPS-62`, les erreurs côté client
sous `OPS-63`.

**PostgreSQL, le 17 novembre 2026** — un service `postgres-exporter` par environnement dans
`docker-compose.yml` (`quay.io/prometheuscommunity/postgres-exporter:v0.20.1`, 64M, environ 4 Mo
résidents), sur `pedalons-shared`, découvert par l'API Swarm comme le backend (job `postgres` de
`services/monitoring/prometheus/prometheus.yml`, label `env`) : un nouvel environnement n'y change
rien. Il lit la base sous `POSTGRES_USER`, le mot de passe dans sa propre variable
(`DATA_SOURCE_PASS`) pour qu'aucun caractère n'ait à être échappé dans une URL. Deux alertes :
`PostgresDown` (`pg_up == 0`, 2 min, critique) et `PostgresConnectionsHigh` (plus de 80 % de
`max_connections`, 10 min), testées par `promtool test rules`
(`services/monitoring/prometheus/tests/pedalons.test.yml`) ; les noms de métriques ont été relevés
sur un exporteur v0.20.1 réel. Décrit dans `docs/OPERATIONS.md`, « Monitoring ». 
**Déployé le 17 novembre 2026** en staging et en prod (`scripts/deploy.sh --rev` sur
les images déjà en service, puis `--monitoring`) : les deux cibles `postgres` répondent, `pg_up` vaut 1.

**Requêtes lentes, le 17 novembre 2026** — le service `postgres` de `docker-compose.yml` démarre
avec `log_min_duration_statement=500` et `log_parameter_max_length=0` (`command:`) : toute requête
de plus de 500 ms est écrite dans le journal de PostgreSQL, qu'Alloy envoie déjà à Loki
(`{service="postgres"} |= "duration:"`), sans ses paramètres liés — ils portent adresses e-mail et
noms, que Loki garderait 14 jours. Vérifié sur l'image `imresamu/postgis:18-3.6-alpine` avec une
requête liée comme celles de JDBC : la durée et le SQL (`$1`) sont journalisés, la valeur ne l'est
pas. Le réglage est dans le dépôt plutôt qu'en `ALTER SYSTEM`, pour qu'un nouvel environnement
l'ait aussi ; le changer redémarre PostgreSQL au déploiement suivant. Pas d'alerte (décidé avec le
propriétaire) : la requête type est décrite dans `docs/OPERATIONS.md`, « Monitoring ». Déployé en staging et en prod le 17 novembre 2026.
