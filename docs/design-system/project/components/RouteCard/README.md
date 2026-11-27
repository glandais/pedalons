# RouteCard

La carte d'un parcours : vignette cartographique pleine largeur, titre et extrait, distance et dénivelé, badge de revêtement.

Rendu statique écrit à la main d'après `frontend/src/components/card/RouteCard.tsx`. L'aperçu montre la vignette en chargement (`surface-hover` + `IconRoute` 24 px) : les vraies vignettes sont des images de carte, une par thème.

## Structure

1. **Vignette pleine largeur** (≈ 200 px de haut, demandée en 400 px), claire ou sombre selon le thème. Sans vignette : le dégradé de repli et l'icône du type.
2. Padding `space-md`, lien d'équipe optionnel.
3. Logo d'entité 40 px + titre h4 + extrait sur 2 lignes.
4. **Deux statistiques**, plus les commentaires s'il y en a : `IconMap` distance (« 68 km »), `IconArrowUp` dénivelé (« 1 240 m »), `IconMessageCircle`. Unités selon la préférence (métrique ou impérial), espace insécable.
5. **Rangée de badges** en bas, écart `space-xs` : revêtement (Route, Gravel, VTT, Mixte), puis la visibilité seulement si elle diffère de celle de l'équipe.

Dans « Utilisé dans », la plage d'un voyage s'écrit « ven. 20 → dim. 22 nov. ».
