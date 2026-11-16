---
id: MOB-65
title: "Sens des tracés sur les cartes de l'app, comme au web"
status: done
done: 2026-10-11
---

## Livré

`MOB-65` **Sens des tracés sur les cartes de l'app, comme au web** (11 octobre 2026, contrat
inchangé) — le pendant mobile de `WEB-49` : un chevron répété le long de chaque tracé, dans
l'ordre de ses points, sur toutes les cartes que dessine `PdlMapController` (sortie, parcours,
voyage et étape). Même dessin que le site (`map/pdl_route_arrow.dart`, 16 points), mais
`symbol-spacing` à 50 au lieu de 90 : MapLibre natif mesure l'espacement sur la tuile, et au
cadrage d'une étape de 65 km il ne posait qu'un chevron, caché sous une borne kilométrique, teintes `mapArrow` / `mapArrowRim` dans `PdlColors`, identiques
dans les deux thèmes comme l'ombrage. Pas sur la couche de masse (tous les parcours) : sans
survol, il n'y a pas de tracé « courant » à flécher. Couvert par `pdl_map_controller_test.dart`
(groupe « sens des tracés »). **À ne pas défaire** : les chevrons ont leur **propre source**, une
entité par ligne entière — posés sur les tronçons d'un tracé colorisé par pente, ils tomberaient
au hasard des coupures ; l'image est dessinée à 3× puis réduite par `icon-size`, parce que les
greffons iOS et Android posent une image à un pixel par point (floue sur un écran 3× sinon) ; elle
est reposée à chaque pose, un changement de fond de carte effaçant les images du style ; et
`_raise` repasse la couche de chevrons au-dessus du tracé sélectionné qu'il vient de remonter.
