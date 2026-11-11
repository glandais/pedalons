# Migration biketeam → Pédalons, équipe par équipe et en direct

> **Reste à faire** : suivi sous le préfixe `MIG` de [`docs/LEDGER_NEXT.md`](../LEDGER_NEXT.md) (mise en
> production, 302 → 301, domaines personnalisés, liens et logos avant l'arrêt de biketeam, équipe
> migrée supprimable, données non importées, fin de vie du code) et au §2 (purge de la corbeille).
> Ce plan s'archivera après l'arrêt de biketeam.
>
> Écrit le 22 septembre 2026. **Implémenté et fusionné** des deux côtés (V43, suite e2e du 25
> septembre 2026), **en service en staging** ; la mise en production attend biketeam (§10, « Ordre
> de mise en production ») ; l'ancien import par dump a été **supprimé le 28 septembre 2026**. Ce document
> est le **contrat** entre trois implémenteurs qui travaillaient en parallèle sans se parler :
> *tribly backend*, *tribly frontend* (à l'écriture : worktree
> `tribly.worktrees/biketeam-live-migration`, branche `feat/biketeam-live-migration`) et *biketeam*
> (worktree `biketeam.worktrees/pedalons-migration`, branche `feat/pedalons-migration`).
> Tout ce qui traverse une frontière (jeton, en-tête, JSON, URL, code d'erreur) est fixé ici au
> champ près ; ce qui n'en traverse pas est laissé à l'implémenteur. Quand le code et ce document
> divergent sur un point de contrat, c'est ce document qui a raison jusqu'à ce qu'il soit amendé.
>
> **Ce qui fait foi et ce qui est historique.** Le contrat, ce sont les sections qui décrivent ce
> qui traverse la frontière — §0 à §6, §8.4, §9, §10 (configuration **et** ordre de mise en production, encore à dérouler
> en prod) et les décisions du §13 — telles qu'amendées
> par les « Écarts d'implémentation » datés en fin de document. **Depuis le 11 novembre 2026, il n'y a
> plus ni essai (`dryRun`) ni `reset`** : toute migration est incrémentale, et la bascule est une
> action séparée, en un clic, côté biketeam seulement (écart du 2026-11-11, décision 23) ; les sections qui font
> foi sont à jour, les écarts antérieurs gardent leur vocabulaire d'époque. Le §7 et les §8.1 à §8.3 décrivent
> l'implémentation Pédalons telle qu'elle était prévue : le code fait foi. Le §11 (dépréciation de
> l'ancien import) et le §12 (découpage des tâches) sont exécutés et ne restent que comme
> historique.

A remplacé la procédure par dump de [`MIGRATE_BIKETEAM.md`](../MIGRATE_BIKETEAM.md) (dump +
dossier de données + `backend-restore`), supprimée le 28 septembre 2026 : ce fichier est désormais
le guide d'exploitation de la migration en direct. Les **règles de correspondance** qu'il documente
(ordre des groupes et étapes, dates et fuseaux, visibilité, logo factice, FAQ, empreinte des GPX)
restent vraies et sont reprises telles quelles — seule la façon d'obtenir les données a changé.

---

## 0. Les décisions en une table

| Sujet | Décision |
|---|---|
| Qui déclenche | L'admin d'une équipe biketeam, depuis l'admin de **son** équipe (`/{teamId}/admin/pedalons`). |
| Identité Pédalons | Redirection + confirmation : jeton de demande **signé par biketeam** → page Pédalons → connexion si besoin → confirmation → **grant** à usage unique → retour sur biketeam. |
| Déclenchement | Appel M2M biketeam → Pédalons, secret partagé, `{requestId, grant, teamId}`. Asynchrone : Pédalons répond un `jobId`, biketeam interroge le statut. |
| Récupération | **API d'export M2M côté biketeam** : un instantané JSON de l'équipe + un endpoint de fichiers. Pas de connexion directe à la base, pas de montage de fichiers. |
| Réutilisation | Le mapping de `BiketeamMigrationService` est conservé ; `BiketeamReader` (SQL) est abstrait derrière une interface `BiketeamSource`, dont l'instantané HTTP est une seconde implémentation. Depuis la suppression de l'ancien import (28 septembre 2026), l'instantané est la seule. |
| Personnes | **Rien** : ni utilisateurs, ni adhésions, ni participations, ni commentaires, ni inscriptions, ni notes (évaluations) ni favoris de parcours. Le compte Pédalons qui a confirmé devient ADMIN de l'équipe et `createdBy` de tout. |
| Cible | Le domaine Pédalons sur lequel l'utilisateur a confirmé. Slug de l'équipe = identifiant biketeam (comme aujourd'hui). |
| Migration | **Toujours incrémentale** (2026-11-11) : elle copie l'équipe sur Pédalons, ou met à jour la copie, et se relance autant de fois que voulu. Elle ne change rien sur biketeam : après une migration réussie, l'équipe y reste modifiable et non redirigée. Plus d'essai (`dryRun`) ni de `reset`. |
| Bascule | **Manuelle, séparée de la migration, et propre à biketeam** — Pédalons n'y participe pas, il renvoie `urlMap` dans tout job `SUCCEEDED`. **Un seul clic** de l'admin de l'équipe, quand il le décide : « Basculer vers Pédalons ». biketeam enregistre alors la table d'URL (`urlMap`) de la dernière migration réussie, passe directement l'équipe à `MIGRATED` et redirige toutes les pages et téléchargements de l'équipe (code configurable, **302** par défaut, 301 une fois stabilisé), repli sur la page d'équipe Pédalons ; `/api/` répond `410` JSON. L'équipe biketeam devient lecture seule, rien n'y est supprimé. |
| Équipe migrée à la corbeille | Si l'équipe Pédalons issue de ce `teamId` est **déjà** à la corbeille, le job la met de côté (slug renommé, elle reste à la corbeille) et recrée l'équipe. Aucune migration ne met une équipe vivante à la corbeille. Jamais une équipe native. |
| Ancien import | Déprécié le 22 septembre 2026 et marqué partout (§11), puis **supprimé le 28 septembre 2026**. |

---

## 1. Séquence complète

```
 Navigateur (admin)            biketeam (public)                 Pédalons (public)           Pédalons worker          biketeam /internal
 ──────────────────            ─────────────────                 ─────────────────           ───────────────          ──────────────────
 1  POST /{t}/admin/pedalons/start
        ─────────────────────────▶ crée pedalons_migration(REQUESTED, id=requestId)
                                   signe le jeton de demande (HS256, §3.2)
    ◀───────────── 303 Location: {PEDALONS_URL}/migration-biketeam?request=<jeton>
 2  GET /migration-biketeam?request=…  ──────────────────────────▶ (SPA)
    POST /api/biketeam-migration/preview {requestToken}  ────────▶ vérifie signature, exp, returnUrl
    ◀──────────────────────────────────────────────── 200 aperçu (équipe, compteurs, état de la cible)
 3  (si non connecté) connexion / inscription Pédalons, retour sur la même page
 4  POST /api/biketeam-migration/confirm {requestToken}  ────────▶ @Logged : revérifie tout,
                                                                  crée biketeam_migrations(GRANTED),
                                                                  grant = aléa 32 o, stocke son hash
    ◀──────────────────────────────────── 200 {redirectUrl: returnUrl?request=<id>&grant=<grant>}
 5  GET /{t}/admin/pedalons/callback?request=<id>&grant=<grant>
        ─────────────────────────▶ (session admin biketeam exigée)
                                   pedalons_migration → TRIGGERING (aucun gel de l'équipe)
 6                                 POST {PEDALONS_INTERNAL_URL}/api/internal/biketeam-migration/jobs
                                   X-Biketeam-Migration-Secret ───────────────────▶ consomme le grant
                                                                  GRANTED → QUEUED
                                   ◀──────────────────────────────── 202 {jobId, status: QUEUED}
                                   → RUNNING (jobId)
    ◀──────────── 303 /{t}/admin/pedalons (page de suivi, se rafraîchit seule)
 7                                                                                 réclame le job (CAS)
                                                                                   QUEUED → RUNNING
                                                                    GET /internal/pedalons/teams/{t}/snapshot
                                                                    X-Pedalons-Export-Secret ────────────────▶ JSON (§6.2)
                                                                    GET …/files/{kind}/{id} (au besoin) ────▶ octets
                                                                                   mapping (§7), progression
                                                                                   → SUCCEEDED + urlMap | FAILED
 8                                 (planifié, 15 s) GET …/api/internal/biketeam-migration/jobs/{jobId}
                                   ◀──────────────────────── 200 statut (+ urlMap si SUCCEEDED)
 9                                 SUCCEEDED : bilan affiché ; l'équipe reste modifiable et non redirigée
                                   FAILED : erreur affichée
    (autant de migrations que voulu : chacune met à jour la copie Pédalons — retour en 1)
    POST /{t}/admin/pedalons/switch (« Basculer vers Pédalons », quand l'admin le décide)
        ─────────────────────────▶ table d'URL (urlMap) de la dernière migration réussie écrite,
                                   team.pedalons_state null→MIGRATED
10  GET /{t}/rides/42 ─────────────▶ 302 (configurable) Location: https://www.pedalons.fr/equipes/{teamSlug}/sorties/{rideSlug}
    GET /api/teams/{t}/rides/42 ───▶ 410 {"code":"TEAM_MIGRATED","url":"https://www.pedalons.fr/equipes/{teamSlug}"}
```

Trois canaux, trois secrets distincts (§3) : le jeton de demande transite par le navigateur, le
déclenchement et le statut vont de biketeam à Pédalons, l'export va de Pédalons à biketeam — les
deux en HTTPS par Internet, via les entrées publiques (pas de VPN, §3.4).

---

## 2. Ce qu'on ne fait pas, et pourquoi

- **Pas de copie de personnes.** Même le compte biketeam de l'admin n'est pas copié : c'est le compte
  Pédalons qui a confirmé qui devient ADMIN. Les membres rejoignent ensuite par les moyens normaux
  (lien d'invitation, adhésion libre si l'équipe est `joinable`).
- **Pas de connexion à la base biketeam depuis Pédalons.** Couplage au schéma biketeam, second
  datasource et `information_schema` à sonder : c'est exactement ce que l'ancien import obligeait à
  faire. L'export M2M est le seul point qui connaît le schéma biketeam, et il vit **dans** biketeam.
- **Pas de suppression dans biketeam.** Ni données, ni fichiers. La bascule est réversible par un
  admin plateforme biketeam (§9.6).
- **Pas de purge physique côté Pédalons.** Une équipe migrée mise de côté (elle était à la
  corbeille, §7.3) y reste, slug renommé ; purger les équipes à la corbeille est un autre
  chantier (§13, décision 10 ; ledger `MIG-9`).
- **Pas de remise à zéro** (2026-11-11). L'option `reset`, qui mettait l'équipe Pédalons à la
  corbeille pour la recréer, est supprimée des deux côtés : une migration ne fait que créer ou
  mettre à jour (décision 23).

---

## 3. Sécurité

### 3.1 Les trois secrets

| Secret | Qui signe / envoie | Qui vérifie | Pédalons (env) | biketeam (env) |
|---|---|---|---|---|
| Clé du jeton de demande (HMAC, base64, **≥ 32 octets décodés**) | biketeam | Pédalons | `PEDALONS_BIKETEAM_REQUEST_KEY` | `PEDALONS_REQUEST_KEY` |
| Secret de déclenchement (biketeam → Pédalons) | biketeam | Pédalons | `PEDALONS_BIKETEAM_TRIGGER_SECRET` | `PEDALONS_TRIGGER_SECRET` |
| Secret d'export (Pédalons → biketeam) | Pédalons | biketeam | `PEDALONS_BIKETEAM_EXPORT_SECRET` | `PEDALONS_EXPORT_SECRET` |

Générer chacun avec `openssl rand -base64 32`. Jamais en dur, jamais dans un fichier versionné :
`.env` de chaque déploiement, documentés vides dans `.env.example` (tribly) et `.env.template`
(biketeam).

Comparaison **à temps constant** partout : `MessageDigest.isEqual(sha256(reçu), sha256(attendu))`
(le hachage préalable évite de fuiter la longueur). Les secrets ne sont jamais journalisés, pas même
tronqués.

### 3.2 Jeton de demande (biketeam → navigateur → Pédalons)

Un JWS compact **HS256** (`base64url(header).base64url(payload).base64url(signature)`, base64url
**sans** remplissage), signé avec la clé décodée du base64 de `…REQUEST_KEY`. Pas de bibliothèque
JWT requise : `javax.crypto.Mac("HmacSHA256")` sur les octets ASCII de `header64 + "." + payload64`.

En-tête — exactement :

```json
{"alg":"HS256","typ":"JWT"}
```

Charge utile (tous les champs du tableau obligatoires, types stricts) :

| Claim | Type | Valeur |
|---|---|---|
| `iss` | string | `"biketeam"` |
| `aud` | string | `"pedalons:biketeam-migration"` |
| `ver` | int | `1` |
| `jti` | string | `requestId`, UUID v4 en minuscules = `pedalons_migration.id` |
| `iat` | int | secondes epoch |
| `exp` | int | `iat + 3600` (le temps de se créer un compte Pédalons et de vérifier son e-mail) |
| `teamId` | string | identifiant biketeam, minuscules, vérifie `^[a-z0-9][a-z0-9_.-]{0,254}$` (biketeam fait ce contrôle avant de signer) ; normalisé, c'est aussi le slug cible (§13.19) |
| `teamName` | string | `team.name` |
| `requestedBy` | string | prénom + nom de l'admin biketeam, pour affichage seulement |
| `returnUrl` | string | **exactement** `{site.url}/{teamId}/admin/pedalons/callback` |
| `summary` | object | `{places, routes, rides, rideTemplates, trips, tripStages, publications: int ; faqPage, logo: bool}` — éléments **non supprimés** ; `logo` vrai si un fichier logo existe (factice ou non) |

**Claims `dryRun` et `reset` (retirés le 2026-11-11).** biketeam ne les envoie plus ; `ver` reste
`1`. Pédalons les **ignore** s'ils sont présents, quel que soit leur type — il ne les lit ni ne les
exige —, comme tout claim que ce tableau ne nomme pas : un biketeam pas encore mis à jour les envoie
encore, et son jeton reste accepté. D'où l'ordre de déploiement, **Pédalons d'abord, biketeam
ensuite** (§10) : un Pédalons d'avant le 2026-11-11 refuserait un jeton sans ces deux claims ; un
biketeam d'avant qui envoie `reset: true` ou `dryRun: false` voit ces valeurs ignorées, et sa
migration est incrémentale comme les autres.

Vérification côté Pédalons, dans cet ordre, toute erreur → `400 BIKETEAM_REQUEST_INVALID` sauf
mention :

1. trois segments ; l'en-tête décodé vaut `alg=HS256` (tout autre `alg`, dont `none`, est refusé) ;
2. HMAC recalculé sur les **segments reçus** (jamais sur un JSON re-sérialisé), comparé à temps
   constant ;
3. `iss`, `aud`, `ver` attendus ; `exp - iat ≤ 3600` ;
4. `exp` dépassé (tolérance 60 s) → `400 BIKETEAM_REQUEST_EXPIRED` ;
5. `returnUrl` égale **à la lettre** `{PEDALONS_BIKETEAM_PUBLIC_URL sans / final}/{teamId}/admin/pedalons/callback`
   — c'est ce qui empêche la redirection ouverte, en plus de la signature.

**Vecteur de test** (à reprendre tel quel dans les tests des deux côtés) — clé base64
`AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8=` (octets 0x00…0x1f), payload
`{"iss":"biketeam","aud":"pedalons:biketeam-migration","ver":1,"jti":"6f1c2a3e-0000-4000-8000-000000000001","iat":1790000000,"exp":1790000900,"teamId":"n-peloton","teamName":"N'Peloton","requestedBy":"Jane D.","returnUrl":"https://biketeam.example/n-peloton/admin/pedalons/callback","summary":{"places":1,"routes":2,"rides":3,"rideTemplates":0,"trips":1,"tripStages":2,"publications":4,"faqPage":true,"logo":false}}`
(octets UTF-8 exacts, sans espace) donne :

```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJiaWtldGVhbSIsImF1ZCI6InBlZGFsb25zOmJpa2V0ZWFtLW1pZ3JhdGlvbiIsInZlciI6MSwianRpIjoiNmYxYzJhM2UtMDAwMC00MDAwLTgwMDAtMDAwMDAwMDAwMDAxIiwiaWF0IjoxNzkwMDAwMDAwLCJleHAiOjE3OTAwMDA5MDAsInRlYW1JZCI6Im4tcGVsb3RvbiIsInRlYW1OYW1lIjoiTidQZWxvdG9uIiwicmVxdWVzdGVkQnkiOiJKYW5lIEQuIiwicmV0dXJuVXJsIjoiaHR0cHM6Ly9iaWtldGVhbS5leGFtcGxlL24tcGVsb3Rvbi9hZG1pbi9wZWRhbG9ucy9jYWxsYmFjayIsInN1bW1hcnkiOnsicGxhY2VzIjoxLCJyb3V0ZXMiOjIsInJpZGVzIjozLCJyaWRlVGVtcGxhdGVzIjowLCJ0cmlwcyI6MSwidHJpcFN0YWdlcyI6MiwicHVibGljYXRpb25zIjo0LCJmYXFQYWdlIjp0cnVlLCJsb2dvIjpmYWxzZX19.GL7rqlMf1cehmTFcjN146SPsbzhNBsS2Ib5WhPbP4Z8
```

(biketeam : le test de signature reproduit ce jeton à l'octet près à partir de ces octets de
payload ; Pédalons : le test de vérification l'accepte avec une horloge figée à `1790000100` et le
refuse à `1790001000`. Vecteur du 2026-11-11 ; le précédent, qui portait
`"dryRun":true,"reset":false` entre `requestedBy` et `returnUrl` et se terminait par la signature
`-Fy6Ljdr2ChwKFIAAkH3lh8CIUynNQFNJm2Us2G-jlw`, reste dans `BiketeamRequestTokenVerifierTest` comme
preuve qu'un jeton d'un biketeam pas encore mis à jour est toujours accepté.)

Le jeton n'est **pas** un titre d'accès : à lui seul il ne permet que l'aperçu. Il voyage dans la
query string de la page Pédalons ; c'est acceptable, et c'est pour cela que la confirmation exige
une session Pédalons et que le grant, lui, est à usage unique.

### 3.3 Grant (Pédalons → navigateur → biketeam → Pédalons)

- Valeur : `"bmg_" + base64url(32 octets SecureRandom)` (sans remplissage), 47 caractères.
- Stocké **haché** (`TokenUtils.hashToken`, SHA-256 base64) dans `biketeam_migrations.grant_hash`,
  jamais en clair côté Pédalons.
- Lié à : l'utilisateur Pédalons connecté, le domaine courant (`DomainResolver.getDomain()`, donc le
  domaine **parent** si la requête arrive par un alias), `teamId`, `requestId`.
- Durée de vie : `pedalons.biketeam.grant-ttl`, défaut **10 min**. Usage unique : consommé par le
  déclenchement (§5.1).
- Re-confirmation de la même demande par le **même** utilisateur tant qu'elle n'a pas été consommée
  — ligne `GRANTED`, ou `EXPIRED` (grant échu sans déclenchement), tant que le jeton de demande est
  valide (double clic, bouton retour, grant échu) : un nouveau grant **remplace** l'ancien, qui cesse
  de valoir, et la ligne redevient `GRANTED` (écart 3e revue). Par un autre utilisateur, ou après
  consommation (job créé) : `409 BIKETEAM_REQUEST_ALREADY_USED`.
- biketeam le reçoit en query string sur son callback, le garde en base le temps du déclenchement
  (colonne `pedalons_migration.grant_value`) et **l'efface** dès que le job est créé. La page de
  callback répond par une redirection immédiate avec `Referrer-Policy: no-referrer`.

### 3.4 Exposition réseau (pas de VPN)

**Décision du propriétaire, 2026-09-24 : pas de VPN entre les serveurs.** Les appels M2M passent par
Internet, **en HTTPS, par les entrées publiques normales** des deux applications :

- biketeam → Pédalons : `{PEDALONS_INTERNAL_URL}/api/internal/biketeam-migration/**`, où
  `PEDALONS_INTERNAL_URL` est l'URL publique de Pédalons (en général égale à `PEDALONS_URL`). Côté
  Pédalons, `/api/internal/` passe par Caddy puis par le routeur Traefik `quarkus`
  (`PathPrefix(\`/api\`)`) comme le reste de l'API : **aucun** entrypoint, routeur ni refus
  particulier dans `docker-compose.yml` ou `frontend/server.js`.
- Pédalons → biketeam : `{PEDALONS_BIKETEAM_EXPORT_URL}/internal/pedalons/**`, où l'URL est
  l'adresse publique de biketeam (en général égale à `PEDALONS_BIKETEAM_PUBLIC_URL`). Le vhost public
  de biketeam sert `/internal/pedalons/` normalement ; `SecurityConfig` le déclare `permitAll`, sans
  restriction réseau.

La sécurité repose **uniquement** sur :

1. les secrets partagés (`X-Biketeam-Migration-Secret`, `X-Pedalons-Export-Secret`), comparés à
   temps constant, jamais journalisés, qui ne transitent qu'en HTTPS ;
2. le **grant à usage unique** (§3.3) : le secret de déclenchement seul ne crée aucun job ;
3. l'export **limité aux équipes en migration** (§6) : le secret d'export seul ne permet pas
   d'aspirer n'importe quelle équipe.

**HTTPS obligatoire.** Chaque côté refuse au démarrage une URL M2M en `http://` qui ne vise pas
`localhost`/`127.0.0.1` (Pédalons : `PEDALONS_BIKETEAM_EXPORT_URL` ; biketeam :
`PEDALONS_INTERNAL_URL`) ; `http://localhost` reste permis pour le développement.

**Choix assumé.** Le propriétaire juge la fuite d'un secret très improbable ; les renforcements
possibles — allowlist IP (Traefik `ipallowlist` / vhost), signature HMAC des requêtes, mTLS, VPN
avec entrypoint dédié — sont **écartés** pour rester simple. Une première version (VPN, entrypoint
Traefik `internal`, double blocage de `/api/internal` sur l'entrée publique, refus de `/internal/`
par le vhost biketeam) a été implémentée puis retirée le 2026-09-24.

Les deux applications désactivent leurs endpoints M2M (réponse `404` sans corps) tant que leur
configuration n'est pas complète (§10).

---

## 4. Pédalons — API publique (hors contrat OpenAPI)

Deux endpoints publics (joignables sans secret, appelés par la page web), mais **absents** de
`contracts/openapi.yaml` depuis le 2026-09-24 (écart tribly du même jour) : `@Operation(hidden =
true)`, sans `@Tag`, et DTO sans `@Schema` de classe, donc rien dans les clients générés frontend
et mobile. Le frontend les appelle par un module écrit à la main
(`frontend/src/pages/biketeamMigration/biketeamMigrationApi.ts`, types recopiés des DTO Java ci-
dessous). Seuls les codes `BIKETEAM_*` de l'enum `ErrorCode` partagé restent dans le contrat (onze à l'origine, dix depuis le retrait de `BIKETEAM_RESET_BLOCKED` le 2026-11-11) :
`pedalons.api.version` **4.4.0 → 4.5.0** (ajout rétrocompatible). Les noms (`operationId`, DTO)
ci-dessous restent ceux du code Java et du module frontend.

Quand la fonction est désactivée (§10), les deux répondent `404 NOT_FOUND`.

### 4.1 `POST /api/biketeam-migration/preview` — `operationId: previewBiketeamMigration`

Public (`@PermitAll`, service `@Public`) : un visiteur non connecté doit voir de quoi il retourne
avant de se connecter, comme pour les invitations. Si un utilisateur est connecté, la réponse dit
en plus s'il peut confirmer.

Requête `BiketeamMigrationTokenRequest` :

```json
{ "requestToken": "eyJhbGciOi…" }
```

Réponse `200` `BiketeamMigrationPreviewDto` :

```json
{
  "requestId": "6f1c2a3e-0000-4000-8000-000000000001",
  "teamId": "n-peloton",
  "teamName": "N'Peloton",
  "requestedBy": "Jane D.",
  "expiresAt": "2026-09-22T11:15:00Z",
  "summary": {
    "places": 12, "routes": 2585, "rides": 665, "rideTemplates": 3,
    "trips": 19, "tripStages": 124, "publications": 40, "faqPage": true, "logo": true
  },
  "targetDomainName": "Pédalons",
  "targetTeamSlug": "n-peloton",
  "targetState": "NEW",
  "existingTeamName": null,
  "trashedTeamSetAside": null,
  "confirmable": false,
  "blockReason": "LOGIN_REQUIRED",
  "cancelUrl": "https://biketeam.example/n-peloton/admin/pedalons/callback?request=6f1c2a3e-0000-4000-8000-000000000001&outcome=cancelled"
}
```

| Champ | Type | Règle |
|---|---|---|
| `expiresAt` | date-time | `exp` du jeton |
| `summary` | `BiketeamMigrationSummaryDto` | recopié du jeton |
| `targetDomainName` | string | `Domain.name` du domaine courant |
| `targetState` | enum `BiketeamMigrationTargetState` | `NEW` (aucune équipe à ce slug, corbeille comprise, ou équipe à la corbeille issue de ce `teamId`) · `EXISTING_MIGRATED` (équipe active issue de ce `teamId`) · `SLUG_CONFLICT` (slug pris par une équipe qui n'en est pas issue ; une équipe `EXISTING_MIGRATED` renommée n'est plus concernée par le slug normalisé, qu'une autre équipe peut tenir sans conflit) · `MIGRATED_IN_OTHER_DOMAIN` (ce `teamId` a déjà été migré vers un autre domaine de la même base) |
| `existingTeamName` | string\|null | nom de l'équipe Pédalons existante, pour `EXISTING_MIGRATED` et `SLUG_CONFLICT` |
| `trashedTeamSetAside` | string\|null | nom de l'équipe issue de ce `teamId` qui est à la corbeille (`targetState = NEW`) : le job la met de côté — slug renommé `<slug>-reset-<jobId>`, elle reste à la corbeille — avant de recréer l'équipe ; `null` sinon. Même évaluation que le worker (`BiketeamTargetResolver`, `Target.trashed`) (2026-09-25) |
| `confirmable` | bool | `blockReason == null` |
| `blockReason` | enum `BiketeamMigrationBlockReason`\|null | premier motif applicable, dans cet ordre : `SLUG_CONFLICT`, `MIGRATED_IN_OTHER_DOMAIN`, `REQUEST_ALREADY_USED`, `MIGRATION_RUNNING`, `LOGIN_REQUIRED`, `NOT_TEAM_ADMIN` (`RESET_BLOCKED` retiré le 2026-11-11 avec le `reset`) |
| `cancelUrl` | string | `returnUrl + "?request=" + requestId + "&outcome=cancelled"` |

`NOT_TEAM_ADMIN` : l'équipe existe (`EXISTING_MIGRATED`) et l'utilisateur connecté n'en est ni
ADMIN ni PLATFORM_ADMIN. Migrer de nouveau vers une équipe Pédalons est réservé à qui l'administre
**sur Pédalons** — elle a pu vivre depuis sa première migration. `MIGRATION_RUNNING` : un job `QUEUED`/`RUNNING`
existe pour ce `teamId`.

Le DTO ne porte plus `dryRun` ni `reset` (2026-11-11) : la page n'a plus de mode à afficher.

Erreurs : `400 BIKETEAM_REQUEST_INVALID`, `400 BIKETEAM_REQUEST_EXPIRED`.

### 4.2 `POST /api/biketeam-migration/confirm` — `operationId: confirmBiketeamMigration`

`@RolesAllowed("user")`, service `@Logged`. Même corps que l'aperçu. Refait **toutes** les
vérifications de l'aperçu (rien n'est cru du client), puis crée ou recharge la ligne
`biketeam_migrations` (§8.1) en `GRANTED`.

Réponse `200` `BiketeamMigrationConfirmDto` :

```json
{
  "redirectUrl": "https://biketeam.example/n-peloton/admin/pedalons/callback?request=6f1c2a3e-0000-4000-8000-000000000001&grant=bmg_Q2xhdWRl…",
  "expiresAt": "2026-09-22T10:25:00Z"
}
```

`expiresAt` = fin de validité du grant. Le frontend fait `window.location.assign(redirectUrl)`.

Erreurs (corps `ErrorResponse` habituel) :

| HTTP | `code` | Cas |
|---|---|---|
| 401 | `UNAUTHORIZED` | non connecté |
| 400 | `BIKETEAM_REQUEST_INVALID` / `BIKETEAM_REQUEST_EXPIRED` | §3.2 |
| 409 | `BIKETEAM_SLUG_CONFLICT` | `targetState = SLUG_CONFLICT` |
| 409 | `BIKETEAM_MIGRATED_IN_OTHER_DOMAIN` | `targetState = MIGRATED_IN_OTHER_DOMAIN` |
| 409 | `BIKETEAM_REQUEST_ALREADY_USED` | ligne déjà consommée (job créé), ou `GRANTED`/`EXPIRED` d'un autre utilisateur |
| 409 | `BIKETEAM_MIGRATION_RUNNING` | job actif pour ce `teamId` |
| 403 | `BIKETEAM_NOT_TEAM_ADMIN` | voir ci-dessus |

Nouveaux `ErrorCode` (backend) et clés `errors.api.<CODE>` (frontend, fr + en) :
`BIKETEAM_REQUEST_INVALID`, `BIKETEAM_REQUEST_EXPIRED`, `BIKETEAM_REQUEST_ALREADY_USED`,
`BIKETEAM_SLUG_CONFLICT`, `BIKETEAM_MIGRATED_IN_OTHER_DOMAIN`, `BIKETEAM_NOT_TEAM_ADMIN`,
`BIKETEAM_MIGRATION_RUNNING`, `BIKETEAM_GRANT_INVALID`,
`BIKETEAM_GRANT_EXPIRED`, `BIKETEAM_JOB_NOT_FOUND` (les trois derniers ne servent qu'au M2M, mais
vivent dans le même enum ; `BIKETEAM_JOB_NOT_FOUND` a été ajouté le 2026-09-24 pour le §5.2).
`BIKETEAM_RESET_BLOCKED` (409, un `DomainAlias` épinglait l'équipe à remettre à zéro) a été
**retiré de l'enum** le 2026-11-11 avec le `reset` : `pedalons.api.version` **13.8.0 → 14.0.0**.

### 4.3 Page web `biketeamMigration`

`contracts/routes.yaml`, section *Auth* (à côté de `invitation`) :

```yaml
  # Where biketeam sends a team admin who asked to move their team here. The signed request travels
  # in ?request= ; it is not a credential on its own (confirming needs a session), see
  # docs/plans/2026-09-22-biketeam-live-migration.md.
  - id: biketeamMigration
    path:
      en: /biketeam-migration
      fr: /migration-biketeam
    web: true
    mobile: false
    deeplink: false
```

biketeam construit **toujours** la forme `fr` : `{PEDALONS_URL}/migration-biketeam?request=<jeton>`.

---

## 5. Pédalons — API M2M (hors contrat public)

Préfixe `/api/internal/biketeam-migration`. Chaque opération porte `@Operation(hidden = true)` : ni
les endpoints ni leurs DTO n'apparaissent dans `contracts/openapi.yaml` (vérifier le diff après
génération). Pas de dépendance au `Host` : le domaine cible vient de la ligne de job.

Authentification : en-tête **`X-Biketeam-Migration-Secret: <PEDALONS_BIKETEAM_TRIGGER_SECRET>`**,
vérifié par un `ContainerRequestFilter` lié par une `@NameBinding` dédiée (`@BiketeamM2M`, même motif
que `@TileTokenAuth`/`TileTokenFilter`). Pas d'`Authorization: Bearer` : smallrye-jwt tenterait de
le lire comme un JWT et répondrait 401 avant la ressource. Ressource `@PermitAll` ; les méthodes de
service appelées portent `@Public` (l'`ArchitectureTest` exige une annotation de sécurité ; c'est le
filtre qui authentifie).

| Situation | Réponse |
|---|---|
| fonction désactivée (§10) | `404`, sans corps |
| en-tête absent ou faux | `401` `{"code":"UNAUTHORIZED"}` |

Corps d'erreur : l'`ErrorResponse` habituel ; biketeam ne lit que `code`.

### 5.1 `POST /api/internal/biketeam-migration/jobs` — déclencher

Requête :

```json
{
  "requestId": "6f1c2a3e-0000-4000-8000-000000000001",
  "grant": "bmg_Q2xhdWRl…",
  "teamId": "n-peloton"
}
```

Traitement : `hashToken(grant)` → ligne ; `requestId` et `teamId` doivent être
**égaux** à ceux de la ligne ; toute autre propriété du corps est **ignorée** — dont `dryRun` et
`reset`, qu'un biketeam pas encore mis à jour envoie encore (2026-11-11) ; CAS `GRANTED → QUEUED` (`queued_at = now`). L'index unique partiel
(§8.1) garantit un seul job actif par `teamId`.

| HTTP | Corps | Cas |
|---|---|---|
| `202` | `BiketeamJobCreatedDto` | job créé |
| `200` | idem, même `jobId` | **rejeu idempotent** : grant déjà consommé par ce job, champs identiques (biketeam a perdu la réponse) |
| `400` | `VALIDATION` | `requestId`, `grant` ou `teamId` manquant |
| `403` | `BIKETEAM_GRANT_INVALID` | grant inconnu, ou `requestId`/`teamId` diffère de la ligne |
| `400` | `BIKETEAM_GRANT_EXPIRED` | `grant_expires_at` dépassé (la ligne passe `EXPIRED`) |
| `409` | `BIKETEAM_MIGRATION_RUNNING` | un autre job actif pour ce `teamId` ; le corps porte en plus `"activeJobId"` |

```json
{ "jobId": "0hx3k2m9q8r4t", "status": "QUEUED", "targetTeamSlug": "n-peloton" }
```

`jobId` = TSID de la ligne, chaîne minuscule comme tous les ids de l'API. `targetTeamSlug` = le slug
où le job atterrit, à l'instant du déclenchement : celui de l'équipe déjà écrite par le job, sinon
celui de l'équipe migrée que le job met à jour (même renommée), sinon — création — le
slug normalisé (§13.19). Jamais l'identifiant biketeam brut.

### 5.2 `GET /api/internal/biketeam-migration/jobs/{jobId}` — statut

`404` `{"code":"BIKETEAM_JOB_NOT_FOUND","message":"…"}` (corps d'erreur habituel) si le job
n'existe pas, si l'id n'est pas un TSID valide, ou s'il n'a jamais été déclenché (une ligne
`GRANTED`/`EXPIRED` n'est pas un job). **C'est le seul 404 que biketeam lit comme `JOB_LOST`** : un
404 sans ce code (proxy sans route, Pédalons qui redémarre, fonction désactivée → 404 sans corps)
est transitoire et le poller réessaie (2026-09-24).

```json
{
  "jobId": "0hx3k2m9q8r4t",
  "requestId": "6f1c2a3e-0000-4000-8000-000000000001",
  "teamId": "n-peloton",
  "status": "SUCCEEDED",
  "attempt": 1,
  "queuedAt": "2026-09-22T10:16:02Z",
  "startedAt": "2026-09-22T10:16:10Z",
  "finishedAt": "2026-09-22T10:24:51Z",
  "progress": { "phase": "DONE", "done": 0, "total": 0 },
  "targetTeam": {
    "slug": "n-peloton",
    "name": "N'Peloton",
    "url": "https://www.pedalons.fr/equipes/n-peloton"
  },
  "counts": {
    "teamPages":     { "total": 2,    "migrated": 2,    "skipped": 0, "failed": 0 },
    "places":        { "total": 12,   "migrated": 12,   "skipped": 0, "failed": 0 },
    "routes":        { "total": 2601, "migrated": 2560, "skipped": 16, "failed": 25 },
    "rideTemplates": { "total": 3,    "migrated": 3,    "skipped": 0, "failed": 0 },
    "publications":  { "total": 41,   "migrated": 40,   "skipped": 1, "failed": 0 },
    "rides":         { "total": 670,  "migrated": 665,  "skipped": 5, "failed": 0 },
    "trips":         { "total": 19,   "migrated": 19,   "skipped": 0, "failed": 0 },
    "tripStages":    { "total": 124,  "migrated": 124,  "skipped": 0, "failed": 0 },
    "images":        { "total": 210,  "migrated": 210,  "skipped": 0, "failed": 0 }
  },
  "warnings": [
    { "entityType": "ROUTE", "biketeamId": "8c0…", "code": "GPX_MISSING", "message": "No GPX file in the export" }
  ],
  "warningsTruncated": false,
  "error": null,
  "lastAttemptError": null,
  "urlMap": {
    "TEAM":        { "n-peloton": "https://www.pedalons.fr/equipes/n-peloton" },
    "TEAM_ABOUT":  { "n-peloton": "https://www.pedalons.fr/equipes/n-peloton/a-propos" },
    "TEAM_FAQ":    { "n-peloton": "https://www.pedalons.fr/equipes/n-peloton/pages/faq" },
    "ROUTES_LIST": { "n-peloton": "https://www.pedalons.fr/equipes/n-peloton/parcours" },
    "ROUTE":       { "<map.id>": "https://www.pedalons.fr/equipes/n-peloton/parcours/<slug>" },
    "RIDE":        { "<ride.id>": "https://www.pedalons.fr/equipes/n-peloton/sorties/<slug>" },
    "TRIP":        { "<trip.id>": "https://www.pedalons.fr/equipes/n-peloton/voyages/<slug>" },
    "TRIP_STAGE":  { "<trip_stage.id>": "https://www.pedalons.fr/equipes/n-peloton/voyages/<trip-slug>/etapes/<slug>" },
    "POST":        { "<publication.id>": "https://www.pedalons.fr/equipes/n-peloton/articles/<slug>" }
  }
}
```

| Champ | Règle |
|---|---|
| `status` | `QUEUED` · `RUNNING` · `SUCCEEDED` · `FAILED` — seuls états visibles d'un job |
| `attempt` | tentatives commencées (1 à `max-attempts`) |
| `progress.phase` | `QUEUED`, `SNAPSHOT`, `TEAM`, `PLACES`, `ROUTES`, `RIDE_TEMPLATES`, `PUBLICATIONS`, `RIDES`, `TRIPS`, `URLS`, `DONE` ; `done`/`total` comptent les éléments de la phase |
| `targetTeam` | `null` tant que l'équipe n'est pas résolue |
| `counts.*.skipped` | supprimé côté biketeam (`deleted: true`) ou volontairement ignoré |
| `counts.*.failed` | échec de l'élément seul — l'équipe continue (même frontière d'erreur par élément que l'ancien import) |
| `warnings` | au plus 500 entrées, `warningsTruncated` le signale ; `entityType` ∈ `TEAM, TEAM_PAGE, PLACE, ROUTE, RIDE_TEMPLATE, PUBLICATION, RIDE, TRIP, TRIP_STAGE, IMAGE, LOGO` ; `code` ∈ `GPX_MISSING, GPX_EMPTY, GPX_FAILURE, FILE_DOWNLOAD_FAILED, IMAGE_FAILED, ITEM_FAILED, TRIP_STAGES_OUTSIDE_DATES, TAGS_TRUNCATED` (ce dernier ajouté avec `API-59`) |
| `error` | `null`, ou `{"code": "...", "message": "..."}` quand `FAILED` : `BIKETEAM_SLUG_CONFLICT`, `BIKETEAM_MIGRATED_IN_OTHER_DOMAIN`, `BIKETEAM_NOT_TEAM_ADMIN`, `EXPORT_REFUSED` (4xx de l'export), `EXPORT_UNAVAILABLE` (5xx/réseau après toutes les tentatives), `EXPORT_INVALID` (instantané illisible, mauvaise `schemaVersion`, mauvais `team.id`), `WORKER_LOST` (plus de tentative après un arrêt brutal), `INTERNAL_ERROR` |
| `lastAttemptError` | `null`, ou `{"code": "...", "message": "..."}` quand le job est `QUEUED` ou `RUNNING` après une tentative ratée, en attente ou en cours de la suivante : pourquoi elle a raté — `EXPORT_UNAVAILABLE` (5xx/réseau), `INTERNAL_ERROR`, `WORKER_LOST` (plus de battement, job remis en file). `null` avant tout échec, en `SUCCEEDED` et en `FAILED` (la raison finale est alors dans `error`, qui reste réservé à l'échec définitif) (2026-09-25) |
| `urlMap` | présent (non nul) **seulement** en `SUCCEEDED`, pour **tout** job réussi ; §8.4 |

Un `SUCCEEDED` avec des `failed > 0` reste un succès : l'ancien import perdait 25 parcours sur la
base de 2026-07 pour des fichiers absents ou invalides, et ce n'est pas une raison de ne pas
basculer. biketeam affiche les avertissements ; la décision de basculer reste humaine : rien ne
bascule sans le clic « Basculer vers Pédalons » de l'admin (§9.2).

La réponse ne porte plus `dryRun` ni `reset` (2026-11-11) ; biketeam ne les lisait pas.

---

## 6. biketeam — API d'export M2M

Préfixe `/internal/pedalons`. Authentification : en-tête **`X-Pedalons-Export-Secret`**. Déclaré
`permitAll` dans `SecurityConfig` **avant** la règle `/{teamId}/**` (qui sinon lirait `internal`
comme un `teamId`), hors de la liste CSRF (GET seulement), le secret étant vérifié par le contrôleur
ou un filtre dédié.

Garde supplémentaire : l'export d'une équipe n'est servi **que** si elle a une ligne
`pedalons_migration` en `TRIGGERING` ou `RUNNING` (§9.2). Le secret d'export seul ne permet donc pas
d'aspirer n'importe quelle équipe.

| Situation | Réponse |
|---|---|
| fonction désactivée (§10) | `404`, sans corps |
| secret absent ou faux | `401` `{"code":"UNAUTHORIZED","message":"…"}` |
| équipe inconnue ou `deletion = true` | `404` `{"code":"TEAM_NOT_FOUND"}` |
| aucune migration active pour l'équipe | `409` `{"code":"NO_ACTIVE_MIGRATION"}` |
| fichier absent, ou entité hors de l'équipe | `404` `{"code":"FILE_NOT_FOUND"}` |

### 6.1 Conventions de format

- UTF-8, `Content-Type: application/json`.
- **Tout champ documenté est toujours présent**, `null` quand il n'a pas de valeur ; tableaux vides
  plutôt que `null`. Pédalons ignore les champs inconnus (`@JsonIgnoreProperties(ignoreUnknown = true)`)
  pour que biketeam puisse ajouter sans casser.
- Date seule : `"YYYY-MM-DD"` (`LocalDate.toString()`). Heure seule : `"HH:mm:ss"`, secondes
  **toujours** présentes (`DateTimeFormatter.ofPattern("HH:mm:ss")`). Instant : ISO-8601 UTC avec `Z`
  (`Instant.toString()`, fraction de secondes possible).
- Nombres : nombres JSON (`length` en mètres comme en base, vitesses en km/h).
- Texte : tel qu'en base, sans échappement HTML ni normalisation de fins de ligne (Pédalons
  normalise, comme aujourd'hui).
- Énumérations : noms Java de biketeam (`MapType`, `RideType`, `WindDirection`, `PublishedStatus`,
  `Visibility`, `Country`).
- **Ordre** : tableaux de premier niveau triés par `id` croissant (déterminisme) ; tableaux imbriqués
  dans l'**ordre d'affichage de biketeam** (§6.3) — l'index dans le tableau devient le `sortOrder`
  Pédalons.

### 6.2 `GET /internal/pedalons/teams/{teamId}/snapshot`

Couvre tout ce que lisait `BiketeamReader` (l'ancien import SQL, supprimé le 28 septembre 2026), **moins** `user_account`, `user_role`,
`ride_group_participant`, `trip_participant`, `message`, `user_email_conflict` ; plus le fuseau de
l'équipe (que l'ancien import supposait `Europe/Paris`) et les références de fichiers.

```json
{
  "schemaVersion": 1,
  "generatedAt": "2026-09-22T10:16:11.123Z",
  "team": {
    "id": "n-peloton",
    "name": "N'Peloton",
    "city": "Nantes",
    "country": "FR",
    "createdAt": "2019-03-02",
    "visibility": "PUBLIC",
    "timezone": "Europe/Paris",
    "description": {
      "description": "Texte libre…",
      "addressStreetLine": null,
      "addressPostalCode": "44000",
      "addressPostalCity": "Nantes",
      "phoneNumber": null,
      "email": "contact@example.org",
      "facebook": "npeloton",
      "twitter": null,
      "instagram": null,
      "other": "https://example.org"
    },
    "markdownPage": "# FAQ\n…",
    "logo": {
      "kind": "LOGO",
      "path": "/internal/pedalons/teams/n-peloton/files/logo/n-peloton",
      "fileName": "logo.png",
      "contentType": "image/png",
      "size": 18342,
      "md5": "fc9ed08a9d6f7f1989c804c8a6961721"
    }
  },
  "places": [
    {
      "id": "3a2…", "name": "Place du Commerce", "address": "…", "link": null,
      "lat": 47.2129, "lng": -1.5588, "startPlace": true, "endPlace": false
    }
  ],
  "maps": [
    {
      "id": "8c0…", "permalink": "boucle-du-lac", "name": "Boucle du lac",
      "length": 84210.0, "type": "ROAD",
      "positiveElevation": 612.0, "negativeElevation": 611.0,
      "postedAt": "2023-04-11",
      "startPoint": { "lat": 47.21, "lng": -1.55 },
      "endPoint":   { "lat": 47.21, "lng": -1.55 },
      "windDirection": "NORTH_EAST",
      "tags": ["lac", "plat"],
      "deleted": false,
      "gpx": {
        "kind": "GPX",
        "path": "/internal/pedalons/teams/n-peloton/files/gpx/8c0…",
        "fileName": "8c0….gpx",
        "contentType": "application/gpx+xml",
        "size": 412733,
        "md5": "9e107d9d372bb6826bd81d3542a419d6"
      }
    }
  ],
  "rideTemplates": [
    {
      "id": "…", "name": "Sortie du samedi", "description": "…", "type": "REGULAR",
      "increment": 7, "startPlaceId": "3a2…", "endPlaceId": null,
      "groups": [
        { "id": "…", "name": "Groupe A", "averageSpeed": 28.0, "meetingTime": "08:30:00" }
      ]
    }
  ],
  "publications": [
    {
      "id": "…", "title": "AG 2025", "content": "…",
      "publishedStatus": "PUBLISHED", "publishedAt": "2025-01-10T18:00:00Z",
      "deleted": false,
      "image": null
    }
  ],
  "rides": [
    {
      "id": "…", "permalink": "sortie-du-12", "date": "2025-04-12",
      "title": "Sortie du 12", "description": "…", "type": "REGULAR",
      "publishedStatus": "PUBLISHED", "publishedAt": "2025-04-05T09:00:00Z",
      "startPlaceId": "3a2…", "endPlaceId": null,
      "listedInFeed": true, "deleted": false,
      "image": {
        "kind": "RIDE_IMAGE",
        "path": "/internal/pedalons/teams/n-peloton/files/ride-image/…",
        "fileName": "….jpg", "contentType": "image/jpeg", "size": 201234, "md5": "…"
      },
      "groups": [
        { "id": "…", "name": "A", "averageSpeed": 30.0, "meetingTime": "08:00:00", "mapId": "8c0…" }
      ]
    }
  ],
  "trips": [
    {
      "id": "…", "permalink": "tour-2025",
      "startDate": "2025-07-01", "endDate": "2025-07-05", "meetingTime": "07:30:00",
      "type": "ROAD", "publishedStatus": "PUBLISHED", "publishedAt": "2025-03-01T12:00:00Z",
      "title": "Tour 2025", "description": "…",
      "startPlaceId": null, "endPlaceId": null,
      "markdownPage": null,
      "listedInFeed": true, "deleted": false,
      "image": null,
      "stages": [
        { "id": "…", "date": "2025-07-01", "name": "Étape 1", "mapId": "8c0…", "alternative": false }
      ]
    }
  ]
}
```

Champ par champ, là où ce n'est pas évident :

| Champ | Type | Source biketeam / règle |
|---|---|---|
| `team.visibility` | enum | `PUBLIC`, `PUBLIC_UNLISTED`, `PRIVATE`, `PRIVATE_UNLISTED`, `USER` |
| `team.timezone` | string | `team_configuration.timezone` |
| `team.description` | objet\|null | `team_description` ; `addressPostalCity` = colonne `address_postal_city` |
| `team.markdownPage` | string\|null | `team_configuration.markdown_page` (la FAQ), `null` si vide |
| `team.logo` | FileRef\|null | `misc/<teamId>/logo.<png\|jpg\|jpeg>` s'il existe — **y compris** le logo factice : c'est Pédalons qui l'écarte par empreinte, comme aujourd'hui. Jamais `heatmap.png`, jamais `misc/logo.png`. |
| `places[].lat/lng` | number\|null | `point_lat`/`point_lng` |
| `maps[]` | | **toutes** les lignes de `map` de l'équipe, supprimées comprises (`deleted = map.deletion`) : Pédalons met à la corbeille le parcours d'une carte supprimée depuis un passage précédent |
| `maps[].startPoint/endPoint` | `{lat,lng}`\|null | `null` si une coordonnée manque |
| `maps[].windDirection` | enum\|null | nom Java : `NORTH`, `NORTH_EAST`, … (voir §7.4, correction d'un défaut de l'ancien import) |
| `maps[].tags` | string[] | `map_tags`, vides écartés, ordre de la table |
| `maps[].gpx` | FileRef\|null | `gpx/<teamId>/<mapId>.gpx` ; `null` si absent **ou** si `deleted` |
| `rideTemplates[].groups` | | ordre §6.3 |
| `publications[]` | | toutes, supprimées comprises (`deleted`) ; ni `allowRegistration` ni inscriptions |
| `*.image` | FileRef\|null | `pub-images`/`ride-images`/`trip-images` `/<teamId>/<id>.<png\|jpg\|jpeg>` ; première extension trouvée dans l'ordre PNG, JPEG ; `null` si `deleted` |
| `rides[].groups` | | ordre §6.3 ; **sans** participants |
| `trips[].stages` | | ordre §6.3 ; **sans** participants |
| `trips[].markdownPage` | string\|null | page `/trips/{id}/notes` ; importée à la fin de la description du voyage, sous un titre `## Notes` (§13, décision 13) |

`FileRef` :

| Champ | Type | Règle |
|---|---|---|
| `kind` | enum | `GPX`, `RIDE_IMAGE`, `TRIP_IMAGE`, `PUBLICATION_IMAGE`, `LOGO` |
| `path` | string | chemin absolu **relatif à l'hôte** de l'endpoint de fichier (§6.4) ; Pédalons le préfixe de `PEDALONS_BIKETEAM_EXPORT_URL` et refuse tout `path` qui ne commence pas par `/internal/pedalons/teams/{teamId}/files/` |
| `fileName` | string | nom du fichier sur disque (son extension guide Pédalons) |
| `contentType` | string | `application/gpx+xml`, `image/png`, `image/jpeg` |
| `size` | int | octets |
| `md5` | string | 32 hex minuscules de l'**intégralité** du fichier |

`size` et `md5` servent l'empreinte des GPX (`"<size>:<md5>"`, **format identique** à celui
qu'écrit l'ancien import dans `biketeam_migration_map.source_fingerprint`) : un parcours dont le
fichier n'a pas changé n'est **pas téléchargé** et saute tout le pipeline GPX, y compris pour une
équipe déjà importée par l'ancien chemin. biketeam peut mettre les digests en cache mémoire, clé
`(chemin, taille, mtime)` — 2 600 GPX à relire à chaque instantané coûtent quelques secondes.

### 6.3 Ordre d'affichage (à reproduire à l'export)

Biketeam ne stocke aucun ordre et trie en Java au rendu. L'export trie **avec les mêmes
comparateurs**, rendus totaux (valeurs nulles en dernier, `id` pour départager les égalités exactes,
là où biketeam trie un `HashSet` sans ordre défini) :

| Tableau | Comparateur |
|---|---|
| `rides[].groups` | `meetingTime` (nulls en dernier), puis `name` par `String::compareTo`, puis `id` — `Ride.getSortedGroups()` |
| `trips[].stages` | `date` (nulls en dernier), puis `name`, puis `id` — `Trip.getSortedStages()` |
| `rideTemplates[].groups` | `name` **seul**, puis `id` — `RideTemplate.getSortedGroups()` |

Attention : les `getSorted*()` existants lèvent une NPE sur un `meetingTime`/`date` nul ; écrire des
comparateurs dédiés plutôt que de les appeler.

### 6.4 `GET /internal/pedalons/teams/{teamId}/files/{kind}/{entityId}`

`kind` (segment de chemin) ∈ `gpx`, `ride-image`, `trip-image`, `publication-image`, `logo`.
`entityId` = id de la carte / sortie / voyage / publication ; pour `logo`, le `teamId`.

biketeam **résout lui-même** le fichier à partir de `(kind, teamId, entityId)` — jamais un chemin
fourni par l'appelant — après avoir vérifié que l'entité appartient à l'équipe. Réponse `200` en
flux : `Content-Type` du FileRef, `Content-Length`, `ETag: "<md5>"`. Même garde de migration active
que l'instantané.

---

## 7. Pédalons — exécution du job

### 7.1 Worker

`BiketeamLiveMigrationWorker`, `@Scheduled(every = "10s", concurrentExecution = SKIP)`, sans
`@Transactional` (même motif que `UserExportScheduler`) : un job par tick, donc **un seul job à la
fois sur l'instance** (le pipeline GPX est lourd ; c'est voulu). Ne fait rien si la fonction est
désactivée.

1. **Réclamer** : `select … where status = 'QUEUED' and next_attempt_at <= now() order by queued_at
   limit 1 for update skip locked`, puis CAS `QUEUED → RUNNING`, `attempts += 1`, `started_at` (au
   premier essai), `heartbeat_at = now()`. Motif de `UserExportRepository`.
2. **Contexte** : charger en une transaction un `LiveJobContext` en valeurs simples (ids, flags,
   `base_url`), sans entité gérée — les transactions suivantes sont courtes et nombreuses.
3. **Portée de requête** : activer le contexte requête Arc à la main, `domainResolver.setDomainForTest(domain)`,
   `pedalonsContext.setUserForTest(user)`, et tout exécuter sous `notificationPublisher.silently(…)`
   — exactement comme `BiketeamMigrationService.run()` aujourd'hui (l'historique rejoué n'est pas une
   nouvelle). Revérifier : l'utilisateur est actif, et si l'équipe existe il en est ADMIN ou
   PLATFORM_ADMIN (sinon `FAILED BIKETEAM_NOT_TEAM_ADMIN`).
4. **Instantané** (phase `SNAPSHOT`) : `BiketeamExportClient.fetchSnapshot(teamId)`
   (`java.net.http.HttpClient`, `export-snapshot-timeout` (5 min) jusqu'aux en-têtes de
   l'instantané, 120 s pour ceux d'un fichier ; le corps — instantané ou fichier — est
   abandonné après `export-idle-timeout` sans un octet (60 s) ou `export-transfer-timeout` en tout
   (10 min), en `EXPORT_UNAVAILABLE` réessayé). `schemaVersion != 1` ou `team.id != teamId` →
   `EXPORT_INVALID`.
5. **Cible** (phase `TEAM`) : §7.3.
6. **Mapping** : `BiketeamMigrationService` avec la source instantané (§7.2), phases `PLACES` →
   `ROUTES` → `RIDE_TEMPLATES` → `PUBLICATIONS` → `RIDES` → `TRIPS` (l'ordre de `migrateTeam`
   aujourd'hui). Progression et `heartbeat_at` écrits dans leur propre transaction courte au plus
   toutes les 5 s et **avant chaque parcours** (un seul GPX peut tenir plusieurs minutes), et
   **pendant un téléchargement** au plus une fois par minute, à la lecture du corps, hors de toute
   transaction d'élément.
7. **URL** (phase `URLS`) : §8.4, stockée dans `result`.
8. `SUCCEEDED`, `finished_at`, `progress.phase = DONE`.

**Échecs.** Une exception au niveau de l'équipe (étapes 3 à 5, ou hors frontière par élément) :
- réseau / 3xx / 5xx de l'export, ou 4xx **sans** corps JSON `{"code": …}` de biketeam (proxy sans
  route, redémarrage, export désactivé = 404 sans corps) : si `attempts < max-attempts` (défaut 3),
  retour `QUEUED` avec `next_attempt_at = now + 2^attempts min` ; sinon `FAILED EXPORT_UNAVAILABLE` ;
- 4xx de l'export portant le `code` JSON de biketeam : `FAILED EXPORT_REFUSED`, pas de nouvelle
  tentative ;
- téléchargement d'un fichier (GPX, image, logo) : seul `404 {"code":"FILE_NOT_FOUND"}` (ou des
  octets qui ne correspondent pas à l'instantané) reste un avertissement `FILE_DOWNLOAD_FAILED` sur
  l'élément ; une autre réponse est un échec **de la tentative**, classé comme ci-dessus — un job ne
  termine jamais `SUCCEEDED` avec les éléments qu'une coupure de biketeam lui a coûtés ;
- erreur métier (§7.3) : `FAILED` avec son code, pas de nouvelle tentative ;
- autre : comme le réseau, code final `INTERNAL_ERROR`.

**Reprise après crash.** Toutes les 5 min, un job `RUNNING` dont `heartbeat_at` a plus de
`pedalons.biketeam.stuck-after` (défaut **20 min**) repasse `QUEUED` si `attempts < max-attempts`,
sinon `FAILED WORKER_LOST` — deux `UPDATE` conditionnels en masse, sans `@Version`. Le démarrage
échoue si `stuck-after` est inférieur au plus long silence d'un job vivant + 2 min : en-têtes d'un
fichier (120 s) + une lecture inactive (`export-idle-timeout`) + 1 min de battement + transaction
d'un parcours (600 s), ou en-têtes de l'instantané (`export-snapshot-timeout`) + lecture inactive +
1 min (16 min avec les défauts). La migration
étant idempotente, reprendre depuis le début est correct et rapide (empreintes GPX, §7.5).

**Ménage.** Toutes les heures : `GRANTED` dont `grant_expires_at` est passé → `EXPIRED`. Chaque nuit,
les lignes terminées depuis plus d'un an (`SUCCEEDED`, `FAILED`, `EXPIRED`) sont supprimées : la
politique de confidentialité l'annonce (§6 ; ledger `LEGAL-12`). `biketeam_migration_map` n'est
pas touchée.

### 7.2 Une source, deux implémentations

> Historique pour ce qui touche à l'ancien import : `BiketeamReader`, `LegacyJdbcBiketeamSource`,
> `PeopleData` et le `run()` legacy ont été supprimés le 28 septembre 2026.
> `SnapshotBiketeamSource` est aujourd'hui la seule implémentation de `BiketeamSource`.

Le mapping (1 800 lignes, dont toutes les subtilités de `MIGRATE_BIKETEAM.md`) est **conservé** ; on
change sa source de données.

- `BiketeamModel` (nouveau, **non** déprécié) : les records `BtTeam`, `BtTeamDescription`, `BtPlace`,
  `BtMap`, `BtRide`, `BtRideGroup`, `BtRideTemplate`, `BtRideGroupTemplate`, `BtTrip`, `BtTripStage`,
  `BtPublication`, déplacés hors de `BiketeamReader`. Les records de personnes (`BtUser`,
  `BtUserRole`, `BtRideGroupParticipant`, `BtTripParticipant`, `BtMessage`) vivaient dans
  `BiketeamReader`, supprimé avec l'ancien import le 28 septembre 2026.
- `BiketeamSource` (interface) : `team()`, `teamDescription()`, `teamMarkdownPage()`, `zone()`,
  `places()`, `maps()`, `rideTemplates()` + `rideGroupTemplates()`, `publications()`, `rides()` +
  `rideGroups()`, `trips()` + `tripStages()` (listes **déjà ordonnées**), et pour les fichiers
  `gpx(mapId)`, `image(kind, entityId)`, `logo()` qui rendent un `SourceFile` :
  `fileName()`, `fingerprint()` (`"size:md5"` ou `null`), `md5()`, `open()` → `Path` (téléchargé
  **à la demande** dans un répertoire temporaire du job, supprimé à la fin du job).
- `SnapshotBiketeamSource` : construit sur l'instantané désérialisé + `BiketeamExportClient`.
  Convertit les champs vers les records (`deleted` → `deletion`, `startPoint.lat` → `startPointLat`,
  etc.). `zone()` = `ZoneId.of(team.timezone)`, repli `Europe/Paris` si invalide (journalisé).
- ~~`LegacyJdbcBiketeamSource`~~ (supprimée le 28 septembre 2026 avec l'ancien import) : enveloppait `BiketeamReader` + le `data-dir` ;
  `zone()` = `Europe/Paris` ; `fingerprint()` = `digest(Path)` actuel.

Refactorisation de `BiketeamMigrationService` :

- `migrateTeamContent(Run r)` (privée ; `Run` porte équipe, acteur, source, fuseau, id biketeam,
  progression) : description, FAQ, logo, lieux, parcours, modèles, publications, sorties, voyages.
  Aucune participation ni aucun utilisateur n'est migré (`PeopleData`, prévu pour le chemin legacy,
  a disparu avec lui le 28 septembre 2026).
- Les constantes `PARIS` / `atParis` deviennent un fuseau passé par la source (`atZone(zone, …)`).
- `ensureLiveTargetTeam(domain, actor, btTeam, zone, expectedTeamId, setAside)` (règles du §7.3) :
  le créateur est le confirmant, suivi de `ensureMembership(team, actor, ADMIN)` (`ensureTargetTeam`
  était le chemin legacy, supprimé le 28 septembre 2026).
- Toutes les écritures de mapping passent `biketeamTeamId` (§8.1).
- Legacy : `run()` (toutes les équipes, admin de bootstrap, puis utilisateurs, adhésions,
  participations, commentaires) a été supprimé le 28 septembre 2026 (`d93fd3af`) ;
  `migrateTeamLive` est le seul point d'entrée.
- Point d'entrée direct : `migrateTeamLive(Domain domain, User actor, BiketeamSource source,
  @Nullable Long expectedTeamId, @Nullable Runnable setAside, LongConsumer onTarget,
  BiketeamMigrationProgress progress)`.

### 7.3 Résolution de la cible, `reset`, conflits

> **2026-11-11 — le `reset` n'existe plus.** Les deux lignes « `reset` » du tableau ci-dessous
> sont caduques (une équipe `EXISTING_MIGRATED` est toujours réutilisée, épinglée par un
> `DomainAlias` ou non, quel que soit le slug normalisé), de même que `BIKETEAM_RESET_BLOCKED`. La
> **mise au rebut** reste, pour le seul cas d'une équipe issue de ce `teamId` trouvée **à la
> corbeille** : elle y est déjà (`t.deleted` ne change pas), son slug est renommé
> `<slug>-reset-<jobTsid>` — suffixe conservé, des lignes le portent — et son mapping oublié.

`m` = `biketeam_migration_map[TEAM, teamId]`, lu **en premier** : une équipe migrée reste cette
équipe quel que soit son slug actuel (renommée sur Pédalons, elle est rejouée ou remise à zéro, pas
dupliquée). `slug` = `teamId` normalisé (§13.19). `t` = équipe du domaine à `slug` **corbeille
comprise** (`uk_teams_domain_slug` porte aussi sur les équipes supprimées ; `findBySlugAndDomain` les
ignore, il faut une requête dédiée), consultée seulement si `m` n'est pas une équipe active du
domaine.

| Situation | Action |
|---|---|
| `m` pointe une équipe active d'un **autre** domaine | `FAILED BIKETEAM_MIGRATED_IN_OTHER_DOMAIN` (la clé de mapping est globale, §8.1) |
| `m` pointe une équipe active du domaine, **quel que soit son slug** | `EXISTING_MIGRATED` : lignes « active » ci-dessous (contrôle ADMIN, `reset`) |
| `t` absente | créer (si `m` est une équipe du domaine à la corbeille, ailleurs qu'à `slug` : mise au rebut d'abord) |
| `t` présente, `m` absent ou ≠ `t.id` | `FAILED BIKETEAM_SLUG_CONFLICT` — **jamais** toucher une équipe native |
| `t` présente, `m = t.id`, `t` à la corbeille | mise au rebut (ci-dessous), puis créer — l'équipe a été supprimée sur Pédalons, on la recrée |
| `t` présente, `m = t.id`, active, `reset` | vérifier qu'aucun `DomainAlias` ne l'épingle (sinon `FAILED BIKETEAM_RESET_BLOCKED`), mise au rebut, créer |
| `m` active du domaine **à un autre slug** (renommée), `reset`, `slug` pris par une autre équipe (`t` présente, `t.id ≠ m`) | `SLUG_CONFLICT` dès l'aperçu et la confirmation, `FAILED BIKETEAM_SLUG_CONFLICT` au job — **rien** n'est mis à la corbeille |
| `t` présente, `m = t.id`, active, sans `reset` | réutiliser (rejeu idempotent) |

**Mise au rebut** — dans la transaction même qui crée la nouvelle équipe, avant d'y revérifier que
`slug` est libre : un conflit (ou une création concurrente, `uk_teams_domain_slug`) annule le tout, et
l'ancienne équipe reste intacte, mapping compris : `t.deleted = true` (la même suppression logique que
`TeamService.deleteTeam`), `t.slug = <slug>-reset-<jobTsid>` (slug d'origine raccourci pour que le
tout tienne dans les 200 caractères d'un slug, suffixe intact) pour libérer le slug,
puis `delete from biketeam_migration_map where biketeam_team_id = :teamId or (entity_type,
biketeam_id) in (<clés de l'instantané>)` — la seconde clause couvre les lignes écrites par l'ancien
import, qui n'ont pas de `biketeam_team_id`. Aucune donnée n'est effacée physiquement.

Les mêmes règles sont évaluées à l'aperçu et à la confirmation (§4) pour échouer tôt ; le job les
réévalue car l'état a pu changer entre-temps.

### 7.4 Ce qui change dans le mapping, et ce qui ne change pas

Inchangé (voir `MIGRATE_BIKETEAM.md`, sections *Ordering*, *Visibility*, *Dates*, *Team pages*,
*Team logos*) : visibilité équipe → contenu, `listed_in_feed` → `PUBLIC_UNLISTED`, `joinable`,
statuts, antidatage `createdAt` (`backdate`), heure inventée des étapes (1re = `meetingTime` du
voyage, suivantes 8:00), `sortOrder` = index, FAQ en page additionnelle « FAQ » par le dépôt (pas le
service plafonné), logo factice écarté par MD5, directives `::asset{}` des images, empreinte des GPX,
`RideGroupDto.leader` **non renseigné** (null ; jamais de repli sur `createdBy`).

Changé :

| Point | Avant | En direct |
|---|---|---|
| Fuseau | `Europe/Paris` en dur | `team.timezone` de l'instantané |
| Auteur (`createdBy`), membre ADMIN | admin de bootstrap, PLATFORM_ADMIN, **non** membre | le confirmant, membre **ADMIN** |
| Utilisateurs, adhésions, participations, commentaires | importés | **aucun** |
| Vent | `NORTHEAST`… attendus, alors que biketeam écrit `NORTH_EAST` : **les quatre diagonales étaient perdues** | accepter `NORTH_EAST` **et** `NORTHEAST` (corrige aussi le legacy) |
| GPX | lu sur disque | téléchargé seulement si l'empreinte diffère |
| Images, logo | lus sur disque | téléchargés seulement si la clé `ASSET` n'est pas déjà mappée (comme aujourd'hui) |
| Mapping | `(type, biketeamId) → id` | idem + `biketeam_team_id` |

