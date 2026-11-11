# Limiter l'offre gratuite, débloquer une équipe à la main

Écrit le 11 novembre 2026, révisé le même jour (chaque enregistrement compte, quota personnel des
outils GPX). **État : décidé, pas codé.** Ledger `BILL-10`. Précède la monétisation
([`2026-10-17-monetisation.md`](2026-10-17-monetisation.md)) : on pose les limites et le levier
de déblocage **avant** tout paiement ; Qonto viendra plus tard comme une seconde façon de
débloquer, sans rien changer à ce qui est décrit ici.

L'état du code décrit ici a été vérifié le 11 novembre 2026 (contrat `14.0.0`, migration `V88`).
Les chemins Java sont relatifs à `backend/src/main/java/fr/pedalons/`.

---

## 1. En une page

Deux paliers d'équipe, et c'est l'admin plateforme seul qui fait passer une équipe de l'un à
l'autre :

| | **Gratuit** | **Débloqué** |
|---|---|---|
| Membres | **25 au plus** (invitations en cours comprises) | illimité |
| Enregistrements d'un parcours tracé au planificateur, dans l'équipe | **20 par mois civil** | illimité |
| Tout le reste (sorties, groupes, import GPX, posts, annonces, calendrier, notifications, applis, envoi vers les compteurs, webhook) | ✓ | ✓ |

Et un quota **personnel**, pour qu'on ne contourne pas le quota d'équipe par les outils GPX
(`/api/gpx-previews`, le planificateur hors équipe) :

| | **Membre d'au moins une équipe débloquée** | **Tout autre utilisateur** |
|---|---|---|
| Enregistrements d'un tracé dessiné dans les outils GPX | illimité | **10 par mois civil** |

**Chaque enregistrement compte.** Créer un parcours tracé compte 1, chaque modification de son
tracé au planificateur compte 1 de plus. Ne comptent pas : l'import ou le remplacement par un
fichier GPX, un renommage, les points de passage seuls, le départ et l'allure — rien de ce qui ne
fait pas appel au routage. Le quota mesure donc le travail au planificateur, ce qui coûte, et se
dit en une phrase : « 20 enregistrements par mois ».

