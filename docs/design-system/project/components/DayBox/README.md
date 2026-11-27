# DayBox

La boîte du jour : la date d'une sortie ou d'un voyage en trois lignes centrées, jour, chiffre, mois — la seule date d'une carte.

Rendu statique écrit à la main d'après `frontend/src/components/common/DayBox.tsx` (web) et `_DateBlock` / `_DayTile` (mobile).

## Anatomie

- 56 à 72 px de large, `radius-md`.
- Jour abrégé « sam. » : style `day-label` (12–13 px, 600), couleur `primary-on-soft`.
- Chiffre : style `day-number` (22–30 px, 700), couleur `text-bright`.
- Mois abrégé « avr. » : 12–13 px, 500.
- **Hors de l'année en cours, une quatrième ligne donne l'année**, au style du mois ; la boîte grandit en hauteur, jamais en largeur.

## Variantes

- **À plat** (listes, agenda, bloc de départ) : fond `primary-soft` ; un voyage prend `fam-teal-soft`.
- **Posée** sur l'image d'une carte : fond blanc, `shadow-sm`, en haut à gauche à 16 px.

## Avec elle

La ligne de départ sous le titre de la carte : `IconClock` 18 px en `primary`, puis « Départ 09:00 » (style `start-time`). Pour une personne inscrite, l'heure est celle de son groupe. Format : « 09:00 », jamais « 09h00 ».
