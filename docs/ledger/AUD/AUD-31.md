---
id: AUD-31
title: "Le Makefile Garmin ne nomme plus de version du SDK"
status: done
done: 2026-09-30
---

## Livré

| ID | Thème | Audit | Gravité | Livré |
|---|---|---|---|---|
| `AUD-31` | Garmin | G6 | Important | **Le Makefile Garmin ne nomme plus de version du SDK** (2026-09-30, scindé de `AUD-27`) — `simulator-docker` et `run-docker` appelaient `connectiq-sdk-lin-8.4.0-2025-12-03-5122605dc` en dur. `DOCKER_CIQ_HOME` prend le nom du répertoire du SDK détecté (`CIQ_HOME`, déjà utilisé par les cibles natives) sous le point de montage du conteneur, `/root/.Garmin/ConnectIQ/Sdks/`. Vérifié par `make -n` avec le SDK installé et avec un `CIQ_HOME` fictif en 9.0.0. Pas de test automatisé |
