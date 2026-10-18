# Suppression des points et des ancres du planificateur — étude

Lu le 18 octobre 2026 sur `feat/routing-web-mobile`, glisser d'une ancre au doigt compris (commit
`66932325`). Chemins relatifs à `frontend/src/`. Les mesures chiffrées viennent d'une sonde Vitest
jetable, avec un routeur simulé et des tracés synthétiques, qui n'est pas versée au dépôt : les cas
de test à écrire sont décrits au §5. Les décisions du propriétaire qui ont suivi cette étude sont
dans le plan, tâche B12 : [`../plans/2026-10-17-editeur-parcours-web.md`](../plans/2026-10-17-editeur-parcours-web.md).

## 1. Comportement actuel

### Le mécanisme commun : des bornes qui dépendent du zoom

- `computeRoute` simplifie le tracé par Douglas-Peucker à 5 m (`lib/planner.ts:85`). Chaque point
  gardé reçoit `zoom = round(log2(R·cos(lat) / écart))` (`:59-66`, `:88`). Un point manual vaut
  100 000 m dans la récursion (`:297`), il découpe donc toujours le tracé. Le premier et le
  dernier point deviennent manual (`:275`, `:278`).
- Le calque `anchor-points` montre les points non manual dont `zoom ≤ zoom de la carte`
  (`RoutePlanner.tsx:649-661`, filtre `:850`). En pixels, comme le zoom MapLibre se compte en
  tuiles de 512 px, un point blanc apparaît quand son écart dépasse 512/2π ≈ 81 px à l'écran.
  L'arrondi place le seuil entre 58 et 115 px.
- `findAnchorStartPoint` et `findAnchorEndPoint` (`hooks/useRoutePlanner.ts:59-92`) partent du
  point visé, excluent ce point, et remontent jusqu'au premier point qui est manual **ou**
  visible au zoom courant (`p.zoom <= zoom`, `:68`, `:88`). Sans tel point, ils renvoient le
  premier ou le dernier point (`:71`, `:91`). Tous les gestes de modification passent par ces
  deux fonctions, avec `getMapZoom()` (`RoutePlanner.tsx:118`).

### Suppression d'un point manual

Le geste passe par le clic droit (`RoutePlanner.tsx:363-381`), les touches Suppr et retour arrière
(`:921-926`) ou le menu d'appui long (`:289-293`). Il appelle
`removeControlPoint(point.idx, directKey, zoom)` (`useRoutePlanner.ts:228-237`), puis
`remove` (`planner.ts:194-232`).

- **Point intermédiaire M.** `before` va jusqu'à la borne gauche, puis vient un segment routé
  borne → borne, puis `after` (`:224-231`). Cela coûte **1 requête**, et 0 en ligne droite ou si
  les bornes sont à moins de 5 m l'une de l'autre (`:242-256`). Tout ce qui est entre les bornes
  disparaît : M et les ancres cachées. Les ancres visibles restent. Au zoom large, les bornes sont
  les points manual voisins. Zoomé, ce sont des ancres proches de M, posées sur le détour qui
  menait à M.
  *Sonde* : un tracé dessiné A → M → B, M à 3,3 km du chemin direct. Supprimé au zoom 10, le
  détour disparaît (latitude max 47,0136, 8,3 km). Supprimé aux zooms 12 à 16, **le point
  disparaît mais le détour reste** (latitude max ≥ 47,030, 10,7 à 10,9 km).
- **Départ.** Il n'y a pas de borne gauche, donc le tracé est coupé jusqu'à la borne droite
  (`planner.ts:205-209`), sans requête. La borne devient le nouveau départ, puisque Douglas-Peucker
  la passe manual. Zoomé, le départ recule jusqu'à l'ancre la plus proche. Au zoom large, tout le
  premier tronçon disparaît.
  *Sonde* : sur un tracé importé de 40,7 km (sinusoïde de 300 m d'amplitude, 58 points, 2 manual),
  supprimer le départ aux zooms 9 à 12 **ne laisse qu'un point, l'arrivée**, car aucune ancre
  n'est visible et la recherche tombe sur le dernier point (`useRoutePlanner.ts:91`). Au zoom 14,
  il reste 37,0 km. Le cadrage initial d'un tel tracé sur un téléphone est vers le zoom 9.
- **Arrivée.** C'est le cas symétrique (`planner.ts:212-216`), sans requête.

### Insertion, glisser du fantôme, glisser d'un point ou d'une ancre

Ces gestes passent tous par `insert(start, p, end)` (`planner.ts:137-191`). Tout ce qui est entre
`start` et `end` est remplacé par deux segments routés, start → p et p → end (**2 requêtes**, 1 à
une extrémité, 0 en ligne droite).

- Le toucher sur le tracé utilise le sommet le plus proche (`around`, `RoutePlanner.tsx:424`),
  puis les bornes au zoom courant (`:427-430`).
- Le fantôme à la souris (`:530-548`, relâché `:550-562`) fige les bornes au `mousedown`.
- Le glisser d'un marqueur (`:326-337`, `:348-361`, `updateControlPoint` → `insert`,
  `useRoutePlanner.ts:219-226`) borne lui aussi au zoom. Zoomé, déplacer M de 2 km ne re-route
  qu'entre deux ancres voisines de l'ancienne position : le tracé fait encore un crochet vers
  l'ancienne position de M.
