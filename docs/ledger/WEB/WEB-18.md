---
id: WEB-18
title: "Page d'équipe en 1440×900"
status: done
group: "La recette web, automatisée"
done: 2026-09-25
---

## Livré

`WEB-18` Page d'équipe en 1440×900 : **arbitré le 25 septembre 2026, l'objectif de 220 px
n'est pas tenu** — le contenu commence à ~283 px (~300 avant le portage). Gagner les 60 px
restants voudrait dire refaire la navigation d'équipe (le carré de 40 px et son libellé font
~78 px), un chantier de design et non de portage. — `team-misc.e2e.ts` fige **< 300 px** pour
attraper une régression.
