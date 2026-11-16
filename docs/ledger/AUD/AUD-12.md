---
id: AUD-12
title: "Alertes"
status: done
done: 2026-09-29
---

## Livré

| ID | Thème | Audit | Gravité | Livré |
|---|---|---|---|---|
| `AUD-12` | Observabilité | I7 | Critique | **Alertes** (2026-09-29) — Alertmanager envoie par courriel (`ALERT_SMTP_*`) onze règles de `services/monitoring/prometheus/rules/pedalons.yml` (5xx et latence par site vus de Caddy, OOM, conteneur près de sa limite mémoire, disque, mémoire de l'hôte, heap après GC, pool de connexions saturé, cible injoignable) et une règle de journaux évaluée par Loki (`BackendErrors`). Deux pièces **hors de l'hôte**, parce qu'une alerte levée sur un hôte tombé n'en sort pas : l'alerte `Watchdog`, toujours active, pingue Healthchecks toutes les 5 minutes, qui écrit quand elle cesse ; Gatus, sur l'hôte de sauvegarde (`services/monitoring/gatus/`), sonde l'API, l'accueil, la redirection du domaine nu et staging, et l'expiration des certificats. Les sauvegardes n'y sont pas : leur propre check Healthchecks les couvre déjà. Alertmanager ne lit pas l'environnement : `deploy.sh` rend sa configuration dans `data/monitoring/` et y écrit le mot de passe SMTP et l'URL de ping **en fichiers** (`smtp_auth_password_file`, `url_file`), pour qu'aucune valeur ne casse le YAML. Couvert par `services/monitoring/prometheus/tests/pedalons.test.yml` (`promtool test rules` : les rapports dont les deux membres doivent partager leurs labels, faute de quoi l'alerte ne se déclenche jamais) ; Gatus essayé contre les vrais sites, quatre succès |
