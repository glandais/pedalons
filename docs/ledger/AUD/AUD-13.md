---
id: AUD-13
title: "Journaux JSON centralisés"
status: done
done: 2026-09-29
---

## Livré

| ID | Thème | Audit | Gravité | Livré |
|---|---|---|---|---|
| `AUD-13` | Observabilité | §9.3 | — | **Journaux JSON centralisés** (2026-09-29) — le backend journalise en JSON en `%prod` (`quarkus-logging-json`, `quarkus.log.console.json.enabled` faux hors `%prod`), une entrée par événement, trace de pile comprise. Alloy envoie à Loki les journaux de tous les conteneurs de toutes les stacks (labels `stack`, `service`, et `level` pour le backend) et les journaux d'accès de Caddy, **lus tels que Caddy les écrit, donc déjà filtrés** (`OPS-6`). À ne pas défaire : la rétention de Loki est de **14 jours**, la promesse de la politique de confidentialité pour le journal d'accès — ne pas la relever, et ne jamais brancher Alloy sur une source non filtrée ; peu de labels (ni statut, ni chemin, ni utilisateur), le reste se cherche dans la ligne avec `\| json`. Conséquence acceptée : la pile complète d'un poste de travail tourne en `%prod`, donc journalise aussi en JSON. Essayé hors Swarm : un conteneur étiqueté comme une tâche Swarm et un fichier d'accès Caddy arrivent dans Loki avec les labels attendus, la règle du ruler est chargée |
