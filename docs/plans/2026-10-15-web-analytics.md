# Mesure d'audience du site — GoatCounter auto-hébergé

Écrit le 15 octobre 2026, relu le même jour (revues vie privée et technique, intégrées) ; les
questions ouvertes ont été tranchées le même jour (§7). **État : proposé, rien n'est implémenté.**
Ledger `OPS-36` (le service), `API-117` (le drapeau dans `/api/config`), `WEB-90` (le compteur côté
site), `LEGAL-19` (la politique). Alternatives écartées : `OPS-37`, `OPS-38`, `OPS-39`, `LEGAL-20`.
Écartés par les décisions du §7 : `OPS-40` (compter des visites), `API-116` (couper la mesure pour un
club), `WEB-91` (statistiques pour les admins de club).

Les faits sur GoatCounter marqués **[à vérifier]** viennent de mémoire, pas de sa documentation :
l'étape 0 (§8) les confirme ou les corrige avant toute autre ligne de code. Les faits sur le dépôt
ont été relus dans le worktree le 15 octobre 2026, avec leurs numéros de ligne à cette date.

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
| Mémoire indicative *[à vérifier]* | ≈ 50 à 100 Mo | ≈ 200 à 300 Mo | > 1 Go | ≈ 300 Mo + base | — | — |
| Cookie | Aucun *[à vérifier]* | Aucun | Aucun | Oui par défaut (désactivable) | Variable | Aucun |
| IP conservée | Non : sessions coupées, IP lue en mémoire pour le pays *[à vérifier]* | Non : hachage | Non | Configurable (anonymisation) | Chez un tiers | **Oui** dans les journaux |
| Sessions désactivables | Oui, réglage de collecte *[à vérifier]* | Non *[à vérifier]* | Non | Oui | Variable | — |
| Navigations côté client (React Router) | Oui, appel explicite | Oui | Oui | Oui | Oui | **Non** : seul le premier chargement passe par le serveur |
| Nouveau sous-traitant | Non (Scaleway déjà déclaré) | Non | Non | Non | **Oui** | Non |
| Plusieurs hôtes sur un site | Oui, l'hôte voyage dans le chemin (§3.1) | Oui | Oui | Oui | Oui | — |
| Ce qu'il faut maintenir | Une image, une base | Une image, une base, des migrations Prisma | Deux moteurs de base | PHP, une base de plus, des greffons | Un contrat | Des scripts hors dépôt |

**Pourquoi GoatCounter.** C'est le plus petit qui réponde aux cinq questions : un binaire, aucune
base nouvelle (une base `goatcounter` sur le cluster existant), pas de cookie, des sessions que
l'on peut couper, et l'IP n'est utilisée qu'en mémoire. Son API de comptage est un simple
`GET /count` *[à vérifier]*, qu'on peut appeler sans son script.

**Umami, en repli.** Même stockage (PostgreSQL, pas de cookie, auto-hébergé), plus lourd en mémoire
et avec plus de dépendances. Il sert si l'étape 0 révèle un blocage chez GoatCounter : sessions
impossibles à couper, IP mal lue derrière deux proxys, journal d'accès impossible à couper, image
abandonnée. **Il porte le même risque de suivi d'un site à l'autre** : sa session est un hachage de
l'IP, de l'agent utilisateur et du *website* *[à vérifier]*. Un *website* Umami unique pour tous les
hôtes relierait donc les sites de club entre eux ; basculer sur Umami impose un *website* par hôte
(donc le couplage avec `AdminDomainResource` écarté au §3.1), à moins qu'il permette de couper les
sessions. Le côté site (§4) est écrit pour qu'en changer ne touche que l'expéditeur.

**Pourquoi pas les autres** (au ledger, « Délibérément dehors ») :

- **Plausible CE** (`OPS-37`) : ClickHouse, une seconde base de données à sauvegarder, surveiller et
  mettre à jour, et plus de mémoire que tout le reste de la pile pour quelques milliers de visites
  par mois.
