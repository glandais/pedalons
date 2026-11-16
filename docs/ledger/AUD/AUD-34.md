---
id: AUD-34
title: "Un seul rafraîchissement du jeton"
status: done
done: 2026-11-13
---

## Livré

| ID | Thème | Audit | Gravité | Livré |
|---|---|---|---|---|
| `AUD-34` | Karoo | K7 | Important | **Un seul rafraîchissement du jeton** (2026-11-13, scindé de `AUD-24`) — la logique, copiée dans les deux chargements de `MainActivity.kt` et dans `GpsConnectActivity.kt` en fonctions `suspend` à rappels, est dans `auth/Session.kt` (`freshAccessToken`, derrière un `Mutex`), que `data/PedalonsRepository.kt` appelle et qui rend des résultats typés (`RoutesResult`, `HammerheadStatus`, `SyncResult`) au lieu d'exceptions à trier. La rotation du jeton de rafraîchissement (`SEC-11`) y est gardée : celui de la réponse remplace l'ancien, une réponse sans jeton garde le stocké. La synchro ne rafraîchit toujours pas (`API-186`). Tests : `SessionTest`, `PedalonsRepositoryTest`, `StartupAndAuthFlowTest` |
