---
id: AUD-7
title: "Limites mémoire"
status: done
done: 2026-09-29
---

## Livré

| ID | Thème | Audit | Gravité | Livré |
|---|---|---|---|---|
| `AUD-7` | Docker | I14 | Important | **Limites mémoire** (2026-09-29) — chaque service de `docker-compose.yml` porte `deploy.resources.limits.memory`, appliqué par Swarm comme par compose : backend `BACKEND_MEMORY` (1536M), varnish `VARNISH_MEMORY` (1536M), imgproxy 1536M, postgres et minio 1G, frontend 512M, traefik 256M ; le tileserver de la stack partagée 3G. Le heap du backend n'a **pas de `-Xmx`** : l'entrypoint `run-java.sh` de l'image Jib (`ubi9/openjdk-25-runtime`) passe `-XX:MaxRAMPercentage=$JAVA_MAX_MEM_RATIO`, que `application.properties` fixe à 60 dans l'image (`quarkus.jib.environment-variables`, avec `GC_MAX_METASPACE_SIZE=256`) — sans limite, ce même entrypoint prenait 80 % de la RAM de l'hôte, ~24 Go mesurés sur un poste de 30 Go. Le cache Varnish, en mémoire (malloc), passe de 20G sans limite à `VARNISH_SIZE` 1G par défaut ; imgproxy est plafonné à 4 images simultanées (`IMGPROXY_WORKERS`, au lieu de deux par CPU de l'hôte) pour que sa limite tienne. À ne pas défaire : pas de `-Xmx` en dur (il faudrait le tenir à la main en phase avec la limite), ni de ratio à 80 (le non-heap — metaspace ~115 Mo mesurés, threads, buffers Netty, runtime ONNX de Magika — n'y tiendrait plus, et un kill par le cgroup ne passe pas par `ExitOnOutOfMemoryError`) ; pas de limite sur valhalla, dont le rebuild en demande bien plus que le service (service retiré le 2026-10-17, `OPS-48`). Pas de test : `docker compose config` et `docker stack config` acceptent les deux fichiers. Tableau et budget d'un hôte dans [`OPERATIONS.md`](../../OPERATIONS.md#memory). La limite CPU reste ouverte (`AUD-30`) |
