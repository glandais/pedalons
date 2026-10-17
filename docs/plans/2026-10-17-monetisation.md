# Monétiser pedalons.fr — modèle, paiement, abonnements

Écrit le 17 octobre 2026. **État : proposition, rien n'est décidé ni implémenté.** Ledger `BILL-1`
(la décision et le socle), les suites sont numérotées au §10. Fait suite à la lecture du rapport
Ride with GPS ([`../research/2026-10-17-rwgps-state-of-the-cycling-club-2026.md`](../research/2026-10-17-rwgps-state-of-the-cycling-club-2026.md)),
dont le §7 parle de commercialisation sans dire comment facturer.

L'état de Pédalons décrit ici a été vérifié dans le code le 17 octobre 2026 (`develop`, contrat
`11.5.1`, migration `V71`). Les chemins Java sont relatifs à `backend/src/main/java/fr/pedalons/`.
Les faits sur Stripe, Apple et la fiscalité sont au §9, avec ce qui est **supposé** et doit être
vérifié avant la première ligne de code.

---

## Sommaire

1. [En une page](#1-en-une-page)
2. [Ce qui existe déjà](#2-ce-qui-existe-déjà)
3. [Le modèle de tarification](#3-le-modèle-de-tarification)
4. [Le paiement](#4-le-paiement)
5. [Le suivi des abonnements — backend](#5-le-suivi-des-abonnements--backend)
6. [Les clients — web, mobile, Karoo, Garmin](#6-les-clients--web-mobile-karoo-garmin)
7. [Juridique, fiscal, vie privée](#7-juridique-fiscal-vie-privée)
8. [Exploitation](#8-exploitation)
9. [Faits externes, hypothèses à vérifier](#9-faits-externes-hypothèses-à-vérifier)
10. [Découpage, ordre et tailles](#10-découpage-ordre-et-tailles)
11. [Décisions à prendre par le propriétaire](#11-décisions-à-prendre-par-le-propriétaire)
12. [Délibérément dehors](#12-délibérément-dehors)

---

## 1. En une page

**Qui paie : l'équipe, jamais le membre.** Le rapport RWGPS le confirme : 8 clubs sur 10 ont une
cotisation, mais modeste, et un club de 51 à 200 membres décide de ses outils en hiver, en assemblée
générale, sur un budget annuel. Un prix par membre et par mois est illisible pour un trésorier
d'association ; un prix par équipe et par an se vote en AG. Le membre, lui, ne voit jamais de
paiement : tout ce qui est « gratuit pour le cycliste » le reste.

**Trois paliers, un seul levier de vente : la taille de l'équipe et les intégrations.**

| Palier | Prix (HT, à trancher §11) | Pour qui | Ce qui le distingue |
|---|---|---|---|
| **Peloton** (gratuit) | 0 € | Groupe d'amis, section naissante | Jusqu'à **25 membres**, tout le produit de base : sorties avec groupes, parcours GPX, posts, annonces, calendrier, notifications in-app et push |
| **Club** | **8 €/mois** ou **80 €/an** | Le club type du rapport (51–200 membres) | Membres **illimités**, planificateur de parcours, envoi vers Garmin/Karoo/Wahoo et envoi automatique, webhook Slack/Discord, résumé par e-mail, statistiques « actifs vs inscrits » (chantier D du rapport), export des membres |
| **Fédération** | sur devis, à partir de **30 €/mois** | Comité départemental, organisateur d'événement, réseau de clubs | Un **site à son nom** (`DomainAlias`, déjà en place), plusieurs équipes gérées par la même personne, support prioritaire |

Pourquoi 25 : c'est le seuil du rapport sous lequel 61 % des clubs n'ajoutent personne en un an —
en dessous ce n'est pas un club qui a un budget, au-dessus il en a un. Pourquoi 80 €/an : moins
qu'une licence FFVélo par an, moins qu'un maillot ; au niveau d'un club, c'est **moins de 1 € par
membre et par an**, ce qui se dit en AG en une phrase.

**Paiement par Stripe, dans deux formes** : le self-service (carte ou prélèvement SEPA, via
Stripe Checkout + Customer Portal) pour qui a une carte du club, et **la facture à régler par
virement** (Stripe Invoicing, `collection_method: send_invoice`) pour le trésorier qui doit
présenter une facture et payer depuis le compte de l'association. Les deux aboutissent au même
objet Stripe `Subscription` et au même suivi chez nous.

**Suivi chez nous : une table `team_subscriptions`, alimentée par les webhooks Stripe, et une seule
fonction qui dit ce que l'équipe a le droit de faire** (`TeamEntitlements`). Le reste du code ne
connaît ni Stripe ni les prix : il demande « cette équipe peut-elle ouvrir le planificateur ? » et
obtient oui, non, ou « oui, en période de grâce ». La bascule d'un palier à l'autre ne supprime
jamais rien : un club qui redescend en gratuit garde ses 300 membres et ses parcours, il ne peut
plus *ajouter* de membre et perd les intégrations.

**Lancement en trois temps** : (1) tout le monde en « Club » gratuitement jusqu'au **31 mars 2027**
(la saison se décide en hiver, les adhésions culminent en avril — rapport §3.6), (2) à partir de
janvier 2027, la page de tarifs et le paiement ouverts, (3) au 1er avril 2027, les équipes qui
n'ont pas souscrit passent en « Peloton » avec leurs droits acquis. Les équipes migrées de biketeam
(`n-peloton`, `gaby`) et toute équipe que le propriétaire désigne sont « offertes » sans limite de
durée : un palier géré à la main depuis l'admin plateforme, pas un cas spécial dans le code.

---

## 2. Ce qui existe déjà

Tout ce qui suit est en place et se réutilise tel quel.

### 2.1 Deux familles de drapeaux sur `Team`

`domain/team/Team.java` porte déjà deux sortes de « blocage par équipe » :

| Famille | Champs | Qui les règle | Rôle aujourd'hui |
|---|---|---|---|
| **Modules choisis par l'équipe** | `enableTrips`, `enableAds`, `enablePosts`, `enableRides`, `enableRoutes`, `enableMemberDirectory`, `postsAsTeamByDefault` | L'admin d'équipe, par `TeamRequest` (`TeamService.applyFeatureFlags`, création et modification) | Ce que l'équipe veut *montrer* |
| **Gouvernance plateforme** | `visibilityEditable`, `joinable`, `addMemberAllowed`, `enableRoutePlanner` | L'admin plateforme seul, `PATCH /api/admin/teams/{id}/attributes` (`AdminTeamService.updateTeamAttributes`) ; une nouvelle équipe part à `false` partout (`TeamService.createTeam:162`), une équipe migrée de biketeam à `true` (`BiketeamMigrationService:388`) | Ce que la plateforme *autorise* |

La seconde famille est exactement le mécanisme d'un palier payant, **à la main**. Le plan ne la
remplace pas : il ajoute une troisième source de vérité (l'abonnement) et une fonction qui combine
les trois. L'admin plateforme garde la main : un drapeau de gouvernance forcé à `true` reste un
droit, quel que soit le palier (c'est ce qui fait le palier « offert »).

Les deux clients lisent ces drapeaux dans `TeamDetailDto` (`enableRoutePlanner`, `joinable`…) et
le web décide de montrer ou non le planificateur avec (`frontend/src/components/route/RouteEditor.tsx`).
Il faut donc **ajouter** une notion de droit au DTO, pas la déduire des drapeaux existants (§5.5).

### 2.2 Ce qui s'inscrit naturellement dans un palier

| Capacité | Où elle vit | Palier proposé |
|---|---|---|
| Planificateur de parcours (Valhalla, 17 Go de tuiles partagées) | `Team.enableRoutePlanner`, `Domain.enableGpxPlanner` | Club |
| Envoi vers Garmin/Karoo/Wahoo, envoi automatique (`API-120`, `GPS_SYNC_ENABLED`) | `GpsResource`, `service/gps/sync/` | Club (le lien de compte reste personnel ; c'est l'*équipe* qui ouvre la fonction à ses membres) |
| Webhook d'équipe Slack/Discord/Mattermost | `service/notification/TeamWebhookService` | Club |
| Résumé quotidien par e-mail (construit, coupé en prod depuis le 21 septembre 2026, `NOTIF-9`) | `NotificationScheduler` | Club — la réouverture que le rapport demande (§6-G) devient une raison de payer |
| Site à son nom | `domain/platform/DomainAlias`, `AdminDomainAliasService` | Fédération |
| Plusieurs équipes administrées par la même personne | `TeamService.MAX_ADMIN_TEAMS_PER_USER = 1` | Fédération (la limite devient un droit) |
| Taille de l'équipe | `UserTeam`, `TeamMembershipService.joinTeam`, `TeamInvitationService` | Peloton ≤ 25 ; au-delà, Club |
| Stockage (pièces jointes, images) | `Asset.fileSize` est renseigné et rattrapé par `AssetSizeBackfillScheduler` | Un quota est *calculable* dès aujourd'hui ; non recommandé comme levier (§3.4) |

### 2.3 Ce qui n'existe pas

- Aucun code de paiement, aucune dépendance Stripe, aucun mot « abonnement » dans le backend hors
  des flux iCal et des notifications.
- Aucune page de tarifs : `pages/features/FeaturesPage.tsx` présente le produit sans prix, et les
  CGU (§2 « Description du service ») ne disent ni gratuit ni payant.
- Aucune mention de paiement dans la politique de confidentialité ; Scaleway et GitHub sont les
  deux seuls sous-traitants déclarés (§4 de la politique).
- La **base installée est minuscule** : en prod au 16 octobre 2026, `n-peloton` (5 membres, 2 696
  parcours, 557 sorties) et `gaby` (1 membre). Le plan ne peut pas s'appuyer sur une mesure
  d'usage : c'est un plan de *lancement*, pas d'optimisation.

---

## 3. Le modèle de tarification

### 3.1 Les principes

1. **L'unité facturée est l'équipe.** Un abonnement = une `Team`. Un membre ne paie jamais rien ;
   l'app mobile ne vend rien (§6.2).
2. **Un palier se décrit par des droits, pas par des fonctions cachées.** Les droits sont peu
   nombreux et nommés (§5.3) ; une fonction absente du produit n'est pas « premium », elle n'existe
   pas.
3. **Redescendre ne détruit rien.** Perdre un palier bloque des *actions* (ajouter un membre,
   dessiner un parcours, envoyer vers un compteur), jamais des *données* ni de la lecture.
4. **Le prix se dit en une phrase en AG.** Par an, HT et TTC affichés, moins de 1 € par membre.
5. **Le gratuit est un vrai produit**, pas une démo : le groupe de 12 amis qui roule le dimanche
   doit pouvoir rester gratuit pour toujours. C'est aussi le bouche-à-oreille (42 % des arrivées
   dans le rapport) : chaque membre d'un club payant qui crée son petit groupe le fait gratuitement.

### 3.2 Les paliers, en détail

| Droit (`Entitlement`) | Peloton | Club | Fédération | Offert |
|---|---|---|---|---|
| `MEMBER_LIMIT` | 25 | illimité | illimité | illimité |
| `ROUTE_PLANNER` | — | ✓ | ✓ | ✓ |
| `GPS_SYNC` (envoi manuel et automatique vers Garmin/Karoo/Wahoo) | — | ✓ | ✓ | ✓ |
| `TEAM_WEBHOOK` | — | ✓ | ✓ | ✓ |
| `EMAIL_DIGEST` | — | ✓ | ✓ | ✓ |
| `MEMBER_STATS` (actifs vs inscrits, usage des parcours — chantier D du rapport, à construire) | — | ✓ | ✓ | ✓ |
| `MEMBER_EXPORT` (CSV de la liste, le « pont » vers l'outil fédéral) | — | ✓ | ✓ | ✓ |
| `ADMIN_TEAMS_LIMIT` (équipes administrées par un même compte) | 1 | 1 | 5 | selon |
| `CUSTOM_HOSTNAME` | — | — | ✓ | selon |
| `PRIORITY_SUPPORT` (adresse dédiée, délai annoncé) | — | — | ✓ | — |

Ce qui reste **gratuit partout**, et doit le rester parce que c'est la valeur de base que le rapport
valide : sorties avec groupes et allure, parcours GPX importés avec distance/dénivelé/surface, carte,
météo, posts, annonces, commentaires, calendrier iCal, notifications in-app et push, applications
mobile, Karoo et Garmin (lecture et téléchargement FIT), page publique SSR, vitrine, invitations
par e-mail, modèles de sortie, tags.

> **Nuance sur `GPS_SYNC`.** Le téléchargement du FIT depuis l'app Garmin et la lecture par
> l'extension Karoo (`DeviceRouteService`) restent gratuits : c'est le *compteur* qui vient
> chercher. Ce qui passe en Club, c'est le *push* depuis nos serveurs vers les clouds Hammerhead,
> Garmin et Wahoo — celui qui nous coûte des quotas d'API et des contrats de partenaire.

### 3.3 Les prix proposés et ce qui les justifie

| Palier | Mensuel | Annuel | Remise annuelle |
|---|---|---|---|
| Club | 8 € HT | 80 € HT | 2 mois |
| Fédération | 30 € HT | 300 € HT | 2 mois |

Repères : RWGPS vend son compte club entre 199 et 599 $/an selon la taille (vérifié §9) ; un club
de 100 membres à 20 €/an de cotisation encaisse 2 000 €. 80 € est 4 % de ce budget. Les
coûts marginaux par club sont faibles (une base, Valhalla partagé, Open-Meteo), le coût fixe
d'exploitation est l'instance Scaleway et le temps du propriétaire : **la première dizaine de
clubs payants couvre l'hébergement, pas le travail**. Le prix sert d'abord à qualifier (un club qui
paie 80 € a une AG, un trésorier et des raisons de rester) et à financer l'infrastructure, pas à
vivre du produit — ce que le propriétaire doit dire explicitement au §11.

L'**annuel est le mode par défaut** sur la page de tarifs : il colle au cycle des clubs (AG d'hiver,
saison d'avril) et évite 11 relances de prélèvement.

### 3.4 Ce qu'on ne fait pas payer, et pourquoi

- **Pas de prix par membre.** Illisible pour un trésorier ; incite le club à ne pas inscrire ses
  membres — exactement l'inverse de ce que le produit veut (« la liste n'est pas le club »).
- **Pas de quota de stockage ni de parcours.** `n-peloton` a 2 696 parcours : un quota le
  pénaliserait, et le rapport montre que la taille de bibliothèque ne prédit rien. Les bornes de
  sécurité existantes (`GpxLimits`, 10 Mo par GPX, 100 Mo par requête) suffisent contre l'abus.
- **Pas d'abonnement individuel** (« Pédalons Premium » pour un cycliste) : l'anti-persona de la
  fiche produit est le cycliste solitaire. Si une demande réelle apparaît (envoi GPS pour un
  membre d'une équipe gratuite), elle sera réexaminée — pas avant.
- **Pas de publicité, pas de vente de données.** Incompatible avec la politique de confidentialité
  telle qu'écrite et avec le positionnement.
- **Pas de gestion des cotisations du club** (encaisser les adhésions pour le compte du club).
  Déjà écarté par le rapport (§6-I) : en France, c'est le rôle des fédérations et de HelloAsso ;
  `MEMBER_EXPORT` est le pont.

---

## 4. Le paiement

### 4.1 Le prestataire : Stripe

Choisi pour : abonnements natifs (`Subscription`, essais, prorata, relances), SEPA et carte,
factures hébergées payables par virement, Customer Portal (le client change de carte, de palier,
résilie, télécharge ses factures sans qu'on code un écran), webhooks signés, pas de minimum, API
stable et SDK Java officiel (`com.stripe:stripe-java`). Alternatives écartées :

| Alternative | Pourquoi non |
|---|---|
| GoCardless | SEPA seulement ; pas de facture hébergée ni de portail client équivalent |
| Paddle, Lemon Squeezy (marchand de référence) | Règlent la TVA internationale, inutile pour des clubs français ; commission 5 % + ; facture au nom du marchand, ce qu'un trésorier d'association ne veut pas |
| HelloAsso | Réservé aux associations bénéficiaires ; Pédalons est une entreprise individuelle (§7) |
| Virement manuel + tableur | Zéro commission, mais aucun suivi automatique ; gardé comme **repli** pour un club qui refuse tout le reste : palier « offert » posé à la main avec une date de fin, facture faite hors outil |

### 4.2 Deux parcours d'achat, un même abonnement

**A. Self-service** (carte, SEPA) — `POST /api/teams/{slug}/billing/checkout-session` crée une
`Checkout Session` en mode `subscription` avec `customer` (créé ou retrouvé), `client_reference_id =
teamId`, `success_url` et `cancel_url` sur la page de tarifs de l'équipe, `allow_promotion_codes`,
`tax_id_collection` (SIRET/TVA facultatifs), `billing_address_collection: required` (la facture doit
porter l'adresse du club), `locale: fr`. On ne reçoit jamais de numéro de carte : la page est chez
Stripe.

**B. Sur facture** (virement) — `POST /api/teams/{slug}/billing/invoice-request` crée la même
`Subscription` avec `collection_method: send_invoice`, `days_until_due: 30`, et
`payment_settings.payment_method_types: ["sepa_debit", "customer_balance"]` (virement SEPA vers un
IBAN virtuel Stripe, rapproché automatiquement). Le trésorier reçoit une facture PDF avec IBAN et
référence ; dès le virement reçu, Stripe passe la facture `paid` et la souscription `active`. En
attendant, l'équipe est en **`PENDING`** avec les droits du palier *déjà ouverts* (§5.2) : on ne fait
pas attendre un club 30 jours pour un virement d'association.

Les deux parcours ne sont ouverts qu'à un **admin de l'équipe** (`@CheckAccess(TEAM, UPDATE)`), et
la souscription porte `metadata.teamId` et `metadata.domainId` : c'est par là que le webhook
retrouve l'équipe, pas par l'e-mail du payeur (qui peut changer de club).

### 4.3 Après l'achat : le Customer Portal

`POST /api/teams/{slug}/billing/portal-session` renvoie une URL de portail Stripe où l'admin
d'équipe change de moyen de paiement, passe de mensuel à annuel, résilie (à fin de période, jamais
immédiatement), télécharge ses factures. On ne code **aucun** de ces écrans. Le portail est
configuré dans le tableau de bord Stripe (une fois, documenté en `OPERATIONS.md`) : résiliation
autorisée, changement de palier Club ↔ Fédération autorisé, pas de pause.

### 4.4 Codes promotionnels

Gérés chez Stripe (`Coupon` + `PromotionCode`), saisis sur la page Checkout. Usage prévu :
« première saison à -50 % » pour un club apporté par un autre, offre comité départemental. Aucun
code chez nous, aucune table.

---

## 5. Le suivi des abonnements — backend

### 5.1 Le modèle

Une nouvelle table, une entité, un enum de palier, un enum d'état, un journal des événements Stripe.

```sql
-- V72__team_subscriptions.sql (nom indicatif)
create table team_subscriptions (
  id                      bigint primary key,
  team_id                 bigint not null unique references teams(id),
  plan                    varchar(20)  not null,          -- PELOTON | CLUB | FEDERATION
  status                  varchar(20)  not null,          -- §5.2
  source                  varchar(20)  not null,          -- STRIPE | MANUAL
  stripe_customer_id      varchar(64),
  stripe_subscription_id  varchar(64) unique,
  current_period_end      timestamptz,
  trial_end               timestamptz,
  cancel_at               timestamptz,
  grace_until             timestamptz,
  manual_note             varchar(500),                   -- « offert : club pilote », posé par l'admin plateforme
  created_at              timestamptz not null,
  updated_at              timestamptz not null,
  version                 bigint not null
);

create table stripe_events (
  id            varchar(64) primary key,                  -- evt_… : idempotence
  type          varchar(100) not null,
  received_at   timestamptz not null,
  processed_at  timestamptz,
  error         varchar(2000)
);
```

- **Une ligne par équipe, créée à la demande** : une équipe sans ligne est en `PELOTON` / `ACTIVE`
  (pas de rattrapage de données ; `TeamEntitlements` traite l'absence comme le gratuit).
- `source = MANUAL` est le palier « offert » : posé par l'admin plateforme, jamais touché par un
  webhook. Un webhook Stripe pour une équipe en `MANUAL` est journalisé et ignoré (le cas ne doit
  pas se produire : l'écran d'achat est caché à une équipe offerte).
- **Aucune donnée de paiement chez nous** : ni carte, ni IBAN, ni adresse de facturation — Stripe
  les tient. On stocke deux identifiants opaques.
- Pas de `deleted` : la ligne suit l'équipe (soft delete de `Team`) ; à la suppression définitive
  d'une équipe (si elle existe un jour), résilier la souscription Stripe d'abord.

### 5.2 Les états et leurs transitions

| `status` | Sens | Droits du palier |
|---|---|---|
| `ACTIVE` | Payé, ou offert, ou essai en cours | Ouverts |
| `PENDING` | Facture envoyée, virement attendu (parcours B) | Ouverts |
| `PAST_DUE` | Un paiement a échoué ; Stripe relance (Smart Retries, 3 semaines) | Ouverts jusqu'à `grace_until` (= échec + 21 jours), puis fermés |
| `CANCELED` | Résilié, fin de période atteinte, ou facture impayée après les relances | Fermés : l'équipe est traitée comme `PELOTON` |

Les transitions viennent des webhooks (`customer.subscription.created|updated|deleted`,
`invoice.paid`, `invoice.payment_failed`, `invoice.marked_uncollectible`) ; un job quotidien
(`SubscriptionReconcileScheduler`, 04:20, `Crons.ZONE`) relit chez Stripe toute souscription dont
`current_period_end` est dépassée de plus de 2 jours sans événement reçu, pour rattraper un webhook
perdu. Le job est idempotent (relire puis écrire l'état, pas « avancer d'un cran »), ce que le
déploiement à chaud impose (CLAUDE.md, « Deploys are rolling »).

**Le cas « on redescend »** (`CANCELED`, ou `PAST_DUE` après la grâce) ne modifie aucune autre
table : les 300 membres restent, les parcours dessinés restent, le webhook configuré reste en base
mais n'est plus appelé, les envois automatiques GPS en attente sont annulés par le planificateur
existant (`GpsRouteSyncPlanner`) qui vérifiera le droit comme il vérifie déjà `enabled`.

### 5.3 `TeamEntitlements` : la seule porte

```java
// service/billing/TeamEntitlements.java — résolu une fois par requête (RequestScoped), par équipe
public record TeamEntitlements(Plan plan, SubscriptionStatus status, boolean inGrace,
                               int memberLimit, int adminTeamsLimit, Set<Entitlement> granted) {
  public boolean has(Entitlement e) { … }
  public boolean canAddMember(long currentCount) { return currentCount < memberLimit; }
}
```

`TeamEntitlementsResolver.forTeam(Team)` combine, dans cet ordre :

1. la ligne `team_subscriptions` (absente → `PELOTON`/`ACTIVE`) et sa période de grâce ;
2. les **drapeaux de gouvernance existants** — `enableRoutePlanner = true` posé par l'admin
   plateforme **accorde** `ROUTE_PLANNER` même en `PELOTON` (c'est ainsi que les équipes migrées de
   biketeam gardent ce qu'elles ont, sans ligne d'abonnement) ; `addMemberAllowed` continue de
   gouverner *qui* peut ajouter, la limite gouverne *combien* ;
3. les modules choisis par l'équipe (`enableRoutes`…) **ne jouent pas** : ce sont des préférences
   d'affichage, pas des droits.

Les points de contrôle, chacun avec son code d'erreur nouveau dans `ErrorCode` :

| Action | Où | Erreur |
|---|---|---|
| Rejoindre, accepter une invitation, être ajouté | `TeamMembershipService.joinTeam`, `TeamInvitationService.accept`, ajout par l'admin, import biketeam (`BiketeamMigrationService` : **exempté**, l'équipe migrée est offerte) | `409 PLAN_MEMBER_LIMIT_REACHED` |
| Envoyer une invitation | `TeamInvitationService` : refus si `membres + invitations en cours ≥ limite` | idem |
| Dessiner / modifier un tracé | `RouteResource` (planificateur), `/api/router` (Valhalla) | `403 PLAN_REQUIRED` avec `entitlement: ROUTE_PLANNER` |
| Envoyer vers un service GPS, activer l'envoi automatique | `GpsResource.uploadRoute`, `GpsRouteSyncPlanner` (filtre SQL sur les équipes titulaires, **par page, pas par ligne**) | `403 PLAN_REQUIRED` |
| Configurer / déclencher le webhook d'équipe | `TeamWebhookService` | `403 PLAN_REQUIRED` ; en livraison, une équipe sans droit est sautée silencieusement |
| Résumé e-mail | `NotificationScheduler` (job quotidien) | filtre par équipe, par page |
| Créer une 2ᵉ équipe administrée | `TeamService.createTeam` (`MAX_ADMIN_TEAMS_PER_USER` devient `adminTeamsLimit`) | `USER_TEAM_LIMIT_REACHED` (existant) |
| Alias de domaine | `AdminDomainAliasService` : reste admin plateforme ; le droit `CUSTOM_HOSTNAME` sert à l'affichage et au devis, pas à un self-service | — |

`PLAN_REQUIRED` porte dans `ErrorResponse.details` le droit manquant et le palier qui l'ouvre : le
client affiche « Disponible avec le palier Club » et, si l'utilisateur est admin de l'équipe, un
lien vers la page de tarifs ; sinon « Demandez à un administrateur de l'équipe ».

**Invariant de coût** : aucune résolution par ligne dans une liste. Une page de sorties ne
demande pas 20 fois les droits ; le fil ne les demande pas du tout. Un `BillingQueryCountTest` sur
`GpsRouteSyncPlanner` et le job de résumé garde cela, comme les `…QueryCountTest` existants.

### 5.4 Le webhook Stripe

`POST /api/billing/stripe/webhook` — `@Public`, hors `@RolesAllowed`, **exclu du filtre CSRF**
(`CrossSiteRequestFilter`) et de la résolution de domaine (`DomainResolver` ne trouvera aucun
`Host` connu : l'endpoint est monté sur un hostname dédié `billing.pedalons.fr`, ou exempté par
chemin — à trancher à l'implémentation, le second est plus simple).

1. Lire le corps brut, vérifier `Stripe-Signature` avec `STRIPE_WEBHOOK_SECRET`
   (`Webhook.constructEvent`, tolérance 5 min). Échec → `400`, journalisé en `WARN` sans le corps.
2. `insert into stripe_events … on conflict do nothing` : si la ligne existait, répondre `200`
   sans rien faire (Stripe renvoie les événements, parfois dans le désordre).
3. Traiter dans la même transaction ; retrouver l'équipe par `metadata.teamId` ou
   `stripe_subscription_id` ; mettre à jour la ligne depuis **l'objet complet relu chez Stripe**
   (`Subscription.retrieve`), pas depuis le contenu de l'événement, pour que l'ordre d'arrivée ne
   compte pas.
4. Répondre `200` en moins de quelques secondes ; tout envoi de notification est délégué au
   pipeline existant (`NotificationEvent`, livré par `NotificationScheduler`), jamais fait en ligne.

Événements → effets :

| Événement | Effet |
|---|---|
| `checkout.session.completed` | Lier `customer` et `subscription` à l'équipe (`client_reference_id`) ; état depuis la souscription |
| `customer.subscription.created/updated` | `plan` depuis `price.lookup_key` (`club_monthly`, `club_yearly`…), `status`, `current_period_end`, `cancel_at`, `trial_end` |
| `customer.subscription.deleted` | `CANCELED` |
| `invoice.paid` | `ACTIVE`, `grace_until = null` ; notification « Merci, votre abonnement Club est actif jusqu'au … » à tous les admins de l'équipe |
| `invoice.payment_failed` | `PAST_DUE`, `grace_until = now + 21 j` ; notification aux admins avec le lien du portail |
| `invoice.marked_uncollectible`, `invoice.voided` (parcours B expiré) | `CANCELED` |

Les prix sont identifiés par `lookup_key`, jamais par identifiant `price_…` codé en dur : les
mêmes clés existent en test et en prod.

### 5.5 Le contrat d'API (`12.0.0`, majeure — voir la nuance)

Nouveaux objets, nouveaux endpoints, un champ ajouté :

```yaml
TeamDetailDto:
  plan:          { $ref: Plan }                      # PELOTON | CLUB | FEDERATION — tout lecteur
  entitlements:  { type: array, items: Entitlement } # ce que l'équipe peut faire — tout lecteur
  memberLimit:   { type: integer, nullable: true }   # null = illimité
  billing:       { $ref: TeamBillingDto, nullable: true }  # admins d'équipe seulement, sinon null

TeamBillingDto:
  status:            SubscriptionStatus
  source:            STRIPE | MANUAL
  currentPeriodEnd:  Instant?
  cancelAt:          Instant?
  graceUntil:        Instant?
  portalAvailable:   boolean          # true si STRIPE et customer existant

POST /api/teams/{slug}/billing/checkout-session   { priceLookupKey }  → { url }
POST /api/teams/{slug}/billing/invoice-request    { priceLookupKey, billingEmail, legalName, address } → { hostedInvoiceUrl }
POST /api/teams/{slug}/billing/portal-session     → { url }
GET  /api/billing/plans                            → catalogue (paliers, droits, prix HT/TTC, lookup keys) — public, sans session, mis en cache
POST /api/billing/stripe/webhook                   → 200 (hors contrat client : documenté mais exclu de la génération)

PATCH /api/admin/teams/{id}/subscription           { plan, note, until? }  → pose ou retire un palier MANUAL
GET   /api/admin/teams/{id}/subscription
```

`AppConfigDto` gagne `billingEnabled: boolean` (`BILLING_ENABLED`, défaut `false` : sans clés
Stripe, la page de tarifs ne montre aucun bouton d'achat et tout le monde est en « Club » — c'est
l'état de la phase 1 du lancement, §10).

**Majeure ou mineure ?** Les champs ajoutés sont des ajouts (mineure, `11.6.0`). Ce qui est une
rupture, c'est le **comportement** : des actions qui réussissaient répondent `403 PLAN_REQUIRED`
ou `409 PLAN_MEMBER_LIMIT_REACHED`. Un mobile ancien afficherait une erreur générique. Comme le
mobile est hors stores et republié avec le backend (`API-42`), on peut rester en mineure pour le
contrat et traiter la rupture par la republication — **à trancher au §11**. Le plan propose
`11.6.0` pour l'ajout des champs (phase 1, inerte) et `12.0.0` pour l'activation des refus
(phase 3).

### 5.6 Admin plateforme

`AdminTeamDto` gagne `plan`, `subscriptionStatus`, `subscriptionSource`, `currentPeriodEnd` ;
`AdminTeamsPage` les affiche et offre « Offrir le palier … jusqu'au … » / « Retirer ». C'est l'outil
du lancement (phase 1 : tout le monde offert jusqu'au 31 mars 2027, posé par un script SQL de
migration `V7x__launch_offer.sql` plutôt qu'à la main, idempotent, et **réversible** par le même
écran).

Un tableau de bord minimal sur `AdminDashboardPage` : équipes par palier, abonnements en
`PAST_DUE`, échéances dans les 30 jours. Le chiffre d'affaires se lit chez Stripe, pas chez nous.

### 5.7 Tests

- `TeamEntitlementsResolverTest` : les trois sources combinées, la grâce, l'absence de ligne, le
  `MANUAL` qui prime, le drapeau de gouvernance qui accorde.
- `StripeWebhookResourceTest` : signature invalide → 400 ; événement rejoué → 200 sans effet ;
  événements dans le désordre → état final identique (le client Stripe est **simulé** par une
  interface `StripeGateway`, comme `OpenMeteoGateway` ; aucun test ne parle à Stripe).
- `BillingLimitsResourceTest` : 26ᵉ membre refusé en `PELOTON`, accepté en `CLUB` ; invitation
  comptée ; planificateur et envoi GPS refusés avec `PLAN_REQUIRED` ; une équipe migrée garde
  `enableRoutePlanner`.
- `BillingQueryCountTest` : le planificateur GPS et le résumé ne coûtent pas une requête par
  équipe.
- e2e Playwright : la page de tarifs, le bandeau admin, le refus du 26ᵉ membre ; **pas** de
  Checkout (page externe) — le parcours réel se recette à la main en mode test Stripe (§8).

---

## 6. Les clients — web, mobile, Karoo, Garmin

### 6.1 Web

- **Page de tarifs publique** `/tarifs` (`contracts/routes.yaml`, puis `pnpm generate-routes`), en
  SSR : trois colonnes, annuel par défaut, HT et TTC, FAQ (« qui paie ? », « que se passe-t-il si
  on arrête ? », « facture pour le trésorier ? »), lien vers la vitrine. Mêmes données que
  `GET /api/billing/plans`.
- **Dans les paramètres d'équipe** (admin) : un onglet « Abonnement » — palier, état, échéance,
  bouton « Passer au palier Club » (Checkout) ou « Recevoir une facture » (parcours B), « Gérer
  l'abonnement » (portail), et pendant la grâce un bandeau rouge « Paiement en échec, droits
  maintenus jusqu'au … ».
- **Aux points de refus** : `PLAN_REQUIRED` est rendu par un composant unique
  (`PlanRequiredNotice`) qui connaît le rôle de l'utilisateur ; `PLAN_MEMBER_LIMIT_REACHED` est
  rendu sur l'invitation et la liste des membres avec un compteur « 24 / 25 ».
- **Vitrine** : `FeaturesPage` gagne une ligne « Gratuit jusqu'à 25 membres » et un lien vers les
  tarifs ; la page publique d'équipe ne montre jamais le palier.
- Pas de nouveau composant hors Mantine (compétence `mantine-ui`).

### 6.2 Mobile (Flutter)

**L'application ne vend rien et n'en parle pas.** Elle lit `plan`, `entitlements`, `memberLimit`
dans `TeamDetailDto` et :

- cache les actions sans droit (envoi GPS, webhook) ou les montre désactivées avec « Disponible
  avec le palier Club — à régler par un administrateur sur le site » ;
- rend `PLAN_REQUIRED` / `PLAN_MEMBER_LIMIT_REACHED` par un message, sans prix et sans lien
  d'achat.

Raison : les lignes directrices App Store (3.1.1 et 3.1.3) imposent l'achat intégré pour toute
fonction numérique vendue *dans* l'app et encadrent les liens vers un achat externe ; un
abonnement d'organisation acheté sur le web et simplement *reflété* dans l'app est la pratique des
outils d'équipe (3.1.3 b, « multiplatform services ») à condition de ne pas inciter à l'achat depuis
l'app. Tant que le mobile est hors stores, c'est sans enjeu ; le jour de la soumission, c'est la
règle qui tient (`MOB`, fiches des stores). Vérifié §9.

### 6.3 Karoo et Garmin

Rien ne change : la lecture et le FIT restent gratuits (§3.2). La synchro Karoo
(`POST /api/device/routes/{team}/{route}/sync`) passe par la table d'envois GPS : elle vérifiera
`GPS_SYNC` et répondra `403 PLAN_REQUIRED` ; l'extension affiche son message d'erreur générique,
suffisant pour un cas que l'app a déjà expliqué.

---

## 7. Juridique, fiscal, vie privée

### 7.1 Le vendeur

Le responsable du traitement est **LANDAIS Gabriel, entreprise individuelle** (politique §12) :
une EI peut facturer. Points à régler avec l'expert-comptable **avant** la première facture (§11) :

- **TVA** : une EI sous le seuil de franchise en base facture « TVA non applicable, art. 293 B du
  CGI » ; au-delà, 20 %. Le seuil (prestations de services) et son éventuelle réforme sont à
  vérifier à la date du lancement (§9). Les prix sont affichés **HT et TTC** dans tous les cas pour
  que le passage à la TVA ne change pas la grille. Stripe Tax n'est pas nécessaire (clients
  français, B2B) ; si la franchise saute, un simple `tax_rate` fixe de 20 % sur les prix suffit.
- **Mentions de facture** : nom, adresse, SIREN, numéro de facture séquentiel (Stripe les
  numérote), mention de franchise ou TVA, adresse du client — Stripe Invoicing les porte si le
  compte est bien configuré.
- **Déclaration** : le chiffre d'affaires Stripe entre dans les déclarations de l'EI ; l'export
  Stripe mensuel suffit.

### 7.2 Les CGU

Les CGU actuelles ne parlent ni de prix ni de durée. À ajouter, en un article « Abonnements »
(`LEGAL`) : les paliers et leurs limites, la durée (mensuelle ou annuelle, tacite reconduction,
résiliation à tout moment pour la fin de période), ce qui se passe à l'échéance (retour au gratuit,
rien n'est supprimé), le délai de grâce, le prix et sa révision (préavis 30 jours par e-mail aux
admins), le droit de rétractation **non applicable** aux professionnels et associations agissant
dans le cadre de leur activité (à confirmer juridiquement : une association n'est pas un
consommateur au sens du Code de la consommation lorsqu'elle contracte pour son objet), et le
fait que l'abonnement est souscrit par un admin **au nom de l'équipe**.

### 7.3 La politique de confidentialité

- **Nouveau sous-traitant : Stripe** (Stripe Payments Europe Ltd, Irlande ; transferts vers
  Stripe, Inc., États-Unis, encadrés par les clauses contractuelles types et le DPF) — §4 et §5
  de la politique. Données : nom et e-mail de l'admin qui souscrit, nom et adresse de facturation
  du club, moyen de paiement (jamais chez nous), historique des paiements.
- **Nouvelle finalité** : gestion des abonnements et facturation ; base légale : exécution du
  contrat ; conservation : factures **10 ans** (obligation comptable), identifiants Stripe tant
  que l'équipe existe.
- **Effacement de compte** : l'admin qui a souscrit peut supprimer son compte ; la souscription
  reste à l'équipe (le `customer` Stripe porte le nom du club, l'e-mail de facturation est celui
  donné au parcours B ou celui de l'admin au moment de l'achat — à remplacer par un autre admin
  depuis le portail). À écrire dans la politique §7.
- Le relevé des équipes par palier dans l'admin plateforme est couvert par la mention
  « administration de la plateforme » existante.

### 7.4 Ce que le rapport et `WEB-91` imposent

`MEMBER_STATS` (actifs vs inscrits) est un droit **Club**, mais c'est aussi un traitement nouveau :
la base légale (intérêt légitime de l'association pour gérer son activité) et la mention dans la
politique sont à écrire **avant** de l'ouvrir, en même temps que le chantier D du rapport. Ne pas
vendre ce droit avant qu'il existe : la page de tarifs ne liste que ce qui est livré.

---

## 8. Exploitation

- **Secrets** : `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `STRIPE_PUBLISHABLE_KEY` (inutile
  avec Checkout hébergé, gardée pour plus tard), `BILLING_ENABLED` — dans `.env` de prod et de
  staging seulement ; `.env.e2e` et un `.env` de workstation n'ont **aucune** clé Stripe et
  `BILLING_ENABLED=false`. Le test e2e en CI échoue si une clé Stripe apparaît dans `.env.e2e`,
  comme il échoue déjà si le mailer ne pointe pas sur mailpit.
- **Staging** parle au **mode test** Stripe (clés `sk_test_…`), avec son propre endpoint webhook
  déclaré chez Stripe ; prod au mode live. Les deux ont les mêmes `lookup_key`.
- **Webhook** : Stripe réessaie 3 jours ; l'URL passe par Caddy → traefik → backend comme le
  reste. Pendant un déploiement à chaud, les deux backends peuvent recevoir le même événement : la
  table `stripe_events` règle le cas.
- **Monitoring** : un compteur Micrometer `pedalons_billing_webhook_total{type,result}` et une
  alerte Grafana si `stripe_events.error` se remplit ou si aucun événement n'arrive 7 jours
  alors que des abonnements existent.
- **Runbook** (`OPERATIONS.md`, section « Billing ») : configurer le portail, créer les produits
  et prix avec leurs `lookup_key` (script `scripts/stripe-catalog.sh`, idempotent, en mode test
  puis live), rotation du secret de webhook, « un club dit avoir payé et n'a pas ses droits »
  (relire la souscription → job de réconciliation à la main `POST /api/admin/billing/reconcile`),
  rembourser (depuis Stripe ; notre état suit par webhook), poser un palier offert.
- **Sauvegardes** : `team_subscriptions` est dans la base, donc dans `scripts/backup.sh` ; une
  restauration ancienne se corrige par la réconciliation quotidienne (Stripe fait foi).
- **Open-Meteo** : devenir payant tranche la question de `OPS-29` — l'offre gratuite est réservée
  à un usage non commercial. **Avant d'encaisser le premier euro**, passer au plan payant
  (`OPEN_METEO_URL` + `OPEN_METEO_API_KEY`, aucun changement de code) ; à vérifier aussi pour
  les tuiles VersaTiles (`pedalons.map.styles`) et le géocodage (`pedalons.geocode.user-agent`,
  Nominatim ?) dont les conditions d'usage peuvent exclure le commercial (§9).

---

## 9. Faits externes, hypothèses à vérifier

| # | Fait | Source | Confiance |
|---|---|---|---|
| F1 | Stripe Checkout en mode `subscription`, Customer Portal, Invoicing avec `collection_method: send_invoice` et paiement par virement (`customer_balance`, IBAN virtuel SEPA) | Documentation Stripe (Billing, Invoicing, « Bank transfers ») | Élevée ; **vérifier** que `customer_balance` est bien activé pour un compte français en EUR et le délai de rapprochement |
| F2 | Stripe Smart Retries sur ~3 semaines, événements `invoice.payment_failed` / `invoice.marked_uncollectible`, relais 3 jours des webhooks, identifiant d'événement stable pour l'idempotence | Documentation Stripe (Billing, Webhooks) | Élevée |
| F3 | `stripe-java` officiel, sans dépendance Quarkus particulière (client HTTP propre) ; `Webhook.constructEvent` vérifie la signature | Dépôt `stripe/stripe-java` | Élevée ; vérifier la compatibilité Java 25 de la version courante |
| F4 | Frais Stripe en Europe : carte ~1,5 % + 0,25 €, SEPA ~0,35 € plafonné, virement `customer_balance` ~0,25 € ; Billing 0,5–0,7 % en sus selon le palier Stripe | Grille publique Stripe France | Moyenne — **à relire à la date du lancement** ; sur 80 €/an, de l'ordre de 1,5 à 2 € par facture |
| F5 | RWGPS « Club account » : de l'ordre de 199 à 599 $/an selon la taille du club | Page tarifs RWGPS | Moyenne — grille vue en 2026, à revoir |
| F6 | App Store 3.1.1 / 3.1.3(b) : un service multi-plateforme peut ouvrir dans l'app ce qui a été acheté ailleurs, sans lien ni incitation à acheter hors de l'app (les assouplissements UE sur les liens externes ne couvrent pas l'affichage de prix sans lien) | App Store Review Guidelines | Moyenne — relire avant la soumission ; Play (« Payments policy ») a une exception équivalente pour les abonnements d'organisation |
| F7 | Franchise en base de TVA, prestations de services : seuil de l'ordre de 37 500 € (majoré 41 250 €) en 2025 ; la réforme à 25 000 € votée en loi de finances 2025 a été suspendue, puis rediscutée | BOFiP, loi de finances | **Faible sur la valeur 2027** — à vérifier avec l'expert-comptable |
| F8 | Droit de rétractation : non applicable au contrat conclu entre professionnels ou par une association pour son objet (hors cas du non-professionnel ≤ 5 salariés hors champ de l'activité principale, art. L221-3 C. conso.) | Code de la consommation | Moyenne — l'exception L221-3 peut s'appliquer à un petit club : prévoir 14 jours de rétractation offerts à tous, c'est plus simple que de distinguer |
| F9 | Open-Meteo : gratuit « for non-commercial use », plan commercial payant par clé d'API | Conditions Open-Meteo, déjà citées par `OPS-29` | Élevée |
| F10 | VersaTiles (`tiles.versatiles.org`) et Nominatim : conditions d'usage à relire pour un service commercial ; VersaTiles invite à auto-héberger au-delà d'un usage léger, Nominatim interdit l'usage lourd et impose un `User-Agent` | Pages de conditions des deux projets | Moyenne — un auto-hébergement des tuiles est déjà en place pour le rendu serveur (`tileserver`), pas pour les tuiles vecteur du client |

Rien ici ne demande à Stripe de garder nos données de membres : seuls le nom et l'e-mail de l'admin
qui souscrit et les coordonnées de facturation du club partent chez eux.

---

## 10. Découpage, ordre et tailles

Tailles : S = quelques jours, M = une à deux semaines, L = davantage. Chaque lot est livrable seul
et laisse le produit entier ; l'ordre suit le lancement (§1).

| Lot | Ledger | Contenu | Taille | Dépend de |
|---|---|---|---|---|
| **0. Décisions** | `BILL-1` | Les choix du §11 tranchés ; le catalogue Stripe créé en mode test ; expert-comptable consulté (TVA, mentions) | — | — |
| **1. Socle inerte** | `BILL-2` | `V72` (tables), `TeamSubscription`, `TeamEntitlements`, `TeamEntitlementsResolver` ; `plan` / `entitlements` / `memberLimit` dans `TeamDetailDto` (`11.6.0`) ; `AdminTeamDto` et `PATCH …/subscription` ; `BILLING_ENABLED=false` ; la migration de lancement qui pose « Club offert jusqu'au 31 mars 2027 » sur toute équipe existante. **Aucun refus actif.** | M | 0 |
| **2. Stripe** | `BILL-3` | `StripeGateway`, Checkout, portail, parcours B, webhook, `stripe_events`, réconciliation quotidienne, notifications aux admins (`NOTIF`), `GET /api/billing/plans` ; runbook et secrets ; recette en mode test sur staging | M–L | 1 |
| **3. Web** | `BILL-4` | Page `/tarifs` (routes.yaml), onglet « Abonnement », `PlanRequiredNotice`, compteur de membres, vitrine ; e2e | M | 1 (affichage), 2 (achat) |
| **4. Juridique** | `BILL-5` (`LEGAL`) | Article « Abonnements » des CGU, Stripe dans la politique, finalité et conservation, e-mail de préavis | S | 0 |
| **5. Activation des refus** | `BILL-6` | Les points de contrôle du §5.3 avec leurs codes d'erreur ; `12.0.0` ; `BillingLimitsResourceTest`, `BillingQueryCountTest` ; Open-Meteo payant, conditions VersaTiles/Nominatim relues | M | 1, 4 |
| **6. Mobile** | `BILL-7` (`MOB`) | Lecture des droits, actions cachées ou désactivées, rendu des deux erreurs ; republication avec 5 | S | 5 |
| **7. Bascule** | `BILL-8` | 1er avril 2027 : expiration des paliers offerts (le job quotidien suffit, rien à lancer), tableau de bord admin, suivi des `PAST_DUE` | S | 2, 5 |
| **8. Ce qui se vend** | chantiers du rapport `D` (`MEMBER_STATS`), `G` (résumé e-mail) | Livrés comme des droits Club ; ne figurent sur la page de tarifs qu'une fois livrés | M chacun | 5 |

Calendrier visé : lots 1 à 4 avant fin décembre 2026 (page de tarifs visible pour les AG de
janvier), lot 5 en janvier 2027 sur staging puis prod avec `BILLING_ENABLED=true`, lots 6 et 7
avant le 1er avril 2027.

Le préfixe **`BILL`** est nouveau (table de `LEDGER_NEXT.md`, section dans les deux ledgers). Les
tâches purement web, mobile ou légales pourraient porter `WEB`/`MOB`/`LEGAL` ; le plan les garde
sous `BILL` parce qu'elles n'ont de sens qu'ensemble et qu'un `grep BILL-` doit tout retrouver —
**à trancher au §11**, avant le premier commit (un identifiant ne se renomme pas).

---

## 11. Décisions à prendre par le propriétaire

| # | Question | Proposition | Ce que l'autre choix implique |
|---|---|---|---|
| Q1 | Objectif : couvrir les coûts, ou en vivre ? | **Couvrir les coûts et qualifier les clubs**, prix bas, pas de commercial | Vivre du produit demande ×5 sur le prix ou ×50 sur le nombre de clubs, et un vrai canal de vente (l'enquête française 2027 du rapport §7) |
| Q2 | Prix Club | 8 €/mois, 80 €/an HT | 5 €/mois (60 €/an) rapproche du « don » et dévalue ; 15 €/mois rapproche de RWGPS sans sa bibliothèque mondiale |
| Q3 | Seuil du gratuit | 25 membres | 10 ferme la porte aux sections de clubs ; 50 couvre la moitié des clubs du rapport et ne laisse qu'une raison de payer, les intégrations |
| Q4 | Le push GPS en Club, ou gratuit ? | **Club** (coûte des quotas et des partenariats) | Gratuit : le seul droit différenciant devient la taille — plus simple à expliquer, moins de raisons de payer pour un petit club équipé |
| Q5 | Date de bascule | 1er avril 2027, tout le monde offert d'ici là | Plus tôt (1er janvier) laisse moins de temps aux AG ; plus tard rate la saison |
| Q6 | Équipes offertes pour toujours | Les équipes migrées de biketeam (`n-peloton`, `gaby`) et les clubs pilotes nommés | Tout faire payer y compris les pilotes : plus cohérent, mais ce sont eux qui ont testé |
| Q7 | Parcours B (facture, virement) dès le lancement ? | **Oui** — c'est le parcours naturel d'un trésorier | Carte/SEPA seulement : moins de travail (pas de formulaire d'adresse), mais perd les clubs sans carte au nom de l'association |
| Q8 | Contrat : `12.0.0` à l'activation des refus, ou mineure ? | `12.0.0` | Mineure + republication mobile simultanée (`API-42`) : moins de cérémonie, même effet |
| Q9 | Préfixe `BILL` | Oui, nouveau préfixe | Éclater sous `API`/`WEB`/`MOB`/`LEGAL`/`OPS` |
| Q10 | Statut juridique | Rester en EI, franchise de TVA tant que possible | Créer une société avant d'encaisser : coûts fixes, inutile à cette échelle |
| Q11 | Rétractation | 14 jours offerts à tous (F8) | Distinguer selon le client : plus juste, impossible à automatiser |

---

## 12. Délibérément dehors

| Sujet | Pourquoi |
|---|---|
| Prix par membre, quota de stockage ou de parcours | §3.4 |
| Abonnement individuel | §3.4 ; à rouvrir sur demande réelle |
| Achat dans l'app mobile (in-app purchase) | §6.2 : commission 15–30 %, deux catalogues à tenir, et l'unité facturée est l'équipe |
| Encaisser les cotisations du club | Rapport §6-I, `MEMBER_EXPORT` est le pont |
| Essai gratuit à l'inscription (14 jours de Club) | Remplacé par la période de lancement ; après avril 2027, à reconsidérer — Stripe `trial_period_days` suffit, aucun code |
| Facturation multi-devises, Stripe Tax | Clients français ; à rouvrir avec un premier club hors France |
| Marchand de référence (Paddle…) | §4.1 |
| Self-service de l'alias de domaine | Reste un acte d'admin plateforme (DNS, certificat Caddy) : un devis, pas un bouton |
| Dunning maison (nos propres relances) | Stripe le fait ; nous ne faisons que notifier les admins |
