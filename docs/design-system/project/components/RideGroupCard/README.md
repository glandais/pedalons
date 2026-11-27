# RideGroupCard

La carte d'un groupe sous une sortie : chiffres, météo, personnes inscrites, barre de places et le contrôle d'inscription de la personne qui lit.

Rendu statique écrit à la main d'après `frontend/src/components/ride/RideGroupCard.tsx` (BRANDING §7.7, KIT §9 R5–R8).

## Contenu

Nom ; **la personne capitaine seulement si le groupe en a une** (le plus souvent non : rien alors, jamais la personne qui a créé la sortie) ; distance · D+ · vitesse ; ligne météo ; lien vers le parcours ; compte « 11/12 personnes » (« 11 personnes » sans maximum) en 14 px couleur texte ; grappe d'avatars (sans la personne capitaine, qu'une ligne nomme déjà) ; **barre de places en `primary`, en `danger` quand le groupe est plein**, aucune sans maximum.

## Contrôle, selon la personne qui lit

| État | Contrôle |
|---|---|
| Inscrite nulle part | « Rejoindre », bouton plein ; pendant l'appel « Inscription… » |
| Son groupe | badge « J'y vais » en haut, contour `primary` sur la carte, lien rouge « Quitter le groupe » au pied |
| Inscrite dans un autre groupe | « Changer pour C », bouton plein, en un seul appel |
| Groupe plein | « Complet », désactivé, même avec une inscription ailleurs |
| Sortie annulée | aucun contrôle |

**Jamais de confirmation** pour rejoindre, changer ou quitter. Une erreur s'affiche dans la carte. Un seul bouton plein par carte. L'export « GPS » n'est pas sur cette carte : il est dans l'en-tête de la page.

## Pour une personne non membre

Le compte seul : ni grappe, ni noms, ni capitaine.
