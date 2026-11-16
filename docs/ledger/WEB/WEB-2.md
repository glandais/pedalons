---
id: WEB-2
title: "L'anneau de focus passe 3:1 en thème sombre"
status: done
group: "Accessibilité"
done: 2026-09-30
---

## Livré

`WEB-2` **L'anneau de focus passe 3:1 en thème sombre** (2026-09-30) — Mantine le dessine en
`--mantine-primary-color-filled`, indigo-8 (`#3b5bdb`) en sombre : **2,74:1** sur la page
(`#242424`), **2,40:1** sur les surfaces élevées et les champs (`#2e2e2e`), sous le 3:1 de SC 1.4.11.
`index.css` repeint le contour des deux classes de Mantine (`.mantine-focus-auto:focus-visible`,
`.mantine-focus-always:focus`) en `--mantine-color-primary-text` : la nuance que Mantine emploie
déjà pour le texte primaire en sombre, indigo-4 (`#748ffc`, charte §3), soit **5,23:1** sur
`#242424`, **4,58:1** sur `#2e2e2e`, **5,55:1** sur `#1f1f1f` et **3,78:1** sur le survol
`#3b3b3b`. En clair la variable vaut la nuance pleine, indigo-6 (`#4c6ef5`) : l'anneau clair ne
change pas (**4,32:1** sur blanc, **4,10:1** sur `#f8f9fa`). Indigo-5 (`#5c7cfa`) passait aussi,
mais à 3,05:1 seulement sur `#3b3b3b`. Pas de nouvelle couleur : la ligne « Anneau de focus » de
[`BRANDING.md`](../../BRANDING.md) §3.2 la consigne. Ne pas reposer l'anneau sur
`--mantine-primary-color-filled`, ni le mettre dans `lib/theme.ts` (le thème Mantine n'a pas de
réglage de couleur d'anneau). Pas de test automatique : ni vitest (jsdom) ni la suite e2e ne
mesurent un contour ; la sortie de `pnpm build` a été vérifiée (la règle suit celle de Mantine),
`pnpm typecheck`, `pnpm lint` et `npx vitest run` passent.
