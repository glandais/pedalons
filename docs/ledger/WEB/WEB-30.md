---
id: WEB-30
title: "Un bouton de partage sur le site"
status: done
group: "Référencement"
done: 2026-09-30
---

## Livré

`WEB-30` **Un bouton de partage sur le site** (2026-09-30, sans changement de contrat) — le mobile
partageait déjà un lien (`share_link.dart`), le web n'avait rien. `components/common/ShareButton.tsx`
est posé dans l'en-tête des pages de sortie, d'article, de voyage, d'étape et de parcours, et dans
celui de l'équipe (`TeamLayout`) : la feuille de partage du système quand `navigator.share`
existe, la copie du lien sinon (Firefox et Chrome de bureau), avec un bandeau qui dit si la copie
a échoué. Le lien est celui de la **barre d'adresse**, pas un `paths.xxx()` : sur un hôte épinglé
à une équipe, le chemin du routeur est préfixé et l'adresse visible ne l'est pas — c'est elle qui
marche chez le destinataire. Pas de bouton sur les annonces, comme au mobile : elles ne se lisent
qu'entre membres. Couvert par `ShareButton.test.tsx` (feuille, fermeture sans bandeau, copie,
copie refusée).
