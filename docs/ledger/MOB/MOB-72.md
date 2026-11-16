---
id: MOB-72
title: "Un APK signé pour les Android sans Google Play"
status: done
group: "Tableau de bord d'équipe"
done: 2026-10-16
---

## Livré

`MOB-72` **Un APK signé pour les Android sans Google Play** (16 octobre 2026, contrat
inchangé) — `publish_beta.sh` pousse, après son commit de numéro de build, le tag
`mobile.X.Y.Z.N` (le `+` de `pubspec.yaml` devient `.`, une URL de release porte le tag) ;
`.github/workflows/mobile-release.yml` construit l'APK universel de ce commit, le publie sur la
release du tag (notes : le whatsNew FR puis EN de `metadata/version/X.Y.Z/`) et le recopie sur la
release fixe `mobile-latest`, cible du bouton « APK Android sans Google Play » de la page
Applications de l'app (`apps_page.dart`) et du site (`WEB-93`). Le workflow échoue si le tag ne
correspond pas à `pubspec.yaml`, si le whatsNew manque, ou si l'APK sort signé par la clé de
debug (repli silencieux de `build.gradle.kts` sans `key.properties`). Firebase échouait déjà sans
bruit (`main.dart`, `push_gateway.dart`) : aucun changement de code. Pas de test automatisé ; la
recette sur un appareil sans GMS est `MOB-73`. **À ne pas défaire** : l'APK est signé par la **clé
Karoo** (secrets `KAROO_KEYSTORE_*`), jamais par la clé d'upload Play, et cette clé ne change
plus — une autre clé coupe les mises à jour de toutes les installations par APK ; son empreinte
`26:24:…` reste dans `frontend/public/.well-known/assetlinks.json` (liens profonds, passkeys) ;
`mobile-latest` n'est jamais marquée « Latest » ni supprimée (immutable releases désactivées) ;
seul `publish_beta.sh` tague, pas `publish_test.sh` (les builds internes restent privés).
