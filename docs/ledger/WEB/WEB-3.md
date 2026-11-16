---
id: WEB-3
title: "Le survol des cartes web a un effet"
status: done
group: "Défauts d'interface"
done: 2026-09-30
---

## Livré

`WEB-3` **Le survol des cartes web a un effet** (2026-09-30) — l'ombre `md` des cartes était
déclarée en `'&:hover'` dans la prop `styles`, que Mantine rend en style inline : le
pseudo-sélecteur était ignoré. Elle passe par une classe de `Card.module.css` (mixin `hover` de
`postcss-preset-mantine` : `:hover` sous `(hover: hover)`, `:active` sous `(hover: none)`), qui
porte aussi le reste du style du lien (`display`, couleur, transition). Même motif corrigé pour le
soulignement au survol de `CardTeamLink` (même module), `TeamContextBanner` et `TripStageCard`
(un module chacun). [`BRANDING.md`](../../BRANDING.md) §5.2 et §7.1 décrivent désormais l'ombre au
survol comme acquise. Ne pas remettre de pseudo-sélecteur dans `styles` ou `style` : il n'y a
aucun effet et rien ne le signale. Pas de test : ni vitest (jsdom ne calcule pas `:hover`) ni la
suite e2e ne mesurent un style au survol ; `pnpm typecheck`, `pnpm lint` et `npx vitest run`
passent, et la sortie de `postcss-preset-mantine` sur le module a été vérifiée.
