# Mesure d'audience du site — GoatCounter auto-hébergé

Écrit le 15 octobre 2026, relu le même jour (revues vie privée et technique, intégrées) ; les
questions ouvertes ont été tranchées le même jour (§7). **État : étape 0 faite le même jour (§9) ;
étapes 1 à 4 livrées le même jour dans le dépôt (`OPS-36`, `API-117`, `WEB-90`, `LEGAL-19`, au
ledger des livraisons), `ConfigServiceTest` et `e2e/analytics-off.e2e.ts` écrits mais à lancer par
le propriétaire ; étapes 5 et 6 (prod) à faire, ledger `OPS-41`. Rien n'est en production, le
compteur est coupé.** Les écarts entre l'implémentation et ce
plan sont dits dans les lignes des étapes (§8).
Ledger `OPS-36` (le service), `API-117` (le drapeau dans `/api/config`), `WEB-90` (le compteur côté
site), `LEGAL-19` (la politique), `OPS-41` (le déploiement et l'activation, étapes 5 et 6). Alternatives écartées : `OPS-37`, `OPS-38`, `OPS-39`, `LEGAL-20`.
Écartés par les décisions du §7 : `OPS-40` (compter des visites), `API-116` (couper la mesure pour un
club), `WEB-91` (statistiques pour les admins de club).

Les faits sur GoatCounter ont été **vérifiés le 15 octobre 2026 (étape 0, §9)** sur l'image
`arp242/goatcounter:2.7.0` : dans son code source (tag `v2.7.0`) et par une pile jetable sur un poste
(GoatCounter, PostgreSQL 17, Traefik v3.7.10 réglé comme la prod, Caddy 2.11.4). Ce qui reste
invérifiable sur un poste est dit à sa place, avec la raison. Les faits sur le dépôt ont été relus
dans le worktree le 15 octobre 2026, avec leurs numéros de ligne à cette date.

---

## 1. Contexte et objectif

Le site n'a aujourd'hui **aucune** mesure d'audience. Ce n'est pas un oubli : la politique le
promet (`privacy/privacy-policy.fr.md:203`, « nous n'utilisons aucun outil d'analyse ou de
suivi », et `:446`, « Aucun consentement aux cookies n'est donc requis »), et l'audit de juillet
avait retiré une ligne « Améliorer le service (analyse d'usage agrégée) » du §3 parce que rien ne
l'implémentait (`docs/plans/archive/2026-07-25-privacy-policy-audit.md:42`). La seule vue d'usage
est celle de Caddy, par hôte, sans route (`OPS-21`).

Les statistiques doivent répondre à cinq questions, et à rien d'autre :

1. **Combien de pages vues par domaine et par équipe** : par club quand le club a son domaine ou
   son alias, et par équipe sur un hôte partagé comme `pedalons.fr`, d'après le slug de l'équipe
   gardé dans le chemin (§4.2). Ce sont des **pages vues, pas des visites ni des visiteurs** : les
   sessions de GoatCounter sont coupées (§3.5), parce qu'une session unique sur tous les domaines de
   club relierait la navigation d'un site de club à l'autre (§5.1, condition 3) et que son
   empreinte, gardée sur chaque page vue, permettrait de reconstituer un parcours (§4.5). Décidé le
   15 octobre 2026, avec un seul site GoatCounter (§7) ; compter des visites est écarté (`OPS-40`).
2. **Quels écrans sont utilisés** : quelles routes, au niveau du gabarit (« fiche d'une sortie »),
   pas de l'objet (« la sortie du 12 ») ; seule l'équipe est nommée, jamais la sortie, le parcours ni
   la page.
3. **D'où viennent les visiteurs** : les sites référents, réduits à leur hôte, pour la première
   page d'un chargement seulement.
4. **Avec quoi** : famille de navigateur, système, largeur d'écran (téléphone ou bureau).
5. **Pages publiques ou pages réservées aux membres** : quelle part de l'audience porte sur les
   pages ouvertes à tous, d'après la propriété `auth` **de la route** (statique), jamais d'après
   l'état de connexion du visiteur.

### Hors périmètre, explicitement

- **Aucun suivi par personne** : pas d'identifiant de visiteur persistant, pas de cookie, pas de
  session, pas de parcours individuel reconstitué.
- **Aucun événement rattaché à un compte** : ni identifiant utilisateur, ni équipe d'appartenance
  du visiteur (l'équipe nommée dans le chemin est celle de la page vue, §4.2), ni rôle, ni état
  « connecté ». Rien n'est recoupé avec la base `pedalons`.
- **Pas de mesure dans l'application mobile**, ni dans les extensions Karoo et Garmin : le binaire
  mobile reste « no analytics » (`mobile/store-metadata/data-safety.md:30`, `:99`, `:464` ;
  `PrivacyInfo.xcprivacy`, `NSPrivacyTracking=false`). L'app n'a pas de WebView du site
  (`mobile/lib/core/utils/link_launcher.dart:206,293`, navigateur externe) : un lien ouvert depuis
  l'app est une visite du site, pas du binaire.
- **Pas de statistiques produit** pour les clubs (« Statistics and analytics » de
  `docs/PRODUCT_SHEET.md:151` est une autre notion), ni d'accès des admins de club au tableau de
  bord : seul le responsable du traitement le voit (§3.6, décision du §7 ; `WEB-91`).
- **Pas d'événements métier** (clic sur « Je participe », envoi d'un formulaire) : des pages vues
  seulement.

---

## 2. Décision : GoatCounter auto-hébergé, Umami en repli

GoatCounter tourne comme un service de plus de la pile Swarm, avec sa base sur le PostgreSQL 17
existant. Il est servi **sur la même origine** que le site, sous `/count`, depuis chaque domaine de
club.

| Critère | **GoatCounter** | Umami | Plausible CE | Matomo | SaaS (Plausible, Fathom…) | Journaux (GoAccess, `goatcounter import` des journaux Caddy) |
|---|---|---|---|---|---|---|
| Stockage | PostgreSQL (existant) | PostgreSQL (existant) | **ClickHouse** + PostgreSQL | MySQL/MariaDB | Chez le fournisseur | Fichiers de l'hôte |
| Conteneurs en plus | 1, binaire Go | 1, Node/Next.js | 2 à 3 (ClickHouse ≈ 1 à 2 Go) | 2 + PHP | 0 | 0 à 1 |
| Mémoire indicative | ≈ 40 Mo au repos (mesuré, §9) | ≈ 200 à 300 Mo | > 1 Go | ≈ 300 Mo + base | — | — |
| Cookie | Aucun sur `/count` (mesuré) ; un cookie de connexion au seul tableau de bord | Aucun | Aucun | Oui par défaut (désactivable) | Variable | Aucun |
| IP conservée | Non : sessions coupées, IP gardée en mémoire au plus 10 s pour le pays (vérifié) ; sauf un journal d'erreur, §3.1 | Non : hachage | Non | Configurable (anonymisation) | Chez un tiers | **Oui** dans les journaux |
| Sessions désactivables | Oui, case *Sessions* des réglages de collecte (vérifié) | Non : pas de réglage, la session est toujours calculée (code de la v3.4.0) | Non | Oui | Variable | — |
| Navigations côté client (React Router) | Oui, appel explicite | Oui | Oui | Oui | Oui | **Non** : seul le premier chargement passe par le serveur |
| Nouveau sous-traitant | Non (Scaleway déjà déclaré) | Non | Non | Non | **Oui** | Non |
| Plusieurs hôtes sur un site | Oui, l'hôte voyage dans le chemin (§3.1) | Oui | Oui | Oui | Oui | — |
| Ce qu'il faut maintenir | Une image, une base | Une image, une base, des migrations Prisma | Deux moteurs de base | PHP, une base de plus, des greffons | Un contrat | Des scripts hors dépôt |

**Pourquoi GoatCounter.** C'est le plus petit qui réponde aux cinq questions : un binaire, aucune
base nouvelle (une base `goatcounter` sur le cluster existant), pas de cookie, des sessions que
l'on peut couper, et l'IP n'est utilisée qu'en mémoire. Son API de comptage est un simple
`GET /count` (vérifié : appelé sans script, il répond un GIF de 43 octets, sans cookie ; §4.3),
qu'on peut appeler sans son script.

**Umami, en repli.** Même stockage (PostgreSQL, pas de cookie, auto-hébergé), plus lourd en mémoire
et avec plus de dépendances. Il sert si l'étape 0 révèle un blocage chez GoatCounter : sessions
impossibles à couper, IP mal lue derrière deux proxys, journal d'accès impossible à couper, image
abandonnée. **Il porte le même risque de suivi d'un site à l'autre** : sa session est un hachage de
l'IP, de l'agent utilisateur et du *website* (vérifié dans `src/app/api/send/route.ts` de la v3.4.0 :
`uuid(websiteId, ip, userAgent, sel mensuel, distinctId)`, sans réglage pour la couper). Un
*website* Umami unique pour tous les
hôtes relierait donc les sites de club entre eux ; basculer sur Umami impose un *website* par hôte
(donc le couplage avec `AdminDomainResource` écarté au §3.1), puisqu'il ne permet pas de couper les
sessions. Le côté site (§4) est écrit pour qu'en changer ne touche que l'expéditeur.

**Pourquoi pas les autres** (au ledger, « Délibérément dehors ») :

- **Plausible CE** (`OPS-37`) : ClickHouse, une seconde base de données à sauvegarder, surveiller et
  mettre à jour, et plus de mémoire que tout le reste de la pile pour quelques milliers de visites
  par mois.
- **Matomo** (`OPS-38`) : PHP et MySQL, deux briques absentes de la pile ; cookies par défaut, à
  désactiver ; des greffons à suivre. Il figurait sur l'ancienne liste CNIL des outils exemptables (la page
  de juillet 2025 n'en donne plus, §5.1), mais sa configuration exemptée ne fait rien de plus que
  GoatCounter ici.
- **Un service SaaS** (`LEGAL-20`) : un sous-traitant de plus au §4 de la politique, souvent un
  transfert hors UE au §5, un domaine tiers que les bloqueurs coupent, et un contrat à suivre.
- **Une solution par les journaux** (`OPS-39`) : les journaux Caddy vivent sur l'hôte, hors dépôt ;
  ils ne voient que le premier chargement d'une page, pas les navigations côté client ; ils
  contiennent les chemins concrets (`/outils-gpx/{previewId}`, les slugs des sorties, parcours et
  pages), qu'il faudrait réécrire après coup.

---

## 3. Conception côté infrastructure (`OPS-36`)

### 3.1 Le service dans `docker-compose.yml`

Un service `goatcounter`, qui respecte les règles de l'en-tête du fichier
(`docker-compose.yml:1-15`) : ni `profiles:` ni `name:` racine, labels Traefik sous `labels` **et**
`deploy.labels` par une ancre, une limite mémoire.

```yaml
  # GoatCounter, mesure d'audience du site (docs/plans/2026-10-15-web-analytics.md, ledger OPS-36).
  # Image officielle, épinglée ; base « goatcounter » sur le postgres de la pile.
  goatcounter:
    image: arp242/goatcounter:2.7.0             # 15 décembre 2025, la dernière ; suivie par dependabot
    # Le DSN par GOATCOUNTER_DB (GoatCounter lit chaque option dans GOATCOUNTER_<OPTION>) : `serve`
    # comme tout `docker exec … goatcounter db …` le trouvent sans le répéter. Le mot de passe passe
    # par l'environnement (lib/pq lit PGPASSWORD), jamais par le DSN : sans site, GoatCounter écrit le
    # DSN entier dans son journal au démarrage (§9), qui part dans Loki.
    environment:
      GOATCOUNTER_DB: postgresql+host=postgres dbname=goatcounter user=goatcounter sslmode=disable
      PGPASSWORD: ${GOATCOUNTER_DB_PASSWORD:-}
    command:
      - serve
      - -listen=:8080
      - -tls=http                                # le nom en 2.7 (« none », « proxy » : anciens alias) ; le cookie du tableau de bord ne prend Secure que si X-Forwarded-Proto vaut https
      - -automigrate
      - -dbconn=4,1                              # 16,4 par défaut ; postgres est dimensionné pour le backend
    logging:                                     # rotation courte : borne la copie du journal d'erreur restée sur l'hôte
      driver: json-file
      options: { max-size: 1m, max-file: "2" }
    networks: [pedalons]                        # pas « shared » : Traefik choisirait la mauvaise IP (:55-57)
    # L'image déclare VOLUME /home/goatcounter/goatcounter-data : sans montage, chaque tâche y laisserait
    # un volume anonyme. Rien n'y est écrit (base GeoIP intégrée, tout en PostgreSQL).
    volumes:
      - type: tmpfs
        target: /home/goatcounter/goatcounter-data
    healthcheck:
      test: ["CMD", "wget", "-qO", "/dev/null", "http://127.0.0.1:8080/status"]   # wget de busybox, dans l'image
      interval: 30s
      timeout: 5s
      retries: 3
    labels: &goatcounter-labels
      - traefik.enable=true
      - traefik.stack=${ENV_NAME}
      # Le compteur, sur tous les hôtes.
      - traefik.http.routers.goatcounter-count.rule=Path(`/count`)
      - traefik.http.routers.goatcounter-count.priority=150
      - traefik.http.routers.goatcounter-count.middlewares=ratelimit-count,count-headers
      - traefik.http.routers.goatcounter-count.service=goatcounter
      # Le vhost unique, plus ni cookie ni Referer : une valeur vide supprime l'en-tête (vérifié, §9).
      - traefik.http.middlewares.count-headers.headers.customrequestheaders.Host=${GOATCOUNTER_VHOST:-}
      - traefik.http.middlewares.count-headers.headers.customrequestheaders.Cookie=
      - traefik.http.middlewares.count-headers.headers.customrequestheaders.Referer=
      # Les en-têtes d'IP que GoatCounter préfère à X-Forwarded-For, et qu'un client pose à sa guise :
      # Caddy les laisse passer, Traefik aussi (forwardedHeaders.insecure). Retirés, l'IP lue est le
      # dernier saut public de X-Forwarded-For, celui que Caddy écrit (§3.1, « IP réelle »).
      - traefik.http.middlewares.count-headers.headers.customrequestheaders.X-Real-Ip=
      - traefik.http.middlewares.count-headers.headers.customrequestheaders.Cf-Connecting-Ip=
      - traefik.http.middlewares.count-headers.headers.customrequestheaders.Fly-Client-Ip=
      - traefik.http.middlewares.count-headers.headers.customrequestheaders.X-Azure-Socketip=
      - traefik.http.middlewares.ratelimit-count.ratelimit.average=…
      - traefik.http.middlewares.ratelimit-count.ratelimit.sourcecriterion.ipstrategy.depth=1
      # Le tableau de bord, sur le seul vhost : aucun bloc Caddy ne le relaie, seul un tunnel l'atteint (§3.6).
      - traefik.http.routers.goatcounter-dash.rule=Host(`${GOATCOUNTER_VHOST:-}`)
      - traefik.http.routers.goatcounter-dash.service=goatcounter
      - traefik.http.services.goatcounter.loadbalancer.server.port=8080
      - traefik.http.services.goatcounter.loadbalancer.healthcheck.path=/status
    deploy:
      replicas: 1                                # 0 hors prod : deploy.sh le met à 0 quand GOATCOUNTER_* sont vides (§3.7)
      labels: *goatcounter-labels
      # stop-first, pas *rolling-update : avec -automigrate, deux instances migreraient la même base.
      update_config:
        order: stop-first
      rollback_config:
        order: stop-first
      resources:
        limits:
          memory: 128M
```

Les points qui comptent :

- **Routage** : `Path(/count)` sans `Host()`, priorité 150, entre `/api` (100) et
  `karoo-manifest` (200, le précédent d'un `Path()` exact, `:207-213`). Comme les autres routeurs,
  il s'applique à **tout hôte qui atteint Traefik** : aucune règle à ajouter par club, ni DNS ni
  certificat. `docs/OPERATIONS.md:264-307` ne montre que les blocs Caddy de `pedalons.fr`,
  `www.pedalons.fr` et `staging.*` ; **chaque bloc Caddy de domaine de club ou d'alias doit
  importer le snippet `pedalons_access_log` et sa règle `log_skip` (§3.9)**, à vérifier hôte par
  hôte au déploiement (étape 5). Pas de sous-domaine `stats.<club>` : un bloc Caddy, un certificat
  et un DNS par club.
- **Un seul site GoatCounter** : GoatCounter choisit le site d'après le `Host` de la requête, port
  retiré (`Site.ByHost`, `lower(cname)`) ; **tant qu'une instance n'a qu'un site, il le sert pour
  n'importe quel `Host`** (repli de `handlers/mw.go`, vérifié : un `Host: whatever.example` est
  compté). Le middleware `count-headers` réécrit quand même le `Host` vers le vhost unique
  (`GOATCOUNTER_VHOST`, par exemple `stats.pedalons.internal`) : vérifié, Traefik v3.7 applique un
  `Host` personnalisé à `req.Host` (GoatCounter ne lit pas `X-Forwarded-Host`), et la mesure ne
  dépend pas du repli, qui tomberait au premier site ajouté. Le domaine du club voyage dans le chemin
  compté (§4.2). Pas de `passhostheader=false` : le `Host` deviendrait l'IP de la tâche. L'alternative, un site par
  `Domain` et par `DomainAlias`, couplerait la création d'un domaine (`AdminDomainResource`) à
  GoatCounter : écartée tant que les sessions sont coupées (§3.5), ce qui retire la seule raison
  vie privée de séparer les sites.
- **Ni cookie ni `Referer`** : le cookie `refresh_token` est posé en `Path=/`
  (`RefreshTokenCookieFactory.java:28`) et une requête même origine vers `/count` le porterait,
  avec `lang` ; le `Referer` d'une requête même origine est l'URL entière de la page, `?token=`
  compris. Le site ne les envoie pas (§4.3) ; le middleware les retire quand même, en défense en
  profondeur (vérifié derrière Caddy et Traefik : ni `Cookie` ni `Referer` n'arrivent). GoatCounter
  ne lit d'ailleurs jamais l'en-tête `Referer` pour un hit (vérifié dans le code et par une requête
  directe : sans `r`, le référent reste vide ; sans `p`, la requête est refusée en 400). Sa réponse
  ne pose aucun cookie ; elle porte `Access-Control-Allow-Origin: *` et un
  `Strict-Transport-Security` de 90 jours, sans effet sur des domaines déjà en HTTPS.
- **Pas de `/count.js`** : le site n'utilise pas le script de GoatCounter (§4.3), un seul chemin est
  routé sur les hôtes publics.
- **Pas de volume** : tout est dans PostgreSQL. Le répertoire de données de l'image,
  `/home/goatcounter/goatcounter-data` (vérifié), est déclaré `VOLUME` par le Dockerfile : sans
  montage, chaque tâche y créerait un volume anonyme, que `docker stack rm` laisserait derrière lui.
  Un `tmpfs` le remplace ; rien n'y est écrit (pas de `.mmdb` : la base GeoIP intégrée sert, §3.5).
- **Pool de connexions** : `postgres` est limité à 1 Go, dimensionné pour les 20 connexions du
  backend (`:256-262`). `-dbconn=4,1` (`max_open,max_idle` ; 16,4 par défaut, vérifié dans l'aide de
  `serve`) borne GoatCounter à 4 connexions.
- **Limite de débit propre à GoatCounter** : `/count` refuse au-delà de 4 requêtes par seconde et par
  IP (`429`, `-ratelimit count:4/1` par défaut, vérifié). Une navigation humaine n'y arrive pas ; le
  `ratelimit-count` de Traefik reste la borne d'ensemble.
- **Mise à jour stop-first**, écrite dans `update_config` et `rollback_config` même si c'est le
  défaut de Swarm, parce que la règle de la pile est start-first (`*rolling-update`,
  `docker-compose.yml:149`) : avec `-automigrate`, deux instances simultanées migreraient la même
  base en même temps. Perdre quelques secondes de comptage à chaque déploiement de GoatCounter est
  sans conséquence ; une migration concurrente pourrait l'être. `replicas: 1` explicite, pour
  qu'un `restore.sh` interrompu ne le laisse pas à 0 sans trace ; c'est `deploy.sh`, pas le fichier,
  qui le met à 0 là où la mesure n'existe pas (staging, §3.7).
- **Mot de passe de la base** : par `PGPASSWORD` (vérifié : lib/pq le lit, la connexion réussit avec
  un DSN sans mot de passe), **jamais dans le DSN**. Tant qu'aucun site n'existe (entre
  `goatcounter-init.sh db` et `site`, §3.2), GoatCounter écrit au démarrage un avertissement
  « No sites yet » qui recopie le DSN en entier (vérifié) : Loki l'aurait gardé 14 jours.
  Hexadécimal quand même (`openssl rand -hex 24`), pour le SQL de `goatcounter-init.sh`. Un
  `docker exec … goatcounter db …` hérite de l'environnement du conteneur : le script n'a pas à le
  répéter.
- **Variables vides** : `${GOATCOUNTER_VHOST}` et `${GOATCOUNTER_DB_PASSWORD}` ne peuvent pas porter
  `:?` ici : compose interpole tout le fichier, services hors profil compris, ce qui casserait la
  pile e2e et les postes. Elles s'écrivent `${…:-}` (pas d'avertissement là où elles manquent).
  `deploy.sh` en tire trois cas : **les deux posées** (prod), GoatCounter à 1 réplique ; **les deux
  vides** (staging), GoatCounter à 0 réplique par l'overlay qu'il écrit déjà pour `--hold-app`
  (§3.7) ; **une seule posée**, il **refuse de déployer** : sinon la prod aurait silencieusement un
  `Host=` vide et zéro comptage. Il refuse aussi `PEDALONS_ANALYTICS_COUNT_PATH` posé alors que
  GoatCounter est à 0 : le site compterait vers un `/count` que rien ne sert.
- **Healthcheck** : `/status` est intercepté avant la résolution du site (`handlers/mw.go`) et
  répond `200` en JSON (`uptime`, `version`, `database`, `go`…) **quel que soit le `Host`** (vérifié
  avec `Host: <ip>:8080`) : pas de `healthcheck.hostname`. Il répond `200` même base injoignable
  (l'erreur de `zdb.Info` est ignorée) : c'est un test de vie, pas de santé. L'image (Alpine) a le
  `wget` de busybox (vérifié ; ni `curl` ni binaire dédié) : le healthcheck de conteneur du bloc
  ci-dessus. `/status` donne les versions : il n'est routé que sur le vhost, jamais sur les hôtes
  publics.
- **Journal du conteneur** : les journaux des conteneurs partent dans Loki pour 14 jours
  (`docs/OPERATIONS.md:612-618`). **Pas de journal d'accès** par défaut (vérifié : seulement avec
  `-debug=req`, et `/count` en est exclu même alors ; aucune IP dans le journal après des dizaines de
  hits). **Mais un journal d'erreur, si** : quand l'enregistrement d'un hit échoue (base
  injoignable, panique), GoatCounter écrit le hit entier, **IP et agent utilisateur bruts compris**
  (`memlog.Error(ctx, err, "hit", h)` dans `memstore.go`, `"paths", hits` dans `cron/tasks.go` ;
  vérifié en arrêtant postgres : une ligne `hit = &{… Mozilla/5.0 … 81.2.69.142 …}`). La promesse
  « IP non conservée » serait fausse 14 jours après chaque panne de base. À l'étape 1 donc :
  `services/monitoring/alloy/config.alloy` gagne, pour `{service="goatcounter"}`, un `stage.drop`
  des lignes `^\s+(hit|paths)\s+=` (le journal est en texte aligné, une ligne par attribut), et le
  service une rotation courte du journal Docker (`logging.options.max-size`/`max-file`), qui borne la
  copie restée sur l'hôte. Le test de l'étape 6 refait la panne.
- **Courriels** : sans `-smtp`, GoatCounter « envoie » ses courriels sur sa sortie standard (défaut
  `stdout`, vérifié dans l'aide). Le seul compte est celui du responsable du traitement, et aucun
  courriel ne parle d'un visiteur ; mais un lien de réinitialisation de mot de passe finirait dans
  Loki. Ne jamais utiliser « Forgot password » : changer le mot de passe par
  `scripts/goatcounter-init.sh password`, dit dans `OPERATIONS.md`. Tranché à l'étape 1 :
  `goatcounter db update user -password <valeur>` prend la valeur telle quelle, **en argument**,
  visible dans `ps`, sans prompt ; la sous-commande `password` lit donc le mot de passe au prompt du
  script et le passe par `GOATCOUNTER_PASSWORD` (GoatCounter lit chaque option dans
  `GOATCOUNTER_<OPTION>`), transmis par `docker exec -e GOATCOUNTER_PASSWORD`, sans valeur sur la
  ligne de commande.
- **IP réelle** (vérifiée derrière Caddy et un Traefik réglé comme la prod) : GoatCounter
  (`mware.RealIP` de zgo.at/zhttp) prend, dans l'ordre, le premier **public** de `Cf-Connecting-Ip`,
  `Fly-Client-Ip`, `X-Azure-Socketip`, `X-Real-Ip`, puis le dernier saut **public** de
  `X-Forwarded-For`, puis l'adresse de connexion ; aucun réglage de proxy de confiance. Caddy
  remplace le `X-Forwarded-For` du client (vérifié : un `XFF: 9.9.9.9` envoyé devient l'IP du
  client) ; Traefik (`forwardedHeaders.insecure=true`) y ajoute l'IP de Caddy, privée donc sautée,
  et pose `X-Real-Ip` à l'IP de Caddy **sauf si le client en a envoyé un, qu'il garde** (vérifié :
  `X-Real-Ip: 7.7.7.7` arrive tel quel, `Cf-Connecting-Ip` aussi). Sans les quatre lignes vides du
  middleware, un client choisirait son pays et contournerait la limite de 4/s. Avec elles, l'IP lue
  est celle que Caddy a écrite (vérifié : un `X-Forwarded-For` public donne le pays `GB` attendu).
  Elle sert au pays, à la limite de débit et au filtre de robots par plage d'IP, en mémoire : un hit
  attend au plus 10 s (`-store-every`) avant d'être écrit, et l'IP n'est pas une colonne écrite.
- **CSP** : `site-headers` ne restreint ni `script-src` ni `connect-src` aujourd'hui
  (`docker-compose.yml:196-202`). Un appel vers la même origine restera permis par le futur
  `connect-src 'self'` de `SEC-31`.

### 3.2 La base sur le PostgreSQL existant

Le conteneur `postgres` ne crée que `POSTGRES_DB` et n'a aucun script d'init (`:245-250`) ; un
script ne rejouerait de toute façon pas sur le volume de prod. Le rôle et la base se créent donc par
un script idempotent, **`scripts/goatcounter-init.sh`**, en deux sous-commandes :

- **`goatcounter-init.sh db`**, sans interaction :
  1. trouver le postgres de `${ENV_NAME}` par `container_of` (`scripts/_backup_common.sh:111`),
     en Swarm comme en compose ;
  2. créer `ROLE goatcounter` et `DATABASE goatcounter OWNER goatcounter` s'ils n'existent pas, le
     SQL passé **par l'entrée standard** (`docker exec -i … psql`), jamais par
     `-c "… PASSWORD '…'"` : le mot de passe apparaîtrait dans `ps` ;
  3. remettre GoatCounter à 1 réplique (`docker service scale ${ENV_NAME}_goatcounter=1` en Swarm,
     `docker compose up -d goatcounter` sur un poste) et attendre `/status`, donc la migration :
     `serve -automigrate` crée seul le schéma dans une base vide dont le rôle est propriétaire
     (vérifié), sans `-createdb`. Comme `/status` répond avant d'avoir une base (§3.1), attendre
     plutôt la ligne `GoatCounter ready` du journal, ou `goatcounter db test` en `docker exec`.
- **`goatcounter-init.sh site`**, interactif : créer le site s'il n'existe pas,
  `goatcounter db create site -vhost ${GOATCOUNTER_VHOST} -user.email ${GOATCOUNTER_ADMIN_EMAIL}`
  (syntaxe de 2.7 vérifiée ; sans `-user.password`, le mot de passe est **demandé au prompt**, d'où
  `-it`, jamais dans `.env` ; pas de `-createdb`, la base existe), **puis poser les
  réglages du §3.5 aussitôt, par SQL**, avant que le moindre hit n'arrive : le site naît avec les
  sessions **allumées** (vérifié, `collect = 190`), et une session allumée écrit en base, à chaque
  arrêt, les clés brutes « agent utilisateur-IP-site » (§3.5). GoatCounter garde les réglages en
  cache : le script l'arrête (0 réplique), passe le SQL par l'entrée standard, puis le remonte
  (vérifié : la valeur écrite en base est celle lue au démarrage). **Il l'arrête avant de créer le
  site**, pas après (revue de l'étape 1) : après une restauration, `PEDALONS_ANALYTICS_COUNT_PATH`
  est encore posé et des hits arrivent ; un GoatCounter qui sert `/count` entre la création et
  l'arrêt les compterait avec les réglages par défaut, région comprise, gardée 24 mois. Le site est
  donc créé par un conteneur jetable de la même image (`docker run --rm -it`), dans l'espace réseau
  du conteneur postgres (`--network container:<postgres>`, postgres en `127.0.0.1`) : le réseau
  overlay de la pile n'est pas `attachable`, et le rendre tel changerait le réseau de prod (vérifié
  sur une pile jetable : le site est créé, `collect = 190`). Si la création échoue, le script
  remonte GoatCounter et s'arrête :
  `update sites set settings = jsonb_set(jsonb_set(settings, '{collect}', '30'), '{data_retention}', '730')`
  (`settings` est en `jsonb`) et `delete from store where key = 'session'` (les sessions écrites à
  l'arrêt). Le script relit enfin `settings` et échoue si `collect` ou `data_retention` diffèrent ;
  `OPERATIONS.md` dit de vérifier la page *Settings*.

**Premier déploiement** : le service est déployé avant que son rôle existe. GoatCounter redémarre
donc en boucle jusqu'à `goatcounter-init.sh db` ; c'est attendu, inoffensif (`deploy.sh` ne
l'attend pas, §3.8 ; vérifié : il sort aussitôt sur `pq: password authentication failed for user
"…"`, sans écrire le DSN), et c'est l'étape qui y met fin. Puis `goatcounter-init.sh site`. Sur un poste,
les deux étapes ne servent que si le profil `analytics` est démarré (§3.7). Sur staging, elles ne
servent pas : le script s'arrête sans rien faire, avec un message, quand `GOATCOUNTER_VHOST` est vide
(§3.7), ce qui laisse aussi `restore.sh` l'appeler sans condition.

### 3.3 Configuration et clés d'environnement

| Clé | Où | Rôle |
|---|---|---|
| `GOATCOUNTER_DB_PASSWORD` | `.env` de prod, `.env.example` (vide : un gabarit copié tel quel garde la mesure absente, et `deploy.sh` ne le refuse pas) | Mot de passe du rôle `goatcounter`, hexadécimal, passé à GoatCounter par `PGPASSWORD` et jamais dans le DSN (§3.1). Finit aussi dans l'environnement du backend (`env_file`, `:86-87`) : acceptable, le `.env` est sauvegardé chiffré (`backup.sh:117`) |
| `GOATCOUNTER_VHOST` | `.env` de prod, `.env.example` | Le vhost unique du site, cible de la réécriture de `Host` et règle du routeur du tableau de bord |
| `GOATCOUNTER_ADMIN_EMAIL` | `.env` de prod, `.env.example` | Le compte du tableau de bord, créé par `goatcounter-init.sh site` (son mot de passe est saisi au prompt) |
| `PEDALONS_ANALYTICS_COUNT_PATH` → `pedalons.analytics.count-path` | `.env` de prod seulement | Absent = compteur coupé. Lu par le backend, exposé dans `/api/config` (`API-117`) |

Aucun port publié, donc aucune clé de port (§3.6). Le `.env` de staging n'en pose aucune : la
mesure ne tourne qu'en prod (décision du §7). `deploy.sh` refuse que `GOATCOUNTER_VHOST` et
`GOATCOUNTER_DB_PASSWORD` soient l'une posée et l'autre vide, et `PEDALONS_ANALYTICS_COUNT_PATH`
sans elles (§3.1).

Le frontend ne reçoit aucune variable propre (seulement `API_BASE_URL`, `:170-175`) : le drapeau
passe par `/api/config`, sur le modèle de `webPush` (`ConfigService.java:37-48`, `Optional<String>`,
« null quand le déploiement ne le configure pas »). `ConfigDto` gagne un champ nullable
`analytics: { countPath: string } | null`. Changement de contrat **mineur**, avec bump de
`pedalons.api.version` et la compétence `contract-first-api`. Le mobile ignore le champ.

Un drapeau par domaine (pour couper la mesure d'un club) n'est **pas** prévu, pas avant qu'un club
le demande (décision du §7 ; `API-116`).

### 3.4 Sauvegarde et restauration

C'est le point qui casse si on l'oublie : `backup.sh` ne dumpe que `POSTGRES_DB`
(`scripts/backup.sh:102-105`), et `restore.sh` **efface le volume postgres** puis ne restaure que
`POSTGRES_DB` (`scripts/restore.sh:201`, `:236-240`). Surtout, `restore.sh` fait un
`docker stack rm` puis `deploy.sh --hold-app` (`restore.sh:194-210`), qui ne garde à 0 que backend
et frontend (`deploy.sh:160`) : sans changement, GoatCounter revient tout de suite à 1 réplique sur
un postgres vide et redémarre en boucle.

**Décision (15 octobre 2026, §7) : statistiques jetables, non sauvegardées.** Elles ne sont pas des données de
membres, leur perte n'empêche rien, et elles ne justifient pas d'alourdir la sauvegarde, son
MANIFEST et ses `SHA256SUMS`. En contrepartie :

- l'overlay `--hold-app` de `deploy.sh` (`:160`) garde aussi `goatcounter` à 0 ;
- `restore.sh`, après `pg_restore` et avant de remonter backend et frontend (`:253-261`), appelle
  `scripts/goatcounter-init.sh db`, qui recrée le rôle et la base vide et remonte GoatCounter (et ne
  fait rien sur un environnement sans GoatCounter, §3.2) ;
- `restore.sh` finit en rappelant l'étape interactive `goatcounter-init.sh site` (le site et son
  compte ont disparu avec la base) ; d'ici là, GoatCounter refuse les hits, sans conséquence ;
- `docs/OPERATIONS.md` le dit dans la table du snapshot (`:667`) : « la base `goatcounter` n'est pas
  sauvegardée » ; la politique aussi (§5.2, §6 « Sauvegardes »).

Un second `pg_dump` chiffré (`goatcounter.dump.age`, dans le MANIFEST et les `SHA256SUMS`) n'est pas
fait. S'il le devenait un jour, la phrase de la politique sur les sauvegardes serait à réécrire dans
le même commit.

### 3.5 Réglages du site GoatCounter

Posés par SQL par `goatcounter-init.sh site` (§3.2), vérifiables dans *Settings*, et à reporter
dans `docs/OPERATIONS.md` sous leurs noms de la 2.7 (vérifiés sur la page) :

- **Collecte** (*Data collection*, champ `settings.collect`, un masque de bits) : cocher **Referrer**
  (2), **User-Agent** (4, « Browser and system name derived from the User-Agent header (the header
  itself is not stored) »), **Size** (8) et **Country** (16), soit `collect = 30`. Décocher
  **Sessions** (128), **Region** (32), et laisser décochés **Language** (64, lu dans
  `Accept-Language`) et **Individual pageviews** (256). Le défaut d'un site neuf est `190` : sessions
  et région allumées (vérifié).
  - **Sessions** : coupées, ni suivi d'un site de club à l'autre (§5.1, condition 3), ni empreinte
    de session (§4.5). C'est **un blocage levé, pas un détail** : allumées, GoatCounter garde en
    mémoire la clé `<agent utilisateur>-<IP>-<site>` 8 heures et **l'écrit en clair dans la table
    `store` à chaque arrêt** (`Memstore.StoreSessions`, vérifié :
    `Mozilla/5.0 … Firefox/140.0-81.2.69.142-1`). Coupées, rien n'est calculé, et `store` ne garde
    que `{"sessions":{},"hashes":{},"paths":{},"seen":{}}` (vérifié après un arrêt).
  - **Individual pageviews** : coupé (le défaut), **la table `hits` reste vide** (vérifié : 0 ligne
    après les hits de test) et seuls les agrégats sont écrits (`hit_counts` et `ref_counts` par
    heure, `hit_stats`, `browser_stats`, `system_stats`, `location_stats`, `size_stats` par jour,
    chacun par chemin). Le tableau de bord n'en dépend pas (« This doesn't affect anything else »).
    C'est un **changement de conception** par rapport à la première version : aucune ligne ne réunit
    plus le navigateur, le système, l'écran et le pays d'une même page vue (§4.5).
  - **Country** : déduit **sur place**, par la base **GeoLite2-Country intégrée au binaire**
    (`pkg/geo`, `//go:embed`, construite le 20 mai 2025 dans la 2.7.0 ; vérifié au démarrage et par
    un hit dont l'IP donne `GB`), sans service tiers ni téléchargement : `-geodb` n'est pas posé, et
    le répertoire de données est un `tmpfs` vide (§3.1). Une base de pays ne contient pas de régions :
    la case *Region* est décochée quand même, pour qu'un `-geodb` ajouté plus tard n'en collecte pas.
  - **Referrer** : couvre le paramètre `r` et les paramètres de campagne de `q` ; le site n'envoie
    jamais `q` (§4.3).
- **Tableau de bord public** : *Dashboard viewable by* = **Only logged in users** (`settings.public =
  private`), le défaut (vérifié ; un visiteur non connecté est renvoyé vers `/user/new`).
  *Allow adding visitor counts on your website* (`allow_counter`) reste décoché, le défaut.
- **Jetons d'API** : aucun.
- **Rétention des données** : *Data retention in days* = **730** (`settings.data_retention`, borné à
  31…1825 ; 0 par défaut, c'est-à-dire jamais). Vérifié dans le code (`Site.DeleteOlderThan`) : la
  purge efface **aussi les tables agrégées** (`hit_stats`, `system_stats`, `browser_stats`,
  `location_stats`, `language_stats`, `size_stats`, `campaign_stats` par jour, `hit_counts`,
  `ref_counts` par heure), `hits`, puis les `paths` qui ne servent plus : aucune purge à écrire.
  **Non exécutée sur le poste** : la tâche tourne une fois par jour, **24 h (± 15 min) après le
  démarrage**, puis toutes les 24 h, et son minuteur repart à chaque redémarrage. Un GoatCounter
  redémarré tous les jours ne purgerait jamais ; à surveiller (`select min(day) from hit_stats`)
  dans `OPERATIONS.md`. La table `bots` (chemin et agent utilisateur **brut** des robots détectés,
  sans IP) est purgée à 30 jours par une autre tâche (`oldBot`).
- **Accès au tableau de bord** : un seul compte, celui du responsable du traitement.

### 3.6 Accès au tableau de bord

Seule la prod a un tableau de bord (§3.7) ; seul le responsable du traitement y accède, par tunnel
(décision du §7 ; des statistiques pour les admins de club sont écartées, `WEB-91`). Aucun port
publié : prod et staging tournent sur le même hôte (`TRAEFIK_PORTS="8089 8090"`,
`scripts/pedalons-firewall.sh:19`), un port fixe entrerait en conflit, et `MONITORING_PORTS`
(`:22`, `3300` par défaut) resterait à tenir à jour. Le tableau de bord passe donc par le Traefik de
l'environnement, sur le routeur `goatcounter-dash` (`Host(GOATCOUNTER_VHOST)`, §3.1) :

```bash
ssh -L 8090:127.0.0.1:8090 <host>          # HTTP_PORT de la prod ; staging (8089) n'a pas de GoatCounter
# puis, dans /etc/hosts du poste : 127.0.0.1 stats.pedalons.internal
# et http://stats.pedalons.internal:8090 — le port est retiré avant la recherche du site (vérifié)
```

Rien n'y arrive d'Internet : `HTTP_PORT` est déjà fermé par le pare-feu (`docs/OPERATIONS.md:178-192`),
et Caddy n'a aucun bloc pour ce nom. Le pare-feu reste inchangé. Vérifier depuis une autre machine
qu'une requête par Caddy avec `Host: <vhost>` n'atteint pas le tableau de bord.

Vérifié sur le poste, par le routeur `Host()` de Traefik avec `Host: stats.pedalons.internal:8090`
(ce que le tunnel envoie) : la page de connexion répond, la connexion par e-mail et mot de passe pose
le cookie `key` en `HttpOnly; SameSite=Lax`, **sans `Secure`** (GoatCounter ne le met que si la
requête est en TLS ou porte `X-Forwarded-Proto: https`, et Traefik pose `http` sur ce chemin), et le
tableau de bord s'affiche ensuite avec les chemins comptés. L'en-tête HSTS que GoatCounter envoie
sur le tableau de bord est ignoré par les navigateurs en `http://`. Le passage par le vrai tunnel
`ssh -L` n'a pas été fait (il faut l'hôte) : il est à l'étape 5.

### 3.7 Postes de travail et pile e2e : coupés par défaut

- **Pile e2e** : `scripts/e2e.sh` charge `docker-compose.yml` + `docker-compose.e2e.yml` (fonction
  `compose()`, `:25-28`) avec `--profile app` (`:93`). Un service ajouté au fichier de déploiement y
  démarrerait aussi : `docker-compose.e2e.yml` lui donne `profiles: [analytics]`, un profil que
  `e2e.sh` n'active jamais. `.env.e2e` ne définit pas `PEDALONS_ANALYTICS_COUNT_PATH` :
  `/api/config` rend `analytics: null`, le site ne compte rien.
- **Poste de travail** : `docker-compose.local.yml` met `goatcounter` derrière
  `profiles: [analytics]`, qui ne démarre qu'à la demande. Le `.env` local ne définit pas
  `PEDALONS_ANALYTICS_COUNT_PATH`. Le `%dev` de `application.properties` le laisse vide. En dev
  (`pnpm dev`), `server.js` ne relaie que `/api` (`:71-93`) : le compteur reste coupé tant que le
  drapeau l'est, rien n'aboutit dans le fourre-tout SSR.
- **Staging** : **aucune mesure** (décision du §7 : prod seulement). Même `docker-compose.yml` que
  la prod, donc pas de `profiles:` pour l'écarter (`docker stack deploy` les refuse) : le `.env` de
  staging ne pose ni `GOATCOUNTER_*` ni `PEDALONS_ANALYTICS_COUNT_PATH`, et `deploy.sh`, voyant les
  deux clés vides, ajoute `goatcounter: deploy: replicas: 0` à son overlay (le même fichier que
  `--hold-app`, `deploy.sh:157-161`). Le service est déclaré mais sans tâche, sa base n'est jamais
  créée (`goatcounter-init.sh` ne fait rien, §3.2), `/api/config` rend `analytics: null` et le site
  ne compte rien. **Un service sans tâche ne monte aucun routeur dans Traefik** : le provider Swarm
  ne lit les labels qu'à travers les tâches en cours (`listTasks` de
  `pkg/provider/docker/pswarm.go`, v3.7, saute toute tâche qui n'est pas `running` ; seul
  `traefik.docker.lbswarm=true`, que la pile n'utilise pas, lirait le service lui-même). Lu dans le
  code de Traefik, pas exécuté : une pile Swarm ne peut pas être déployée sur le poste. Ni
  `goatcounter-count`, ni `goatcounter-dash` (et son `Host(``)` vide), ni le middleware n'existent
  donc sur staging ; un `/count` y tombe dans le routeur `frontend` (`PathPrefix(/)`, priorité 1),
  qui rend la page 404 du site, sans effet puisque le site n'appelle rien. À constater à l'étape 5
  (aucune erreur `goatcounter` dans le journal du Traefik de staging). Le snippet Caddy partagé
  garde son `log_skip` pour les blocs `staging.*`, inoffensif.

### 3.8 Mémoire et déploiement

- Une ligne au tableau mémoire de `docs/OPERATIONS.md` (`:106-117`) et la somme par environnement
  refaite (« 7.3 GB », `:136-143`). Mesuré sur le poste : 36 à 40 Mio au repos, après une trentaine
  de hits ; la limite de 128 Mo laisse la marge des exports CSV et du tableau de bord.
- `deploy.sh` n'attend que backend et frontend (`:170`, `:223`, `:245`) : un GoatCounter qui ne
  démarre pas ne fait pas échouer un déploiement. C'est voulu (il n'est pas sur le chemin critique,
  et il boucle au premier déploiement, §3.2), et écrit dans `OPERATIONS.md`.
- `deploy.sh` ne vérifie que les images `pedalons-*` (`:146-147`) : l'image amont est tirée du
  registre par `docker stack deploy`, rien à changer dans `build.sh`. En revanche, il gagne la
  vérification des clés (§3.1), `goatcounter` dans l'overlay `--hold-app` (§3.4) et le même overlay,
  à 0 réplique, quand les deux clés sont vides (staging, §3.7). La ligne mémoire ne compte que pour la
  prod.

### 3.9 Journal Caddy : `/count` n'y est pas écrit

Écrire `/count` dans le journal d'accès de Caddy garderait, pour chaque page vue, l'IP, l'agent
utilisateur, l'heure, l'hôte et le gabarit : 14 jours sur l'hôte, puis 14 jours dans Loki, soit
l'historique de navigation de chaque IP, navigations côté client comprises. Filtrer `r` ou `p` n'y
changerait rien. **La requête de mesure n'est donc pas journalisée du tout** : le snippet
`pedalons_access_log` (`docs/OPERATIONS.md:264-290`), importé par chaque bloc de site, gagne

```caddyfile
	@count path /count
	log_skip @count
```

(`log_skip` depuis Caddy 2.8, `skip_log` avant). Vérifié sur Caddy 2.11.4 avec ce snippet importé :
`/count` n'est pas écrit, une autre requête du même bloc l'est. **La version de Caddy de l'hôte
reste à lire** (`caddy version`, étape 5) : elle n'est ni dans le dépôt ni joignable d'un poste. C'est
documenté dans la section « Access logs » d'`OPERATIONS.md`, avec un piège de plus : un bloc de
club qui n'importe pas le snippet journaliserait `/count` en clair. Le snippet vit hors dépôt et se
modifie à la main sur l'hôte ; l'étape 6 vérifie qu'aucune ligne `/count` n'apparaît.

---

## 4. Conception côté site (`WEB-90`)

### 4.1 Où compter

Dans **`getRouter()`** (`frontend/src/App.tsx:34-46`, à côté de `installPrefetchAudit`), par
`router.subscribe`. Trois raisons :

- c'est le seul endroit qui voit **toutes** les routes, y compris les trois `layout: 'bare'`
  rendues hors `<Layout>` (`gpx-tools-map`, `stage-map`, `route-map`), que l'effet de navigation de
  `Layout.tsx:77-80` ne voit pas ;
- il ne s'exécute qu'au client (`App.tsx:29-33` lève en SSR), et ne rend rien : aucun risque
  d'hydratation (`docs/SSR.md`, Findings 3 à 5) ;
- il est hors de React, donc pas doublé par `StrictMode` (`entry-client.tsx:89`).

Règles :

- **Première page vue** : la configuration est déjà amorcée (`seedAppConfig` s'exécute avant le
  premier rendu, `entry-client.tsx:72-79`, donc avant `getRouter()`). Avec `hydrationData` (le cas
  SSR), le routeur naît initialisé et `router.subscribe` ne se déclenche pas pour l'état de
  départ : on compte `router.state` **à la création**. Sans SSR, on attend
  `state.initialized`. Sans compteur automatique, c'est elle qui serait perdue.
- **Navigations** : on compte quand `state.navigation.state === 'idle'` et que
  `state.location.key` a changé. On compte une navigation `PUSH` ou `POP` ; une `REPLACE` seulement
  si le `routeId` change. Les changements de filtres (`useUrlFilters`, `Layout.tsx:84-89`) passent
  par `REPLACE` sur la même route et ne sont pas comptés. Les redirections de loaders
  (`RouteGenerator.tsx:44-49`) et les redirections héritées (`teamLegacyRedirects.ts`) comptent la
  page d'arrivée, une fois. React Router enregistre une navigation redirigée par un `replace()` de
  loader comme une `REPLACE`, y compris vers la route d'où l'on vient (fiche de la sortie A → groupe
  de la sortie B → `rideGroupDataRedirect` → fiche de la sortie B) : le compteur la reconnaît à ce
  qu'elle arrive ailleurs que le chemin visé quand la navigation a quitté `idle`, et la compte comme
  le `PUSH` qu'elle est ; un filtre ou une réécriture de `useCanonicalPath` arrive où il visait
  (revue de l'étape 3).
- **Redirections rendues par un composant** : une route masquée (`hideWhenSingleTeam`) n'a pas de
  `handle` et rend `<Navigate replace>` vers l'accueil (`RouteGenerator.tsx:60-64`, `:87-89`) ;
  une route `authenticated` visitée sans session rend `<Navigate … replace>` vers la connexion
  (`ProtectedRoute.tsx:27`). Toutes deux valident d'abord une navigation. D'où trois règles :
  - **un match sans `routeId` est ignoré** (route masquée) ;
  - **`/404` n'est compté que pour la route `*`**, qui reçoit un
    `handle: { routeId: 'not-found' }` (`RouteGenerator.tsx:132`) ;
  - **l'envoi est différé d'un court délai** (100 ms) : une `REPLACE`
    survenue entre-temps remplace le hit en attente au lieu d'en ajouter un ; toute autre page vue
    survenue entre-temps envoie aussitôt le hit en attente, puis attend son propre délai entier (un
    par `PUSH`). Le cas résiduel (vérification de session plus longue que le délai) donne au plus un
    hit de trop, accepté.
- **Dédoublonnage** par `location.key`.

### 4.2 Ce qui est envoyé

Une fonction pure, **`toCountHit(state, host, referrer, isFirst)`**, testée isolément. Elle part du
dernier match (`state.matches.at(-1)`), de son `handle.routeId` (`RouteGenerator.tsx:87-89`) et de
son seul paramètre `teamSlug`, **jamais** de `location.pathname`, `location.search`,
`location.hash` ni `window.location`.

| Paramètre | Valeur | Ce qu'il ne contient jamais |
|---|---|---|
| `p` (chemin) | `/<hôte>` + le gabarit canonique de la route, `routeById.get(routeId).paths.fr` (`routeUtils.ts:7-9`), où **le seul segment `:teamSlug` est remplacé par le slug de l'équipe** (règle ci-dessous), les autres paramètres restant des marqueurs : `/club-exemple.fr/outils-gpx/:previewId`, `/pedalons.fr/equipes/n-peloton/sorties/:rideSlug`. Pour la route `*` (`routeId: 'not-found'`) : `/<hôte>/404` | Un identifiant (`previewId`, `groupId`), un autre slug (`rideSlug`, `routeSlug`, `tripSlug`, `stageSlug`, `postSlug`, `pageSlug`, `adSlug`, `templateSlug`), un `teamSlug` mal formé, une query string (`?token=`, `?request=`, `?code=`, `?next=`), un fragment |
| `t` (titre) | `routeId` et la propriété **statique** `auth` de la route (`routes.types.ts:10`) : `ride-detail · public` ou `ride-detail · authenticated` | `document.title`, que `Layout.tsx:91-95` remplit avec le nom d'une sortie, d'une page ou d'une équipe privée (`Team.visibility = TEAM` par défaut) ; l'état de connexion du visiteur |
| `r` (référent) | L'**origine** de `document.referrer` (`new URL(…).origin`, schéma et hôte) si son hôte est externe, **pour la première page vue du chargement seulement** ; absent ensuite : `document.referrer` ne change pas pendant une navigation côté client, et le republier à chaque page fausserait les chiffres et tracerait le parcours depuis la source. L'origine plutôt que l'hôte nu : avec le schéma, GoatCounter reconnaît le référent comme un lien et regroupe les moteurs (vérifié : `r=https://www.google.fr` est rangé sous « Google », `r=https://lemonde.fr` sous `lemonde.fr` ; un hôte nu reste en texte brut, sans regroupement). Il retire lui-même le schéma | Une URL complète : avec `strict-origin-when-cross-origin`, une navigation interne donne l'URL entière, requête comprise. GoatCounter ne remplace jamais un `r` absent par l'en-tête `Referer` (vérifié, §3.1) |
| `s` (écran) | La **catégorie** de `screen.width`, envoyée comme la borne haute de sa tranche dans le tableau de bord de GoatCounter (`HitStats.ListSizes` de la v2.7.0, lu dans le code : téléphone ≤ 600, tablette ≤ 1000, ordinateur ≤ 1920, au-delà grand écran) : `600`, `1000`, `1920` ou `2560` (`screenSizeCategory` de `sender.ts`). Le tableau de bord affiche la même chose qu'avec la largeur exacte, et `size_stats.width` ne garde plus que quatre valeurs (§5.1, ligne 2). GoatCounter garde la première valeur d'une liste séparée par des virgules (vérifié : `s=390`) ; le paramètre `width` du décodeur est ignoré quand `s` est là | La largeur exacte de l'écran |
| `rnd` | Cinq caractères aléatoires, contre les caches qui ignorent `Cache-Control` (comme `count.js`) ; non stocké | — |

**Ni `b` ni `q`, ni `e`.** `b` (robot) n'est pas envoyé : l'expéditeur n'envoie rien du tout quand
`navigator.webdriver` est vrai (§4.3), et GoatCounter n'accepte de toute façon que `b` absent, `0` ou
≥ 150 (`b=1` répond `400 wrong value`, vérifié) ; un `b ≥ 150` range le hit dans la table `bots` avec
l'agent utilisateur **brut** (vérifié). `q` est la requête de la page : GoatCounter en tire un
référent de campagne (`utm_source`, `ref`, `src`, `source`) et crée une campagne (`utm_campaign`,
`campaign`) — vérifié : `q=?utm_source=newsletter&token=SECRET` a créé le référent `newsletter`. Il
porterait la query string, ce que la règle du §4.2 interdit. `e` (événement) est hors périmètre
(§1). GoatCounter retire la barre oblique finale du chemin (`/club-b.fr/` devient `/club-b.fr`,
vérifié) ; `p` est limité à 2048 octets, `t` à 1024, un `p` vide est refusé en `400`.

Le gabarit est pris en français, une seule forme par écran quelle que soit la langue de l'URL.
L'hôte est celui que voit le navigateur (`location.host`), ce qui distingue chaque domaine et
chaque alias.

**Le slug d'équipe, pour toutes les équipes** (décision du 15 octobre 2026, §7) : sur un hôte
partagé comme `pedalons.fr`, l'hôte seul ne dit pas quelle équipe est visitée. Toutes les routes
d'équipe déclarent leur équipe par le même paramètre, `:teamSlug`, en tête de chemin
(`/equipes/:teamSlug/…`, `pathVariants.*(':teamSlug', …)` dans `routes.config.ts`), et c'est le
seul paramètre substitué. La règle, dans `toCountHit` :

- la valeur vient de `match.params.teamSlug` du dernier match, celle que le routeur a résolue,
  jamais d'un découpage de l'URL ;
- elle n'est gardée que si elle a la forme d'un slug, `^[a-z0-9]+(-[a-z0-9]+)*$` et au plus
  200 caractères (`SlugService.PATTERN_VALID_SLUG` et `MAX_SLUG_LENGTH`, ceux que le backend impose
  à tout slug) ; sinon le segment reste `:teamSlug`. Une URL tapée ou collée avec autre chose à
  cette place (un jeton, une adresse, des majuscules, un `%`) ne part donc jamais ;
- la substitution porte sur le segment entier égal à `:teamSlug` dans `paths.fr`, une fois ; un
  slug bien formé mais sans équipe (page 404 de l'équipe) part tel quel, accepté ;
- **visibilité ignorée** : le slug part pour une équipe `PUBLIC` comme pour une équipe privée
  (`Team.visibility = TEAM` par défaut). Le site ne connaît pas toujours la visibilité au moment du
  comptage, et la condition aurait rendu les chiffres incomparables d'une équipe à l'autre ;
- **sur un hôte épinglé**, le navigateur affiche `/sorties/x` mais le routeur travaille sur
  `/equipes/<slug>/…` (`pinnedHistory.ts:1-12`) : `match.params.teamSlug` y porte donc le slug
  épinglé et le chemin compté est le même que sur l'hôte partagé, à l'hôte près. Les pages
  globales d'un hôte épinglé (connexion, profil, outils GPX) n'ont pas de `:teamSlug` et restent
  des gabarits.

Conséquences, assumées : les slugs des équipes privées, qui sont en général le nom du club,
**entrent dans la base `goatcounter`**. Ce n'est pas une donnée personnelle sur les membres (le nom
d'une association, pas d'une personne, et rien n'y relie un visiteur), mais la politique doit dire
que le chemin compté contient l'identifiant de l'équipe (§5.2). Une équipe dont le slug change
(`TeamService.updateSlug`) voit son historique coupé en deux chemins, sans regroupement
rétroactif. Les autres slugs (sortie, parcours, page) restent des marqueurs : ils nommeraient un
objet, et pour un contenu `PUBLIC_UNLISTED` ils sont une partie de l'URL-capacité.

Ne pas marquer une page vue « connecté » d'après la session est voulu : sur un petit domaine de
club, ce marqueur croisé avec le pays, l'écran et le navigateur désignerait un groupe de quelques
membres. La propriété de la route répond à la question 5 du §1 sans rien dire du visiteur.

Ces règles couvrent les URL-capacités : `/outils-gpx/{previewId}` (accessible à quiconque a le lien,
`privacy-policy.fr.md:216`), les contenus `PUBLIC_UNLISTED` (dont le slug de l'objet n'est jamais
envoyé ; le slug de l'équipe seul ne donne accès à rien), les jetons d'invitation, de vérification
et de réinitialisation, l'appairage d'appareil. Aucun n'atteint GoatCounter, ni dans les
paramètres, ni dans un en-tête (§4.3).

### 4.3 L'expéditeur

Un module **`frontend/src/lib/analytics/`** d'une trentaine de lignes, sans le `count.js` de
GoatCounter : pas de global `window.goatcounter`, pas de chargement de script, pas de compteur
automatique à désactiver, pas de licence à vérifier, et un test qui voit exactement ce qui part. Il
envoie `GET <countPath>?p=…&t=…&r=…&s=…&rnd=…` (vérifié : `/count` accepte un `GET` sans le script,
avec ces noms de paramètres, décodés par `formam` sur les balises JSON de `goatcounter.Hit`, les
inconnus ignorés ; il répond `200` et un GIF, ou `400` avec la raison dans `X-Goatcounter`) par

```ts
fetch(url, { keepalive: true, credentials: 'omit', referrerPolicy: 'no-referrer', cache: 'no-store' })
```

**Jamais par `navigator.sendBeacon`** : il fait toujours un `POST`, envoie toujours les cookies
(dont `refresh_token`, `Path=/`) et un `Referer`, qui en même origine est l'URL entière de la page
— la règle « gabarit et slug d'équipe seulement » du §4.2 serait contournée par l'en-tête lui-même. Le middleware
Traefik retire de toute façon `Cookie` et `Referer` (§3.1). Passer à Umami ne changerait que ce
module.

**Import sans effet** : `lib/analytics` est importé par `App.tsx`, qui fait partie du bundle SSR. Le
module ne touche ni `window`, ni `navigator`, ni `localStorage`, ni `document` au moment de
l'import : seulement dans les fonctions appelées depuis `getRouter()`.

L'expéditeur **n'envoie rien** quand :

- `getAppConfig().analytics` est `null` (e2e, poste de travail, déploiement non configuré) ;
- **Do Not Track** (`navigator.doNotTrack === '1'`) ou **Global Privacy Control**
  (`navigator.globalPrivacyControl === true`) est actif : c'est le mécanisme d'opposition par
  défaut, sans rien demander, et **le seul qui vaille pour tous les sites de club à la fois** ;
- l'opposition locale est posée (§4.4), relue à chaque envoi ;
- le navigateur est piloté (`navigator.webdriver`), ou la page est en prérendu
  (`document.prerendering`) ;
- l'hôte est `localhost` ou une IP de bouclage.

Côté serveur, GoatCounter écarte en plus les robots (bibliothèque `zgo.at/isbot`, vérifié) : d'après
l'agent utilisateur (`curl/8` est rangé en robot), les plages d'IP connues des robots, et les
en-têtes de préchargement (`Purpose: prefetch`, `X-Moz: prefetch`…), ignorés sans rien écrire. Un
robot ne compte pas, mais sa ligne va dans la table `bots` (chemin, agent utilisateur brut, sans IP)
pour 30 jours (§3.5).

### 4.4 L'opposition

La CNIL demande un droit d'opposition facile à exercer. En plus de DNT et GPC :

- un **interrupteur** « Mesure d'audience du site » dans `/profil/vie-privee` (route
  `profile-privacy`, `profilePrivacy` dans `contracts/routes.yaml`, écran « Profil →
  Confidentialité », `profile.nav.privacy`) pour un membre connecté ;
- le **même interrupteur sur la page `/confidentialite`**, pour un visiteur sans compte, qui est le
  cas le plus fréquent sur les pages publiques. Il est rendu **par `PrivacyPolicyPage.tsx`, hors du
  Markdown** (un encadré au-dessus du texte de la politique, avec l'ancre `#mesure-audience`), pas
  dans `LegalPage.tsx` : celle-ci sert aussi les CGU et le support et rend le Markdown d'un bloc par
  `MarkdownDisplay`, et ce Markdown est aussi un asset de l'app mobile, où un marqueur inséré
  apparaîtrait tel quel. La page est publique, donc rendue côté serveur : l'état est lu par
  `useSyncExternalStore` avec un `getServerSnapshot` neutre (ou dans un effet), jamais au rendu
  serveur, sous peine de casser l'hydratation.

Il pose une clé de stockage local, **`pedalons-analytics-optout`** (lue et écrite dans un
`try/catch`). Elle n'est **pas** enregistrée sur le compte : ce serait relier la mesure à une
personne, ce que l'exemption interdit. Conséquence à dire partout : **elle ne vaut que pour ce
navigateur et pour ce site** (une clé `localStorage` est propre à une origine). Chaque domaine de
club, chaque `DomainAlias` et `www.pedalons.fr` demandent leur propre opposition, sur chaque
navigateur. Le libellé de l'interrupteur le dit (« sur ce navigateur et pour ce site uniquement »),
pour qu'il ne passe pas pour un réglage du compte, et renvoie à DNT et GPC comme seul moyen global.
La clé figure dans la liste du §8 de la politique. Côté mobile, rien : l'app ne mesure pas, et son
écran Confidentialité n'a pas d'interrupteur.

### 4.5 Ce qui est stocké, et combien de temps

Vérifié dans la base de la pile jetable (§9), avec les réglages du §3.5 (*Individual pageviews*
coupé) : **aucune ligne par page vue**. GoatCounter écrit, pour chaque chemin, des **compteurs** :
`hit_counts` (pages vues par heure), `ref_counts` (par heure et par référent), et par jour
`hit_stats`, `browser_stats` (famille et version majeure du navigateur, `Firefox 140`),
`system_stats` (`Linux`), `size_stats` (largeur d'écran), `location_stats` (pays). Les tables de
référence gardent le chemin et le titre envoyés (`paths` : un hôte, un gabarit, le slug de l'équipe
pour une page d'équipe, un `routeId` et la propriété `auth` de la route) et les référents (`refs` :
un hôte ou un groupe, « Google »). **L'IP et l'agent utilisateur bruts ne sont pas stockés** (ni
colonne, ni table, vérifié), sauf l'agent utilisateur des robots détectés, 30 jours dans `bots`
(§4.3). Chaque dimension est comptée **à part** : rien ne dit quel navigateur avait quelle largeur
d'écran ni quel pays.

**La session** : la colonne `hits.session` existe (`bytea`, nullable, vérifié par `\d hits`), mais
la table `hits` reste vide, *Individual pageviews* coupé. Même allumé, une session coupée y écrit
16 octets nuls, la même valeur pour toutes les lignes (vérifié : `count(distinct session) = 1`) :
rien ne relie deux pages vues. **Aucune purge nocturne n'est donc à poser.** Le vrai risque des
sessions était ailleurs, dans la table `store` (§3.5) ; il disparaît avec elles.

**Le slug d'équipe** (§4.2) ajoute une dimension à chaque compteur : sur les pages réservées aux
membres d'une petite équipe privée, une page vue vient presque sûrement de l'un de ses quelques
membres, et le compteur horaire dit à quelle heure. Sans ligne par page vue, le navigateur, l'écran
et le pays de cette page vue ne sont pas reliés entre eux, mais sur un chemin qui ne compte qu'une
vue dans la journée, chaque compteur journalier en donne un : c'est accepté parce que rien ne relie
deux pages vues et que seul le responsable du traitement lit la base ; c'est une raison de plus de
ne pas ouvrir le tableau de bord aux admins de club (`WEB-91`), qui connaissent leurs membres.

Rétention : 24 mois, tables agrégées comprises (§3.5). Pas de sauvegarde (§3.4).

---

## 5. Juridique (`LEGAL-19`)

### 5.1 Conditions d'exemption de la CNIL, et comment chacune est remplie

Sources, **relues sur cnil.fr le 15 octobre 2026** (étape 4) :

- les **lignes directrices** « cookies et autres traceurs » (délibération n° 2020-091 du 17 septembre
  2020), art. 5, points 50 à 52 : les **conditions** de l'exemption (art. 82 de la loi Informatique
  et Libertés) — finalité limitée à la seule mesure d'audience, pour le compte exclusif de
  l'éditeur ; pas de suivi global de la navigation d'un site ou d'une application à l'autre ;
  statistiques anonymes seulement ; pas de recoupement avec d'autres traitements ni de transmission
  à des tiers ; et le RGPD reste applicable au traitement (point 52) ;
- la **recommandation** du même jour (délibération n° 2020-092), point 50 : des
  **recommandations**, pas des conditions — informer les personnes (par exemple dans la politique de
  confidentialité), des traceurs d'au plus 13 mois non prorogés à chaque visite, des données gardées
  au plus 25 mois, et ces durées réexaminées périodiquement ;
- la page « Cookies : solutions pour les outils de mesure d'audience » (datée du 4 juillet 2025) :
  **elle ne donne plus de liste d'outils exemptables** (la mention d'une liste, dans la première
  version de ce plan, est périmée) ; elle renvoie à un **outil d'auto-évaluation** (juillet 2025) à
  l'usage des fournisseurs, dont les critères sont des conditions suffisantes et dont les « mesures
  techniques » sont des recommandations, une mesure différente restant admise si son analyse est
  documentée. C'est à l'éditeur de pouvoir justifier le respect du cadre ; une auto-évaluation
  n'engage pas la CNIL. Ici l'éditeur héberge lui-même l'outil : les critères propres à la
  sous-traitance (DPA, pas de mise en commun entre clients, pas de réutilisation par le
  prestataire) sont sans objet. La démonstration est ce tableau, à tenir à jour.

| # | Condition (source) | Comment elle est remplie |
|---|---|---|
| 1 | Finalité limitée à la mesure d'audience, pour le seul éditeur (LD 51) ; au plus trois types d'événements : présence sur une page, usage d'une fonctionnalité, temps de chargement ou de lecture (auto-évaluation) | Instance auto-hébergée, un seul compte, celui du responsable du traitement ; tableau de bord public désactivé, aucun jeton d'API (§3.5) ; aucun usage hors des cinq questions du §1 ; **des pages vues seulement**, aucun événement (§1, `e` jamais envoyé, §4.2). Des chiffres **par équipe** (§4.2) restent une mesure d'audience du service pour son éditeur : savoir quels sites et quelles équipes la plateforme sert. Les communiquer aux clubs serait une autre affaire (une finalité pour un tiers, à relire contre cette condition) : écarté, `WEB-91` |
| 2 | Données minimisées : en-têtes HTTP réduits (version majeure du navigateur et du système, par exemple), ni identifiant client, ni UTM, ni identifiant de campagne dans les URL, référent limité à l'hôte (auto-évaluation) | Navigateur en famille et version majeure (`Firefox 140`), système en nom (`Linux`), langue non collectée (§3.5) ; `q` jamais envoyé, aucune query string dans `p` (§4.2) ; `r` réduit à l'origine, que GoatCounter réduit à l'hôte (§4.2). Largeur d'écran réduite à sa catégorie (§4.2) : **tranché à l'étape 3** (`WEB-90`), l'expéditeur envoie la borne haute de la tranche du tableau de bord de GoatCounter (`600`, `1000`, `1920`, `2560`, lues dans `HitStats.ListSizes` de la v2.7.0), non plus `Math.round(screen.width)` ; la question 4 du §1 ne demande que « téléphone ou bureau » |
| 3 | Pas de suivi d'un site ou d'une application à l'autre (LD 51) ; aucun identifiant permettant un suivi à travers plusieurs domaines, une empreinte devant intégrer une composante propre au site et une composante temporelle (auto-évaluation) | **Sessions coupées**, donc **aucun identifiant du tout**, ni cookie ni empreinte : un site GoatCounter unique pour tous les domaines de club ne relie donc pas la navigation d'un site de club à l'autre (avec les sessions, la clé `agent utilisateur-IP-site` d'un site unique serait justement l'identifiant multi-domaines que le critère exclut) ; une instance à nous, aucun tiers ; l'app mobile ne mesure pas. Même constat pour Umami (§2) |
| 4 | Pas de recoupement avec d'autres traitements, pas de transmission à des tiers (LD 51) ; pas d'import de données externes, pas d'intégration d'outils tiers, aucun marquage qui récupère des informations personnelles, des formulaires par exemple (auto-évaluation) | Base `goatcounter` séparée, aucun lien avec `pedalons` ; ni cookie ni `Referer` transmis (§4.3, §3.1) ; l'opposition n'est pas stockée sur le compte (§4.4) ; hébergement Scaleway déjà déclaré ; aucune donnée de formulaire ni de compte dans le hit (§4.2) |
| 5 | Statistiques anonymes seulement (LD 51) ; rapports anonymes **quels que soient les critères de sélection** (une combinaison ne doit pas isoler un utilisateur), avec, en mesure recommandée, l'agrégation et la présentation **à la dizaine la plus proche**, et à défaut une analyse qui justifie l'anonymat (avis du G29) ; pas de rejeu de session (auto-évaluation) | Pas d'identifiant persistant, **pas de session** ni d'empreinte (§3.5, §4.5) ; **aucune ligne par page vue**, des compteurs par chemin seulement (*Individual pageviews* coupé, §3.5, §4.5) ; chemins réduits au gabarit et au slug de l'équipe, qui nomme un club et non une personne (§4.2) ; aucun champ de compte, aucun état de connexion (§4.2) ; pas de rejeu de session. GoatCounter affiche des comptes exacts, sans arrondi ni seuil : sur une page réservée d'une petite équipe privée, un compteur à 1 désigne presque sûrement l'un de ses quelques membres (§4.5). La mesure recommandée (la dizaine) n'est pas en place ; l'exemption repose sur **l'analyse d'anonymat** décidée par le propriétaire le 15 octobre 2026 (§7) : **rien ne relie deux pages vues entre elles** (ni session, ni identifiant, ni ligne par page vue) **ni une page vue à un compte** (aucun champ de compte, aucun état de connexion, base séparée) ; **un seul lecteur**, le responsable du traitement, qui ne recoupe pas les statistiques avec d'autres données (condition 4). Un compteur bas dit qu'une page d'équipe a été vue, jamais par qui, ni quoi d'autre cette personne a vu. L'analyse est à relire si un second lecteur reçoit l'accès (`WEB-91`) |
| 6 | IP : si elle est utilisée, localisation à l'échelle de la ville au plus, puis pseudonymisation en retirant au moins le dernier octet (auto-évaluation) | Plus strict que le critère : IP lue en mémoire seulement, au plus 10 s, pour le pays, la limite de débit et le filtre de robots, **jamais écrite en base**, sessions coupées (vérifié, §3.1, §3.5) ; région coupée, pays seul, déduit sur nos serveurs par la base GeoIP intégrée (vérifié, §3.5) ; pas de journal d'accès du conteneur (vérifié), et les lignes de son journal d'erreur qui recopient l'IP écartées avant Loki (§3.1) ; **`/count` absent du journal Caddy** (`log_skip`, §3.9) |
| 7 | Traceurs d'au plus 13 mois, non prorogés à chaque visite (recommandation 50) | Aucun traceur posé sur le terminal ; la seule clé locale est l'opposition, posée par la personne |
| 8 | Données conservées au plus 25 mois, durées réexaminées périodiquement (recommandation 50) | Rétention à 730 jours, qui purge aussi les tables agrégées (vérifié dans le code, §3.5), posée par `goatcounter-init.sh site` avant l'activation. Le réexamen : une ligne dans `OPERATIONS.md` (étape 1), avec la surveillance de la purge (§3.5), pour relire la durée une fois par an |
| 9 | Information des personnes (recommandation 50) | Sous-section « Mesure d'audience du site » de la politique, en FR et en EN, et ses renvois aux sections 2, 3, 4, 6, 7 et 8 (§5.2) |
| 10 | Opposition, dès lors qu'il y a traitement de données personnelles : un **bouton ou lien cliquable au sein de la politique de confidentialité** du site, et un moyen de retenir le refus dans la durée, un cookie d'opposition par exemple (auto-évaluation) | DNT et GPC respectés d'office, seul moyen global ; interrupteur **sur la page `/confidentialite` elle-même**, au-dessus du texte de la politique, et sur `/profil/vie-privee` (§4.4) ; refus retenu par la clé `pedalons-analytics-optout`, propre à chaque site et à chaque navigateur, ce que la politique dit. Dans l'app, la politique n'a pas d'interrupteur : l'app ne mesure rien |

Base légale : l'intérêt légitime (fiabilité et ergonomie du site), exemptée de consentement.

### 5.2 Passages de la politique à réécrire

Source unique : `privacy/privacy-policy.fr.md` et `privacy/privacy-policy.en.md`, alignés ligne à
ligne (les numéros valent pour les deux). `frontend/src/assets/legal/` est une copie de build
ignorée par git : ne rien y écrire. **Parité FR/EN** dans le même commit, et le texte étant un asset
de l'app mobile, il n'y apparaîtra qu'à la build suivante — d'où des renvois écrits pour les deux
rendus (« sur le site… ; l'application ne mesure rien »), jamais « l'interrupteur ci-dessous ».

| Ligne | Section | Changement |
|---|---|---|
| 3 | En-tête | Date du jour de la mise en ligne |
| 5 | Intro | Rien à changer ; la nouvelle section dit que la mesure ne vaut que pour le site |
| 48 | §1 « Journaux serveur » | Ajouter : « Les requêtes de mesure d'audience n'y figurent pas. » |
| après 48 | §1 | **Nouvelle sous-section « Mesure d'audience du site »** : ce qui est mesuré (§4.5 : pages vues, pas de visites ni de visiteurs ; le site et le type de page, et **pour une page d'équipe, l'identifiant de l'équipe (celui de son adresse sur pedalons.fr), y compris pour une équipe privée, même sur le domaine propre d'un club**, où l'adresse affichée ne le montre pas (§4.2, hôte épinglé) ; la catégorie de taille de l'écran, jamais sa largeur), ce qui ne l'est jamais (adresse complète, sortie, parcours ou page consultés, paramètres de l'adresse, compte, état de connexion), sans cookie ni session, IP non conservée, pays seul **déduit sur nos serveurs, sans service tiers** (confirmé à l'étape 0 : base GeoLite2-Country intégrée à l'outil), des compteurs par page et non un enregistrement par page vue, outil auto-hébergé, « le site seulement : l'application ne mesure pas l'audience », et comment s'y opposer, avec la portée de l'opposition (ci-dessous, §7) |
| 165 | §2 « Automatiquement » | Ajouter « la mesure d'audience du site décrite à la section 1 » à la liste fermée |
| 176-198 | §3 | Nouvelle ligne : « **Mesurer l'audience du site, de façon anonyme et agrégée** : Intérêt légitime (exempté de consentement) ; opposition possible, voir section 7 » |
| **203** | §3 « jamais » | « Des statistiques d'utilisation — nous n'utilisons aucun outil d'analyse ou de suivi » devient « Un suivi de votre navigation d'un site à l'autre, ou des statistiques rattachées à votre compte » (EN : « Tracking you across sites, or usage statistics tied to your account ») |
| 223-241 | §4 sous-traitants | Pas de nouveau tiers. Une phrase, sur le modèle de `:280` : l'outil de mesure d'audience est auto-hébergé chez Scaleway |
| 296 | §5 Firebase | Relire : « aucun composant d'analyse » porte sur Firebase et reste vrai ; préciser « de Firebase » si l'ambiguïté apparaît |
| 304-341 | §6 Conservation | Nouvelle ligne, à côté de `:337` : « **Statistiques d'audience du site** (sans adresse IP, ni identifiant, ni session ; statistiques agrégées comprises) : 24 mois ». Pas de purge nocturne à dire : l'étape 0 l'a rendue inutile (§4.5) |
| 337 | §6 Journaux d'accès | Ajouter « hors requêtes de mesure d'audience, qui n'y sont pas écrites » |
| 342 | §6 « Sauvegardes » | Ajouter : « Les statistiques d'audience du site ne sont pas sauvegardées. » (conséquence du §3.4) |
| 355 | §7 opposition | Ajouter : « Pour la mesure d'audience du site : activez Do Not Track ou Global Privacy Control dans votre navigateur, ce qui vaut pour tous nos sites ; ou, sur le site, utilisez l'interrupteur de **Profil → Confidentialité** ou de la page **Confidentialité** (/confidentialite). Cet interrupteur ne vaut que pour ce navigateur et pour ce site : à refaire sur chaque site de club et sur chaque navigateur. L'application ne mesure rien. » (EN : « **Profile → Privacy** », « the **Privacy** page (/privacy) », « The app measures nothing. ») |
| 395-444 | §8 liste | Nouvelle clé : `pedalons-analytics-optout`, *Type* localStorage, *Finalité* retenir votre opposition à la mesure d'audience **sur ce site**, *Durée* jusqu'à ce que vous la retiriez ou effaciez les données du site |
| **446** | §8 conclusion | « Nous n'utilisons aucun cookie de suivi, d'analyse ou de publicité. Aucun consentement… » devient : « Nous n'utilisons aucun cookie de suivi, d'analyse ou de publicité. La mesure d'audience du site n'utilise aucun cookie et remplit les conditions d'exemption de consentement de la CNIL (section 1) ; vous pouvez vous y opposer à tout moment (section 7). Aucun consentement n'est donc requis : … » (le reste inchangé). « Remplit » : l'écart des comptes exacts (§5.1, ligne 5) est levé par l'analyse d'anonymat du §7 |
| 475-477 | §11 | Inchangé. La mise en ligne avant l'ouverture publique tient lieu d'annonce (§5.3) ; si la condition du §5.3 n'est pas remplie à l'étape 5, l'e-mail que promet le §11 est envoyé |

Rien à changer : les CGU, les déclarations des stores (`app-privacy.json`, `data-safety.csv`,
`data-safety.md`, dont la note de périmètre `:19-21` dit déjà qu'elles décrivent le binaire),
`PrivacyInfo.xcprivacy`.

### 5.3 Annoncer le changement

Le §11 promet un e-mail « en cas de changement important », et `LEGAL-14` exclut une notification
dans l'app. Retirer « aucun outil d'analyse » contredit une promesse explicite : c'est
vraisemblablement un changement important.

**Décision (15 octobre 2026, §7) : mise en ligne avant l'ouverture publique, sans e-mail.** La
politique réécrite est publiée tant que le site n'est pas ouvert au public ; la date en tête suffit.

**Précondition, vérifiée à l'étape 5** : aucun domaine de prod n'a encore de vrais membres qui ont
accepté la politique actuelle. Le 15 octobre 2026, la migration biketeam n'a pas eu lieu en prod
(`MIG-1` ouvert ; elle ne tourne qu'en staging). Mais la vérification porte sur la base, pas sur le
ledger : comptes de prod hors comptes de test et de l'équipe (inscrits de la bêta compris, la
plateforme a une liste d'inscriptions bêta), équipes migrées, invitations acceptées. Si la
précondition tombe — une équipe migrée, des bêta-testeurs actifs —, la règle du §11 s'applique :
**un e-mail à chaque membre** avant l'activation, envoi groupé à organiser (outil, cadence, jamais
depuis une pile locale, qui écrit à mailpit).

**Ordre imposé** : la politique réécrite est en ligne **avant** que le drapeau ne soit posé en prod.
C'est le précédent de l'audit de juillet dans l'autre sens : ne déclarer une finalité qu'une fois le
code livré, ne lancer le code qu'une fois la finalité déclarée.

---

## 6. Risques

- **Un seul mainteneur, côté projet** : GoatCounter est essentiellement l'œuvre d'une personne
  (arp242). S'il est abandonné, l'image cesse d'avoir des correctifs. Au 15 octobre 2026 il ne l'est
  pas : dernière version 2.7.0 le 15 décembre 2025, commits jusqu'au 27 septembre 2026, dépôt non
  archivé. L'image se construit sur `golang:latest` et `alpine` sans version : un tag repoussé
  changerait de contenu ; épingler par condensat
  (`arp242/goatcounter:2.7.0@sha256:791df3317bf5ce379511181a4802aaf29127a318b372d4fe39ec59e1c5af44be`,
  celui vérifié) si dependabot le suit, sinon le tag. Atténuation : l'expéditeur
  maison (§4.3) rend le passage à Umami local ; la base est jetable (§3.4). Mais Umami demanderait
  un *website* par hôte (§2).
- **Un seul mainteneur, côté Pédalons** : un service de plus à mettre à jour (dependabot sur
  `docker-compose.yml`, `.github/dependabot.yml:141-153`), et une procédure de restauration plus
  longue d'une étape interactive.
- **Bloqueurs de publicité** : servir sur la même origine évite les listes de domaines, mais
  certaines listes filtrent le chemin `/count` ou le paramètre de GoatCounter. Les chiffres seront
  sous-estimés, plus encore avec DNT/GPC. C'est accepté : on cherche des tendances, pas un compte
  exact. Si la perte est forte, renommer le chemin (le routeur Traefik, la règle `log_skip` et
  `countPath`).
- **Pages vues, pas visites** : sessions coupées, on ne sait pas combien de personnes ; une page
  rechargée compte deux fois. Accepté (§1).
- **Déploiements à chaud** : pendant la minute où deux frontends cohabitent, l'ancien (sans
  compteur) ne compte rien ; inoffensif. GoatCounter en stop-first perd quelques secondes ; sa
  migration automatique ne tourne que sur une instance.
- **Restauration** : `restore.sh` recrée la base (§3.4), mais le site reste à recréer à la main ;
  d'ici là, rien n'est compté. La restauration du site n'en dépend pas.
- **Réécriture du `Host`** : vérifiée à l'étape 0 (Traefik v3.7.10). Tant que l'instance n'a qu'un
  site, GoatCounter le servirait même sans elle (§3.1) ; elle compte le jour où un second site est
  créé.
- **Un réglage de collecte rallumé** : *Sessions* recochée dans *Settings* remettrait des clés
  « agent utilisateur-IP » en clair dans `store` à chaque arrêt (§3.5), *Individual pageviews* une
  ligne par page vue. `goatcounter-init.sh site` vérifie `collect = 30` ; `OPERATIONS.md` dit de ne
  pas y toucher, et l'étape 6 relit `store` et `hits`.
- **Journal d'erreur** : une panne de la base fait écrire à GoatCounter l'IP et l'agent utilisateur
  des hits en attente (§3.1). Couvert par le filtre Alloy et la rotation de l'étape 1 ; à revoir à
  chaque mise à jour de GoatCounter (le format de ces lignes peut changer).
- **Un bloc Caddy de club sans le snippet** : `/count` y serait journalisé avec l'IP. Vérifié hôte
  par hôte à l'étape 5, et à chaque nouveau domaine de club.
- **Slug d'équipe renommé** : l'historique de l'équipe se coupe en deux chemins (§4.2) ; à
  regrouper à la main dans le tableau de bord si besoin. Accepté.
- **Une route nouvelle sans `handle`** : ignorée, donc pas comptée ; le test de `toCountHit` sur
  toute la table la détecte.
- **Dérive de la promesse** : quelqu'un « améliore » plus tard le compteur avec `location.pathname`,
  `document.title`, `sendBeacon` ou l'état de session. Les tests vitest du §8 l'interdisent ; un
  commentaire `docs/LEDGER_*.md WEB-90` à l'appel le rappelle.

---

## 7. Décisions

Les questions ouvertes de la première version ont été tranchées le **15 octobre 2026**. Il n'en
reste aucune.

- **Pages vues, pas visites** (ex-Q8) : sessions coupées, un seul site GoatCounter pour tous les
  hôtes (§1, §3.5). Compter des visites, c'est-à-dire un site par domaine et la purge de
  `hits.session`, est écarté (`OPS-40`).
- **Statistiques par équipe** (ex-Q1) : le slug de l'équipe est **gardé pour toutes les équipes**,
  publiques ou privées, et substitué au seul `:teamSlug` du gabarit ; les autres paramètres restent
  des marqueurs (§4.2). La politique dit que le chemin contient l'identifiant de l'équipe (§5.2).
- **Propriété `auth` de la route, jamais l'état de session** (ex-Q2, tranchée à la relecture) : §4.2.
- **Pas de coupure par club** (ex-Q3) : aucun drapeau par `Domain`, pas avant qu'un club le demande
  (§3.3, `API-116`).
- **Statistiques jetables** (ex-Q4) : la base `goatcounter` n'est pas sauvegardée (§3.4), et la
  politique le dit.
- **Prod seulement** (ex-Q5) : ni drapeau ni GoatCounter sur staging, mis à 0 réplique par
  `deploy.sh` (§3.7).
- **Mise en ligne avant l'ouverture publique** (ex-Q6) : pas d'e-mail, sous la précondition du §5.3,
  vérifiée à l'étape 5.
- **Tableau de bord pour le seul responsable du traitement**, par tunnel (ex-Q7) : §3.6. Des
  statistiques pour les admins de club sont écartées (`WEB-91`).
- **Comptes exacts, justifiés par une analyse d'anonymat** (décidé après l'implémentation) : pas
  d'arrondi à la dizaine ; rien ne relie deux pages vues entre elles ni à un compte, et le
  responsable du traitement est le seul lecteur (§5.1, ligne 5). Si un second lecteur reçoit
  l'accès, l'analyse tombe : à refaire avant (`WEB-91`).

---

## 8. Étapes, dans l'ordre

Chaque étape est livrable seule ; le compteur ne s'allume qu'à l'étape 6.

| # | Étape | Fichiers | Taille | Tests |
|---|---|---|---|---|
| 0 | **Fait le 15 octobre 2026** (§9) — **Vérifier GoatCounter sur un poste** : version et image (binaire de healthcheck, journal d'accès), `GET /count` sans script et ses paramètres, **qu'il ne prend jamais le `Referer` comme repli de `p` ou de `r`**, résolution du site par `Host` et réécriture par Traefik, suppression de `Cookie` et `Referer` par le middleware, en-tête d'IP lu derrière deux proxys, option `-tls` et cookies du tableau de bord en `http://`, **coupure des sessions et schéma (`\d hits` : la colonne `session` reste-t-elle vide ?)**, pays résolu sur place ou non, noms des réglages de collecte, *Public*, rétention et tables agrégées, accès au tableau de bord par le routeur `Host()` et un tunnel, routeurs d'un service Swarm à 0 réplique (le cas de staging, §3.7). Mettre à jour ce plan : retirer chaque *[à vérifier]* ou basculer sur Umami. **Verdict : GoatCounter convient, pas de bascule** ; quatre changements de conception (§9) | ce plan | S | Manuels, consignés au §9 |
| 1 | **Livrée le 15 octobre 2026** (`OPS-36`) ; écarts : DSN par `GOATCOUNTER_DB` et non `-db=` (§3.1) ; `.env.example` aux clés vides ; `goatcounter-init.sh site` arrête GoatCounter **avant** de créer le site, créé par un conteneur jetable dans l'espace réseau de postgres (§3.2) ; sous-commande `password` (§3.1, « Courriels ») ; profil `analytics` dit dans le `README` ; revue annuelle de la rétention dans `OPERATIONS.md` (§5.1, ligne 8) — **Service et base** (`OPS-36`) : service `goatcounter` (commande en liste, `PGPASSWORD` hors du DSN, `-tls=http`, `-dbconn=4,1`, `tmpfs` sur le répertoire de données, healthcheck `wget`, rotation courte du journal Docker, middleware `count-headers` avec ses quatre en-têtes d'IP vidés, routeur du tableau de bord, stop-first), overlays local et e2e, clés `.env.example`, `scripts/goatcounter-init.sh` (`db` ; `site`, qui pose aussi `collect = 30` et `data_retention = 730` par SQL, §3.2), vérification des clés, `goatcounter` dans `--hold-app` et à 0 réplique sans clés (`deploy.sh`), appel de `goatcounter-init.sh db` (`restore.sh`), filtre Alloy des lignes `hit =`/`paths =` (§3.1), section `OPERATIONS.md` (création, réglages, tunnel, restauration, mémoire, base non sauvegardée, purge à surveiller, pas de « Forgot password », `log_skip` dans « Access logs ») | `docker-compose.yml`, `docker-compose.local.yml`, `docker-compose.e2e.yml`, `.env.example`, `scripts/goatcounter-init.sh`, `scripts/deploy.sh`, `scripts/restore.sh`, `services/monitoring/alloy/config.alloy`, `docs/OPERATIONS.md` | M | `docker stack config` / `docker compose config` sur les trois combinaisons ; `scripts/e2e.sh` ne démarre pas `goatcounter` ; `deploy.sh` refuse une seule des deux clés `GOATCOUNTER_*` posée, et `PEDALONS_ANALYTICS_COUNT_PATH` sans elles ; les deux vides (staging), il déploie `goatcounter` à 0 réplique et `goatcounter-init.sh db` ne fait rien ; un `curl` sur `/count` depuis deux hôtes, avec un cookie, un `Referer` et un `X-Real-Ip` forgé, atterrit dans le même site sans eux (le refaire de la pile jetable du §9) ; après `goatcounter-init.sh site`, `settings->>'collect' = '30'` et le journal sans « No sites yet » ni mot de passe |
| 2 | **Livrée le 15 octobre 2026** (`API-117`, contrat `11.3.0`) ; écarts : le chemin est vérifié par liste blanche (`/[A-Za-z0-9._~-][A-Za-z0-9._~/-]*`), pas seulement contre un `//` de tête : un navigateur lit `/\hôte` et `/<TAB>/hôte` comme `//hôte` (revue) ; `%test` force le drapeau à vide comme `%dev` — **Drapeau dans `/api/config`** (`API-117`) : `ConfigDto.analytics` nullable, `@ConfigProperty Optional<String>`, bump mineur, régénération des clients | `ConfigDto.java`, `ConfigService.java`, `application.properties`, contrat, `frontend/src/api/dto/configDto.ts`, client mobile régénéré | XS | Test backend de `ConfigService` (null sans propriété, rempli sinon) — **à lancer par le propriétaire**, pas par l'agent |
| 3 | **Livrée le 15 octobre 2026** (`WEB-90`) ; écarts (revue) : une redirection de loader qui revient sur la route quittée est comptée (§4.1) ; une page vue arrivée dans le délai d'une autre envoie celle-ci aussitôt (§4.1) ; `s` réduit à la catégorie d'écran (§4.2, §5.1 ligne 2) ; le test « toutes les routes » passe l'URL entière, requête et fragment compris, par l'état d'un routeur mémoire. **Le Playwright ne prouve que la configuration de la pile e2e**, pas l'effet du drapeau seul : sur cette pile, `navigator.webdriver` et l'hôte de bouclage (`localhost`, `*.localhost`) bloquent aussi l'envoi, et aucun hôte de la pile n'échappe au second ; l'effet du drapeau est prouvé par le vitest « without the analytics config » — **Compteur côté site** (`WEB-90`) : `lib/analytics/` (`toCountHit`, expéditeur `fetch`, garde-fous), abonnement dans `getRouter()`, `handle` de la route `*`, interrupteur d'opposition sur `/profil/vie-privee` et dans `PrivacyPolicyPage.tsx` hors du Markdown, libellés FR/EN (portée « ce navigateur et ce site ») | `frontend/src/lib/analytics/*`, `frontend/src/App.tsx`, `frontend/src/config/RouteGenerator.tsx`, la page de la route `profile-privacy`, `pages/legal/PrivacyPolicyPage.tsx`, `locales/{fr,en}/common.json` | M | Vitest : `toCountHit` sur **toutes** les entrées de `routesConfig` × `LOCALES`, URL concrètes aux paramètres sentinelles (`previewId='SECRET123'`, `rideSlug='sortie-secrete'` et une sentinelle par autre paramètre, `teamSlug='equipe-privee'`, `?token=SECRET`, `#frag`) → **`equipe-privee` apparaît exactement comme segment de `p` pour chaque route qui a `:teamSlug`, à la place de ce seul marqueur**, aucune autre sentinelle, aucun `?` ni `#` dans `p` ; un `teamSlug` mal formé (`Equipe%20X`, `a@b.fr`, plus de 200 caractères) reste `:teamSlug` ; le même chemin compté sur un hôte épinglé (`pinnedHistory`) et sur l'hôte partagé ; `t` sans `document.title` ni état de session ; référent interne → absent, externe → origine seule (`https://hôte`, ni chemin ni requête), **et seulement au premier hit** ; jamais de paramètre `q`, `b` ni `e` ; `s` entier ; options du `fetch` (`credentials: 'omit'`, `referrerPolicy: 'no-referrer'`, `keepalive`), jamais `sendBeacon` ; aucun envoi si config nulle, DNT, GPC, opposition (**y compris après rechargement du module**), `webdriver`, `localhost` ; import du module sans `window`. Routeur mémoire : un envoi au départ (avec et sans `hydrationData`), un par `PUSH`, un par `POP`, aucun sur `REPLACE` de même route, un sur redirection de loader, **un seul sur une route masquée et sur une route protégée visitée sans session**, `/404` seulement pour `*`. Playwright : `e2e/analytics-off.e2e.ts`, aucune requête vers `/count` sur un parcours de quelques pages (la pile e2e n'a ni drapeau ni service) |
| 4 | **Rédigée le 15 octobre 2026** (`LEGAL-19`), pas encore en ligne (étape 5, `OPS-41`) ; la date en tête (15 octobre 2026) est à recaler au jour de la mise en ligne. L'écart de l'écran (§5.1, ligne 2) est levé à l'étape 3 ; celui des comptes exacts (ligne 5) est levé par l'analyse d'anonymat (§7), et la phrase du §8 de la politique dit « remplit les conditions d'exemption » (§5.2). L'identifiant d'équipe est dit « celui de son adresse sur pedalons.fr », vrai aussi sur un hôte épinglé — **Politique FR/EN** (`LEGAL-19`) : les passages du §5.2, relecture des conditions CNIL sur cnil.fr (faite, §5.1) | `privacy/privacy-policy.{fr,en}.md` | S | Relecture ; parité ligne à ligne vérifiée par `diff <(grep -c '' …)` |
| 5 | **À faire, `OPS-41`** — **Déploiement sans drapeau** : service et base en prod (boucle de redémarrage attendue jusqu'à `goatcounter-init.sh db`), `goatcounter-init.sh site` (son conteneur jetable en `--network container:<postgres>` vérifié sur la tâche Swarm de postgres, §3.2), réglages du §3.5, tunnel vérifié, tableau de bord injoignable par Caddy ; `caddy version` de l'hôte lue (≥ 2.8 pour `log_skip`, sinon `skip_log`), `log_skip` dans le snippet Caddy et **chaque bloc de club et d'alias vérifié** ; politique en ligne ; **précondition du §5.3 vérifiée en base** (aucun membre réel n'a accepté la politique actuelle), sinon e-mail à chaque membre avant l'étape 6 ; staging vérifié sans tâche `goatcounter` | hôte | XS | Manuels, consignés dans `OPERATIONS.md` |
| 6 | **À faire, `OPS-41`** — **Activation**, seulement si les réglages du §3.5 sont en place (`collect = 30`, `data_retention = 730` : la rétention couvre les tables agrégées, vérifié à l'étape 0, aucune purge à ajouter) et le filtre Alloy déployé : `PEDALONS_ANALYTICS_COUNT_PATH=/count` dans le `.env` de prod, redéploiement | `.env` de prod | XS | Une visite par un navigateur sans DNT apparaît dans le tableau de bord avec le gabarit ; la même avec DNT n'apparaît pas ; le journal du conteneur ne contient aucune IP de visiteur, celui de Caddy aucune ligne `/count` ; `select count(*) from hits` vaut 0 ; après un redémarrage de GoatCounter, `store` ne garde que des sessions vides ; une panne de base simulée (postgres arrêté quelques secondes) ne laisse dans Loki aucune ligne `hit =` |

Au bout d'un mois de production (`OPS-41`) : relire les chiffres contre les cinq questions du §1,
puis archiver ce plan (`docs/plans/archive/`, avec sa ligne dans le README des archives) et
déplacer `OPS-41` dans `LEDGER_DONE.md` ; les étapes 1 à 4 y sont déjà.

---

## 9. Résultats de l'étape 0 (15 octobre 2026)

**Verdict : GoatCounter convient, on ne bascule pas sur Umami.** Les deux blocages possibles sont
levés : les sessions se coupent (et coupées, rien n'est écrit), et le `Referer` n'est jamais pris
comme repli. Aucun fait ne contredit le choix ; quatre changent la conception, reportés plus haut.

### Comment

- **Code source** : `arp242/goatcounter` au tag `v2.7.0` (commit `7e91d8a9bdbb`, celui de l'image),
  et ses dépendances `zgo.at/zhttp` (`mware.RealIP`, `IsSecure`) et `zgo.at/isbot` aux versions de
  son `go.mod`. Traefik : `pkg/provider/docker/pswarm.go` de la branche `v3.7`. Umami :
  `src/app/api/send/route.ts` de `master` (v3.4.0, 17 septembre 2026).
- **Pile jetable** sur un poste, réseau Docker `gcverify-net`, sans port publié, retirée à la fin
  (conteneurs, réseau, volumes anonymes) : `arp242/goatcounter:2.7.0`
  (`sha256:791df3317bf5ce379511181a4802aaf29127a318b372d4fe39ec59e1c5af44be`), `postgres:17`
  (17.11, rôle et base `goatcounter` créés comme le fera `goatcounter-init.sh db`), `traefik:v3.7`
  (3.7.10, provider Docker restreint par contrainte de label, **`forwardedHeaders.insecure=true`
  comme la prod**), `caddy:2` (2.11.4) devant, un conteneur `curl` comme client et `traefik/whoami`
  derrière le même middleware pour voir les en-têtes reçus. Les labels du service étaient ceux du
  §3.1.

### Ce qui a été constaté

| Question | Résultat | Comment |
|---|---|---|
| Version, image | 2.7.0 du 15 décembre 2025, la dernière ; Alpine, utilisateur `goatcounter`, entrée `goatcounter`, `VOLUME /home/goatcounter/goatcounter-data` | `docker image inspect`, Dockerfile |
| Healthcheck | `/status` : JSON (`uptime`, `version`, `database`…), `200` quel que soit le `Host`, même base injoignable ; `wget` de busybox dans l'image, pas de `curl` | requêtes, `which` dans l'image, `handlers/mw.go` |
| Journal d'accès | Aucun par défaut ; seulement avec `-debug=req`, et `/count` en est exclu | journal après des dizaines de hits (aucune IP), `handlers/backend.go` |
| **Journal d'erreur** | **Recopie le hit entier, IP et agent utilisateur compris**, quand l'écriture échoue | postgres arrêté : ligne `hit = &{… 81.2.69.142 …}` → §3.1 |
| DSN dans le journal | Sans site, l'avertissement « No sites yet » recopie `-db` en entier, mot de passe compris ; `PGPASSWORD` marche à sa place | journal au premier démarrage, second conteneur sans mot de passe dans le DSN → §3.1 |
| `GET /count` sans script | Oui (`GET` et `POST`) ; `200` + GIF de 43 octets, aucun `Set-Cookie` ; `400` + `X-Goatcounter` si invalide ; `429` au-delà de 4/s par IP | requêtes |
| Paramètres | `p`, `t`, `r`, `s` (liste, 1ʳᵉ valeur = largeur), `q` (campagnes), `e`, `b` (absent, 0 ou ≥ 150), `rnd` ; inconnus ignorés ; barre finale de `p` retirée | `hit.go`, `count.js`, requêtes → §4.2 |
| **`Referer` en repli** | **Jamais**, ni pour `r` ni pour `p` : sans `r` le référent est vide, sans `p` c'est `400` | requête directe avec `Referer`, `grep Referer` du code (seul l'import de journaux le lit) |
| Site d'après `Host` | `lower(cname)`, port retiré ; **avec un seul site, n'importe quel `Host` le sert** | `Host: whatever.example` compté, `site.go`, `handlers/mw.go` |
| Réécriture de `Host` par Traefik | Appliquée à `req.Host` ; `X-Forwarded-Host` garde l'hôte d'origine, que GoatCounter ne lit pas | whoami derrière le middleware |
| `Cookie`, `Referer` retirés | Oui, une valeur vide supprime l'en-tête | whoami |
| IP lue derrière Caddy et Traefik | 1ᵉʳ public de `Cf-Connecting-Ip`, `Fly-Client-Ip`, `X-Azure-Socketip`, `X-Real-Ip`, puis dernier saut public de `X-Forwarded-For` ; Caddy remplace le XFF du client, mais **`X-Real-Ip` et `Cf-Connecting-Ip` envoyés par le client traversent** ; vidés par le middleware, l'IP lue est celle de Caddy | whoami, `mware/realip.go` → §3.1 |
| `-tls` | `http` (défaut) ; `none` et `proxy` sont d'anciens alias | aide `help listen`, `acme/acme.go` |
| Tableau de bord en `http://` | Connexion par le routeur `Host()` avec `Host: …:8090` ; cookie `key` `HttpOnly; SameSite=Lax`, sans `Secure` ; non connecté → `303 /user/new` | `curl` avec un pot à cookies → §3.6 |
| **Sessions** | Coupables (case *Sessions*, bit 128) ; **allumées, la clé `<UA>-<IP>-<site>` est écrite en clair dans `store` à chaque arrêt** ; coupées, `store` ne garde que des maps vides | arrêt du conteneur avant/après → §3.5 |
| `\d hits`, `hits.session` | `session bytea` nullable ; sessions coupées : 16 octets nuls, une seule valeur pour toutes les lignes ; *Individual pageviews* coupé (défaut) : **`hits` reste vide** | `psql` → §4.5 |
| Pays | Base GeoLite2-Country **intégrée** (20 mai 2025), sans service tiers ; un XFF `81.2.69.142` donne `GB` ; la région demande une base City | journal de démarrage, `pkg/geo/geo.go`, `location_stats` |
| Réglages | *Data collection* : Individual pageviews, Sessions, Referrer, User-Agent, Size, Country, Region, Language (bits 256, 128, 2, 4, 8, 16, 32, 64) ; défaut `190` ; *Dashboard viewable by* (`private` par défaut) ; *Data retention in days* (31…1825, 0 = jamais) | page *Settings*, `settings.go` → §3.5 |
| Rétention et agrégats | Purge `hits`, toutes les tables `*_stats`, `hit_counts`, `ref_counts`, puis les `paths` orphelins ; une fois par jour, 24 h après le démarrage | `site.go` (`DeleteOlderThan`), `cron/` — **lu, pas exécuté** (24 h d'attente) |
| `db create site` | `-vhost`, `-user.email`, mot de passe demandé s'il manque ; `-createdb` inutile, `serve -automigrate` crée le schéma dans une base vide | exécution |
| Pool | `-dbconn max_open,max_idle`, 16,4 par défaut | aide de `serve` |
| Mémoire | 36 à 40 Mio au repos | `docker stats` |
| `log_skip` | Marche sur Caddy 2.11.4 | snippet du §3.9 sur un Caddy jetable |
| Swarm à 0 réplique | Aucun routeur, middleware ni service : le provider ne lit que les tâches `running` | code de Traefik v3.7 — **lu, pas exécuté** (pas de Swarm sur le poste) → §3.7 |
| Umami | Session `uuid(website, ip, UA, sel mensuel, distinctId)`, sans réglage pour la couper | code de la v3.4.0 → §2 |

### Ce qui change dans la conception

1. **Pas de ligne par page vue** : *Individual pageviews* reste coupé (le défaut), la table `hits`
   reste vide, la purge nocturne de `hits.session` n'a plus d'objet (§3.5, §4.5, §5.2). La
   première version ne connaissait pas ce réglage.
2. **Le middleware vide aussi `X-Real-Ip`, `Cf-Connecting-Ip`, `Fly-Client-Ip` et
   `X-Azure-Socketip`** : sinon un client choisit l'IP que GoatCounter lit (§3.1). Pas de
   `healthcheck.hostname` (§3.1).
3. **Le mot de passe de la base passe par `PGPASSWORD`**, et le journal d'erreur de GoatCounter
   est filtré avant Loki (Alloy) et borné sur l'hôte (rotation) : sans cela, le mot de passe et des
   IP de visiteurs y passeraient (§3.1).
4. **Les réglages de collecte et de rétention sont posés par `goatcounter-init.sh site`, en SQL,
   avant tout hit** : le site naît sessions allumées (§3.2, §3.5).

Plus petits : `-tls=http`, `-dbconn=4,1`, `tmpfs` sur le répertoire de données, healthcheck de
conteneur par `wget`, `r` envoyé comme origine et non comme hôte nu, ni `b` ni `q` envoyés, ne
jamais utiliser « Forgot password » (courriels sur la sortie standard).

### Ce qui reste à constater ailleurs que sur un poste

- La version de Caddy de l'hôte (`log_skip` ou `skip_log`) et chaque bloc de club : étape 5 (`OPS-41`).
- Le tunnel `ssh -L` jusqu'au Traefik de prod : étape 5 (`OPS-41`).
- Le conteneur jetable de `goatcounter-init.sh site` dans l'espace réseau de la tâche Swarm de
  postgres (`--network container:`), constaté seulement sur une pile jetable : étape 5 (`OPS-41`).
- L'absence de routeur `goatcounter` sur le Traefik de staging (service à 0 réplique) : étape 5 (`OPS-41`).
- La purge de rétention réellement exécutée : un jour après l'activation, `select min(day) from
  hit_stats` ne doit jamais dépasser 730 jours ; à suivre dans `OPERATIONS.md`.
- ~~L'option `-password` de `goatcounter db update user` (au prompt ou non) : étape 1.~~ Tranché à
  l'étape 1 : la valeur passe en argument, sans prompt ; d'où la sous-commande `password` de
  `goatcounter-init.sh`, par `GOATCOUNTER_PASSWORD` (§3.1, « Courriels »).
