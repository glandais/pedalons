---
id: MOB-89
title: "Pages personnalisées d'équipe en puces de section, comme les onglets du web"
status: out
---

## Écarté

| ID | Sujet | Décision | Ce que ça implique |
|---|---|---|---|
| `MOB-89` | **Pages personnalisées d'équipe en puces de section, comme les onglets du web** | Non (24 octobre 2026) | Au mobile, elles restent une liste dans « À propos », une ligne par page qui ouvre son écran (`team_about_page.dart`), comme le demandait la note de conception (`plans/archive/audit-ux/BRIEF.md`, onglet À propos). Avec plusieurs pages, la rangée de puces déborderait. Le web garde ses onglets : sa rangée a la place et n'a pas de menu de débordement (`WEB-25`). Le filtrage des pages réservées aux membres se fait côté backend (`isListed` dans `TeamDetailDto`). L'autre volet de l'entrée, la visibilité de « Membres », n'avait rien à changer au mobile : c'est sa règle que le web reprend (`WEB-112`) |
