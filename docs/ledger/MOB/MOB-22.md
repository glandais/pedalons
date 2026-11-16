---
id: MOB-22
title: "Jeu d'icônes Tabler côté mobile"
status: out
---

## Écarté

| ID | Sujet | Décision | Ce que ça implique |
|---|---|---|---|
| `MOB-22` | **Jeu d'icônes Tabler côté mobile** | Material outline conservé | L'écart ne porte que sur la graisse du trait des icônes de badge de 11 px. `PdlIcons` (`lib/core/theme/pdl_icons.dart`) devrait être le **seul** fichier à nommer `Icons.*` (17 autres fichiers le font encore au 16 octobre 2026) : une fois ce ménage fait, basculer ne touchera qu'un fichier |
