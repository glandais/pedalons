---
id: OPS-54
title: "Images Docker publiées sur un registry public, construites par la CI (étude)"
status: open
group: "Exploitation"
verified: 2026-11-16
---

## Reste à faire

`OPS-54` **Images Docker publiées sur un registry public, construites par la CI (étude)**
— chaque hôte construit aujourd'hui ses propres images (`./build.sh` dans `~/prod`,
`~/staging`), sous un tag par environnement : ce que staging a recetté n'est pas l'artefact
qui part en prod, la restauration doit recompiler, et l'hôte porte JDK, Maven, pnpm et leurs
caches. Proposition, rien de décidé : GHCR public, un workflow `images.yml` qui pousse
`<sha12>` en multi-arch avec attestation de provenance, `scripts/deploy.sh` qui tire et
déploie par digest (repli `--local` sur `build.sh`). Prérequis : une image unique pour tous
les environnements — acquis pour les sourcemaps, servies partout par décision du
16 novembre 2026 (`ISSUE-10`, écartée).
Laisse `AUD-1` dehors. Étude, découpage et décisions :
[`2026-10-25-public-registry.md`](../../plans/2026-10-25-public-registry.md). Taille : M (deux à
trois jours).
