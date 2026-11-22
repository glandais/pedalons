# Retoucher un parcours existant : viser une distance, déplacer l'arrivée

Écrit le 22 novembre 2026. **État : décidé le 22 novembre 2026 (§9) ; lot 0 mesuré le 22 novembre 2026
(§10 bis) : aucun critère tenu tel quel, lot 2 non ouvert, lot 1 à ouvrir sous une forme étroite si le
propriétaire le décide.** Ledger `API-212`.
Suite de [`2026-11-15-generateur-parcours-osm.md`](2026-11-15-generateur-parcours-osm.md)
(`API-207`) : même moteur (osm-route-details, crate `ord-loops`), même façade côté Pédalons.

Ce qui est marqué **(lu)** a été relu dans le code le 20 ou le 22 novembre 2026 (osm-route-details
`1.14.0`, contrat Pédalons `16.1.1`) ; **(mesuré)** renvoie à un relevé existant, cité ; **(estimé)**
et **(proposé)** sont à confirmer au lot 0. Ni secret, ni coordonnée d'équipe réelle ici.

---

## 1. En une page

Le générateur part toujours de zéro : un départ, une arrivée facultative, un cap, une distance. Il
ne sait pas reprendre un parcours. Deux demandes ne passent donc par aucun outil aujourd'hui, sinon
par le planificateur, à la main, point de passage par point de passage :

| Demande | Ce que la personne donne | Ce qu'elle attend |
|---|---|---|
| **Viser une distance** | un parcours, une cible en km (plus ou moins que l'actuel) | le même parcours, à la cible, changé à un seul endroit |
| **Déplacer l'arrivée** | un parcours, un point | le même parcours jusqu'à l'endroit où il faut le quitter, puis un raccord ; la distance finale n'est pas un objectif |

Le principe retenu est une **greffe locale** : un tronçon du parcours est remplacé, le reste est
rendu **dans sa géométrie d'origine, au point près**. Le moteur n'a à poser sur son graphe que les
deux coutures ; ce qu'il ne reconnaît pas (un chemin absent d'OSM, un bac) reste intact.

Le moteur a déjà presque tout **(lu)** : la recherche d'un aller simple à distance visée
(`generate_inner` avec `end`), les deux arbres (`tree_forward`, `tree_backward`), l'A* point à point
(`astar_p2p`), le contrôle (`verify.rs`, et le contrôleur indépendant `ord-loops-check`), et
l'appariement d'un parcours au graphe (`ord-graph-match`, celui de la surcouche de nuit). Il manque
trois choses : une **entrée « parcours »**, une **interdiction qui dure** des arêtes gardées, et un
**contrôle du parcours recollé**.

---

## 2. Ce qui existe et ce qui manque

| Brique | État | Où |
|---|---|---|
| Aller simple de A à B à distance D, ±10 % | existe ; lentille seule, ni triangle ni couloir **(lu)** | `ord-loops/src/generate.rs` |
| Refus quand D < 1,05 × le plus court chemin | existe (`DistanceTooShort`) **(lu)** | `feasibility` |
| Arbre retour depuis un point, A* point à point avec arêtes interdites | existent **(lu)** | `search.rs` |
| Interdire des arêtes pendant toute une recherche | **manque** : `Ban` est remis à zéro à chaque essai, `Forbidden` ne porte que des virages **(lu)** | `search.rs` |
| Contrôle d'un parcours | existe pour un parcours **entièrement** sur le graphe ; **manque** pour un parcours recollé | `verify.rs`, `ord-loops-check` |
| Parcours d'équipe → arêtes du graphe | existe : `network_edges` de chaque parcours, apparié par `ord-graph-match` ; **99,22 %** des km appariés **(mesuré, `ord-graph-lot1-mesures.md`)** | dépôt de la surcouche |
| Savoir si l'appariement est **continu** le long d'un parcours | **inconnu** : le relevé compte des km, pas des trous | lot 0 |
| Endpoint « retoucher » | **manque** des deux côtés | §6, §7 |
| Écran | **manque** ; le générateur n'existe que sur le site, pas dans l'app **(lu)** | §8 |

---

## 3. La greffe

Un parcours `R` de longueur `L` est une polyligne. Posé sur le graphe, il devient une suite de
**plages appariées** (arêtes orientées du graphe) séparées par des **trous** (non apparié).

