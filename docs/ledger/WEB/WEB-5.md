---
id: WEB-5
title: "`pnpm ssr-audit:verify` repasse"
status: done
group: "Outillage"
done: 2026-09-30
---

## Livré

`WEB-5` **`pnpm ssr-audit:verify` repasse** (2026-09-30) — `notifications`, `web: true` dans
`contracts/routes.yaml`, manquait à `scripts/routes-ssr.yml` ; la vérification a sorti trois
autres absentes, venues avec le signalement et le support : `support`, `teamAdminReports`,
`adminReports`. Les quatre y sont, rangées comme leurs voisines : `notifications` pour les trois
comptes connectés (la boîte est par utilisateur), `support` pour tous (page publique),
`teamAdminReports` pour `user1` sur `gaby`, `adminReports` pour `admin`. Couvert par
`pnpm ssr-audit:verify` lui-même (69 routes), qui tourne sans pile ; le crawl, lui, n'a pas été
relancé.
