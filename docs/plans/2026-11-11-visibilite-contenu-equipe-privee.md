# Contenu public d'une équipe privée, et droits calculés par le backend

Écrit le 11 novembre 2026. **État : lot 1 fait le 11 novembre 2026 (drapeau, `V87`, règle unique d'écriture, lecture par lien, contrat `13.6.0`) ; lot 2 fait le même jour (droits calculés, contrat `13.7.0`) ; lots 3 à 5 à faire.** Ledger `API-176` (backend et
contrat), `WEB-166` (site), `MOB-137` (application), `SEC-51` (constat relevé, hors périmètre).
Branche prévue : `feat/visibilite-equipe-privee`, un commit par lot. Numéros vérifiés libres le
11 novembre 2026 : `API-176`, `API-177`, `WEB-166`, `MOB-137`, `SEC-51`, migration `V87`, contrat `13.5.0`
aujourd'hui.

Chemins relatifs à `backend/src/main/java/fr/pedalons/` sauf mention contraire.

---

## 1. En une page

Aujourd'hui une équipe privée (`Team.visibility = TEAM`) ne peut porter que du contenu « Équipe » :
`TeamEntityService.validateVisibility` refuse le reste (`INVALID_VISIBILITY`), et la lecture d'un
détail par un non-membre exige `te.team.visibility <> 'TEAM'`. Une équipe qui veut rester fermée ne
peut donc pas annoncer **une** sortie par lien.

Ce plan :

1. laisse la personne qui peut modifier une entité d'une équipe privée la publier en « Public » ou
   « Non répertorié », **par lien seulement**, pour les équipes qu'un administrateur de la
   plateforme y a autorisées ;
2. garantit qu'un changement de visibilité laisse les entités associées **compatibles** (une sortie
   ou un voyage non « Équipe » n'utilise que des parcours non « Équipe »), dans les deux sens ;
3. fait **calculer les droits par le backend** et les expose dans le contrat, pour que les clients
   cessent de recopier les règles (huit éditeurs le font aujourd'hui).

## 2. L'audit du 11 novembre 2026 : les règles en place

Tout passe par `repository/common/TeamEntityRepository.getPedalonsQuery` (filtre SQL) et les
`*AccessChecker`. Un administrateur de la plateforme contourne tout sur ce qu'il ouvre (`API-137`).

| Appelant | Détail par lien | Listes |
|---|---|---|
| Anonyme, non-membre | équipe ≠ `TEAM` **et** entité ≠ `TEAM`, publié ou annulé ; jamais une annonce | entité `PUBLIC` ; équipe `PUBLIC` en liste transverse, ≠ `TEAM` en liste d'une équipe |
| Membre | tout le publié ou annulé de son équipe, ses propres annonces en brouillon | idem |
| Organisateur | plus les brouillons (sauf pages et annonces) et le contenu masqué par modération | idem |
| Admin d'équipe | plus les brouillons de pages | idem |

- **Écriture** : organisateur pour sorties, parcours, posts, voyages, modèles, lieux ; admin pour
  pages, tags, équipe ; tout membre crée une annonce, admin ou auteur la modifie.
- **L'équipe elle-même** (détail, tableau de bord, publications, tags) : équipe ≠ `TEAM` ou membre.
- **Noms, commentaires, participants** : membres seulement, quelle que soit la visibilité de
  l'entité (`MemberNamesVisibility`, `API-144` ; `CommentAccessChecker`).
- **Pièces jointes et images** : le droit de lecture de l'entité propriétaire (`AssetAccessChecker`).
- **S'inscrire** à une sortie ou un voyage : membres seulement.

Anomalies relevées :

| # | Constat | Traité par |
|---|---|---|
| A1 | Un parcours peut repasser en « Équipe » sous une sortie ou un voyage public : le contrôle n'existe qu'à l'enregistrement du conteneur (`RideService.getRoute`, `TripService.getRoute`), pas dans `RouteService.updateRoute` | lot 3 |
| A2 | `TeamPageForm.tsx` propose « Public » en équipe privée (refus générique du serveur) et jamais « Non répertorié » | lot 4 |
| A3 | Passer une équipe en privé bascule tout son contenu en « Équipe » (`TeamService.makeContentTeamOnly`) sans avertissement ni retour arrière | lot 4 |
| A4 | Voir `SEC-51` | hors périmètre |
| A5 | La règle est recopiée dans cinq éditeurs web et trois mobiles (`team.visibility !== 'TEAM'`), et deux fois dans `RideTemplateService` | lots 1, 2, 4, 5 |

## 3. Décisions (11 novembre 2026, avec le propriétaire)

| # | Décision | Ce qu'elle écarte |
|---|---|---|
| D1 | **Lien seul.** En équipe privée, « Public » et « Non répertorié » sont équivalents : lisibles par lien, hors de toute liste, hors sitemap, `noindex`. Les deux valeurs restent proposées ; elles ne se distinguent que si l'équipe s'ouvre | lister et indexer le « Public » d'une équipe privée (elle serait plus exposée qu'une équipe non répertoriée) |
| D2 | **Un drapeau par équipe**, `publicContentAllowed`, posé par l'administrateur de la plateforme, indépendant de `visibilityEditable` | ouvrir à toute équipe : une équipe naît privée et non validée, c'est le garde-fou contre le contenu public d'inconnus |
| D3 | **Passage d'une équipe en privé : la bascule de tout le contenu en « Équipe » reste**, précédée d'une confirmation qui l'annonce | conserver les visibilités : passer en privé ne fermerait plus rien |
| D4 | **Qui peut modifier l'entité choisit sa visibilité** (organisateur ; admin pour les pages) | réserver la publication hors équipe à l'admin |
| D5 | **Montée d'un conteneur : aligner après confirmation.** Le backend refuse en listant les parcours incompatibles ; le client confirme ; le backend aligne dans la même transaction | aligner en silence ; refuser sans proposer |
| D6 | **Baisse d'un parcours utilisé publiquement : refus**, avec la liste des usages. Une sortie n'est jamais fermée par ricochet | fermer les sorties avec le parcours |
| D7 | **Les droits sont calculés par le backend** et lus par les clients ; un client ne redérive pas une règle à partir du rôle et de la visibilité | — |

