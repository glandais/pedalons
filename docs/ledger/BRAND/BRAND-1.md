---
id: BRAND-1
title: "Types d'annonce réalignés sur la charte"
status: done
done: 2026-09-30
---

## Livré

`BRAND-1` **Types d'annonce réalignés sur la charte** (2026-09-30) — `AdDetailPage.tsx` gardait
sa propre table `adTypeColors` (SALE `primary`, RENTAL `grape`, WANTED `yellow`) ; son badge lit
maintenant `TYPE_COLORS` de `badgeColors.ts` (SALE green, RENTAL indigo, WANTED orange, comme le
§3.6 de [`BRANDING.md`](../../BRANDING.md), qui ne signale plus la divergence). Ne pas remettre de table
locale dans une page : la couleur d'une énumération se lit dans `badgeColors.ts`, en attendant la
source unique de `BRAND-2`. Pas de test : rien ne compare encore les couleurs (c'est `BRAND-2`) ;
`pnpm typecheck` et `pnpm lint` passent.
