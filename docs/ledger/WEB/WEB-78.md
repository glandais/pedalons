---
id: WEB-78
title: "Page d'un groupe de sortie (`WEB-77`) : recette navigateur des états restants"
status: done
size: "S"
done: 2026-11-16
---

## Livré

### `WEB-78` Page d'un groupe de sortie : les états restants vus dans un navigateur (2026-11-16, contrat inchangé)

`WEB-78` **La recette à l'œil de la page d'un groupe (`WEB-77`) est faite** — sur staging (`3b8a0b80`, contrat `15.0.0`), Chrome au bureau avec un compte administrateur, clair et sombre, et Chromium émulé en téléphone tactile de 390 px sans compte (Playwright), avec une sortie à quatre
groupes sur trois parcours et une à six groupes créées pour l'occasion. Vus et conformes : la colonne de carte
collante à partir de 64em (`position: sticky`, `top: 76px` à 1040 et 1440 px ; carte au-dessus et colonne dessous à
1000 px) ; le sélecteur en quatre segments puis en `Select` à six groupes, nom long compris ; l'état « Ce groupe
n'existe plus » et son retour à la sortie ; « Votre inscription est dans le groupe G2. Voir le groupe » sur un autre
groupe ; le tout en sombre et à 390 px. Les défauts relevés sont sortis dans `WEB-188` (segments coupés à 390 px, et
deux points à trancher : pas de « Changer pour ce groupe » sur la page, pas de distance pour un groupe qui roule le
parcours de la sortie).

### `WEB-78` Page d'un groupe de sortie : les e2e passés (constaté le 16 octobre 2026, contrat inchangé)

`WEB-78` **Les e2e de la page d'un groupe (`WEB-77`, `WEB-79`), écrits le 13 octobre 2026 sans
être lancés, sont passés** — constaté à la relecture du ledger du 16 octobre 2026 : suite
Playwright verte sur les deux projets, prod sur `ac130fc5`. `routes-render.e2e.ts` couvre
l'écran `rideGroup` (`groupId` dans le jeu de données, audit de préchargement : aucune relecture
des participants après hydratation) ; les parcours d'inscription qui passent par le détail de la
sortie et les specs adaptées par `WEB-79` (`rides`, `flow-routes`, `pinned-host`) passent aussi.
L'écran `rideGroup` attendait alors le titre fautif « Groupe Groupe A », corrigé depuis par `WEB-83`.
La section météo de la page a été vérifiée dans un navigateur par `WEB-94` ; la recette à l'œil
des autres états (carte collante, sélecteur de groupe, groupe supprimé, inscrit ailleurs) reste
ouverte sous le même identifiant.
