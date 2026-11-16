---
id: MOB-97
title: "Le build release iOS ne plante plus à l'ouverture"
status: done
done: 2026-10-25
---

## Livré

`MOB-97` **Le build release iOS ne plante plus à l'ouverture** (25 octobre 2026, cause
rectifiée le 26 octobre, contrat inchangé) — l'app s'arrêtait au lancement sur
`Unrecognized selector +[shared_preferences_foundation.LegacyUserDefaultsApiSetup
getInstanceWithName:]` (SIGABRT, iPhone, iOS 27.0.1). On a d'abord accusé
`shared_preferences_foundation` 2.6.0 (Pigeon FFI) et figé le plugin en 2.5.7 ; c'était faux. Le
build était **incohérent** : le Dart compilé contre la 2.6.0 (`.dart_tool/package_config.json`)
appelait en FFI le Swift de la 2.5.7, parce que le `Package.swift` SwiftPM généré
(`mobile/ios/Flutter/ephemeral/…`) pointait encore vers `.packages/shared_preferences_foundation-2.5.7`.
La mise à jour des dépendances avait été faite dans un autre worktree, et le build lancé avec
`flutter run --release --no-pub` : avec `--no-pub`, flutter ne régénère pas les fichiers natifs
des plugins, et `dart pub get` ne le fait jamais. Le message `does not implement
methodSignatureForSelector:` le trahissait : la classe chargée ne dérivait pas de `NSObject`,
contrairement à celle de la 2.6.0. Reproduit en **debug** sur le simulateur en recréant ce
décalage ; un build propre en 2.6.0 s'ouvre. **À ne pas défaire** : après tout changement du
`pubspec.lock` (pull, merge, mise à jour), lancer `flutter pub get` — pas `dart pub get` — ou un
`flutter run`/`build` sans `--no-pub` avant de construire pour iOS ; un `Unrecognized selector`
sur une classe de plugin désigne d'abord ce décalage, pas le plugin.
