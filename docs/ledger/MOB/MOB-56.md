---
id: MOB-56
title: "La connexion levait quand Firebase n'avait pas démarré"
status: done
group: "Erreurs remontées automatiquement — 6 octobre 2026"
---

## Livré

`MOB-56` **La connexion levait quand Firebase n'avait pas démarré** (feedback #4) —
`main.dart` tolère l'échec de `Firebase.initializeApp()`, mais le constructeur de
`FirebasePushGateway` lisait `FirebaseMessaging.instance`, qui lève alors `[core/no-app]` :
`pushGatewayProvider` passait en erreur à chaque connexion. `_messaging` est paresseux,
`ensureInitialized` retente l'initialisation et, en cas d'échec, le push est simplement
`unsupported`. **À ne pas défaire** : rien de Firebase ne doit être lu avant
`ensureInitialized`.
