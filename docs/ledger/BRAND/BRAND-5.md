---
id: BRAND-5
title: "Un nouvel enum coloré passe en une seule régénération"
status: done
done: 2026-10-06
---

## Livré

`BRAND-5` **Un nouvel enum coloré passe en une seule régénération** (2026-10-06, contrat
inchangé) — `scripts/generate-brand-colors.mjs` lit le modèle Freezed de chaque enum coloré
(`mobile/lib/api/generated/models/<enum>.dart`), or `pnpm check` le lançait avant que le client
mobile ne soit généré : un nouvel enum demandait deux passes. Corrigé par l'ordre, pas par le
générateur : [`regenerate.sh`](../../../regenerate.sh) génère le client mobile (`pub get`,
`openapi_retrofit_generator`, `build_runner`) entre le backend et `pnpm check`, et
[`check.sh`](../../../check.sh) lance `mobile/clean.sh` (qui régénère le client) après le backend au
lieu d'avant. Le générateur, s'il ne trouve pas le modèle, le dit et renvoie à cet ordre.
**À ne pas défaire** : ne pas rendre le générateur tolérant à l'absence du Dart — il produirait
un `enum_colors.generated.dart` sans l'enum, ou faux, sans échouer ; il doit continuer à lire les
identifiants dans le modèle Freezed plutôt que de les deviner. Vérifié : `pnpm
generate-brand-colors` laisse les deux `.generated.*` inchangés ; message d'erreur contrôlé en
retirant `relative_wind.dart`. Pas de test automatisé (outillage).
