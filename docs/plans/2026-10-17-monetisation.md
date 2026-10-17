# Monétiser pedalons.fr — modèle, paiement, abonnements

Écrit le 17 octobre 2026, réécrit le même jour pour **Qonto, en abonnement annuel seul** (la
première version reposait sur Stripe, voir §12). **État : proposition, rien n'est décidé ni
implémenté.** Ledger `BILL-1` (la décision et le socle), les suites sont numérotées au §10. Fait
suite à la lecture du rapport Ride with GPS
([`../research/2026-10-17-rwgps-state-of-the-cycling-club-2026.md`](../research/2026-10-17-rwgps-state-of-the-cycling-club-2026.md)),
dont le §7 parle de commercialisation sans dire comment facturer.

L'état de Pédalons décrit ici a été vérifié dans le code le 17 octobre 2026 (`develop`, contrat
`11.5.1`, migration `V71`). Les chemins Java sont relatifs à `backend/src/main/java/fr/pedalons/`.
Les faits sur l'API Qonto ont été lus dans sa documentation le même jour ; ils sont au §9 avec ce
qui est **supposé** et doit être vérifié dans le bac à sable Qonto avant la première ligne de code.

---

## Sommaire

1. [En une page](#1-en-une-page)
2. [Ce qui existe déjà](#2-ce-qui-existe-déjà)
3. [Le modèle de tarification](#3-le-modèle-de-tarification)
4. [Le paiement par Qonto](#4-le-paiement-par-qonto)
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

| Palier | Prix annuel (HT, à trancher §11) | Pour qui | Ce qui le distingue |
|---|---|---|---|
| **Peloton** (gratuit) | 0 € | Groupe d'amis, section naissante | Jusqu'à **25 membres**, tout le produit de base : sorties avec groupes, parcours GPX, posts, annonces, calendrier, notifications in-app et push |
| **Club** | **80 €/an** | Le club type du rapport (51–200 membres) | Membres **illimités**, planificateur de parcours, envoi vers Garmin/Karoo/Wahoo et envoi automatique, webhook Slack/Discord, résumé par e-mail, statistiques « actifs vs inscrits » (chantier D du rapport), export des membres |
| **Fédération** | sur devis, à partir de **300 €/an** | Comité départemental, organisateur d'événement, réseau de clubs | Un **site à son nom** (`DomainAlias`, déjà en place), plusieurs équipes gérées par la même personne, support prioritaire |

Pourquoi 25 : c'est le seuil du rapport sous lequel 61 % des clubs n'ajoutent personne en un an —
en dessous ce n'est pas un club qui a un budget, au-dessus il en a un. Pourquoi 80 €/an : moins
qu'une licence FFVélo, moins qu'un maillot ; au niveau d'un club, c'est **moins de 1 € par membre
et par an**, ce qui se dit en AG en une phrase.

**Annuel seul.** Une facture par club et par an, qui couvre une période de douze mois. Pas de
mensualité, pas de prélèvement récurrent : c'est le rythme des clubs (AG d'hiver, saison d'avril),
et c'est ce qui rend Qonto suffisant.

**Paiement par Qonto, le compte professionnel.** Pédalons émet la facture par l'API Qonto, qui la
numérote, la met en page, l'envoie par e-mail et la publie sur une page consultable sans compte.
Le club paie **par virement** sur l'IBAN imprimé (le cas normal d'une association) ou **par carte**
via un lien de paiement Qonto rattaché à la facture (Mollie derrière, phase 2, §4.4). Le paiement
est détecté par les webhooks Qonto ; un rapprochement quotidien rattrape ce qui leur échappe ; un
bouton « marquer payée » dans l'admin plateforme couvre le reste.

**Ce que Qonto ne fait pas et que nous écrivons** : le cycle de vie de l'abonnement — la date de
renouvellement, l'émission de la facture suivante, les relances, la période de grâce, la
résiliation. C'est l'essentiel du lot 2 (§10). Avec une facture par an et par club, ce moteur reste
petit : quelques dizaines de factures par an au début, un job quotidien.

**Suivi chez nous : deux tables (`team_subscriptions`, `billing_invoices`) et une seule fonction
qui dit ce que l'équipe a le droit de faire** (`TeamEntitlements`). Le reste du code ne connaît ni
Qonto ni les prix : il demande « cette équipe peut-elle ouvrir le planificateur ? » et obtient oui,
non, ou « oui, en période de grâce ». La bascule d'un palier à l'autre ne supprime jamais rien : un
club qui redescend en gratuit garde ses 300 membres et ses parcours, il ne peut plus *ajouter* de
membre et perd les intégrations.

**Lancement en trois temps** : (1) tout le monde en « Club » gratuitement jusqu'au **31 mars 2027**
(la saison se décide en hiver, les adhésions culminent en avril — rapport §3.6), (2) à partir de
janvier 2027, la page de tarifs et la souscription ouvertes, avec une première période qui court
du 1er avril 2027 au 31 mars 2028 quelle que soit la date de souscription, (3) au 1er avril 2027,
les équipes qui n'ont pas souscrit passent en « Peloton » avec leurs droits acquis. Les équipes
migrées de biketeam (`n-peloton`, `gaby`) et toute équipe que le propriétaire désigne sont
« offertes » sans limite de durée : un palier géré à la main depuis l'admin plateforme, pas un cas
spécial dans le code.

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
Il faut donc **ajouter** une notion de droit au DTO, pas la déduire des drapeaux existants (§5.6).

### 2.2 Ce qui s'inscrit naturellement dans un palier

| Capacité | Où elle vit | Palier proposé |
|---|---|---|
| Planificateur de parcours (routage Stadia Maps, API facturée à l'usage depuis `OPS-48` : plus de 17 Go de tuiles hébergées, mais chaque calcul compte) | `Team.enableRoutePlanner`, `Domain.enableGpxPlanner` | Club |
| Envoi vers Garmin/Karoo/Wahoo, envoi automatique (`API-120`, `GPS_SYNC_ENABLED`) | `GpsResource`, `service/gps/sync/` | Club (le lien de compte reste personnel ; c'est l'*équipe* qui ouvre la fonction à ses membres) |
| Webhook d'équipe Slack/Discord/Mattermost | `service/notification/TeamWebhookService` | Club |
| Résumé quotidien par e-mail (construit, coupé en prod depuis le 21 septembre 2026, `NOTIF-9`) | `NotificationScheduler` | Club — la réouverture que le rapport demande (§6-G) devient une raison de payer |
| Site à son nom | `domain/platform/DomainAlias`, `AdminDomainAliasService` | Fédération |
| Plusieurs équipes administrées par la même personne | `TeamService.MAX_ADMIN_TEAMS_PER_USER = 1` | Fédération (la limite devient un droit) |
| Taille de l'équipe | `UserTeam`, `TeamMembershipService.joinTeam`, `TeamInvitationService` | Peloton ≤ 25 ; au-delà, Club |
| Stockage (pièces jointes, images) | `Asset.fileSize` est renseigné et rattrapé par `AssetSizeBackfillScheduler` | Un quota est *calculable* dès aujourd'hui ; non recommandé comme levier (§3.4) |

Les patrons techniques à réutiliser pour le moteur d'abonnement :

- **Travail planifié idempotent** : `@Scheduled(…, concurrentExecution = SKIP)` et `Crons.ZONE`,
  comme `GpsRouteSyncPlanner` / `GpsRouteSyncWorker` (planificateur + exécutant, état en base).
- **Passerelle externe simulable** : `OpenMeteoGateway`, que les tests remplacent ; la passerelle
  Qonto suit le même modèle.
- **Évènement → notification** : le pipeline `NotificationEvent` / `NotificationScheduler` porte
  les relances aux admins d'équipe.

### 2.3 Ce qui n'existe pas

- Aucun code de paiement, aucun mot « abonnement » dans le backend hors des flux iCal et des
  notifications.
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
   nombreux et nommés (§5.4) ; une fonction absente du produit n'est pas « premium », elle n'existe
   pas.
3. **Redescendre ne détruit rien.** Perdre un palier bloque des *actions* (ajouter un membre,
   dessiner un parcours, envoyer vers un compteur), jamais des *données* ni de la lecture.
4. **Le prix se dit en une phrase en AG.** Par an, HT et TTC affichés, moins de 1 € par membre.
5. **Le gratuit est un vrai produit**, pas une démo : le groupe de 12 amis qui roule le dimanche
   doit pouvoir rester gratuit pour toujours. C'est aussi le bouche-à-oreille (42 % des arrivées
   dans le rapport) : chaque membre d'un club payant qui crée son petit groupe le fait gratuitement.
6. **Une facture par an, payable par virement.** Le trésorier reçoit un document qu'il peut
   présenter au bureau et régler depuis le compte de l'association, sans carte.

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

| Palier | Prix annuel HT | TTC si TVA à 20 % |
|---|---|---|
| Club | 80 € | 96 € |
| Fédération | à partir de 300 €, sur devis | à partir de 360 € |

Repères : RWGPS vend son compte club entre 199 et 599 $/an selon la taille (vérifié §9) ; un club
de 100 membres à 20 €/an de cotisation encaisse 2 000 €. 80 € est 4 % de ce budget. Les coûts
marginaux par club sont faibles (une base, Open-Meteo, et le routage Stadia Maps — facturé à
l'usage depuis `OPS-48`, donc le seul qui grandit avec les clubs qui planifient), le coût fixe
d'exploitation est l'instance Scaleway, le forfait Qonto et le temps du propriétaire : **la
première dizaine de clubs payants couvre l'hébergement, pas le travail**. Le prix sert d'abord à
qualifier (un club qui paie 80 € a une AG, un trésorier et des raisons de rester) et à financer
l'infrastructure, pas à vivre du produit — ce que le propriétaire doit dire explicitement au §11.

Un virement SEPA reçu sur Qonto ne coûte rien de plus que le forfait ; seul le paiement par carte
via un lien de paiement a des frais (Mollie, à lire dans le forfait, §9). Le virement est donc le
moyen mis en avant sur la facture, la carte une commodité.

### 3.4 Ce qu'on ne fait pas payer, et pourquoi

- **Pas de prix par membre.** Illisible pour un trésorier ; incite le club à ne pas inscrire ses
  membres — exactement l'inverse de ce que le produit veut (« la liste n'est pas le club »).
- **Pas de quota de stockage ni de parcours.** `n-peloton` a 2 696 parcours : un quota le
  pénaliserait, et le rapport montre que la taille de bibliothèque ne prédit rien. Les bornes de
  sécurité existantes (`GpxLimits`, 10 Mo par GPX, 100 Mo par requête) suffisent contre l'abus.
- **Pas d'abonnement individuel** (« Pédalons Premium » pour un cycliste) : l'anti-persona de la
  fiche produit est le cycliste solitaire. Si une demande réelle apparaît (envoi GPS pour un
  membre d'une équipe gratuite), elle sera réexaminée — pas avant.
- **Pas de mensualité.** Voir §12.
- **Pas de publicité, pas de vente de données.** Incompatible avec la politique de confidentialité
  telle qu'écrite et avec le positionnement.
- **Pas de gestion des cotisations du club** (encaisser les adhésions pour le compte du club).
  Déjà écarté par le rapport (§6-I) : en France, c'est le rôle des fédérations et de HelloAsso ;
  `MEMBER_EXPORT` est le pont.

---

## 4. Le paiement par Qonto

### 4.1 Ce que Qonto fournit, et ce qu'il ne fournit pas

| Besoin | Qonto | Chez nous |
|---|---|---|
| Fiche client (raison sociale, adresse, e-mail, SIRET/TVA) | `POST/PATCH /v2/clients` | L'identifiant Qonto du client et l'e-mail de facturation |
| Facture numérotée, mentions légales, PDF | `POST /v2/client_invoices` (numérotation automatique, `status: unpaid`, `due_date`, `performance_start_date`/`performance_end_date`, `purchase_order`, `footer`), PDF généré de façon asynchrone | La ligne `billing_invoices` et une copie du PDF |
| Envoi par e-mail | `POST /v2/client_invoices/{id}/send` (`send_to`, `email_title`, `email_body`) | Le texte du message |
| Page publique de la facture | `invoice_url`, consultable sans compte **180 jours** | Au-delà, le PDF copié chez nous (§5.3) |
| Paiement par virement | IBAN Qonto imprimé sur la facture (`payment_methods.iban`) | La référence à recopier dans le libellé |
| Paiement par carte | Lien de paiement de type facture (`POST /v2/payment_links` avec `invoice_id`), carte, Apple Pay, PayPal ; via une connexion Mollie ; **OAuth obligatoire** | Phase 2 (§4.4) |
| Savoir qu'une facture est payée | Webhooks `v1/client-invoices` (statut, `paid_at`), `v1/transactions` (crédits), `v1/payment-links` | Le rapprochement (§5.5) |
| Marquer payée, annuler | `mark_as_paid`, `unmark_as_paid`, `mark_as_canceled`, avoirs | Les appels, depuis le moteur ou l'admin plateforme |
| Facture électronique | `POST /v2/client_invoices/{id}/send_einvoice` | Rien tant que l'obligation ne nous vise pas (§7.1) |
| Renouvellement, relances, grâce, résiliation | **Non** | **Tout** (§5) |
| Portail client (changer d'adresse, télécharger ses factures, résilier) | **Non** | L'onglet « Abonnement » (§6.1) |
| Codes promotionnels | `discount` par facture | Une remise posée sur l'abonnement par l'admin plateforme, reprise à l'émission |

Les liens de paiement « récurrents » que décrit le support Qonto (débit automatique à chaque cycle)
ne sont pas exposés par l'API d'après la documentation lue le 17 octobre 2026 ; ils ne servent pas
ici, l'annuel se renouvelant par une nouvelle facture.

### 4.2 Le parcours de souscription

1. L'admin d'équipe ouvre « Abonnement » dans les paramètres de l'équipe, choisit **Club** et
   remplit un formulaire : raison sociale du club, adresse, e-mail de facturation (le trésorier,
   pas forcément un membre), SIRET ou numéro RNA facultatif, numéro de TVA facultatif.
2. `POST /api/teams/{slug}/billing/subscribe` (admin d'équipe, `@CheckAccess(TEAM, UPDATE)`) :
   - crée ou met à jour le client Qonto ;
   - crée la facture : une ligne « Pédalons — palier Club, équipe <nom>, du <début> au <fin> »,
     `performance_start_date` / `performance_end_date` = la période, `due_date` = émission + 30 jours,
     `purchase_order` = **la référence de virement** `PDL-<code>` (8 caractères dérivés de l'id
     d'équipe et de la période, sans ambiguïté O/0), le pied de facture avec la mention de TVA
     (§7.1) et « Indiquez la référence PDL-… dans le libellé de votre virement » ;
   - l'envoie à l'e-mail de facturation, en copie aux admins de l'équipe ;
   - ouvre les droits **tout de suite**, en `PENDING` : on ne fait pas attendre un club 30 jours
     pour un virement d'association.
3. Le trésorier paie par virement (ou par carte en phase 2). Le moteur détecte le paiement (§5.5),
   passe l'abonnement en `ACTIVE`, et notifie les admins : « Merci, votre abonnement Club est actif
   jusqu'au 31 mars 2028 ».

La **première période** commence à la souscription, sauf pendant le lancement où elle commence au
1er avril 2027 (§1) ; elle dure douze mois. Les suivantes s'enchaînent sans trou : la période N+1
commence le lendemain de la fin de la période N, même si la facture a été payée en retard.

### 4.3 Le renouvellement

- **J-45** avant la fin de période : le moteur émet la facture de la période suivante, avec les
  coordonnées de facturation à jour, et l'envoie. L'abonnement reste `ACTIVE`.
- **J-15** si elle est impayée : relance par e-mail Qonto (renvoi de la facture) et notification
  aux admins.
- **Fin de période** si elle est impayée : `PAST_DUE`, droits maintenus pendant la **grâce de
  30 jours** (le rythme des bureaux d'association), notification aux admins.
- **Fin de grâce** si elle est toujours impayée : `CANCELED`, l'équipe repasse en Peloton ; la
  facture impayée est annulée par un avoir (§7.1). Un paiement reçu après coup réactive
  l'abonnement sur la période facturée.

Pour ne pas renouveler, l'admin d'équipe clique « Ne pas renouveler » à tout moment : les droits
courent jusqu'à la fin de la période payée et aucune facture suivante n'est émise. Si la facture
suivante a déjà été émise et n'est pas payée, elle est annulée par un avoir. Le bouton
« Reprendre le renouvellement » défait l'opération tant que la période n'est pas finie.

### 4.4 La carte, en phase 2

Le lien de paiement Qonto rattaché à une facture ouvre la carte, Apple Pay et PayPal. Il demande
une connexion Mollie depuis Qonto, faite une fois par le propriétaire, et **un jeton OAuth** :
l'endpoint `POST /v2/payment_links` n'accepte pas la clé d'API qui suffit aux factures. Il faut
donc enregistrer une application OAuth chez Qonto, faire le consentement une fois, et garder le
jeton de rafraîchissement en secret. C'est du travail et un sous-traitant de plus (Mollie) pour
un moyen de paiement secondaire : **le lancement se fait au virement seul**, la carte s'ajoute si
des clubs la demandent. Quand elle existe, le lien est créé à l'émission de la facture et cité
dans l'e-mail et l'onglet « Abonnement ».

### 4.5 Passer d'un palier à l'autre

- **Peloton → Club** : la souscription du §4.2.
- **Club → Fédération** : sur devis, posé par l'admin plateforme (palier, prix, remise) ; la
  facture de complément au prorata est émise par le même moteur à la demande de l'admin
  plateforme, la période ne change pas.
- **Fédération → Club, ou Club → Peloton** : à la fin de la période, par « Ne pas renouveler » ou
  par le choix du palier sur la facture suivante.

Aucun changement de palier en cours de période n'est en self-service : à cette échelle, c'est un
e-mail au support.

---

## 5. Le suivi des abonnements — backend

### 5.1 Le modèle

Trois tables : l'abonnement par équipe, ses factures, le journal des webhooks Qonto.

```sql
-- V72__billing.sql (nom indicatif)
create table team_subscriptions (
  id                     bigint primary key,
  team_id                bigint not null unique references teams(id),
  plan                   varchar(20)  not null,          -- PELOTON | CLUB | FEDERATION
  status                 varchar(20)  not null,          -- §5.2
  source                 varchar(20)  not null,          -- QONTO | MANUAL
  current_period_start   date,
  current_period_end     date,                           -- dernier jour couvert, inclus
  grace_until            date,
  renews                 boolean not null default true,  -- « Ne pas renouveler »
  annual_price_cents     integer,                        -- prix HT de la période suivante (devis Fédération, remise)
  discount_percent       integer,                        -- remise de la prochaine facture
  qonto_client_id        uuid,
  billing_email          varchar(250),
  manual_note            varchar(500),                   -- « offert : club pilote »
  created_at             timestamptz not null,
  updated_at             timestamptz not null,
  version                bigint not null
);

create table billing_invoices (
  id                 bigint primary key,
  team_id            bigint not null references teams(id),
  qonto_invoice_id   uuid not null unique,
  number             varchar(40)  not null,              -- numéro Qonto
  reference          varchar(20)  not null unique,       -- PDL-… à recopier dans le virement
  plan               varchar(20)  not null,
  period_start       date not null,
  period_end         date not null,
  amount_cents       integer not null,                   -- TTC
  status             varchar(20)  not null,              -- UNPAID | PAID | CANCELED
  issued_at          timestamptz not null,
  due_date           date not null,
  paid_at            timestamptz,
  pdf_asset_id       bigint,                             -- copie du PDF dans MinIO
  payment_link_url   varchar(500),                       -- phase 2
  unique (team_id, period_start)                         -- une facture par période : l'idempotence du renouvellement
);

create table billing_events (
  id            varchar(64) primary key,                 -- id de l'enveloppe Qonto : idempotence
  type          varchar(50)  not null,                   -- v1/client-invoices, v1/transactions…
  payload       jsonb not null,
  received_at   timestamptz not null,
  processed_at  timestamptz,
  attempts      integer not null default 0,
  error         varchar(2000)
);
```

- **Une ligne d'abonnement par équipe, créée à la demande** : une équipe sans ligne est en
  `PELOTON` / `ACTIVE` (pas de rattrapage de données ; `TeamEntitlements` traite l'absence comme le
  gratuit).
- `source = MANUAL` est le palier « offert » : posé par l'admin plateforme, aucune facture, jamais
  touché par le moteur ni un webhook.
- La contrainte `unique (team_id, period_start)` est ce qui rend l'émission sûre pendant un
  déploiement à chaud : deux backends qui tentent d'émettre la même facture ne peuvent en inscrire
  qu'une. L'ordre est donc **inscrire la ligne d'abord** (statut `ISSUING`), appeler Qonto ensuite,
  compléter la ligne enfin ; une ligne `ISSUING` vieille de plus d'une heure est rapprochée en
  cherchant la facture chez Qonto par `purchase_order` avant toute nouvelle tentative (§5.3).
- **Les coordonnées de facturation** (raison sociale, adresse) vivent chez Qonto, dans la fiche
  client. Nous ne gardons que l'e-mail de facturation, nécessaire à l'envoi.
- Pas de `deleted` : les lignes suivent l'équipe (soft delete de `Team`). Les factures ne se
  suppriment jamais (obligation comptable, §7.3).

### 5.2 Les états et leurs transitions

| `status` | Sens | Droits du palier |
|---|---|---|
| `ACTIVE` | Période en cours payée, ou offerte | Ouverts |
| `PENDING` | Première facture émise, pas encore payée | Ouverts jusqu'à `due_date` + 30 jours, puis `CANCELED` |
| `PAST_DUE` | La période payée est finie, la facture de la suivante est impayée | Ouverts jusqu'à `grace_until` (= fin de période + 30 jours), puis `CANCELED` |
| `CANCELED` | Non renouvelé, ou impayé après la grâce | Fermés : l'équipe est traitée comme `PELOTON` |

Toutes les transitions sauf le paiement viennent **du temps**, donc d'un job : la règle est écrite
une fois, dans une fonction pure `SubscriptionClock.next(state, today, invoices)` que les tests
parcourent jour par jour, et appliquée par le job quotidien du §5.3. Le paiement vient du
rapprochement (§5.5) et fait passer `PENDING` ou `PAST_DUE` à `ACTIVE`, en avançant la période si
la facture payée est celle de la période suivante.

**Le cas « on redescend »** (`CANCELED`) ne modifie aucune autre table : les 300 membres restent,
les parcours dessinés restent, le webhook configuré reste en base mais n'est plus appelé, les
envois automatiques GPS en attente sont annulés par le planificateur existant
(`GpsRouteSyncPlanner`) qui vérifiera le droit comme il vérifie déjà `enabled`.

### 5.3 Le moteur : un job quotidien et un exécutant

- **`SubscriptionScheduler`** (`@Scheduled(cron = "0 20 4 * * ?", timeZone = Crons.ZONE)`) :
  pour chaque abonnement `source = QONTO`, applique `SubscriptionClock` et inscrit le travail à
  faire — émettre la facture de J-45, relancer à J-15, passer en `PAST_DUE`, en `CANCELED`,
  annuler une facture par avoir. Il **décide**, il n'appelle pas Qonto. Idempotent : il relit
  l'état et les factures, et ne fait qu'avancer vers l'état que la date impose.
- **`BillingWorker`** (`@Scheduled(every = "30s", concurrentExecution = SKIP)`) : exécute les
  appels Qonto inscrits (émettre, envoyer, relancer, annuler, télécharger le PDF), avec
  `attempts` et un délai croissant, comme `GpsRouteSyncWorker`. Il traite aussi la file
  `billing_events` (§5.5).
- **Le PDF** est généré par Qonto de façon asynchrone : le worker le télécharge (`attachment_id`
  puis `GET /v2/attachments/{id}`) dès qu'il est prêt et le range dans MinIO comme un `Asset`
  privé. C'est ce qui permet de servir la facture après les 180 jours de `invoice_url`.
- **La période de lancement** est une ligne `MANUAL` par équipe existante, `current_period_end =
  2027-03-31`, posée par une migration ; le job la fait expirer comme une autre (une ligne
  `MANUAL` avec une date de fin redevient `PELOTON` à cette date — c'est la seule transition que
  le job applique aux lignes `MANUAL`).

### 5.4 `TeamEntitlements` : la seule porte

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
| Dessiner / modifier un tracé | `RouteResource` (planificateur), `/api/router` (Stadia Maps, facturé à l'usage) | `403 PLAN_REQUIRED` avec `entitlement: ROUTE_PLANNER` |
| Envoyer vers un service GPS, activer l'envoi automatique | `GpsResource.uploadRoute`, `GpsRouteSyncPlanner` (filtre SQL sur les équipes titulaires, **par page, pas par ligne**) | `403 PLAN_REQUIRED` |
| Configurer / déclencher le webhook d'équipe | `TeamWebhookService` | `403 PLAN_REQUIRED` ; en livraison, une équipe sans droit est sautée silencieusement |
| Résumé e-mail | `NotificationScheduler` (job quotidien) | filtre par équipe, par page |
| Créer une 2ᵉ équipe administrée | `TeamService.createTeam` (`MAX_ADMIN_TEAMS_PER_USER` devient `adminTeamsLimit`) | `USER_TEAM_LIMIT_REACHED` (existant) |
| Alias de domaine | `AdminDomainAliasService` : reste admin plateforme ; le droit `CUSTOM_HOSTNAME` sert à l'affichage et au devis, pas à un self-service | — |

`PLAN_REQUIRED` porte dans `ErrorResponse.details` le droit manquant et le palier qui l'ouvre : le
client affiche « Disponible avec le palier Club » et, si l'utilisateur est admin de l'équipe, un
lien vers l'onglet « Abonnement » ; sinon « Demandez à un administrateur de l'équipe ».

**Invariant de coût** : aucune résolution par ligne dans une liste. Une page de sorties ne
demande pas 20 fois les droits ; le fil ne les demande pas du tout. Un `BillingQueryCountTest` sur
`GpsRouteSyncPlanner` et le job de résumé garde cela, comme les `…QueryCountTest` existants.

### 5.5 Savoir qu'une facture est payée : le rapprochement

Trois sources, de la plus directe à la plus lente, qui aboutissent toutes à la même opération
idempotente `BillingInvoiceService.markPaid(invoice, paidAt, source)` :

1. **Webhook `v1/client-invoices`** : Qonto signale que la facture est passée `paid` (quand il
   l'a rapprochée lui-même d'un virement, ou qu'on l'a marquée payée dans l'app Qonto). Facture
   retrouvée par `qonto_invoice_id`.
2. **Webhook `v1/transactions`** : un crédit (`side: credit`, `status: completed`) arrive sur le
   compte. On cherche la référence `PDL-…` dans `reference`, `label` et `note` ; si elle désigne
   une facture `UNPAID` **et** que le montant est égal, on la marque payée chez nous **et** chez
   Qonto (`mark_as_paid`), ce qui la rapproche aussi dans la comptabilité. Montant différent ou
   référence absente : rien d'automatique, une alerte « virement à rapprocher » dans l'admin
   plateforme, avec le libellé et le montant.
3. **Rapprochement quotidien** : le job du §5.3 relit chez Qonto toute facture `UNPAID` dont
   l'échéance approche ou est passée (`GET /v2/client_invoices/{id}`), pour rattraper un webhook
   perdu.

Et en dernier recours, **« Marquer payée »** dans l'admin plateforme, pour un chèque ou un
virement sans référence ; l'action passe aussi par `mark_as_paid` chez Qonto.

**Le webhook lui-même** — `POST /api/billing/qonto/webhook`, `@Public`, hors `@RolesAllowed`,
**exempté par chemin** du filtre CSRF (`CrossSiteRequestFilter`) et de la résolution de domaine
(`DomainResolver`) :

1. Lire le corps brut, vérifier `X-Qonto-Signature` (`t=…,v1=…`, HMAC-SHA256 de `t.corps` avec
   `QONTO_WEBHOOK_SECRET`, comparaison en temps constant, horodatage à moins de 5 minutes). Échec →
   `400`, journalisé en `WARN` sans le corps.
2. `insert into billing_events … on conflict do nothing`, puis répondre `200`. **Rien d'autre
   dans la requête** : Qonto attend l'acquittement **au plus une seconde** et réessaie sinon,
   pendant plusieurs jours.
3. Le `BillingWorker` traite la file : il relit l'objet chez Qonto (la facture, la transaction)
   plutôt que de faire confiance au contenu de l'évènement, pour que l'ordre d'arrivée et les
   doublons ne comptent pas.

Les transactions qui n'ont rien à voir avec Pédalons (tout le compte Qonto passe par ce webhook)
sont écartées au traitement et purgées de `billing_events` après 30 jours ; seuls les crédits sont
gardés le temps du rapprochement.

### 5.6 Le contrat d'API

Nouveaux objets, nouveaux endpoints, un champ ajouté :

```yaml
TeamDetailDto:
  plan:          { $ref: Plan }                      # PELOTON | CLUB | FEDERATION — tout lecteur
  entitlements:  { type: array, items: Entitlement } # ce que l'équipe peut faire — tout lecteur
  memberLimit:   { type: integer, nullable: true }   # null = illimité
  billing:       { $ref: TeamBillingDto, nullable: true }  # admins d'équipe seulement, sinon null

TeamBillingDto:
  status:              SubscriptionStatus
  source:              QONTO | MANUAL
  currentPeriodStart:  LocalDate?
  currentPeriodEnd:    LocalDate?
  graceUntil:          LocalDate?
  renews:              boolean
  billingEmail:        string?
  invoices:            BillingInvoiceDto[]           # les plus récentes d'abord

BillingInvoiceDto:
  id, number, reference, plan, periodStart, periodEnd, amount, status, issuedAt, dueDate, paidAt,
  pdfUrl          # notre copie, servie aux admins de l'équipe
  invoiceUrl?     # la page Qonto, tant qu'elle vit
  paymentLinkUrl? # phase 2
  iban            # l'IBAN où virer, rappelé à l'écran

POST /api/teams/{slug}/billing/subscribe        { plan, legalName, address, billingEmail, siret?, vatNumber? } → TeamBillingDto
PUT  /api/teams/{slug}/billing/details          { legalName, address, billingEmail, siret?, vatNumber? }      → TeamBillingDto
POST /api/teams/{slug}/billing/stop-renewal     → TeamBillingDto
POST /api/teams/{slug}/billing/resume-renewal   → TeamBillingDto
GET  /api/teams/{slug}/billing/invoices/{id}/pdf → application/pdf
GET  /api/billing/plans                          → catalogue (paliers, droits, prix HT/TTC) — public, sans session, mis en cache
POST /api/billing/qonto/webhook                  → 200 (hors contrat client : documenté mais exclu de la génération)

PATCH /api/admin/teams/{id}/subscription         { plan, source, until?, annualPriceCents?, discountPercent?, note? }
GET   /api/admin/billing/invoices?status=        → factures, toutes équipes
POST  /api/admin/billing/invoices/{id}/mark-paid { paidAt, note }
POST  /api/admin/billing/invoices/{id}/reissue   → renvoie la facture par e-mail
GET   /api/admin/billing/unmatched-credits       → virements reçus sans facture reconnue
```

`AppConfigDto` gagne `billingEnabled: boolean` (`BILLING_ENABLED`, défaut `false` : sans clés
Qonto, la page de tarifs ne montre aucun bouton de souscription et tout le monde est en « Club » —
c'est l'état de la phase 1 du lancement, §10).

**Majeure ou mineure ?** Les champs ajoutés sont des ajouts (mineure, `11.6.0`). Ce qui est une
rupture, c'est le **comportement** : des actions qui réussissaient répondent `403 PLAN_REQUIRED`
ou `409 PLAN_MEMBER_LIMIT_REACHED`. Un mobile ancien afficherait une erreur générique. Comme le
mobile est hors stores et republié avec le backend (`API-42`), on peut rester en mineure pour le
contrat et traiter la rupture par la republication — **à trancher au §11**. Le plan propose
`11.6.0` pour l'ajout des champs (phase 1, inerte) et `12.0.0` pour l'activation des refus
(phase 3).

### 5.7 Admin plateforme

`AdminTeamDto` gagne `plan`, `subscriptionStatus`, `subscriptionSource`, `currentPeriodEnd` ;
`AdminTeamsPage` les affiche et offre « Offrir le palier … jusqu'au … » / « Retirer », et le prix
et la remise de la prochaine facture (devis Fédération, offre de parrainage). Une page « Factures »
liste les factures par statut, les virements à rapprocher, et porte « Marquer payée » et
« Renvoyer ».

Un tableau de bord minimal sur `AdminDashboardPage` : équipes par palier, abonnements en
`PAST_DUE`, factures impayées, échéances dans les 60 jours. Le chiffre d'affaires et la trésorerie
se lisent dans Qonto, pas chez nous.

### 5.8 Tests

- `SubscriptionClockTest` : la fonction pure parcourue jour par jour — souscription pendant le
  lancement, J-45, J-15, fin de période, grâce, paiement en retard qui réactive sans décaler la
  période, « Ne pas renouveler » avant et après l'émission, année bissextile.
- `TeamEntitlementsResolverTest` : les trois sources combinées, la grâce, l'absence de ligne, le
  `MANUAL` qui prime et qui expire, le drapeau de gouvernance qui accorde.
- `QontoWebhookResourceTest` : signature invalide ou horodatage trop vieux → 400 ; évènement rejoué
  → 200 sans second effet ; la réponse ne dépend d'aucun appel sortant.
- `BillingReconciliationTest` : virement avec la référence et le bon montant → payée ici et chez
  Qonto ; mauvais montant ou sans référence → virement à rapprocher, rien de payé ; facture déjà
  payée → rien ; débit → ignoré.
- `BillingIssuanceTest` : deux émissions concurrentes de la même période → une seule facture
  (`unique (team_id, period_start)`) ; ligne `ISSUING` orpheline retrouvée par `purchase_order`.
- `BillingLimitsResourceTest` : 26ᵉ membre refusé en `PELOTON`, accepté en `CLUB` ; invitation
  comptée ; planificateur et envoi GPS refusés avec `PLAN_REQUIRED` ; une équipe migrée garde
  `enableRoutePlanner`.
- `BillingQueryCountTest` : le planificateur GPS et le résumé ne coûtent pas une requête par
  équipe.
- La passerelle Qonto est **simulée** par une interface `QontoGateway`, comme `OpenMeteoGateway` ;
  aucun test automatisé ne parle à Qonto. Le parcours réel se recette à la main dans le **bac à
  sable Qonto** depuis staging (§8).
- e2e Playwright : la page de tarifs, l'onglet « Abonnement » (souscription contre le bac à sable
  simulé, factures affichées), le bandeau de grâce, le refus du 26ᵉ membre.

---

## 6. Les clients — web, mobile, Karoo, Garmin

### 6.1 Web

- **Page de tarifs publique** `/tarifs` (`contracts/routes.yaml`, puis `pnpm generate-routes`), en
  SSR : trois colonnes, prix annuel HT et TTC, FAQ (« qui paie ? », « comment payer ? — par
  virement sur facture », « que se passe-t-il si on arrête ? », « puis-je avoir un devis pour le
  bureau ? »), lien vers la vitrine. Mêmes données que `GET /api/billing/plans`.
- **L'onglet « Abonnement »** des paramètres d'équipe (admin), qui remplace le portail client :
  - palier, état, période couverte, date du prochain renouvellement ou « Non renouvelé » ;
  - souscription (le formulaire du §4.2) ;
  - les factures, avec numéro, période, montant, statut, PDF ; pour une facture impayée,
    **l'IBAN et la référence à recopier**, en gros, avec un bouton « copier » ;
  - « Modifier les coordonnées de facturation », « Ne pas renouveler » / « Reprendre » ;
  - pendant `PENDING` ou la grâce, un bandeau « Facture en attente de règlement, droits maintenus
    jusqu'au … ».
- **Un devis** : pour qu'un trésorier fasse voter la dépense, un bouton « Télécharger un devis »
  sur la page de tarifs et dans l'onglet produit un PDF simple au nom de l'équipe (nous le
  générons, ou devis Qonto `client_quotes` si l'API le permet, §9). À trancher au §11.
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
  de souscription.

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

### 7.1 Le vendeur et la facture

Le responsable du traitement est **LANDAIS Gabriel, entreprise individuelle** (politique §12) :
une EI peut facturer, et le compte Qonto doit être celui de l'EI. Points à régler avec
l'expert-comptable **avant** la première facture (§11) :

- **TVA** : une EI sous le seuil de franchise en base facture « TVA non applicable, art. 293 B du
  CGI » — mention portée par le pied de facture Qonto et un taux de TVA nul sur la ligne (vérifier
  le motif d'exonération que l'API attend pour la France, §9) ; au-delà, 20 %. Le seuil et son
  éventuelle réforme sont à vérifier à la date du lancement (§9). Les prix sont affichés **HT et
  TTC** dans tous les cas pour que le passage à la TVA ne change pas la grille.
- **Mentions de facture** : nom, adresse, SIREN, numéro séquentiel (Qonto numérote), date de
  prestation (`performance_start_date` / `performance_end_date` = la période), mention de franchise
  ou TVA, adresse du client, conditions de paiement, pénalités de retard et indemnité forfaitaire de
  40 € (obligatoires entre professionnels ; Qonto les porte, à vérifier dans les réglages).
- **Annuler une facture** : une facture émise ne se supprime pas ; elle s'annule par un **avoir**.
  Vérifier que `mark_as_canceled` chez Qonto produit un avoir conforme, sinon créer l'avoir par
  l'API des avoirs (§9).
- **Facturation électronique** : la réforme française impose de pouvoir *recevoir* des factures
  électroniques dès septembre 2026 et, pour les micro-entreprises, d'en *émettre* à partir de
  septembre 2027 entre assujettis. Une association non assujettie à la TVA relève plutôt de
  l'*e-reporting*. Qonto expose l'envoi en facture électronique : le moment venu, c'est un appel
  de plus au worker, pas une refonte. À confirmer avec l'expert-comptable (§9).
- **Déclaration** : le chiffre d'affaires Qonto entre dans les déclarations de l'EI ; la
  comptabilité se tient dans Qonto, factures et encaissements y sont déjà rapprochés.

### 7.2 Les CGU

Les CGU actuelles ne parlent ni de prix ni de durée. À ajouter, en un article « Abonnements »
(`LEGAL`) : les paliers et leurs limites, la durée (**un an**, renouvelé par l'émission d'une
nouvelle facture 45 jours avant l'échéance, que le club peut refuser à tout moment par « Ne pas
renouveler »), le paiement à 30 jours par virement, ce qui se passe à l'échéance impayée (30 jours
de grâce puis retour au gratuit, rien n'est supprimé), le prix et sa révision (préavis par e-mail
aux admins avant l'émission de la facture de renouvellement), le droit de rétractation (§9, F8 :
14 jours offerts à tous), et le fait que l'abonnement est souscrit par un admin **au nom de
l'équipe**.

### 7.3 La politique de confidentialité

- **Nouveau sous-traitant : Qonto** (Olinda SAS, France) pour la facturation et l'encaissement :
  données concernées, la raison sociale, l'adresse et l'e-mail de facturation du club, le nom et
  l'e-mail de l'admin qui souscrit (copie des envois), le montant et la date des paiements, le nom
  du titulaire du compte qui vire. Pas de transfert hors de l'Union européenne déclaré par Qonto :
  à vérifier dans son accord de sous-traitance (§9).
- **Phase 2** : **Mollie** (Mollie B.V., Pays-Bas) pour les paiements par carte, qui reçoit les
  données de carte directement — jamais nous.
- **Nouvelle finalité** : gestion des abonnements et facturation ; base légale : exécution du
  contrat et obligation légale (comptable) ; conservation : factures et pièces **10 ans**
  (art. L123-22 du Code de commerce), y compris nos copies PDF ; e-mail de facturation tant que
  l'abonnement existe, puis avec les factures.
- **Effacement de compte** : l'admin qui a souscrit peut supprimer son compte ; l'abonnement reste
  à l'équipe, les factures déjà émises gardent son nom si elles le portent (obligation comptable),
  l'e-mail de facturation est celui du trésorier, modifiable par tout autre admin. À écrire dans la
  politique §7.
- Le relevé des équipes par palier et des factures dans l'admin plateforme est couvert par la
  mention « administration de la plateforme » existante.

### 7.4 Ce que le rapport et `WEB-91` imposent

`MEMBER_STATS` (actifs vs inscrits) est un droit **Club**, mais c'est aussi un traitement nouveau :
la base légale (intérêt légitime de l'association pour gérer son activité) et la mention dans la
politique sont à écrire **avant** de l'ouvrir, en même temps que le chantier D du rapport. Ne pas
vendre ce droit avant qu'il existe : la page de tarifs ne liste que ce qui est livré.

---

## 8. Exploitation

- **Secrets** : `QONTO_API_LOGIN` et `QONTO_API_SECRET_KEY` (clé d'API de l'organisation, en-tête
  `Authorization: login:secret`), `QONTO_WEBHOOK_SECRET`, `QONTO_IBAN` (le compte imprimé sur les
  factures), `QONTO_BASE_URL`, `BILLING_ENABLED` ; en phase 2, `QONTO_OAUTH_CLIENT_ID`,
  `QONTO_OAUTH_CLIENT_SECRET` et le jeton de rafraîchissement. Dans `.env` de prod et de staging
  seulement.
- **Un environnement qui n'est pas la prod ne doit pas pouvoir facturer**, pour la même raison
  qu'il ne doit pas pouvoir envoyer de mail (CLAUDE.md) : une facture envoyée à un vrai trésorier
  depuis staging est un document comptable émis. Staging parle au **bac à sable Qonto**
  (`thirdparty-sandbox.staging.qonto.co`, en-tête `X-Qonto-Staging-Token`) ; `.env.e2e` et un `.env`
  de workstation n'ont **aucune** clé Qonto et `BILLING_ENABLED=false`. Le backend refuse de
  démarrer avec `BILLING_ENABLED=true` si `ENV_NAME` n'est pas la prod et que `QONTO_BASE_URL` n'est
  pas le bac à sable ; la CI e2e échoue si une clé Qonto apparaît dans `.env.e2e`, comme elle
  échoue déjà si le mailer ne pointe pas sur mailpit.
- **Webhook** : un abonnement par type (`v1/client-invoices`, `v1/transactions`, plus tard
  `v1/payment-links`) créé par `POST /v2/webhook_subscriptions` vers
  `https://www.pedalons.fr/api/billing/qonto/webhook`, par un script idempotent
  `scripts/qonto-webhooks.sh` (bac à sable puis prod). L'URL passe par Caddy → traefik → backend
  comme le reste. Pendant un déploiement à chaud, les deux backends peuvent recevoir le même
  évènement : la table `billing_events` règle le cas.
- **Réglages Qonto** faits une fois dans l'app et décrits dans le runbook : numérotation
  automatique, mentions légales de l'EI, pénalités de retard, modèle d'e-mail, logo.
- **Monitoring** : compteurs Micrometer `pedalons_billing_webhook_total{type,result}`,
  `pedalons_billing_invoices{status}` ; alertes Grafana si `billing_events` a des lignes en erreur,
  si aucun évènement n'arrive pendant 7 jours alors que des factures sont impayées, ou si un
  virement attend d'être rapproché depuis plus de 3 jours.
- **Runbook** (`OPERATIONS.md`, section « Billing ») : créer les abonnements de webhook, faire
  tourner le secret, « un club dit avoir payé et n'a pas ses droits » (chercher le virement dans
  Qonto, « Marquer payée » ou rapprocher), rembourser (virement sortant depuis Qonto et avoir),
  poser un palier offert, émettre un devis Fédération.
- **Sauvegardes** : les trois tables sont dans la base, donc dans `scripts/backup.sh`, et les PDF
  dans MinIO avec les autres assets ; une restauration ancienne se corrige par le rapprochement
  quotidien (Qonto fait foi pour le statut des factures).
- **Open-Meteo** : devenir payant tranche la question de `OPS-29` — l'offre gratuite est réservée
  à un usage non commercial. **Avant d'encaisser le premier euro**, passer au plan payant
  (`OPEN_METEO_URL` + `OPEN_METEO_API_KEY`, aucun changement de code) ; à vérifier aussi pour
  les tuiles VersaTiles (`pedalons.map.styles`) dont les conditions d'usage peuvent exclure le
  commercial (§9). Le géocodage ne pose plus la question : il est passé de Nominatim à Stadia Maps
  le 17 octobre 2026 (`OPS-49`), sur la même clé et le même plan payant que le routage.

---

## 9. Faits externes, hypothèses à vérifier

| # | Fait | Source | Confiance |
|---|---|---|---|
| F1 | Factures clients par API : `POST /v2/client_invoices` (client, dates, `items`, `payment_methods.iban` d'un compte Qonto, `status` `draft`/`unpaid`, numérotation automatique, `purchase_order` ≤ 40 car., `performance_start_date`/`performance_end_date`, `footer`, `discount`), statuts `draft`/`unpaid`/`paid`/`canceled`, `invoice_url` public 180 jours, PDF asynchrone (`attachment_id`) ; envoi par e-mail ; `mark_as_paid`, `unmark_as_paid`, `mark_as_canceled` ; clé d'API acceptée, tous forfaits | [docs.qonto.com, client invoices](https://docs.qonto.com/api-reference/business-api/expense-management/client-quotes-notes/client-invoices/create-a-client-invoice.md) | Élevée ; **vérifier en bac à sable** que la clé d'API (et pas seulement OAuth) suffit à créer, envoyer et marquer, et le motif d'exonération de TVA attendu pour la France |
| F2 | Webhooks : signature `X-Qonto-Signature: t=…,v1=…` (HMAC-SHA256 de `t.corps`), acquittement en **1 seconde** au plus, nouvelles tentatives à délai croissant pendant quelques jours, doublons possibles ; enveloppe avec un `id` ; types `v1/client-invoices`, `v1/transactions` (`side`, `status`, `amount`, `reference`, `label`, `note`), `v1/payment-links` | [docs.qonto.com, webhooks setup](https://docs.qonto.com/api-reference/business-api/webhooks/setup.md), [transactions](https://docs.qonto.com/api-reference/business-api/webhooks/supported-webhooks/v1-transactions.md), [client invoices](https://docs.qonto.com/api-reference/business-api/webhooks/supported-webhooks/v1-client-invoices.md) | Élevée sur la forme ; **vérifier** l'authentification exigée pour créer un abonnement de webhook (clé d'API ou OAuth) et la liste complète des statuts |
| F3 | Qonto rapproche-t-il lui-même un virement entrant d'une facture client (et passe-t-il la facture `paid`, ce qui déclenche le webhook) ? | Non documenté dans les pages lues | **Inconnu** — le plan ne compte pas dessus (§5.5, source 2) |
| F4 | Liens de paiement de type facture : `POST /v2/payment_links` (`invoice_id`, `invoice_number`, `debitor_name`, `amount`), carte, Apple Pay, PayPal, iDEAL — **pas de virement** ; connexion Mollie préalable, une seule par utilisateur Qonto ; **OAuth obligatoire** (`payment_link.write`) | [docs.qonto.com, payment links](https://docs.qonto.com/api-reference/business-api/payments-transfers/payment-links/create.md) | Élevée ; **frais Mollie non trouvés**, à lire dans le forfait |
| F5 | Liens de paiement récurrents : décrits par le support Qonto (France, Allemagne, Pays-Bas, owners et admins), pas exposés par l'API d'après la documentation lue | [Support Qonto](https://support-fr.qonto.com/hc/en-us/articles/43017462111505-How-do-I-create-and-manage-recurring-payment-links) | Moyenne — sans objet pour l'annuel |
| F6 | Devis (`client_quotes`) et avoirs (`credit_notes`) existent dans la même famille d'API que les factures | Index de la documentation Qonto | Moyenne — **vérifier** qu'un avoir se crée par l'API et que `mark_as_canceled` en produit un conforme |
| F7 | RWGPS « Club account » : de l'ordre de 199 à 599 $/an selon la taille du club | Page tarifs RWGPS | Moyenne — grille vue en 2026, à revoir |
| F8 | Droit de rétractation : non applicable entre professionnels, sauf l'exception de l'art. L221-3 C. conso. (≤ 5 salariés, contrat hors du champ de l'activité principale), qui peut viser un petit club | Code de la consommation | Moyenne — prévoir 14 jours de rétractation offerts à tous, plus simple que de distinguer |
| F9 | Franchise en base de TVA, prestations de services : seuil de l'ordre de 37 500 € (majoré 41 250 €) en 2025 ; la réforme à 25 000 € votée en loi de finances 2025 a été suspendue, puis rediscutée | BOFiP, loi de finances | **Faible sur la valeur 2027** — à vérifier avec l'expert-comptable |
| F10 | Facturation électronique : réception obligatoire pour toutes les entreprises en septembre 2026, émission pour les PME et micro-entreprises en septembre 2027 ; Qonto expose l'envoi en facture électronique | Calendrier DGFiP ; [docs.qonto.com, send e-invoice](https://docs.qonto.com/api-reference/business-api/expense-management/client-quotes-notes/client-invoices/send-a-client-invoice-by-e-invoice.md) | Moyenne — le traitement d'une association non assujettie est à confirmer |
| F11 | App Store 3.1.1 / 3.1.3(b) : un service multi-plateforme peut ouvrir dans l'app ce qui a été acheté ailleurs, sans lien ni incitation à acheter hors de l'app ; Play a une exception équivalente | App Store Review Guidelines, Google Play Payments policy | Moyenne — relire avant la soumission |
| F12 | Open-Meteo : gratuit « for non-commercial use », plan commercial payant par clé d'API | Conditions Open-Meteo, déjà citées par `OPS-29` | Élevée |
| F13 | VersaTiles (`tiles.versatiles.org`) : conditions d'usage à relire pour un service commercial (Nominatim ne compte plus : géocodage chez Stadia Maps depuis `OPS-49`) | Page de conditions du projet | Moyenne |

Rien ici n'envoie nos données de membres chez Qonto : seuls les coordonnées de facturation du
club, l'e-mail de facturation et celui de l'admin qui souscrit en sortent.

---

## 10. Découpage, ordre et tailles

Tailles : S = quelques jours, M = une à deux semaines, L = davantage. Chaque lot est livrable seul
et laisse le produit entier ; l'ordre suit le lancement (§1).

| Lot | Ledger | Contenu | Taille | Dépend de |
|---|---|---|---|---|
| **0. Décisions et vérifications** | `BILL-1` | Les choix du §11 tranchés ; expert-comptable consulté (TVA, mentions, avoir, facture électronique) ; accès au bac à sable Qonto ; F1, F2, F3 et F6 vérifiés en bac à sable | — | — |
| **1. Socle inerte** | `BILL-2` | `V72` (les trois tables), `TeamSubscription`, `TeamEntitlements` et son résolveur ; `plan` / `entitlements` / `memberLimit` dans `TeamDetailDto` (`11.6.0`) ; `AdminTeamDto` et `PATCH …/subscription` ; `BILLING_ENABLED=false` ; la migration de lancement qui pose « Club offert jusqu'au 31 mars 2027 » sur toute équipe existante. **Aucun refus actif.** | M | 0 |
| **2. Le moteur Qonto** | `BILL-3` | `QontoGateway`, souscription, `SubscriptionClock`, `SubscriptionScheduler`, `BillingWorker`, émission et envoi, copie des PDF, webhook et file `billing_events`, rapprochement, avoirs, notifications aux admins (`NOTIF`), pages admin plateforme, `GET /api/billing/plans` ; garde-fou « pas de facture hors prod » ; runbook et secrets ; recette en bac à sable sur staging | L | 1 |
| **3. Web** | `BILL-4` | Page `/tarifs` (routes.yaml), onglet « Abonnement », devis, `PlanRequiredNotice`, compteur de membres, vitrine ; e2e | M | 1 (affichage), 2 (souscription) |
| **4. Juridique** | `BILL-5` (`LEGAL`) | Article « Abonnements » des CGU, Qonto dans la politique, finalité et conservation, préavis de prix | S | 0 |
| **5. Activation des refus** | `BILL-6` | Les points de contrôle du §5.4 avec leurs codes d'erreur ; `12.0.0` ; `BillingLimitsResourceTest`, `BillingQueryCountTest` ; Open-Meteo payant, conditions VersaTiles relues | M | 1, 4 |
| **6. Mobile** | `BILL-7` (`MOB`) | Lecture des droits, actions cachées ou désactivées, rendu des deux erreurs ; republication avec 5 | S | 5 |
| **7. Bascule** | `BILL-8` | 1er avril 2027 : expiration des paliers offerts (le job quotidien suffit), tableau de bord admin, suivi des impayés | S | 2, 5 |
| **8. La carte** | `BILL-9` | Application OAuth Qonto, connexion Mollie, lien de paiement par facture, webhook `v1/payment-links`, Mollie dans la politique | M | 2 ; seulement si des clubs la demandent |
| **9. Ce qui se vend** | chantiers du rapport `D` (`MEMBER_STATS`), `G` (résumé e-mail) | Livrés comme des droits Club ; ne figurent sur la page de tarifs qu'une fois livrés | M chacun | 5 |

Calendrier visé : lots 1 à 4 avant fin décembre 2026 (page de tarifs visible et souscription
ouverte pour les AG de janvier, première période au 1er avril 2027), lot 5 en janvier 2027 sur
staging puis prod avec `BILLING_ENABLED=true`, lots 6 et 7 avant le 1er avril 2027. Le lot 2 est
plus gros qu'il ne l'était avec Stripe : c'est le prix du moteur d'abonnement écrit chez nous.

Le préfixe **`BILL`** est nouveau (table de `LEDGER_NEXT.md`, section dans les deux ledgers). Les
tâches purement web, mobile ou légales pourraient porter `WEB`/`MOB`/`LEGAL` ; le plan les garde
sous `BILL` parce qu'elles n'ont de sens qu'ensemble et qu'un `grep BILL-` doit tout retrouver —
**à trancher au §11**, avant le premier commit de code (un identifiant ne se renomme pas).

---

## 11. Décisions à prendre par le propriétaire

| # | Question | Proposition | Ce que l'autre choix implique |
|---|---|---|---|
| Q1 | Objectif : couvrir les coûts, ou en vivre ? | **Couvrir les coûts et qualifier les clubs**, prix bas, pas de commercial | Vivre du produit demande ×5 sur le prix ou ×50 sur le nombre de clubs, et un vrai canal de vente (l'enquête française 2027 du rapport §7) |
| Q2 | Prix Club | 80 €/an HT | 60 €/an rapproche du « don » et dévalue ; 150 €/an rapproche de RWGPS sans sa bibliothèque mondiale |
| Q3 | Seuil du gratuit | 25 membres | 10 ferme la porte aux sections de clubs ; 50 couvre la moitié des clubs du rapport et ne laisse qu'une raison de payer, les intégrations |
| Q4 | Le push GPS en Club, ou gratuit ? | **Club** (coûte des quotas et des partenariats) | Gratuit : le seul droit différenciant devient la taille — plus simple à expliquer, moins de raisons de payer pour un petit club équipé |
| Q5 | Date de bascule et première période | 1er avril 2027 ; toute souscription faite avant court du 1er avril 2027 au 31 mars 2028 | Une période qui démarre à la souscription : plus simple, mais un club qui souscrit en janvier paie trois mois déjà offerts |
| Q6 | Une date d'échéance commune à tous (le 31 mars) ou propre à chaque club ? | **Propre à chaque club** après le lancement, la première étant alignée sur le 31 mars | Commune : une campagne de renouvellement par an, plus lisible pour le propriétaire, mais prorata à calculer pour qui souscrit en cours d'année |
| Q7 | Équipes offertes pour toujours | Les équipes migrées de biketeam (`n-peloton`, `gaby`) et les clubs pilotes nommés | Tout faire payer y compris les pilotes : plus cohérent, mais ce sont eux qui ont testé |
| Q8 | Ouvrir les droits avant le paiement (`PENDING`) ? | **Oui**, 30 jours d'échéance + 30 jours de grâce | Attendre le virement : aucun risque d'impayé, mais un club attend des semaines après avoir voté |
| Q9 | La carte au lancement ? | **Non**, virement seul ; la carte (lot 8) si des clubs la demandent | Oui : OAuth, Mollie, un sous-traitant de plus et des frais, pour un moyen de paiement que peu d'associations utilisent |
| Q10 | Un devis téléchargeable ? | **Oui**, généré par nous ou par l'API Qonto selon F6 | Non : le trésorier demande un devis par e-mail, fait à la main |
| Q11 | Contrat : `12.0.0` à l'activation des refus, ou mineure ? | `12.0.0` | Mineure + republication mobile simultanée (`API-42`) : moins de cérémonie, même effet |
| Q12 | Préfixe `BILL` | Oui, nouveau préfixe | Éclater sous `API`/`WEB`/`MOB`/`LEGAL`/`OPS` |
| Q13 | Statut juridique | Rester en EI, franchise de TVA tant que possible, compte Qonto au nom de l'EI | Créer une société avant d'encaisser : coûts fixes, inutile à cette échelle |
| Q14 | Rétractation | 14 jours offerts à tous (F8) | Distinguer selon le client : plus juste, impossible à automatiser |

---

## 12. Délibérément dehors

| Sujet | Pourquoi |
|---|---|
| **Stripe** (première version de ce plan) | Remplacé par Qonto le 17 octobre 2026, choix du propriétaire. Stripe apportait le moteur d'abonnement, le portail client et le mensuel ; Qonto apporte la facture au format attendu par un trésorier, la comptabilité et l'encaissement au même endroit, un sous-traitant français, aucun transfert hors UE au lancement, et pas de commission sur un virement. Le prix est le moteur écrit chez nous (§5.3). À rouvrir si le mensuel devient nécessaire |
| Mensualité, prélèvement récurrent | Annuel seul (§1). Un prélèvement SEPA existe dans l'API Qonto (mandats, `/v2/sepa/direct_debit_mandates`) et permettrait de renouveler sans virement ; il demande la signature d'un mandat par le club et la gestion des rejets. À rouvrir si les relances de virement deviennent le premier poste de travail |
| Prix par membre, quota de stockage ou de parcours | §3.4 |
| Abonnement individuel | §3.4 ; à rouvrir sur demande réelle |
| Achat dans l'app mobile (in-app purchase) | §6.2 : commission 15–30 %, deux catalogues à tenir, et l'unité facturée est l'équipe |
| Encaisser les cotisations du club | Rapport §6-I, `MEMBER_EXPORT` est le pont |
| Essai gratuit à l'inscription | Remplacé par la période de lancement ; après avril 2027, `PENDING` (droits ouverts dès la souscription) en tient lieu |
| Changement de palier en cours de période en self-service | §4.5 : un e-mail au support à cette échelle |
| Facturation multi-devises | Clients français ; à rouvrir avec un premier club hors France |
| Self-service de l'alias de domaine | Reste un acte d'admin plateforme (DNS, certificat Caddy) : un devis, pas un bouton |