Une retouche choisit deux **coutures** `i < j` sur des plages appariées, cherche un nouveau chemin
de `i` à `j`, et rend `R[0..i] + chemin + R[j..]`. Pour l'arrivée, `j` est le nouveau point et la
fin de `R` disparaît.

Règles communes :

- **Une couture tombe sur un nœud du graphe**, dans une plage appariée d'au moins 200 m de part et
  d'autre **(proposé)**, pour que le virage à la couture se juge sur des arêtes connues.
- **Les arêtes gardées sont interdites** au nouveau chemin, sauf près des coutures, où la règle de
  queue du moteur s'applique (reprise tolérée sur 15 % de la distance, `tail_reuse_share`) **(lu)**.
  Dans un trou, rien n'est interdit : la garantie « pas de route prise deux fois » devient « au
  mieux », et la réponse le dit (`unmatched_m`).
- **Le parcours recollé est contrôlé en entier** là où il est apparié : continuité aux coutures,
  virage serré ou demi-tour à la couture, arête prise plus de deux fois, croisements.
- **Trois propositions au plus**, différentes entre elles, comme le générateur.
- **Rien n'est écrasé** : la réponse est une proposition, ouverte dans le planificateur (§8).

Le repli écarté pour l'instant : régénérer tout le parcours en traitant l'original comme une
surcouche d'équipe d'un seul parcours. Moins de code, mais aucune garantie sur ce qui est gardé ;
à rouvrir seulement si la greffe échoue trop souvent sur les gros écarts (§4.3).

---

## 4. Viser une distance

### 4.1 Méthode

`Δ = D′ − L`. Pour une fenêtre `(i, j)` de longueur `ℓ`, le moteur cherche un aller simple de `i` à
`j` de longueur `ℓ + Δ`, arêtes gardées interdites : c'est la lentille existante (un point de
demi-tour `n` qui minimise `|T1(n) + ρ·T2(n) − (ℓ + Δ)|`, l'aller dans l'arbre, le retour par A*).

- **Rallonger** : `ℓ + Δ > ℓ`, le détour sort du parcours et y revient.
- **Raccourcir** : `ℓ + Δ < ℓ`, borné par la corde : pas en dessous de 1,05 × le plus court chemin
  de `i` à `j` **(lu)**. Un gros raccourcissement d'une boucle prend donc `i` sur l'aller et `j`
  sur le retour, et abandonne la partie lointaine.

### 4.2 Choix de la fenêtre

Automatique par défaut **(proposé, à régler au lot 0)** :

- fenêtres glissantes de longueur `ℓ ∈ {1,5 ; 3} × |Δ|` pour rallonger ; pour raccourcir, les
  couples `(i, j)` dont `ℓ − plus court chemin(i, j)` approche `|Δ|` (un arbre par `i` candidat) ;
