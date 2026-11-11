# Limiter l'offre gratuite, débloquer une équipe à la main

Écrit le 11 novembre 2026. **État : décidé, pas codé.** Ledger `BILL-10`. Précède la monétisation
([`2026-10-17-monetisation.md`](2026-10-17-monetisation.md)) : on pose les limites et le levier
de déblocage **avant** tout paiement ; Qonto viendra plus tard comme une seconde façon de
débloquer, sans rien changer à ce qui est décrit ici.

L'état du code décrit ici a été vérifié le 11 novembre 2026 (contrat `14.0.0`, migration `V88`).
Les chemins Java sont relatifs à `backend/src/main/java/fr/pedalons/`.

---

## 1. En une page

Deux paliers, et c'est l'admin plateforme seul qui fait passer une équipe de l'un à l'autre :

| | **Gratuit** | **Débloqué** |
|---|---|---|
| Membres | **25 au plus** (invitations en cours comprises) | illimité |
| Parcours tracés au planificateur | **10 par mois civil** | illimité |
| Tout le reste (sorties, groupes, import GPX, posts, annonces, calendrier, notifications, applis, envoi vers les compteurs, webhook) | ✓ | ✓ |

**Le gratuit est un vrai produit.** Le rapport Ride with GPS
([`../research/2026-10-17-rwgps-state-of-the-cycling-club-2026.md`](../research/2026-10-17-rwgps-state-of-the-cycling-club-2026.md))
situe la frontière vers 25 membres : en dessous, 61 % des clubs n'ajoutent personne en un an — ce
sont des groupes d'amis et des sections naissantes, sans budget ; au-dessus, un club a un bureau et
une AG. Le bouche-à-oreille fait 42 % des arrivées : chaque petit groupe gratuit est aussi
l'endroit d'où viendra le club suivant. Rien de ce qui fait la valeur de base que le rapport valide
(un calendrier, une liste, des parcours au même endroit, l'allure de chaque groupe) n'est réservé.

**Le planificateur est la seule fonction limitée, parce que c'est la seule qui coûte à l'usage** :
chaque calcul d'itinéraire est facturé par Stadia Maps (`OPS-48`). Une petite équipe qui roule une
fois par semaine trace 4 à 5 parcours par mois ; 10 la laissent à l'aise. L'import de GPX, lui,
reste illimité.

**En contrepartie, une nouvelle équipe s'ouvre seule.** Aujourd'hui elle naît fermée
(`joinable = false`, `addMemberAllowed = false` posés par `TeamService.createTeam`) et attend que
l'admin plateforme l'ouvre. Désormais c'est le plafond de 25 qui protège : une équipe créée invite
et se laisse rejoindre tout de suite, dans la limite.

**Rien n'est perdu en redescendant.** Une équipe débloquée que l'on remet en gratuit garde ses
120 membres et tous ses parcours ; elle ne peut plus *ajouter* de membre ni tracer au-delà du
quota.

**Les équipes existantes sont débloquées d'office** par la migration ; les équipes importées de
biketeam aussi (`BiketeamMigrationService`), comme elles reçoivent déjà tous les drapeaux de
gouvernance.

---

## 2. Ce qui existe et ce qui change

### 2.1 Les drapeaux de gouvernance

`domain/team/Team.java` porte quatre drapeaux réglés par l'admin plateforme seul
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
l'emporte toujours sur le palier.

### 2.2 Le modèle

```sql
-- V89__team_tier.sql
alter table teams add column tier varchar(20) not null default 'FREE';   -- FREE | UNLOCKED
alter table teams add column tier_note varchar(500);                      -- « club pilote », « offert par … »
update teams set tier = 'UNLOCKED';                                       -- toutes les équipes existantes

create table team_planner_usages (
  team_id   bigint not null references teams(id),
  route_id  bigint not null references team_entities(id) on delete cascade,  -- un parcours (héritage TeamEntity)
  month     date   not null,                     -- premier jour du mois, fuseau de l'équipe
  first_at  timestamptz not null,
  primary key (team_id, month, route_id)
);
```

- **Compatible avec le déploiement à chaud** : une colonne avec défaut et une table nouvelle ; le
  backend précédent les ignore. Une équipe créée par l'ancien backend pendant la minute de
  recouvrement naît en `FREE` fermée — sans conséquence, elle s'ouvre à sa première modification
  par l'admin ou reste simplement fermée comme aujourd'hui. La migration ne touche pas les drapeaux
  des équipes existantes.
- **Un parcours compte une fois par mois**, qu'il soit créé ou modifié dix fois au planificateur :
  `insert … on conflict do nothing`. Le quota est le nombre de lignes du mois. C'est ce qui rend la
  règle lisible (« 10 parcours ») plutôt qu'un nombre d'enregistrements.
- `tier` est une colonne de `Team` et non une table d'abonnement : la monétisation ajoutera
  `team_subscriptions` comme une **seconde source** du même résolveur (§2.3) ; `UNLOCKED` posé à la
  main y deviendra le palier « offert » (`source = MANUAL`).

### 2.3 Une seule porte : `TeamLimits`

```java
// service/team/TeamLimits.java
public record TeamLimits(TeamTier tier, @Nullable Integer memberLimit, @Nullable Integer plannerMonthlyQuota) {
  static TeamLimits of(Team team) { … }   // FREE → 25 / 10 ; UNLOCKED → null / null
}
```

Les valeurs vivent dans `application.properties` (`pedalons.team.free.member-limit=25`,
`pedalons.team.free.planner-monthly-quota=10`) : les changer est un redéploiement, pas une
migration. Le reste du code ne connaît pas les nombres. La monétisation remplacera `of(Team)` par
le `TeamEntitlementsResolver` de son §5.4, sans toucher aux points de contrôle.

---

## 3. Les points de contrôle

| Action | Où | Règle | Erreur |
|---|---|---|---|
| Rejoindre une équipe ouverte | `TeamMembershipService.joinTeam` | membres actifs < limite | `409 TEAM_MEMBER_LIMIT_REACHED` |
| Ajouter un membre (admin d'équipe) | `TeamMembershipService` (`:118`) | idem | idem |
| Envoyer une invitation | `TeamInvitationService` (`:114`) | membres + invitations en cours < limite | idem |
| Accepter une invitation | `TeamInvitationService.accept` | membres actifs < limite (une invitation envoyée sous la limite peut buter si d'autres sont entrés entre-temps) | idem |
| Enregistrer un tracé dessiné | `RouteService.checkPlannerAllowed`, `GpxPreviewService.createRoute` | parcours déjà compté ce mois, **ou** lignes du mois < quota ; puis inscription de l'usage dans la même transaction | `403 ROUTE_PLANNER_QUOTA_REACHED` |
| Calculer un itinéraire | `PlannerAccess.check` | refusé quand le quota du mois est atteint (§3.2) | idem |

**Exemptés** : l'admin plateforme (comme pour `addMemberAllowed` aujourd'hui) et l'import
biketeam. L'admin plateforme qui ajoute le 26ᵉ membre d'une équipe gratuite le fait sciemment.

### 3.1 La course au 25ᵉ membre

Compter puis insérer laisse passer deux arrivées simultanées. Les quatre chemins prennent un
**verrou sur la ligne de l'équipe** (`select … for update` sur `teams`) avant de compter : c'est
rare, court, et propre à une équipe. Pas de contrainte en base : un dépassement d'une unité serait
sans gravité, mais le verrou coûte une requête et ferme la question.

### 3.2 Le quota et le calcul d'itinéraire

Le coût est dans le **calcul** (`/api/router`), mais ce qu'on compte est l'**enregistrement** — une
équipe qui explore dix variantes d'un même parcours doit compter une fois. Le calcul reste donc
ouvert tant que le quota n'est pas atteint, et se ferme quand il l'est, sauf pour retoucher un
parcours déjà compté ce mois : le client passe alors `routeId` à `POST /api/router`, le serveur
vérifie la ligne `team_planner_usages`. **Le calcul sans enregistrement n'est borné par rien
aujourd'hui**, sauf le quota mensuel global de Stadia Maps (`ROUTING_QUOTA_EXCEEDED`), commun à
toutes les équipes : une équipe gratuite pourrait l'épuiser sans jamais enregistrer. Le lot 3
ajoute donc un plafond de calculs par équipe et par jour (ordre de grandeur : quelques centaines,
à fixer sur l'usage réel de `n-peloton`), compté en mémoire ou en base, pour les deux paliers.

### 3.3 Les codes d'erreur

Deux codes nouveaux dans `ErrorCode`, chacun avec `details` : `limit`, `current` (et `resetsOn`,
premier jour du mois suivant, pour le planificateur). Les clients affichent :

- membres : « L'équipe a atteint 25 membres, la limite de l'offre gratuite. Pour aller au-delà,
  contactez-nous. » — un lien vers la page de contact pour un admin d'équipe ; « Demandez à un
  administrateur de l'équipe » pour les autres ;
- planificateur : « Les 10 parcours tracés ce mois-ci sont atteints. L'import de GPX reste
  disponible, et le compteur repart le 1er décembre. »

Copie épicène (BRANDING §8.2), relue au moment du code.

---

## 4. Le contrat

```yaml
TeamDetailDto:
  tier:          TeamTier          # FREE | UNLOCKED — tout lecteur
  memberLimit:   integer?          # null = illimité
  memberCount:   integer           # déjà connu des membres ; affiché « 24 / 25 »
  plannerQuota:  PlannerQuotaDto?  # éditeurs de parcours de l'équipe seulement, sinon null

PlannerQuotaDto:
  limit:     integer?              # null = illimité
  used:      integer               # parcours comptés ce mois
  resetsOn:  LocalDate

AdminTeamDto:            + tier, tierNote
AdminTeamAttributesRequest: + tier, tierNote
POST /api/router …       + routeId? (§3.2)
```

`memberCount` n'est donné qu'à qui voit déjà la liste (invariant « les noms ne sortent pas de
l'équipe » : un compte n'est pas un nom, mais on reste sur ce que `TeamDetailDto` expose déjà —
à vérifier au code).

**Version** : `14.1.0` pour les champs ; les deux refus sont un changement de comportement. Un
mobile ancien affiche son message d'erreur générique au 26ᵉ membre — acceptable : le cas est rare
au début, et la version mobile qui sait le rendre part avec le même lot. À relire si l'on préfère
`15.0.0`.

---

## 5. Les clients

**Web**
- Admin plateforme (`AdminTeamsPage`) : le palier en colonne, filtrable ; dans la fiche, un
  sélecteur « Gratuit / Débloqué » et la note, à côté des drapeaux existants.
- Paramètres d'équipe, liste des membres et invitation : « 24 / 25 membres » quand une limite
  existe, l'invitation désactivée à 25 avec le message du §3.3.
- Éditeur de parcours (`RouteEditor`) : « 7 / 10 parcours tracés ce mois-ci » ; à 10, le
  planificateur ne s'ouvre plus sur un parcours non compté (le message dit pourquoi et rappelle
  l'import), il reste ouvert sur un parcours déjà compté.
- Page de rejoindre une équipe pleine : le bouton est remplacé par le message.
- Aucune mention de prix nulle part : il n'y en a pas encore.

**Mobile** : le compteur de membres et le rendu des deux erreurs ; l'app ne trace pas de parcours,
le quota ne la concerne que par l'erreur d'un parcours enregistré ailleurs (aucune). Rien sur
Karoo ni Garmin.

---

## 6. Tests

- `TeamLimitsResourceTest` : 26ᵉ arrivée refusée par chacun des quatre chemins en `FREE`, acceptée
  en `UNLOCKED` et pour l'admin plateforme ; invitations en cours comptées ; une équipe débloquée
  repassée en gratuit avec 30 membres garde ses 30 et refuse le 31ᵉ ; une nouvelle équipe est
  ouverte (`joinable`, `addMemberAllowed`, `enableRoutePlanner` à `true`).
- `PlannerQuotaResourceTest` : 10 parcours passent, le 11ᵉ est refusé ; le même parcours modifié
  plusieurs fois compte une fois ; le compteur repart au mois suivant (horloge injectée, fuseau de
  l'équipe) ; routage refusé à quota plein sauf avec un `routeId` compté ; un drapeau
  `enableRoutePlanner = false` ferme le planificateur même en `UNLOCKED`.
- Concurrence : deux `joinTeam` simultanés sur une équipe à 24 → un seul passe.
- `…QueryCountTest` : la liste des équipes de l'admin plateforme ne coûte pas une requête par
  ligne pour le palier (c'est une colonne) ; le compteur de membres reste par page.
- e2e Playwright : le 26ᵉ membre refusé, le compteur du planificateur, le déblocage depuis
  l'admin plateforme.

---

## 7. Découpage

| Lot | Contenu | Taille |
|---|---|---|
| 1 | Migration, `TeamTier`, `TeamLimits`, défauts d'ouverture à la création, admin plateforme (contrat + page), champs de `TeamDetailDto` — **sans refus** | S |
| 2 | Plafond de membres : les quatre chemins, verrou, erreur, clients web et mobile | S–M |
| 3 | Quota du planificateur : table d'usage, enregistrement, routeur et son plafond quotidien, compteur dans l'éditeur | M |

L'ordre permet de déployer le lot 1 et de vérifier les paliers en prod avant qu'un refus existe.
Le lot 2 suffit à protéger contre l'usage « club gratuit » ; le lot 3 protège la facture Stadia.

---

## 8. Ce qui change dans le plan de monétisation

- Le seuil de 25 (Q3) et les « équipes offertes » (Q7) sont tranchés ici : 25, et toutes les
  équipes existantes au 11 novembre 2026.
- Le droit `ROUTE_PLANNER` du plan devient un **quota** plutôt qu'un interrupteur : le gratuit
  garde 10 parcours par mois.
- Le push GPS (Q4) et le webhook restent **gratuits** à ce stade ; la monétisation les rouvrira si
  elle veut d'autres raisons de payer.
- `TeamLimits` est le germe de `TeamEntitlements` ; `tier = UNLOCKED` en sera la source `MANUAL`.

## 9. Délibérément dehors

| Sujet | Pourquoi |
|---|---|
| Limiter le nombre de sorties, de posts, de parcours importés, le stockage | La valeur de base du rapport ; `n-peloton` a 2 696 parcours, et la taille de bibliothèque ne prédit rien (rapport §2). `GpxLimits` suffit contre l'abus |
| Limiter le nombre d'équipes créées par personne | Déjà fait : `MAX_ADMIN_TEAMS_PER_USER = 1` |
| Une demande de déblocage en libre-service (formulaire, bouton) | À cette échelle, un e-mail ; le paiement viendra avec la monétisation |
| Un essai « débloqué » de N jours pour les nouvelles équipes | Le gratuit suffit à essayer ; on n'apprend rien à quelqu'un en lui retirant quelque chose |
| Supprimer ou masquer des membres au-delà de la limite | Redescendre ne détruit rien |