Garde-fou recommandé : en direct, un id trouvé dans le mapping n'est cru que si l'entité appartient à
l'équipe cible (`findByIdAndTeam`) — une ligne périmée crée alors un doublon plutôt que de modifier
une autre équipe. Ni si elle est à la corbeille : elle est recréée (§13.21).

### 7.5 Idempotence, rejeu, concurrence

- **Rejeu** : chaque migration rejoue tout ; les lignes déjà migrées sont retrouvées
  par le mapping et mises à jour sur place. Une migration relancée ne recrée rien, elle
  resynchronise ce qui a changé côté biketeam entre-temps.
- **Un seul job actif par `teamId`** : index unique partiel (§8.1) + `409` au déclenchement +
  `MIGRATION_RUNNING` à l'aperçu. Un seul job à la fois sur l'instance (worker `SKIP`).
- **Déclenchement rejoué** : `200` avec le même `jobId` (§5.1).
- **Crash** : §7.1. Un parcours interrompu en plein envoi n'a pas d'empreinte et sera refait.
- **Pas de mode** (2026-11-11) : il n'y a qu'une exécution, incrémentale. La bascule est une
  action de biketeam, postérieure et distincte (§9.2).

---

## 8. Données Pédalons

### 8.1 Flyway `V43__biketeam_live_migration.sql`

