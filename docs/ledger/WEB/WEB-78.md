---
id: WEB-78
title: "Page d'un groupe de sortie (`WEB-77`) : recette navigateur des états restants"
status: open
size: "S"
verified: 2026-11-16
---

## Reste à faire

`WEB-78` **Page d'un groupe de sortie (`WEB-77`) : recette navigateur des états restants
(S)** — les e2e sont passés (voir la part livrée sous le même identifiant) et `WEB-94` a
vérifié la section météo de la page dans un navigateur (clair, sombre, 390 px). Restent à
voir à l'œil : la colonne de carte collante à partir de 64em, le sélecteur de groupe (4 puis
`Select`), un groupe supprimé (état vide), un inscrit dans un autre groupe, en mode sombre et
sur téléphone. Recoupe `WEB-61`.

## Livré

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
