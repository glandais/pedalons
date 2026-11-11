# Rendre l'audit des cartes exploitable — méthode (2026-11-11)

Comment passer de l'[audit](README.md) (environ 300 écarts entre les cartes de l'app et du site) à des corrections
vérifiables. Proposition, rien n'est commencé.

## Principe

L'audit n'est pas une liste de 300 corrections. On le réduit à une dizaine de **règles**, on valide chaque règle sur
une **maquette avant / cible**, puis on corrige règle par règle en vérifiant le code contre la cible.

Trois choix structurent la méthode :

- **Décider par règle, pas par carte.** « Quels badges d'état porte une carte, dans quel ordre » règle d'un coup
  toutes les cartes des deux supports.
- **Valider sur maquette ce qui se voit**, et seulement cela. Une liste suffit pour un défaut ou un mot.
- **Corriger à la source** quand l'écart vient de ce que chaque support recalcule de son côté.

## Étape 1 — Trier en trois tas

Chaque ligne des quatre fichiers d'audit reçoit une étiquette.

| Tas | Définition | Exemples | Ce qu'il devient |
|---|---|---|---|
| **Défaut** | Un seul côté a raison, sans débat | « 92.4 km » sur le site ; « 1 membres » ; voyage annulé sans badge dans l'app ; « Quitter » sur une sortie annulée du site ; phrases non épicènes | Corrigé sans maquette (étape 5, premier lot) |
| **Décision** | Les deux côtés se défendent | Pluie toujours affichée ou seulement en alerte ; compteurs d'une carte de voyage ; quelle distance pour une sortie ; confirmer une désinscription | Regroupé en règles, validé sur maquette (étapes 3 et 4) |
| **Écart voulu** | La différence tient au support | Menu ⋯ d'édition sur le site ; jauge de places absente du fil de l'app | Écrit dans « Délibérément dehors » du ledger, avec sa raison |

Les écarts de gravité **faible** ne sont pas triés un par un : ils se corrigent au passage quand un lot touche la
carte.

**Livrable** : `tri.md` dans ce dossier — la liste des défauts, la liste des règles à décider (une dizaine attendue),
la liste des écarts voulus. Le tri est proposé, puis relu.

## Étape 2 — Une référence vérifiable : les galeries de cartes

Aujourd'hui, les planches de la page « Cartes » ont été dessinées d'après le code et **jamais comparées à l'app ni au
site en fonctionnement**. Avant de s'en servir comme « avant », il faut une vue réelle des cartes, reproductible.

- **App** : une page de galerie des cartes, à côté de la galerie des composants (`mobile/lib/dev/pdl_gallery_page.dart`),
  qui rend chaque carte dans chaque état avec des données fixes. Capture sur le simulateur.
- **Site** : une page de démonstration équivalente, réservée au développement, capturée par Playwright. Le site n'a
  aujourd'hui ni catalogue de composants ni test par capture : c'est à créer.
- **Mêmes données des deux côtés**, celles des maquettes (`KIT.md` §6), complétées des cas manquants (voyage, annonce,
  équipe, notification). C'est ce qui rend la comparaison lisible.

Une fois les galeries en place, les planches « avant » sont confrontées aux captures et corrigées.

**Livrable** : les deux galeries, leurs captures versionnées, la page « Cartes » de l'artifact fidèle à l'existant.

## Étape 3 — Maquettes avant / cible

Pour chaque règle à décider, une planche courte dans l'artifact, sur une page « Cartes — cibles » :

| Colonne | Contenu |
|---|---|
| Avant, app | La carte actuelle de l'app |
| Avant, site | La carte actuelle du site |
| Cible, app | La proposition |
| Cible, site | La proposition |

- Une planche par règle, avec seulement les cartes et les états que la règle change : une quinzaine de cartes cibles
  en tout, pas les seize planches entières.
- Une légende dit ce qui change et pourquoi, et renvoie aux lignes de l'audit.
- Pas de maquette pour les défauts ni pour le vocabulaire.

## Étape 4 — Décisions

- Une question à la fois, la recommandation en premier, en regardant la planche.
- Chaque réponse est écrite dans `KIT.md` (nouvelle section « Règles des cartes »), sous une forme vérifiable :
  « une carte de sortie porte, dans cet ordre : … ».
- Le vocabulaire tranché va dans le lexique de `docs/BRANDING.md` §8.4.
- Un écart qu'on choisit de garder passe dans « Délibérément dehors ».
- La cible validée remplace l'« avant » dans l'artifact ; l'« avant » reste dans l'historique git.

## Étape 5 — Corriger par lots

| Lot | Contenu | Maquette |
|---|---|---|
| 0 | Les défauts, app et site | Non |
| 1 à n | Une règle par lot, sur les deux supports | Oui |

- Une entrée de ledger par lot : `MOB-…` pour l'app, `WEB-…` pour le site, rattachée à `WEB-165`. Une règle qui
  change l'API prend une entrée `API-…`.
- Trois corrections se font à la source plutôt que carte par carte :
  - **Formats** : un jeu de cas partagé dans `contracts/` (valeur, langue, unités → texte attendu), lu par les tests
    de l'app et par ceux du site. C'est ce qui empêche l'écart de revenir.
  - **Vocabulaire** : le lexique commun, puis les clés des deux fichiers de traduction.
  - **Distance d'une sortie** : choisie par l'API plutôt que par chaque carte, comme pour les permissions
    (ledger `API-176`).

## Étape 6 — Vérifier contre la cible

Pour chaque lot :

1. Tests unitaires de la règle (formats, ordre des badges, conditions d'affichage).
2. Capture de la galerie de l'app et de celle du site.
3. Comparaison à la planche cible, carte par carte, par une liste de contrôle : contenu, ordre, libellés, états,
   actions.
4. Les écarts restants sont soit corrigés, soit reportés sur la planche si c'est la maquette qui avait tort.

Un lot n'est terminé que si les captures ont été regardées. Ce qui n'a pas été vu à l'écran est dit tel quel.

## Limites

- **La comparaison se fait à l'œil**, pas au pixel. Les maquettes sont du HTML qui imite l'app et le site : fidèles
  sur le contenu, l'ordre et les libellés, moins sur les espacements.
- **L'audit est une lecture du code.** Ce qu'il a seulement déduit (« 1 membres », la jauge du site réduite à zéro
  pixel) se vérifie à l'étape 2, avant toute correction.
- **Les galeries ont un coût d'entrée**, surtout côté site où rien n'existe. Elles servent ensuite à chaque lot, et
  aux captures des stores.
- **Clair seulement** dans les maquettes ; le mode sombre de l'app se vérifie sur la galerie.

## Ordre

1. Tri (`tri.md`).
2. Galeries et planches « avant » corrigées.
3. Lot 0, les défauts — peut avancer en parallèle de l'étape 2.
4. Planches cibles et décisions, règle par règle.
5. Lots par règle, chacun vérifié contre sa cible.
6. À la fin : ce dossier est archivé avec le plan, les règles restent dans `KIT.md` et `BRANDING.md`.