- jamais dans les premiers et derniers 5 % du parcours (les rues du départ et de l'arrivée) ;
- une douzaine de fenêtres au plus par demande, tirées par la graine, pour tenir le budget ;
- note d'une proposition : écart à la cible, part gardée, puis la note du moteur (goût, équipe).

En option, la personne **désigne le tronçon** à changer (deux points sur le profil ou la carte) :
une seule fenêtre, pas de tirage.

### 4.3 Limites connues

- **Tolérance** : ±10 % de la distance demandée **au tronçon**, soit bien moins sur le total ; la
  réponse donne la distance obtenue. Critère visé : `|L′ − D′| ≤ 3 %` de `D′` **(proposé)**.
- **Forme** : l'aller simple ne joue ni triangle ni couloir. Un détour de 10 km sera propre ; un
  rallongement de 40 km sur un tronçon court peut donner une épingle. Au-delà de `|Δ| > 30 %` de
  `L` **(proposé)**, la réponse est un refus explicite (`change_too_large`) plutôt qu'un mauvais
  parcours, et l'écran renvoie au générateur. À revoir avec les relevés.
- **Distance du tronçon** : la borne basse du service (5 km **(lu)**) vaut pour une génération, pas
  pour une greffe ; la greffe a la sienne (1 km **(proposé)**).

---

## 5. Déplacer l'arrivée

Pas de cible : le critère est de **changer le moins possible**.

1. Un arbre retour depuis la nouvelle arrivée `E′`, dans un disque autour du parcours et de `E′`.
2. Pour chaque nœud `k` des plages appariées, le coût du raccord `k → E′` se lit dans l'arbre.
3. `k` minimise **longueur abandonnée + longueur du raccord**.
4. Le raccord est contrôlé (pas de demi-tour en `k`, pas de reprise du préfixe hors queue) ; refusé,
   il est recherché par `astar_p2p`, préfixe interdit.

Ce que le critère donne :

| `E′` | Résultat |
|---|---|
| à côté de l'ancienne arrivée | presque tout est gardé, un court raccord |
| au-delà du point lointain d'une boucle | le parcours est quitté vers le point lointain, le retour disparaît |
| près d'un point du milieu du parcours | tout est gardé, un raccord en fin (la boucle complète, puis `E′`) |
| le départ (fermer un aller simple en boucle) | même calcul ; la règle de queue borne la reprise de l'aller |

Jusqu'à trois variantes quand elles diffèrent : le minimum, « tout garder puis raccorder », et
« quitter au plus près de `E′` ». **Déplacer le départ** serait le même calcul en miroir (arbre aller
depuis `S′`, suffixe gardé) : hors de la première version (§9, D5), sans rien qui l'empêche ensuite.

---

## 6. osm-route-details

### 6.1 Entrée : poser le parcours sur le graphe

L'entrée est le **document `network_edges`** du parcours, celui que le backend dépose déjà chaque
nuit pour la surcouche (une ligne NDJSON par trace) **(lu)**, plus la polyligne. Raisons : la chaîne
est en production, son taux est mesuré, et le moteur ne refait pas le recalage sur la rue.

Deux inconnues, toutes deux pour le lot 0 :

- **la continuité** : combien de trous par parcours, de quelle longueur, et où (les 0,78 % de km non
  appariés sont surtout des sens interdits et des arêtes absentes d'OSM **(mesuré)** : sont-ils
  étalés ou groupés ?) ;
- **l'ordre** : l'appariement de la surcouche compte des passages ; la greffe a besoin de la suite
  **ordonnée** des arêtes le long de la trace, avec l'abscisse de chacune sur la polyligne.

Un parcours sans `network_edges` (une proposition du générateur pas encore enregistrée) ne se
retouche pas : §9, D1.

### 6.2 Moteur (`ord-loops`)

- `search.rs` : un second tampon d'interdiction, **posé pour la requête** et lu à côté de `Ban`.
- Deux fonctions publiques, `resize` et `move_end`, au-dessus de l'existant ; une
  structure d'entrée « parcours posé » (plages, trous, abscisses).
- `verify.rs` : contrôle du parcours recollé (§3) ; `ord-loops-check` suit, en restant indépendant.
- Invariant à garder : **une génération ordinaire rend les mêmes parcours qu'avant, au bit près**
  (les tests de non-régression du moteur le vérifient déjà version après version).

### 6.3 Service (`ord-server`)

Un endpoint de plus, ajout pur au contrat (version mineure suivante) :

```
POST /v1/generator/routes/edit
{
  "polyline": "…",                 // précision 6
  "network_edges": { … },          // le document de la trace
  "ride_type": "road", "cursor": 0.25, "seed": 0,
  "operation": { "resize": { "distance_m": 95000, "window": null } }
             | { "move_end": { "point": {…} } }
}
→ routes[] : polyline complète, distance_m, changed { from_m, to_m, new_m },
             kept_share, unmatched_m, et les champs de RouteV1
```

Mêmes en-têtes (`Ord-Namespace-Key`, `Ord-Team`), même file et même budget que la génération,
mêmes problèmes RFC 9457, plus `change_too_large`, `no_seam` (pas de plage appariée où coudre) et
`route_off_coverage`. `capabilities.generator.edit` annonce les opérations. Rien de la requête
n'est journalisé, comme aujourd'hui.

---

## 7. Backend Pédalons

- `POST /api/teams/{teamSlug}/routes/{routeId}/retouch` **(nom proposé)** : `targetDistanceKm` ou
  `end`, `discovery`, `seed` ; réponse de la forme de `RouteGeneratorResponse`, avec le
  tronçon changé par proposition. Contrat : version mineure.
- Droits : lire le parcours **et** `PlannerAccess.check`, comme le générateur. Même interrupteur
  `enabled`, même fenêtre de 30 demandes par 15 min et par personne (compteur partagé), aucun quota
  tiré : le quota est celui de l'enregistrement dans le planificateur.
- `RouteGeneratorGateway` gagne l'appel ; `GeneratedRouteSanity` et `GeneratedRouteAscent`
  s'appliquent tels quels aux propositions.
- Un parcours dont `network_edges` manque ou date d'avant sa dernière modification : refus propre,
  pas de calcul à la volée dans la requête (D1).
- Pile e2e : pas de graphe, l'endpoint répond `GENERATOR_UNAVAILABLE` ; les specs bouchonnent.
- Aucune migration.

---

## 8. Écrans

Site d'abord (le générateur n'a pas d'écran dans l'app) :

