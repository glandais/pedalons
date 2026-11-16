---
id: ISSUE-2
title: "Côté mobile"
status: open
verified: 2026-11-16
---

## Reste à faire

`ISSUE-2` **Côté mobile**, si le build release passe à `--obfuscate`, conserver les
`--split-debug-info` par build, sans quoi les piles Dart deviennent inexploitables et
l'empreinte change à chaque version. La consigne vaut pour les trois chemins de build
release : `publish_test.sh`, `publish_beta.sh` et le workflow `mobile-release.yml`.
