# Pédalons

Pédalons est une plateforme d'équipes cyclistes : sorties, voyages, parcours GPX, publications et
annonces, sur un site web (React + Mantine) et une app mobile (Flutter). Ce design system en est
la charte, lue par les personnes et par les agents qui dessinent pour le produit.

> **Copie dérivée.** Les valeurs viennent du code : `frontend/src/lib/theme.ts` (web),
> `mobile/lib/core/theme/pdl_colors.dart` (Flutter, et seule source des fonds doux sombres),
> `contracts/brand-colors.yaml` (code couleur métier) et `docs/BRANDING.md` (la charte écrite).
> Quand ce système et le code divergent, **le code a raison** ; ce système se republie depuis
> `docs/design-system/` du dépôt.

## 1. Essence

Sobre, utilitaire, **dense en information**. L'identité ne cherche pas l'effet : elle sert la
lecture rapide d'un contenu très structuré (une sortie a une date, des groupes, des places, un
parcours ; un parcours a une distance, un dénivelé, un revêtement, un profil).

1. **La donnée avant la décoration.** Chaque carte porte des statistiques chiffrées avec icône.
   Pas d'illustration gratuite : sans photo, un dégradé du type de contenu (`gradient-*`) et
   l'icône du type.
2. **La couleur est sémantique, jamais esthétique.** Une couleur = un type d'entité, un statut,
   un rôle, un revêtement, une catégorie de col (§4). Ne jamais recolorer une carte « pour varier ».
3. **Parité clair / sombre stricte.** Le produit suit la préférence système ; tout écran existe
   dans les deux thèmes. Le clair est le défaut.

À éviter : dégradés décoratifs, cartes à bordure gauche colorée, emoji, illustrations, mascottes,
formules enthousiastes.

## 2. Logo

Un « P » dessiné en cadre de vélo, orange `brand-orange` sur un carré arrondi bleu `brand-blue`
(rayon 96 px sur 512, soit 18,75 % du côté). Fichiers dans le groupe d'assets **Logos**.

- **Le logo est bleu et orange, l'interface est indigo** (`primary`). Cette dissociation est
  voulue : jamais un bouton bleu de logo, jamais un logo indigo.
- Dans l'en-tête du site, le nom s'écrit en texte, pas en logotype : « Pédalons », 20 px, 700,
  couleur `primary`. Toujours avec l'accent aigu.

## 3. Couleurs

Employez les jetons par **rôle**, jamais une valeur brute.

