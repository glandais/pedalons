# Pédalons — Identité visuelle et thème

La charte de Pédalons : logo et icônes générées, palette et code couleur métier, typographie,
rayons, espacements, iconographie, composants signature, ton éditorial. Deux sources portent ces
valeurs ; elles s'accordent sur le code couleur métier — et doivent continuer à s'accorder — mais
chacune fait foi sur autre chose. À lire avant de changer une couleur dans l'une d'elles :

| Source | Fait foi sur | Ne fait pas foi sur |
|---|---|---|
| **Ce fichier** | Icônes et fichiers générés, méta/SEO, le thème **web** tel que Mantine le rend (variables CSS, échelles de nuances, valeurs par défaut des composants), et tout ce qu'aucun code ne porte : typographie, rayons, ombres, espacements, iconographie, composants signature, lexique français | Les valeurs Flutter |
| [`mobile/lib/core/theme/`](../mobile/lib/core/theme/) (`pdl_colors.dart`, `pdl_tokens.dart`, `pdl_typography.dart`) | Les jetons de l'app **Flutter** — et le *seul* endroit où vivent les **paires sombres dérivées des fonds doux de badge**, puisqu'aucune maquette ne fournissait de mode sombre. `pdl_colors.dart` documente la règle de dérivation et la vérifie sur les cinq paires que ce fichier publie | Le web |

Pour le web, le code reste la référence :
[`frontend/src/lib/theme.ts`](../frontend/src/lib/theme.ts). Quand un tableau de ce fichier le
contredit, c'est `theme.ts` qui a raison — et ce fichier qu'il faut corriger.

**Le code couleur métier est sémantique, jamais esthétique** : une couleur = un type d'entité, un
statut, un rôle, un revêtement ou une catégorie de col. Il a **une source unique**,
[`contracts/brand-colors.yaml`](../contracts/brand-colors.yaml) (§3.6), dont `pnpm generate-brand-colors`
tire `badgeColors.generated.ts` au web et `enum_colors.generated.dart` au mobile : le changer
ailleurs n'est pas possible, et le changer là change les deux clients.

Trois pièges à connaître :

- **Le minimum de 44 px est une règle tactile.** Le web descend volontairement à 36 px au-delà de
  48 em. Ne pas lire la feuille de style des maquettes comme une spécification web sur ce point.
- **Ne jamais introduire les variables CSS `--pdl-*` dans le site.** Ce sont les variables du moteur
  de maquettage (le §9 en donne le jeu complet, clair et sombre ; [`pedalons.css`](pedalons.css)
  est le sous-ensemble en mode clair qu'ont chargé les écrans mobile v2, et fait foi sur leurs
  métriques). Le site exprime déjà la même
  charte en thème Mantine : une seconde couche de variables créerait deux sources de vérité. Les
  classes de jetons Flutter `Pdl*` sont une autre affaire — c'est le vrai thème de l'app, et elles
  sont justes.
- **Le mode sombre des fonds doux de badge n'est pas ici en entier.** Ce fichier n'en publie que
  cinq paires ; les autres ont été **dérivées** pour la v2 par la règle
  `soft(sombre) = nuance 9 × 0,5`, `on-soft(sombre) = nuance 0`. La table complète vit dans
  [`pdl_colors.dart`](../mobile/lib/core/theme/pdl_colors.dart), qui fait foi là-dessus.

Les §1 et §4 à §9 viennent de la charte écrite le 25 juillet 2026 pour produire les maquettes de la
v2, à partir du code de l'époque (`theme.ts`, `index.css`, les composants, les jetons Flutter,
`locales/fr/common.json`). Son périmètre est celui d'un membre : consultation et participation ;
l'administration, la création et l'édition n'y sont pas décrites.

---

## 1. Essence de marque

Pédalons est une **plateforme de club cycliste multi-tenant**. L'identité visuelle est
délibérément **sobre, utilitaire et dense en information** : elle ne cherche pas l'effet, elle
sert la lecture rapide d'un contenu très structuré (une sortie a une date, des groupes, des
places, un parcours ; un parcours a une distance, un dénivelé, un revêtement, un profil).

Trois principes :

1. **La donnée avant la décoration.** Chaque carte affiche des statistiques chiffrées avec icône.
   Pas d'illustration gratuite : quand il n'y a pas de photo, on met un dégradé porteur de sens
   (couleur du type de contenu) et l'icône du type.
2. **Le code couleur est sémantique, jamais esthétique.** Une couleur = un type d'entité, un
   statut, un rôle, un revêtement ou une catégorie de col. Ne jamais recolorer une carte « pour
   varier ».
3. **Parité clair / sombre stricte.** Le produit suit la préférence système (`auto`). Tout écran
   existe dans les deux modes ; les vignettes cartographiques elles-mêmes existent en deux versions
   (`thumbnailLight` / `thumbnailDark`).

**Par défaut, le produit est en mode clair** (fond blanc ; `useResolvedColorScheme`, le remplaçant de
`useComputedColorScheme('light')` qui tient compte du SSR, retombe sur `light` partout dans le code), mais le mode sombre est un citoyen de première classe, pas une
option dégradée.

---

## 2. Logo & icône

| Élément | Valeur |
|---|---|
| Concept | Lettre « P » stylisée en cadre de vélo (tube, guidon, fourche), dessinée dans Inkscape |
| Fond de l'icône | `#228be6` (bleu de marque, Mantine `blue-6`) |
| Forme du « P » | `#fd7e14` (orange de marque, Mantine `orange-6`) |
| Support | Carré arrondi, rayon 96 px sur canevas 512×512 (≈ 18,75 % du côté) |

Le bleu `#228be6` et l'orange `#fd7e14` sont **les couleurs de l'icône**, pas la couleur primaire
de l'interface. L'interface est **indigo**. Cette dissociation est volontaire et doit être
conservée : le logo reste bleu/orange, les boutons restent indigo.

Dans l'en-tête web, le nom du produit est écrit en texte, pas en logotype :
`Text size="xl" fw={700} c="primary"` → **« Pédalons » en indigo, 20 px, graisse 700**.

L'accent aigu est significatif : le produit s'écrit **Pédalons** dans toute l'interface (le
dépôt s'appelle `tribly`, ce n'est pas un nom de marque).

### 2.1 Fichiers d'icône

Toutes les icônes sont générées depuis `assets/icon.svg` par `scripts/generate-icons.sh` (options
`--web`, `--mobile`, `--karoo`, `--garmin`, `--all`).

**Source** (`assets/`) :

| Fichier | Taille | Rôle |
|---|---|---|
| `inkscape.svg` | 512×512 | Source maîtresse (éditable dans Inkscape) |
| `icon.svg` | 512×512 | SVG nettoyé (entrée de la génération) |
| `icon-1024.png` | 1024×1024 | Intermédiaire rastérisé (généré) |

**Web** (`frontend/public/`, via `--web` / `pnpm generate-icons`) :

| Fichier | Taille | Rôle |
|---|---|---|
| `icon.svg` | 512×512 | Favicon SVG (copie de la source) |
| `favicon.ico` | multiple | Favicon navigateur |
| `pwa-64x64.png` | 64×64 | Petite icône PWA |
| `pwa-192x192.png` | 192×192 | Icône PWA |
| `pwa-512x512.png` | 512×512 | Grande icône PWA |
| `apple-touch-icon-180x180.png` | 180×180 | Écran d'accueil iOS |
| `maskable-icon-512x512.png` | 512×512 | PWA *maskable* (zone de sécurité) |

**Mobile** (`mobile/`, via `--mobile` / `dart run flutter_launcher_icons`) :

| Fichier | Taille | Rôle |
|---|---|---|
| Icônes de lancement Android/iOS | variables | Générées par flutter_launcher_icons depuis `icon-1024.png` |
| `ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png` | 168×168 | Image de lancement iOS @1x |
| `ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png` | 336×336 | Image de lancement iOS @2x |
| `ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png` | 504×504 | Image de lancement iOS @3x |
| `android/app/src/main/res/drawable-{m,h,xh,xxh,xxxh}dpi/ic_stat_notification.png` | 24→96 | Petite icône de notification Android |

L'icône de notification n'est **pas** l'icône de lancement : Android n'en garde que le canal alpha
et peint en blanc tout pixel restant, si bien que l'icône de lancement s'afficherait en carré blanc,
le P avalé par son propre fond. `generate_android_notification_icon` garde donc ce qui est *orange*
dans `icon.svg` — le P vélo — et jette tout le reste, bordure comprise.

**Karoo** (`karoo/app/src/main/res/`, via `--karoo`) : `mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png`,
de 48×48 à 192×192, alpha aplati sur fond `#228be6`.

**Garmin** (`garmin-app/resources/drawables/`, via `--garmin`) : `launcher_icon.png`, 60×60, RGB
16 bits, alpha aplati sur fond `#228be6`.

### 2.2 Méta / SEO

| Propriété | Valeur |
|---|---|
| Theme-color navigateur / splash | `#228be6` |
| Titre | Par page, construit par `src/lib/seo.ts` à partir du `meta()` de la route ; à défaut, le nom d'application du domaine (`appName` de `/api/config`, sinon `Pédalons`) |
| Description | Par page ; à défaut, la clé i18n `home.subtitle` (« Votre plateforme pour organiser vos sorties cyclistes ») |
| Image Open Graph | `/og-image.png`, 1200×630 — défaut du site ; une page qui a sa propre image l'utilise (voir [frontend/docs/LINK_PREVIEW.md](../frontend/docs/LINK_PREVIEW.md)) |
| `<title>` statique | `Pédalons` dans `index.html` — repli pour la SPA de dev sans JS uniquement, retiré par le serveur SSR |

---

## 3. Palette

### 3.1 Thème web

