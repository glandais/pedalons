# Cartes et tracés

Les couleurs et les contrôles des cartes interactives et des vignettes. Source : `docs/BRANDING.md`
§3.7, §3.8 et §7.6.

## Couleurs d'un tracé

- **Pente** : seules les montées se colorent, de `slope-climb-0` (vert, 0 %) à `slope-climb-18`
  (magenta, 18 % et plus) en passant par le jaune et le rouge ; plats et descentes en
  `slope-neutral`. Même règle pour la carte et le profil altimétrique.
- **Revêtement** : l'aplat de sa famille (§4 du README), celui du thème clair dans les deux thèmes ;
  les trois classes grises prennent chacune une nuance (asphalte foncé, hors réseau moyen, inconnu
  pâle en clair ; l'inverse en sombre).
- **Vent** : Dos `fam-teal`, Travers `fam-gray`, Face `fam-orange`, nuance 6 dans les deux thèmes ;
  un tronçon sans vent connu prend `slope-neutral`, jamais du gris. Toujours une légende en mots
  (« Dos 32 km · Travers 18 km · Face 40 km »).
- **Plusieurs parcours** sur une carte : `route-palette-1` à `route-palette-10`, dans l'ordre ;
  carte multi-parcours d'une liste : `map-multi-route`, `map-multi-route-hover` au survol.
- Marqueurs : `map-start`, `map-end`, `map-hover`. Point de parcours : pastille de sa famille,
  anneau blanc de 2 px, pictogramme foncé sur un disque clair (jaune, orange, teal, vert), blanc
  sinon.

## Vignette de parcours

Carré strict 80 / 120 / 160 px, `radius-md`, bordure `border`, image en 2× ; **une image par
thème** (fond cartographique clair ou sombre) ; tracé d'un parcours en rouge ; pas de marqueurs.
Chargement : même carré en `surface-hover`, `IconRoute` 24 px en `text-dimmed`. Sans vignette :
rien.

## Contrôles d'une carte

La même zone sur toutes les cartes : recherche en haut à gauche, caméra (zoom, nord, localiser,
plein écran) en colonne haut gauche, affichage (fond, traces) en colonne haut droite, outils de la
tâche en barre en bas au centre, échelle et crédit sur la ligne du bas. 36 px à la souris, 44 px au
doigt, `radius-md`, jamais plus de cinq boutons par colonne ; chaque icône a un nom accessible.
L'app n'affiche jamais la position de la personne sur une carte.

## Annonces

**Un secteur, jamais un point** : la position est floutée à ~1 km. Une carte d'annonce dessine une
zone ; le texte dit « Secteur {lieu} », sans épingle.