| Rôle | Jetons |
|---|---|
| Fonds | `body` (page et cartes), `surface-alt` (champs, bloc de départ), `surface-raised` (menus, modales + `shadow-md`), `surface-hover` |
| Bordures | `border` (cartes, champs, vignettes), `border-subtle` (séparateurs) |
| Texte | `text`, `text-bright` (titres), `text-dimmed` (statistiques, extraits), `text-placeholder` (invites seulement), `anchor` (liens) |
| Primaire | `primary` (bouton plein, actif, barre de places), `primary-hover`, `primary-soft` / `primary-on-soft` (badge « J'y vais », boîte du jour), `primary-faint`, `focus-ring` |
| États | `success*`, `warning*`, `danger*`, `neutral*`, `done-soft` / `done-on-soft` (« Terminée »), `disabled-*` |
| Voiles | `overlay`, `overlay-solid` (superpositions sur une carte, pastille posée sur une image) |

Règles :

- **Aplat en nuance 6 en clair, 8 en sombre** ; **fond doux** (`*-soft`) = nuance 1 en clair, et
  texte dessus (`*-on-soft`) = nuance 9 en clair, 0 en sombre.
- `primary` est une nuance plus foncée que l'indigo Mantine en clair (indigo-7), et `text-dimmed`
  est hors palette : c'est ce qui tient 4,5:1. Ne pas « remettre » les valeurs Mantine.
- `warning` porte un texte foncé (`neutral-on-soft`), jamais blanc. La paire `warning-soft` /
  `warning-on-soft` de la source échoue en clair : à garder pour des badges courts.
- En sombre, l'ombre porte peu : c'est la `border` qui sépare les surfaces.

## 4. Code couleur métier — à respecter à la lettre

Source unique : `contracts/brand-colors.yaml`. Chaque valeur d'énumération a une **famille** ; la
famille donne trois jetons, `fam-<famille>` (aplat), `fam-<famille>-soft` et `fam-<famille>-on-soft`.
Par défaut un badge est **doux** ; les catégories de col et les points de parcours sont en
**aplat**.

| Énumération | Valeurs → famille |
|---|---|
| Type de contenu | Sortie `blue` · Publication `grape` · Voyage `teal` |
| Annonce | Vente `green` · Location `indigo` · Recherche `orange` |
| Statut | Brouillon `gray` · Publié `green` · Annulé `red` |
| Rôle | Administrateur `grape` · Organisateur `blue` · Membre `gray` |
| Revêtement | Route `gray` · Gravel `orange` · VTT `green` · Mixte `teal` |
| Visibilité | Public `blue` · Non listé `orange` · Équipe uniquement `gray` |
| Vent relatif | Dos `teal` · Travers `gray` · Face `orange` — toujours doublé du libellé et d'une flèche |
| Catégorie de col (aplat) | HC `grape` · 1 `red` · 2 `orange` · 3 `yellow` (texte foncé) · 4 `green` |
| Point de parcours (aplat, pastille) | Regroupement `indigo` · Ravitaillement, Café `orange` · Eau `blue` · Danger `red` · Col `grape` · Point de vue `teal` · Départ réel `green` · Séparation `yellow` · Toilettes, Magasin, Info `gray` |

- États dérivés côté client : « J'y vais » `primary` doux, « Terminée » / « Terminé » `done-soft`,
  « Supprimé » **rouge en aplat** (pour se distinguer d'« Annulé »).
- Une valeur inconnue se rend en `gray`.
- Image de repli d'une carte sans photo : dégradé à 135° de `gradient-<type>-from` à
  `gradient-<type>-to` (sortie, publication, voyage, équipe, annonce), icône du type 48 px en blanc
  à 80 %.

## 5. Typographie

**Inter seule**, pour tout le produit (fichiers dans `fonts/`, 400 à 700) ; pile monospace
système pour les coordonnées. Pas de serif, pas de police d'accompagnement.

- Titres h1–h4 en 700, tailles fluides (24 → 34 px pour h1) ; **h4 est le titre de carte**.
- **`text-sm` (14 px) est la taille de travail** : statistiques, filtres, secondaire.
- Graisses : 400 corps · 500 libellés, onglets · 600 valeurs chiffrées · 700 titres, badges,
  heure de départ.
- **Badges : 10 px, 700, CAPITALES, interlettrage 0,25 px** — le seul endroit en capitales.
- Titres : nom sans article, capitale initiale seule (« Parcours », « Cols et montées »).

## 6. Formes, espacements, densité

- **`radius-md` (8 px) partout** : cartes, boutons, champs, vignettes, logos. `radius-pill` pour
  badges, chips, avatars. Les cartes de l'app Flutter seules prennent 12 px.
- **`space-md` (16 px)** : padding des cartes, gouttière de grille. Valeurs fines 2 / 4 / 8 px
  dans les cartes.
- Cartes **plates au repos** (bordure seule), `shadow-md` au survol, rien d'autre.
- **Cible tactile 44 px** au doigt ; le site descend volontairement à 36 px à la souris au-delà
  de 48 em.
- Densité moyenne : 4 statistiques au plus sur une ligne, titre tronqué sur une ligne, extrait
  coupé à 150 caractères (2 lignes). **Un compteur à zéro ne s'affiche pas.**
- Conteneur 1140 px ; en-tête 56 px (60 px au bureau).

## 7. Iconographie

- **Web : Tabler Icons**, trait seul, 24×24, `stroke-width: 2`, couleur héritée du texte. Jamais
  de version pleine, jamais d'icône dessinée à la main. **Mobile : Material Icons**, style
  *outlined*.
- Tailles : **16 px** (statistiques, sections de bouton, chips — la dominante), 14 px (menus),
  18 px (alertes, ligne de départ), 24 px (vignette vide), 48 px (image de repli).
- Sens fixes : `IconCalendar` date · `IconClock` départ · `IconUsers` personnes · `IconMap`
  distance · `IconArrowUp` dénivelé · `IconRoute` parcours · `IconBike` sortie · `IconArticle`
  publication · `IconUsersGroup` équipe · `IconTag` annonce · `IconStack2` groupes ou étapes ·
  `IconMessageCircle` commentaires · `IconGps` export du parcours · `IconMapPin` lieu de départ —
  **jamais sur une annonce**.

## 8. Composants signature

Fiches et aperçus dans **Components** : Badge, Boîte du jour, Carte de sortie, Carte de parcours,
Carte de groupe, Avatar, Chips de filtre, Boutons. Les cartes du site et de l'app suivent les mêmes
règles ; quand l'une s'en écarte, c'est elle qui est en retard. Les aperçus sont des **rendus
statiques écrits à la main** d'après le code ; les vrais composants sont React + Mantine
(`frontend/src/components/`) et Flutter (`mobile/lib/`).

## 9. Invariants produit — un dessin ne doit jamais les contredire

- **Une annonce montre un secteur, jamais une épingle** : sa position est floutée à ~1 km ; on
  écrit « Secteur Brest », sans `IconMapPin`, et une carte dessine une zone, pas un point.
- **Les noms des membres ne sortent jamais de l'équipe** : pour une personne non membre, le
  compte seul (« 12 personnes ») — ni grappe d'avatars, ni nom, ni capitaine, ni auteur.
- **Le plus souvent, un groupe n'a pas de capitaine** : alors on n'affiche rien, et jamais la
  personne qui a créé la sortie à sa place.
- **Un badge signale une exception** : jamais « Publié » sur une carte ; la visibilité seulement
  quand elle diffère de celle de l'équipe.
- **Un seul bouton plein par carte** ; rejoindre, changer de groupe ou quitter ne se confirment
  jamais, supprimer se confirme toujours.

## 10. Accessibilité

Texte à 4,5:1 sur son fond dans les deux thèmes (3:1 à 24 px et plus) ; chaque contrôle a un nom
accessible (« Ouvrir le menu », « Filtres, 2 actifs ») ; un bouton-icône a son infobulle ; la
couleur ne porte jamais seule un sens (le vent a son libellé et sa flèche, le statut son mot).

## 11. Écriture

Le français du produit a ses règles : vouvoiement, épicène sans point médian, lexique imposé.
Voir la section **Lexique et ton**.

## Non synchronisé

- Les composants ne sont pas construits depuis le code (pas de `bundle.js`) : React + Mantine ne
  s'empaquette pas seul, les aperçus sont des rendus statiques à la main.
- Les jetons CSS `--pdl-*` des anciennes maquettes ne sont pas repris : ils ne doivent pas entrer
  dans le site.
- Les marques de tiers (Garmin, Wahoo, Hammerhead) de `assets/` ne sont pas reprises.
- Les tailles de titres sont celles du bureau ; les valeurs fluides `clamp()` sont dans les notes
  d'usage.