Deux choix d'exécution, à défaire seulement en connaissance de cause :

- **L'alignement monte un parcours à « Non répertorié »**, la plus basse valeur qui satisfait
  l'invariant, même sous une sortie « Public » : un parcours ne devient jamais « Public » sans
  décision explicite.
- **Les annonces restent « Équipe »** (membres seulement, `AdAccessChecker`), et les modèles de
  sortie suivent la règle commune (leur visibilité est celle des sorties qu'ils créent).

## 4. Backend

### 4.1 Le drapeau (lot 1)

- `Team.publicContentAllowed`, `boolean`, faux par défaut. Migration `V87` : colonne
  `not null default false`. Additive, donc compatible avec la version précédente pendant le
  déploiement à chaud (son `insert` omet la colonne, le défaut s'applique).
- `AdminTeamAttributesRequest` et `AdminTeamDto` le portent ; `BiketeamMigrationService` le laisse
  à faux (une équipe migrée publique n'en a pas besoin).
- Ne joue que pour une équipe `TEAM` : une équipe publique ou non répertoriée choisit déjà ses
  visibilités.

### 4.2 Une règle unique d'écriture (lot 1)

Un seul composant (`service/common/ContentVisibilityRules`, nom libre) répond à « quelles
visibilités cette équipe accepte-t-elle pour ce type d'entité ? » :

| Équipe | Sortie, parcours, post, voyage, modèle, page | Annonce |
|---|---|---|
| `PUBLIC`, `PUBLIC_UNLISTED` | les trois | `TEAM` |
| `TEAM`, `publicContentAllowed` | les trois | `TEAM` |
| `TEAM`, sinon | `TEAM` | `TEAM` |

`TeamEntityService.validateVisibility` l'appelle ; les deux copies de `RideTemplateService`
disparaissent. Le même composant alimente les champs calculés du §4.5 : la validation et ce que le
client affiche ne peuvent pas diverger.

Retirer le drapeau à une équipe qui a déjà du contenu public : le contenu **reste** lisible par
lien, mais plus rien ne peut être publié ni enregistré en non « Équipe » (le champ calculé de
l'entité le dit, §4.5). L'administrateur de la plateforme qui veut tout fermer passe par la bascule
de D3. À confirmer à la recette : c'est le comportement le moins surprenant, pas une décision du
propriétaire.

### 4.3 La lecture par lien (lot 1)

`TeamEntityRepository.getPublicEntity`, branche détail (`list == false`) : la clause
`te.team.visibility <> 'TEAM'` disparaît. **Rien d'autre ne change** :

- les branches liste gardent leur clause d'équipe : le contenu public d'une équipe privée n'entre
  dans aucune liste, transverse ou d'équipe (`RouteAccessChecker` laisse passer `LIST` pour tout le
  monde, c'est le SQL qui tient) ;
- `findIndexable` garde `te.team.visibility = 'PUBLIC'` : rien au sitemap ;
- `TYPE(te) <> Ad` reste pour l'anonyme ;
- suivent sans changement, parce qu'ils délèguent au droit de lecture de l'entité : pièces jointes
  et images, ICS d'une sortie ou d'un voyage, étapes, météo ;
- restent fermés au non-membre : noms et avatars (`API-144`), participants, commentaires,
  inscription, `GET team`, tableau de bord, tags de l'équipe.

Ce que le lien révèle, par construction : le nom et le slug de l'équipe privée, portés par le DTO
de l'entité, les tags de l'entité (pas le vocabulaire de l'équipe), et **le logo de l'équipe**
(décision du 11 novembre 2026) : le logo seul, pas les autres pièces de la page « À propos », est
public exactement quand l'équipe a `publicContentAllowed`. Sans le drapeau, le logo reste fermé,
même s'il reste du contenu public d'avant son retrait, et le résumé d'équipe embarqué ne porte alors
ni identifiant ni URL de logo pour un appelant qui ne peut pas consulter l'équipe.

Deux ajouts du lot 1, issus de sa relecture, à ne pas défaire :

- **`V87` remet en « Équipe » tout le contenu des équipes privées** (modèles compris).
  `makeContentTeamOnly` n'existe que depuis le 28 septembre 2026 : une équipe passée en privé avant
  pouvait encore porter du contenu non « Équipe », que seule la clause retirée cachait.
- **Les images d'une entité « Public » d'une équipe privée sortent sous le préfixe
  `public_unlisted`** (`AssetService.buildImageUrl`), qui porte `noindex` : le préfixe `public` est
  laissé indexable par `ApiNoIndexFilter`, ce qui contredirait D1. Étendu le même jour à la règle
  d'indexation complète : le préfixe `public` ne sert que pour une entité « Public » d'une équipe
  « Public », si bien que les images d'une équipe non répertoriée passent aussi en `noindex`,
  comme ses pages (`WEB-4`).

`makeContentTeamOnly` ne change pas (D3). Avec le drapeau, une équipe passée en privé peut ensuite
rouvrir entité par entité.

### 4.4 La compatibilité des entités associées (lot 3)

Les seules associations entre entités à visibilité : `Ride.route`, `RideGroup.route`, `Trip.route`,
`TripStage.route`. Une étape hérite la visibilité de son voyage ; un modèle n'a pas de parcours ; un
lieu n'a pas de visibilité.

**Invariant : un conteneur non `TEAM` n'utilise que des parcours non `TEAM`.** Un composant unique
le vérifie dans les deux sens, à la place des deux `getRoute` de `RideService` et `TripService`.

- **Enregistrer une sortie ou un voyage non `TEAM`** (création, modification de la visibilité, ou
  ajout d'un parcours « Équipe » à un conteneur déjà public) : si un de ses parcours est `TEAM`,
  refus `INCOMPATIBLE_VISIBILITY`, dont le détail liste les parcours en cause (slug, nom, visibilité
  actuelle, visibilité proposée). La requête rejouée avec `alignVisibility = true` monte ces
  parcours à `PUBLIC_UNLISTED` dans la même transaction.
- **Passer un parcours en `TEAM`** (`RouteService.updateRoute`) : s'il est utilisé par un conteneur
  non `TEAM`, non supprimé, refus `INCOMPATIBLE_VISIBILITY`, dont le détail liste ces usages.
  Pas de drapeau d'alignement dans ce sens (D6).
- `PUBLIC_RIDE_PRIVATE_ROUTE` et `PUBLIC_TRIP_PRIVATE_ROUTE` restent dans l'enum du contrat mais ne
  sont plus émis : un client d'une version antérieure qui reçoit le nouveau code affiche son
  message générique.

À trancher en codant : le brouillon. Un conteneur en brouillon non `TEAM` compte comme un usage
(il sera publié tel quel) ; un conteneur supprimé ne compte pas, et sa restauration repasse par la
même vérification.

### 4.5 Les droits calculés (lot 2)

Principe (D7) : le backend répond, le client affiche. Aucun client ne lit `team.visibility` ou
`team.role` pour décider d'un contrôle.

**Sur `TeamDetailDto`**

| Champ | Sens |
|---|---|
| `allowedContentVisibilities` | par type d'entité, la liste du §4.2 pour l'appelant ; un éditeur masque le champ quand elle n'a qu'une valeur |
| `defaultContentVisibility` | la valeur d'un formulaire de création (aujourd'hui recopiée de `team.visibility` à huit endroits) : `TEAM` pour une équipe privée, drapeau ou non |
| `publicContentAllowed` | pour l'écran d'administration de la plateforme |

**Sur chaque DTO d'entité** (sortie, parcours, post, voyage, étape, page, annonce), un bloc
`permissions` :

| Champ | Sens |
|---|---|
| `canEdit`, `canDelete` | ce que décident déjà les `*AccessChecker` pour `UPDATE` et `DELETE` |
| `canRegister` | sortie, voyage : membre et entité publiée ; **sur un détail**, faux aussi quand tous les groupes sont partis ou que le voyage est terminé (la condition même des endpoints d'inscription). En liste, pas de prise en compte du temps : aucune requête par ligne, la valeur peut différer du détail |
| `canComment`, `canSeeParticipants` | membre ou administrateur de la plateforme |
| `allowedVisibilities` | les valeurs que **cette** entité peut prendre : la liste de l'équipe, moins `TEAM` pour un parcours utilisé publiquement (§4.4) |
| `indexable` | la règle de `findIndexable` : entité `PUBLIC`, équipe `PUBLIC`, publiée |

**Sur le résumé d'équipe embarqué dans l'entité** : `accessible`, vrai quand `GET team` répondrait
à l'appelant. Le client n'appelle `GET team` que s'il est vrai.

Contraintes :

- **par page, jamais par ligne** (invariant du dépôt) : le rôle de l'appelant se résout une fois par
  page, comme `MemberNamesVisibility.teamsWithNames` ; les usages publics d'un parcours ne se
  calculent que sur le détail, pas sur les cartes de liste (où `allowedVisibilities` est absent) ;
- les `…QueryCountTest` restent verts sans être modifiés ;
- le bloc ne porte jamais un nom, un identifiant de membre ni un rôle : il ne dit que ce que
  l'appelant peut faire ;
- les `*AccessChecker` exposent la règle qu'ils appliquent et le bloc appelle la même ;
  `ContentPermissionsConsistencyTest` échoue s'ils divergent, modules désactivés compris.

Arbitrages du lot 2 (11 novembre 2026) : `TripService.joinTrip` refuse un voyage non publié pour
tout le monde, administrateur de la plateforme compris, comme les sorties ; la page « À propos » a
`canEdit` vrai (elle se modifie par l'équipe), `canDelete` faux et pas d'`allowedVisibilities` ; le
rôle de l'appelant est lu deux fois par requête de détail, ce que `API-177` supprimera.

### 4.6 Contrat

Tout est additif (champs nouveaux, un code d'erreur, un champ de requête optionnel) : `13.6.0` au
lot 1, **`13.7.0`** au lot 2, une version mineure de plus au lot 3. Les champs calculés sont
**requis** dans le contrat (décision du 11 novembre 2026) : le backend les renvoie toujours, un
client n'a pas de cas « absent » à gérer.
Compétence `contract-first-api`, puis régénération des deux clients. Une application mobile d'une
version antérieure continue de fonctionner : son éditeur masque le sélecteur en équipe privée et
renvoie la visibilité que l'entité avait.

### 4.7 Tests backend

À écrire avec le code, à lancer par le propriétaire :

- détail anonyme d'une sortie, d'un parcours, d'un post, d'un voyage et d'une étape publics en
  équipe privée : 200, sans nom ni avatar ; `…/participants` et commentaires refusés ;
- la même entité absente de `/api/routes`, des publications, du tableau de bord, du sitemap ;
- équipe privée sans drapeau : `INVALID_VISIBILITY` comme aujourd'hui ;
- `allowedContentVisibilities` pour chaque ligne de la table du §4.2, et par rôle ;
- montée d'une sortie avec parcours « Équipe » : refus listant les parcours, puis alignement avec
  `alignVisibility` ; groupes et étapes compris ;
- baisse d'un parcours utilisé publiquement : refus listant les usages ;
- `groupLeader_isNotTheRideCreator`, `MemberNamesVisibilityResourceTest` et les `…QueryCountTest`
  inchangés.

## 5. Site web (lot 4, `WEB-166`)

- **Éditeurs** (`RideEditor`, `RideTemplateEditor`, `RouteEditor`, `TripEditor`, `PostEditor`,
  `TeamPageForm`) : un composant de sélection partagé, qui lit `allowedContentVisibilities` à la
  création et `permissions.allowedVisibilities` à la modification. Les valeurs initiales viennent
  de `defaultContentVisibility` (huit sites d'appel). Règle A2 au passage.
- **Confirmation d'alignement** (sortie, voyage) : sur `INCOMPATIBLE_VISIBILITY`, une boîte liste
  les parcours et leur nouvelle visibilité, puis rejoue avec `alignVisibility`. Sur un parcours, le
  refus liste les usages, avec un lien vers chacun.
- **Pages de détail sans l'équipe** : sortie, groupe, parcours, post, voyage, étape, page. Quand
  `team.accessible` est faux, pas d'appel à `GET team` ; l'en-tête et le fil d'Ariane utilisent le
  résumé embarqué, sans lien vers l'équipe. `teamAccess(team, …)` cède la place à `permissions`.
- **SSR** (`entry-server.tsx`) : le 404 posé sur l'échec de `GET team` ne doit plus couvrir une
  entité lue avec succès. Une équipe privée ouverte directement reste un 404.
- **Indexation** (`config/routeMeta.ts`) : `noindex` dès que `permissions.indexable` est faux, à la
  place de `notIndexable` et de `withIndexing`, qui lisaient l'équipe en cache.
- **Formulaire d'équipe** : confirmation avant le passage en privé (D3, A3) ; interrupteur
  `publicContentAllowed` dans le bloc de l'administrateur de la plateforme.
- **Textes** (épicènes, BRANDING.md §8) : libellé de l'interrupteur, aide du sélecteur en équipe
  privée (« accessible à qui a le lien, hors des listes »), boîtes de confirmation,
  `errors.api.INCOMPATIBLE_VISIBILITY`.
- **e2e** (pile `tribly-e2e`, feu vert à demander avant tout run) : un anonyme ouvre le lien d'une
  sortie publique d'une équipe privée ; l'équipe elle-même répond 404 ; l'alignement d'un parcours.

## 6. Application mobile (lot 5, `MOB-137`)

- **Éditeurs** (`ride_editor_page`, `ride_template_editor_page`, `route_editor_page`) : même lecture
  des champs calculés ; `teamOnly` disparaît.
- **Confirmation d'alignement** dans l'éditeur de sortie ; refus listant les usages dans celui de
  parcours.
- **Retour arrière** : un lien profond vers l'entité d'une équipe non consultable ne reconstruit
  plus `TeamHomePage` sous l'écran de détail (aujourd'hui « Équipe indisponible »).
- Les écrans de détail lisent `permissions` à la place de `teamMembershipProvider` pour leurs
  bandeaux et actions. L'anonyme reste renvoyé vers la connexion : seul le non-membre connecté est
  concerné.
- Patrol : un non-membre ouvre le lien d'une sortie publique d'une équipe privée.

## 7. Ordre et tailles

| Lot | Contenu | Taille |
|---|---|---|
| 1 | drapeau, `V87`, règle unique d'écriture, lecture par lien | S |
| 2 | champs calculés, contrat `13.7.0`, clients régénérés | M |
| 3 | invariant de compatibilité, `INCOMPATIBLE_VISIBILITY`, `alignVisibility` | S |
| 4 | site web | M |
| 5 | application mobile | S |

Les lots 1 à 3 se déploient seuls : sans client à jour, aucune équipe n'a le drapeau et rien ne
change. Le drapeau n'est à poser sur une équipe de production qu'après le lot 4.

## 8. Ce qui reste dehors

- **Lister ou indexer le contenu public d'une équipe privée** (D1). À rouvrir sur une demande
  réelle ; il faudrait ouvrir les branches liste de `getPublicEntity` et `findIndexable`.
- **`SEC-51`** : relevé par l'audit, sans lien avec l'assouplissement.
- **Rejoindre une équipe privée depuis le lien d'une de ses sorties** : l'invitation reste la seule
  entrée (`UserTeamAccessChecker`, `JOIN`).
