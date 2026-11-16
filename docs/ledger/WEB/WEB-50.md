---
id: WEB-50
title: "« Fonctionnalités » quitte l'en-tête d'un membre connecté"
status: done
group: "Défauts d'interface"
done: 2026-10-04
---

## Livré

`WEB-50` **« Fonctionnalités » quitte l'en-tête d'un membre connecté** (4 octobre 2026, relevé
dans `docs/BUGS.md`) — la page vend le produit à un visiteur ; un membre l'a déjà adopté.
`useMainNavItems` (`hooks/useNavItems.ts`) ne l'ajoute plus quand la session est ouverte (en-tête
et tiroir) ; la page reste accessible par son URL et le pied de page. Test : `MainNav.test.tsx`.