**Le gratuit est un vrai produit.** Le rapport Ride with GPS
([`../research/2026-10-17-rwgps-state-of-the-cycling-club-2026.md`](../research/2026-10-17-rwgps-state-of-the-cycling-club-2026.md))
situe la frontière vers 25 membres : en dessous, 61 % des clubs n'ajoutent personne en un an — ce
sont des groupes d'amis et des sections naissantes, sans budget ; au-dessus, un club a un bureau et
une AG. Le bouche-à-oreille fait 42 % des arrivées : chaque petit groupe gratuit est aussi
l'endroit d'où viendra le club suivant. Rien de ce qui fait la valeur de base que le rapport valide
(un calendrier, une liste, des parcours au même endroit, l'allure de chaque groupe) n'est réservé.

**Le planificateur est la seule fonction limitée, parce que c'est la seule qui coûte à l'usage** :
chaque calcul d'itinéraire est facturé par Stadia Maps (`OPS-48`). Une petite équipe qui roule une
fois par semaine trace 4 à 5 parcours par mois et en retouche quelques-uns : 20 enregistrements la
laissent à l'aise. L'import de GPX, lui, reste illimité partout.

**En contrepartie, une nouvelle équipe s'ouvre seule.** Aujourd'hui elle naît fermée
(`joinable = false`, `addMemberAllowed = false` posés par `TeamService.createTeam`) et attend que
l'admin plateforme l'ouvre. Désormais ce sont les plafonds qui protègent : une équipe créée invite,
se laisse rejoindre et trace tout de suite, dans la limite.

**Rien n'est perdu en redescendant.** Une équipe débloquée que l'on remet en gratuit garde ses
120 membres et tous ses parcours ; elle ne peut plus *ajouter* de membre ni tracer au-delà du
quota. Ses membres perdent le quota personnel illimité s'ils n'ont pas d'autre équipe débloquée ;
leurs aperçus GPX restent.

**Les équipes existantes sont débloquées d'office** par la migration ; les équipes importées de
biketeam aussi (`BiketeamMigrationService`), comme elles reçoivent déjà tous les drapeaux de
gouvernance.

---

## 2. Ce qui existe et ce qui change

### 2.1 Les drapeaux de gouvernance

`domain/team/Team.java` porte des drapeaux réglés par l'admin plateforme seul
(`PATCH /api/admin/teams/{id}/attributes`, `AdminTeamService.updateTeamAttributes`) :

| Drapeau | Contrôlé dans | Défaut aujourd'hui | Défaut après |
|---|---|---|---|
| `joinable` | `UserTeamAccessChecker` (`JOIN`) | `false` | **`true`** |
| `addMemberAllowed` | `TeamMembershipService:118`, `TeamInvitationService:114` | `false` | **`true`** |
| `enableRoutePlanner` | `RouteService.checkPlannerAllowed`, `GpxPreviewService.createRoute`, `PlannerAccess` | `false` | **`true`** (le quota prend le relais) |
| `visibilityEditable` | `TeamService:278` | `false` | `false` (inchangé : c'est une modération, pas un palier) |
| `publicContentAllowed` | `ContentVisibilityRules` | `false` | `false` (inchangé, `API-176`) |

Les drapeaux **restent** : ils servent à *fermer* une équipe précise (abus, spam) quel que soit son
palier. Le palier ajoute des *plafonds*, il ne remplace pas les interrupteurs. Un drapeau à `false`
l'emporte toujours sur le palier. Côté outils GPX, `Domain.enableGpxPlanner` joue le même rôle :
fermé, le planificateur hors équipe l'est pour tout le monde.

### 2.2 Le modèle

```sql
-- V89__team_tier.sql
alter table teams add column tier varchar(20) not null default 'FREE';   -- FREE | UNLOCKED
alter table teams add column tier_note varchar(500);                      -- « club pilote », « offert par … »
update teams set tier = 'UNLOCKED';                                       -- toutes les équipes existantes

create table planner_saves (
  id          bigint primary key,                 -- TSID
  domain_id   bigint not null references domains(id),
  user_id     bigint not null references users(id),
  team_id     bigint references teams(id),        -- null : outils GPX (quota personnel)
  saved_at    timestamptz not null,
  target_id   bigint                              -- parcours ou aperçu, pour le diagnostic ; pas de clé étrangère
);
create index on planner_saves (team_id, saved_at) where team_id is not null;
create index on planner_saves (user_id, saved_at) where team_id is null;
```

- **Un journal, une ligne par enregistrement** ; le quota est le nombre de lignes depuis le
  premier jour du mois. Pas de clé étrangère vers le parcours ni l'aperçu : supprimer ce qu'on a
  tracé **ne rend pas** le crédit, sinon créer-supprimer-recréer contournerait tout.
- Le mois d'une équipe se lit dans son fuseau (`Team.timezone`) ; celui d'un utilisateur dans
  `Crons.ZONE`. Purge des lignes de plus de 13 mois par un job quotidien idempotent.
- **Compatible avec le déploiement à chaud** : une colonne avec défaut et une table nouvelle ; le
  backend précédent les ignore. Une équipe créée par l'ancien backend pendant la minute de
  recouvrement naît en `FREE` fermée, comme aujourd'hui. La migration ne touche pas les drapeaux
  des équipes existantes. Les enregistrements faits par l'ancien backend pendant cette minute ne
  sont pas comptés : sans conséquence.
- `tier` est une colonne de `Team` et non une table d'abonnement : la monétisation ajoutera
  `team_subscriptions` comme une **seconde source** du même résolveur (§2.3) ; `UNLOCKED` posé à la
  main y deviendra le palier « offert » (`source = MANUAL`).

### 2.3 Une seule porte : `PlanLimits`

```java
// service/limits/PlanLimits.java
public TeamLimits forTeam(Team team);   // FREE → 25 membres / 20 ; UNLOCKED → null / null
public @Nullable Integer personalPlannerQuota(long userId);  // null si membre d'une équipe UNLOCKED du domaine
```

Les valeurs vivent dans `application.properties` (`pedalons.limits.free.member-limit=25`,
`pedalons.limits.free.team-planner-monthly=20`, `pedalons.limits.free.personal-planner-monthly=10`) :
les changer est un redéploiement, pas une migration. Le reste du code ne connaît pas les nombres.
« Membre d'une équipe débloquée » = au moins un `UserTeam` actif, quel que soit le rôle, dans une
équipe `UNLOCKED` **du domaine courant**. La monétisation remplacera ces deux fonctions par le
`TeamEntitlementsResolver` de son §5.4, sans toucher aux points de contrôle.

---

## 3. Les points de contrôle

### 3.1 Membres

| Action | Où | Règle | Erreur |
|---|---|---|---|
| Rejoindre une équipe ouverte | `TeamMembershipService.joinTeam` | membres actifs < limite | `409 TEAM_MEMBER_LIMIT_REACHED` |
| Ajouter un membre (admin d'équipe) | `TeamMembershipService` (`:118`) | idem | idem |
| Envoyer une invitation | `TeamInvitationService` (`:114`) | membres + invitations en cours < limite | idem |
| Accepter une invitation | `TeamInvitationService.accept` | membres actifs < limite (une invitation envoyée sous la limite peut buter si d'autres sont entrés entre-temps) | idem |

Compter puis insérer laisse passer deux arrivées simultanées : les quatre chemins prennent un
**verrou sur la ligne de l'équipe** (`select … for update` sur `teams`) avant de compter.

### 3.2 Planificateur

| Action | Où | Quota | Erreur |
|---|---|---|---|
| Créer ou modifier un parcours d'équipe avec un tracé dessiné | `RouteService.checkPlannerAllowed` (création et modification) | équipe | `403 PLANNER_QUOTA_REACHED`, `scope: TEAM` |
| Promouvoir un aperçu dessiné en parcours d'équipe | `GpxPreviewService.createRoute` (`preview.isDrawn()`) | équipe (une création) | idem |
| Créer un aperçu depuis le planificateur | `GpxPreviewService.createPreviewFromPoints` | personnel | `403 PLANNER_QUOTA_REACHED`, `scope: PERSONAL` |
| Modifier le tracé d'un aperçu au planificateur | `GpxPreviewService.updatePreview` avec points ou état, sans fichier | personnel | idem |
| Calculer un itinéraire | `PlannerAccess.check` : avec `teamSlug` → quota de l'équipe ; sans → quota personnel | refusé quand le quota est **atteint** | idem |

- **La règle** : `enregistrements du mois < quota`, puis inscription de la ligne dans la même
  transaction que l'enregistrement. Un enregistrement refusé ne compte pas.
- **Ce qui compte comme « tracé dessiné »** est la règle qui existe déjà : pas de fichier, et des
  points ou un `PlannerState` (`RouteService.checkPlannerAllowed`, `drawing`). Un `PlannerState`
  fait seulement de morceaux importés (`drawn() == false`) ne compte pas, comme il n'est pas
  gouverné aujourd'hui (décision `WEB-100`, C4a).
- **Le contournement visé** : un membre d'une équipe gratuite qui tracerait dans les outils GPX
  pour promouvoir ensuite. Il bute sur ses 10 enregistrements personnels, et la promotion compte
  encore dans le quota de l'équipe. Le contournement qui reste — exporter le GPX d'un aperçu et
  le réimporter comme fichier — est déjà accepté (`API-127`) : il ne coûte aucun calcul de plus.
- **Le calcul sans enregistrement** reste ouvert tant que le quota n'est pas atteint. Il n'est
  borné par rien d'autre aujourd'hui que le quota mensuel global de Stadia Maps
  (`ROUTING_QUOTA_EXCEEDED`), commun à toutes les équipes. Le lot 3 ajoute un plafond de calculs
  par jour, **par utilisateur** (ordre de grandeur : quelques centaines, à fixer sur l'usage réel
  de `n-peloton`), pour les deux paliers ; un plafond par équipe ne suffirait pas, le planificateur
  hors équipe n'en a pas.
- **Exemptés** : l'admin plateforme, et l'import biketeam (aucun tracé dessiné).

### 3.3 Les codes d'erreur

Deux codes nouveaux dans `ErrorCode`, chacun avec `details` : `limit`, `current`, et pour le
planificateur `scope` (`TEAM` | `PERSONAL`), `resetsOn` (premier jour du mois suivant) et, pour
`TEAM`, `teamName`.
`ROUTE_PLANNER_DISABLED` reste pour le drapeau fermé. Les clients affichent :

- membres : « L'équipe a atteint 25 membres, la limite de l'offre gratuite. Pour aller au-delà,
  contactez-nous. » — un lien vers la page de contact pour un admin d'équipe ; « Demandez à un
  administrateur de l'équipe » pour les autres ;
- planificateur, équipe : « <Équipe> utilise l'offre gratuite, qui permet 20 enregistrements
  de parcours tracés sur la carte par mois. Ils sont tous utilisés ce mois-ci. L'import de GPX
  reste disponible, et le compteur repart le 1er décembre. Pour lever la limite, un
  administrateur de l'équipe peut nous contacter. » ;
- planificateur, personnel : « Vous ne faites partie d'aucune équipe débloquée : dans les outils
  GPX, le tracé sur la carte est limité à 10 enregistrements par mois, tous utilisés ce mois-ci.
  L'import de GPX reste disponible, et le compteur repart le 1er décembre. Rejoindre une équipe
  débloquée lève cette limite. »

Chaque message dit **pourquoi** la limite s'applique (l'équipe est en offre gratuite ; vous
n'êtes membre d'aucune équipe débloquée), pas seulement qu'elle est atteinte. Le nom de l'équipe
vient de `details.teamName` (`scope: TEAM`).

Copie épicène (BRANDING §8.2), relue au moment du code.

---

## 4. Le contrat

```yaml
TeamDetailDto:
  tier:          TeamTier          # FREE | UNLOCKED — tout lecteur
  memberLimit:   integer?          # null = illimité ; memberCount existe déjà
  plannerQuota:  PlannerQuotaDto?  # à qui peut créer des parcours dans l'équipe, sinon null

UserDto (GET /api/users/me):
  plannerQuota:  PlannerQuotaDto   # quota personnel des outils GPX

PlannerQuotaDto:
  limit:     integer?              # null = illimité
  used:      integer               # enregistrements du mois
  resetsOn:  LocalDate

AdminTeamDto:               + tier, tierNote
AdminTeamAttributesRequest: + tier, tierNote
```

Le point d'accès exact du « moi » (`/api/users/me` ou celui qui porte déjà le profil) est à relire
au code.

**Version** : `14.1.0` pour les champs ; les refus sont un changement de comportement. Un mobile
ancien affiche son message d'erreur générique au 26ᵉ membre — acceptable : le cas est rare au
début, et la version mobile qui sait le rendre part avec le même lot. À relire si l'on préfère
`15.0.0`.

---

## 5. Les clients

**Web**
- Admin plateforme (`AdminTeamsPage`) : le palier en colonne, filtrable ; dans la fiche, un
  sélecteur « Gratuit / Débloqué » et la note, à côté des drapeaux existants.
- Paramètres d'équipe, liste des membres et invitation : « 24 / 25 membres » quand une limite
  existe, l'invitation désactivée à 25 avec le message du §3.3.
- Planificateur : **aucun compteur affiché**. Le front ne fait qu'une chose avant l'appel :
  quand `plannerQuota.used >= limit` est **déjà** atteint, il désactive le point d'entrée, avec le
  message du §3.3 en infobulle ou en texte d'aide —
  - outils GPX : le bouton « Créer un parcours » (le tracé au planificateur ; l'import de fichier
    reste actif) ;
  - création d'un parcours d'équipe : l'option « Tracer sur la carte » (l'import de GPX reste
    actif).
- Refus de l'API (`PLANNER_QUOTA_REACHED`, quota atteint en cours de route : un autre membre a
  enregistré entre-temps, un autre onglet) : une **modale bloquante** porte le message du §3.3 selon
  `scope` : pourquoi la limite s'applique (équipe en offre gratuite, ou aucune équipe débloquée),
  quand le compteur repart (`resetsOn`), et l'import de GPX qui reste possible. Un seul composant, partagé par l'éditeur d'équipe et les outils GPX, déclenché par le
  code d'erreur quel que soit l'appel (enregistrement ou calcul d'itinéraire).
- Page de rejoindre une équipe pleine : le bouton est remplacé par le message.
- Aucune mention de prix nulle part : il n'y en a pas encore.

**Mobile** : le compteur de membres et le rendu de `TEAM_MEMBER_LIMIT_REACHED` ; l'app ne trace
pas de parcours. Rien sur Karoo ni Garmin.

---

## 6. Tests

- `TeamLimitsResourceTest` : 26ᵉ arrivée refusée par chacun des quatre chemins en `FREE`, acceptée
  en `UNLOCKED` et pour l'admin plateforme ; invitations en cours comptées ; une équipe débloquée
  repassée en gratuit avec 30 membres garde ses 30 et refuse le 31ᵉ ; une nouvelle équipe est
  ouverte (`joinable`, `addMemberAllowed`, `enableRoutePlanner` à `true`).
- `TeamPlannerQuotaResourceTest` : 20 enregistrements passent, le 21ᵉ est refusé ; trois
  modifications du même parcours comptent trois ; un import GPX, un renommage, des points de
  passage seuls ne comptent pas ; supprimer un parcours ne rend rien ; le compteur repart au mois
  suivant (horloge injectée, fuseau de l'équipe) ; routage refusé à quota plein ;
  `enableRoutePlanner = false` ferme le planificateur même en `UNLOCKED`.
- `PersonalPlannerQuotaResourceTest` : un utilisateur sans équipe débloquée a 10 enregistrements
  d'aperçu ; membre d'une équipe débloquée (quel que soit le rôle) → illimité ; d'une équipe
  débloquée d'un autre domaine → 10 ; la promotion d'un aperçu dessiné compte dans le quota de
  l'équipe ; routage sans équipe refusé à quota plein.
- Concurrence : deux `joinTeam` simultanés sur une équipe à 24 → un seul passe.
- `…QueryCountTest` : la liste des équipes de l'admin plateforme ne coûte pas une requête par
  ligne pour le palier (c'est une colonne) ; le compteur de membres reste par page.
- e2e Playwright : le 26ᵉ membre refusé ; à quota plein, « Créer un parcours » (outils GPX) et
  « Tracer sur la carte » (équipe) désactivés ; la modale sur un refus de l'API ; le déblocage
  depuis l'admin plateforme.

---

## 7. Découpage

| Lot | Contenu | Taille |
|---|---|---|
| 1 | Migration, `TeamTier`, `PlanLimits`, défauts d'ouverture à la création, admin plateforme (contrat + page), `tier` et `memberLimit` dans `TeamDetailDto` — **sans refus** | S |
| 2 | Plafond de membres : les quatre chemins, verrou, erreur, clients web et mobile | S–M |
| 3 | Quotas du planificateur : journal `planner_saves`, les points de contrôle équipe et personnel, le routeur et son plafond quotidien par utilisateur, les points d'entrée désactivés à quota plein et la modale de refus | M |

L'ordre permet de déployer le lot 1 et de vérifier les paliers en prod avant qu'un refus existe.
Le lot 2 suffit à protéger contre l'usage « club gratuit » ; le lot 3 protège la facture Stadia.

---

## 8. Ce qui change dans le plan de monétisation

- Le seuil de 25 (Q3) et les « équipes offertes » (Q7) sont tranchés ici : 25, et toutes les
  équipes existantes au 11 novembre 2026.
- Le droit `ROUTE_PLANNER` du plan devient un **quota** plutôt qu'un interrupteur : le gratuit
  garde 20 enregistrements par mois et par équipe, 10 à titre personnel.
- Le push GPS (Q4) et le webhook restent **gratuits** à ce stade ; la monétisation les rouvrira si
  elle veut d'autres raisons de payer.
- `PlanLimits` est le germe de `TeamEntitlements` ; `tier = UNLOCKED` en sera la source `MANUAL`.

## 9. Délibérément dehors

| Sujet | Pourquoi |
|---|---|
| Compter un parcours une seule fois par mois, quel que soit le nombre de modifications | Première version de ce plan, écartée le 11 novembre 2026 : chaque modification au planificateur coûte des calculs, elle compte ; le quota est relevé de 10 à 20 en conséquence |
| Rendre le crédit à la suppression d'un parcours ou d'un aperçu | Créer-supprimer-recréer contournerait le quota |
| Limiter le nombre de sorties, de posts, de parcours importés, le stockage | La valeur de base du rapport ; `n-peloton` a 2 696 parcours, et la taille de bibliothèque ne prédit rien (rapport §2). `GpxLimits` suffit contre l'abus |
| Fermer l'export puis le réimport d'un tracé dessiné | Déjà accepté (`API-127`) : il ne coûte aucun calcul |
| Limiter le nombre d'équipes créées par personne | Déjà fait : `MAX_ADMIN_TEAMS_PER_USER = 1` |
| Une demande de déblocage en libre-service (formulaire, bouton) | À cette échelle, un e-mail ; le paiement viendra avec la monétisation |
| Un essai « débloqué » de N jours pour les nouvelles équipes | Le gratuit suffit à essayer ; on n'apprend rien à quelqu'un en lui retirant quelque chose |
| Supprimer ou masquer des membres au-delà de la limite | Redescendre ne détruit rien |
