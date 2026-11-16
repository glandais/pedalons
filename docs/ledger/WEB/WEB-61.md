---
id: WEB-61
title: "Météo des sorties : recette navigateur de ce que `WEB-94` n'a pas vu"
status: open
size: "S"
kind: recette
verified: 2026-11-16
---

## Reste à faire

`WEB-61` **Météo des sorties : recette navigateur de ce que `WEB-94` n'a pas vu (S)** —
`WEB-94` a refait la météo de la page d'un groupe (`GroupWeatherSection` pleine largeur sous
la grille statistiques/carte) et l'a vérifiée dans un navigateur sur une vraie sortie (clair,
sombre, 390 px) ; la disposition d'origine (bloc entre l'en-tête et la carte, frise
horizontale des points) n'existe plus sur cette page. Reste à voir dans un navigateur :
`RideWeatherSection` sur le détail d'une sortie à plusieurs groupes, la ligne météo des
cartes de groupe (`GroupWeatherLine`), et la météo des étapes (`WEB-67`) : bloc de la page
d'étape, ligne des cartes d'étape ; mode sombre et téléphone pour chacune. À trancher avec le
propriétaire : le libellé de l'alerte
(`rides.weather.summary.rainAlert`, aujourd'hui « Pluie 70 % vers 10:00 » ; la maquette disait
« Averse 70 % »). Aucun e2e ne couvre la météo : la pile e2e coupe le fournisseur, il
faudrait remplir le cache par SQL.
