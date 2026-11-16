---
id: WEB-94
title: "« Météo du parcours » d'un groupe, refaite (16 octobre 2026)"
status: done
group: "Mesure d'audience du site"
done: 2026-10-16
---

## Livré

### `WEB-94` « Météo du parcours » d'un groupe, refaite (16 octobre 2026)

`WEB-94` **La page d'un groupe répond d'abord aux quatre questions d'un cycliste, puis détaille
le parcours tronçon par tronçon et passage par passage** (2026-10-16, aucun changement de
contrat) — l'ancien bloc empilait départ, bande de vent et points de passage sans
dire s'il ferait froid, s'il pleuvrait, d'où viendrait le vent ni si le groupe rentrerait avant
la nuit. La section `GroupWeatherSection` occupe désormais toute la largeur sous la grille
statistiques/carte de `RideGroupPage` (l'ancre `#meteo` et son `ErrorBoundary` l'ont suivie) ;
les statuts (terminée, annulée, `OUT_OF_RANGE`, `NO_LOCATION` réservé aux organisateurs, étape
sans prévision) se comportent comme avant.
- **Quatre verdicts** (`RouteVerdicts.tsx`, calculs purs dans `windPhases.ts`) : températures
  (« 7 °C → 16 °C », départ et ressenti, heure la plus chaude), pluie (alerte nommée et « Dès … »,
  sinon « Sec » avec le pic et sa fenêtre, « 0 % » à part, « — » quand aucun point ne donne de
  probabilité), vent (dominant sur chaque moitié ; « face jusqu'au km X, dos après le km Y »
  seulement quand toute phase de face finit avant la première phase de dos, sinon les totaux),
  jour (marge avant le coucher, « après le coucher », « Arrivée de nuit » passé une heure, départ
  avant le lever ; tuile absente sans coucher). Un verdict à surveiller prend un pictogramme
  d'alerte, sa réponse garde la couleur du texte.
- **« Le vent, tronçon par tronçon »** : les tronçons fusionnés en phases (`windPhases`), en
  mots et avec une flèche, totaux en légende. Au bureau, c'est la **première ligne de la table**,
  chaque phase au-dessus de ses propres colonnes (`phaseColumns`, deux demi-colonnes par point) :
  une barre à part, à la largeur des kilomètres, ne tombait jamais en face des heures (corrigé le
  16 octobre 2026, `windPhases.test.ts` « phaseColumns »). Une phase plus courte
  que l'écart entre deux points n'a **aucun point à elle** (`checkpoints` vide) : son
  `firstCheckpoint` ne sert qu'à la sélection et aux heures, et la phase cliquée est gardée dans
  la sélection plutôt que retrouvée depuis le point.
- **« Heure par heure, à votre passage »** : au bureau, une table défilante (colonne d'intitulés
  collante, unité de vitesse dite dans l'intitulé, courbe de température SVG unique, heures
  12 h sur deux lignes, `scroll-padding` pour qu'un focus ne passe pas sous les intitulés) ; au
  téléphone, une bande compacte, cinq repères sous le centre de leur colonne, un curseur natif,
  puis la liste « Par tronçon » (une phase ouverte à la fois) au lieu de la barre, illisible à
  390 px. Un panneau de détail commun au point choisi ; une ligne masquée l'annonce, sauf quand le
  curseur, dont `aria-valuetext` le dit déjà, l'a choisi. Un point sans prévision reste
  sélectionnable.
- Contrastes : intitulés en couleur de texte (jamais `dimmed`), courbe et anneaux de sélection en
  `--mantine-color-primary-text`, anneau de focus à l'intérieur de l'anneau de sélection,
  `WindArrow` en nuance 9 de sa famille en clair et `-text` en sombre (≥ 3:1 sur blanc et sur sa
  teinte).

Tests vitest : `windPhases.test.ts` (fusion des phases, phase sans point, verdicts, courbe,
repères, écart des points), `GroupWeatherSection.test.tsx` (tuiles, alerte de pluie, sec, 0 %,
pluie inconnue, arrivée après le coucher et de nuit, sans coucher, barre des phases, phase courte
cliquée, sélection au clic, par la barre, la liste et le curseur, annonce, point sans prévision,
chaque statut), `RideGroupPage.test.tsx`. Vérifié dans un navigateur sur la vraie « Raymond Ride
300 » (clair, sombre, 390 px).
**À ne pas défaire** : le vent n'est **jamais dit par la seule couleur** (mot et flèche à côté de
chaque bande) ; ses couleurs viennent de `RELATIVE_WIND_COLORS` (`contracts/brand-colors.yaml`),
jamais d'une table locale ; les deux mises en page sont dans le balisage et basculées en CSS
(`visibleFrom`/`hiddenFrom`), jamais par une mesure JS, pour que serveur et navigateur rendent le
même arbre ; le client affiche `daylight` tel que l'API l'envoie (`API-123`) ; une probabilité de
pluie absente n'est jamais lue « 0 % » ni « Sec ».
