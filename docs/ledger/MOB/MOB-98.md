---
id: MOB-98
title: "`shared_preferences_foundation` n'est plus figé en 2.5.7"
status: done
done: 2026-10-26
---

## Livré

`MOB-98` **`shared_preferences_foundation` n'est plus figé en 2.5.7** (26 octobre 2026,
contrat inchangé) — le `dependency_overrides` posé par `MOB-97` est retiré et le plugin passe en
2.6.0. Le diagnostic refait sur le simulateur a montré que la 2.6.0 n'avait rien de cassé (voir
`MOB-97`). Vérifié en ouvrant un build release (`flutter run --release`, sans `--no-pub`) sur un
iPhone sous iOS 27.0.1. Aucun test ne le couvre.