- Le glisser d'une ancre au doigt (`:579-637`) se comporte de la même façon. Un toucher bref sur
  une ancre annule le glisser (`:633-636`), puis le clic insère au point touché (2 requêtes).
- *Sonde* : sur le tracé importé, une insertion au milieu remplace 56 points sur 58 aux zooms 9 et
  11, et 7 au zoom 13.

### Deux défauts trouvés en chemin

- Le sommet le plus proche peut être **un point manual**. Les bornes l'excluent
  (`useRoutePlanner.ts:66`, `:86`), donc un toucher sur le tracé à plus de 22 px d'un marqueur,
  ou un fantôme à plus de 20 px (`RoutePlanner.tsx:477-487`), *remplace* ce point au lieu d'en
  ajouter un.
- Un second doigt posé pendant le glisser d'une ancre ne l'annule pas. Le glisser sort sans rien
  faire quand il y a plus d'un doigt (`:582`), et le relâchement insère quand même.

### Pourquoi le résultat surprend

Le même geste n'a pas la même portée selon le zoom, et rien ne montre cette portée avant le
toucher ou le clic droit. Les bornes vertes ne s'affichent que pendant un glisser
(`:1011-1050`). Le recalcul ajoute un autre effet. Douglas-Peucker est relancé sur tout le tracé,
et l'intervalle entre deux points manual qui contient la modification change de hiérarchie. Dans
la sonde, une insertion près du départ change le niveau de 15 des 49 ancres restantes, dont des
ancres lointaines. Des points blancs apparaissent ou disparaissent ailleurs, et la portée du
geste suivant change.

## 2. La demande, en règles testables

**Ce que demande le propriétaire, reformulé.** Il distingue deux sortes de points. Un point
numéroté porte une intention de l'auteur, et le supprimer doit défaire *cette intention-là*,
quel que soit le zoom. Un point blanc est une poignée sur la géométrie, et le supprimer doit
lisser *ce que l'on voit*, entre les poignées voisines.

**Constat qui oriente tout.** Sur un tronçon routé, une ancre n'est qu'un sommet du chemin
choisi par le routeur. Re-router entre deux de ses voisines redonne à peu près le même chemin,
puisqu'un sous-chemin d'un plus court chemin est un plus court chemin. Supprimer une telle ancre
coûte donc une requête pour rien. Les ancres n'ont de sens que sur une géométrie **importée**.

**Proposition : marquer la provenance.** On ajoute `imported: boolean` à `RoutePoint`. Il vaut
vrai pour les points de `createRoute` (le tracé chargé) et faux pour tout ce que produisent
`router()`, `add` et `insert`. Le champ survit à Douglas-Peucker, qui garde les objets, et aux
instantanés, qui copient `{...p}`. On en tire deux bornes pures, à placer dans `lib/planner.ts`
pour les tester :

- `legBounds(i)` : en partant de i, le premier point manual **ou importé**, sans zoom ;
- `spanBounds(i, zoom)` : le premier point manual **ou importé et visible** (`zoom ≤ z`). Les
  points routés sont toujours sautés.

| Règle | Geste | Bornes | Requêtes |
|---|---|---|---|
| R1 | Supprimer un point manual intermédiaire | `legBounds`, sans zoom | 1, ou 0 en ligne droite |
| R2 | Déplacer un point manual | `legBounds` | 2, ou 1 à une extrémité |
| R3 | Supprimer le départ ou l'arrivée | coupe jusqu'à `spanBounds` ; refus si le tracé tomberait sous 2 points | 0 |
| R4 | Supprimer une ancre importée | `spanBounds` au zoom du début du geste | 1, ou 0 en ligne droite |
| R5 | Insérer, glisser le fantôme, glisser une ancre | `spanBounds` | 2 |
| R6 | Ancre sur un tronçon routé | pas de suppression proposée ; elle reste une poignée de glisser | — |

