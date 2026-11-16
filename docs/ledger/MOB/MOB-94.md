---
id: MOB-94
title: "La météo sur la carte, palier 3 lot B : sortie solo et voyages"
status: done
done: 2026-10-25
---

## Livré

`MOB-94` **La météo sur la carte, palier 3 lot B : sortie solo et voyages** (25 octobre 2026,
contrat inchangé) — le mode Météo (puce sous la carte encastrée, tracé coloré, légende et crédit,
pastilles et feuille en plein écran) gagne le détail d'une sortie solo (`ride_detail_page.dart`,
seul le parcours du groupe unique se colore), la carte d'une étape (`RouteMap` via un point
d'extension générique `RouteMapLayer`, sans notion de météo dans le dossier routes) et la carte
d'ensemble du voyage (`trip_map.dart` : chaque étape colorée par son vent, pastilles de toutes les
étapes, légende qui additionne les legs et dit lesquels sont comptés). Brique commune
`weather_map_layer.dart` (couleurs mémorisées par leg, pastilles, puce, interrupteur, légende),
reprise par le groupe ; `tripMapWindModeProvider` (une clé par voyage, partagé entre la carte
d'ensemble et celle d'une étape) ; `PdlMapTrack.emphasized`. Plan [`2026-10-24-weather-on-map.md`](../../plans/archive/2026-10-24-weather-on-map.md). Couvert par
`ride_solo_weather_map_test.dart`, `trip_map_weather_test.dart`, `stage_map_weather_test.dart`,
`ride_detail_page_test.dart`, `pdl_map_controller_test.dart`. **À ne pas défaire** : un tracé
coloré par le vent est `emphasized` (opacité et largeur du sélectionné), sinon la nuance 6 est
délavée à 50 % ; le mode du voyage ne s'éteint que si la page **perdait** une prévision qu'elle
montrait ; pas de légende quand aucune étape colorée n'est dessinée ; un parcours masqué dans les
couches retire légende, crédit et puce ; les pastilles d'un voyage ont un préfixe d'id par étape.
