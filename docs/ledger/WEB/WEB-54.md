---
id: WEB-54
title: "Calendrier rendu côté serveur dans le mauvais fuseau, sans préférence `timezone`"
status: out
---

## Écarté

| ID | Sujet | Décision | Ce que ça implique |
|---|---|---|---|
| `WEB-54` | **Calendrier rendu côté serveur dans le mauvais fuseau, sans préférence `timezone`** | Accepté tel quel (décidé le 4 octobre 2026, à la dissolution de `frontend/docs/SSR-BUGS.md`) | Sans préférence `timezone`, le serveur ne connaît pas le fuseau du visiteur et rend en UTC : une sortie à 00 h 30, heure de Paris, s'affiche dans la case de la **veille**, puis change de case au rendu qui suit l'hydratation, avec le vrai fuseau (`useEffectiveTimezone`, `getServerSnapshot` en UTC ; `CalendarView`). Ce n'est pas une erreur d'hydratation : le rendu d'hydratation lit UTC des deux côtés, et le mois de la grille est calé sur `hourAlignedNow()` dans le même fuseau. Régler une préférence `timezone` supprime l'effet. Seule autre issue : ne pas rendre la grille côté serveur quand le fuseau est deviné, ce qui perd tout l'intérêt de son préchargement |