```sql
-- One row per confirmed biketeam request. The row is the grant (hashed) and, once biketeam has
-- redeemed it, the job queue — the same "row is the queue" shape as user_exports.
create table biketeam_migrations
(
    id                 bigint                      not null,
    domain_id          bigint                      not null,
    user_id            bigint                      not null,
    biketeam_team_id   varchar(255)                not null,
    biketeam_team_name varchar(250)                not null,
    request_id         varchar(64)                 not null,
    dry_run            boolean                     not null,
    reset              boolean                     not null,
    return_url         varchar(1000)               not null,
    base_url           varchar(500)                not null, -- domains.base_url at confirm time
    grant_hash         varchar(100)                not null,
    grant_expires_at   timestamp(6) with time zone not null,
    status             varchar(20)                 not null, -- GRANTED, EXPIRED, QUEUED, RUNNING, SUCCEEDED, FAILED
    attempts           integer                     not null default 0,
    next_attempt_at    timestamp(6) with time zone,
    heartbeat_at       timestamp(6) with time zone,
    progress           jsonb,
    target_team_id     bigint,
    result             jsonb,                                  -- counts, warnings, urlMap
    error_code         varchar(60),
    error_message      varchar(1000),
    queued_at          timestamp(6) with time zone,
    started_at         timestamp(6) with time zone,
    finished_at        timestamp(6) with time zone,
    created_at         timestamp(6) with time zone not null,
    updated_at         timestamp(6) with time zone not null,
    version            bigint,
    primary key (id)
);
alter table biketeam_migrations add constraint uk_biketeam_migrations_request unique (request_id);
alter table biketeam_migrations add constraint uk_biketeam_migrations_grant unique (grant_hash);
alter table biketeam_migrations add constraint fk_biketeam_migrations_domain foreign key (domain_id) references domains;
alter table biketeam_migrations add constraint fk_biketeam_migrations_user foreign key (user_id) references users on delete cascade;
alter table biketeam_migrations add constraint fk_biketeam_migrations_team foreign key (target_team_id) references teams;
-- One active job per biketeam team, whatever the domain.
create unique index uk_biketeam_migrations_active on biketeam_migrations (biketeam_team_id)
    where status in ('QUEUED', 'RUNNING');
create index idx_biketeam_migrations_status on biketeam_migrations (status, next_attempt_at);

-- Which biketeam team a mapping row came from, so a reset can forget exactly that team. NULL on the
-- rows the legacy import wrote; the live path fills it on every upsert.
alter table biketeam_migration_map add column biketeam_team_id varchar(255);
create index idx_biketeam_migration_map_team on biketeam_migration_map (biketeam_team_id);
```

