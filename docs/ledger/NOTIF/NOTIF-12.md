---
id: NOTIF-12
title: "Le mobile enregistre ses push par une API dépréciée"
status: open
verified: 2026-11-16
---

## Reste à faire

`NOTIF-12` **Le mobile enregistre ses push par une API dépréciée** : firebase_messaging 17
(20 octobre 2026) déprécie `getToken()` / `onTokenRefresh` au profit de `register()` /
`onRegistered`, qui rendent un *Firebase Installation ID* (cible « direct-send ») et non plus
un jeton FCM. `PushGateway` (`mobile/lib/features/notifications/services/push_gateway.dart`)
garde l'ancienne API sous `// ignore: deprecated_member_use`, parce que `FcmRestClient`
n'envoie qu'à `message.token`. Migrer suppose que le backend sache cibler un FID (et accepte
les deux pendant la transition, les installations existantes ayant enregistré un jeton), puis
que le mobile bascule ; à faire avant que Firebase retire l'API. Taille : M, backend + mobile.