**Les questions de la demande, une par une.**

- *Supprimer un point intermédiaire : re-router du point manual précédent au suivant ?*
  Sur un tracé dessiné, R1 fait exactement cela, en une requête. Sur un tracé importé, la règle
  « manual précédent → manual suivant » à la lettre détruirait l'import. Avec un point inséré
  entre le départ et l'arrivée d'un import, sa suppression re-routerait tout le parcours, soit
  56 points sur 58 dans la sonde. Sur une boucle, où le départ et l'arrivée sont à moins de 5 m,
  `router` rend une ligne droite de longueur nulle (`planner.ts:254-256`) et le tracé s'effondre.
  R1 s'arrête aux points importés où les tronçons de M se raccordent. Elle ne perd que ce que
  l'insertion de M avait déjà remplacé, et coûte la même requête.
- *Supprimer le départ ou l'arrivée : jusqu'au point manual suivant ou jusqu'à la première
  ancre ?* Sur un tronçon routé, `spanBounds` va au point manual suivant, sans dépendre du zoom.
  Sur un import, il n'y a aucune structure plus fine que les sommets. On coupe donc jusqu'à
  l'ancre visible, ce qui est le comportement actuel, mais on **refuse** de réduire le parcours
  à un point. Un parcours chargé avec seulement le départ et l'arrivée ne s'effondre plus : sans
  ancre visible, le geste est refusé et un message invite à zoomer.
- *Supprimer une ancre : ancres visibles, toutes les ancres, ou voisins du tracé ?* Il faut les
  **ancres visibles**. Avec toutes les ancres, quel que soit le zoom, les bornes seraient les
  sommets adjacents, et le geste serait invisible tout en coûtant une requête. Le zoom est ici
  légitime : l'auteur vise un point qu'il voit, entre des voisins qu'il voit. On fige le zoom et
  les bornes à l'ouverture du menu. L'ancre et les points cachés entre les bornes disparaissent
  et sont remplacés par des points routés (`imported = false`).
- *Cohérence des niveaux de zoom.* On recommande de ne relancer Douglas-Peucker qu'entre les
  bornes du geste et de garder le niveau des autres points. Les points blancs ne bougent alors
  plus ailleurs, et aucun point déjà simplifié n'est perdu en route : aujourd'hui chaque
  `computeRoute` re-simplifie le résultat précédent.
- *Rendre aussi l'insertion et le glisser indépendants du zoom ?* Oui sur les tronçons routés :
  R5 saute les points routés, donc insérer sur un tronçon dessiné re-route du manual précédent
  au suivant en passant par le nouveau point, à tout zoom. Cela supprime les crochets et le
  résultat qui change avec le zoom. Sur un import, on garde la portée visible : c'est le seul
  moyen d'y faire une retouche locale, et l'aperçu pendant le glisser montre cette portée. Le
  coût reste de 2 requêtes.
- *Annuler et rétablir.* Rien ne change. Chaque geste, y compris la suppression d'une ancre,
  passe par `executeRouteOperation` (`useRoutePlanner.ts:165-198`) : un instantané, une entrée
  d'historique, et une annulation gratuite. Si le tracé a changé entre l'ouverture du menu et
  le choix « Supprimer », on abandonne le geste.
- *Lignes droites (Ctrl, Alt).* Un tronçon droit n'a aucun point intermédiaire
  (`planner.ts:254-256`), donc il ne porte aucune ancre et ses bornes sont les points manual.
  Aujourd'hui le raccord suit la touche tenue au moment de la suppression
  (`RoutePlanner.tsx:378`) ; au doigt il est toujours routé. Avec B6 (`direct` sur
  `RoutePoint`), le raccord hériterait de ses tronçons : deux tronçons droits donneraient un
  raccord droit, sans requête. Alt + clic droit sur une ancre importée la remplace par une ligne
  droite entre ses voisines, sans requête, ce qui est utile pour effacer un saut de GPS.
- Défaut 1 corrigé en même temps : l'insertion vise le *segment* le plus proche, et non plus le
  sommet. Les bornes partent des deux extrémités de ce segment, qu'elles incluent quand elles
  sont manual.

## 3. Les gestes

**Avec une souris : clic droit sur l'ancre**, comme sur un marqueur. On écoute `onContextMenu`
sur la carte.