**2026-11-11** — `V88__biketeam_migration_options_default.sql` donne un défaut aux colonnes
`dry_run` (`true`) et `reset` (`false`), que l'entité `BiketeamMigrationJob` ne porte plus. Elles ne
sont pas supprimées : les déploiements sont *rolling, start-first*, et la version précédente, qui
partage la base une minute (ou y revient en cas de retour arrière), les écrit encore. Leur
suppression est l'entrée `MIG-17` du ledger.

La clé primaire de `biketeam_migration_map` reste `(entity_type, biketeam_id)`, **globale** : les
ids biketeam sont des UUID (les clés d'équipe, de page et de logo portent le `teamId`), et une base
Pédalons ne reçoit une équipe biketeam que dans **un** domaine — c'est la règle
`MIGRATED_IN_OTHER_DOMAIN`. Pas de rétro-remplissage de `biketeam_team_id` : la mise au rebut couvre
les lignes legacy par les clés de l'instantané (§7.3).

Entité `BiketeamMigrationJob` + `BiketeamMigrationJobRepository` (motif `UserExport` ; `jsonb` via
`@Type(JsonBinaryType.class)` comme `NotificationEventEntry.payload`). Nouveaux paquets : un
`package-info.java` `@NullMarked` chacun (`ArchitectureTest`).

### 8.2 Configuration (`application.properties`)

```properties
# ===========================================
# Biketeam live migration (off unless all five values below are set)
# ===========================================
# See docs/plans/2026-09-22-biketeam-live-migration.md. Optional<String> on the Java side: SmallRye
# turns an empty value into null and refuses to inject it.
#   PEDALONS_BIKETEAM_REQUEST_KEY    base64 HMAC key (>= 32 bytes) biketeam signs requests with
#   PEDALONS_BIKETEAM_TRIGGER_SECRET header secret biketeam sends to /api/internal/…
#   PEDALONS_BIKETEAM_EXPORT_URL     biketeam public base URL, https:// (http:// only to localhost)
#   PEDALONS_BIKETEAM_EXPORT_SECRET  header secret sent to biketeam's /internal/pedalons/…
#   PEDALONS_BIKETEAM_PUBLIC_URL     biketeam's public site.url, e.g. https://www.prendslaroue.fr
pedalons.biketeam.grant-ttl=PT10M
pedalons.biketeam.max-attempts=3
# A RUNNING job without a heartbeat for stuck-after is requeued. Startup fails unless it exceeds
# the longest silence of a live job: export-snapshot-timeout + idle + 1 min, or a file's 120 s
# headers + idle + 1 min + the 600 s transaction of a route — plus 2 min (16 min with the defaults).
pedalons.biketeam.stuck-after=PT20M
# A response body of the export that sends nothing for export-idle-timeout, or takes more than
# export-transfer-timeout in all, is given up (EXPORT_UNAVAILABLE, retried). Downloads write the
# heartbeat at most once a minute while data comes in.
pedalons.biketeam.export-idle-timeout=PT60S
pedalons.biketeam.export-transfer-timeout=PT10M
# How long the snapshot's headers may take (a file's: 120 s): biketeam may hash a big team's files
# before it answers.
pedalons.biketeam.export-snapshot-timeout=PT5M
```

Clés lues : `pedalons.biketeam.request-key`, `.trigger-secret`, `.export-url`, `.export-secret`,
`.public-url` (env dérivés automatiquement ci-dessus). **Aucune** renseignée : fonction désactivée,
tous les endpoints en `404`, worker inerte, une ligne INFO au démarrage. **Une partie seulement** :
échec du démarrage (`IllegalStateException` nommant les manquantes) — une moitié de configuration est
toujours une erreur. Clé de demande non décodable ou < 32 octets : échec du démarrage.
`export-url` en `http://` hors `localhost`/`127.0.0.1` : échec du démarrage (§3.4).

### 8.3 Nouvelles classes (indicatif)

`fr.pedalons.service.migration.live` : `BiketeamLiveMigrationConfig`, `BiketeamRequestTokenVerifier`,
`BiketeamMigrationGrantService` (aperçu, confirmation), `BiketeamMigrationJobService` (déclenchement,
statut, réclamation, reprise), `BiketeamLiveMigrationWorker`, `BiketeamExportClient`,
`SnapshotBiketeamSource` + `snapshot/*` (records Jackson de §6.2), `BiketeamMigrationUrls`.
`fr.pedalons.service.migration` : `BiketeamModel`, `BiketeamSource`, `SourceFile`,
`LegacyJdbcBiketeamSource` (supprimée avec l'ancien import). `fr.pedalons.service.security` : `BiketeamM2MFilter` +
`annotation/BiketeamM2M`. `fr.pedalons.api.migration` : `BiketeamMigrationResource` (public),
`BiketeamMigrationInternalResource` (M2M). `fr.pedalons.dto.migration` : DTO de §4 et §5.

### 8.4 Table de correspondance d'URL

Construite à la fin du job **à partir de l'instantané** (pas du mapping seul) : pour chaque entité
non supprimée, id Pédalons par le mapping, slug courant de l'entité (qui doit appartenir à l'équipe
cible et ne pas être supprimée). Par type, une requête sur le mapping et une sur les slugs, par
paquets de 1 000 ids : un nombre de requêtes indépendant du volume. Une entité absente ou en échec n'a pas d'entrée — biketeam
retombera sur la page d'équipe.

URL absolues = `base_url` de la ligne (le `Domain.baseUrl` parent au moment de la confirmation,
jamais un alias) + la forme **`fr`** de `contracts/routes.yaml` (public biketeam francophone ; les
deux routeurs acceptent toutes les langues, comme le rappelle `NotificationLinks`). Segments encodés
comme segments de chemin. `BiketeamMigrationUrls` porte le commentaire « a route renamed in
contracts/routes.yaml must be renamed here ».

| Clé `urlMap` | Clé interne | Route (`routes.yaml` id) | Chemin |
|---|---|---|---|
| `TEAM` | `teamId` | `team` | `/equipes/{teamSlug}` |
| `TEAM_ABOUT` | `teamId` | `teamAbout` | `/equipes/{teamSlug}/a-propos` |
| `TEAM_FAQ` | `teamId` (si la FAQ existe) | `teamPage` | `/equipes/{teamSlug}/pages/{pageSlug}` |
| `ROUTES_LIST` | `teamId` | `routes` | `/equipes/{teamSlug}/parcours` |
| `ROUTE` | `map.id` | `route` | `/equipes/{teamSlug}/parcours/{routeSlug}` |
| `RIDE` | `ride.id` | `ride` | `/equipes/{teamSlug}/sorties/{rideSlug}` |
| `TRIP` | `trip.id` | `trip` | `/equipes/{teamSlug}/voyages/{tripSlug}` |
| `TRIP_STAGE` | `trip_stage.id` | `stage` | `/equipes/{teamSlug}/voyages/{tripSlug}/etapes/{stageSlug}` |
| `POST` | `publication.id` | `post` | `/equipes/{teamSlug}/articles/{postSlug}` |

Les URL restent valides si l'équipe ou un contenu change ensuite de slug sur Pédalons : les tables de
redirection de slug existantes (`team_slug_redirects`, `team_entity_slug_redirects`) s'en chargent.

---

## 9. biketeam

Style du dépôt : identifiants en anglais, **commentaires en français** comme le reste du code
biketeam, gabarits FreeMarker `.ftlh`, `@Value` pour la configuration, changesets dans
`schema-1.0.xml`.

### 9.1 Liquibase (à la fin de `schema-1.0.xml`, `author="tomacla"`)

- `pedalons-migration-table` — `pedalons_migration` :
  `id VARCHAR(36)` PK (= `requestId`), `team_id VARCHAR(255)` NOT NULL FK `team(id)`,
  `requested_by VARCHAR(255)` NULL FK `user_account(id)` **ON DELETE SET NULL**,
  `status VARCHAR(20)` NOT NULL, `dry_run BOOLEAN` NOT NULL, `reset BOOLEAN` NOT NULL (les deux
  sans objet depuis le 2026-11-11 ; leur sort est laissé à biketeam),
  `grant_value VARCHAR(100)` NULL (effacé dès le job créé), `pedalons_job_id VARCHAR(40)` NULL,
  `created_at TIMESTAMP` NOT NULL, `updated_at TIMESTAMP` NOT NULL, `triggered_at TIMESTAMP`,
  `finished_at TIMESTAMP`, `switched_at TIMESTAMP`, `error_code VARCHAR(60)`,
  `error_message VARCHAR(2000)`, `result_json TEXT` (dernier statut reçu, tel quel),
  `pedalons_team_url VARCHAR(1000)` ; index `(team_id, status)`.
- `pedalons-redirect-table` — `pedalons_redirect` : `team_id VARCHAR(255)` FK `team(id)` ON DELETE
  CASCADE, `entity_type VARCHAR(20)`, `entity_id VARCHAR(255)`, `target_url VARCHAR(1000)`, tous NOT
  NULL, PK `(team_id, entity_type, entity_id)`. `entity_type` = clés de `urlMap`.
- `team-pedalons-columns` — `team` : `pedalons_state VARCHAR(20)` NULL (`MIGRATED`, seule valeur
  depuis le 2026-11-11 : `MIGRATING`, le gel pendant un définitif, et `READY`, le gel en attente de
  bascule, ont disparu), `pedalons_url VARCHAR(1000)` NULL,
  `pedalons_migrated_at TIMESTAMP` NULL.
- `pedalons-migration-running-since` — `pedalons_migration.running_since TIMESTAMP` NULL (premier
  `RUNNING` rapporté ; le délai de 6 h en part, l'attente en `QUEUED` a son propre délai de 48 h
  depuis `triggered_at`).

### 9.2 États de `pedalons_migration`

```
REQUESTED ──callback outcome=cancelled──▶ CANCELLED
    │  (nouvelle demande pour l'équipe, ou > 75 min) ─▶ CANCELLED / EXPIRED
    │ callback grant
    ▼
TRIGGERING ──202/200──▶ RUNNING ──statut SUCCEEDED──▶ SUCCEEDED
    │                     │
    │ refus / 3 échecs    ├──statut FAILED, 404 BIKETEAM_JOB_NOT_FOUND, ou délai dépassé──▶ FAILED
    ▼                     │
  FAILED                  └──annulation par l'admin plateforme (unswitch, §9.6)──▶ CANCELLED
                             (vaut aussi pour TRIGGERING)
```

L'état de la bascule est porté par l'équipe, pas par la demande (2026-11-11) :

```
team.pedalons_state :  null ──« Basculer vers Pédalons » (une migration SUCCEEDED existe)──▶ MIGRATED
                         ▲                                                                   │
                         └──────────── annulation par l'admin plateforme (§9.6) ─────────────┘
```

- **Démarrage** `POST /{teamId}/admin/pedalons/start` (sans option depuis le 2026-11-11 ; ajouté à la liste
  CSRF de `SecurityConfig`, formulaire avec `_csrf`) : refusé si la fonction est désactivée, si
  `team.pedalons_state = MIGRATED`, ou si une ligne `TRIGGERING`/`RUNNING` existe. Les `REQUESTED` de
  l'équipe passent `CANCELLED`. Nouvelle ligne `REQUESTED`, jeton §3.2, `303` vers
  `{PEDALONS_URL}/migration-biketeam?request=<jeton>` (jeton encodé URL).
- **Callback** `GET /{teamId}/admin/pedalons/callback` (sous `/{teamId}/admin/**`, donc session admin
  exigée) : `request` doit désigner une ligne `REQUESTED` de **cette** équipe créée il y a moins de
  75 min (validité du jeton 60 min + 15 min de grâce), par le même compte biketeam, sinon message
  d'erreur sur la page d'admin.
  - `outcome=cancelled` → `CANCELLED`.
  - `grant=…` → `TRIGGERING`, `grant_value`, `triggered_at` — **aucun gel** : l'équipe reste
    modifiable pendant la migration ; puis déclenchement §5.1, corps `{requestId, grant, teamId}`
    (3 tentatives à 0/2/5 s sur réseau ou 5xx, même grant — le rejeu est idempotent) :
    - `202`/`200` → `RUNNING`, `pedalons_job_id`, `grant_value = null` ;
    - `409 BIKETEAM_MIGRATION_RUNNING`, `403`, `400`, `401`, `404`, ou 3 échecs → `FAILED`
      (`error_code` = `code` reçu, ou `TRIGGER_UNAVAILABLE`).
  - Réponse : `303` vers `/{teamId}/admin/pedalons`, `Referrer-Policy: no-referrer`.
- **Suivi** `PedalonsMigrationPoller`, `@Scheduled(fixedDelay = 15000)` : pour chaque `RUNNING`,
  `GET` statut §5.2, `result_json` = corps reçu.
  - `SUCCEEDED` : `finished_at`, `pedalons_team_url = targetTeam.url`, `result_json` (qui porte
    `urlMap`). **Rien d'autre**, avertissements ou non : ni table d'URL écrite, ni gel, ni
    bascule. L'équipe reste modifiable et non redirigée ; la page affiche le bilan, les liens, et
    propose de relancer une migration ou de « Basculer vers Pédalons ».
  - `FAILED` : `error_code`/`error_message` de `error`.
  - `404 {"code":"BIKETEAM_JOB_NOT_FOUND"}` : `FAILED JOB_LOST` ; tout autre `404` est
    transitoire (§5.2). Réseau : on réessaie au tick suivant ; sans état terminal 6 h après le
    premier `RUNNING` rapporté (48 h en `QUEUED` depuis le déclenchement) : `FAILED TIMEOUT`.
- **Bascule** `POST /{teamId}/admin/pedalons/switch` (liste CSRF), bouton « Basculer vers
  Pédalons » : seulement si l'équipe a une migration `SUCCEEDED` et aucune migration active. Dans
  une transaction : les `pedalons_redirect` de l'équipe sont remplacés par l'`urlMap` de la
  **dernière migration réussie** (`result_json`), `pedalons_url` est renseigné,
  `team.pedalons_state` passe **directement** à `MIGRATED` (conditionnel), avec
  `pedalons_migrated_at` et le `switched_at` de cette migration ; les demandes `REQUESTED`
  restantes sont annulées ; puis le cache du filtre est rafraîchi. Il n'y a **pas d'étape
  intermédiaire** (ni `READY`, ni gel avant bascule). Ce que l'équipe a modifié sur biketeam après
  sa dernière migration réussie n'arrive pas sur Pédalons : l'admin relance une migration juste
  avant de basculer s'il le faut.
- Une ligne `TRIGGERING` de plus de 3 min (`TRIGGERING_STUCK_AFTER`, pour rejouer dans la fenêtre
  du grant de 10 min) (crash entre callback et réponse) : le poller rejoue le
  déclenchement avec `grant_value` (idempotent) ; grant expiré → `FAILED`.

### 9.3 Page d'admin `/{teamId}/admin/pedalons`

Gabarit `team_admin_pedalons.ftlh`, entrée « Migrer vers Pédalons » dans
`_includes_team_admin_aside.ftlh` (bloc *Administration*), masquée si la fonction est désactivée.
Contenu : ce qui sera migré (compteurs) et ce qui **ne** le sera **pas** (membres, inscriptions,
commentaires, notes (évaluations) et favoris de parcours) ; **aucune option** (ni « Essai », ni
« Réinitialiser le groupe sur Pédalons avant la migration », retirées le 2026-11-11) : la migration
copie ou met à jour l'équipe sur Pédalons, se relance à volonté et ne change rien sur biketeam.
En cours : phase et progression (`result_json`), rafraîchissement automatique toutes les
10 s (`<meta http-equiv="refresh">`). Terminé : compteurs, avertissements, lien vers l'équipe
Pédalons ; dès qu'une migration a réussi, bouton « Basculer vers Pédalons » (§9.2), avec le rappel
que toutes les URL de l'équipe redirigeront vers Pédalons, que l'équipe passera en lecture seule,
et que ce qui a changé sur biketeam depuis la dernière migration réussie ne sera pas repris sans
la relancer ; historique des
demandes de l'équipe.

### 9.4 Redirections (après bascule)

`PedalonsRedirectFilter`, filtre servlet enregistré par `FilterRegistrationBean` **avant** la chaîne
Spring Security (une équipe privée redirige sans demander de connexion ; Pédalons applique ses
propres droits). Cache mémoire `teamId → (état, table)` chargé au démarrage, invalidé à la bascule et
à l'annulation (instance unique).

Le premier segment du chemin, **en minuscules** (`TeamService.get` minuscule aussi), est comparé aux
équipes `MIGRATED`. Aucune collision possible avec les routes globales (`/teams`, `/catalog`…) :
seules les équipes basculées sont testées. Exclus : `/internal/pedalons/**`.

Résolution : `{idOrPermalink}` → id biketeam par les services existants (`RideService.get(teamId, x)`
etc., qui acceptent id ou permalien), puis `pedalons_redirect`. Tout ce qui ne résout pas → `TEAM`.

| Chemin biketeam | Cible |
|---|---|
| `/{t}`, `/{t}/` | `TEAM` |
| `/{t}/faq` | `TEAM_FAQ`, sinon `TEAM_ABOUT` |
| `/{t}/maps`, `/{t}/maps/` (+ recherche), `/{t}/maps/android`, `/{t}/maps/garmin`, `/{t}/maps/autocomplete` | `ROUTES_LIST` |
| `/{t}/maps/{mapIdOrPermalink}` et **tout** sous-chemin (`/gpx`, `/fit`, `/garmin`, `/data`, `/image`, `/add-favorite`, `/remove-favorite`, `/rate`) | `ROUTE[mapId]` |
| `/{t}/rides`, `/{t}/rides/` | `TEAM` |
| `/{t}/rides/{rideIdOrPermalink}` et sous-chemins (`/messages`, `/image`, `/add-participant/…`, `/remove-participant/…`, `/remove-message/…`) | `RIDE[rideId]` |
| `/{t}/trips`, `/{t}/trips/` | `TEAM` |
| `/{t}/trips/{tripIdOrPermalink}` et sous-chemins (`/messages`, `/notes`, `/image`, `/add-participant`, …) | `TRIP[tripId]` |
| `/{t}/publications/{publicationId}` et sous-chemins | `POST[publicationId]` |
| `/api/teams/{t}` et tout sous-chemin | **`410` JSON** avec l'URL de la page d'équipe Pédalons, pas de redirection ni de résolution par entité (voir ci-dessous) |
| `/catalog/trips/{tripId}` d'un voyage d'une équipe basculée | `TRIP[tripId]` |
| tout autre `/{t}/**` (`/join`, `/leave`, `/image`, `/admin/**`, …) | `TEAM` |

Réponse :

- pages HTML et téléchargements (`/{t}/**`, `/catalog/trips/…`, y compris `/gpx`, `/fit`…) :
  `GET`/`HEAD` → redirection `Location: <url>`, query string abandonnée, avec un code
  **configurable** (`pedalons.redirect-status`, nom indicatif) : **302** par défaut, passé à **301**
  une fois la migration stabilisée ; autres méthodes → **410** avec une courte page « Ce groupe a
  déménagé sur Pédalons » et le lien ;
- API (`/api/teams/{t}/**`), toutes méthodes : **410** `application/json`
  `{"code": "TEAM_MIGRATED", "url": "<url>"}`, `url` = la page d'équipe Pédalons (`TEAM` de la
  table, à défaut `pedalons_url`), quel que soit le sous-chemin — un client de l'API
  (application, Garmin) reçoit une erreur lisible plutôt qu'une page HTML.

