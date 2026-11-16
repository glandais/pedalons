---
id: OPS-22
title: "Monitoring mis en service sur l'hôte"
status: done
done: 2026-09-30
---

## Livré

`OPS-22` **Monitoring mis en service sur l'hôte** (2026-09-30) — la stack `pedalons-monitoring`
(`AUD-11`, `AUD-12`, `AUD-13`) tourne en prod, dans l'ordre de
[`OPERATIONS.md`](../../OPERATIONS.md#setting-it-up) : pare-feu réinstallé (3300 et 2020 en `DROP` sur
l'interface publique, v4 et v6, et en timeout vus de l'extérieur — en IPv4 seulement : en IPv6, 3300 répondait encore, voir `SEC-29`), `metrics { per_host }` et site
`:2020` dans le Caddyfile, check Healthchecks du `Watchdog` au vert, relais d'alertes Scaleway TEM
— **le même que l'application**, contrairement au conseil d'`OPERATIONS.md` : une panne de TEM
tairait les alertes qui la signalent (le `Watchdog`, qui passe par Healthchecks, n'en dépend
pas ; à changer : `OPS-23`) —, Gatus sur l'hôte de sauvegarde. Recetté ce qui ne
l'avait été qu'hors Swarm : un backend découvert par environnement (label `env`), cAdvisor avec
les deux labels Swarm sur les quatre stacks, `agroal_awaiting_count` et
`jvm_gc_live_data_size_bytes` des deux backends, journaux JSON dans Loki (`level`, `job="caddy"`),
courriel d'alerte reçu (`amtool alert add`). La mise en service a corrigé quatre choses : Grafana
13 tient ~235 Mo au repos (`ContainerNearMemoryLimit` dès le démarrage à 256M) mais a été
tué par l'OOM killer à 512M (`anon-rss` 490 Mo) en calculant quelques gros tableaux de bord à la
fois : la limite passe à 1G ; `deploy.sh --monitoring` refuse un `ALERT_SMTP_SMARTHOST` sans
port, qu'Alertmanager rejette et que Swarm relançait en boucle ; le panneau « Part de 5xx »
affiche 0 % au lieu de « No data » quand un site n'a aucune erreur ; et surtout la nouvelle alerte
**`BackendMissing`** — la recette prévue (`scale pedalons-staging_backend=0` → `TargetDown`) ne
pouvait pas marcher : la découverte Swarm ne garde que les tâches en cours, si bien qu'un backend
sans tâche n'est pas une cible `down` mais plus de cible du tout. `BackendMissing` (un
environnement scrapé dans les dernières 24 h sans tâche backend depuis 5 min) a été déclenchée
pour de vrai sur le staging, courriel reçu. Ne pas la retirer au profit de `TargetDown`, qui ne
voit pas ce cas ; après un démontage volontaire, la mettre en silence (elle se résout seule 24 h
après). Le tableau de bord « Quarkus Micrometer Prometheus registry » du Dev Service LGTM est
provisionné à côté du nôtre, copié tel quel du dépôt Quarkus : le recopier pour le mettre à jour,
ne pas le modifier. Test : `promtool test rules` (`services/monitoring/prometheus/tests/pedalons.test.yml`).