- **Matomo** (`OPS-38`) : PHP et MySQL, deux briques absentes de la pile ; cookies par défaut, à
  désactiver ; des greffons à suivre. Il figure sur la liste CNIL des outils exemptables, mais sa
  configuration exemptée ne fait rien de plus que GoatCounter ici.
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
    image: arp242/goatcounter:<x.y.z>          # version exacte [à vérifier], suivie par dependabot
    # En liste : le DSN contient des espaces, une chaîne repliée serait découpée en plusieurs arguments.
    command:
      - serve
      - -listen=:8080
      - -tls=none                                # [à vérifier] : une valeur « proxy » passerait les cookies en Secure, et le tableau de bord par tunnel http:// échouerait
      - -automigrate
      - -db=postgresql+host=postgres dbname=goatcounter user=goatcounter password=${GOATCOUNTER_DB_PASSWORD:-} sslmode=disable
    networks: [pedalons]                        # pas « shared » : Traefik choisirait la mauvaise IP (:55-57)
    labels: &goatcounter-labels
      - traefik.enable=true
      - traefik.stack=${ENV_NAME}
      # Le compteur, sur tous les hôtes.
      - traefik.http.routers.goatcounter-count.rule=Path(`/count`)
      - traefik.http.routers.goatcounter-count.priority=150
      - traefik.http.routers.goatcounter-count.middlewares=ratelimit-count,count-headers
      - traefik.http.routers.goatcounter-count.service=goatcounter
      # Le vhost unique, plus ni cookie ni Referer : une valeur vide supprime l'en-tête.
      - traefik.http.middlewares.count-headers.headers.customrequestheaders.Host=${GOATCOUNTER_VHOST:-}
      - traefik.http.middlewares.count-headers.headers.customrequestheaders.Cookie=
      - traefik.http.middlewares.count-headers.headers.customrequestheaders.Referer=
      - traefik.http.middlewares.ratelimit-count.ratelimit.average=…
      - traefik.http.middlewares.ratelimit-count.ratelimit.sourcecriterion.ipstrategy.depth=1
      # Le tableau de bord, sur le seul vhost : aucun bloc Caddy ne le relaie, seul un tunnel l'atteint (§3.6).
      - traefik.http.routers.goatcounter-dash.rule=Host(`${GOATCOUNTER_VHOST:-}`)
      - traefik.http.routers.goatcounter-dash.service=goatcounter
      - traefik.http.services.goatcounter.loadbalancer.server.port=8080
      - traefik.http.services.goatcounter.loadbalancer.healthcheck.path=/status
      - traefik.http.services.goatcounter.loadbalancer.healthcheck.hostname=${GOATCOUNTER_VHOST:-}
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
- **Un seul site GoatCounter** : GoatCounter choisit le site d'après le `Host` de la requête
  *[à vérifier]*. Le middleware `count-headers` réécrit le `Host` vers le vhost unique
  (`GOATCOUNTER_VHOST`, par exemple `stats.pedalons.internal`) *[à vérifier : Traefik v3 applique un
  `Host` personnalisé à `req.Host`]* ; le domaine du club voyage dans le chemin compté (§4.2). Pas
  de `passhostheader=false` : le `Host` deviendrait l'IP de la tâche. L'alternative, un site par
  `Domain` et par `DomainAlias`, couplerait la création d'un domaine (`AdminDomainResource`) à
  GoatCounter : écartée tant que les sessions sont coupées (§3.5), ce qui retire la seule raison
  vie privée de séparer les sites.
- **Ni cookie ni `Referer`** : le cookie `refresh_token` est posé en `Path=/`
  (`RefreshTokenCookieFactory.java:28`) et une requête même origine vers `/count` le porterait,
  avec `lang` ; le `Referer` d'une requête même origine est l'URL entière de la page, `?token=`
  compris. Le site ne les envoie pas (§4.3) ; le middleware les retire quand même, en défense en
  profondeur.
- **Pas de `/count.js`** : le site n'utilise pas le script de GoatCounter (§4.3), un seul chemin est
  routé sur les hôtes publics.
- **Pas de volume** : tout est dans PostgreSQL. Le répertoire de données de l'image
  (`/home/goatcounter/goatcounter-data` *[à vérifier]*) reste inutilisé.
- **Pool de connexions** : `postgres` est limité à 1 Go, dimensionné pour les 20 connexions du
  backend (`:256-262`). Limiter le pool de GoatCounter à quelques connexions, si sa DSN ou une option
  le permet *[à vérifier]*.
