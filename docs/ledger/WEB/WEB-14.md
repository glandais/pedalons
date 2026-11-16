---
id: WEB-14
title: "« Ma prochaine sortie », badge `Inscrit` et « Mes participations » se rendent **dans le HTML initial** pour…"
status: done
group: "La recette web, automatisée"
---

## Livré

`WEB-14` « Ma prochaine sortie », badge `Inscrit` et « Mes participations » se rendent **dans
le HTML initial** pour une requête porteuse d'un cookie de session, en sont **absents** sans
cookie, et survivent à l'hydratation sans erreur `[hydration]`. — `ssr-session.e2e.ts`, dont
le contrôle `curl` fait à la lettre (avec `Cache-Control: no-store` et `Vary: Cookie`).
