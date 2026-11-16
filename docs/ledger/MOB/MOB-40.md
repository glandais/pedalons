---
id: MOB-40
title: "Un lien universel ouvrait l'app et Safari"
status: done
done: 2026-10-02
---

## Livré

`MOB-40` **Un lien universel ouvrait l'app et Safari** (2 octobre 2026, issues feedback #6 et
#7, build 62, iOS) — le QR d'appairage Karoo ouvrait la validation dans l'app **et** dans Safari.
Le deep linking intégré de Flutter (actif par défaut depuis 3.27) poussait la route en plus
d'`app_links` ; au lancement, sur le `MaterialApp` de chargement d'`app.dart` (pas de routeur),
`_onUnknownRoute` levait « Null check operator », et le moteur iOS renvoyait alors le lien non
géré au système (`relayToSystemIfUnhandled`), qui l'ouvrait dans Safari. Désactivé :
`FlutterDeepLinkingEnabled` = `false` (`ios/Runner/Info.plist`) et `flutter_deeplinking_enabled`
= `false` (`AndroidManifest.xml`, où chaque lien était traité deux fois). Pas de test automatisé :
à vérifier par un scan du QR sur iPhone (build 64). **À ne pas défaire** : `_DeepLinkHandler` (`main.dart`) est
le **seul** à recevoir les liens — réactiver le deep linking de Flutter rouvre Safari à chaque
lien reçu avant la fin de l'initialisation de l'auth.