- **Mise à jour stop-first**, écrite dans `update_config` et `rollback_config` même si c'est le
  défaut de Swarm, parce que la règle de la pile est start-first (`*rolling-update`,
  `docker-compose.yml:149`) : avec `-automigrate`, deux instances simultanées migreraient la même
  base en même temps. Perdre quelques secondes de comptage à chaque déploiement de GoatCounter est
  sans conséquence ; une migration concurrente pourrait l'être. `replicas: 1` explicite, pour
  qu'un `restore.sh` interrompu ne le laisse pas à 0 sans trace ; c'est `deploy.sh`, pas le fichier,
  qui le met à 0 là où la mesure n'existe pas (staging, §3.7).
- **Mot de passe de la base** : sans espace ni guillemet (hexadécimal, `openssl rand -hex 24`), il
  est un morceau du DSN.
- **Variables vides** : `${GOATCOUNTER_VHOST}` et `${GOATCOUNTER_DB_PASSWORD}` ne peuvent pas porter
  `:?` ici : compose interpole tout le fichier, services hors profil compris, ce qui casserait la
  pile e2e et les postes. Elles s'écrivent `${…:-}` (pas d'avertissement là où elles manquent).
  `deploy.sh` en tire trois cas : **les deux posées** (prod), GoatCounter à 1 réplique ; **les deux
  vides** (staging), GoatCounter à 0 réplique par l'overlay qu'il écrit déjà pour `--hold-app`
  (§3.7) ; **une seule posée**, il **refuse de déployer** : sinon la prod aurait silencieusement un
  `Host=` vide et zéro comptage. Il refuse aussi `PEDALONS_ANALYTICS_COUNT_PATH` posé alors que
  GoatCounter est à 0 : le site compterait vers un `/count` que rien ne sert.
- **Healthcheck** : celui de Traefik sur `/status` *[à vérifier : JSON version/uptime]*, avec
  `healthcheck.hostname` au vhost : sans lui, Traefik envoie `Host: <ip>:8080`, que GoatCounter
  résoudrait peut-être en « site inconnu ». Un healthcheck de conteneur seulement si l'image
  contient `wget` ou `curl` *[à vérifier]*.
- **Journal du conteneur** : les journaux des conteneurs partent dans Loki pour 14 jours
  (`docs/OPERATIONS.md:612-618`). Si GoatCounter écrit un journal d'accès avec l'IP sur sa sortie
  *[à vérifier]*, le couper : sinon la promesse « IP non conservée » est fausse pendant 14 jours.
- **IP réelle** : Caddy pose `X-Forwarded-For` à l'IP du client, Traefik transmet
  `XFF: <client>, <ip caddy>` et `X-Real-IP` (`docs/OPERATIONS.md:226-229`). Sessions coupées, elle
  ne sert plus qu'au pays : mal lue, tout le monde aurait le pays de l'hôte *[à vérifier : l'en-tête
  lu et un éventuel réglage de proxy de confiance]*.
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
     `docker compose up -d goatcounter` sur un poste) et attendre `/status`, donc la migration.
- **`goatcounter-init.sh site`**, interactif : créer le site s'il n'existe pas,
  `goatcounter db create site -vhost ${GOATCOUNTER_VHOST} -user.email ${GOATCOUNTER_ADMIN_EMAIL}
  -user.password …` *[à vérifier : syntaxe v2 ; `-createdb`]*, le mot de passe **demandé au
  prompt**, jamais dans `.env` ; puis rappeler les réglages à poser à la main (§3.5).