- sur la page d'un parcours, pour qui peut planifier : **« Ajuster la distance »** (un champ en km,
  borné à ±30 %) et **« Déplacer l'arrivée »** (un point posé sur la carte, ou un lieu de l'équipe) ;
- aperçu : l'original en fond, la proposition par-dessus, **le tronçon changé surligné**, distance et
  D+ avant → après, jusqu'à trois propositions et « autres propositions » (graine) ;
- **« Ouvrir dans le planificateur »** : même chemin que le générateur (`gpxFromLine`, import), où
  la personne enregistre un nouveau parcours ou remplace l'ancien. Aucun enregistrement direct.

Textes épicènes (BRANDING §8.2). Mobile : après le planificateur mobile
([`2026-11-15-planificateur-parcours-mobile.md`](2026-11-15-planificateur-parcours-mobile.md)), pas
dans ce plan.

---

## 9. Décisions du propriétaire (22 novembre 2026)

| # | Question | Décision | Écarté |
|---|---|---|---|
| D1 | Quels parcours ? | **Tout parcours d'équipe enregistré** ayant ses `network_edges` à jour. Une proposition du générateur non enregistrée se régénère (graine), elle ne se retouche pas | Retoucher aussi les propositions (calcul des `network_edges` à la volée ou polyligne seule) ; les propositions seulement |
| D2 | Que devient une proposition acceptée ? | **Elle s'ouvre dans le planificateur**, comme une proposition du générateur ; rien n'est écrasé sans geste explicite, le quota d'enregistrement existant s'applique | Un enregistrement direct en nouveau parcours ; le remplacement du parcours (les sorties planifiées dessus changeraient de tracé) |
| D3 | Gros écarts de distance | **Refus explicite et renvoi au générateur** au-delà d'un seuil (±30 % proposé, réglé au lot 0) ; le champ de distance est borné | Régénérer autour de l'original ; greffer sans seuil |
| D4 | Qui choisit le tronçon changé ? | **Le moteur**, automatiquement ; la désignation à la main seulement si l'automatique déçoit, après la première version | Les deux dès le départ ; à la main seulement |
| D5 | Contenu de la première version | Viser une distance, déplacer l'arrivée, et **l'arrivée choisie parmi les lieux de l'équipe** en plus du point posé sur la carte | Déplacer le départ ; le raccourci « fermer en boucle » |

---

## 10. Lots

| Lot | Dépôt | Contenu | Sortie |
|---|---|---|---|
| **0. Mesure** | osm-route-details (`tools/ord-loops-bench`), export hors dépôt | Continuité et ordre de l'appariement sur les vrais parcours ; prototype des deux opérations hors service ; fenêtres du §4.2 réglées | Un relevé `…-mesures.md`, les seuils **(proposé)** de ce plan confirmés ou changés, décision de poursuivre |
| **1. Arrivée** | osm-route-details | Entrée « parcours posé », interdiction durable, `move_end`, contrôle du recollé | Tests du moteur, 0 refus du contrôleur indépendant sur le banc |
| **2. Distance** | osm-route-details | `resize`, choix des fenêtres | Idem, plus l'écart à la cible |
| **3. Service** | osm-route-details | Endpoint, contrat, `capabilities`, mise en service dans la pile partagée (entrée `OPS`) | Image publiée, génération ordinaire inchangée au bit près |
| **4. Backend** | Pédalons | Endpoint, passerelle, droits, limites, tests | Contrat mineur, clients régénérés |
| **5. Site** | Pédalons | Les deux actions, l'aperçu, l'ouverture dans le planificateur, e2e bouchonné | Entrée `WEB` |

