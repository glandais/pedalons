# RideCard

La carte d'une sortie dans un fil ou une liste (`PublicationCard`, type `RIDE`) : image, date, départ, badges d'exception, personnes inscrites, météo et statistiques.

Rendu statique écrit à la main d'après `frontend/src/components/card/PublicationCard.tsx`. Règles communes à l'app et au site (BRANDING §7.1, KIT §9).

## Structure, de haut en bas

1. **Image de 160 px**, coins supérieurs `radius-md` : la première photo ; sinon la carte du tracé (claire ou sombre selon le thème) ; sinon le dégradé `gradient-ride-*` à 135° et `IconBike` 48 px en blanc à 80 %. En haut à gauche, la **boîte du jour posée** ; en haut à droite, seulement aujourd'hui ou demain, une pastille « Aujourd'hui » / « Demain » (jamais sur une sortie annulée ou passée).
2. Padding `space-md`. Lien d'équipe optionnel, petit et atténué, hors du contexte d'une équipe.
3. **Ligne titre** : logo d'entité 32 px (`radius-md`) s'il existe, titre en h4 tronqué sur une ligne, la **ligne de départ** (« Départ 09:00 »), l'extrait à 150 caractères en `text-dimmed`. À droite, la pile de badges (écart 4 px).
4. **Ligne sociale** : grappe d'avatars (Avatar), et la vignette du parcours 160 px **sauf** si l'image est déjà la carte du tracé. Pas de barre de places sur cette carte.
5. **Ligne météo** quand il y a une prévision : « 9–13 °C · ↗ 18 km/h · Pluie 20 % ».
6. **Statistiques** poussées en bas, écart `space-md` : icône 16 px + texte 14 px atténué. **Un compteur à zéro ne s'affiche pas.** La date n'y est pas : c'est la boîte du jour.

Toute la carte est cliquable. Au survol : `shadow-md`, rien d'autre.

## Ce que fournit l'appelant

La sortie telle que l'API la donne : la distance est déjà calculée pour la personne qui lit (aucune carte ne la recalcule). **Pour une personne non membre, ni grappe, ni nom, ni avatar : le compte seul.**
