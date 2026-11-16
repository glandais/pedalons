---
id: OPS-20
title: "Le backend attend postgres et MinIO au démarrage"
status: done
done: 2026-09-29
---

## Livré

`OPS-20` **Le backend attend postgres et MinIO au démarrage** (2026-09-29) — le premier
déploiement de `AUD-7` sur le staging a été annulé par Swarm : la limite mémoire changeait la spec
de postgres et de minio, que Swarm arrête avant de les relancer (stop-first), et le nouveau backend,
démarré au même moment, a échoué dans Flyway (`UnknownHostException: postgres`, exit 1). Flyway a
maintenant `connect-retries=15` (espacement plafonné à 5 s, environ une minute) et
`S3StorageService.init` retente le contrôle du bucket 12 fois toutes les 5 s sur une
`SdkClientException`. Les deux attentes restent bien en deçà des 180 s du `start_period`. Le premier
déploiement d'une stack ne voit donc plus de backend en échec. Ne pas retirer ces retries : Swarm
ignore `depends_on`. Pas de test automatisé (le cas demande un redéploiement Swarm).