- La recherche de cible est celle de `handleMapTouchStart` (`:590-600`), mise en commun dans
  une fonction `anchorAt(point, rayon)`, avec un rayon d'environ 10 px (le cercle fait 5 px plus
  2 px de bord, `:853-855`). Un marqueur à moins de 20 px a la priorité, avec la même règle que
  `:477-487`.
- Il faut ignorer un `contextmenu` dont la cible est dans `.maplibregl-marker`. Les marqueurs
  sont des enfants du conteneur que MapLibre écoute (`maplibre-gl/src/ui/marker.ts:401`,
  `handler_manager.ts:225`), donc un clic droit sur un marqueur déclencherait aussi l'événement
  de la carte.
- On reprend le garde-fou Ctrl + clic de macOS (`RoutePlanner.tsx:377`).
- Une rotation au bouton droit ne déclenche pas de `contextmenu` dès que la souris a bougé
  (`map_event.test.ts:113-125`) : pas de conflit.
- Le survol seul ne suffit pas : il affiche déjà le fantôme (`:498-507`), et une action au survol
  n'a pas d'équivalent au doigt.

**Au doigt : appui long de 500 ms sur l'ancre, dans un rayon de 22 px** (`ANCHOR_TOUCH_RADIUS_PX`,
`:69`), qui ouvre le même `Menu` que pour un marqueur (`:1080-1110`). L'état du menu reçoit
`kind: 'marker' | 'anchor'`, avec les bornes et le zoom figés.

- **Conflit avec le glisser.** Le minuteur part dans `handleMapTouchStart`, après la prise
  (`:601-610`). `handleMapTouchMove` le coupe au-delà de 3 px, le même seuil que
  `ANCHOR_DRAG_TOLERANCE_PX` (`:71`). Au déclenchement, on abandonne le glisser mais on garde les
  deux bornes vertes, reliées par un tiret : c'est l'aperçu de la suppression.
- **Conflit avec le toucher bref.** Au relâchement d'un appui qui a ouvert le menu,
  `handleMapTouchEnd` doit appeler `originalEvent.preventDefault()` (`touchend` n'est pas passif,
  `handler_manager.ts:251`). Sinon, au-delà des 700 ms de grâce (`:402`), le clic produit au
  relâchement fermerait le menu, puis insérerait un point (2 requêtes).
- **Conflit avec l'appui long de MapLibre.** MapLibre 6.14 simule lui-même un `contextmenu` après
  500 ms d'appui (`map_event.ts:163-173`). Sur une ancre, notre `preventDefault` au
  `touchstart` (`:604`) rend `mapEvent` actif et remet ce minuteur à zéro
  (`handler_manager.ts:454-455`, `map_event.ts:86-91`). Ailleurs, il arrive à `onContextMenu`,
  qui doit l'ignorer quand il vient d'un doigt (`isFingerEvent`, `:228-232`).
- **Conflit avec le déplacement de la carte.** L'appui long n'ajoute rien de nouveau : un appui
  à moins de 22 px d'une ancre ne déplace déjà plus la carte (`:604`). Un second doigt doit
  couper le minuteur et le glisser (défaut 2).
- L'aide (`planner.help.remove.*`) ajoute une ligne « point blanc ». L'accès au clavier reste
  pour B7.

## 4. Coût en requêtes

| Geste | Avant | Après |
|---|---|---|
| Ajouter (premier point, ou ligne droite) | 1 (0) | identique |
| Insérer, fantôme, glisser une ancre | 2, 1 à une extrémité | identique ; portée de manual à manual sur un tronçon routé |
| Toucher bref une ancre | 2 | 2 |
| Déplacer un point manual | 2, 1 à une extrémité | identique ; bornes sans zoom |
| Supprimer un point manual intermédiaire | 1 | 1 ; plus de crochet restant |
| Supprimer le départ ou l'arrivée | 0 | 0 ; refus plutôt qu'effondrement |
| Supprimer une ancre importée | — | 1, ou 0 avec Alt |
| Supprimer une ancre routée | — | non proposé (sinon 1 requête pour presque rien) |
| Appui long annulé, menu fermé | 0 | 0 |
| Annuler, rétablir | 0 | 0 |

Le nombre de requêtes ne monte jamais, mais une requête de manual à manual est plus longue. Après
la suppression d'un point entre deux tronçons longs, la limite de longueur peut renvoyer
`ROUTING_SEGMENT_TOO_LONG` : le tracé reste intact et le message s'affiche.

