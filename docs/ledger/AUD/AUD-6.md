---
id: AUD-6
title: "`forwardedHeaders.insecure=true` sur Traefik (atténué par les règles `DOCKER-USER` qui ne laissent que Caddy…"
status: open
verified: 2026-11-16
---

## Reste à faire

| ID | Thème | Audit | Gravité | Constat |
|---|---|---|---|---|
| `AUD-6` | Docker | I10 | Important | `forwardedHeaders.insecure=true` sur Traefik (atténué par les règles `DOCKER-USER` qui ne laissent que Caddy le joindre : sous Swarm il écoute sur toutes les interfaces, voir [`OPERATIONS.md`](../../OPERATIONS.md#only-caddy-may-reach-traefik)) — voir V3, `SEC-16` |
