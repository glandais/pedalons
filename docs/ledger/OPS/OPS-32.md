---
id: OPS-32
title: "Manifest d'extension Karoo, URL stable et lien d'installation"
status: done
done: 2026-10-15
---

## Livré

`OPS-32` **Manifest d'extension Karoo, URL stable et lien d'installation** (2026-10-15,
releases `karoo.1.0.9` à `karoo.1.0.11`) — l'APK sideloadé n'avait ni fiche, ni chemin de mise à
jour, et le site renvoyait vers la liste des releases, d'où rien ne s'installe.
- **Manifest** : chaque tag `karoo.X.Y.Z` publie un `manifest.json` (karoo-ext
  `KarooAppManifest`) construit par `karoo-release.yml` depuis `karoo/metadata/app.json` (dont
  `screenshots`, l'ordre des captures de `karoo/metadata/screenshots/`) et le `whatsNew` de
  `karoo/metadata/version/X.Y.Z/fr-FR.json`, qui est aussi le corps de la release. Sans ce
  fichier, le workflow échoue avant le build. URLs internes épinglées sur le tag.
- **URL stable, en deux maillons** : chaque APK porte la meta-data `MANIFEST_URL =
  https://www.pedalons.fr/karoo/manifest.json` ; traefik (labels du frontend dans
  `docker-compose.yml`) la redirige en 307 vers la release fixe `karoo-latest`, que le workflow
  réécrit (`--clobber`) avec `manifest.json` et `pedalons.apk`.
- **Installation** : `/applications` sur le site pointe vers
  `releases/download/karoo-latest/pedalons.apk` avec le geste (appui long → Partager →
  Hammerhead Companion) ; l'app mobile ouvre la feuille de partage native sur ce lien
  (« Envoyer au Karoo », clé `keys.apps.karooShareButton`), à partir de sa prochaine version
  publiée. Les deux renvoient à l'article de sideloading de Hammerhead.

Pas de test automatisé (workflow de release et configuration traefik) : recette le 2026-10-15 —
redirection 307 vérifiée en production, manifest et assets en 200, `MANIFEST_URL` lu dans l'APK publié,
parcours d'installation depuis le site validé par le propriétaire du dépôt. **À ne pas
défaire** : `releases/latest/download/…` est inutilisable ici, « Latest » vaut pour tout le
monorepo ; `karoo-latest` ne doit jamais être marquée « Latest » ni supprimée, et les immutable
releases du dépôt doivent rester désactivées ; l'URL écrite dans les APK est celle de
pedalons.fr, pour pouvoir déplacer le manifest sans republier d'APK ; le lien d'installation
reste une URL GitHub, la seule que Hammerhead garantit pour le Companion. Le QR code de la
capture d'association est brouillé exprès (l'original menait à la page d'association). La suite,
la publication dans le catalogue Hammerhead, est `OPS-33`.