| Propriété | Valeur |
|---|---|
| Couleur primaire | `primary`, couleur virtuelle associée à Mantine `indigo` |
| Police | Inter, system-ui, sans-serif (pile complète au §4.1) |
| Rayon par défaut | `md` (8 px) |
| Schéma de couleurs | `auto` (suit la préférence système) |
| Contraste automatique | Activé (`autoContrast: true`, `luminanceThreshold: 0.3`) |
| Surcharges de contraste | `cssVariablesResolver` (`theme.ts`) : `primary` une nuance plus foncée en clair (aplat 7, liens 8), `dimmed` hors palette, liens en `primary-3` en sombre — pour tenir 4,5:1 (WCAG 1.4.3) |

**Couleurs virtuelles** — à employer plutôt que les couleurs brutes pour tout ce qui porte un sens :

| Jeton | Associé à | Aplat clair | Aplat sombre | Emploi |
|---|---|---|---|---|
| `primary` | `indigo` | `#4263eb` (7) | `#3b5bdb` (8) | Boutons, liens, états actifs |
| `success` | `green` | `#40c057` (6) | `#2f9e44` (8) | Actions positives, publié |
| `warning` | `yellow` | `#fab005` (6) | `#f08c00` (8) | États de vigilance |
| `danger` | `red` | `#fa5252` (6) | `#e03131` (8) | Actions destructrices, erreurs |

### 3.2 Jetons sémantiques — mode clair et mode sombre

Valeurs exactes issues de Mantine 9 (palettes par défaut inchangées depuis Mantine 8).

| Rôle | Clair | Sombre | Jeton Mantine |
|---|---|---|---|
| Fond de page | `#ffffff` | `#242424` | `--mantine-color-body` |
| Surface (carte, panneau) | `#ffffff` | `#242424` | `Paper` = fond du body + bordure |
| Surface alternée / champs | `#f8f9fa` | `#2e2e2e` | `gray-0` / `dark-6` |
| Surface élevée (menu, modale, popover) | `#ffffff` + ombre `md` | `#2e2e2e` + ombre `md` | `--mantine-color-default` |
| Survol de surface | `#f8f9fa` | `#3b3b3b` | `--mantine-color-default-hover` |
| Texte sur surface par défaut | `#000000` | `#ffffff` | `--mantine-color-default-color` |
| Bordure standard | `#ced4da` | `#424242` | `--mantine-color-default-border` |
| Bordure discrète (séparateur) | `#dee2e6` | `#2e2e2e` | `gray-3` / `dark-6` |
| Texte primaire | `#000000` | `#c9c9c9` | `--mantine-color-text` |
| Texte accentué (titres) | `#000000` | `#ffffff` | `--mantine-color-bright` |
| Texte secondaire / atténué | `#666d75` | `#9a9a9a` | `--mantine-color-dimmed` — hors palette : 4,71:1 sur `gray-1`, 4,83:1 sur `#2e2e2e` |
| Texte d'espace réservé | `#adb5bd` | `#696969` | `--mantine-color-placeholder` |
| Lien / ancre | `#3b5bdb` | `#91a7ff` | `--mantine-color-anchor` (`primary-8` / `primary-3`) |
| Texte d'erreur | `#fa5252` | `#e03131` | `--mantine-color-error` |
| **Primaire de marque (indigo)** | `#4263eb` | `#3b5bdb` | `primary` rempli |
| Primaire — survol | `#3b5bdb` | `#364fc7` | `primary` rempli survol |
| Primaire — fond doux | `#dbe4ff` | `#1b2864` | `primary` variante *light* |
| Primaire — texte sur fond doux | `#364fc7` | `#edf2ff` | `primary-light-color` |
| Anneau de focus | `#4263eb` | `#748ffc` | `primary-text` (`index.css`) — 4,98:1 sur blanc, 5,23:1 sur `#242424`, 4,58:1 sur `#2e2e2e` |
| Succès | `#40c057` | `#2f9e44` | `success` → green |
| Succès — fond doux | `#d3f9d8` | `#16451f` | green variante *light* |
| Alerte / avertissement | `#fab005` | `#f08c00` | `warning` → yellow |
| Alerte — fond doux | `#fff3bf` | `#733c00` | yellow variante *light* |
| Erreur / danger | `#fa5252` | `#e03131` | `danger` → red |
| Erreur — fond doux | `#ffe3e3` | `#651515` | red variante *light* |
| Neutre / inactif | `#868e96` | `#343a40` | gray |
| Neutre — fond doux | `#f1f3f5` | `#111315` | gray variante *light* |
| Désactivé (fond) | `#e9ecef` | `#2e2e2e` | `--mantine-color-disabled` |
| Désactivé (texte) | `#adb5bd` | `#696969` | `--mantine-color-disabled-color` |
| Désactivé (bordure) | `#dee2e6` | `#424242` | `--mantine-color-disabled-border` |
| Voile / superposition | `rgba(255,255,255,0.9)` | `rgba(36,36,36,0.9)` | `OVERLAY_BG` |
| Voile opaque | `rgba(255,255,255,0.95)` | `rgba(36,36,36,0.95)` | `OVERLAY_BG_SOLID` |

### 3.3 Couleurs d'accent

| Accent | Clair (nuance 6) | Sombre (nuance 8) | Emploi |
|---|---|---|---|
| Bleu de marque | `#228be6` | `#1971c2` | Logo, sorties, liens, tracé de parcours |
| Orange de marque | `#fd7e14` | `#e8590c` | Logo, gravel, annonces « recherche », bannières |
| Raisin (grape) | `#be4bdb` | `#9c36b5` | Publications (posts), rôle administrateur, col HC |
| Turquoise (teal) | `#12b886` | `#099268` | Voyages, revêtement mixte |
| Violet | `#7950f2` | `#6741d9` | Dégradé des cartes d'équipe |
| Cyan | `#15aabf` | `#0c8599` | Fin du dégradé « sortie » |
| Rose (pink) | `#e64980` | `#c2255c` | Fin du dégradé « publication » |
| Citron vert (lime) | `#82c91e` | `#66a80f` | Avatars d'équipe (rotation par hachage) |

### 3.4 Variantes Mantine : aplat et fond doux

Règle générale du produit : **les aplats (`filled`) utilisent la nuance 6 en clair et la nuance 8
en sombre** (plus foncée, plus contrastée ; codifié côté Flutter dans
`BrandColors.resolve(light, dark, brightness)`).

| Couleur | Aplat clair (6) | Aplat sombre (8) |
|---|---|---|
| indigo | `#4c6ef5` | `#3b5bdb` |
| blue | `#228be6` | `#1971c2` |
| green | `#40c057` | `#2f9e44` |
| red | `#fa5252` | `#e03131` |
| yellow | `#fab005` | `#f08c00` |
| orange | `#fd7e14` | `#e8590c` |
| grape | `#be4bdb` | `#9c36b5` |
| teal | `#12b886` | `#099268` |
| gray | `#868e96` | `#343a40` |
| violet | `#7950f2` | `#6741d9` |
| cyan | `#15aabf` | `#0c8599` |
| pink | `#e64980` | `#c2255c` |
| dark | `#2e2e2e` | `#1f1f1f` |
| lime | `#82c91e` | `#66a80f` |

La variante **`light`** (fond doux) pose un fond teinté qui change aussi avec le mode. En clair,
c'est la **nuance 1**, pas la nuance 0 — cela a changé avec Mantine 8, et les valeurs ci-dessous
sont celles réellement rendues (les jetons Flutter portent bien `#DBE4FF` pour indigo). Elle se voit
sur tous les badges du produit ; le *texte* posé dessus est en nuance 9 en clair et en nuance 0 en
sombre.

| Couleur | Fond clair (nuance 1) | Fond sombre |
|---|---|---|
| indigo | `#dbe4ff` | `rgba(27, 40, 100, 1)` |
| blue | `#d0ebff` | `rgba(12, 50, 86, 1)` |
| green | `#d3f9d8` | `rgba(22, 69, 31, 1)` |
| red | `#ffe3e3` | `rgba(101, 21, 21, 1)` |
| grape | `#f3d9fa` | `rgba(67, 23, 78, 1)` |
| orange | `#ffe8cc` | `rgba(109, 36, 8, 1)` |
| yellow | `#fff3bf` | `rgba(115, 60, 0, 1)` |
| gray | `#f1f3f5` | `rgba(17, 19, 21, 1)` |

### 3.5 Échelles complètes (référence Mantine)