Repli ultime si une équipe `MIGRATED` n'a pas d'entrée `TEAM` : `team.pedalons_url`.

Domaine personnalisé (`team_configuration.domain`) : la redirection s'applique à ce que voit
l'application, c'est-à-dire `/{teamId}/…` après réécriture par le proxy ; sinon, à traiter au proxy
si besoin (§13, décision 11).

### 9.5 Lecture seule

- **Avant la bascule** : aucun gel (2026-11-11). Les états `MIGRATING` (gel pendant un définitif)
  et `READY` (gel en attente de bascule) ont disparu, et avec eux la réponse **423** /
  `TEAM_FROZEN` du filtre : l'équipe reste modifiable pendant une migration comme après elle. La
  migration est incrémentale — ce qui change sur biketeam est repris par la suivante, d'où le
  conseil d'en relancer une juste avant de basculer.
- **Après bascule** : tout redirige, `/api/` répond `410` (§9.4) ; l'équipe est lecture seule de fait. Les données restent en
  base et sur disque ; rien n'est supprimé.

### 9.6 Annulation de la bascule (admin plateforme)

`POST /admin/teams/pedalons-unswitch/{teamId}` (liste CSRF, bouton dans `admin_teams.ftlh` sur les
équipes `MIGRATED` — inchangée le 2026-11-11, à l'état `READY` près, qui n'existe plus) : `pedalons_state = null`, suppression des `pedalons_redirect` de
l'équipe, cache invalidé ; la migration active éventuelle (`TRIGGERING`/`RUNNING`) passe `CANCELLED`
(`CANCELLED_BY_ADMIN`) dans la même transaction. Tant que le code est 302 (défaut), rien n'est retenu par les navigateurs ; après passage
à 301, ceux qui l'ont mis en cache continueront d'aller sur Pédalons — c'est pourquoi le 301 attend
que la migration soit stabilisée.

### 9.7 Fichiers biketeam à créer / modifier

| Fichier | Rôle |
|---|---|
| `domain/pedalons/PedalonsMigration.java`, `PedalonsMigrationRepository.java`, `PedalonsMigrationStatus.java` | ligne de demande / suivi |
| `domain/pedalons/PedalonsRedirect.java`, `PedalonsRedirectRepository.java` | table d'URL |
| `domain/team/Team.java` (+ `PedalonsState.java`) | colonnes `pedalons_*` |
| `service/pedalons/PedalonsProperties.java` | `@Value` des cinq réglages + code de redirection (302 par défaut), `isEnabled()` |
| `service/pedalons/PedalonsRequestTokenSigner.java` | §3.2 |
| `service/pedalons/PedalonsClient.java` | déclenchement + statut (`RestTemplate`, délais 10 s / 30 s) |
| `service/pedalons/PedalonsMigrationService.java` | états §9.2, bascule manuelle, annulation |
| `service/pedalons/PedalonsMigrationPoller.java` | `@Scheduled` |
| `service/pedalons/export/TeamSnapshotBuilder.java` + records DTO | §6.2, §6.3 (`@Transactional(readOnly = true)`) |
| `service/pedalons/export/FileDigestCache.java` | MD5 en cache |
| `web/pedalons/PedalonsExportController.java` | `@RestController` `/internal/pedalons` |
| `web/pedalons/PedalonsRedirectFilter.java` | §9.4 (le gel §9.5 a disparu le 2026-11-11) |
| `web/team/pedalons/AdminTeamPedalonsController.java` | page, `start`, `callback`, `switch` |
| `web/admin/team/AdminTeamController.java` | annulation §9.6 |
| `SecurityConfig.java` | `permitAll` `/internal/pedalons/**` avant `/{teamId}/**` ; CSRF sur `start`, `switch` et `pedalons-unswitch` ; enregistrement du filtre |
| `templates/team_admin_pedalons.ftlh`, `_includes_team_admin_aside.ftlh`, `admin_teams.ftlh` | IHM |
| `liquibase/schema-1.0.xml` | §9.1 |
| `.env.template`, `README.md` | §10 |

---

## 10. Configuration

### Pédalons (`.env`, documenté dans `.env.example`)

| Variable | Exemple | Rôle |
|---|---|---|
| `PEDALONS_BIKETEAM_REQUEST_KEY` | `openssl rand -base64 32` | vérifie le jeton de demande |
| `PEDALONS_BIKETEAM_TRIGGER_SECRET` | `openssl rand -base64 32` | authentifie biketeam sur `/api/internal/` |
| `PEDALONS_BIKETEAM_EXPORT_URL` | `https://www.prendslaroue.fr` | base de l'export biketeam : son URL publique, `https://` obligatoire (§3.4) |
| `PEDALONS_BIKETEAM_EXPORT_SECRET` | `openssl rand -base64 32` | envoyé à biketeam |
| `PEDALONS_BIKETEAM_PUBLIC_URL` | `https://www.prendslaroue.fr` | `site.url` de biketeam, valide `returnUrl` |

Le service `backend` lit déjà tout `.env` (`env_file`) : pas d'`environment:` à ajouter.

### biketeam (`.env`, documenté dans `.env.template`)

| Variable | Propriété | Exemple | Rôle |
|---|---|---|---|
| `PEDALONS_URL` | `pedalons.url` | `https://www.pedalons.fr` | redirection du navigateur |
| `PEDALONS_INTERNAL_URL` | `pedalons.internal-url` | `https://www.pedalons.fr` | déclenchement + statut : URL publique de Pédalons (en général = `PEDALONS_URL`), `https://` obligatoire (§3.4) |
| `PEDALONS_REQUEST_KEY` | `pedalons.request-key` | = `PEDALONS_BIKETEAM_REQUEST_KEY` | signe le jeton |
| `PEDALONS_TRIGGER_SECRET` | `pedalons.trigger-secret` | = `PEDALONS_BIKETEAM_TRIGGER_SECRET` | envoyé à Pédalons |
| `PEDALONS_EXPORT_SECRET` | `pedalons.export-secret` | = `PEDALONS_BIKETEAM_EXPORT_SECRET` | vérifie les appels d'export |

`@Value("${pedalons.url:}")` etc. (les propriétés se résolvent depuis l'environnement et le `.env`
par `DotenvPropertySource`, points et tirets devenant `_`). Fonction active seulement si **les cinq**
sont renseignées ; sinon bouton masqué, `/internal/pedalons/**` en 404, poller inerte.

### En local (les deux sur un poste)

Pédalons `mvn quarkus:dev` (8080) + `pnpm dev` (5173) ; biketeam sur **8081** (`SERVER_PORT=8081`)
pour ne pas heurter Quarkus. `PEDALONS_URL=http://localhost:5173`,
`PEDALONS_INTERNAL_URL=http://localhost:8080`, `PEDALONS_BIKETEAM_EXPORT_URL=http://localhost:8081`,
`PEDALONS_BIKETEAM_PUBLIC_URL=http://localhost:8081` (= `SITE_URL` de biketeam). `http://` est
accepté parce que ces URL visent `localhost`.

### Ordre de mise en production

1. Pédalons (fonction éteinte : aucune variable), puis biketeam (idem) — les deux sans effet.
2. Secrets des deux côtés, URL M2M en `https://` (entrées publiques, pas de VPN — §3.4),
   redémarrages, lignes « enabled » dans les deux journaux.
3. **Tags de parcours livrés** (ledger `API-59`, import des `maps[].tags`) avant la **première
   bascule** en prod : une équipe basculée ne se voit plus proposer la migration, ses tags ne
   seraient jamais rattrapés. Les migrations peuvent précéder, elles se rejouent.
4. Migration d'une petite équipe (`gaby`, 7 membres) vers **staging**, puis vers prod, puis bascule.
5. **Retrait de `dryRun` et `reset` (2026-11-11) : Pédalons d'abord, biketeam ensuite.** Le
   Pédalons mis à jour accepte les deux biketeam (il ignore les deux claims et les deux champs du
   déclenchement, §3.2 et §5.1) ; un Pédalons pas encore mis à jour refuserait le jeton sans claims
   du biketeam mis à jour (`BIKETEAM_REQUEST_INVALID`). Entre les deux déploiements, une demande
   `reset: true` ou `dryRun: false` de l'ancien biketeam est une migration incrémentale comme les
   autres côté Pédalons ; l'ancien biketeam, lui, gèle encore l'équipe pendant un « définitif ».

---

## 11. Déprécier l'ancien import

> **Historique — exécuté.** L'ancien import a été supprimé le 28 septembre 2026 (`d93fd3af`) :
> chaque élément marqué ci-dessous est parti, et le marqueur ne subsiste plus que dans ce document.
> La procédure est conservée pour mémoire ; l'entrée de `docs/LEDGER_NEXT.md` qu'elle prévoyait a été
> ajoutée puis close.

Marqueur unique, **grep-able** : `REMOVE-WITH-LEGACY-BIKETEAM-IMPORT`. Il figure sur **chaque**
élément à supprimer, en commentaire dans la syntaxe du fichier (`//`, `#`, `<!-- -->`), suivi d'une
courte raison. En Java, en plus, `@Deprecated(forRemoval = true, since = "4.5.0")` sur les classes et
méthodes. Rien n'est supprimé maintenant ; le legacy doit continuer à compiler et à fonctionner.

| # | Élément | Traitement |
|---|---|---|
| 1 | `service/migration/BiketeamMigrationRunner.java` | classe dépréciée + marqueur |
| 2 | `service/migration/BiketeamMigrationConfig.java` | idem |
| 3 | `service/migration/BiketeamReader.java` | idem (après déplacement des records communs vers `BiketeamModel`) |
| 4 | `service/migration/LegacyJdbcBiketeamSource.java` (nouveau) | né déprécié + marqueur |
| 5 | `BiketeamMigrationService` : `run()`, `runWithinRequest()`, `resolveSourceTeams()`, `migrateUsers`, `migrateUser`, `foldIntoKeptUser`, `UserCounts`, `hasRealEmail`, `hasProvenEmail`, `resolveEmail`, `upsertStravaIdentity`, `upsertUserByEmail`, `createUser`, `updateUser`, `applyProvenEmail`, `displayNameFor`, `migrateUserTeams`, `mapRole`, `migrateMessages`, `migrateOneMessage`, `resolveCommentTarget`, les blocs de participations de `migrateOneRide`/`migrateOneTrip`, `PeopleData`, les constantes `T_USER`, `T_USER_TEAM`, `T_RIDE_PARTICIPATION`, `T_TRIP_PARTICIPATION`, `T_COMMENT`, les injections devenues legacy-only (`userRepository`, `socialIdentityRepository`, `userTeamRepository`, `commentRepository`, `rideParticipationRepository`, `tripParticipationRepository`, `bootstrapService`, `config`, `reader`) | méthodes dépréciées + marqueur sur chaque bloc |
| 6 | `application.properties` : bloc « Biketeam → tribly migration » (datasource `biketeam` + commentaires + `%dev.pedalons.migration.biketeam.exit-when-done`) | marqueur en tête et en fin de bloc |
| 7 | `docker-compose.yml` : service `backend-restore` entier ; commentaire « Shared with backend-restore » du volume cache de `backend` ; commentaire du port postgres citant `biketeam_restore.sh` (le port reste, pour le dev : réécrire le commentaire au moment de supprimer) | marqueur |
| 8 | `scripts/biketeam_fetch.sh`, `scripts/biketeam_restore.sh` | marqueur en tête + ligne « DEPRECATED » dans l'aide |
| 9 | `scripts/restore.sh` (commentaire citant `biketeam_restore.sh`, l. ~175) | marqueur (réécrire le commentaire) |
| 10 | `MIGRATE_BIKETEAM.md` : bandeau en tête renvoyant à ce plan ; sections *Reset*, *Backup data*, *Restore the dump*, *Run the migration*, *Which teams get migrated*, *Members without an email*, *Verified emails and passwords*, *Running the migration from dev mode*, *Configuration* marquées une à une. Les sections de règles (*Replaying*, *Known failures*, *Ordering*, *Visibility*, *Dates*, *Team pages*, *Team logos*) **restent** : elles décrivent aussi le chemin direct | marqueurs `<!-- … -->` par section |
| 11 | ~~`README.md` : mention de la migration biketeam dans « Running the full stack locally » et de `biketeam_restore.sh`~~ (retirées avec l'import par dump, `d93fd3af`) | marqueur |
| 12 | ~~`.env.example` : commentaire de `SOCIAL_PLACEHOLDER_EMAIL_DOMAIN`~~ (variable retirée avec la connexion Strava, API 5.0.0) | marqueur sur le commentaire |
| 13 | `service/bootstrap/BootstrapService.java` (javadoc l. ~52, « the biketeam migration relies on… ») | marqueur |
| 14 | L'entrée de `docs/LEDGER_NEXT.md` ci-dessous | marquée elle aussi |
| 15 | ~~`SECURITY_AUDIT.md` : ligne L12 (`scripts/biketeam_fetch.sh`)~~ (retirée avec l'import par dump, `d93fd3af` ; l'audit est depuis dans `docs/SECURITY_AUDIT.md`) | marqueur dans la dernière cellule |
| 16 | `BiketeamMigrationService.ensureTargetTeam` (réutilisation aveugle de toute équipe au slug, legacy seul ; le direct passe par `ensureLiveTargetTeam`) | méthode dépréciée + marqueur |

**Non marqués**, et c'est voulu : `BiketeamMigrationMap`, son dépôt, `V21`/`V22` (partagés avec le
direct) ; `NotificationPublisher.silently` (utilisé par le direct) ; `SocialProvider` et
`SOCIAL_PLACEHOLDER_EMAIL_DOMAIN` (les comptes importés vivent en base — les deux ont depuis disparu
avec la connexion Strava, API 5.0.0) ; la phrase de `CLAUDE.md` et
du README sur les milliers d'adresses réelles d'une base importée (reste vraie tant que ces bases
existent).

