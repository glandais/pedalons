---
id: WEB-76
title: "Météo des sorties : vent détaillé, groupe choisi partagé avec la carte"
status: done
group: "Accueil et page Fonctionnalités"
---

## Livré

`WEB-76` **Météo des sorties : vent détaillé, groupe choisi partagé avec la carte** (13 octobre
2026, contrat inchangé). Les tuiles de la frise des points n'affichaient que la flèche et « Face /
Dos / Travers » : la vitesse n'était que dans l'`aria-label`, les rafales nulle part, et
`prevailingWind` n'était pas lu au web (le mobile montrait tout). Chaque tuile écrit désormais la
vitesse moyenne et, quand le modèle les donne, les rafales (`rides.weather.wind.gustsShort`) ;
`LegWeather` affiche le vent dominant (`rides.weather.leg.prevailingWind`), pour une sortie comme
pour une étape. Vent et rafales sont formulés une seule fois, `windWithGusts` de
`useWeatherLabels`, que le bloc départ réutilise. Le `Select` de groupe (au-delà de 4) monte à
`maxDropdownHeight={400}` : à 250 px, 10 groupes n'en montraient que six et demi. Le groupe
choisi est remonté dans `RideDetailPage` (`selectedGroupId`) : la météo le reçoit
(`selectedGroupId` / `onSelectGroup`, son propre état faute de page), les cartes de groupe et la
carte l'allument (survol prioritaire tant qu'il dure), et un clic sur un tracé le choisit
(`RoutesMapView` accepte `selectedItemId` / `onItemSelect`, le voyage n'en passe pas). Tests :
`RideWeatherSection.test.tsx` (vent et rafales par point, vent dominant, groupe choisi par la
page et remonté). Vérifié au navigateur sur une sortie à 10 groupes, sauf le clic sur un tracé.
**À ne pas défaire** : un choix efface le survol, car la carte réaffirme son tracé cliqué en
sortie de survol et masquerait sinon le groupe choisi dans la météo.