| Couleur | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
|---|---|---|---|---|---|---|---|---|---|---|
| dark | `#C9C9C9` | `#b8b8b8` | `#828282` | `#696969` | `#424242` | `#3b3b3b` | `#2e2e2e` | `#242424` | `#1f1f1f` | `#141414` |
| gray | `#f8f9fa` | `#f1f3f5` | `#e9ecef` | `#dee2e6` | `#ced4da` | `#adb5bd` | `#868e96` | `#495057` | `#343a40` | `#212529` |
| red | `#fff5f5` | `#ffe3e3` | `#ffc9c9` | `#ffa8a8` | `#ff8787` | `#ff6b6b` | `#fa5252` | `#f03e3e` | `#e03131` | `#c92a2a` |
| pink | `#fff0f6` | `#ffdeeb` | `#fcc2d7` | `#faa2c1` | `#f783ac` | `#f06595` | `#e64980` | `#d6336c` | `#c2255c` | `#a61e4d` |
| grape | `#f8f0fc` | `#f3d9fa` | `#eebefa` | `#e599f7` | `#da77f2` | `#cc5de8` | `#be4bdb` | `#ae3ec9` | `#9c36b5` | `#862e9c` |
| violet | `#f3f0ff` | `#e5dbff` | `#d0bfff` | `#b197fc` | `#9775fa` | `#845ef7` | `#7950f2` | `#7048e8` | `#6741d9` | `#5f3dc4` |
| **indigo** | `#edf2ff` | `#dbe4ff` | `#bac8ff` | `#91a7ff` | `#748ffc` | `#5c7cfa` | **`#4c6ef5`** | `#4263eb` | `#3b5bdb` | `#364fc7` |
| blue | `#e7f5ff` | `#d0ebff` | `#a5d8ff` | `#74c0fc` | `#4dabf7` | `#339af0` | `#228be6` | `#1c7ed6` | `#1971c2` | `#1864ab` |
| cyan | `#e3fafc` | `#c5f6fa` | `#99e9f2` | `#66d9e8` | `#3bc9db` | `#22b8cf` | `#15aabf` | `#1098ad` | `#0c8599` | `#0b7285` |
| teal | `#e6fcf5` | `#c3fae8` | `#96f2d7` | `#63e6be` | `#38d9a9` | `#20c997` | `#12b886` | `#0ca678` | `#099268` | `#087f5b` |
| green | `#ebfbee` | `#d3f9d8` | `#b2f2bb` | `#8ce99a` | `#69db7c` | `#51cf66` | `#40c057` | `#37b24d` | `#2f9e44` | `#2b8a3e` |
| lime | `#f4fce3` | `#e9fac8` | `#d8f5a2` | `#c0eb75` | `#a9e34b` | `#94d82d` | `#82c91e` | `#74b816` | `#66a80f` | `#5c940d` |
| yellow | `#fff9db` | `#fff3bf` | `#ffec99` | `#ffe066` | `#ffd43b` | `#fcc419` | `#fab005` | `#f59f00` | `#f08c00` | `#e67700` |
| orange | `#fff4e6` | `#ffe8cc` | `#ffd8a8` | `#ffc078` | `#ffa94d` | `#ff922b` | `#fd7e14` | `#f76707` | `#e8590c` | `#d9480f` |

### 3.6 Code couleur métier (à respecter à la lettre)

La table fait foi dans [`contracts/brand-colors.yaml`](../contracts/brand-colors.yaml), et nulle
part ailleurs : pour chaque énumération du contrat, la **famille** de chaque valeur, le **style** de
la série, et les dégradés de repli. Après l'avoir éditée, `pnpm generate-brand-colors` (depuis
`frontend/`) régénère `frontend/src/lib/badgeColors.generated.ts` et
`mobile/lib/core/theme/enum_colors.generated.dart` ; le générateur refuse une valeur absente du
contrat, une valeur du contrat sans famille et une famille hors liste. Seul le choix de la famille
est partagé : le web la rend en nuances Mantine (nuance 6 en aplat, 8 en sombre, fond doux du §3.4),
le mobile par `PdlFamilyTone` dans `enum_colors.dart`.

Ce que la table ne dit pas d'elle-même :

- **Doux par défaut, aplat pour les catégories de col et les types de point de parcours** (`style: filled`). En aplat, le jaune
  de `CAT3` porte un texte foncé (`#212529`), les autres du blanc — `autoContrast` au web, `onFill`
  au mobile.
