---
id: BRAND-2
title: "Code couleur métier : source unique et générateur"
status: done
done: 2026-09-30
---

## Livré

`BRAND-2` **Code couleur métier : source unique et générateur** (2026-09-30, contrat inchangé) —
[`contracts/brand-colors.yaml`](../../../contracts/brand-colors.yaml) porte, pour chaque énumération du
contrat, la famille de chaque valeur et le style de la série (`soft`, ou `filled` pour les seules
catégories de col), plus les dégradés de repli en nuances Mantine. `pnpm generate-brand-colors`
(`scripts/generate-brand-colors.mjs`, sur le modèle de `generate-routes`) en tire
`frontend/src/lib/badgeColors.generated.ts` et `mobile/lib/core/theme/enum_colors.generated.dart`,
et refuse une valeur hors contrat, une valeur sans famille ou une famille hors liste. Au web, il
remplace `badgeColors.ts` (supprimé), `getClimbCategoryColor` (`RouteDetailView.tsx`), les
dégradés de `CardImage.tsx`, et aussi des tables que la tâche n'avait pas relevées : les
`statusColors` locales de cinq pages de détail, le `PUBLIC` badgé `primary` (indigo) de
`VisibilityBadge` et le `PUBLIC` vert des gabarits de sortie — tous deux `blue` désormais, comme
la charte. Au mobile, les extensions `StatusTone`… sont générées et seul le rendu d'une famille
reste écrit à la main (`PdlFamilyTone` dans `enum_colors.dart`) ; `PdlGradients` lit
`PdlFallbackGradients`. **Arbitrage `ROAD`** : gris doux partout — badge web (`dark` avant) comme
trait de rappel mobile (near-black `accentDark` avant) ; `accentDark` et
`PedalonsColors.darkLight/darkDark`, devenus sans usage, sont retirés. Les états dérivés
(« Inscrit », « Terminée », « Supprimé ») restent hors du YAML : aucune énumération ne les porte.
[`BRANDING.md`](../../BRANDING.md) §3.6 renvoie au YAML au lieu de recopier les tableaux. Test :
`mobile/test/core/theme/pdl_tokens_test.dart` (ROAD gris, aplat compris ; cols seuls en aplat ;
valeurs inconnues en gris) ; au web, `pnpm typecheck` vérifie chaque table générée par
`satisfies Record<Enum, BadgeFamily>`. **Ne pas** réintroduire de table de couleurs locale dans
un composant, ni éditer les deux fichiers générés : on édite le YAML et on régénère.
