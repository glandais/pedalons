---
id: MOB-5
title: "Exploration de parcours (21)"
status: open
group: "Recette sur une application qui tourne"
verified: 2026-11-16
---

## Reste à faire

`MOB-5` **Exploration de parcours (21)** — vue liste et vue carte, en prod sur `n-peloton`
(2 696 parcours). Le mobile rend désormais les
vraies tuiles `.mvt`, comme le web (jeton signé, API 2.3.0) : vérifier qu'au-delà de quelques
centaines de tracés la carte les montre **tous**, sans plafond ni pilule de troncature, et
qu'aucune requête ne part au tap sur un tracé. À faire **en build release au moins une fois** :
`featuresAtPoint` a un antécédent de `ClassNotFoundException` Android corrigé en maplibre
0.3.5, que le mode debug ne montre pas. Vérifier aussi le renouvellement du jeton : laisser la
carte ouverte au-delà de la durée de vie, les tuiles doivent continuer d'arriver et les
marqueurs rester **au-dessus** de la masse. Bascule automatique en compact au-delà de 200
résultats.
