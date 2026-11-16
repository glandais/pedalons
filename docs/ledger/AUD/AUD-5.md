---
id: AUD-5
title: "Un healthcheck sur chaque service"
status: done
done: 2026-09-30
---

## Livré

| ID | Thème | Audit | Gravité | Livré |
|---|---|---|---|---|
| `AUD-5` | Docker | I5 | Critique | **Un healthcheck sur chaque service** (2026-09-30) — minio, imgproxy, varnish et traefik rejoignent backend, frontend et postgres, chacun avec l'outil que son image embarque déjà : `mc ready local` (l'alias `local` est livré avec l'image `pgsty/minio`), `imgproxy health`, `varnishadm ping` (le socket de gestion du `varnishd` en cours, dans le répertoire de travail par défaut, qu'il soit en tmpfs sous compose ou dans l'image sous Swarm), `traefik healthcheck --ping`. traefik prend `--ping=true`, sur son entrypoint interne `:8080`, ni publié ni routé — **jamais sur `web`**, que Caddy ouvre à tout Internet ; les deux overlays (`docker-compose.local.yml`, `docker-compose.e2e.yml`), qui remplacent sa commande, le répètent. 10 s d'intervalle, 3 essais, 10 à 20 s de `start_period`. Sous Swarm, une tâche qui échoue son healthcheck est remplacée : c'est le gain, et le risque si une commande est fausse. Vérifié sur la pile e2e (les quatre `healthy`, `smoke.e2e.ts` et les tests d'avatar, qui passent par MinIO → imgproxy → varnish, verts) et par `docker stack config` ; **pas encore vu sous Swarm** — au premier `deploy.sh`, regarder `docker service ps` des quatre services. Pas de test automatisé |
