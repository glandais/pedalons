---
id: WEB-37
title: "Changer de groupe vite ne se solde plus par un 409"
status: done
group: "Défauts d'interface"
done: 2026-09-30
---

## Livré

`WEB-37` **Changer de groupe vite ne se solde plus par un 409** (2026-09-30, contrat inchangé) —
« Quitter » met la sortie à jour de façon optimiste : les autres groupes affichaient
« Rejoindre » avant que le serveur ait libéré le premier, et un « Rejoindre » tapé dans cet
intervalle partait pendant le `leave` et revenait en `ALREADY_REGISTERED`, la carte montrant
« Inscrit » jusqu'au retour arrière. Relevé par `rides.e2e.ts` « changing group » (mobile, sous
5 workers : `join` parti à +113 ms d'un `leave` de 220 ms). `RideDetailPage` désactive désormais
les boutons de **toutes** les cartes tant qu'une inscription ou une sortie est en vol, plus
seulement celle touchée (l'état `joiningGroupId` disparaît). Ne pas revenir à une désactivation
par carte : l'optimisme rend les autres cartes actionnables trop tôt.
