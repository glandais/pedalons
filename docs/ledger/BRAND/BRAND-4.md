---
id: BRAND-4
title: "Vent relatif au code couleur métier"
status: done
done: 2026-10-05
---

## Livré

`BRAND-4` **Vent relatif au code couleur métier** (2026-10-05, contrat `10.9.0`) —
`RelativeWind` est entré dans [`contracts/brand-colors.yaml`](../../../contracts/brand-colors.yaml),
style `soft` : `TAIL` teal, `CROSS` gray, `HEAD` orange ; les deux tables générées sont
régénérées et lues par la barre d'exposition et les flèches de vent des deux clients (`WEB-60`,
`MOB-51`). **À ne pas défaire** : la couleur n'est jamais seule, toujours doublée du libellé et de
la flèche ; les conditions météo (`WeatherCondition`) n'ont pas de couleur — si on leur en donne,
c'est ici, dans le YAML, jamais dans une table d'un client.
