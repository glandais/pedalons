---
id: OPS-36
title: "GoatCounter auto-hébergé pour la mesure d'audience du site"
status: done
done: 2026-10-15
---

## Livré

`OPS-36` **GoatCounter auto-hébergé pour la mesure d'audience du site** (2026-10-15, livré
dans le dépôt, pas encore déployé : c'est `OPS-41`) — plan
[`2026-10-15-web-analytics.md`](../../plans/2026-10-15-web-analytics.md) (§3, étape 1 du §8, faits
vérifiés à l'étape 0, §9). Un service `goatcounter` dans `docker-compose.yml`
(`arp242/goatcounter:2.7.0`, commande en liste YAML, DSN par `GOATCOUNTER_DB` et mot de passe par
`PGPASSWORD` hors du DSN, `-tls=http`, `-dbconn=4,1`, `tmpfs` sur le répertoire de données,
healthcheck `wget`, rotation courte du journal Docker, 128M, réseau `pedalons` seul, ancre de
labels, `update_config`/`rollback_config` stop-first à cause de `-automigrate`), routé en
`Path(/count)` sans `Host()` à la priorité 150, pour que chaque domaine de club l'atteigne sur sa
propre origine, derrière le middleware `count-headers` (réécrit le `Host` vers le site unique,
retire `Cookie` et `Referer`, vide `X-Real-Ip`, `Cf-Connecting-Ip`, `Fly-Client-Ip` et
`X-Azure-Socketip`) et une limite de débit ; tableau de bord sans port publié, par un routeur
`Host(GOATCOUNTER_VHOST)` atteint par tunnel SSH. Base `goatcounter` sur le PostgreSQL existant,
créée par `scripts/goatcounter-init.sh db` (sans interaction, SQL par stdin) ; `site` arrête
GoatCounter, crée le site par un conteneur jetable dans l'espace réseau de postgres, pose
`collect = 30` (sessions, région, langue et pages vues individuelles coupées) et
`data_retention = 730` en SQL avant tout hit, purge les sessions de `store`, relit les réglages
et remonte le service ; `password` change le mot de passe du compte. **Base non sauvegardée** :
`deploy.sh --hold-app` garde GoatCounter à 0, `restore.sh` rappelle `goatcounter-init.sh db`
après `pg_restore`. `deploy.sh` refuse une seule des deux clés `GOATCOUNTER_*` posée, et
`PEDALONS_ANALYTICS_COUNT_PATH` sans elles ; les deux vides (staging), il met `goatcounter` à 0
réplique dans son overlay. Coupé sur la pile e2e (`profiles: [analytics]` dans
`docker-compose.e2e.yml`) et sur un poste par défaut (profil dit dans le `README`) ; clés vides
dans `.env.example`. Alloy écarte avant Loki les lignes `hit =`/`paths =` du journal d'erreur, qui
recopient IP et agent utilisateur quand l'écriture échoue. `OPERATIONS.md` : création, réglages,
tunnel, restauration, mémoire, base non sauvegardée, purge à surveiller, revue annuelle de la
rétention, ne jamais utiliser « Forgot password », `log_skip` dans « Access logs ». Pas de test
automatisé (infrastructure) : la recette est la ligne 1 du §8 du plan ; ce qui ne se constate
qu'en prod (Caddy de l'hôte, tunnel, tâche Swarm de postgres, staging) est `OPS-41`. **À ne pas
défaire** : sessions coupées et *Individual pageviews* coupé — un site unique pour tous les
domaines, sessions allumées, relierait la navigation d'un club à l'autre (clé
`agent utilisateur-IP-site` en clair dans `store`) ; un seul site GoatCounter, `Path(/count)` sans
`Host()` ; les en-têtes d'IP du client vidés par le middleware (sinon le client choisit l'IP
lue) ; jamais de mot de passe dans le DSN (l'avertissement « No sites yet » le recopie) ; réglages posés
en SQL **avant** l'activation, GoatCounter arrêté pendant la création du site ; la base n'est
pas sauvegardée (la politique le dit) ; prod seulement, sans `profiles:` dans
`docker-compose.yml` ; `/count` jamais écrit dans le journal Caddy.
