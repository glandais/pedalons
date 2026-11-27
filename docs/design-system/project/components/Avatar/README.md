# Avatar

Le rond qui représente une équipe ou une personne : photo, ou initiales sur une teinte stable tirée du nom ; en grappe sur les cartes.

Rendu statique écrit à la main d'après `frontend/src/components/team/TeamAvatar.tsx`, `frontend/src/lib/avatarTint.ts` et `PdlAvatar` (mobile).

## Équipe (`TeamAvatar`)

Cercle (`radius-pill`), 16 / 26 / 38 / 56 / 84 px. Logo recadré `cover` s'il existe ; sinon les initiales des deux premiers mots en capitales sur un aplat choisi par hachage du nom parmi `red, orange, yellow, lime, green, teal, cyan, blue, indigo, violet, grape, pink`. Info-bulle avec le nom complet.

## Personne

Sans photo, deux initiales au plus, **en blanc**, sur `avatar-0` … `avatar-10` : indice = hachage du nom affiché (`hash × 31 + unité UTF-16`, gardé sur 31 bits) modulo 11. Les onze teintes sont foncées et identiques dans les deux thèmes. **La personne qui lit est toujours en `primary`** : l'indigo lui est réservé. La table existe en deux endroits qui doivent rester identiques (`avatarTint.ts`, `pdl_colors.dart`).

## Grappe

Pastilles de 26 px (`avatar-cluster-size`), recouvrement de 4 px, 5 visibles puis une pastille grise « +N », et « Voir tout » dès que « +N » paraît. **Jamais pour une personne non membre de l'équipe** : le compte seul.
