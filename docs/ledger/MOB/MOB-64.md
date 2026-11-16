---
id: MOB-64
title: "Publier Pédalons sur Google Play"
status: open
size: "S"
group: "Fiches des stores"
verified: 2026-11-16
---

## Reste à faire

`MOB-64` **Publier Pédalons sur Google Play (S)** — la fiche est poussée sur Google Play
(`fastlane listing`, 11 octobre 2026) : description FR/EN reprise de l'App Store, sept cartes
1080 × 1920 capturées sur l'émulateur (`screenshots/capture-android.sh`, `koubou/play.yaml`,
`assemble-play.sh`) et une bannière refaite (`koubou/feature.yaml`). État au 15 octobre 2026
(fiche et images identiques au dépôt, vérifié par l'API) : aucune version en production ; le
test fermé (`alpha`, liste de diffusion « Test Pedalons ») reçoit chaque bêta 1.1.0 de
`publish_beta.sh` (la build en test est celle du dernier passage du script), la première
approuvée le 15 octobre (la Console coche « Publier une version de test fermé »).
**Bloquant** : le compte développeur est personnel, la Console refuse de demander l'accès en
production avant **douze testeurs inscrits au test fermé pendant quatorze jours d'affilée**
(zéro inscrit au 15 octobre), et ces testeurs doivent **réellement utiliser l'app** : la
demande d'accès porte sur l'usage et les retours obtenus pendant le test. Les testeurs passent
depuis le 15 octobre par le
Google Group `pedalons-testeurs@googlegroups.com` (ouvert à tous, publication réservée aux
gestionnaires), déclaré sur le canal Alpha : chacun rejoint
https://groups.google.com/g/pedalons-testeurs puis accepte
https://play.google.com/apps/testing/fr.pedalons.mobile ; seul un testeur qui a accepté le
second lien compte. En viser une quinzaine : sous douze, les quatorze jours repartent de zéro.
Le canal n'est ouvert que dans un pays, et l'adresse de commentaires y est `dev@pedalons.fr`
(TestFlight : `gabriel.landais@gmail.com`). Les formulaires de *Contenu de l'application*
sont tous traités (neuf les 11 et 12 avril 2026 : informations de connexion, classification
du contenu, cible et contenu, annonces, identifiant publicitaire…), et la sécurité des
données a été repoussée par `fastlane data_safety` le 25 octobre 2026, à envoyer en examen
depuis *Vue d'ensemble de la publication*.
Une fois l'accès obtenu : promouvoir la release `alpha` depuis la Console plutôt que
`fastlane deploy`, qui renverrait le même versionCode. Fiche (textes 1.1.0) et captures
refaites sur l'app du 25 octobre poussées par `fastlane listing` le 25 octobre 2026.
