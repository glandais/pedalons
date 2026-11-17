---
id: OPS-21
title: "Ce que le monitoring ne voit pas encore"
status: open
group: "Exploitation"
verified: 2026-11-17
---

## Reste à faire

`OPS-21` **Ce que le monitoring ne voit pas encore** — trois angles morts restent :

- **Les requêtes lentes de PostgreSQL** : il faudrait `pg_stat_statements` dans
  `shared_preload_libraries`, c'est-à-dire un redémarrage de la base de chaque environnement
  (`command:` du service `postgres` de `docker-compose.yml`), puis `CREATE EXTENSION` ; à défaut,
  `log_min_duration_statement` mettrait les requêtes lentes dans Loki par un simple rechargement (`ALTER SYSTEM`, `pg_reload_conf()`).
- **Le frontend SSR** : ni métriques Node ni temps de rendu ; seul Caddy le voit, par hôte.
- **Les erreurs côté client web et mobile** : un GlitchTip, compatible Sentry, pèserait une base et
  un Redis de plus — à ne faire que si le besoin se confirme.

Taille : M.

## Livré

**PostgreSQL, le 17 novembre 2026** — un service `postgres-exporter` par environnement dans
`docker-compose.yml` (`quay.io/prometheuscommunity/postgres-exporter:v0.20.1`, 64M, environ 4 Mo
résidents), sur `pedalons-shared`, découvert par l'API Swarm comme le backend (job `postgres` de
`services/monitoring/prometheus/prometheus.yml`, label `env`) : un nouvel environnement n'y change
rien. Il lit la base sous `POSTGRES_USER`, le mot de passe dans sa propre variable
(`DATA_SOURCE_PASS`) pour qu'aucun caractère n'ait à être échappé dans une URL. Deux alertes :
`PostgresDown` (`pg_up == 0`, 2 min, critique) et `PostgresConnectionsHigh` (plus de 80 % de
`max_connections`, 10 min), testées par `promtool test rules`
(`services/monitoring/prometheus/tests/pedalons.test.yml`) ; les noms de métriques ont été relevés
sur un exporteur v0.20.1 réel. Décrit dans `docs/OPERATIONS.md`, « Monitoring ». **Déployé le 17 novembre 2026** en staging et en prod (`scripts/deploy.sh --rev` sur
les images déjà en service, puis `--monitoring`) : les deux cibles `postgres` répondent, `pg_up` vaut 1.
