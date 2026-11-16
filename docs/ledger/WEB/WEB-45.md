---
id: WEB-45
title: "Navigation principale dans l'en-tête"
status: done
group: "Accueil et page Fonctionnalités"
done: 2026-10-04
---

## Livré

`WEB-45` **Navigation principale dans l'en-tête** (4 octobre 2026, décidé avec le propriétaire).
Fil · Équipes · Calendrier (connecté) · Parcours · Fonctionnalités passent de la rangée d'onglets
de l'accueil à l'en-tête (`MainNav`, libellés à partir de `lg`, icônes avec info-bulle entre `sm`
et `lg`) et au tiroir mobile ; `HomeLayout` est supprimé. `useHomeNavItems` reste la source unique
(fil d'Ariane compris), `useMainNavItems` y ajoute Fonctionnalités ; l'entrée active vient de
l'URL (`activeMainNavId`, remontée de `parentId` dans `routes.config.ts`), « Équipes » s'allume
sur les pages d'équipe. Tests : `MainNav.test.tsx` ; e2e via `mainNavLink` (`e2e/support/ui.ts`).
**À ne pas défaire** : un seul endroit définit les entrées de navigation ; le nom affiché près de
l'avatar reste visible à partir de `md` car l'e2e desktop trouve le menu du compte par ce nom.
