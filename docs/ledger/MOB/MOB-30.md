---
id: MOB-30
title: "Parcours"
status: done
group: "Couverture e2e Patrol"
done: 2026-09-29
---

## Livré

`MOB-30` **Parcours** (29 septembre 2026) — un cycliste d'aucune équipe cherche dans l'onglet Parcours : le parcours public d'une équipe publique sort, jamais son parcours réservé aux membres ni celui d'une équipe privée (aussi vérifié par `/api/routes`) ; la bascule liste/carte garde la recherche ; la fiche du parcours dessine son profil altimétrique (tiré du GPX téléversé) et « Utilisée dans » ne nomme que la sortie publique. Un membre trouve les deux parcours de l'équipe ; un filtre de revêtement réduit la liste, un filtre sans résultat mène à l'état vide filtré ; « Utilisée dans » ajoute la sortie réservée aux membres et le voyage (« via l'étape … »), jamais la sortie sans parcours — `routes_visibility_test.dart`. *Non couvert : le tracé sur la carte et le popup de la vue Carte (tuiles et valhalla absents de la stack e2e, seule la présence de la vue est vérifiée), la section Parcours d'une équipe, les autres filtres (distance, dénivelé, vent, « Autour de moi »), le tri et la densité.*