L'entrée prévue pour [`docs/LEDGER_NEXT.md`](../LEDGER_NEXT.md) (alors au §2 « Reprises immédiates », livrée depuis sous `MIG-12`) disait quand
supprimer (la dernière équipe basculée, ou la décision de ne plus rejouer de dump) et comment
(`git grep` du marqueur, puis vérifier qu'aucune mention de `biketeam_import`, `backend-restore`,
`BiketeamReader`, `biketeam_fetch` ou `biketeam_restore` ne subsiste hors des plans datés, sans
migration Flyway : `biketeam_migration_map` sert encore au direct). C'est ce qui a été fait le 28
septembre 2026.

---

## 12. Découpage des tâches

> Historique — exécuté. Le découpage d'origine entre les trois implémenteurs.

Chaque implémenteur ne s'appuie que sur ce document. Personne ne commite.

### 12.1 tribly backend

1. `V43__biketeam_live_migration.sql` (§8.1) ; entité + dépôt `BiketeamMigrationJob` ;
   `BiketeamMigrationMap`/dépôt : colonne `biketeamTeamId`, surcharges d'`upsert` qui la renseignent,
   `deleteByTeamOrKeys(teamId, keys)`.
2. `BiketeamModel`, `BiketeamSource`, `SourceFile`, `LegacyJdbcBiketeamSource` ; refactorisation de
   `BiketeamMigrationService` (§7.2), fuseau paramétré, correction du vent (§7.4). Le legacy doit
   rester fonctionnellement identique (hors vent).
3. Config (§8.2), `BiketeamRequestTokenVerifier` (§3.2), grants et aperçu/confirmation (§4),
   `ErrorCode`, ressource publique.
4. `@BiketeamM2M` + filtre, ressource interne cachée (§5), service de job (déclenchement, statut,
   réclamation, reprise, ménage), worker (§7.1), `BiketeamExportClient`, `SnapshotBiketeamSource`,
   résolution de cible et mise au rebut (§7.3), `BiketeamMigrationUrls` et `urlMap` (§8.4).
5. `.env.example` (§10). Rien dans `docker-compose.yml` ni `frontend/server.js` (§3.4 : pas de VPN).
6. Dépréciation (§11) — marqueurs, `@Deprecated`, bandeau `MIGRATE_BIKETEAM.md`, entrée `LEDGER_NEXT.md` ;
   ajouter une ligne vers ce plan dans le tableau « Where things are written down » de `CLAUDE.md`.
7. Bump `pedalons.api.version=4.5.0`, compétence `contract-first-api` (`regenerate.sh`) ; vérifier
   que `contracts/openapi.yaml` ne contient **aucun** `/api/biketeam-migration` ni `/api/internal`,
   ni DTO `BiketeamMigration*` — seulement les codes `BIKETEAM_*` d'`ErrorCode` (écart 2026-09-24).
8. Tests (écrits, **non lancés** — consignes à l'utilisateur) : vérificateur de jeton (vecteur §3.2,
   `alg` falsifié, `exp`, `returnUrl`) ; `BiketeamMigrationResource` (aperçu public, confirmation
   401/409/403, re-confirmation) ; ressource interne (404 désactivée, 401 secret faux, 202/200/409,
   grant expiré ou champ différent) ; `SnapshotBiketeamSource` + service sur un instantané fixture
   avec un faux `BiketeamExportClient` (fichiers depuis `src/test/resources`) : équipe créée,
   confirmant ADMIN et `createdBy`, **aucun** utilisateur ni commentaire créé, `leader` null, ordre
   des groupes, étape 2 à 8:00 dans le fuseau de l'équipe, rejeu sans doublon ni téléchargement GPX,
   `reset` (tombe, slug libéré, recréée), `SLUG_CONFLICT` sur une équipe native intacte.
   `cd backend && mvn -q compile -DskipTests` doit passer ; `./format.sh backend`.

### 12.2 tribly frontend

1. `contracts/routes.yaml` : route `biketeamMigration` (§4.3) ; `pnpm generate-routes` ;
   `scripts/routes-ssr.yml` : entrée `- id: biketeamMigration` avec `skip:` (exige un jeton signé),
   `pnpm ssr-audit:verify`. (Outil retiré depuis, ledger `WEB-53` : c'est
   `frontend/e2e/routes-render.e2e.ts` qui couvre la route.)
2. `src/pages/biketeamMigration/BiketeamMigrationPage.tsx`, déclarée `auth: 'public'` dans
   `routes.config.ts` (comme `invitation`), `pageComponents.ts`. Modèle : `AcceptInvitationPage`.
   - lit `?request=`, le garde en `sessionStorage` (`pendingBiketeamMigrationRequest`) pour survivre
     au détour par la connexion ou l'inscription ; sans `?request=`, reprend celui du stockage ;
   - appelle `previewBiketeamMigration`, **rappelle** l'aperçu quand l'état d'authentification change ;
   - affiche : équipe, demandeur, mode (« Essai : l'équipe sera réellement créée sur Pédalons, mais
     biketeam ne redirigera pas » / « Définitif : biketeam redirigera toutes les adresses du groupe
     vers Pédalons »), avertissement `reset` (nomme `existingTeamName`), compteurs `summary`, ce qui
     n'est **pas** importé (membres, inscriptions, commentaires, notes et favoris), domaine cible et
     adresse de l'équipe (`targetTeamSlug`) ;
   - `blockReason = LOGIN_REQUIRED` : bouton de connexion avec `state={{ from: location }}` ; autres
     motifs : `Alert` avec `t('biketeamMigration.block.<REASON>')` ;
   - `confirmable` : bouton « Confirmer et revenir sur biketeam » → `confirmBiketeamMigration` →
     `sessionStorage.removeItem` puis `window.location.assign(redirectUrl)` ; lien « Annuler » vers
     `cancelUrl` ;
   - erreurs : `t('errors.api.<code>')`.
3. i18n fr + en (clés plates) : `biketeamMigration.*` et les dix `errors.api.BIKETEAM_*` (§4.2).
4. Appels et types écrits à la main (endpoints hors contrat, écart 2026-09-24) :
   `src/pages/biketeamMigration/biketeamMigrationApi.ts` exporte `previewBiketeamMigration`,
   `confirmBiketeamMigration` (via `axiosMutator`, donc `ApiClientError` et codes `BIKETEAM_*`
   comme un client généré) et les types `BiketeamMigrationPreviewDto`, `BiketeamMigrationConfirmDto`,
   `BiketeamMigrationTokenRequest`, `BiketeamMigrationSummaryDto`, `BiketeamMigrationTargetState`,
   `BiketeamMigrationBlockReason`, recopiés champ pour champ des DTO Java. `pnpm check`.
5. Pas de mobile : la route est `mobile: false`. Le client mobile régénéré ne gagne que les codes
   `BIKETEAM_*` d'`ErrorCode`.

### 12.3 biketeam

