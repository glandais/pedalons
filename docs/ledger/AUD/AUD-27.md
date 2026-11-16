---
id: AUD-27
title: "Pas de `slow_down` (le backend n'en émet aucun à ce jour — relevé le 30 septembre 2026 : `grep slow_down…"
status: open
verified: 2026-11-16
---

## Reste à faire

| ID | Thème | Audit | Gravité | Constat |
|---|---|---|---|---|
| `AUD-27` | Garmin | G8, G9 | Important | Pas de `slow_down` (le backend n'en émet aucun à ce jour — relevé le 30 septembre 2026 : `grep slow_down backend/` ne trouve rien ; `SEC-4` a limité `/complete` et `/verify`, pas `/token`, dont le `device_code` de 256 bits n'a rien à deviner : le point ne mordra que si `/token` est un jour freiné) ; offsets fixes dans les layouts. G6 est livré sous `AUD-31` |
