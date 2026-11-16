---
id: BRAND-9
title: "L'année dans la boîte du jour, hors de l'année en cours"
status: done
done: 2026-11-09
---

## Livré

`BRAND-9` **L'année dans la boîte du jour, hors de l'année en cours** (9 novembre 2026) — sur une carte, la boîte est la seule date : une sortie de l'an prochain se lisait comme celle de cette année. Une quatrième ligne « 2027 », au style du mois, s'y ajoute (`DayBox` au web, `PdlDayBox.year` via `dayBoxFor` sur mobile) ; la boîte grandit en hauteur, jamais en largeur, et la boîte compacte de « Cette semaine » n'en a pas. Écartés sur maquette : « avr. 27 » sur la ligne du mois (déborde à « sept. », se lit comme un jour) et l'année sur la ligne de départ (loin de la date). BRANDING §7.8 et §8.3. Tests : `DayBox.test.tsx`, `day_box_test.dart`.
