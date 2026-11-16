---
id: AUD-23
title: "Un filet de tests et un `ViewModel`"
status: done
done: 2026-11-13
---

## Livré

| ID | Thème | Audit | Gravité | Livré |
|---|---|---|---|---|
| `AUD-23` | Karoo | K2, K3 | Critique | **Un filet de tests et un `ViewModel`** (2026-11-13) — 361 tests JVM (Robolectric, Android 12, sans appareil ni réseau), une seule commande, `./gradlew verifyRoborazziDebug`, en fin de `karoo/check.sh` et dans le job Karoo de `ci.yml` (qui ne faisait qu'`assembleDebug`). Quatre couches, décrites dans `karoo/CLAUDE.md` § Tests : contrat du client d'API sur `MockEngine` (méthode, URL, jeton, corps, statut → résultat, réponses d'anciens backends) ; logique pure ; comportement des trois vraies activités pilotées aux touches contre un `FakeBackend` (textes affichés, requêtes émises, jetons stockés) ; 70 captures Roborazzi en 480×800 à 300 dpi, en `en` et `fr`. Posé **avant** le découpage sur le code d'origine, puis éprouvé par 25 mutations à la main (22 détectées ; les 3 autres sans portée : deux se couvrent l'une l'autre, une équivalente). Un test `CHARACTERIZATION:` tient un comportement qui ressemble à un défaut : ne pas le « corriger » en passant. **Les captures ne se réenregistrent que pour un changement visuel voulu**, et seulement sous Linux x86_64. L'état vit dans `MainViewModel` (état immuable dans un `StateFlow`), la navigation et la sélection dans un réducteur pur (`browse/BrowseState.kt`, testé sans Android) ; il survit donc à une recréation de l'activité. Injection à la main par constructeur : ni Hilt ni Koin, ni bibliothèque de navigation, ni découpage en modules — rien à cette taille ne les justifie. Reste : `API-190` |
