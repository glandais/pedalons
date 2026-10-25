# Publier les images Docker sur un registry public — étude

Écrit le 25 octobre 2026. **État : étude, rien n'est décidé ni implémenté.** Ledger `OPS-54`.
Rouvre en partie `AUD-1` (« à rouvrir avec un registry ») sans le trancher : le déploiement reste
lancé à la main depuis l'hôte.

L'état décrit ici a été vérifié dans le code le 25 octobre 2026 (`develop`, `37415fdb5`) :
`build.sh`, `scripts/_image_tag.sh`, `scripts/deploy.sh`, `docker-compose.yml`,
`frontend/Dockerfile`, `backend/src/main/resources/application.properties`, les cinq workflows de
`.github/workflows/`, et `docs/OPERATIONS.md` (Deployment, Rolling updates, Restoring). Les faits
sur les registries sont au §9, avec ce qui reste **à vérifier** avant la première ligne.

---

## Sommaire

1. [En une page](#1-en-une-page)
2. [Ce qui existe aujourd'hui](#2-ce-qui-existe-aujourdhui)
3. [Quel registry](#3-quel-registry)
4. [Rendre les images publiables](#4-rendre-les-images-publiables)
5. [Le workflow de publication](#5-le-workflow-de-publication)
6. [La livraison : `deploy.sh` et compose](#6-la-livraison--deploysh-et-compose)
7. [Sécurité de la chaîne](#7-sécurité-de-la-chaîne)
8. [Ce que ça change ailleurs](#8-ce-que-ça-change-ailleurs)
9. [Faits externes, hypothèses à vérifier](#9-faits-externes-hypothèses-à-vérifier)
10. [Découpage, ordre et tailles](#10-découpage-ordre-et-tailles)
11. [Décisions à prendre par le propriétaire](#11-décisions-à-prendre-par-le-propriétaire)
12. [Délibérément dehors](#12-délibérément-dehors)

---

## 1. En une page

**Aujourd'hui**, chaque hôte construit ses images lui-même : `cd ~/prod && ./build.sh &&
scripts/deploy.sh`. Staging et prod construisent chacune leur image du même commit, sous des tags
différents (`pedalons-backend:pedalons-prod-<sha12>`, `…:pedalons-staging-<sha12>`). Ce qu'on a
recetté en staging n'est donc **pas** l'artefact qui part en prod : c'est un second build du même
source, avec ses propres build-args.

**Proposition** :

- **GitHub Container Registry (GHCR)**, `ghcr.io/glandais/pedalons-backend` et
  `ghcr.io/glandais/pedalons-frontend`, publics. Le dépôt l'est déjà : l'image n'expose rien que le
  source n'expose (§4.1). Le push se fait avec le `GITHUB_TOKEN` du workflow, sans aucun secret à
  créer, et l'hôte tire anonymement, sans aucun identifiant (§3).
- **Un workflow `images.yml`** construit les deux images à chaque push sur `develop`, en
  `linux/amd64` + `linux/arm64`, les tague **`<sha12>`** (sans `ENV_NAME`), y attache une
  attestation de provenance et un SBOM (§5).
- **`deploy.sh` tire au lieu de construire** : il résout `ghcr.io/…:<sha12>` en digest, déploie
  `image@sha256:…` et vérifie l'attestation avant (§6). Staging et prod déploient **le même digest**
  : la recette porte sur l'artefact livré.
- **`build.sh` reste**, pour le poste de travail, la suite e2e et le **repli** si GitHub ou GHCR est
  indisponible (`scripts/deploy.sh --local`). Le registry ne devient pas un point de défaillance
  unique de la restauration.

Coût : un workflow (~S), une réécriture partielle de `deploy.sh` (~M), deux build-args à sortir du
build du frontend (~S), la doc d'exploitation (~S). Rien dans le backend ni dans le code applicatif.

Gain : un artefact unique promu de staging à prod ; des images multi-arch (le poste Apple Silicon
tire la même image que le serveur) ; une restauration qui n'a plus à recompiler (§8) ; plus de
Maven ni de pnpm ni de 2 Go de cache de build sur les hôtes ; un retour arrière vers n'importe quel
commit encore dans le registry, au-delà des cinq builds locaux.

---

## 2. Ce qui existe aujourd'hui

| Où | Ce qui compte pour l'étude |
|---|---|
| `build.sh` | Backend par Jib (`mvn package -Dquarkus.container-image.build=true`, plateforme = celle du démon local), frontend par `docker build`. Tague `pedalons-<svc>:${ENV_NAME}` et, depuis un arbre propre, `pedalons-<svc>:${ENV_NAME}-<sha12>`. `carry_over` donne le tag du commit à l'image non reconstruite. |
| `scripts/_image_tag.sh` | Le tag par commit n'est **jamais déplacé** : c'est ce qui fait rouler Swarm et garde la spec précédente pour `docker service rollback`. `ENV_NAME` est dans le tag « parce que prod et staging partagent le magasin d'images de l'hôte ». |
| `scripts/deploy.sh` | Exige que `pedalons-<svc>:${ENV_NAME}<suffix>` existe localement, exporte `BACKEND_IMAGE_SUFFIX` / `FRONTEND_IMAGE_SUFFIX`, `docker stack deploy`, attend la convergence (compare l'image de la spec et celle des conteneurs à la référence attendue), puis garde `KEEP_BUILDS=5` builds par image. Swarm avertit qu'il ne peut pas résoudre l'image sur un registry. |
| `docker-compose.yml` | `image: pedalons-backend:${ENV_NAME}${BACKEND_IMAGE_SUFFIX:-}`, idem frontend. Toutes les autres images viennent déjà d'un registry public (Docker Hub, `ghcr.io/imgproxy`…), goatcounter épinglée par digest. |
| `frontend/Dockerfile` | Deux build-args propres à un environnement : `VITE_BUILD_SOURCEMAP` (`FRONTEND_SOURCEMAP` du `.env` : `true` en staging, `false` en prod) et `FRONTEND_PREFETCH_AUDIT` (outil de diagnostic, `false` partout par défaut). Rien d'autre ne vient du `.env` au build. |
| Backend (Jib) | Aucun secret dans l'image : tout ce qui est sensible est lu à l'exécution (`${ENCRYPTION_KEY:}`, `STADIAMAPS_API_KEY`, `PEDALONS_BIKETEAM_*`…), les clés JWT sont montées depuis `data/keys`. |
| `.github/workflows/` | `ci.yml` (tests, filtré par chemins), `e2e.yml` (nuit, construit ses images), `codeql.yml`, `karoo-release.yml`, `mobile-release.yml`. Aucun ne pousse d'image ni ne déploie — à dessein (`AUD-1`). |
| Restauration (`OPERATIONS.md`, Restoring) | Les images ne sont pas dans les sauvegardes : on les reconstruit avec `./build.sh` au commit noté dans le `MANIFEST`. |
| Ledger | `ISSUE-10` (staging sert ses `.map`), `ISSUE-1` (archiver les sourcemaps avec l'image plutôt que les servir), `AUD-1` (pas de CD, à rouvrir avec un registry). |

Conséquence directe : **l'image dépend de l'environnement par un seul point**, les sourcemaps.
`FRONTEND_PREFETCH_AUDIT` est un outil de poste qu'on n'active pas sur un hôte. Tout le reste est
déjà configuré à l'exécution, ce qui rend une image unique pour tous les environnements possible
sans toucher au code applicatif.

---

## 3. Quel registry

| Critère | **GHCR** | Docker Hub | Registry auto-hébergé (`registry:2` sur l'hôte) |
|---|---|---|---|
| Coût d'une image publique | gratuit (§9) | gratuit, dépôts publics illimités sur un compte personnel | gratuit, disque de l'hôte |
| Pull anonyme depuis l'hôte | oui, sans limite documentée pour un paquet public (§9, à vérifier) | oui mais limité par IP (100 / 6 h, ou moins selon les sources, §9) | — |
| Identifiant pour pousser depuis Actions | `GITHUB_TOKEN` + `permissions: packages: write`, **aucun secret** | un jeton d'accès Docker Hub dans les secrets du dépôt | il faudrait exposer le registry à GitHub, ou pousser depuis l'hôte |
| Lien au dépôt | le label `org.opencontainers.image.source` rattache le paquet au dépôt (page, visibilité, droits) | aucun | aucun |
| Attestations | `actions/attest-build-provenance` les stocke chez GitHub, `gh attestation verify` les vérifie | possibles en attestations OCI à côté de l'image (buildx), sans vérification intégrée | à monter soi-même |
| Visibilité / découverte | onglet *Packages* du dépôt | le catalogue Docker Hub, meilleure découverte | aucune |
| Point unique de défaillance | GitHub (déjà le cas pour le code) | un second fournisseur | l'hôte lui-même — ne protège de rien |

**Recommandation : GHCR.** Il ne demande ni secret dans GitHub ni identifiant sur l'hôte, ce qui
préserve exactement l'argument d'`AUD-1` (aucune clé de l'hôte chez GitHub, aucun accès de la CI à
l'infrastructure). Il est déjà la dépendance dont le code vient, et ses attestations se vérifient
d'une commande. Docker Hub n'apporte que la découverte, qui n'a pas d'intérêt pour une application
qu'on ne distribue pas comme un produit à installer ; un miroir pourra s'ajouter plus tard
(`docker buildx imagetools create` recopie un manifeste multi-arch d'un registry à l'autre).

Le registry auto-hébergé est écarté : sur un Swarm mono-nœud il n'apporte rien que le magasin
d'images local n'ait déjà, et il ne règle pas la question « construire ailleurs que sur l'hôte ».

**Nommage** : `ghcr.io/glandais/pedalons-backend` et `ghcr.io/glandais/pedalons-frontend` gardent
les noms actuels, ce qui limite le diff de `docker-compose.yml` et des scripts.
`ghcr.io/glandais/pedalons/backend` (un espace par dépôt) est possible aussi ; c'est une question de
goût, §11.

---

## 4. Rendre les images publiables

### 4.1 Ce qu'une image publique expose

Le dépôt est public : le code, le `pom.xml`, le `pnpm-lock.yaml` et donc chaque version de
dépendance le sont déjà. Une image publique n'ajoute que :

- **les couches de base** (`ubi9/openjdk-25-runtime`, `node:26-alpine`) et leurs versions — déductibles
  du dépôt aussi ;
- **le bundle compilé**, lisible sans sourcemap à partir du source public ;
- **les sourcemaps si elles y sont** — elles ne révèlent rien que le dépôt ne montre, mais §4.2.

Vérifié ce qui **ne doit pas** y être et n'y est pas aujourd'hui :

- pas de `.env` : le contexte du frontend est `frontend/`, celui de Jib le jar ; `frontend/.env`
  (le `VITE_API_TARGET` du dev) n'est pas exclu par `.dockerignore`, mais n'est lu que par le
  serveur de dev — **à exclure quand même** (une ligne) pour qu'un `.env` de poste ne puisse jamais
  partir dans une image publique ;
- `e2e/.auth` (jetons de session) est exclu, `docs/` aussi ;
- clés JWT : montées, jamais copiées ; secrets backend : lus à l'exécution.

Un contrôle automatique, dans le workflow, avant le push : lister les fichiers de l'image et
échouer sur `*.pem`, `.env*`, `*.key`, `e2e/.auth`. C'est quelques lignes et cela couvre
l'oubli futur plutôt que l'état présent.

### 4.2 Une image pour tous les environnements

**Sourcemaps.** C'est la seule différence réelle entre l'image de staging et celle de prod. Trois
voies :

1. **Image sans `.map`, sourcemaps en artefact à part** (recommandé). Le build les produit
   (`VITE_BUILD_SOURCEMAP=true`), une étape les extrait de `dist/client/assets/*.map` et les publie
   comme artefact du workflow, ou comme une seconde image `pedalons-frontend:<sha12>-sourcemaps`
   (`FROM scratch`, rien que les `.map`), puis l'image servie est construite sans. C'est exactement
   ce que demande `ISSUE-1` (« ne pas servir les `.map` mais les archiver avec l'image ») et cela
   règle `ISSUE-10` du même coup. Coût : une cible `sourcemaps` dans le `Dockerfile` (multi-stage,
   même stage `build`, donc un seul `pnpm build`).
2. **Les garder dans l'image unique**, donc servies aussi en prod. Le dépôt étant public, c'est
   défendable (`ISSUE-10` l'envisage) ; mais c'est 408 fichiers et plusieurs Mo servis pour rien, et
   la décision « staging oui, prod non » disparaît.
3. **Deux tags par commit**, `<sha12>` et `<sha12>-debug`. Ramène la divergence staging/prod qu'on
   cherche à supprimer.

**`FRONTEND_PREFETCH_AUDIT`** : outil de diagnostic, à `false` sur tous les hôtes. L'image publiée
le laisse à `false` ; qui veut l'audit construit localement (`build.sh`, inchangé). Rien à faire
d'autre que le documenter.

**Tag sans `ENV_NAME`.** Il y était parce que deux builds du même commit pour deux environnements
pouvaient différer. Avec une image unique, `ghcr.io/glandais/pedalons-backend:<sha12>` est le même
objet pour staging et prod — c'est le but. Le tag reste par commit et jamais déplacé, ce que
`_image_tag.sh` exige pour que Swarm roule et garde de quoi revenir en arrière. Mieux : `deploy.sh`
déploie par **digest** (§6), ce qui rend la question de l'immuabilité du tag sans objet.

### 4.3 Multi-arch

Le serveur est `amd64`, le poste Apple Silicon `arm64` (`build.sh` choisit aujourd'hui la
plateforme du démon local).

- **Backend** : Jib construit plusieurs plateformes d'un coup quand il **pousse** vers un registry
  (`QUARKUS_JIB_PLATFORMS=linux/amd64,linux/arm64` + `quarkus.container-image.push=true`) — pas en
  chargement dans le démon local, d'où le choix actuel de `build.sh`. Le jar est le même, seules les
  couches de base diffèrent : aucun coût d'émulation.
- **Frontend** : les dépendances d'exécution sont du JavaScript pur (vérifié : aucune des
  `dependencies` n'a de binaire natif ; `sharp`, `esbuild`, `@swc/core` ne servent qu'au build).
  Les stages `base`, `prod-deps` et `build` peuvent donc tourner en `FROM --platform=$BUILDPLATFORM`,
  natifs sur le runner `amd64`, et seul le stage final change de base selon la cible. Pas de QEMU
  pour `pnpm build`, qui serait lent. À vérifier par un `docker buildx build --platform
  linux/amd64,linux/arm64` (§9).

---

## 5. Le workflow de publication

Nouveau fichier `.github/workflows/images.yml` — séparé de `ci.yml`, dont le filtrage par chemins
n'a pas de sens ici : chaque commit de `develop` doit avoir **ses deux images**, comme `carry_over`
le garantit aujourd'hui.

**Déclencheurs** : `push` sur `develop`, et `workflow_dispatch` (reconstruire un commit). Jamais
`pull_request` : une PR externe n'obtient ni `packages: write` ni d'image publiée.

**Faut-il attendre la CI verte ?** Deux possibilités :

- `workflow_run` sur la fin de `CI` avec `conclusion == success`, puis checkout de
  `github.event.workflow_run.head_sha` — l'image n'existe que si les tests passent ;
- ou en parallèle de la CI, et c'est `deploy.sh` qui refuse un commit dont la CI n'est pas verte.

Le premier est plus simple à raisonner (« une image publiée est un commit testé ») ; il ajoute la
durée de la CI au délai avant de pouvoir déployer. Mais `ci.yml` saute ses jobs quand le chemin
n'a pas changé, donc « CI success » sur un commit qui ne touche que `docs/` ne dit rien des tests
backend — sans gravité, puisque le code n'a pas changé. Recommandé : `workflow_run`.

**Esquisse** (à affiner à l'implémentation) :

```yaml
permissions:
  contents: read
  packages: write        # pousser sur ghcr.io/glandais/*
  id-token: write        # attestation (OIDC, Sigstore)
  attestations: write

jobs:
  backend:
    steps:
      - checkout, setup-java 25 (comme ci.yml)
      - docker/login-action → ghcr.io, ${{ github.actor }}, ${{ secrets.GITHUB_TOKEN }}
      - mvn -B package -DskipTests
          -Dquarkus.container-image.build=true -Dquarkus.container-image.push=true
          -Dquarkus.container-image.registry=ghcr.io
          -Dquarkus.container-image.group=glandais
          -Dquarkus.container-image.name=pedalons-backend
          -Dquarkus.container-image.tag=<sha12>
          -Dquarkus.jib.platforms=linux/amd64,linux/arm64
          (+ labels OCI : source, revision, version = pedalons.api.version)
      - actions/attest-build-provenance (subject-name, subject-digest, push-to-registry: true)
  frontend:
    steps:
      - checkout, cp privacy/*.md (comme build.sh)
      - docker/setup-buildx-action, docker/login-action
      - docker/build-push-action : platforms amd64+arm64, tags :<sha12>,
          cache-from/to: type=gha, provenance + sbom
      - cible sourcemaps → artefact ou image -sourcemaps (§4.2)
      - contrôle du contenu (§4.1), attest-build-provenance
```

**Tags** : `<sha12>` seulement, immuable par convention. Un alias mobile `develop` est tentant
pour le poste, mais un alias est ce qu'on a appris à ne pas déployer ; à n'utiliser que par compose
sur un poste, jamais par `deploy.sh`. Un tag de version (`api-11.5.3`) n'aurait pas de sens : le
contrat d'API ne change pas à chaque commit.

**Rétention** : GHCR garde tout tant qu'on ne supprime pas. Une image de commit fait de l'ordre de
quelques centaines de Mo (deux plateformes, couches communes partagées). Garder les 50 derniers
`<sha12>` plus tout ce qui a été déployé en prod (marqué par un tag `prod-<date>` ajouté par
`deploy.sh` ? — demanderait un jeton sur l'hôte, voir §7) via `actions/delete-package-versions` ou
équivalent, en tâche hebdomadaire. **À décider** (§11) ; sans élagage, rien ne casse, ça grossit.

**Durée** : le backend sans tests, avec cache Maven, prend quelques minutes ; le frontend, avec le
cache `gha` de buildx, autant. Le délai « merge → déployable » devient CI + images, de l'ordre de
10 à 15 min, contre le temps d'un `./build.sh` sur l'hôte aujourd'hui.

---

## 6. La livraison : `deploy.sh` et compose

### 6.1 `docker-compose.yml`

Une référence complète par service, fournie par `deploy.sh`, avec pour défaut l'image locale du
poste :

```yaml
backend:
  image: ${BACKEND_IMAGE:-pedalons-backend:${ENV_NAME}}
frontend:
  image: ${FRONTEND_IMAGE:-pedalons-frontend:${ENV_NAME}}
```

L'interpolation imbriquée est acceptée par compose v2 ; `docker stack deploy` aussi, mais
`deploy.sh` exporte toujours la variable, donc le défaut ne sert qu'au poste. **À vérifier** sur les
deux outils (§9) — sinon, `deploy.sh` exporte aussi un défaut et le fichier garde la forme
`${BACKEND_IMAGE}`. `BACKEND_IMAGE_SUFFIX` / `FRONTEND_IMAGE_SUFFIX` disparaissent.

Un poste peut alors aussi lancer l'image publiée d'un commit, sans rien construire :
`BACKEND_IMAGE=ghcr.io/glandais/pedalons-backend:<sha12> docker compose --profile app up -d`.

### 6.2 `deploy.sh`

Le flux devient :

```bash
cd ~/prod && git pull && scripts/deploy.sh     # tire et déploie le commit extrait
scripts/deploy.sh --rev <commit>               # un commit antérieur, tiré du registry
scripts/deploy.sh --local                      # repli : l'image locale de ./build.sh (aujourd'hui)
```

Ce qui change dans le script :

1. **Résoudre l'image** : `ghcr.io/glandais/pedalons-<svc>:${suffix#-}`. Si elle n'existe pas
   encore (workflow en cours), attendre jusqu'à `IMAGE_TIMEOUT` en sondant
   `docker buildx imagetools inspect` — ou échouer tout de suite avec « image absente, workflow en
   cours ? » ; plus simple, et l'humain relance. Recommandé : échouer, avec l'URL du workflow.
2. **Vérifier la provenance** (§7) : `gh attestation verify oci://… --repo glandais/pedalons`, ou
   `cosign verify-attestation`. Refuser une image sans attestation de ce dépôt et de ce workflow.
3. **Tirer et figer le digest** : `docker pull`, puis `docker image inspect -f '{{index
   .RepoDigests 0}}'` → exporter `BACKEND_IMAGE=ghcr.io/…@sha256:…`. Swarm enregistre le digest,
   l'avertissement « could not resolve image » disparaît, et le tag ne peut plus bouger sous le
   service.
4. **Attente de convergence** : `rollout_state` compare aujourd'hui la référence de la spec
   (`${spec_image%%@*}`) et celle du conteneur (`docker ps --format '{{.Image}}'`) à
   `pedalons-<svc>:${ENV_NAME}<suffix>`. À réécrire pour comparer le **digest** : c'est plus juste
   que la comparaison par nom, et le commentaire sur `carry_over` (« l'ancienne tâche passerait
   pour la nouvelle ») tombe, puisqu'un digest identique *est* la même image et qu'un rollout sans
   changement d'image n'a rien à attendre.
5. **Élagage** : les images locales deviennent un cache. `KEEP_BUILDS` peut rester (même logique,
   motif `ghcr.io/glandais/pedalons-<svc>:[0-9a-f]{12}` et images référencées par digest), mais un
   `--rev` sur une image élaguée se règle par un `docker pull`, plus par un rebuild.
6. **`--local`** garde exactement le comportement actuel (`pedalons-<svc>:${ENV_NAME}<suffix>`,
   construit par `build.sh`) : repli si GitHub est indisponible, ou pour déployer un correctif
   avant la fin du workflow.

Ce qui ne change pas : la vérification d'arbre propre (le `.env` et le compose viennent toujours du
checkout), le réseau partagé, les clés JWT, `--hold-app`, GoatCounter, les stacks `--shared` et
`--monitoring`.

**`docker stack deploy --with-registry-auth`** : inutile tant que les images sont publiques.

### 6.3 Promotion staging → prod

```text
merge sur develop ─► CI ─► images.yml ─► ghcr.io/…:<sha12> (digest D)
                                            │
            ~/staging : git pull && deploy.sh ─► D   (recette)
            ~/prod    : git checkout <sha12> && deploy.sh ─► D   (le même octet près)
```

La prod déploie un commit précis, déjà vu en staging, et obtient le même digest. Rien n'oblige à
passer par staging ; rien ne l'impose non plus, comme aujourd'hui.

---

## 7. Sécurité de la chaîne

- **Aucun secret nouveau.** GitHub pousse avec le `GITHUB_TOKEN` éphémère du job, limité à
  `packages: write` ; l'hôte tire anonymement. Aucun identifiant de l'hôte chez GitHub, aucun
  identifiant GitHub sur l'hôte : l'argument d'`AUD-1` tient.
- **Ce qui devient attaquable** : qui peut pousser sur `develop` (ou modifier `images.yml`) peut
  publier une image que l'hôte tirera. C'est **déjà** le cas aujourd'hui : l'hôte compile ce qu'il
  `git pull`. La surface est la même, déplacée du checkout vers le workflow. Garde-fous : protection
  de branche sur `develop`, actions épinglées (comme le reste des workflows), Dependabot qui suit
  déjà les actions.
- **Vérification à l'arrivée** : l'attestation de provenance (SLSA, signée par Sigstore via l'OIDC
  du workflow) dit *quel dépôt, quel workflow, quel commit* ont produit le digest. `deploy.sh` la
  vérifie avant de déployer (§6.2) : une image poussée à la main, ou depuis un fork, est refusée.
  Coût sur l'hôte : `gh` (déjà utile) ou `cosign`, un binaire.
- **Tag ≠ contenu** : GHCR ne rend pas un tag immuable (à vérifier, §9). Le déploiement par digest
  et la vérification d'attestation rendent ce point sans conséquence.
- **Taguer `prod-*` depuis l'hôte** (pour la rétention, §5) demanderait un jeton d'écriture sur
  l'hôte. **Écarté** : la rétention se décide côté GitHub (garder les N derniers, et ceux qu'un
  tag git `deploy/prod/<date>`, poussé à la main, désigne — si on y tient).
- **Scan de vulnérabilités** : une image publique sera scannée par d'autres ; autant le faire
  soi-même. Trivy ou Grype dans le workflow, en information (pas bloquant au début), ou l'onglet
  *Security* via un SARIF. Optionnel, §10.

---

## 8. Ce que ça change ailleurs

| Où | Changement |
|---|---|
| `docs/OPERATIONS.md` — Deployment | `cd ~/prod && git pull && scripts/deploy.sh` ; `./build.sh` devient le repli. Retirer « No registry ». |
| `docs/OPERATIONS.md` — Rolling updates | Tag par commit sans `ENV_NAME`, déploiement par digest, `--rev` tire du registry, `--local`. |
| `docs/OPERATIONS.md` — Restoring | Étape 2 : `docker pull` au commit du `MANIFEST` au lieu de `./build.sh` — une restauration n'a plus besoin de Maven, pnpm ni de la JDK sur l'hôte de secours. Garder `./build.sh` comme repli documenté. |
| `scripts/restore.sh` | Il source `_image_tag.sh` : vérifier ce qu'il en attend (le tag des images à tenir à zéro réplique). |
| `scripts/_image_tag.sh` | Garde `image_suffix` / `worktree_dirty` ; gagne la référence registry. Son en-tête (« ENV_NAME stays in the tag because… ») est à réécrire. |
| `build.sh` | Inchangé pour le poste et l'e2e. Optionnellement `--push` pour publier depuis le poste en dépannage — **déconseillé** : une image sans attestation de workflow serait refusée par `deploy.sh`, ce qui est voulu. |
| `README.md` | « Running the full stack locally » : mention de `BACKEND_IMAGE=ghcr.io/…` pour lancer un commit publié sans le construire. |
| `.github/workflows/e2e.yml` | Option : la nuit, tester les images publiées du commit plutôt que d'en reconstruire — on testerait l'artefact livré. Mais l'e2e veut parfois tester un build avec des options de poste ; à garder tel quel au début. |
| `.github/dependabot.yml` | Rien : les images de base sont dans le `Dockerfile` et `application.properties`, déjà suivies. |
| Hôtes | Plus besoin de JDK, Maven, Node, pnpm pour déployer (ils peuvent rester pour le repli). Le cache Jib (`target/jib-cache`) et le cache buildx cessent de grossir sur l'hôte. |
| Ledger | `OPS-54` (cette étude) ; à la livraison, `ISSUE-10` et une partie d'`ISSUE-1` ; `AUD-1` reste dehors, sa raison est à mettre à jour (« sans registry » devient faux). |

---

## 9. Faits externes, hypothèses à vérifier

Lus le 25 octobre 2026, à revérifier au moment de l'implémentation :

- **GHCR** : les paquets publics sont gratuits (stockage et bande passante) et se tirent
  anonymement, d'après la documentation GitHub Packages et l'annonce de disponibilité générale.
  GitHub s'est engagé à prévenir un mois avant tout changement de prix. **À vérifier** : la page de
  facturation actuelle de GitHub Packages, et l'absence de limite de débit sur les pulls anonymes
  d'un paquet public.
- **Docker Hub** : pulls anonymes limités par IPv4 ou par /64 IPv6 — 100 par 6 h selon la
  documentation Docker consultée, 10 par heure selon des annonces de début 2025, et la doc a changé
  plusieurs fois depuis. Non bloquant pour un seul hôte, mais c'est un risque de plus.
- **Jib multi-plateforme** : n'est possible qu'en push vers un registry, pas en chargement dans le
  démon (`dockerBuild`). **À vérifier** avec la version de Quarkus du moment
  (`quarkus.jib.platforms`).
- **Frontend multi-arch sans QEMU** : hypothèse fondée sur l'absence de dépendance d'exécution
  native. **À vérifier** par un build `--platform linux/amd64,linux/arm64` et un démarrage du
  conteneur `arm64` sur le poste.
- **Interpolation imbriquée** `${A:-${B}}` : supportée par compose v2 ; **à vérifier** avec
  `docker stack config` / `docker stack deploy` de la version Docker des hôtes.
- **Immuabilité des tags sur GHCR** : à ma connaissance non proposée ; sans conséquence avec un
  déploiement par digest.
- **`gh attestation verify`** pour une image OCI : `gh attestation verify oci://ghcr.io/… --repo
  glandais/pedalons`, à essayer sur une première image (dépend d'un accès réseau à l'API GitHub
  depuis l'hôte, sans authentification pour un dépôt public — **à vérifier**).

---

## 10. Découpage, ordre et tailles

Chaque étape est livrable seule et ne casse pas le flux actuel jusqu'à la 5.

1. **Image unique** (S) — cible `sourcemaps` dans `frontend/Dockerfile`, `frontend/.env` exclu de
   l'image, l'image servie sans `.map`. `build.sh` inchangé dans son usage. Règle `ISSUE-10`.
2. **`images.yml`** (S) — build + push multi-arch sur `develop`, labels OCI, contrôle du contenu,
   attestations. Rendre les deux paquets publics à la main une fois (un paquet GHCR naît privé
   s'il n'est pas lié à un dépôt public — à vérifier) et les lier au dépôt.
3. **Essai sur le poste** (XS) — `BACKEND_IMAGE=ghcr.io/…:<sha12> docker compose --profile app up`
   sur Apple Silicon : valide le multi-arch et le défaut de compose.
4. **Compose** (XS) — `${BACKEND_IMAGE:-…}` / `${FRONTEND_IMAGE:-…}` ; `deploy.sh` les exporte
   déjà sous l'ancienne forme (`pedalons-<svc>:${ENV_NAME}<suffix>`) — aucun changement visible.
5. **`deploy.sh`** (M) — pull, digest, vérification d'attestation, `rollout_state` par digest,
   `--local`, élagage. Essai sur staging d'abord, avec un `docker service rollback` volontaire.
6. **Docs** (S) — `OPERATIONS.md` (Deployment, Rolling updates, Restoring), `README.md`, en-tête
   de `_image_tag.sh`, raison d'`AUD-1`. Un exercice de restauration avec images tirées.
7. **Optionnels** — rétention (S), scan Trivy (S), e2e sur images publiées (S), miroir Docker Hub
   (XS).

Total hors optionnels : de l'ordre de deux à trois jours.

---

## 11. Décisions à prendre par le propriétaire

1. **GHCR** (recommandé) ou Docker Hub, ou les deux (GHCR + miroir).
2. **Noms** : `ghcr.io/glandais/pedalons-backend` (recommandé, noms actuels) ou
   `ghcr.io/glandais/pedalons/backend`.
3. **Déclencheur** : à chaque push sur `develop` après CI verte (recommandé), ou seulement sur tag
   git (`deploy/*`), ce qui ferait de la livraison un geste explicite côté GitHub mais garderait
   un délai d'attente à chaque déploiement.
4. **Sourcemaps** : hors de l'image et archivées (recommandé, `ISSUE-1`), ou servies partout.
5. **`arm64`** : utile tant que le poste est Apple Silicon ; quasi gratuit (§4.3).
6. **Vérifier l'attestation au déploiement** : oui (recommandé) — demande `gh` ou `cosign` sur
   l'hôte.
7. **Rétention** dans GHCR : tout garder (simple) ou N derniers.

---

## 12. Délibérément dehors

- **Déploiement automatique depuis la CI (push)** — `AUD-1` tient : il faudrait une clé SSH de
  l'hôte dans GitHub ou un runner auto-hébergé. Le registry lève l'obstacle « pas d'endroit où
  mettre les images », pas l'obstacle « la CI ne touche pas l'hôte ».
- **Déploiement automatique tiré par l'hôte** (un timer qui sonde le registry et déploie, façon
  Watchtower) — techniquement possible sans secret, mais ce serait du CD sans geste humain sur la
  prod, avec Flyway en jeu ; à rediscuter avec `AUD-1` si les déploiements deviennent fréquents.
  Pour staging seul, c'est une idée raisonnable à garder en tête.
- **Registry auto-hébergé** — rien à gagner sur un Swarm mono-nœud (§3).
- **Pousser depuis le poste** — une image sans attestation de workflow ; `deploy.sh` la refuserait,
  et c'est voulu. Le repli est `build.sh` + `deploy.sh --local` sur l'hôte.
- **Images des services tiers** (traefik, postgis, minio…) — déjà tirées de registries publics,
  hors sujet.
