---
id: AUD-22
title: "`MainActivity.kt` découpé"
status: done
done: 2026-11-13
---

## Livré

| ID | Thème | Audit | Gravité | Livré |
|---|---|---|---|---|
| `AUD-22` | Karoo | K1 | Critique | **`MainActivity.kt` découpé** (2026-11-13) — de 1 986 lignes à 106 ; le plus gros fichier de `karoo/app/src/main` en fait 304 (`browse/MainViewModel.kt`). Un écran par fichier dans `browse/ui/`, lignes de liste et structure d'écran partagées dans `ui/components/`, formateurs dans `ui/Formatters.kt`, écrans de connexion dans `auth/AuthScreens.kt` et `auth/GpsConnectContent.kt`. La connexion au Karoo System Service, copiée dans les trois activités, est dans `system/KarooConnection.kt` ; l'URL du site vient de `BuildConfig.PEDALONS_BASE_URL` ; plus aucun `!!`. Refactor **à comportement constant**, jugé par le filet d'`AUD-23` posé d'abord sur l'ancien code : les 70 captures de référence sont restées identiques à l'octet (`sha256sum`), et les défauts existants sont gardés tels quels (`API-186` à `API-189`). Trois écarts voulus : le démarrage n'enchaîne plus de requêtes en double, l'état survit à un changement de configuration (voir `AUD-23`), et `PedalonsExtension` annonce le `versionName` de l'APK au lieu de `1.0.0` en dur. Ne pas réintroduire de lambdas modifiables sur l'activité pour parler aux écrans, ni de logique dans un composable : touche ou toucher → méthode du `MainViewModel` → réducteur → état. Vérifié : `./gradlew spotlessCheck assembleDebug verifyRoborazziDebug assembleRelease` (R8 compris). Pas de recette sur appareil (`API-190`) |