1. Liquibase (§9.1), entités et dépôts (§9.7).
2. `PedalonsProperties`, `PedalonsRequestTokenSigner` (+ test au vecteur §3.2).
3. Export : `TeamSnapshotBuilder` (§6.2, ordre §6.3, digests), `PedalonsExportController`
   (secret, garde de migration active, fichiers §6.4 sans chemin fourni par l'appelant).
4. `AdminTeamPedalonsController` + gabarit + entrée de menu ; `PedalonsClient` ;
   `PedalonsMigrationService` (§9.2) ; `PedalonsMigrationPoller`.
5. `PedalonsRedirectFilter` (§9.4, §9.5) et son enregistrement avant la sécurité ;
   `SecurityConfig` (§9.7) ; annulation (§9.6).
6. `.env.template` (cinq variables vides, commentées en français), `README.md`.
7. Tests (écrits, non lancés) : signature ; instantané (champs, ordre, exclusion des personnes, dates
   aux formats §6.1) ; résolution des redirections (id et permalien, sous-chemins, repli) ; gel.
   `./mvnw -q compile -DskipTests` doit passer.

---

## 13. Décisions

Les questions ouvertes de la première version, tranchées par le propriétaire le 2026-09-22. Les
sections concernées (§0, §1, §6.2, §9.2 à §9.7) sont à jour. **La décision 23 (2026-11-11) renverse
les décisions 2, 3 et 10 et amende la 4 et la 17** ; elles sont annotées sur place.

1. **Une seule cible.** Une instance biketeam ne vise **qu'un** Pédalons (`PEDALONS_URL`) ; pas de
   choix de cible dans la page d'admin. Pour un essai en staging, on pointe temporairement biketeam
   (prod, ou une copie) vers le staging Pédalons.
2. **Visibilité avant la bascule.** Une migration crée l'équipe pour de vrai et **garde** sa
   visibilité biketeam : une équipe `PUBLIC` apparaît dans la découverte Pédalons avant la bascule.
   (Formulée pour l'« essai » ; vaut pour toute migration depuis la décision 23.)
3. ~~**Essai non obligatoire** avant le définitif ; il reste seulement coché par défaut.~~
   **Renversée par la décision 23** : il n'y a plus ni essai ni définitif.
4. **Bascule manuelle.** Une migration `SUCCEEDED` ne bascule pas : l'admin clique
   « Basculer vers Pédalons » quand il le décide, après lecture du bilan (§9.2, §9.3). L'équipe
   n'est jamais gelée avant (amendée par la décision 23 : auparavant un « définitif » gelait
   l'équipe dès son lancement et la laissait gelée jusqu'à la bascule).
5. **`/api/` d'une équipe basculée** → `410` JSON `{"code": "TEAM_MIGRATED", "url": …}` ; les pages
   HTML et les téléchargements (GPX/FIT…) restent redirigés (§9.4). Les clients de l'API biketeam
   (application, Garmin) cessent de fonctionner pour l'équipe, mais sur une erreur lisible.
6. **Code de redirection configurable**, **302** par défaut ; passage à **301** une fois la migration
   stabilisée (§9.4, §9.6).
7. **Pas de slug alternatif.** Slug = identifiant biketeam **normalisé** (§13.19) ; en cas de conflit,
   la migration échoue et l'admin renomme l'équipe native sur Pédalons.
8. **Identité** (accepté) : aucun lien exigé entre le compte biketeam de l'admin et le compte
   Pédalons qui confirme ; l'admin biketeam choisit lui-même où il envoie son équipe.
9. **Une base, plusieurs domaines** (accepté) : une équipe biketeam n'est migrée que vers un domaine
   par base Pédalons (`MIGRATED_IN_OTHER_DOMAIN`).
10. ~~**Reset = corbeille**, pas purge~~ — **le reset est supprimé (décision 23).** Reste vrai :
    une équipe migrée mise de côté (elle était déjà à la corbeille) garde ses données et ses
    fichiers S3 ; la purge physique des équipes à la corbeille est un chantier séparé (ledger
    `MIG-9`).
11. **Domaines personnalisés** (`team_configuration.domain`) : la redirection est faite par
    l'application, sur les chemins `/{teamId}/…` qu'elle reçoit. Si le proxy du domaine personnalisé
    ne réécrit pas vers ce préfixe, ce sera traité au proxy, au cas par cas.
12. **Publications programmées** (accepté) : une sortie/publication/voyage `UNPUBLISHED` à
    `published_at` futur devient `DRAFT` (parité avec l'ancien import) et ne se publiera pas seule sur
    Pédalons.
13. **Notes de voyage importées.** `trip.markdown_page` (page `/trips/{id}/notes`) termine la
    description du voyage Pédalons, sous un titre `## Notes` : Pédalons n'a pas de page par voyage.
    Le texte est déjà du Markdown : seules les fins de ligne sont normalisées (CRLF → LF). La
    description est reconstruite de la source à chaque passage, donc un rejeu n'empile pas de
    seconde section. Appliqué aux deux sources de l'époque (instantané et ancien import, ce dernier supprimé le
    2026-09-28, `d93fd3af`). `/trips/{id}/notes`
    redirige déjà vers le voyage (§9.4).
14. **Tags de parcours, ville/pays de l'équipe, intégrations** (Mattermost, webhooks, réseaux) : non
    importés pour le moment (tags exportés pour plus tard).
15. **Équipes basculées dans les listes biketeam** (`/teams`, accueil) : elles restent listées et
    redirigent vers Pédalons au clic.
16. **Liens internes** dans les textes (FAQ, descriptions, notes) pointant vers biketeam : non
    réécrits, mais ils redirigeront d'eux-mêmes vers Pédalons — la bascule règle la plupart des cas
    que `MIGRATE_BIKETEAM.md` laissait « à corriger à la main ».
17. **Données legacy déjà en base** : si une équipe a été importée par l'ancien chemin dans la base
    cible (avec membres et commentaires), elle est reconnue comme issue de ce `teamId` et **mise à
    jour** sans perdre ces données (le `reset`, qui les mettait à la corbeille avec l'équipe,
    n'existe plus — décision 23).
18. **Pas de VPN** (2026-09-24, choix assumé) : les appels M2M passent par Internet, en HTTPS, via
    les entrées publiques ; sécurité = secrets partagés + grant à usage unique + export limité aux
    équipes en migration. Allowlist IP, HMAC des requêtes et mTLS sont écartés : le propriétaire juge
    la fuite de secret très improbable (§3.4).
19. **Slug normalisé** (2026-09-24). Un identifiant biketeam (`^[a-z0-9][a-z0-9_.-]{0,254}$`) n'est
    pas toujours un slug Pédalons (`^[a-z0-9]+(-[a-z0-9]+)*$`, 200 caractères au plus) : toute suite
    de `[_.-]` devient un seul `-`, les tirets de bord tombent, le tout est tronqué à 200 (puis les
    tirets de fin retirés) — `SlugService.slugifyWithinLimit`. L'identifiant brut reste la clé de
    mapping et la clé de l'`urlMap` ; seul le slug change, et l'aperçu l'affiche
    (`targetTeamSlug`). Deux identifiants qui se normalisent pareil (`club_x`, `club.x`), ou une
    équipe native au slug normalisé : `BIKETEAM_SLUG_CONFLICT`, comme avant.
20. **Rejeu = réglages Pédalons conservés** (2026-09-24). Visibilité et `joinable` biketeam ne sont
    posés qu'à la **création** de l'équipe Pédalons ; un rejeu ne les touche pas, et la visibilité des
    contenus importés suit celle de l'équipe **Pédalons** (`TEAM` si l'équipe est `TEAM`, comme
    `validateVisibility`). Le confirmant n'est rattaché ADMIN qu'à la création : sur un rejeu il a
    déjà été vérifié ADMIN ou PLATFORM_ADMIN, et un PLATFORM_ADMIN ne devient pas membre.
21. **Rejeu = biketeam fait foi pour le contenu** (2026-09-24). Un élément importé (parcours,
    publication, sortie, voyage, page FAQ) que l'admin Pédalons a mis à la corbeille est **recréé**
    par le rejeu suivant, tant qu'il existe côté biketeam : nouvelle entité, ligne de mapping
    réécrite ; l'élément à la corbeille n'est ni restauré ni modifié, et aucun groupe ou étape ne
    pointe plus vers un parcours à la corbeille. Les images suivent l'entité recréée (une image
    rattachée à une entité à la corbeille n'est pas réutilisée : elle est retéléchargée). Pour qu'un
    élément disparaisse durablement, il faut le supprimer côté biketeam. Choix assumé : pendant la
    période de migration, biketeam reste la source du contenu, et un rejeu doit converger vers lui
    plutôt qu'échouer en `NotFound` à chaque passage.
22. **Seul administrateur d'une équipe migrée = compte non supprimable** (2026-09-25). La règle
    develop « les équipes où l'on est seul partent avec le compte » mettait à la corbeille une équipe
    venue de biketeam, vers laquelle biketeam continue de rediriger ses anciennes adresses (404). La
    suppression du compte est refusée (`SOLE_MIGRATED_TEAM_ADMIN`) tant que l'utilisateur est le
    seul administrateur d'une équipe issue de biketeam (live ou ancien import), **même sans autre
    membre** ; il nomme un autre administrateur, ou un admin plateforme annule la bascule côté
    biketeam avant de supprimer l'équipe. L'écran de confirmation le dit avant (écart du même jour).
23. **Une migration est toujours incrémentale ; la bascule est une action à part** (2026-11-11,
    décision du propriétaire). Plus de distinction « essai » (`dryRun`) / « définitif » : côté
    Pédalons, `dryRun` ne changeait déjà rien au traitement, il n'était que transporté et affiché.
    Toute migration copie l'équipe ou met à jour sa copie, se relance à volonté et laisse l'équipe
    biketeam modifiable et non redirigée. La bascule (table d'URL, lecture seule, redirections) se
    décide ensuite, **côté biketeam seulement**, par **un seul bouton** de l'admin de l'équipe,
    « Basculer vers Pédalons » : biketeam enregistre la table d'URL de la dernière migration
    réussie et passe directement l'équipe à `MIGRATED` ; Pédalons n'y participe pas et renvoie
    `urlMap` dans tout job `SUCCEEDED`. Les états `MIGRATING` et `READY` disparaissent, et avec eux
    le gel en lecture seule avant bascule (`423` / `TEAM_FROZEN`) : ce qui est modifié sur biketeam
    après la dernière migration réussie n'arrive pas sur Pédalons, l'admin en relance une juste
    avant de basculer s'il le faut. L'option
    **`reset`** est supprimée des deux côtés, avec `RESET_BLOCKED` et `BIKETEAM_RESET_BLOCKED`.
    Conséquence assumée à connaître : plus rien, dans le produit, ne met à la corbeille une équipe
    Pédalons issue de biketeam (`DELETE /teams/{slug}` la refuse, ledger `MIG-5`) — ledger
    `MIG-18`. Détail dans l'écart du 2026-11-11.

---

## Écarts d'implémentation

Notes datées des implémenteurs quand le code s'écarte de ce document.

### 2026-09-22 — biketeam (aucun impact sur le contrat entre les deux applications)

1. **Page de suivi après la bascule.** `/{t}/admin/pedalons` (et ses sous-chemins) n'est redirigée
   ni pendant le gel (§9.5, conforme) ni **après** la bascule, alors que le tableau du §9.4 envoie
   tout `/{t}/admin/**` sur `TEAM` : l'administrateur doit pouvoir relire le bilan (compteurs,
   avertissements) et l'historique une fois le groupe basculé. `start` y reste refusé par le service
   (`pedalons_state = MIGRATED`).
2. **Configuration partielle côté biketeam** : échec du démarrage (`IllegalStateException` nommant
   les variables manquantes), comme côté Pédalons (§8.2) ; clé de demande non base64 ou < 32 octets :
   idem. Le §10 disait seulement « active si les cinq sont renseignées ».
3. **Cache du filtre** chargé paresseusement à la première requête (et après chaque invalidation)
   plutôt qu'au démarrage : même effet, sans course avec l'ouverture du port HTTP.
4. **Suppression physique d'un groupe** (`AsyncDeletionService`) : efface d'abord ses lignes
   `pedalons_migration`, dont la clé étrangère vers `team` n'est pas en cascade (§9.1) — sans cela la
   purge d'un groupe supprimé échouerait. `pedalons_redirect` suit par `ON DELETE CASCADE`.
5. **Annulation (§9.6) aussi pour un groupe `MIGRATING`** : le bouton de `/admin/teams` apparaît dès
   que `pedalons_state` est renseigné, pour dégeler à la main un groupe resté bloqué.
6. **Gel** : `OPTIONS` est traité comme une lecture (pré-vol CORS) ; `/{t}/maps/tags` et
   `/api/teams/{t}/maps/tags` redirigent sur `ROUTES_LIST` comme `/android`, `/garmin`,
   `/autocomplete`.
7. **Logo** : `misc/<teamId>/logo.jpeg` est aussi cherché (après `.png` et `.jpg`), comme pour les
   images de contenu (§6.2).
8. **Table d'URL reçue** : les types inconnus et les URL non `http(s)` absolues sont écartés à la
   bascule (défense contre une redirection ouverte si Pédalons renvoyait n'importe quoi).
9. **Callback lié au demandeur** : en plus de la session d'administrateur du groupe (§9.2), le
   callback exige que le compte biketeam connecté soit celui qui a fait la demande
   (`pedalons_migration.requested_by`) — le `requestId` joue le rôle de « state ».
10. **Erreur interne de l'export** (§6) : toute exception autre que les cas du tableau répond
    `500` `{"code":"INTERNAL_ERROR","message":"Export failed"}` (une exception qui porte déjà un
    statut — 405, 406… — le garde, avec `"code":"BAD_REQUEST"` pour un 4xx), jamais la redirection
    vers l'accueil du gestionnaire global de biketeam. Pédalons la traite donc en panne transitoire
    (§7.1, `EXPORT_UNAVAILABLE` après les tentatives) et non en `EXPORT_REFUSED`.
11. **Fichier illisible à l'instantané** (taille ou empreinte impossibles à lire) : sa `FileRef`
    vaut `null` et un avertissement est tracé côté biketeam — l'élément part sans fichier
    (`GPX_MISSING` pour un parcours) au lieu de faire échouer tout l'instantané.
12. **Filtre de redirection et de gel** (§9.4, §9.5) : il résout le chemin **décodé** comme Spring
    MVC (`UrlPathHelper` : décodage UTF-8, contenu après `;` retiré, `//` fusionnés). Un segment
    encodé (`/%6E-peloton/join`) ne contourne donc plus le gel ni la bascule, et un permalien non
    ASCII (`Boucle_de_l’Erdre`, servi en `%E2%80%99`) retrouve son entrée de la table d'URL.

13. **Bascule manuelle (§9.2, §13.4 tranchée).** Un définitif réussi ne bascule plus : le poller enregistre la table d'URL et passe le groupe à `pedalons_state = READY` (nouvelle valeur, sans changeset : colonne `VARCHAR(20)`), avec `pedalons_url`, mais sans `switched_at` ni `pedalons_migrated_at`. Le gel est levé si le job échoue (`null`) ; s'il réussit, le groupe `READY` reste **gelé** mais n'est pas redirigé (décision du 2026-09-24 : rien ne doit se perdre entre le succès et le clic). La page d'admin affiche le bilan et un bouton « Basculer vers Pédalons » (`POST /{t}/admin/pedalons/switch`, CSRF, confirmation JS), qui passe le groupe à `MIGRATED`, renseigne `pedalons_migrated_at` et le `switched_at` du dernier définitif réussi, et annule les demandes `REQUESTED` restantes. Avant la bascule, une nouvelle migration reste possible. Au callback, un définitif regèle le groupe et efface la table en attente ; un essai l'efface aussi et remet le groupe à `null`, car il modifie, voire réinitialise, le groupe Pédalons : seul un définitif réussi permet de basculer. Les transitions gel, bascule et abandon sont des `UPDATE` conditionnels sur l'état, donc sans course entre une bascule et un nouveau lancement. Un callback sur un groupe `MIGRATED` est refusé. L'annulation plateforme (§9.6) s'applique aussi à un groupe `READY`.
14. **API d'un groupe basculé (§9.4, §13.5 tranchée).** `/api/teams/{t}/**`, lectures comprises, répond `410` `{"code":"TEAM_MIGRATED","message":"Ce groupe a déménagé sur Pédalons.","url":"<page Pédalons du groupe>"}`, avec l'URL `TEAM` de la table ou, à défaut, `pedalons_url`. Les pages et téléchargements hors `/api/` restent redirigés.
15. **Code de redirection configurable (§9.4, §13.6 tranchée).** `PEDALONS_REDIRECT_STATUS` (`pedalons.redirect-status`) vaut `301` ou `302`, `302` par défaut. Toute autre valeur fait échouer le démarrage, même fonction éteinte. On passe à `301` une fois les bascules stabilisées (`.env.template`, README).
16. **Listes (§13.15).** Les groupes basculés restent listés sur `/teams` et l'accueil ; un clic redirige. Leur logo `/{t}/image`, affiché en `<img>` par ces listes, n'est **pas** redirigé et reste servi par biketeam.

### 2026-09-22 — tribly backend

Rien ne change sur le fil (en-têtes, chemins, JSON, codes) ; ce qui suit précise des points que le
document laissait ouverts, deux d'entre eux étant visibles de biketeam (4, 5).

1. **`MIGRATED_IN_OTHER_DOMAIN`** ne retient qu'une équipe **active** d'un autre domaine : si
   l'équipe pointée par `biketeam_migration_map[TEAM, teamId]` a été mise à la corbeille dans son
   domaine, le `teamId` est de nouveau migrable ailleurs (la ligne de mapping est alors réécrite).
2. **Garde-fou `findByIdAndTeam` (§7.4)** appliqué aux deux chemins, direct **et** legacy : un id
   trouvé dans le mapping n'est cru que si l'entité appartient à l'équipe cible. Pour le legacy, cela
   ne change rien tant que le mapping est sain (il visait déjà la même équipe).
3. **Signature** : `migrateTeamLive(Domain, User, BiketeamSource, expectedTeamId, onTarget,
   BiketeamMigrationProgress)` plutôt que `migrateTeamLive(LiveJobContext, …)` (§7.2, indicatif) —
   le worker charge le domaine et l'utilisateur, résout la cible (§7.3) puis appelle le service avec
   l'équipe résolue (`null` si le slug est libre) et un rappel qui enregistre `target_team_id` dès
   que l'équipe existe (voir 12).
4. **`urlMap`** : les neuf clés sont **toujours** présentes ; une clé sans entrée vaut `{}` (p. ex.
   `TEAM_FAQ` d'une équipe sans FAQ, `RIDE` d'une équipe sans sortie).
5. **Rejeu du déclenchement (§5.1, `200`)** : le corps porte le **statut courant** du job
   (`QUEUED`, `RUNNING`, `SUCCEEDED` ou `FAILED`), pas forcément `QUEUED`. `jobId` est inchangé.
6. **Intégrité des fichiers** : un fichier téléchargé dont la taille ou le MD5 diffère du `FileRef`
   est refusé (avertissement `FILE_DOWNLOAD_FAILED`), sans quoi l'empreinte enregistrée mentirait.
   Un seul fichier téléchargé est gardé à la fois dans le répertoire temporaire du job.
7. **Compteurs** : `teamPages` ne compte que les pages présentes dans l'instantané (à-propos si
   `description` rend un texte, FAQ si `markdownPage` n'est pas vide) ; `images` compte le logo
   (le logo factice en `skipped`) et les images de contenu ; un élément déjà téléversé lors d'un
   passage précédent compte `migrated`. `tripStages` : `failed` pour les étapes d'un voyage en échec.
8. **Compte confirmant supprimé** entre la confirmation et le job : `FAILED` avec `INTERNAL_ERROR`
   (message explicite), sans nouvelle tentative.
9. **Re-confirmation** : seule une ligne encore `GRANTED` (même utilisateur, même domaine) peut être
   re-confirmée ; une ligne `EXPIRED` répond `409 BIKETEAM_REQUEST_ALREADY_USED` (repartir de
   biketeam). *Remplacé par la 3e revue (2026-09-24, point 4) : une ligne `EXPIRED` se re-confirme.*
10. **Tests** : la fonction est activée pour tout le contexte de test par des valeurs
    `%test.pedalons.biketeam.*` dans application.properties (clé du vecteur §3.2) — pas de
    `@TestProfile`, donc pas de redémarrage de Quarkus. Le cas « désactivée » est couvert sans
    Quarkus : `BiketeamMigrationDisabledTest` (config et endpoints publics) et
    `BiketeamM2MFilterTest` (404 nu du M2M). Le worker planifié ne tourne pas en test
    (`%test.quarkus.scheduler.enabled=false`) ; les tests l'appellent directement.

### 2026-09-22 — tribly, après revue

11. **Cible vérifiée et écrite dans la même transaction** (§7.3). `prepareTarget` décide dans sa
    propre transaction ; `ensureLiveTargetTeam` refait le contrôle dans celle qui écrit, **avant**
    toute ligne de mapping, visibilité ou adhésion : slug libre attendu → création seule (une équipe
    trouvée au slug, ou créée entre-temps et rattrapée par `uk_teams_domain_slug`, fait échouer le
    job en `BIKETEAM_SLUG_CONFLICT`) ; équipe migrée attendue → réutilisée seulement si c'est encore
    elle au slug **et** si `biketeam_migration_map[TEAM, teamId]` pointe toujours sur elle. Une
    équipe native créée entre les deux transactions n'est donc jamais reprise.
12. **Remise à zéro appliquée une fois par job.** `target_team_id` est écrit dès que l'équipe cible
    existe (plus seulement en fin de mapping) et rechargé dans `LiveJobContext` ; une tentative
    suivante du même job ne remet pas à zéro l'équipe que ce job a lui-même créée — elle reprend le
    mapping, avec les empreintes GPX. Le statut porte aussi `targetTeam` pendant le job.
13. **Aucun téléchargement dans une transaction.** GPX, images et logo sont téléchargés entre deux
    transactions courtes (lecture du mapping, puis écriture) ; rien n'est téléchargé quand le
    mapping sera réutilisé (empreinte GPX identique, asset déjà rattaché). L'échec d'un
    téléchargement est signalé comme avant (`FILE_DOWNLOAD_FAILED` sur l'élément ou l'image).
14. **Assets mappés : garde d'appartenance.** Une ligne `ASSET` (image, logo) n'est crue que si
    l'asset appartient à l'équipe cible **et** à l'entité (sortie, voyage, publication, page
    à-propos) qui le porte ; sinon l'image est téléversée de nouveau et la ligne réécrite. La branche
    « parcours supprimé » ne met à la corbeille qu'un parcours de l'équipe cible. Cas visé : la
    re-migration vers un autre domaine permise par l'écart 1, où les lignes de l'ancienne équipe
    restent en place.
15. **`teamId` migrables** — **fait côté biketeam** (`ea72260`, 2026-09-25 :
    `PedalonsMigrationService.isMigratable`, refus dans `start()`, bouton masqué par
    `pedalonsMigratable`). Pédalons n'accepte que
    `^[a-z0-9][a-z0-9_.-]{0,254}$` : le `teamId` devient le slug de l'équipe et un segment de chaque
    URL construite (les slugs Pédalons natifs sont même plus stricts, `^[a-z0-9]+(-[a-z0-9]+)*$`).
    Élargir ce motif créerait des slugs non ASCII que le reste de Pédalons ne sait pas servir ; il
    est donc **conservé**, et un refus pour ce motif est désormais journalisé côté Pédalons (le
    visiteur voit toujours `BIKETEAM_REQUEST_INVALID`). Or `Strings.normalizePermalink` de biketeam
    garde `’`, `œ`, `æ`, `ß`, `°`… et peut commencer par `_`, `-` ou `.`. **Règle reportée au §3.2** :
    « `teamId` vérifie `^[a-z0-9][a-z0-9_.-]{0,254}$` ; biketeam fait ce contrôle
    avant de signer (`PedalonsMigrationService.start()`, message « identifiant de groupe non
    migrable ») et masque le bouton de `/{teamId}/admin/pedalons` pour un tel groupe. »
    *Précisé par la décision 19 (2026-09-24) : le slug est le `teamId` normalisé
    (`SlugService.slugifyWithinLimit`), l'identifiant brut reste la clé de mapping.*

### 2026-09-22 — exploitation (§3.4)

16. ~~**Double barrière sur `/api/internal`**~~ — **retirée le 2026-09-24.** Le constat de revue
    « endpoints M2M joignables depuis l'entrée publique » est désormais **voulu** : sans VPN,
    `/api/internal/` et `/internal/pedalons/` sont servis par les entrées publiques, en HTTPS, et
    protégés par les secrets, le grant à usage unique et la garde « équipe en migration » (§3.4,
    §13 décision 18). Le routeur Traefik `quarkus-internal-block`, l'entrypoint `internal` et le
    refus dans `frontend/server.js` ont été supprimés ; `docker-compose.yml` et `server.js` sont
    revenus à leur état de `develop` pour ces points. Ajout : refus au démarrage d'une URL M2M en
    `http://` hors `localhost` (les deux côtés).

### 2026-09-22 — tribly frontend

Rien ne change sur le fil ; précisions sur la page `biketeamMigration` (§12.2).

1. **Attente de la session** : l'aperçu n'est demandé qu'une fois l'état d'authentification
   initialisé (`authStore.isInitialized`), puis redemandé à chaque changement de session — sans
   quoi un visiteur connecté verrait d'abord `LOGIN_REQUIRED`.
2. **Compte qui confirme** : connecté, la page affiche le compte (« Connecté en tant que… ») et
   propose « Utiliser un autre compte » (déconnexion puis retour sur la même URL), puisque c'est ce
   compte qui devient ADMIN de l'équipe.
3. **Échec de la confirmation** : `BIKETEAM_REQUEST_INVALID`/`EXPIRED` → page d'erreur et
   `sessionStorage` vidé ; tout autre code (conflit 409, 403, session perdue) → message
   `errors.api.<code>` au-dessus des boutons **et** aperçu redemandé, qui affiche alors le motif de
   blocage. Le jeton est aussi retiré du stockage sur « Annuler ».
4. **`reset` sans équipe existante** (`targetState = NEW`) : la page dit que la remise à zéro sera
   sans effet plutôt que de ne rien dire.
5. **Audit SSR** : `scripts/routes-ssr.yml` gagne `biketeamMigration` avec `skip:`.
   `pnpm ssr-audit:verify` échoue néanmoins sur `notifications`, absente du fichier **avant** cette
   branche (écart préexistant, non traité ici).

### 2026-09-24 — tribly, endpoints publics retirés du contrat OpenAPI

Rien ne change sur le fil (chemins, JSON, codes). À la demande du propriétaire, `POST
/api/biketeam-migration/preview` et `/confirm` sortent du contrat, comme les endpoints internes (§5) :
fonction ponctuelle qu'aucun client autre que la page web n'appelle.

1. `BiketeamMigrationResource` : `@Operation(hidden = true)` sur les deux méthodes, `@Tag` retiré
   (la documentation des réponses passe en Javadoc).
2. Les quatre DTO de `dto/migration/` perdent leur `@Schema` **de classe** : SmallRye ajoute aux
   `components` tout type ainsi annoté, même sans opération qui le référence — c'est ce qui les
   gardait dans le contrat après le masquage des opérations. Les `@Schema(required = true)` des
   champs restent pour `@ValidateSchema` ; les deux enums disparaissent avec eux.
3. Contrat : par rapport à `develop`, seul `ErrorCode` gagne les dix `BIKETEAM_*` ; la version reste
   **4.5.0** (ajout rétrocompatible, jamais publiée sous une autre forme).
4. Frontend : `pages/biketeamMigration/biketeamMigrationApi.ts` (écrit à la main) remplace le
   client Orval ; `api/endpoints/biketeam-migration/`, `api/zod/biketeam-migration/` et les DTO
   `biketeamMigration*` ne sont plus générés. Mobile : plus de `biketeam_migration_client` ni de
   modèles `biketeam_migration_*`.

### 2026-09-24 — biketeam, après revue

- **Suivi du job** : seul un `404` dont le corps JSON porte `code = BIKETEAM_JOB_NOT_FOUND` conclut
  `JOB_LOST` (corps conservé). Tout autre 404 (sans corps, HTML de proxy, autre code) est transitoire
  et réessayé au tick suivant, jusqu'au `TIMEOUT` de 6 h.
- **Gel** : une écriture sur `/api/teams/{t}/**` d'une équipe gelée (`MIGRATING` ou `READY`) reçoit
  un `423` `application/json` `{"code":"TEAM_FROZEN","message":…,"url":<page Pédalons ou null>}` ;
  les pages HTML gardent leur 423 HTML.
- **Voyages du catalogue** : `/catalog/trips/{x}` est résolu sans SQL par requête — rien n'est
  cherché tant qu'aucune équipe n'est `MIGRATED`, sinon un index en mémoire (id et permalien des
  voyages non supprimés → équipe, voyage) construit au chargement du cache, en un nombre fixe de
  requêtes.
- **Instantané** : lectures par graphes JPA (`FETCH`), 6 requêtes quel que soit le volume, sans
  charger participants ni inscriptions (test Hibernate Statistics) ; chaque répertoire de fichiers
  listé une fois, un seul accès disque par fichier exporté.

### 2026-09-24 — tribly, après revue (cible, 404, slug)

1. **Cible résolue par le mapping d'abord** (§7.3). `BiketeamTargetResolver` lisait l'équipe au slug
   `teamId` : une équipe migrée puis renommée sur Pédalons était vue `NEW`, ce qui sautait les
   contrôles `NOT_TEAM_ADMIN` / `RESET_BLOCKED`, créait une seconde équipe et déplaçait le mapping. Le
   `TEAM` du mapping (équipe active du domaine) donne maintenant `EXISTING_MIGRATED` quel que soit
   son slug ; aperçu, confirmation, `prepareTarget` et `ensureLiveTargetTeam` suivent la même
   logique (ce dernier vérifie l'équipe attendue par id, domaine et mapping, plus par slug).
2. **`404 BIKETEAM_JOB_NOT_FOUND`** (§5.2) : nouvelle valeur d'`ErrorCode`, contrat et clients
   régénérés, version **4.5.0** conservée (jamais publiée).
3. **Export : 4xx sans code = transitoire** (§7.1). Seul un 4xx portant le `code` JSON de biketeam est
   `EXPORT_REFUSED`. Côté fichiers, seul `404 FILE_NOT_FOUND` reste un avertissement par élément ;
   réseau, 3xx, 5xx, 4xx sans corps lèvent `BiketeamExportException` (non vérifiée), qui traverse
   les frontières par élément (`itemFailed` la relance) et fait réessayer la tentative
   (`retryOrFail`). `SourceFileUnavailableException` ne désigne plus que le fichier manquant (ou
   des octets non conformes à l'instantané).
4. **Slug normalisé** (§13.19) ; la mise au rebut produit un slug valide de 200 caractères au plus.
5. **Rejeu** (§13.20) : plus de réécriture de la visibilité / `joinable`, plus d'adhésion ADMIN hors
   création. L'ancien import garde son comportement (il réaligne la visibilité à chaque passage).
6. **Duplication** : les clés de mapping (`faqPageKey`, `logoKey`, `imageKey`, `mappingKeys`) sont
   construites par `BiketeamMigrationService` seul, que la mise au rebut et la table d'URL
   appellent ; `common/PersistenceErrors.isUniqueViolation` (SQLState `23505` à travers tout
   enveloppement, `getNextException` compris — une violation de clé étrangère n'en est plus une),
   `TokenUtils.constantTimeEquals` et `common/UrlUtils` (`stripTrailingSlash`, `requireHttps`)
   remplacent les copies.

### 2026-09-24 — biketeam, 2e revue

- **(5)** Décision du propriétaire : un groupe `READY` reste **gelé** en lecture seule jusqu'au clic
  « Basculer » (le code l'était déjà) ; commentaires, README, encart d'administration et messages
  423 qui parlaient de « dégel » à la réussite corrigés.
- **(6)** `TRIGGERING_STUCK_AFTER` passe de 10 à **3 min** : au-delà d'un déclenchement complet
  (≈ 2 min 07 au pire : 3 essais × 40 s de délais réseau + 7 s d'attente) et en deçà de
  `pedalons.biketeam.grant-ttl` (10 min) moins le pas du poller (15 s) — le rejeu tombe dans la
  fenêtre du grant. Un échec de déclenchement ne termine la ligne que si elle est encore
  `TRIGGERING`, pour qu'un essai perdant ne dégèle pas une migration lancée par un rejeu concurrent.
- **(8)** Une demande `REQUESTED` accepte son callback, et n'est expirée par le poller, que jusqu'à
  **exp du jeton + 15 min** (75 min après sa création) : Pédalons accepte une confirmation jusqu'à
  exp + 60 s et le grant émis vit encore 10 min. Le grant fait foi.
- **(10)** Cache MD5 de l'export : une entrée par chemin (taille, mtime, md5), remplacée si le
  fichier change, LRU borné à 20 000 entrées ; MD5 calculé hors verrou.

### 2026-09-24 — tribly, 2e revue

1. **`reset` d'une équipe migrée renommée, slug normalisé pris** (§7.3). La mise au rebut était
   validée avant de vérifier le slug cible : une équipe native à `club-x` faisait échouer la création
   en `BIKETEAM_SLUG_CONFLICT` en laissant l'unique copie (`club-x-lyon`) à la corbeille, mapping
   supprimé. `BiketeamTargetResolver.evaluate(…, reset)` renvoie désormais `SLUG_CONFLICT` pour un
   `reset` d'une équipe `EXISTING_MIGRATED` dont le slug normalisé est tenu par une autre équipe
   (aperçu, confirmation), le job le revérifie (`prepareTarget`, sans rien écrire), et la mise au
   rebut elle-même se fait dans la transaction de `ensureLiveTargetTeam`, avant sa vérification du
   slug : tout conflit l'annule.
2. **Lecture du corps de l'export bornée** (§7.1). Le délai de 120 s ne couvrait que les en-têtes ;
   un corps qui cale bloquait le thread du worker (et, par `SKIP`, toute la file). `TimedBodySubscriber`
   remplace `BodyHandlers.ofInputStream()` : chaque lecture attend au plus
   `pedalons.biketeam.export-idle-timeout` (PT60S), le corps entier au plus
   `pedalons.biketeam.export-transfer-timeout` (PT10M, sous `stuck-after`) ; au-delà l'échange est
   annulé et c'est `EXPORT_UNAVAILABLE`, réessayé — y compris pour un instantané coupé en plein JSON
   (auparavant `EXPORT_INVALID`, définitif).
3. **Entités mises à la corbeille sur Pédalons** (§13.21). `owned()` ignorait `isDeleted()` : un
   parcours à la corbeille était réutilisé (`updateRoute` → `NotFound` à chaque rejeu) et son slug
   donné aux groupes et étapes. Une entité à la corbeille n'est plus réutilisable : elle est
   recréée, mapping réécrit ; `reusableImage` / `reusableLogo` écartent aussi un asset rattaché à une
   entité à la corbeille (sinon l'image n'était ni préchargée ni rattachée à l'entité recréée).
4. **`RESET_BLOCKED` à l'aperçu** (§4.1). Nouvelle valeur de `BiketeamMigrationBlockReason`,
   calculée comme la confirmation : l'aperçu ne se dit plus « confirmable » avant un `409` en boucle.
   Type TS et page (message dédié, fr/en) à jour.
5. **`targetTeamSlug` du déclenchement** (§5.1) : le vrai slug (équipe écrite, équipe migrée
   réutilisée, sinon slug normalisé), plus l'identifiant biketeam brut. Le statut (`targetTeam`) lisait
   déjà l'équipe écrite par le job.
6. **Empreinte GPX calculée une fois** (source legacy). Elle était lue et hachée deux fois par
   parcours (`prefetchGpx` puis `migrateOneMap`, chacun relisant tout le fichier par
   `readAllBytes`) : `migrateMaps` la calcule une fois et la passe aux deux, et `DiskFile` hache en
   flux (`DigestInputStream`), taille et MD5 d'une seule lecture, mémoïsés.

### 2026-09-24 — biketeam, 3e revue

- **Colonnes `pedalons_*` de `team` en lecture seule pour Hibernate** (`insertable = false,
  updatable = false`) : écrites uniquement par les UPDATE ciblés et conditionnels de
  `TeamRepository` (gel, `readyPedalons` MIGRATING → READY, `unfreezePedalons` MIGRATING → null,
  bascule, abandon, unswitch). Un `save()` d'un Team chargé avant un gel ou une bascule n'annule
  plus rien.
- **Transitions de `pedalons_migration` en UPDATE conditionnels**, depuis l'état attendu
  seulement, jamais par `save()` d'une copie lue plus tôt.
- **L'annulation plateforme (§9.6) annule aussi la migration active** (TRIGGERING/RUNNING →
  `CANCELLED`, `error_code = CANCELLED_BY_ADMIN`) dans la transaction du dégel : l'export n'est
  plus servi et le job Pédalons échoue sur l'export ; un succès ou un échec rapporté ensuite est
  ignoré et tracé. Un succès définitif exige que l'équipe soit encore `MIGRATING`, sinon `FAILED
  TEAM_NOT_FROZEN`.
- **§9.2 : le délai de 6 h ne court qu'à partir du premier `RUNNING` rapporté par Pédalons**
  (colonne `running_since`, changeset `pedalons-migration-running-since`). En `QUEUED`, ou tant
  qu'aucun `RUNNING` n'a été vu, le délai est de 48 h (depuis le déclenchement, ou depuis le
  premier `RUNNING` si le job est revenu en file). Tant qu'un délai court, l'équipe reste gelée et
  l'export servi.
- **Instantané en deux temps** : entités converties en valeurs simples dans une transaction courte
  en lecture seule, puis taille et MD5 des fichiers calculés hors transaction, avant le premier
  en-tête.

### 2026-09-24 — tribly, 3e revue

1. **Battement pendant les téléchargements** (§7.1). Le battement n'était écrit qu'avant chaque
   élément ; un seul parcours pouvait rester muet 120 s (en-têtes) + 10 min (transfert) + 600 s
   (transaction) > `stuck-after` : un job vivant était remis en file, puis `WORKER_LOST`. La lecture
   du corps (`TimedBodySubscriber`, sur le thread du worker) appelle `JobProgressTracker.heartbeat()`,
   qui écrit au plus une fois par minute, dans sa propre transaction ; un job perdu arrête le
   téléchargement (`BiketeamJobLostException`, relancée par `rethrowIfExportFailure` au lieu de
   compter comme échec de l'élément), une autre erreur d'écriture est seulement journalisée.
   `BiketeamLiveMigrationConfig` refuse de démarrer si `stuck-after` n'excède pas le plus long
   silence possible + 2 min (§7.1) ; `export-transfer-timeout` n'est plus borné par `stuck-after`.
2. **Grant échu non consommé** (§3.3, §4). Une ligne `EXPIRED` répondait `REQUEST_ALREADY_USED` alors
   qu'une ligne `GRANTED` au grant échu se re-confirmait : la réponse dépendait du passage du
   balayage horaire. Seule une ligne consommée (job créé, `status.isJob()`) est « utilisée » ; une
   ligne `GRANTED` ou `EXPIRED` se re-confirme par le même utilisateur sur le même domaine tant que le
   jeton de demande est valide, et redevient `GRANTED` avec un nouveau grant. Remplace le point 9 de
   « 2026-09-22 — tribly backend ».
3. **Table d'URL en requêtes par lots** (§8.4). Deux requêtes par entité (`findTriblyId` +
   `em.find`) : désormais, par type, une requête sur le mapping (`entityType = ? and biketeamId in
   (…)`) et une projection `(id, slug)` sur les entités (étapes : jointure sur le voyage), par
   paquets de 1 000, dans une seule transaction de lecture ouverte après la préparation des listes.
   Aucune entité chargée. `BiketeamMigrationUrlsQueryCountTest` vérifie qu'on paie le même nombre de
   requêtes pour 3 et pour 30 éléments de chaque type (≤ 12).
4. **Reprise des jobs bloqués en masse** (§7.1). `recoverStuck()` modifiait des entités `@Version`
   dans une seule transaction : un conflit optimiste avec un worker annulait toute la reprise. Deux
   `UPDATE` conditionnels (`status = RUNNING`, battement périmé, `attempts <` ou `>= max-attempts`)
   passent le job en `QUEUED` ou en `FAILED WORKER_LOST` ; ils incrémentent `version`, pour qu'une
   copie périmée de la ligne ne puisse pas être réécrite par-dessus. Côté worker, `owned()` verrouille
   la ligne (`PESSIMISTIC_WRITE`) le temps de sa courte transaction : un battement concurrent est soit
   vu par la reprise (qui ne touche alors plus le job, la condition étant réévaluée sur la ligne
   verrouillée), soit refusé parce que la ligne est déjà `QUEUED`.
5. **Délai des en-têtes de l'instantané** (§7.1, §8.2). Nouveau
   `pedalons.biketeam.export-snapshot-timeout` (défaut PT5M) : après un redémarrage, biketeam peut
   hacher ~1 Go de fichiers d'une grosse équipe avant de répondre. Celui des fichiers reste 120 s
   (`BiketeamExportClient.FILE_REQUEST_TIMEOUT`). Compté dans la contrainte du point 1.

### 2026-09-25 — tribly, après e2e

1. **Erreur de la dernière tentative** (§5.2). Entre deux tentatives, le statut M2M répondait
   `error: null` : l'erreur n'était exposée qu'en `FAILED`. Nouveau champ `lastAttemptError` (même
   forme `{code, message}`), non nul quand le job est `QUEUED`/`RUNNING` après une tentative ratée ;
   `error` reste réservé à l'échec définitif. `retryOrFail` écrit désormais aussi `error_code` (le
   code qui serait final) en remettant en file, et la reprise des jobs bloqués (`requeueStuck`)
   écrit `WORKER_LOST` et un message ; un succès les efface. biketeam affiche `lastAttemptError`.
2. **Code de redirection** (§9.4). `MIGRATE_BIKETEAM.md` annonçait des redirections « with a 301 » :
   302 par défaut, 301 via `PEDALONS_REDIRECT_STATUS` côté biketeam, et seulement après le clic
   « Basculer vers Pédalons ». Aucune autre mention incohérente (README, `docs/LEDGER_NEXT.md`, ce plan).
3. **Équipe à la corbeille mise de côté** (§4.1). L'aperçu affichait `targetState = NEW` sans dire
   qu'une équipe migrée à la corbeille occupait le slug et serait mise de côté. Nouveau champ
   `trashedTeamSetAside` (nom de cette équipe, ou `null`), tiré de la même évaluation
   `BiketeamTargetResolver` que le worker ; la page l'annonce (`biketeamMigration.trashed.setAside`),
   y compris à la place de « la remise à zéro sera sans effet » quand `reset` est demandé.

### 2026-09-25 — biketeam, après e2e

- **Raison d'une tentative ratée** : la page de suivi lit `lastAttemptError` (`{code, message}` ou
  null) dans le statut Pédalons déjà conservé tel quel (`result_json`), sans nouvelle colonne.
  Affiché seulement pour une demande active et un job `QUEUED`/`RUNNING`, échappé : « Tentative n
  échouée : <message> — nouvel essai automatique », n = `attempt` en `QUEUED`, `attempt - 1` en
  `RUNNING` (Pédalons incrémente `attempts` au démarrage d'une tentative). Un Pédalons sans ce champ
  n'affiche rien ; l'échec final reste porté par `error`.
- **Page 423 HTML** : porte l'URL Pédalons quand elle est connue (même repli que le JSON
  `TEAM_FROZEN`) avec un lien « Voir le groupe sur Pédalons » ; texte selon l'état — `MIGRATING`
  « migration en cours », `READY` « migration terminée, en attente de bascule par l'administrateur
  du groupe ». Le JSON 423 de l'API est inchangé.

### 2026-09-25 — tribly, suppression de compte

Un e2e a montré que le seul admin d'une équipe migrée (et basculée) qui supprime son compte Pédalons
emporte l'équipe à la corbeille, sans que l'écran d'impact le dise, et biketeam redirige alors vers
des 404. Décision 22.

1. **Blocage** (`UserService.deleteUser`). Nouveau code `SOLE_MIGRATED_TEAM_ADMIN` (400), vérifié
   **avant** `SOLE_TEAM_ADMIN` : l'utilisateur est le seul admin vivant d'une équipe non supprimée
   vers laquelle pointe une ligne `TEAM` de `biketeam_migration_map` — autres membres ou non. Une
   seule requête pour toutes ses équipes (`UserTeamRepository.findMigratedTeamsAdministeredAlone`,
   `EXISTS` sur le mapping, index `(entity_type, tribly_id)`). Une équipe migrée à la corbeille, ou
   ayant un autre admin, ne bloque pas. Rien n'empêche, en revanche, de supprimer l'équipe elle-même
   (`DELETE /teams/{slug}`) : hors périmètre.
2. **Impact** (`GET /users/me/deletion-impact`). Nouveau champ `migratedTeams` (`TeamPublicationDto`
   : nom, slug) ; `blocked` le compte ; une équipe migrée n'apparaît que là (retirée de
   `blockingTeams` et `deletedTeams`). Trois requêtes quel que soit le nombre d'équipes (test
   `getMyDeletionImpact_costsTheSameForOneMigratedTeamAsForThree`). Contrat régénéré, API toujours
   4.5.0 (non publiée).
3. **Écrans.** Web (`AccountDeletionImpact`) : l'alerte porte désormais le titre « Vous ne pouvez
   pas encore supprimer votre compte », puis les équipes venues de biketeam (nom, slug, « ses
   anciennes adresses biketeam redirigent vers elle », lien vers ses membres, marche à suivre), puis
   les autres équipes bloquantes. Mobile (`AccountSection`) : bandeau `profile.account.blockedMigrated`
   avant celui des équipes bloquantes. Traductions fr/en, dont `errors.api.SOLE_MIGRATED_TEAM_ADMIN`.
4. **Avertissement `TRIP_STAGES_OUTSIDE_DATES`** (§5.2). Un voyage biketeam dont des étapes tombent
   hors de `[start_date, end_date]` (une date absente ne borne pas) est migré tel quel, avec un
   avertissement `TRIP` par voyage qui nomme les dates du voyage et chaque étape hors bornes :
   Pédalons fait finir un voyage à sa dernière étape, la `end_date` biketeam est perdue et le voyage
   peut « finir avant de commencer ». Aucune correction des données. Émis par les deux sources
   (instantané et ancien import) ; `MIGRATE_BIKETEAM.md` le mentionne.

### 2026-11-11 — les deux côtés, plus d'essai ni de `reset` (décision 23)

Décision du propriétaire : **chaque migration est incrémentale**, exactement comme un essai
jusque-là, et la bascule devient une action séparée, faite côté biketeam seulement. Les sections
qui font foi (§0, §1, §2, §3.2, §3.3, §4, §5, §9, §10, §13) sont à jour ; les écarts antérieurs
parlent encore d'« essai », de « définitif », de `reset` et de `MIGRATING` : c'est l'historique.

**Contrat entre les deux applications**

1. **Jeton de demande (§3.2).** Les claims `dryRun` et `reset` ne sont plus envoyés ; `ver` reste
   `1`. Pédalons ne les lit ni ne les exige : présents, ils sont ignorés quel que soit leur type.
   Nouveau vecteur de test (même clé) ; l'ancien reste dans `BiketeamRequestTokenVerifierTest` comme
   preuve de compatibilité.
2. **Aperçu et confirmation (§4).** `BiketeamMigrationPreviewDto` perd `dryRun` et `reset` ;
   `blockReason` perd `RESET_BLOCKED` ; la confirmation ne répond plus `409
   BIKETEAM_RESET_BLOCKED`. Le code est retiré de l'enum `ErrorCode` du contrat OpenAPI :
   `pedalons.api.version` **13.8.0 → 14.0.0** (valeur d'enum retirée).
3. **Déclenchement (§5.1).** Corps `{requestId, grant, teamId}` ; l'égalité avec la ligne ne porte
   plus que sur `requestId` et `teamId`. `dryRun` et `reset` reçus sont ignorés
   (`@JsonIgnoreProperties(ignoreUnknown = true)` sur `BiketeamJobTriggerRequest`, en plus du
   réglage par défaut de Quarkus).
4. **Statut (§5.2).** La réponse ne porte plus `dryRun` ni `reset` ; `error.code` ne vaut plus
   jamais `BIKETEAM_RESET_BLOCKED`. `urlMap` accompagne tout job `SUCCEEDED`, comme avant.
5. **Ordre de déploiement : Pédalons d'abord, biketeam ensuite** (§10, point 5).

**Pédalons**

6. **Résolution de la cible (§7.3).** `BiketeamTargetResolver.evaluate(domainId, teamId)` n'a plus
   de paramètre `reset` ; `isResetBlocked`, `slugHeldByAnotherTeam`,
   `DomainAliasRepository.existsByPinnedTeam` et `TeamRepository.existsTrashedBySlugSuffixAndDomain`
   sont supprimés. Une équipe `EXISTING_MIGRATED` est toujours mise à jour sur place : un
   `DomainAlias` épinglé sur elle ne bloque plus rien, et une équipe native au slug normalisé d'une
   équipe migrée renommée n'est plus un conflit.
7. **Mise de côté conservée pour la seule équipe déjà à la corbeille** (`Target.trashed` →
   `Prepared.create(teamId)` → `setAside`, `trashedTeamSetAside` de l'aperçu). Le suffixe
   `-reset-<jobTsid>` garde son nom : des lignes le portent en base. La garde `setAsideByThisJob`
   (ledger `MIG-15`) disparaît avec le reset qu'elle protégeait : une nouvelle tentative après un
   arrêt entre la création de l'équipe et l'écriture de `target_team_id` retrouve l'équipe par sa
   ligne `TEAM`, validée dans la transaction qui l'a créée avec l'adhésion ADMIN du confirmant —
   `EXISTING_MIGRATED`, donc reprise (`BiketeamSetAsideRetryAfterLostTargetRaceTest`).
   `LiveJobContext` perd `dryRun`, `reset` et `targetTeamId`, que plus rien ne lisait.
8. **Schéma.** L'entité `BiketeamMigrationJob` ne porte plus `dry_run` ni `reset` ;
   `V88__biketeam_migration_options_default.sql` leur donne un défaut (`true`, `false`) sans les
   supprimer, pour la version précédente qui les écrit encore pendant un déploiement *rolling* ou
   après un retour arrière. Suppression : ledger `MIG-17`. Une ligne `reset = true` créée par
   l'ancienne version et exécutée par la nouvelle est une migration incrémentale.
9. **Page `biketeamMigration`.** Plus de bandeau « Mode » ni d'avertissement de remise à zéro : un
   bandeau dit que l'équipe est copiée ou mise à jour, que rien ne change sur biketeam, que la
   migration se relance à volonté et que la bascule des adresses se décide ensuite depuis
   biketeam. Clés `biketeamMigration.copy.*` ; `biketeamMigration.mode.*`,
   `biketeamMigration.reset.*`, `biketeamMigration.block.RESET_BLOCKED` et
   `errors.api.BIKETEAM_RESET_BLOCKED` supprimées (fr + en).
10. **Conséquence : une équipe migrée ne peut plus être retirée de Pédalons par le produit.**
    `DELETE /teams/{slug}` la refuse (`MIGRATED_TEAM`, ledger `MIG-5`) et le reset, seule voie qui
    la mettait à la corbeille, n'existe plus. Une copie faite « pour voir » reste donc, avec la
    visibilité de l'équipe biketeam (décision 2). À trancher : ledger `MIG-18`.

**biketeam** (implémenté en parallèle par le propriétaire ; décrit ici pour le contrat)

11. **Plus d'option au démarrage** (§9.2, §9.3) : ni « Essai », ni « Réinitialiser le groupe sur
    Pédalons avant la migration ». Toute migration réussie laisse le groupe **modifiable et non
    redirigé**.
12. **Bascule par un seul bouton** : quand l'admin du groupe le décide, « Basculer vers Pédalons »
    enregistre la table d'URL (`urlMap`) de la dernière migration réussie et passe directement le
    groupe à `MIGRATED` (redirections, lecture seule, `410` sur l'API). Les états `MIGRATING` et
    `READY` disparaissent tous les deux, et avec eux le gel en lecture seule avant bascule (plus de
    `423` / `TEAM_FROZEN`, §9.5). Ce qui est modifié sur biketeam après la dernière migration
    réussie n'arrive pas sur Pédalons : l'admin relance une migration juste avant de basculer s'il
    le faut. L'annulation d'une bascule par un admin plateforme (§9.6) est inchangée.