Critères du lot 0 pour continuer **(proposés)** : une couture possible à moins de 1 km de tout
point pour 95 % des parcours ; arrivée déplacée sans refus du contrôleur dans 95 % des essais ;
distance tenue à 3 % dans 90 % des essais pour `|Δ| ≤ 25 %` ; temps au P90 sous 2 s.

---

## 10 bis. Lot 0 : ce que les mesures ont donné (22 novembre 2026)

Conception et relevé dans osm-route-details : `docs/design/technique/ord-retouche-lot0.md` et
`ord-retouche-lot0-mesures.md` (sous-commandes `retouche-continuity` et `retouche-play` du banc, prototypes
sous la feature `probe`, générations ordinaires inchangées). 3 355 traces réelles, 85 482 essais de
`move_end`, 7 044 demandes de `resize` **(mesuré)**.

| Critère (§10) | Mesuré | Verdict |
|---|---|---|
| Couture à 1 km ou moins de tout point, 95 % des parcours | 54,2 % ; 70,8 % au mieux (marge de 50 m) ; 95 % demanderait 2,6 km | non tenu, **et mal posé** : il ne prédit pas le succès de `resize` |
| Arrivée déplacée sans refus du contrôleur, 95 % | 79,5 % ; 89 % des refus sont un virage serré à la couture que le moteur ne voit pas (le cap de la jambe gardée) ; sans eux, 96,3 % **(calculé)** | non tenu, cause unique et localisée |
| Distance à ±3 %, 90 %, pour \|Δ\| ≤ 25 % | 88,9 % pondéré (80,1 % brut) ; allongement ~97 %, **raccourcissement 53 à 67 %** (47 % pour les allers simples à −10 %) | à la limite ; le raccourcissement échoue |
| P90 sous 2 s | `move_end` 127 ms ; `resize` 4,5 s avec contrôles (18 s au-delà de 200 km) | tenu / non tenu |
| (ajouté) Ordre des jambes fiable | 5,0 % des traces ont une anomalie d'ordre | non tenu : à rejeter à l'entrée |

Ce que les chiffres disent des seuils proposés : marge de couture **100 m** plutôt que 200 (+12 points
sur le premier critère, rien de perdu ailleurs) ; ±3 % se garde ; ±30 % est un choix de produit, sans
falaise mesurée. Le **recalage géométrique** du §11 n'est pas justifié : les trous d'appariement ont une
corde de 32 m au P50. L'interdiction des arêtes gardées doit rester (sans elle, −5,8 points sur la
distance).

**Recommandation du relevé** (au propriétaire de trancher) : ne pas ouvrir le lot 2 tant que le
raccourcissement et le temps de `resize` ne sont pas réglés ; ouvrir le lot 1 sous une forme étroite :
cap d'arrivée de la jambe gardée donné au moteur en premier, traces à anomalie d'ordre refusées, marge
de 100 m, critère de couture remplacé par une condition sur les paires de coutures offertes ; sortie :
arrivée déplacée sans refus dans 95 % des essais.

---

## 11. Risques

- **Appariement troué là où l'on veut coudre** (centre-ville, pistes en sens interdit) : la greffe
  se décale ; si le lot 0 montre des parcours sans couture utilisable, l'entrée doit être complétée
  (recalage géométrique direct de la polyligne), ce qui est un autre chantier.
- **Parcours à cheval sur le bord du graphe** ou plus long que la fenêtre montée : la fenêtre se
  dimensionne sur le tronçon, pas sur le parcours, mais l'interdiction des arêtes gardées ne vaut
  que dans la fenêtre.
- **`network_edges` périmé** après une modification du parcours : coutures fausses. Le backend
  refuse plutôt que de coudre sur un document qui ne correspond plus à la trace (§7).
- **Attente déçue sur la forme** pour les grands rallongements (§4.3) : d'où le refus à ±30 %.
- **Charge** : une retouche lance jusqu'à une douzaine de petites recherches ; elle passe par la
  même file que la génération et compte dans la même fenêtre de demandes.
