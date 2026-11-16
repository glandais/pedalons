---
id: MOB-35
title: "Détail d'une sortie : participants et exports"
status: done
group: "Couverture e2e Patrol"
done: 2026-09-29
---

## Livré

`MOB-35` **Détail d'une sortie : participants et exports** (29 septembre 2026) — « Voir la
liste » réunit les inscrits des deux groupes (total 2, une ligne chacun, ni le lecteur ni le
créateur) ; la pastille de la carte des groupes nomme le premier groupe, puis celui dont on touche
la carte ; la carte de groupe propose « GPX » (et « FIT » si le parcours en a un) d'après les assets
du parcours, pas « Envoyer vers un appareil » sans service GPS connecté, et « GPX » ouvre la feuille
de partage du système sur un fichier GPX (lue dans l'arbre natif) — `ride_participants_map_test.dart`.
Deux défauts trouvés en chemin et corrigés : les exports n'étaient pas câblés sur la carte de groupe
(05b20faf), et changer de groupe levait « pdl-track-src already exists » (poses de la carte non
sérialisées, ec5df0df). *Non couvert : l'envoi vers un appareil (il faut un service GPS connecté
par OAuth, hors de portée de la stack e2e), l'export FIT jusqu'à la feuille de partage, les tracés
eux-mêmes (vue native MapLibre, illisible par Patrol) et le plein écran de la carte.*
