---
id: BRAND-11
title: "Un design system Pédalons pour /design"
status: open
size: "S"
kind: externe
verified: 2026-11-27
---

## Livré

`BRAND-11` **Un design system Pédalons pour /design** (2026-11-27, sans changement de contrat ni de code) — `/design` de Claude Code ne lit pas la charte du dépôt : il cherche un artefact « Design System » sur le compte claude.ai, et n'en trouvant aucun, dessinait avec un style à lui. Le design system « Pédalons » a été publié en artefact (https://claude.ai/artifact/JrjsweYBAcFdevAGV7guVD), tiré de `frontend/src/lib/theme.ts`, `mobile/lib/core/theme/pdl_colors.dart` (fonds doux sombres), `contracts/brand-colors.yaml`, `frontend/src/lib/avatarTint.ts` et `docs/BRANDING.md` : 109 couleurs en clair et en sombre (dont les trois jetons `fam-*` de chaque famille métier), Inter 400 à 700, rayons, espacements, ombres, mise en page, le logo, huit composants signature en aperçus statiques écrits à la main, et les sections « Lexique et ton » et « Cartes et tracés ». Ses fichiers texte sont dans `docs/design-system/project/`, d'où il se republie (`docs/design-system/README.md`). Le CLAUDE.md racine le nomme, pour que `/design` le trouve dans chaque worktree. **À ne pas défaire** : c'est une copie dérivée — quand elle et le code divergent, le code a raison, et on republie la copie ; les jetons `--pdl-*` des maquettes n'y entrent pas.

## Reste à faire

Le marquer « Set as default » dans claude.ai (page Artifacts, menu Claude Design, « View design systems ») ; puis lancer un `/design` simple (une carte de sortie) et voir s'il prend la charte.
