---
id: OPS-40
title: "Compter des visites plutôt que des pages vues"
status: out
---

## Écarté

| ID | Sujet | Décision | Ce que ça implique |
|---|---|---|---|
| `OPS-40` | **Compter des visites plutôt que des pages vues** (un site GoatCounter par domaine et par alias, purge nocturne de `hits.session`) | Non : pages vues seulement, sessions coupées, un seul site (décidé le 15 octobre 2026, [`2026-10-15-web-analytics.md`](../../plans/2026-10-15-web-analytics.md) §7) | Avec un site unique, une session relierait la navigation d'un site de club à l'autre (condition 3 de la CNIL) ; un site par hôte couplerait la création d'un domaine (`AdminDomainResource`) à GoatCounter, et l'empreinte de session gardée 24 mois sur chaque page vue ferait un quasi-identifiant sur un petit club. À rouvrir si une question réelle ne se résout pas en pages vues, en écrivant d'abord la purge et la création couplée |
