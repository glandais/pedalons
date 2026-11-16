---
id: MOB-45
title: "« Cols et montées (1) »"
status: done
group: "Défauts trouvés par la recette du 4 octobre 2026"
---

## Livré

`MOB-45` **« Cols et montées (1) »** — `routes.climbs` est un pluriel (`one` « Col ou montée
({}) », « Climb ({}) » en anglais) lu par `.plural()` dans `route_climbs_section.dart`. Test :
`route_climbs_section_test.dart` (une montée, deux montées).
