---
id: MOB-44
title: "Toucher l'équipe depuis un détail laissait une page vide"
status: done
group: "Défauts trouvés par la recette du 4 octobre 2026"
---

## Livré

`MOB-44` **Toucher l'équipe depuis un détail laissait une page vide** — une page de détail
(sortie, parcours, publication, voyage, annonce) vit sur le navigateur racine, au-dessus du shell ;
y faire `context.push` d'une page **d'onglet** (l'équipe, une de ses sections, de n'importe quelle
équipe) recréait la branche sous le détail avec des clés de page déjà prises : assertion
`!keyReservation.contains(key)` en debug, écran vide et `pop` qui lève, « parfois » en release.
`pushLocation` (`core/utils/push_location.dart`) garde le `push` partout ailleurs et, dans ce seul
cas, ouvre la page dans son onglet par `openWithHierarchy`, la pile d'un lien profond (Équipes →
équipe → section) ; tous les `context.push(Paths.team(…))` passent par lui. Test :
`test/core/utils/push_location_test.dart`, sur un routeur de même forme et les vrais chemins —
ses trois cas « depuis une sortie » échouent sans le correctif. **À ne pas défaire** : ne pas
revenir à `context.push` vers une page du shell depuis une page plein écran ; la pile affichée se
lit en déroulant les `ImperativeRouteMatch`, jamais par `currentConfiguration.uri`, qui reste sur
la base après un `push` impératif.
