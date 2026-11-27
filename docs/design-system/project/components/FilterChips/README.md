# FilterChips

Les filtres d'une liste : un bouton « Filtres » qui déplie un panneau sur le site, une rangée de chips dans l'app.

Rendu statique écrit à la main d'après BRANDING §7.3 et §7.10 (`PdlChipRow`, `PdlChip` au mobile).

## Site

Recherche et tri toujours visibles en tête. « Filtres » (`IconFilter` à gauche, chevron à droite) déplie un panneau bordé qui ne contient que les critères (grille 1 → 4 colonnes, gouttière 16 px). Actif : bouton teinté avec un **badge de compte** (nom accessible « Filtres, 2 actifs ») et, à sa droite, « Effacer les filtres » en `subtle` avec `IconX`. Un critère de type est un segmenté « Tout / Sorties / Voyages ».

## App

Recherche épinglée, puis une rangée de chips qui défile, fondu sur les 28 derniers pixels. Chaque chip : pilule de 34 px dans une cible de 44, 14 px, padding 12 px.

1. **Tri** en premier (bordure `text`, chevron + critère).
2. **Filtres actifs** : `primary-soft`, texte `primary-on-soft` en 600, croix à droite ; toute la pastille retire le filtre.
3. **Filtres disponibles** : transparent, bordure `border`, texte `text-dimmed`.

## Règles

Le compteur du bouton compte exactement ce qu'« Effacer les filtres » lève ; **le tri n'est pas un filtre**. Vide filtré : « Aucun parcours pour ces filtres » · « Rien ne correspond à : … » · « Effacer les filtres ».
