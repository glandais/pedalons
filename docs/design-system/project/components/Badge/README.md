# Badge

Pastille de 18 px qui dit le type, l'état, le rôle, le revêtement ou la visibilité d'un contenu, dans la couleur de sa famille métier.

Rendu statique écrit à la main d'après `frontend/src/components/card/common/Badge.tsx` (Mantine `Badge`, `variant="light"`, `size="sm"`) et `mobile/lib/core/theme/enum_colors.dart`.

## Anatomie

- Hauteur 18 px, padding horizontal `space-8`, `radius-pill`.
- Texte : style `badge` — 10 px, 700, CAPITALES, interlettrage 0,25 px. Seul endroit du produit en capitales.
- Icône optionnelle de 12 px à gauche.

## Couleur

- **Doux par défaut** : fond `fam-<famille>-soft`, texte `fam-<famille>-on-soft`. La famille vient de `contracts/brand-colors.yaml` (README §4), jamais d'un choix esthétique.
- **Aplat** pour les catégories de col et les points de parcours : fond `fam-<famille>` ; texte `#212529` sur le jaune (col 3), blanc sinon.
- Dérivés : « J'y vais » en `primary-soft` / `primary-on-soft`, « Terminée » en `done-soft` / `done-on-soft`, « Supprimé » en rouge **aplat**.
- Le blanc sur l'aplat rouge ou orange en clair est sous 4,5:1 : c'est le rendu de la source (Mantine `autoContrast`), gardé tel quel.

## Sur une carte

**Un badge signale une exception.** Dans l'ordre, et seulement ceux qui s'appliquent : Supprimé, le type, **un seul** état (Annulé, En cours, Terminée / Terminé, Brouillon), J'y vais. Jamais « Publié ». La visibilité seulement quand elle diffère de celle de l'équipe ; jamais sur une annonce.

## Ce que fournit l'appelant

Le libellé traduit (épicène, lexique imposé) et la valeur d'énumération, d'où se déduit la famille.
