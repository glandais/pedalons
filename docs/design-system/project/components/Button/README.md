# Button

Les boutons et liens d'action : un plein par carte, des neutres, un subtil pour effacer, des liens rouges pour quitter.

Rendu statique écrit à la main d'après `frontend/src/lib/theme.ts` (Mantine `Button`) et BRANDING §5.4, §7.7, §8.3.

## Variantes

- **Plein** (`primary`, texte `on-primary`, survol `primary-hover`) : l'appel à l'action — « Rejoindre », « Changer pour B », « Créer une sortie ». **Un seul par carte.**
- **Neutre** (`default` : fond `body`, bordure `border`) : « GPS », un seul par page, dans l'en-tête.
- **Subtil** : « Effacer les filtres ».
- **Désactivé** (`disabled-*`) : « Complet ».
- **Danger plein** : seulement dans une confirmation de suppression.
- **Lien rouge** (`danger`) : « Quitter le groupe », « Se désinscrire » — sans confirmation.

## Mesures

Hauteur minimale **44 px au doigt, 36 px à la souris** au-delà de 48 em ; `radius-md` ; 14 px, 600. `ActionIcon` en taille `lg`, toujours avec un nom accessible et une infobulle. Focus : anneau `focus-ring`.

## Libellés

Infinitif court ; état en cours en nom + « … » (« Inscription… »). Supprimer se confirme toujours : « Voulez-vous vraiment supprimer cette annonce ? Cette action est irréversible. »
