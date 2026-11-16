---
id: MOB-28
title: "Écrans d'erreur sur un 5xx"
status: done
group: "Couverture e2e Patrol"
done: 2026-09-29
---

## Livré

`MOB-28` **Écrans d'erreur sur un 5xx** (29 septembre 2026) — un 500 sur l'équipe puis sur la
sortie est retenté trois fois par `providerRetry` (au moins 3 s, quatre requêtes pour la sortie),
puis la page affiche son erreur — « Erreur de chargement » pour la sortie, pas l'« introuvable »
d'un 404 ; une fois le serveur rétabli, « Réessayer » charge la page — `load_error_retry_test.dart`.
Le 500 est fabriqué côté app par un intercepteur que le test ajoute au `Dio` authentifié
(`patrol_test/server_errors.dart`), comme `page.route` côté web : la stack e2e ne sait pas échouer
à la demande, et `lib/` ne porte aucun crochet de test. *Non couvert : un 5xx réellement émis par
le serveur, l'erreur hors ligne (`errors.offline`), les autres écrans en erreur (voyage, article,
parcours, annonce).*
