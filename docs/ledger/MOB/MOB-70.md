---
id: MOB-70
title: "La 1.1.0 est publiée sur l'App Store"
status: done
done: 2026-10-26
---

## Livré

`MOB-70` **La 1.1.0 est publiée sur l'App Store** (constaté le 26 octobre 2026, contrat
inchangé) — la 1.0.0 était en vente ; la 1.1.0 a été créée le 14 octobre dans App Store Connect
(sortie `MANUAL`), sa fiche, ses nouveautés, ses notes de revue et ses captures (iPhone et iPad,
refaites sur l'app du 25 octobre) poussées depuis `mobile/metadata/` et `mobile/screenshots/`,
le build 92 attaché, soumise, approuvée puis publiée à la main. `cd mobile/ios && bundle exec
fastlane release` attache le build du `pubspec` (`asc versions attach-build`) : l'ancienne lane
passait par `deliver`, qui n'attache un build qu'en soumettant, et n'attachait donc rien. Les
informations de test TestFlight (compte de démo, notes de revue, description bêta FR/EN, URL de
confidentialité), remplies par l'API le 15 octobre, ne sont **pas versionnées** : le compte de
démo se change aux deux endroits (fiche App Store et TestFlight). La version suivante est
`MOB-101`.