- **`WaypointType`** (points de parcours d'auteur, `WEB-100` C3d) : un pictogramme Tabler (§6) sur
  un disque de la famille du type. Sur la carte et le profil, nuance 6 dans les deux thèmes (comme
  `TrackSurface` : les aplats sombres s'éteignent sur un fond de carte sombre), anneau blanc de
  2 px, pictogramme `#212529` si la luminance du disque dépasse 0,3 (jaune, orange, teal et vert),
  blanc sinon — même règle au web (`isLightColor`) et au mobile (`Color.computeLuminance`) ;
  dans la liste et la popup, `ThemeIcon` en aplat (nuance du thème, §3.4). Rouge réservé au
  `DANGER`, vert au `REAL_START` comme le départ (§3.7), raisin au `SUMMIT` comme `HC`.
- **`ROAD` est gris doux partout**, badge comme trait de rappel. Le near-black `dark` qu'il portait
  au web (et en trait de rappel au mobile) n'est plus une famille de badge : sa famille est `gray`,
  comme `DRAFT`, `MEMBER` et `TEAM`.
- **Une valeur inconnue** d'un client en retard sur le contrat se rend en `gray`.
- **Le revêtement d'une piste (`TrackSurface`) se rend en trait, pas en badge** : l'aplat de sa famille
  — celui du thème clair dans les deux thèmes, comme le site (les aplats sombres du mobile, un cran
  plus foncés, s'éteignent sur le fond de carte sombre) —, sauf les trois classes grises, qui prennent chacune une nuance (asphalte foncé, hors réseau moyen,
  inconnu pâle en clair ; l'inverse en sombre) — `TRACK_SURFACE_SHADES` au web, `TrackSurfaceStroke`
  et les jetons `mapSurface*` de `pdl_colors.dart` au mobile (`MOB-81`).
- **Le vent relatif** (`RelativeWind`, météo des sorties) : `TAIL` teal, `CROSS` gray, `HEAD`
  orange, en doux. La couleur n'y porte **jamais seule** : barre d'exposition et points de passage
  la doublent toujours du libellé (« Vent de face », « de travers », « dans le dos ») et d'une
  flèche orientée. Les **conditions météo** (soleil, pluie…) n'ont pas de couleur : leur icône prend
  celle du texte. Leur en donner une passerait par le YAML, jamais par une table dans un client.
- **Les états dérivés côté client** — « J'y vais » (indigo), « Terminée » (gris foncé), « Supprimé »
  (rouge **en aplat**, pour se distinguer de `CANCELLED`) — ne sont portés par aucune énumération :
  ils restent hors du YAML (`PdlDerivedTones` au mobile, `DeletedBadge` au web).
- **Les dégradés de repli** (image d'une carte sans photo, 135°) sont des paires de nuances Mantine
  (`blue-6` → `cyan-5` pour une sortie…) ; le générateur en tire les variables CSS du web et les
  hexadécimaux du mobile.

Les libellés de ces valeurs viennent des traductions de chaque client ; le lexique est au §8.2.

### 3.7 Couleurs cartographiques

| Élément | Clair | Sombre |
|---|---|---|
| Tracé du parcours (page de détail) | Coloré par la pente (voir « Profil altimétrique ») | idem |
| Tracé de la carte multi-parcours | `#1d32a8`, `#c90808` au survol | idem |
| Marqueur de départ | `green` nuance 6 `#40c057` | `green` nuance 8 `#2f9e44` |
| Marqueur d'arrivée | `red` nuance 6 `#fa5252` | `red` nuance 8 `#e03131` |
| Marqueur survolé | `blue` nuance 6 `#228be6` | `blue` nuance 8 `#1971c2` |
| Point de parcours | famille de son type (§3.6) | idem |
| Événement calendrier « Sortie » | `blue`, variante `light` | `blue`, variante `light` |
| Événement calendrier « Étape » | `green`, variante `light` | `green`, variante `light` |

**Palette multi-parcours** (superposition de plusieurs tracés, dans cet ordre) :
`#566B13`, `#1d32a8`, `#732C7B`, `#bdbd22`, `#c90808`, `#b81491`, `#628de3`, `#6dcc5c`,
`#c694d4`, `#e3a209`.

**Profil altimétrique** : la pente est mappée en HSL — vert `hsl(85, 86%, 62%)` à 0 %, rouge
`hsl(255, 86%, 62%)` à 18 % et au-delà, interpolation linéaire de la teinte. Neutre (segment sans
pente calculée) : `hsl(210, 86%, 62%)`.

---

## 4. Typographie

### 4.1 Familles

| Contexte | Famille |
|---|---|
| Web | `Inter, system-ui, Avenir, Helvetica, Arial, sans-serif` |
| Mobile Flutter | `Inter` embarquée dans l'app (`mobile/assets/fonts/inter/`, graisses 400 à 700, déclarée dans `pubspec.yaml`) — plus de `google_fonts` |
| Monospace | Pile monospace système (dénivelés, coordonnées, extraits techniques) |

Réglages de rendu appliqués globalement : `font-synthesis: none`,
`text-rendering: optimizeLegibility`, `-webkit-font-smoothing: antialiased`,
`-moz-osx-font-smoothing: grayscale`. **Inter uniquement** : une seule famille pour tout le
produit, pas de police d'accompagnement, pas de serif.

### 4.2 Titres — échelle fluide

Les titres sont responsives via `clamp()`. Graisse **700** pour tous les niveaux.

| Niveau | Taille | Interligne | Rendu mobile → desktop |
|---|---|---|---|
| h1 | `clamp(1.5rem, 5vw, 2.125rem)` | 1.2 | 24 px → 34 px |
| h2 | `clamp(1.25rem, 4vw, 1.625rem)` | 1.3 | 20 px → 26 px |
| h3 | `clamp(1.125rem, 3vw, 1.375rem)` | 1.4 | 18 px → 22 px |
| h4 | `clamp(1rem, 2.5vw, 1.125rem)` | 1.5 | 16 px → 18 px |

`h4` est le **titre de carte** partout dans le produit (`CardTitle` = `<Title order={4}>`).

### 4.3 Corps de texte

| Jeton | Taille | Interligne | Emploi |
|---|---|---|---|
| `xs` | 12 px (0,75 rem) | 1.4 | Métadonnées, mentions légales, pied de page |
| `sm` | 14 px (0,875 rem) | 1.45 | **Taille de travail** : statistiques de carte, libellés de filtre, secondaire |
| `md` | 16 px (1 rem) | 1.55 | Corps par défaut |
| `lg` | 18 px (1,125 rem) | 1.6 | Chapeau, texte de mise en avant |
| `xl` | 20 px (1,25 rem) | 1.65 | Nom du produit dans l'en-tête |

### 4.4 Graisses

| Graisse | Emploi |
|---|---|
| 400 | Corps de texte, descriptions |
| 500 | Libellés de formulaire, onglets, éléments de navigation |
| 600 | Valeurs chiffrées mises en avant (distance, dénivelé, places restantes) |
| 700 | Tous les titres h1–h4, nom du produit, texte des badges |

**Badges** : 10 px, graisse 700, `text-transform: uppercase`, interlettrage `0.25px`. C'est le
seul endroit du produit où l'on écrit en capitales.

---

## 5. Rayons, ombres, espacements, densité

### 5.1 Rayons

Rayon par défaut du thème : **`md` = 8 px**. C'est le rayon dominant : cartes, boutons, champs,
logos d'entité, vignettes de carte.

| Jeton | Valeur | Emploi |
|---|---|---|
| `xs` | 2 px | — |
| `sm` | 4 px | Petites puces internes |
| **`md`** | **8 px** | **Cartes, boutons, champs, panneaux, vignettes, logos** |
| `lg` | 16 px | Grands blocs de mise en page, feuilles modales mobiles |
| `xl` | 32 px | Rare |
| `xl` / pilule | 1000 px | Badges, chips de filtre, avatars (`radius="xl"`) |

Le mobile Flutter arrondit les cartes à **12 px** (`PdlRadii.card`), et seulement elles ; boutons,
champs et vignettes internes restent à **8 px** (`PdlRadii.md`) — légèrement plus rond que le web, cohérent avec Material 3.

### 5.2 Ombres

Ombres Mantine par défaut, très douces et multi-couches. Les cartes sont **plates au repos** (bordure
seule) et prennent `shadow-md` au survol, avec transition `box-shadow 0.2s, border-color 0.2s` —
voir §7.1.

| Jeton | Valeur |
|---|---|
| `xs` | `0 1px 3px rgba(0,0,0,.05), 0 1px 2px rgba(0,0,0,.1)` |
| `sm` | `0 1px 3px rgba(0,0,0,.05), 0 10px 15px -5px rgba(0,0,0,.05), 0 7px 7px -5px rgba(0,0,0,.04)` |
| **`md`** | `0 1px 3px rgba(0,0,0,.05), 0 20px 25px -5px rgba(0,0,0,.05), 0 10px 10px -5px rgba(0,0,0,.04)` |
| `lg` | `0 1px 3px rgba(0,0,0,.05), 0 28px 23px -7px rgba(0,0,0,.05), 0 12px 12px -7px rgba(0,0,0,.04)` |
| `xl` | `0 1px 3px rgba(0,0,0,.05), 0 36px 28px -7px rgba(0,0,0,.05), 0 17px 17px -7px rgba(0,0,0,.04)` |

En mode sombre, l'ombre porte peu : c'est la **bordure `#424242`** qui sépare les surfaces. Ne pas
compenser en assombrissant les ombres.

### 5.3 Espacements

| Jeton | Valeur | Emploi typique |
|---|---|---|
| `xs` | 10 px | Gouttière entre statistiques, groupe de badges |
| `sm` | 12 px | Écart logo ↔ titre, entre chips |
| **`md`** | **16 px** | **Padding intérieur des cartes et panneaux, gouttière de grille** |
| `lg` | 20 px | Séparation entre sections d'une page |
| `xl` | 32 px | Séparation entre grands blocs |

Valeurs fines utilisées ponctuellement dans les cartes : `2`, `4`, `8` px (pile de badges, ligne
icône + valeur).

### 5.4 Mise en page et densité

| Paramètre | Valeur |
|---|---|
| Largeur de conteneur | `Container size="lg"` — 71,25 rem / **1140 px**, centré |
| Hauteur d'en-tête | **56 px** en mobile, **60 px** à partir de `sm` (48 em) |
| Tiroir de navigation mobile | 300 px de large, sous le point de rupture `sm` |
| Hauteur minimale de bouton | **44 px** en mobile, **36 px** à partir de 48 em |
| Taille par défaut d'`ActionIcon` | `lg` (cible tactile confortable) |
| Notifications | Coin supérieur droit |
| Barre de chips de filtre (mobile) | Hauteur mesurée (pastille de 34 px dans une cible de 44), défilement horizontal, padding latéral 16 px |

**Points de rupture** : `xs` 36 em (576 px) · `sm` 48 em (768 px) · `md` 62 em (992 px) ·
`lg` 75 em (1200 px) · `xl` 88 em (1408 px).
Deux ruptures personnalisées existent pour les pages de détail : **64 em (1024 px)** fait passer
la carte en colonne collante (`position: sticky` sous l'en-tête + 16 px), **90 em (1440 px)** lui
fait occuper deux colonnes.

**Densité** : moyenne. Cartes à padding 16 px, listes à 4 statistiques maximum sur une ligne (la 4ᵉ est le
nombre de commentaires, masqué quand l'appelant n'y a pas accès),
titres tronqués sur une ligne (`lineClamp`), descriptions coupées à **150 caractères**. Les listes
longues (l'équipe `n-peloton` compte 1999 membres) utilisent le défilement infini côté mobile et
la pagination côté web — prévoir un état de squelette pour chaque type de carte.

---

## 6. Iconographie

| Plateforme | Bibliothèque |
|---|---|
| Web | **Tabler Icons** (`@tabler/icons-react`) — trait, 24×24, `stroke-width: 2` |
| Mobile | **Material Icons** (Flutter `Icons.*`), style *outlined* privilégié |

**Règle absolue du dépôt** : jamais de SVG dessiné à la main pour une icône, uniquement Tabler.
Les maquettes doivent donc puiser dans le jeu Tabler.

**Tailles employées** :

| Taille | Contexte |
|---|---|
| 14 px | Icônes de menu déroulant |
| **16 px** | **Statistiques de carte, sections gauches de bouton, chips** — la taille dominante |
| 18 px | Icônes de bannière / alerte |
| 24 px | Espace réservé de vignette |
| 48 px | Icône de type sur image de repli en dégradé, en blanc à 80 % d'opacité |

**Icônes récurrentes** (fréquence réelle dans le code, périmètre membre) :

| Icône | Sens |
|---|---|
| `IconCalendar` | Date et heure d'une sortie, d'une étape, du calendrier |
| `IconUsers` | Participants, nombre de membres |
| `IconMapPin` | Lieu de départ, lieu d'arrivée, point de rendez-vous |
| `IconMap` | Distance d'un parcours |
| `IconArrowUp` / `IconArrowDown` | Dénivelé positif / négatif |
| `IconRoute` | Parcours, voyage, vignette de repli |
| `IconBike` | Sortie |
| `IconArticle` | Publication |
| `IconUsersGroup` | Équipe |
| `IconTag` | Petite annonce |
| `IconStack2` | Nombre de groupes d'une sortie, nombre d'étapes d'un voyage |
| `IconDownload` | Téléchargement GPX / FIT |
| `IconDeviceMobile` | Envoi vers l'appareil (Karoo, Garmin) |
| `IconFilter`, `IconChevronDown` / `IconChevronUp`, `IconX` | Ouverture, repli et effacement des filtres |
| `IconEye` / `IconEyeOff` / `IconUsers` | Visibilité publique / non listée / réservée à l'équipe |
| `IconCheck` | Inscription confirmée |
| `IconMapSearch` | Exploration des parcours |
| `IconArrowsMaximize` | Carte en plein écran |
| `IconArrowLeft` | Retour |

**Points de parcours** (`WaypointType`, `WEB-100` C3d ; le mobile prend l'équivalent Material de
chacun en C3f, livré par `MOB-84`). Couleurs : `contracts/brand-colors.yaml` (§3.6).

| Type | Icône Tabler | Mobile (`PdlIcons`) | Libellé |
|---|---|---|---|
| `REGROUP` | `IconUsersGroup` | `waypointRegroup` (`groups_outlined`) | Regroupement |
| `SUPPLY` | `IconToolsKitchen2` | `waypointSupply` (`restaurant`) | Ravitaillement |
| `WATER` | `IconDroplet` | `waypointWater` (`water_drop_outlined`) | Point d'eau |
| `CAFE` | `IconCoffee` | `waypointCafe` (`local_cafe_outlined`) | Café, pause |
| `TOILETS` | `IconToiletPaper` | `waypointToilets` (`wc`) | Toilettes |
| `DANGER` | `IconAlertTriangle` | `waypointDanger` (`warning_amber_outlined`) | Danger |
| `SUMMIT` | `IconMountain` | `waypointSummit` (`landscape_outlined`) | Col, sommet |
| `VIEWPOINT` | `IconBinoculars` | `waypointViewpoint` (`photo_camera_outlined`, pas de jumelles en Material) | Point de vue |
| `BIKE_SHOP` | `IconTool` | `waypointBikeShop` (`build_outlined`) | Magasin de vélo |
| `REAL_START` | `IconPlayerPlay` | `waypointRealStart` (`play_arrow`) | Départ réel |
| `SPLIT` | `IconArrowsSplit2` | `waypointSplit` (`call_split`) | Séparation des groupes |
| `INFO` | `IconInfoSmall` | `waypointInfo` (`info_outline`) | Information |

**Icônes des sections d'équipe** (onglets de l'équipe, menu du fil d'Ariane ; décision du
6 octobre 2026, ledger `BRAND-6`, plan [`2026-10-06-team-agenda.md`](plans/archive/2026-10-06-team-agenda.md)
§2). Ce sont les icônes des *sections* : toutes les pages perso partagent la même. Le mobile prend
l'équivalent de chacune dans `PdlIcons`, jamais une icône Material choisie à part.

| Section | Icône web | Mobile (`PdlIcons`) |
|---|---|---|
| Tableau de bord | `IconLayoutDashboard` | `dashboard` |
| Agenda (sorties et voyages) | `IconCalendarEvent` | `agenda` |
| Publications | `IconArticle` | `post` |
| Parcours | `IconRoute` | `route` |
| Annonces | `IconTag` | `ad` |
| Membres | `IconUsers` | `people` |
| À propos | `IconInfoCircle` | `info` |
| Pages perso | `IconFileText` | `page` |

Les vues d'une liste (`ListViewSwitch`) : `IconLayoutGrid` Vignettes, `IconList` Lignes, `IconMap`
Carte, `IconCalendar` Calendrier — icônes seules, chacune avec son infobulle et son nom accessible.
Au mobile, l'Agenda n'a que Liste (`PdlIcons.list`) et Calendrier (`PdlIcons.calendar`), en
`PdlSegment.iconOnly`.

Style : **trait uniquement, jamais de version pleine**, couleur héritée du texte
(`currentColor`) — donc `#666d75` / `#9a9a9a` dans les statistiques atténuées, couleur du badge
quand l'icône est en `leftSection`.

---

## 7. Composants signature

### 7.1 Carte de sortie (`PublicationCard`, type `RIDE`)

Structure de haut en bas, dans un `Paper withBorder radius="md"` entièrement cliquable :

1. **Image d'en-tête, hauteur 160 px, sans marge, coins supérieurs arrondis à 8 px.**
   Priorité 1 : première photo de la publication, recadrée en `cover`, chargement paresseux.
   Priorité 2 (le cas le plus fréquent) : dégradé 135° `#228be6 → #22b8cf` avec `IconBike` 48 px
   en blanc à 80 % d'opacité, centrée.
2. **Padding intérieur 16 px.**
3. Lien d'équipe optionnel (petit, atténué) quand la carte apparaît hors du contexte d'une équipe.
4. **Ligne titre** : logo carré de l'entité 32 px (rayon 8 px) à gauche s'il existe ; à droite,
   `CardTitle` en h4/700 ; en dessous, aperçu Markdown de la description tronqué à 150 caractères,
   14 px, atténué. Tout à droite, **pile verticale de badges alignés à droite, écart 4 px** :
   badge de type (Sortie, bleu), badge de statut (Publié / Brouillon / Annulé), badge de visibilité.
5. **Ligne sociale** : groupe d'avatars circulaires des personnes inscrites (26 px, chevauchement, 5
   maximum puis pastille grise `+N`), une barre de progression des places, et à droite la
   **vignette du parcours en 160×160** (rayon 8 px, bordure 1 px `#ced4da` / `#424242`).
6. **Barre de statistiques**, poussée en bas de la carte (`mt="auto"`), écart 16 px, chaque
   statistique = icône 16 px + texte 14 px atténué :
   `📅 sam. 12 avril, 09h00` · `👥 12 personnes` · `🗂 3 groupes`.

Au survol : ombre `md`, rien d'autre — aucun soulèvement, aucun agrandissement. Elle est portée
par une classe CSS (`Card.module.css`, mixin `hover` de `postcss-preset-mantine`, donc sans effet
collant sur écran tactile) ; un `'&:hover'` dans la prop `styles` serait rendu en style inline et
ignoré (ledger `WEB-3`).

### 7.2 Carte de parcours (`RouteCard`)

Plus simple et plus horizontale :

1. **Vignette cartographique en pleine largeur** (hauteur naturelle ≈ 200 px), demandée en 400 px
   de large — **la version claire ou sombre selon le thème actif**.
2. Padding 16 px, lien d'équipe optionnel.
3. Logo d'entité 40 px + titre h4 + description tronquée.
4. **Deux statistiques, plus le nombre de commentaires quand il est visible** : `IconMap` +
   distance (`68 km`), `IconArrowUp` + dénivelé (`1 240 m`), `IconMessageCircle` + commentaires. Les unités suivent la préférence de l'utilisateur (métrique / impérial).
5. **Rangée de badges en bas**, écart 10 px : badge de revêtement (Route / Gravel / VTT / Mixte)
   + badge de visibilité.

### 7.3 Chip de filtre

Deux implémentations, à maquetter différemment :

**Web** — pas de chips : un bouton `variant="default"` « Filtres » avec `IconFilter` à gauche et
un chevron à droite, qui déplie un `Paper withBorder p="md"` contenant un champ de recherche
pleine largeur puis une grille de `Select` et de plages min/max
(`1 colonne → 2 (sm) → 3 (lg) → 4 (xl)`, gouttière 16 px). Quand au moins un filtre est actif, un
second bouton `variant="subtle"` « Effacer » avec `IconX` apparaît à droite.

**Mobile** — rangée de chips (`PdlChipRow`) au-dessus de la liste, hauteur mesurée, fondu sur les
28 derniers pixels ; chaque `PdlChip` est une pastille de 34 px dans une cible tactile de 44 :
- **1ʳᵉ position, toujours** : chip de tri (bordure `text`), avec chevron haut/bas 16 px + libellé
  du critère.
- Ensuite les **filtres actifs** : fond `primarySoft`, texte `primaryOnSoft` en 600, pas de
  coche, **croix de suppression à droite**, et **toute la pastille retire le filtre**.
- Enfin les **filtres disponibles non renseignés** : fond transparent, bordure `border`, texte
  `textDimmed`.

Forme dans les deux cas : **pilule**, 14 px de texte, 12 px de padding horizontal.

### 7.4 Badge de statut

`Badge` Mantine, `variant="light"`, `size="sm"` :
hauteur **18 px**, texte **10 px / 700 / CAPITALES / interlettrage 0,25 px**, padding horizontal
**8 px**, **rayon pilule**, fond = nuance 1 de la couleur en clair / teinte sombre dédiée en
sombre, texte = nuance 9 en clair / nuance 0 en sombre.

Exemples rendus : `PUBLIÉ` sur `#d3f9d8` texte `#2b8a3e` · `BROUILLON` sur `#f1f3f5` texte
`#212529` · `ANNULÉ` sur `#ffe3e3` texte `#c92a2a`.
Une icône optionnelle de 12 px peut être placée en section gauche.

### 7.5 Avatar d'équipe (`TeamAvatar`)

- **Cercle** (`radius="xl"`), tailles 16 / 26 / 38 / 56 / 84 px (xs → xl).
- Avec logo : image recadrée `cover`, demandée en 128 px.
- Sans logo : **initiales** (première lettre du premier mot + première lettre du deuxième mot,
  en capitales ; une seule lettre si le nom est en un mot) sur un aplat dont la couleur est
  **déterminée par un hachage du nom d'équipe** parmi 12 teintes, dans cet ordre :
  `red, orange, yellow, lime, green, teal, cyan, blue, indigo, violet, grape, pink`.
- Info-bulle avec flèche au survol, contenant le nom complet de l'équipe.

L'avatar utilisateur suit la même mécanique mais **toujours en indigo primaire**, avec deux
initiales maximum. En groupe : chevauchement, 5 visibles, puis une pastille grise `+N`.

### 7.6 Vignette de carte GPX (`RouteThumbnail`)

- **Carré strict** : 80 px (`sm`), 120 px (`md`), 160 px (`lg`). Image demandée en **2× la taille
  d'affichage** pour les écrans à haute densité.
- Rayon **8 px**, `overflow: hidden`, bordure 1 px `#ced4da` en clair / `#424242` en sombre
  (`--mantine-color-default-border`).
- **Deux fichiers distincts, un par thème** (`thumbnailLightUrl` / `thumbnailDarkUrl`, fonds
  `colorful` et `eclipse`) : seul le fond cartographique change avec le mode. Le tracé d'un
  parcours est rouge dans les deux ; ceux d'une sortie ou d'un voyage suivent la palette
  multi-parcours (§3.7).
- Pas de marqueurs de départ ni d'arrivée.
- État de chargement : carré de même taille, fond `#f8f9fa` / `#3b3b3b` (`default-hover`),
  `IconRoute` 24 px centrée en couleur atténuée (`#666d75` / `#9a9a9a`). En l'absence de
  vignette, rien n'est affiché.

Sur la page de détail d'un parcours ou d'une sortie, la carte interactive n'est plus une vignette
mais un panneau **collant** en colonne de droite à partir de 1024 px, sur deux colonnes à partir
de 1440 px, avec les superpositions (info-bulles, profil altimétrique) posées sur
`rgba(255,255,255,0.9)` / `rgba(36,36,36,0.9)`.

### 7.7 Groupe de sortie (inscription)

Bloc listé sous la sortie, avec pour chaque groupe : nom, capitaine du groupe, compteur
`{{current}}/{{max}} personnes`, lien vers le parcours, boutons `GPX` / `FIT`. L'action varie
selon l'état : **« Rejoindre »** (bouton plein indigo), **« J'y vais »** (badge indigo doux et
contour indigo sur le groupe, avec « Quitter » en bouton `outline`), **« Complet »** (badge gris
doux, sans bouton). C'est le principal appel à
l'action du parcours membre : il doit être le seul élément plein et coloré de la zone.

---

## 8. Ton éditorial des libellés français

### 8.1 Registre

**Vouvoiement, phrases courtes, vocabulaire cycliste français.** Le ton est celui d'un club : net,
factuel, jamais publicitaire ni familier. Aucune exclamation, aucun emoji dans les libellés,
aucune formule enthousiaste (« Génial ! », « C'est parti ! » sont hors marque).

### 8.2 Lexique imposé

| Concept | Terme français officiel | À ne pas écrire |
|---|---|---|
| Ride | **sortie** | « ride », « run », « balade » |
| Route | **parcours** | « itinéraire », « trace » |
| Post | **publication** | « article », « news » |
| Trip | **voyage** ; ses composants sont des **étapes** | « séjour », « tour » |
| Rides + trips of a team | **Agenda** (section : sorties et voyages ; filtres « À venir », « Je participe », « Passées ») ; état vide « Rien à l'agenda pour le moment » | « événements », « programme », « activités » |
| Ride or trip under way | **En cours** (badge dérivé, comme « J'y vais ») | « en direct », « live » |
| Ad | **annonce** (rubrique : **Annonces**) | « petite annonce » dans l'UI |
| Team | **équipe** | « club », « groupe » |
| Group (dans une sortie) | **groupe** | « niveau », « peloton » |
| Elevation gain | **dénivelé positif** | « D+ » dans un libellé long |
| Surface type | **type de revêtement** | « terrain » |
| Hilliness | **relief** (Plat / Vallonné / Montagneux) | « difficulté » |
| Climb | **montée** ; section **Cols et montées** | « ascension » |
| Waypoint | **point de parcours** ; section **Points du parcours** | « waypoint », « POI », « point d'intérêt » |
| Member | **membre** ; hors équipe, **compte** ou **personne** | « utilisateur » |
| Group leader | **capitaine** | « meneur », « leader » |
| Registered people | **personnes inscrites** ; compteur « 12 personnes », « 3 inscriptions » | « participants », « inscrits » |
| Registered (badge) | **J'y vais** | « Inscrit » |
| Ad author | **la personne qui a publié l'annonce** ; libellé « Publiée par » ; bouton « Répondre à l'annonce » | « vendeur », « annonceur » |
| Headwind / crosswind / tailwind | **vent de face** / **de travers** / **dans le dos** (court : Face, Travers, Dos) | « vent contraire », « vent latéral » |
| Stale forecast | **prévision ancienne** | « météo périmée », « obsolète » |

### 8.3 Règles d'écriture

- **Titres de page et de section : nom sans article**, capitale initiale seule.
  → « Parcours », « Annonces », « Groupes », « Cols et montées », « À propos de l'équipe ».
- **Boutons : verbe à l'infinitif**, court.
  → « Rejoindre », « Quitter », « Enregistrer », « Annuler », « Retour », « Filtres », « Effacer »,
  « Télécharger GPX », « Envoyer vers l'appareil », « S'abonner ».
- **États en cours : verbe substantivé + points de suspension.**
  → « Création... », « Enregistrement... », « Adhésion... », « Préparation en cours ».
- **États vides : un titre nominal + une phrase explicative.**
  → « Aucun parcours » / « Aucun parcours n'est disponible pour le moment. »
  → « Aucune publication pour le moment »
  → « Aucune annonce ne correspond à votre recherche. »
  Distinguer toujours *vide absolu* (« Aucun X ») de *vide filtré* (« Aucun X ne correspond à
  votre recherche. »).
- **Champs de recherche : verbe à l'infinitif en libellé, exemple concret en espace réservé.**
  → libellé « Rechercher des parcours », espace réservé « Rechercher par titre ou description... ».
  Les espaces réservés se terminent par des points de suspension.
- **Confirmations : question fermée + conséquence.**
  → « Voulez-vous vraiment quitter cette équipe ? »
  → « Voulez-vous vraiment supprimer cette annonce ? Cette action est irréversible. »
- **Notifications de succès : nom + participe passé + « avec succès ».**
  → « Annonce créée avec succès », « Annonce mise à jour avec succès ».
- **Erreurs : constat neutre, puis action possible.** Jamais de blâme.
  → « Email ou mot de passe incorrect », « Échec de l'ajout du membre. Veuillez réessayer. »
- **Compteurs : toujours pluralisés** (`_one` / `_many` / `_other`).
  → « 1 groupe » / « 3 groupes », « 1 étape » / « 4 étapes », « 12 personnes ».
- **Dates** : format français long abrégé, heure sur 24 h — sur le web, qui suit la langue ; le
  mobile suit le réglage 12 h / 24 h du téléphone (ledger `API-60`). Un rendez-vous lu d'un autre
  fuseau porte la mention « heure de Tokyo (ven. 01:00 chez vous) ». Le calendrier propose
  « Jour / Semaine / Mois », « Toute la journée », « +{{count}} autres ».
- **Unités** : `km` / `m` en métrique, `mi` / `ft` en impérial — l'utilisateur choisit dans ses
  préférences. Espace insécable entre le nombre et l'unité, séparateur de milliers = espace fine
  (`1 240 m`).
- **Apostrophe typographique** : le corpus existant utilise l'apostrophe droite (`'`). Rester
  cohérent avec l'existant plutôt que d'introduire `’`.
- **Accessibilité** : chaque contrôle porte un libellé explicite (« Ouvrir le menu »,
  « Fermer la fenêtre », « Aller au contenu principal », « Fil d'Ariane », « Changer le thème »).
  Les maquettes doivent prévoir ces textes, même invisibles.

### 8.4 Écriture inclusive : épicène d'abord

Pédalons s'adresse à tout le monde : aucun libellé ne suppose le genre de la personne qui le lit,
ni de celle dont il parle. L'API ne connaît pas le genre des membres, on ne peut donc pas accorder
au cas par cas : **on reformule de façon épicène**, sans point médian. Le point médian
(« inscrit·e·s ») allonge les badges et se lit mal aux lecteurs d'écran — il n'est pas employé.

- **Accords avec « vous » : tourner la phrase vers l'action ou l'objet.**
  → « Vous participez à 2 d'entre elles » (pas « Vous êtes inscrit »), « Votre inscription est dans
  le groupe A », « Votre session est ouverte en tant que… », « Connectez-vous pour… »,
  « Vous êtes la seule personne à administrer cette équipe », « Vous êtes l'unique membre ».
- **Confirmations** : « Voulez-vous vraiment… ? », jamais « Êtes-vous sûr… ? ».
- **Une personne nommée : verbe actif.** → « Léa a rejoint votre sortie », « Vous avez bloqué
  Léa » (pas « Léa s'est inscrit », « Léa est bloqué »).
- **Groupes de personnes : noms épicènes ou collectifs.** → *personne(s)*, *membre(s)*, *compte(s)*,
  *capitaine*, *inscription(s)*, *tout le monde* (pas « tous »), « qui organise {équipe} »,
  « l'administration de la plateforme », « Confiez l'administration à un autre membre ».
- **Les rôles gardent leur nom.** `ADMIN` et `ORGANIZER` s'affichent « Administrateur » et
  « Organisateur » (filtres, badges, compteurs « 3 administrateurs ») : ce sont des noms de
  fonction, partagés par le web, le mobile et la documentation. Dans une phrase qui décrit un
  droit, on cite le rôle plutôt que les personnes : « Le rôle Organisateur peut créer des
  sorties », « Visible des rôles Organisateur et Administrateur ».
- **Exceptions tolérées** : les formules figées (« © contributeurs OpenStreetMap », « Tous droits
  réservés ») et les accords qui portent sur une chose (« service connecté », « export prêt »).

### 8.5 Micro-copie de référence (extraits réels)

> « Votre plateforme pour organiser vos sorties cyclistes »
> « Dernières publications »
> « Parcourez les équipes cyclistes ou créez la vôtre »
> « Rejoindre l'équipe » · « Quitter l'équipe » · « Complet » · « J'y vais »
> « Voir le parcours » · « Voir toutes les personnes inscrites » · « Voir tout »
> « Masquer les filtres » · « Tous les niveaux » · « Prix à négocier »
> « Aucun groupe défini pour cette sortie. »
> « Parcours introuvable » · « Le parcours que vous recherchez n'existe pas. »

---

## 9. Annexe — jetons CSS des maquettes (`--pdl-*`)

Les variables du moteur de maquettage, pour **lire** les maquettes — pas pour produire du CSS de
production (voir l'en-tête). [`pedalons.css`](pedalons.css) en est la version chargée par les
écrans du projet Claude Design et fait autorité sur leurs métriques.

```css
/* ============================================================
   Pédalons — jetons de design
   Mode clair par défaut ; mode sombre via [data-theme="dark"]
   ou la préférence système.
   ============================================================ */

:root {
  /* ---- Marque ---- */
  --pdl-brand-blue: #228be6;
  --pdl-brand-orange: #fd7e14;
  --pdl-logo-radius-ratio: 0.1875; /* 96 / 512 */

  /* ---- Typographie ---- */
  --pdl-font-family: Inter, system-ui, Avenir, Helvetica, Arial, sans-serif;
  --pdl-font-mono: ui-monospace, SFMono-Regular, Menlo, monospace;

  --pdl-font-size-xs: 0.75rem;   /* 12 */
  --pdl-font-size-sm: 0.875rem;  /* 14 */
  --pdl-font-size-md: 1rem;      /* 16 */
  --pdl-font-size-lg: 1.125rem;  /* 18 */
  --pdl-font-size-xl: 1.25rem;   /* 20 */

  --pdl-line-height-xs: 1.4;
  --pdl-line-height-sm: 1.45;
  --pdl-line-height-md: 1.55;
  --pdl-line-height-lg: 1.6;
  --pdl-line-height-xl: 1.65;

  --pdl-font-weight-regular: 400;
  --pdl-font-weight-medium: 500;
  --pdl-font-weight-semibold: 600;
  --pdl-font-weight-bold: 700;

  --pdl-h1-size: clamp(1.5rem, 5vw, 2.125rem);
  --pdl-h1-line-height: 1.2;
  --pdl-h2-size: clamp(1.25rem, 4vw, 1.625rem);
  --pdl-h2-line-height: 1.3;
  --pdl-h3-size: clamp(1.125rem, 3vw, 1.375rem);
  --pdl-h3-line-height: 1.4;
  --pdl-h4-size: clamp(1rem, 2.5vw, 1.125rem);
  --pdl-h4-line-height: 1.5;
  --pdl-heading-weight: 700;

  --pdl-badge-font-size: 0.625rem; /* 10 */
  --pdl-badge-weight: 700;
  --pdl-badge-letter-spacing: 0.25px;
  --pdl-badge-transform: uppercase;

  /* ---- Rayons ---- */
  --pdl-radius-xs: 2px;
  --pdl-radius-sm: 4px;
  --pdl-radius-md: 8px;   /* dominant */
  --pdl-radius-lg: 16px;
  --pdl-radius-xl: 32px;
  --pdl-radius-pill: 1000px;
  --pdl-radius-default: var(--pdl-radius-md);
  --pdl-radius-mobile-card: 12px; /* Flutter */

  /* ---- Espacements ---- */
  --pdl-space-2: 2px;
  --pdl-space-4: 4px;
  --pdl-space-8: 8px;
  --pdl-space-xs: 10px;
  --pdl-space-sm: 12px;
  --pdl-space-md: 16px;  /* padding de carte */
  --pdl-space-lg: 20px;
  --pdl-space-xl: 32px;

  /* ---- Mise en page ---- */
  --pdl-container-max: 1140px;      /* Container size="lg" */
  --pdl-header-height: 56px;
  --pdl-header-height-sm: 60px;
  --pdl-navbar-width: 300px;
  --pdl-touch-target: 44px;
  --pdl-button-min-height: 44px;
  --pdl-button-min-height-desktop: 36px;
  --pdl-chip-bar-height: 40px;
  --pdl-card-image-height: 160px;
  --pdl-thumbnail-sm: 80px;
  --pdl-thumbnail-md: 120px;
  --pdl-thumbnail-lg: 160px;

  --pdl-breakpoint-xs: 36em;  /* 576 */
  --pdl-breakpoint-sm: 48em;  /* 768 */
  --pdl-breakpoint-md: 62em;  /* 992 */
  --pdl-breakpoint-detail: 64em; /* 1024 — carte collante */
  --pdl-breakpoint-lg: 75em;  /* 1200 */
  --pdl-breakpoint-xl: 88em;  /* 1408 */
  --pdl-breakpoint-map-wide: 90em; /* 1440 — carte sur 2 colonnes */

  /* ---- Ombres ---- */
  --pdl-shadow-xs: 0 1px 3px rgba(0, 0, 0, 0.05), 0 1px 2px rgba(0, 0, 0, 0.1);
  --pdl-shadow-sm: 0 1px 3px rgba(0, 0, 0, 0.05), 0 10px 15px -5px rgba(0, 0, 0, 0.05),
    0 7px 7px -5px rgba(0, 0, 0, 0.04);
  --pdl-shadow-md: 0 1px 3px rgba(0, 0, 0, 0.05), 0 20px 25px -5px rgba(0, 0, 0, 0.05),
    0 10px 10px -5px rgba(0, 0, 0, 0.04);
  --pdl-shadow-lg: 0 1px 3px rgba(0, 0, 0, 0.05), 0 28px 23px -7px rgba(0, 0, 0, 0.05),
    0 12px 12px -7px rgba(0, 0, 0, 0.04);
  --pdl-shadow-xl: 0 1px 3px rgba(0, 0, 0, 0.05), 0 36px 28px -7px rgba(0, 0, 0, 0.05),
    0 17px 17px -7px rgba(0, 0, 0, 0.04);

  --pdl-transition-card: box-shadow 0.2s, border-color 0.2s;

  /* ---- Dégradés de repli par type ---- */
  --pdl-gradient-ride: linear-gradient(135deg, #228be6 0%, #22b8cf 100%);
  --pdl-gradient-post: linear-gradient(135deg, #be4bdb 0%, #f06595 100%);
  --pdl-gradient-trip: linear-gradient(135deg, #12b886 0%, #51cf66 100%);
  --pdl-gradient-team: linear-gradient(135deg, #7950f2 0%, #5c7cfa 100%);
  --pdl-gradient-ad: linear-gradient(135deg, #ff922b 0%, #ffd43b 100%);

  /* ---- Palette multi-parcours ---- */
  --pdl-route-1: #566b13;
  --pdl-route-2: #1d32a8;
  --pdl-route-3: #732c7b;
  --pdl-route-4: #bdbd22;
  --pdl-route-5: #c90808;
  --pdl-route-6: #b81491;
  --pdl-route-7: #628de3;
  --pdl-route-8: #6dcc5c;
  --pdl-route-9: #c694d4;
  --pdl-route-10: #e3a209;

  /* ============ MODE CLAIR (défaut) ============ */

  /* Surfaces */
  --pdl-bg: #ffffff;
  --pdl-surface: #ffffff;
  --pdl-surface-alt: #f8f9fa;
  --pdl-surface-raised: #ffffff;
  --pdl-surface-hover: #f8f9fa;
  --pdl-overlay: rgba(255, 255, 255, 0.9);
  --pdl-overlay-solid: rgba(255, 255, 255, 0.95);

  /* Bordures */
  --pdl-border: #ced4da;
  --pdl-border-subtle: #dee2e6;

  /* Texte */
  --pdl-text: #000000;
  --pdl-text-bright: #000000;
  --pdl-text-dimmed: #666d75;
  --pdl-text-placeholder: #adb5bd;
  --pdl-link: #3b5bdb;

  /* Primaire de marque — indigo */
  --pdl-primary: #4263eb;
  --pdl-primary-hover: #3b5bdb;
  --pdl-primary-soft: #dbe4ff;
  --pdl-primary-soft-hover: #bac8ff;
  --pdl-primary-on-soft: #364fc7;
  --pdl-on-primary: #ffffff;

  /* États */
  --pdl-success: #40c057;
  --pdl-success-soft: #d3f9d8;
  --pdl-success-on-soft: #2b8a3e;
  --pdl-warning: #fab005;
  --pdl-warning-soft: #fff3bf;
  --pdl-warning-on-soft: #e67700;
  --pdl-danger: #fa5252;
  --pdl-danger-soft: #ffe3e3;
  --pdl-danger-on-soft: #c92a2a;
  --pdl-neutral: #868e96;
  --pdl-neutral-soft: #f1f3f5;
  --pdl-neutral-on-soft: #212529;

  --pdl-disabled-bg: #e9ecef;
  --pdl-disabled-text: #adb5bd;
  --pdl-disabled-border: #dee2e6;

  /* Accents */
  --pdl-accent-blue: #228be6;
  --pdl-accent-orange: #fd7e14;
  --pdl-accent-grape: #be4bdb;
  --pdl-accent-teal: #12b886;
  --pdl-accent-violet: #7950f2;
  --pdl-accent-cyan: #15aabf;
  --pdl-accent-pink: #e64980;
  --pdl-accent-lime: #82c91e;
  --pdl-accent-yellow: #fab005;
  --pdl-accent-red: #fa5252;
  --pdl-accent-indigo: #4c6ef5;
  --pdl-accent-dark: #2e2e2e;

  /* Sémantique métier */
  --pdl-type-ride: #228be6;
  --pdl-type-post: #be4bdb;
  --pdl-type-trip: #12b886;
  --pdl-type-team: #7950f2;
  --pdl-type-ad: #fd7e14;

  --pdl-status-draft: #868e96;
  --pdl-status-published: #40c057;
  --pdl-status-cancelled: #fa5252;

  --pdl-role-admin: #be4bdb;
  --pdl-role-organizer: #228be6;
  --pdl-role-member: #868e96;

  --pdl-ad-sale: #40c057;
  --pdl-ad-rental: #4c6ef5;
  --pdl-ad-wanted: #fd7e14;

  --pdl-surface-road: #868e96;
  --pdl-surface-gravel: #fd7e14;
  --pdl-surface-mtb: #40c057;
  --pdl-surface-mixed: #12b886;

  --pdl-visibility-public: #228be6;
  --pdl-visibility-unlisted: #fd7e14;
  --pdl-visibility-team: #868e96;

  --pdl-climb-hc: #be4bdb;
  --pdl-climb-cat1: #fa5252;
  --pdl-climb-cat2: #fd7e14;
  --pdl-climb-cat3: #fab005;
  --pdl-climb-cat4: #40c057;

  /* Carte */
  --pdl-map-route-line: #228be6;
  --pdl-map-marker-start: #40c057;
  --pdl-map-marker-end: #fa5252;
  --pdl-map-marker-hover: #228be6;
  --pdl-map-event-ride: #228be6;
  --pdl-map-event-stage: #40c057;
  --pdl-elevation-flat: hsl(85, 86%, 62%);
  --pdl-elevation-steep: hsl(255, 86%, 62%);
  --pdl-elevation-neutral: hsl(210, 86%, 62%);
}

/* ============ MODE SOMBRE ============ */

@media (prefers-color-scheme: dark) {
  :root:not([data-theme='light']) {
    --pdl-bg: #242424;
    --pdl-surface: #242424;
    --pdl-surface-alt: #2e2e2e;
    --pdl-surface-raised: #2e2e2e;
    --pdl-surface-hover: #3b3b3b;
    --pdl-overlay: rgba(36, 36, 36, 0.9);
    --pdl-overlay-solid: rgba(36, 36, 36, 0.95);

    --pdl-border: #424242;
    --pdl-border-subtle: #2e2e2e;

    --pdl-text: #c9c9c9;
    --pdl-text-bright: #ffffff;
    --pdl-text-dimmed: #9a9a9a;
    --pdl-text-placeholder: #696969;
    --pdl-link: #91a7ff;

    --pdl-primary: #3b5bdb;
    --pdl-primary-hover: #364fc7;
    --pdl-primary-soft: #1b2864;
    --pdl-primary-soft-hover: #26378b;
    --pdl-primary-on-soft: #edf2ff;
    --pdl-on-primary: #ffffff;

    --pdl-success: #2f9e44;
    --pdl-success-soft: #16451f;
    --pdl-success-on-soft: #ebfbee;
    --pdl-warning: #f08c00;
    --pdl-warning-soft: #733c00;
    --pdl-warning-on-soft: #fff9db;
    --pdl-danger: #e03131;
    --pdl-danger-soft: #651515;
    --pdl-danger-on-soft: #fff5f5;
    --pdl-neutral: #343a40;
    --pdl-neutral-soft: #111315;
    --pdl-neutral-on-soft: #f8f9fa;

    --pdl-disabled-bg: #2e2e2e;
    --pdl-disabled-text: #696969;
    --pdl-disabled-border: #424242;

    --pdl-accent-blue: #1971c2;
    --pdl-accent-orange: #e8590c;
    --pdl-accent-grape: #9c36b5;
    --pdl-accent-teal: #099268;
    --pdl-accent-violet: #6741d9;
    --pdl-accent-cyan: #0c8599;
    --pdl-accent-pink: #c2255c;
    --pdl-accent-lime: #66a80f;
    --pdl-accent-yellow: #f08c00;
    --pdl-accent-red: #e03131;
    --pdl-accent-indigo: #3b5bdb;
    --pdl-accent-dark: #828282;

    --pdl-type-ride: #1971c2;
    --pdl-type-post: #9c36b5;
    --pdl-type-trip: #099268;
    --pdl-type-team: #6741d9;
    --pdl-type-ad: #e8590c;

    --pdl-status-draft: #343a40;
    --pdl-status-published: #2f9e44;
    --pdl-status-cancelled: #e03131;

    --pdl-role-admin: #9c36b5;
    --pdl-role-organizer: #1971c2;
    --pdl-role-member: #343a40;

    --pdl-ad-sale: #2f9e44;
    --pdl-ad-rental: #3b5bdb;
    --pdl-ad-wanted: #e8590c;

    --pdl-surface-road: #343a40;
    --pdl-surface-gravel: #e8590c;
    --pdl-surface-mtb: #2f9e44;
    --pdl-surface-mixed: #099268;

    --pdl-visibility-public: #1971c2;
    --pdl-visibility-unlisted: #e8590c;
    --pdl-visibility-team: #343a40;

    --pdl-climb-hc: #9c36b5;
    --pdl-climb-cat1: #e03131;
    --pdl-climb-cat2: #e8590c;
    --pdl-climb-cat3: #f08c00;
    --pdl-climb-cat4: #2f9e44;

    --pdl-map-route-line: #4dabf7;
  }
}

/* Bascule explicite du thème (prioritaire sur la préférence système) */
:root[data-theme='dark'] {
  --pdl-bg: #242424;
  --pdl-surface: #242424;
  --pdl-surface-alt: #2e2e2e;
  --pdl-surface-raised: #2e2e2e;
  --pdl-surface-hover: #3b3b3b;
  --pdl-overlay: rgba(36, 36, 36, 0.9);
  --pdl-overlay-solid: rgba(36, 36, 36, 0.95);

  --pdl-border: #424242;
  --pdl-border-subtle: #2e2e2e;

  --pdl-text: #c9c9c9;
  --pdl-text-bright: #ffffff;
  --pdl-text-dimmed: #9a9a9a;
  --pdl-text-placeholder: #696969;
  --pdl-link: #91a7ff;

  --pdl-primary: #3b5bdb;
  --pdl-primary-hover: #364fc7;
  --pdl-primary-soft: #1b2864;
  --pdl-primary-soft-hover: #26378b;
  --pdl-primary-on-soft: #edf2ff;

  --pdl-success: #2f9e44;
  --pdl-success-soft: #16451f;
  --pdl-success-on-soft: #ebfbee;
  --pdl-warning: #f08c00;
  --pdl-warning-soft: #733c00;
  --pdl-warning-on-soft: #fff9db;
  --pdl-danger: #e03131;
  --pdl-danger-soft: #651515;
  --pdl-danger-on-soft: #fff5f5;
  --pdl-neutral: #343a40;
  --pdl-neutral-soft: #111315;
  --pdl-neutral-on-soft: #f8f9fa;

  --pdl-disabled-bg: #2e2e2e;
  --pdl-disabled-text: #696969;
  --pdl-disabled-border: #424242;

  --pdl-accent-blue: #1971c2;
  --pdl-accent-orange: #e8590c;
  --pdl-accent-grape: #9c36b5;
  --pdl-accent-teal: #099268;
  --pdl-accent-violet: #6741d9;
  --pdl-accent-cyan: #0c8599;
  --pdl-accent-pink: #c2255c;
  --pdl-accent-lime: #66a80f;
  --pdl-accent-yellow: #f08c00;
  --pdl-accent-red: #e03131;
  --pdl-accent-indigo: #3b5bdb;
  --pdl-accent-dark: #828282;

  --pdl-type-ride: #1971c2;
  --pdl-type-post: #9c36b5;
  --pdl-type-trip: #099268;
  --pdl-type-team: #6741d9;
  --pdl-type-ad: #e8590c;

  --pdl-status-draft: #343a40;
  --pdl-status-published: #2f9e44;
  --pdl-status-cancelled: #e03131;

  --pdl-role-admin: #9c36b5;
  --pdl-role-organizer: #1971c2;
  --pdl-role-member: #343a40;

  --pdl-ad-sale: #2f9e44;
  --pdl-ad-rental: #3b5bdb;
  --pdl-ad-wanted: #e8590c;

  --pdl-surface-road: #343a40;
  --pdl-surface-gravel: #e8590c;
  --pdl-surface-mtb: #2f9e44;
  --pdl-surface-mixed: #099268;

  --pdl-visibility-public: #1971c2;
  --pdl-visibility-unlisted: #e8590c;
  --pdl-visibility-team: #343a40;

  --pdl-climb-hc: #9c36b5;
  --pdl-climb-cat1: #e03131;
  --pdl-climb-cat2: #e8590c;
  --pdl-climb-cat3: #f08c00;
  --pdl-climb-cat4: #2f9e44;

  --pdl-map-route-line: #4dabf7;
}

/* Le mode clair reste disponible en bascule explicite : les valeurs
   de :root ci-dessus s'appliquent déjà, aucune surcharge nécessaire. */
```

### Recettes de composants (application des jetons)

```css
/* Carte (sortie, parcours, voyage, annonce, équipe) */
.pdl-card {
  background: var(--pdl-surface);
  border: 1px solid var(--pdl-border);
  border-radius: var(--pdl-radius-md);
  color: var(--pdl-text);
  text-decoration: none;
  display: block;
  overflow: hidden;
  transition: var(--pdl-transition-card);
}
.pdl-card:hover {
  box-shadow: var(--pdl-shadow-md);
}
.pdl-card__body { padding: var(--pdl-space-md); }
.pdl-card__media { height: var(--pdl-card-image-height); object-fit: cover; width: 100%; }
.pdl-card__media--ride-fallback {
  background: var(--pdl-gradient-ride);
  display: grid; place-items: center;
}

/* Badge de statut / type / rôle */
.pdl-badge {
  display: inline-flex;
  align-items: center;
  gap: var(--pdl-space-4);
  height: 18px;
  padding: 0 var(--pdl-space-8);
  border-radius: var(--pdl-radius-pill);
  font-size: var(--pdl-badge-font-size);
  font-weight: var(--pdl-badge-weight);
  letter-spacing: var(--pdl-badge-letter-spacing);
  text-transform: var(--pdl-badge-transform);
  background: var(--pdl-success-soft);
  color: var(--pdl-success-on-soft);
}

/* Chip de filtre (mobile) */
.pdl-chip {
  height: 32px;
  padding: 0 var(--pdl-space-sm);
  border-radius: var(--pdl-radius-pill);
  font-size: var(--pdl-font-size-sm);
  background: transparent;
  border: 1px solid var(--pdl-border);
  color: var(--pdl-text-dimmed);
}
.pdl-chip[aria-pressed='true'] {
  background: var(--pdl-primary-soft);
  color: var(--pdl-primary-on-soft);
  border-color: transparent;
}

/* Statistique de carte */
.pdl-stat {
  display: inline-flex;
  align-items: center;
  gap: var(--pdl-space-4);
  font-size: var(--pdl-font-size-sm);
  color: var(--pdl-text-dimmed);
}
.pdl-stat svg { width: 16px; height: 16px; }

/* Vignette de carte GPX */
.pdl-thumb {
  width: var(--pdl-thumbnail-lg);
  height: var(--pdl-thumbnail-lg);
  border-radius: var(--pdl-radius-md);
  border: 1px solid var(--pdl-border-subtle);
  overflow: hidden;
  flex-shrink: 0;
}

/* Avatar */
.pdl-avatar {
  border-radius: var(--pdl-radius-pill);
  width: 38px; height: 38px;
  display: grid; place-items: center;
  font-weight: var(--pdl-font-weight-bold);
  color: #fff;
  background: var(--pdl-primary);
}

/* Bouton primaire (Rejoindre) */
.pdl-button {
  min-height: var(--pdl-button-min-height);
  padding: 0 var(--pdl-space-md);
  border-radius: var(--pdl-radius-md);
  font-size: var(--pdl-font-size-sm);
  font-weight: var(--pdl-font-weight-medium);
  background: var(--pdl-primary);
  color: var(--pdl-on-primary);
  border: none;
}
.pdl-button:hover { background: var(--pdl-primary-hover); }
.pdl-button:disabled {
  background: var(--pdl-disabled-bg);
  color: var(--pdl-disabled-text);
}
@media (min-width: 48em) {
  .pdl-button { min-height: var(--pdl-button-min-height-desktop); }
}
```