## 5. Plan de tests

**`lib/planner.test.ts`.** Il faut un routeur simulé qui trace un arc, comme celui de la sonde, et
une fixture importée avec des ancres de niveaux connus.

1. `createRoute` marque les points importés, `add`, `insert` et `remove` produisent des points
   non importés, et l'instantané garde le champ.
2. `legBounds` sur un tracé dessiné rend les points manual voisins, au même résultat aux zooms
   0, 12 et 22.
3. R1 : sur A → M → C au zoom 16, une seule requête de A à C, et le détour disparaît. C'est la
   régression actuelle.
4. R1 sur un import : M inséré puis supprimé ; les points importés hors des bornes gardent le
   même `id` et les mêmes coordonnées. Sur une boucle importée, le tracé ne s'effondre pas.
5. R3 : sur un tracé dessiné, couper au point manual suivant à tout zoom, sans requête. Sur un
   import sans ancre visible, refus (tracé inchangé, aucune requête). Avec une ancre visible,
   coupe à cette ancre.
6. R4 : une requête entre les voisines visibles ; l'ancre et les points cachés disparaissent ;
   0 requête en ligne droite ; un signal déjà abandonné n'envoie rien.
7. R5 : une insertion sur un tronçon routé fait 2 requêtes, depuis A et vers B, à tout zoom.
   Sur un import, la portée visible est conservée (deux zooms, deux portées).
8. R2 : déplacer M utilise `legBounds`.
9. Défaut 1 : une insertion près d'un point manual garde ce point.
10. Si le recalcul est local : les niveaux hors des bornes ne changent pas.

Les cas existants de `remove` (`:390-457`) restent ; on y ajoute les vérifications de `from` et
`to`. Le cas « insert used as a move » (`:365-388`) passe à `legBounds`.

**`e2e/gpx-planner.e2e.ts`**, routeur simulé, requêtes comptées, `from` et `to` vérifiés :

- souris : clic droit sur le coin du tracé en L (fixture `:919-928`) → 1 requête entre ses
  voisins, autant de marqueurs ; Alt + clic droit → 0 requête ; clic droit loin d'une ancre → 0 ;
- souris : trois points, zoom avant sur le point 2, clic droit → requête du point 1 au point 3 ;
- doigt (Pixel 7) : appui long sur le coin → menu, « Supprimer » → 1 requête ; le relâchement
  n'insère rien ;
- doigt : appui puis déplacement de 4 px avant 500 ms → glisser, 2 requêtes, pas de menu ;
  toucher bref → insertion, 2 requêtes ;
- annuler après la suppression d'une ancre : 0 requête, l'ancre revient.

## 6. Questions au propriétaire

*Tranchées le 18 octobre 2026 : S1 à S3 et S5 selon les propositions ci-dessous, S4, S6 et S7 retenues par défaut ; voir le plan, tâche B12.*

| # | Question | Proposition | Effet de l'autre choix |
|---|---|---|---|
| S1 | Suppression d'un point manual sur un tracé importé | Bornes de raccord (`legBounds`, provenance), une requête | Manual à manual à la lettre : un point inséré puis supprimé re-route tout l'import, et une boucle s'effondre |
| S2 | Départ ou arrivée d'un import | Coupe jusqu'à l'ancre visible, refus si le tracé tombe sous 2 points | Jusqu'au point manual suivant : sur un import à deux points manual, il ne reste que l'arrivée ; ou interdire le geste et ne permettre que le glisser |
| S3 | Ancres sur un tronçon routé | Glisser oui, suppression non (absente du menu) | La proposer : une requête facturée pour un tracé à peu près identique |
| S4 | Insertion et glisser sur un tronçon routé | Sans zoom, de manual à manual | Garder le zoom partout : crochets et résultats qui changent avec le zoom |
| S5 | Clic droit sur une ancre | Suppression immédiate, comme pour un marqueur | Un menu, comme au doigt : un clic de plus, mais le menu est prêt pour C3, qui prévoit le clic droit sur le tracé |
| S6 | Raccord en ligne droite | Touche tenue maintenant ; hérité des tronçons avec B6 | Toujours routé : une requête même entre deux tronçons droits |
| S7 | Niveaux de zoom après un geste | Recalcul local entre les bornes | Recalcul global : des points blancs bougent loin du geste |
| S8 | Libellé du menu d'une ancre | « Supprimer le point », aide « point blanc » | « Lisser ici » : décrit l'effet, mais c'est un mot de plus à apprendre |