**Premier déploiement** : le service est déployé avant que son rôle existe. GoatCounter redémarre
donc en boucle jusqu'à `goatcounter-init.sh db` ; c'est attendu, inoffensif (`deploy.sh` ne
l'attend pas, §3.8), et c'est l'étape qui y met fin. Puis `goatcounter-init.sh site`. Sur un poste,
les deux étapes ne servent que si le profil `analytics` est démarré (§3.7). Sur staging, elles ne
servent pas : le script s'arrête sans rien faire, avec un message, quand `GOATCOUNTER_VHOST` est vide
(§3.7), ce qui laisse aussi `restore.sh` l'appeler sans condition.

### 3.3 Configuration et clés d'environnement

| Clé | Où | Rôle |
|---|---|---|
| `GOATCOUNTER_DB_PASSWORD` | `.env` de prod, `.env.example` (`########`, vide = mesure absente) | Mot de passe du rôle `goatcounter`, hexadécimal. Finit aussi dans l'environnement du backend (`env_file`, `:86-87`) : acceptable, le `.env` est sauvegardé chiffré (`backup.sh:117`) |
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

À poser dans « Settings » à la création, et à reporter dans `docs/OPERATIONS.md` *[noms des
réglages à vérifier]* :

- **Collecte** : garder le référent, la taille d'écran, le pays et le navigateur/système ; **couper
  la région** (et la ville si elle existe) ; **couper les sessions** (« visiteurs uniques ») : ni
  suivi d'un site de club à l'autre (§5.1, condition 3), ni empreinte de session sur chaque page
  vue (§4.5). Le pays est-il déduit **sur place**, par une base GeoIP embarquée, sans service tiers
  *[à vérifier]* ? La politique le dit (§5.2).
- **Tableau de bord public** : désactivé (réglage *Public*).
- **Jetons d'API** : aucun.
- **Rétention des données** : 24 mois (sous les 25 de la CNIL). **Exigée avant l'activation**
  (étape 6) : si le réglage de GoatCounter ne purge pas aussi les tables agrégées *[à vérifier]*,
  une purge planifiée de ces tables est posée d'abord, ou la politique dit que les agrégats sont
  gardés plus longtemps — ce qui est à éviter.
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
# et http://stats.pedalons.internal:8090 — si GoatCounter accepte le vhost avec le port [à vérifier]
```

Rien n'y arrive d'Internet : `HTTP_PORT` est déjà fermé par le pare-feu (`docs/OPERATIONS.md:178-192`),
et Caddy n'a aucun bloc pour ce nom. Le pare-feu reste inchangé. Vérifier depuis une autre machine
qu'une requête par Caddy avec `Host: <vhost>` n'atteint pas le tableau de bord.

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
  ne compte rien. Un service sans tâche ne devrait pas monter ses routeurs dans Traefik
  *[à vérifier à l'étape 0]* ; sinon `/count` y répond 503 et le routeur du tableau de bord
  (`Host(``)`) est en erreur dans le journal de Traefik, sans effet puisque le site n'appelle
  rien. Le snippet Caddy partagé garde son `log_skip` pour les blocs `staging.*`, inoffensif.

### 3.8 Mémoire et déploiement

- Une ligne au tableau mémoire de `docs/OPERATIONS.md` (`:106-117`) et la somme par environnement
  refaite (« 7.3 GB », `:136-143`).
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

(`log_skip` depuis Caddy 2.8, `skip_log` avant : version de l'hôte *[à vérifier]*). C'est
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
  page d'arrivée, une fois.
- **Redirections rendues par un composant** : une route masquée (`hideWhenSingleTeam`) n'a pas de
  `handle` et rend `<Navigate replace>` vers l'accueil (`RouteGenerator.tsx:60-64`, `:87-89`) ;
  une route `authenticated` visitée sans session rend `<Navigate … replace>` vers la connexion
  (`ProtectedRoute.tsx:27`). Toutes deux valident d'abord une navigation. D'où trois règles :
  - **un match sans `routeId` est ignoré** (route masquée) ;
  - **`/404` n'est compté que pour la route `*`**, qui reçoit un
    `handle: { routeId: 'not-found' }` (`RouteGenerator.tsx:132`) ;
  - **l'envoi est différé d'un court délai** (de l'ordre de 100 ms, à mesurer) : une `REPLACE`
    survenue entre-temps remplace le hit en attente au lieu d'en ajouter un. Le cas résiduel
    (vérification de session plus longue que le délai) donne au plus un hit de trop, accepté.
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
| `r` (référent) | L'**hôte** de `document.referrer` s'il est externe, **pour la première page vue du chargement seulement** ; vide ensuite : `document.referrer` ne change pas pendant une navigation côté client, et le republier à chaque page fausserait les chiffres et tracerait le parcours depuis la source | Une URL complète : avec `strict-origin-when-cross-origin`, une navigation interne donne l'URL entière, requête comprise |
| `s` (écran) | Largeur d'écran *[format à vérifier]* | — |
| `b` (robot) | Repris du signal de `count.js` : `navigator.webdriver` et équivalents *[à vérifier]* | — |

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
envoie `GET <countPath>?p=…&t=…&r=…&s=…&b=…&rnd=…` *[à vérifier : `/count` accepte un GET sans le
script, et ses paramètres]* par

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

Côté serveur, GoatCounter écarte en plus les robots d'après l'agent utilisateur *[à vérifier]*.

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

D'après la documentation à vérifier de GoatCounter, pour chaque page vue : le chemin et le titre
envoyés (donc un hôte, un gabarit, le slug de l'équipe pour une page d'équipe, un `routeId` et la
propriété `auth` de la route), l'hôte
référent (première page d'un chargement seulement), la famille de navigateur et le système déduits
de l'agent utilisateur, la largeur d'écran, le pays déduit de l'IP, la date. **L'IP et l'agent
utilisateur bruts ne sont pas stockés.**

**La session** : le schéma v2 de GoatCounter garde une colonne `hits.session` par page vue
*[à vérifier : `\d hits` à l'étape 0]*. Gardée 24 mois à côté de l'hôte, de l'écran, du navigateur,
du système et du pays, elle permettrait de reconstituer le parcours d'une session et, pour un petit
club, ferait de cette combinaison un quasi-identifiant. D'où la coupure des sessions (§3.5). Si
l'étape 0 montre que la colonne reste remplie malgré la coupure, une purge nocturne la vide
(`UPDATE hits SET session = NULL WHERE created_at < now() - interval '1 day'`, à adapter au
schéma), posée avant l'activation et dite dans la politique (§5.2).

**Le slug d'équipe** (§4.2) ajoute une dimension à chaque ligne : sur les pages réservées aux
membres d'une petite équipe privée, une page vue vient presque sûrement de l'un de ses quelques
membres, et la ligne garde son heure, son navigateur, son système, sa largeur d'écran et son pays.
C'est accepté parce que chaque ligne reste isolée (ni session, ni identifiant, rien qui relie deux
pages vues) et que seul le responsable du traitement lit la base ; c'est une raison de plus de ne
pas ouvrir le tableau de bord aux admins de club (`WEB-91`), qui connaissent leurs membres.

Rétention : 24 mois, tables agrégées comprises (§3.5). Pas de sauvegarde (§3.4).

---

## 5. Juridique (`LEGAL-19`)

### 5.1 Conditions d'exemption de la CNIL, et comment chacune est remplie

Source : lignes directrices et recommandation « cookies et autres traceurs » du 17 septembre 2020
(art. 82 de la loi Informatique et Libertés) et la fiche « mesure d'audience ». Résumé de mémoire,
**à relire sur cnil.fr** à l'implémentation, ainsi que la liste des outils jugés exemptables, où
GoatCounter n'est probablement pas : la conformité se démontre alors par la configuration.

| # | Condition | Comment elle est remplie |
|---|---|---|
| 1 | Finalité limitée à la mesure d'audience, pour le seul éditeur | Instance auto-hébergée, un seul compte, celui du responsable du traitement ; tableau de bord public désactivé, aucun jeton d'API (§3.5) ; aucun usage hors des cinq questions du §1. Des chiffres **par équipe** (§4.2) restent une mesure d'audience du service pour son éditeur : savoir quels sites et quelles équipes la plateforme sert. Les communiquer aux clubs serait une autre affaire (une finalité pour un tiers, à relire contre cette condition) : écarté, `WEB-91` |
| 2 | Statistiques anonymes et agrégées seulement | Pas d'identifiant persistant, **pas de session** ni d'empreinte sur les pages vues (§3.5, §4.5) ; chemins réduits au gabarit et au slug de l'équipe, qui nomme un club et non une personne (§4.2) ; aucun champ de compte, aucun état de connexion (§4.2) ; la limite des petites équipes privées est au §4.5 |
| 3 | Pas de suivi d'un site ou d'une application à l'autre | **Sessions coupées** : un site GoatCounter unique pour tous les domaines de club ne relie donc pas la navigation d'un site de club à l'autre (avec les sessions, un visiteur passant de `club-a.fr` à `club-b.fr` garderait la même) ; une instance à nous, aucun tiers ; l'app mobile ne mesure pas. Même constat pour Umami (§2) |
| 4 | Pas de recoupement avec d'autres traitements, pas de transmission à des tiers | Base `goatcounter` séparée, aucun lien avec `pedalons` ; ni cookie ni `Referer` transmis (§4.3, §3.1) ; l'opposition n'est pas stockée sur le compte (§4.4) ; hébergement Scaleway déjà déclaré |
| 5 | IP non conservée, ou tronquée, ou utilisée en mémoire seulement ; pas de géolocalisation plus fine que la ville | IP lue en mémoire pour le pays seulement *[à vérifier]* ; région coupée, pays seul, déduit sur nos serveurs (§3.5) ; journal d'accès du conteneur coupé (§3.1) ; **`/count` absent du journal Caddy** (`log_skip`, §3.9) |
| 6 | Traceurs d'au plus 13 mois | Aucun traceur posé sur le terminal ; la seule clé locale est l'opposition, posée par la personne |
| 7 | Données conservées au plus 25 mois | Rétention à 24 mois, tables agrégées comprises, exigée avant l'activation (§3.5) |
| 8 | Information des personnes | Section dédiée de la politique (§5.2), en FR et en EN |
| 9 | Droit d'opposition facile | DNT et GPC respectés d'office, seul moyen global ; interrupteur sur `/confidentialite` et `/profil/vie-privee` (§4.4), propre à chaque site et à chaque navigateur, ce que la politique dit |

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
| après 48 | §1 | **Nouvelle sous-section « Mesure d'audience du site »** : ce qui est mesuré (§4.5 : pages vues, pas de visites ni de visiteurs ; le site et le type de page, et **pour une page d'équipe, l'identifiant de l'équipe tel qu'il figure dans l'adresse**, équipes privées comprises), ce qui ne l'est jamais (adresse complète, sortie, parcours ou page consultés, paramètres de l'adresse, compte, état de connexion), sans cookie ni session, IP non conservée, pays seul **déduit sur nos serveurs, sans service tiers** *[si l'étape 0 le confirme]*, outil auto-hébergé, « le site seulement : l'application ne mesure pas l'audience », et comment s'y opposer, avec la portée de l'opposition (ci-dessous, §7) |
| 165 | §2 « Automatiquement » | Ajouter « la mesure d'audience du site décrite à la section 1 » à la liste fermée |
| 176-198 | §3 | Nouvelle ligne : « **Mesurer l'audience du site, de façon anonyme et agrégée** : Intérêt légitime (exempté de consentement) ; opposition possible, voir section 7 » |
| **203** | §3 « jamais » | « Des statistiques d'utilisation — nous n'utilisons aucun outil d'analyse ou de suivi » devient « Un suivi de votre navigation d'un site à l'autre, ou des statistiques rattachées à votre compte » (EN : « Tracking you across sites, or usage statistics tied to your account ») |
| 223-241 | §4 sous-traitants | Pas de nouveau tiers. Une phrase, sur le modèle de `:280` : l'outil de mesure d'audience est auto-hébergé chez Scaleway |
| 296 | §5 Firebase | Relire : « aucun composant d'analyse » porte sur Firebase et reste vrai ; préciser « de Firebase » si l'ambiguïté apparaît |
| 304-341 | §6 Conservation | Nouvelle ligne, à côté de `:337` : « **Statistiques d'audience du site** (sans adresse IP, ni identifiant, ni session ; statistiques agrégées comprises) : 24 mois ». Si la purge nocturne du §4.5 est retenue, le dire |
| 337 | §6 Journaux d'accès | Ajouter « hors requêtes de mesure d'audience, qui n'y sont pas écrites » |
| 342 | §6 « Sauvegardes » | Ajouter : « Les statistiques d'audience du site ne sont pas sauvegardées. » (conséquence du §3.4) |
| 355 | §7 opposition | Ajouter : « Pour la mesure d'audience du site : activez Do Not Track ou Global Privacy Control dans votre navigateur, ce qui vaut pour tous nos sites ; ou, sur le site, utilisez l'interrupteur de **Profil → Confidentialité** ou de la page **Confidentialité** (/confidentialite). Cet interrupteur ne vaut que pour ce navigateur et pour ce site : à refaire sur chaque site de club et sur chaque navigateur. L'application ne mesure rien. » (EN : « **Profile → Privacy** », « the **Privacy** page (/privacy) », « The app measures nothing. ») |
| 395-444 | §8 liste | Nouvelle clé : `pedalons-analytics-optout`, *Type* localStorage, *Finalité* retenir votre opposition à la mesure d'audience **sur ce site**, *Durée* jusqu'à ce que vous la retiriez ou effaciez les données du site |
| **446** | §8 conclusion | « Nous n'utilisons aucun cookie de suivi, d'analyse ou de publicité. Aucun consentement… » devient : « Nous n'utilisons aucun cookie de suivi, d'analyse ou de publicité. La mesure d'audience du site n'utilise aucun cookie et remplit les conditions d'exemption de consentement de la CNIL (section 1) ; vous pouvez vous y opposer à tout moment (section 7). Aucun consentement n'est donc requis : … » (le reste inchangé) |
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
  (arp242). S'il est abandonné, l'image cesse d'avoir des correctifs. Atténuation : l'expéditeur
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
- **Réécriture du `Host`** : si Traefik ne l'applique pas, rien n'est compté (requêtes refusées
  par GoatCounter, sans site). À tester à l'étape 0, avant d'écrire le reste.
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

---

## 8. Étapes, dans l'ordre

Chaque étape est livrable seule ; le compteur ne s'allume qu'à l'étape 6.

| # | Étape | Fichiers | Taille | Tests |
|---|---|---|---|---|
| 0 | **Vérifier GoatCounter sur un poste** : version et image (binaire de healthcheck, journal d'accès), `GET /count` sans script et ses paramètres, **qu'il ne prend jamais le `Referer` comme repli de `p` ou de `r`**, résolution du site par `Host` et réécriture par Traefik, suppression de `Cookie` et `Referer` par le middleware, en-tête d'IP lu derrière deux proxys, option `-tls` et cookies du tableau de bord en `http://`, **coupure des sessions et schéma (`\d hits` : la colonne `session` reste-t-elle vide ?)**, pays résolu sur place ou non, noms des réglages de collecte, *Public*, rétention et tables agrégées, accès au tableau de bord par le routeur `Host()` et un tunnel, routeurs d'un service Swarm à 0 réplique (le cas de staging, §3.7). Mettre à jour ce plan : retirer chaque *[à vérifier]* ou basculer sur Umami | ce plan | S | Manuels, consignés ici |
| 1 | **Service et base** (`OPS-36`) : service `goatcounter` (commande en liste, middleware `count-headers`, routeur du tableau de bord, stop-first), overlays local et e2e, clés `.env.example`, `scripts/goatcounter-init.sh` (`db`, `site`), vérification des clés, `goatcounter` dans `--hold-app` et à 0 réplique sans clés (`deploy.sh`), appel de `goatcounter-init.sh db` (`restore.sh`), section `OPERATIONS.md` (création, réglages, tunnel, restauration, mémoire, base non sauvegardée, `log_skip` dans « Access logs ») | `docker-compose.yml`, `docker-compose.local.yml`, `docker-compose.e2e.yml`, `.env.example`, `scripts/goatcounter-init.sh`, `scripts/deploy.sh`, `scripts/restore.sh`, `docs/OPERATIONS.md` | M | `docker stack config` / `docker compose config` sur les trois combinaisons ; `scripts/e2e.sh` ne démarre pas `goatcounter` ; `deploy.sh` refuse une seule des deux clés `GOATCOUNTER_*` posée, et `PEDALONS_ANALYTICS_COUNT_PATH` sans elles ; les deux vides (staging), il déploie `goatcounter` à 0 réplique et `goatcounter-init.sh db` ne fait rien ; un `curl` sur `/count` depuis deux hôtes, avec un cookie et un `Referer`, atterrit dans le même site sans eux |
| 2 | **Drapeau dans `/api/config`** (`API-117`) : `ConfigDto.analytics` nullable, `@ConfigProperty Optional<String>`, bump mineur, régénération des clients | `ConfigDto.java`, `ConfigService.java`, `application.properties`, contrat, `frontend/src/api/dto/configDto.ts`, client mobile régénéré | XS | Test backend de `ConfigService` (null sans propriété, rempli sinon) — **à lancer par le propriétaire**, pas par l'agent |
| 3 | **Compteur côté site** (`WEB-90`) : `lib/analytics/` (`toCountHit`, expéditeur `fetch`, garde-fous), abonnement dans `getRouter()`, `handle` de la route `*`, interrupteur d'opposition sur `/profil/vie-privee` et dans `PrivacyPolicyPage.tsx` hors du Markdown, libellés FR/EN (portée « ce navigateur et ce site ») | `frontend/src/lib/analytics/*`, `frontend/src/App.tsx`, `frontend/src/config/RouteGenerator.tsx`, la page de la route `profile-privacy`, `pages/legal/PrivacyPolicyPage.tsx`, `locales/{fr,en}/common.json` | M | Vitest : `toCountHit` sur **toutes** les entrées de `routesConfig` × `LOCALES`, URL concrètes aux paramètres sentinelles (`previewId='SECRET123'`, `rideSlug='sortie-secrete'` et une sentinelle par autre paramètre, `teamSlug='equipe-privee'`, `?token=SECRET`, `#frag`) → **`equipe-privee` apparaît exactement comme segment de `p` pour chaque route qui a `:teamSlug`, à la place de ce seul marqueur**, aucune autre sentinelle, aucun `?` ni `#` dans `p` ; un `teamSlug` mal formé (`Equipe%20X`, `a@b.fr`, plus de 200 caractères) reste `:teamSlug` ; le même chemin compté sur un hôte épinglé (`pinnedHistory`) et sur l'hôte partagé ; `t` sans `document.title` ni état de session ; référent interne → vide, externe → hôte seul, **et seulement au premier hit** ; options du `fetch` (`credentials: 'omit'`, `referrerPolicy: 'no-referrer'`, `keepalive`), jamais `sendBeacon` ; aucun envoi si config nulle, DNT, GPC, opposition (**y compris après rechargement du module**), `webdriver`, `localhost` ; import du module sans `window`. Routeur mémoire : un envoi au départ (avec et sans `hydrationData`), un par `PUSH`, un par `POP`, aucun sur `REPLACE` de même route, un sur redirection de loader, **un seul sur une route masquée et sur une route protégée visitée sans session**, `/404` seulement pour `*`. Playwright : `e2e/analytics-off.e2e.ts`, aucune requête vers `/count` sur un parcours de quelques pages (la pile e2e n'a ni drapeau ni service) |
| 4 | **Politique FR/EN** (`LEGAL-19`) : les passages du §5.2, relecture des conditions CNIL sur cnil.fr | `privacy/privacy-policy.{fr,en}.md` | S | Relecture ; parité ligne à ligne vérifiée par `diff <(grep -c '' …)` |
| 5 | **Déploiement sans drapeau** : service et base en prod (boucle de redémarrage attendue jusqu'à `goatcounter-init.sh db`), `goatcounter-init.sh site`, réglages du §3.5, tunnel vérifié, tableau de bord injoignable par Caddy ; `log_skip` dans le snippet Caddy et **chaque bloc de club et d'alias vérifié** ; politique en ligne ; **précondition du §5.3 vérifiée en base** (aucun membre réel n'a accepté la politique actuelle), sinon e-mail à chaque membre avant l'étape 6 ; staging vérifié sans tâche `goatcounter` | hôte | XS | Manuels, consignés dans `OPERATIONS.md` |
| 6 | **Activation**, seulement si la rétention de 24 mois couvre les tables agrégées (ou leur purge planifiée est posée) et, le cas échéant, la purge nocturne de `hits.session` : `PEDALONS_ANALYTICS_COUNT_PATH=/count` dans le `.env` de prod, redéploiement | `.env` de prod | XS | Une visite par un navigateur sans DNT apparaît dans le tableau de bord avec le gabarit ; la même avec DNT n'apparaît pas ; le journal du conteneur ne contient aucune IP de visiteur, celui de Caddy aucune ligne `/count` ; `hits.session` vide |

Au bout d'un mois de production : relire les chiffres contre les cinq questions du §1, puis
archiver ce plan (`docs/plans/archive/`, avec sa ligne dans le README des
archives) et déplacer les entrées livrées dans `LEDGER_DONE.md`.
