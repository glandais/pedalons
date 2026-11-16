---
id: AUD-32
title: "`navigation-compose` retiré"
status: done
done: 2026-09-30
---

## Livré

| ID | Thème | Audit | Gravité | Livré |
|---|---|---|---|---|
| `AUD-32` | Karoo | K13 | Mineur | **`navigation-compose` retiré** (2026-09-30, scindé de `AUD-24`) — déclaré dans `app/build.gradle.kts` et `gradle/libs.versions.toml`, importé nulle part (ni `NavHost` ni `androidx.navigation`). À redéclarer le jour où le découpage de `MainActivity` (`AUD-22`) en fait usage. Vérifié : `./gradlew assembleDebug` et `testDebugUnitTest` passent |
