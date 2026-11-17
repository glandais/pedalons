---
id: OPS-61
title: "Générateur de parcours : graphe de la France en service dans la pile partagée"
status: done
size: "S"
group: "Exploitation"
done: 2026-11-17
---

## Livré

`OPS-61` **Générateur de parcours : graphe de la France en service dans la pile partagée** (2026-11-17, sans
changement de contrat ; suite d'`API-207`, lot 6) — osm-route-details `1.9.1` puis `1.9.2` dans
`pedalons-shared`, limite du conteneur passée de 2G à 3G, le graphe de la France sous
`~/shared/data/osm-route-details-graph/` au nom `fr-2026-11-15` (données OSM du 15 novembre 2026, `graph.id`
`631bc5683561ed80`, 18 351 265 nœuds, 23 477 176 arêtes ; quatre fichiers, 4,1 Go, sommes SHA-256 contrôlées sur le
serveur, 0444). Générateur prêt en 5,4 s, 105 Mo après le démarrage. Déclencheur avec `force` sur les deux
environnements : prod 9 équipes déposées sur 18 en 227 s, aucun échec ; staging 3 sur 4, la troisième comptée en
échec après 16 minutes alors que le moteur l'avait enregistrée. Cause : lancés ensemble, les deux environnements font
la queue au moteur, qui ne répondait « 100 Continue » qu'après la file ; le client HTTP du JDK prend ce « 100 »
tardif pour la réponse finale et n'entend jamais la vraie. Corrigé dans le moteur `1.9.2` (la première trame du corps
est lue pendant l'attente), rejoué avec le client du JDK contre le service : délai dépassé avant, 200 après. Mémoire du
service après les treize dépôts et les premières générations réelles : 1,0 Go sur 3G, aucun redémarrage. Test : aucun
côté Pédalons (exploitation) ; dans osm-route-details,
`a_queued_deposit_asks_for_its_body_at_once_so_that_100_continue_is_not_held_back`. **À ne pas défaire** : ne pas
revenir sous `1.9.2` tant que deux environnements partagent le moteur ; un graphe arrive toujours sous un nom neuf ;
l'ancien `.env` est gardé dans `~/shared/.env.bak-pdl` et les fichiers `pdl-2026-11-14` restent le temps d'exclure un
retour en arrière, à supprimer à la main ensuite. **Non mesuré** : l'altitude sollicitée à plein en même temps que le
générateur (suivi sous `OPS-58`).
