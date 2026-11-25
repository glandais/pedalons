# Pédalons — exploration du site web (parcours membre)

Captures prises en conditions réelles dans Chrome sur **https://www.pedalons.fr**, session
authentifiée « Gaby Landais », locale **français**, thème **sombre** (thème par défaut du compte).
Périmètre : consultation / participation uniquement (pas d'admin, pas de création/édition).

- Viewport large : ~1365 × 900 px (fenêtre 1440), quelques captures à 1316 px de large en début de session.
- Viewport étroit : 420 px (captures 25 → 27).
- Date de navigation : 25 juillet 2026. Version applicative affichée en pied de page : **v1.2.0 (afbf613)**.

> **Images retirées le 29 septembre 2026** : prises sur les données de production, elles montraient
> des contenus de membres dans un dépôt public. Seul ce descriptif reste ; les fichiers cités
> ci-dessous existent encore dans l'historique git d'avant cette date.

## Index des captures

| # | Fichier | Route | Titre de page |
|---|---------|-------|---------------|
| 01 | `01-accueil-feed.png` | `/` | Accueil — fil global « Dernières publications » |
| 02 | `02-equipes-liste.png` | `/equipes` | Équipes — liste |
| 03 | `03-equipe-n-peloton-feed.png` | `/equipes/n-peloton` | N-Peloton — fil d'actualités |
| 04 | `04-equipe-a-propos.png` | `/equipes/n-peloton/a-propos` | N-Peloton — À propos |
| 05 | `05-equipe-calendrier.png` | `/equipes/n-peloton/calendrier` | N-Peloton — Calendrier |
| 06 | `06-calendrier-global.png` | `/calendrier` | Calendrier global (capture recadrée : le lien ICS contient un token personnel) |
| 07 | `07-parcours-liste-globale.png` | `/parcours` | Tous les parcours — vue liste |
| 08 | `08-parcours-filtres.png` | `/parcours` | Tous les parcours — panneau de filtres déplié |
| 09 | `09-parcours-carte-globale.png` | `/parcours/carte` | Tous les parcours — vue carte |
| 10 | `10-equipe-parcours-liste.png` | `/equipes/n-peloton/parcours` | Parcours de l'équipe — liste |
| 11 | `11-equipe-parcours-carte.png` | `/equipes/n-peloton/parcours/carte` | Parcours de l'équipe — carte |
| 12 | `12-parcours-detail.png` | `/equipes/n-peloton/parcours/np-664-long` | Détail parcours — haut de page |
| 13 | `13-parcours-detail-bas.png` | idem | Détail parcours — cols & « Utilisée dans » |
| 14 | `14-parcours-carte-plein-ecran.png` | `…/np-664-long/carte` | Parcours — carte plein écran + profil |
| 15 | `15-sortie-detail-haut.png` | `/equipes/n-peloton/sorties/n-peloton-664` | Détail sortie — en-tête, description, lieux |
| 16 | `16-sortie-groupes-carte.png` | idem | Détail sortie — carte multi-tracés + colonne Groupes |
| 17 | `17-sortie-non-membre.png` | `/equipes/n-peloton/sorties/n-peloton-665` | Sortie à venir — bandeau « Rejoignez cette équipe » |
| 18 | `18-equipe-gaby-feed-voyages.png` | `/equipes/gaby` | Équipe Gaby — fil mixant voyages et sorties |
| 19 | `19-voyage-detail.png` | `/equipes/gaby/voyages/gtmc-bromance` | Détail voyage — carte + liste d'étapes |
| 20 | `20-voyage-etape-detail.png` | `/equipes/gaby/voyages/gtmc-bromance/etapes/j1-3` | Détail étape — rail d'étapes + parcours |
| 21 | `21-publication-detail.png` | `/equipes/n-peloton/articles/annulation-du-ride-1` | Détail publication |
| 22 | `22-annonces-vide.png` | `/equipes/n-peloton/annonces` | Petites annonces — état vide |
| 23 | `23-profil-haut.png` | `/profil` | Profil — identité, préférences, passkeys |
| 24 | `24-profil-bas.png` | `/profil` | Profil — appareils GPS, comptes liés, RGPD, zone de danger |
| 25 | `25-responsive-accueil-etroit.png` | `/` @420px | Accueil en viewport étroit |
| 26 | `26-responsive-sortie-etroit.png` | `…/sorties/n-peloton-664` @420px | Sortie en viewport étroit |
| 27 | `27-responsive-menu-burger.png` | @420px | Menu burger ouvert |

Correction de libellés par rapport à la demande initiale : les petites annonces sont sur
`/equipes/{slug}/annonces` (et non `/petites-annonces`), les publications sur `…/articles/{slug}`,
les sorties sur `…/sorties/{slug}`, les voyages sur `…/voyages/{slug}` et les étapes sur
`…/voyages/{slug}/etapes/{slug}` (source : `contracts/routes.yaml`).

---

## 01 — Accueil `/`

Chrome applicatif minimal : barre supérieure fine, wordmark « Pédalons » en dégradé violet→bleu à
gauche, et à droite un trio compact (bouton thème soleil, select « Français », pastille avatar +
« Gaby Landais »). Pas de barre latérale : la navigation principale est une **rangée de 4 tuiles
carrées icône-au-dessus-du-label** (Accueil / Équipes / Calendrier / Parcours), la tuile active en
violet plein, les autres en gris ardoise. Au-dessus, un fil d'Ariane discret (« Accueil ··· »).

Contenu : titre H1 « Bienvenue sur Pédalons » + sous-titre, puis section « Dernières publications »
avec une ligne d'outils (champ de recherche large « Rechercher par titre ou description… », select
« Tous » = type, select « Membre » = portée) et une **grille de cartes en 3 colonnes**.

Chaque carte agrège beaucoup d'information dans peu de place : bandeau image 16:9 en haut (photo/meme
réel, ou dégradé de marque avec pictogramme vélo quand il n'y a pas de visuel), ligne équipe cliquable
(« N-Peloton › »), titre gras, extrait de description tronqué à ~3 lignes, pile de badges alignée à
droite (`SORTIE` / `PUBLICATION` violet, `PUBLIÉ` vert ou `BROUILLON` orange, `PUBLIC` avec icône
œil), une vignette carte carrée du parcours quand il y en a un, une rangée d'avatars-initiales des
inscrits, puis un pied de carte : date longue en français (« mercredi 22 juillet 2026 à 19:30 »),
nombre de participants, nombre de groupes. Densité : ~12 cartes par page, **pagination numérotée
1 2 3 4 5 … 47** en bas.

## 02 — Équipes `/equipes`

Même chrome. H1 « Équipes » + sous-titre, bouton primaire « + Créer une équipe » aligné à droite,
recherche + select de portée. Grille de cartes équipe : large bandeau en dégradé violet avec
pictogramme « groupe », puis logo rond de l'équipe, nom, description tronquée, nombre de membres
(7 pour Gaby, 1999 pour N-Peloton) et un badge de rôle `ADMINISTRATEUR` en bas à droite. Deux
équipes seulement ici, donc beaucoup de blanc — la grille ne se recentre pas, les cartes restent
calées à gauche.

## 03 — Équipe : fil `/equipes/n-peloton`

En-tête d'équipe : avatar rond ~70 px (logo N-Peloton), nom en très gros (H1), badge `PUBLIC` avec
icône œil, et à droite un bouton d'action contextuel. Sous l'en-tête, la **même mécanique de tuiles**
que la nav globale, mais pour l'équipe : Fil d'actualités / Calendrier / Parcours / À propos. Le fil
réutilise exactement les cartes de l'accueil (moins la ligne « équipe », redondante ici), recherche +
filtre de type, pagination 1…45.

Observation : selon l'ordre de chargement, le bouton d'en-tête affiche parfois « Rejoindre l'équipe »
(capture 03/04) et parfois « Gérer » (capture 05, 10), et l'onglet Calendrier n'apparaît qu'au second
rendu. L'état de membership arrive donc après le premier paint, ce qui se voit à l'œil nu.

## 04 — Équipe : à propos `/equipes/n-peloton/a-propos`

Page très aérée, une seule carte centrée (max ~865 px) : H2 « À propos de l'équipe », texte libre,
sous-titre « Contact » avec adresse postale, liste à puces des réseaux (Facebook / Instagram /
Twitter) en liens violets, puis un séparateur et deux statistiques en pied avec icône :
« Membres — 1999 membres » et « Création — 16 septembre 2021 ». Beaucoup d'espace vide sous la carte.

## 05 — Équipe : calendrier `/equipes/n-peloton/calendrier`

Barre de contrôle : chevrons ‹ ›, libellé « Juillet 2026 », bouton « Aujourd'hui » à gauche ;
segmenté Jour / Semaine / Mois / Année à droite (Mois actif en violet). Grille mensuelle classique
lun→dim, week-ends en rouge, jour courant (25) dans une pastille violette. Les événements sont des
pastilles fines bleu-violet avec le titre (« N-Peloton #663 », « Raymond Ride #286 ») — lisibles,
mais sans heure ni distance. Sous le calendrier, un bandeau d'information bleu « Abonnez-vous au
calendrier de cette équipe… » avec URL de flux ICS, bouton « S'abonner » et « Régénérer le lien ».

## 06 — Calendrier global `/calendrier`

Identique au calendrier d'équipe mais sans en-tête d'équipe et avec le flux ICS **global** de
l'utilisateur. Ici les sorties des deux équipes se mélangent sans distinction visuelle d'origine
(même couleur de pastille) — impossible de dire d'un coup d'œil de quelle équipe vient un événement.
La capture a été recadrée : le champ « URL du flux global » affiche en clair un token personnel.

## 07 / 08 — Tous les parcours `/parcours`

Barre d'outils : select de portée « Membre » à gauche, segmenté **Liste | Carte** à droite, puis un
bouton « Filtres » repliable. Grille 3 colonnes de cartes parcours dominées par une **grande vignette
carte statique** (fond sombre, tracé rouge vif, labels de communes) — c'est le seul écran où l'image
est réellement porteuse d'information. Sous la vignette : équipe, titre, deux métriques compactes
(distance avec icône carte, D+ avec flèche haut), badges de surface (`ROUTE` gris / `GRAVEL` ocre) et
visibilité. Pagination 1…**225** pages : le volume est énorme et la liste seule ne le laisse pas
deviner (pas de compteur de résultats).

Panneau de filtres déplié (08) : une carte pleine largeur avec recherche texte, puis 4 colonnes —
Distance (min/max), Dénivelé positif (min/max), Relief (« Tous les niveaux »), Type de revêtement
(« Tous les types ») — et une seconde ligne Direction du vent (« Toutes directions ») + Trier par
(« Date ») avec un bouton de sens de tri. Le filtre « direction du vent » est une vraie signature
produit. Le panneau met ~2–3 s à se peupler après le clic (strip gris vide entre-temps).

## 09 — Carte de tous les parcours `/parcours/carte`

Le contenu bascule dans un grand canevas MapLibre (~865 × 620) qui garde les tuiles/contrôles au
chaud sous la barre d'outils inchangée. Tous les tracés sont dessinés en bleu marine translucide sur
un fond **clair** (Mapterhorn/OSM) — contraste fort et un peu brutal avec l'UI sombre. À l'échelle
Europe, on lit immédiatement le « nuage » nantais et quelques excursions (Alpes, Pyrénées, Massif
central). Contrôles zoom +/−/boussole en haut-gauche, bouton de style de fond en bas-gauche,
attribution en bas-droite. Le rendu prend 10–20 s (fond crème vide en attendant) : c'est l'écran le
plus lent du site.

## 10 / 11 — Parcours de l'équipe

Même composant, encapsulé dans l'en-tête d'équipe. En vue liste (10) s'ajoutent deux actions d'auteur
(« Importer GPX », « + Créer un nouveau parcours ») — hors périmètre de ce document mais visibles.
En vue carte (11) l'emprise est recentrée sur les tracés de l'équipe (Bretagne → Île-de-France) et
la densité de traces autour de Nantes est spectaculaire.

## 12 / 13 / 14 — Détail d'un parcours

**Haut (12)** : fil d'Ariane complet Équipes / N-Peloton / Parcours / titre, H1, puis un bloc
carte + profil altimétrique **collés verticalement** (la carte porte les repères de kilométrage 10,
20, 30… dans des pastilles blanches, un point vert = départ, rouge = arrivée ; le profil est un
aplat bleu avec les segments de montée colorés en jaune/orange). Deux boutons d'action en haut à
droite de la carte : plein écran et changement de fond.

Sous la carte, une rangée de 3 actions secondaires : « Télécharger GPX », « Télécharger FIT »,
« Envoyer vers l'appareil ». Puis une ligne de statistiques à icônes colorées : Distance 66.5 km /
Dénivelé positif +413 m (flèche verte) / Dénivelé négatif −413 m (flèche rouge), badges
`ROUTE` (vert) `PUBLIC` (noir) et date de création.

**Bas (13)** : section « Cols et montées (5) » — un tableau léger, une ligne par montée avec badge de
catégorie vert, numéro, plage kilométrique, dénivelé, pente moyenne et pente maximale (valeurs en
gras). Puis « Utilisée dans » : carte de la sortie qui consomme ce parcours, avec badge `SORTIE`,
date, et la liste des groupes concernés (« via les groupes : Chill Route Long 🍓, G1🌶️, G2 🍑,
G3 🥕 »). C'est le lien de traçabilité le plus utile de tout le site.

**Carte plein écran (14)** : bascule en mode immersif — barre noire fine en haut avec flèche retour,
nom du parcours à gauche et les 3 métriques (66.5 km, ↑413 m, ↓−413 m) à droite ; carte occupant
toute la largeur ; profil altimétrique en bandeau fixe en bas, avec les segments de montée coloriés
par intensité. Excellent rapport signal/bruit.

## 15 / 16 / 17 — Détail d'une sortie

**15** : carte de contenu centrée avec H1 « N-Peloton #664 » + badge `PUBLIÉ`, description longue
rendue en texte riche (liens cliquables violets, retours à la ligne respectés, image/meme inline en
taille contenue). En pied de carte : date longue, nombre de participants, puis **Départ** et
**Arrivée** avec pastilles de couleur (vert / rouge), nom du lieu en gras et adresse complète entre
parenthèses.

**16** : c'est le cœur de la page. À gauche (2/3), une carte MapLibre où **tous les parcours de tous
les groupes sont superposés en couleurs différentes** (olive, violet, rose, brun…) avec les marqueurs
départ/arrivée, et un profil altimétrique en médaillon flottant en haut à droite de la carte. À
droite (1/3), une colonne « Groupes » scrollable : une carte par groupe, titre avec emoji
(« Chill Route Court🍄 », « G1🌶️ », « Gravel Superchill 🫐 »), 4 métriques sur deux lignes (heure de
départ, vitesse moyenne, distance, D+), une rangée d'avatars-initiales + « n participants » (avec
« Voir tout » au-delà de 5), puis 4 actions texte à icône : « Voir le parcours », « GPX », « FIT »,
« Envoyer vers l'appareil ». Dix groupes ici : la hiérarchie horaire (19:30 chill / 20:30 G1-G2-G3)
et l'échelle de vitesse (16 → 37 km/h) se lisent en balayant la colonne.

**17** : sortie à venir (#665, brouillon). Les groupes existent déjà mais à 0 participant et sans
parcours (« Aucun parcours disponible » dans le cadre carte). Un **bandeau orange pleine largeur** en
bas de page : « Rejoignez cette équipe pour participer aux sorties. Voir l'équipe ». Le compte utilisé
n'étant membre d'aucune des deux équipes de test, **aucun bouton d'inscription à un groupe n'a pu
être observé** — les cartes de groupe restent purement informatives. (À noter : l'écran `/equipes`
affiche pourtant un badge `ADMINISTRATEUR` sur les deux équipes ; les deux écrans se contredisent.)

## 18 — Équipe Gaby : fil mixte

Montre le fil quand il contient plusieurs types d'objets : badges `VOYAGE` (vert) à côté de `SORTIE`
(violet), et un pied de carte adapté (« 7 étapes », « 11 étapes » au lieu de « n groupes »).
L'en-tête d'équipe porte ici un badge rouge/orange `NON RÉPERTORIÉ`. Les vignettes de couverture
absentes sont remplacées par des dégradés de marque (vert pour les voyages, bleu pour les sorties)
avec le pictogramme correspondant — cohérent et agréable.

## 19 — Détail d'un voyage

Même gabarit que la sortie : carte d'en-tête (titre, badge `PUBLIÉ`, description, date, participants,
« 7 étapes »), puis carte MapLibre 2/3 où **chaque étape a sa propre couleur** (dégradé bleu → rose du
nord au sud de la GTMC) + profil altimétrique en médaillon. À droite, colonne « Étapes » : une carte
par étape avec pastille numérotée violette, titre (J1…J7), date, lien « Voir le parcours » et les deux
métriques distance / D+. Bandeau orange de non-membre en bas.

## 20 — Détail d'une étape

Layout différent et plus riche : bandeau de contexte en haut (« GTMC Bromance » en petit, « J1 » en
gros, badge `PUBLIÉ`), puis **rail vertical de navigation entre étapes** à gauche (« Aperçu » +
7 entrées numérotées avec date, l'étape courante en violet plein) et le contenu à droite. Le contenu
reprend l'anatomie d'un parcours : en-tête d'étape avec pastille numérotée et date, titre du parcours
+ lien « Voir les détails du parcours », carte, profil altimétrique (ici très expressif, montées en
orange/rouge), les 3 boutons GPX/FIT/appareil, les statistiques, puis « Cols et montées (7) ».

## 21 — Détail d'une publication

La page la plus sobre : une seule carte centrée (~730 px), H1 + badge `PUBLIÉ`, corps de texte en
paragraphes bien espacés, image inline encadrée d'un liseré clair, et date en pied avec icône
calendrier. Pas de commentaires, pas de réactions, pas d'auteur affiché.

## 22 — Petites annonces

`/equipes/{slug}/annonces` n'est **pas** exposée dans les tuiles de navigation de l'équipe : la page
n'est atteignable que par URL directe ou deeplink. Au chargement, six squelettes de cartes
apparaissent pendant plusieurs secondes **et un toast d'erreur rouge « Vous n'avez pas les droits
pour effectuer cette action »** s'affiche en haut à droite, avant que la page ne se stabilise sur
l'état vide « Aucune annonce / Aucune annonce n'est disponible pour le moment ». Comportement
identique sur les deux équipes de test. Aucune annonce en production, donc **le détail d'une annonce
n'a pas pu être capturé**.

## 23 / 24 — Profil `/profil`

Page mono-colonne centrée, découpée en sections séparées par des filets : identité (avatar initiales
« GL » avec bouton appareil-photo en overlay, nom, email, champs en lecture seule, bouton primaire
« Modifier le profil ») ; **Préférences** avec un segmenté Métrique / Impérial ; **Passkeys** (liste
d'appareils avec date de dernière utilisation, bouton « + Ajouter », icône corbeille) ; **Appareils
GPS** (Hammerhead, badge vert `CONNECTÉ`, date de connexion) ; **Comptes liés** (Strava avec son logo
et badge `LIÉ`) ; **Vos données** (export RGPD, message d'état « Votre export est prêt… valable
jusqu'au samedi 1 août 2026 ») ; **Actions du compte** (Se déconnecter, bouton pleine largeur) ; et
une **Zone de danger** titrée en rouge avec « Supprimer le compte » en bouton contour rouge. La
gradation visuelle neutre → rouge est nette et bien dosée.

## 25 / 26 / 27 — Comportement responsive (420 px)

À 420 px la mise en page bascule proprement : le trio thème/langue/compte de la barre supérieure est
remplacé par un **menu burger** (27 : panneau plein écran avec bouton thème, select de langue,
utilisateur, « Outils GPX », « Se déconnecter »). Les tuiles de navigation restent sur une seule
ligne, réduites. Les filtres qui étaient côte à côte (recherche / type / portée) s'empilent
verticalement, les cartes passent en une colonne pleine largeur, les images gardent leur ratio.

Sur le détail de sortie (26), la carte et la colonne Groupes s'empilent : carte d'abord, profil
altimétrique au-dessus d'elle, puis les cartes de groupe en pleine largeur avec leurs 4 actions sur
une seule ligne. **Aucun débordement horizontal constaté** sur les pages testées.

---

## Notes transverses

- **Cohérence du système visuel** : un seul vocabulaire de composants (tuile de navigation, carte à
  bandeau, badge pilule, segmenté, ligne de métriques à icône) réutilisé de l'accueil au profil.
- **Format des données** : dates longues en français partout (« mercredi 22 juillet 2026 à 19:30 »),
  unités systématiquement suffixées (km, m, km/h), pentes en %, altitudes en m.
- **Cartes** : toujours en tuiles claires, y compris en thème sombre — hors vignettes de liste de
  parcours qui, elles, utilisent un fond sombre. Deux traitements cartographiques coexistent donc.
- **Chargement** : les cartes MapLibre (10–20 s sur `/parcours/carte`) et les images de couverture du
  fil sont les points lents ; les squelettes existent pour les annonces mais pas pour les cartes.
- **Le compte ne rend jamais visible d'action de participation** dans l'état actuel des données de
  production (aucune sortie future dans une équipe dont l'utilisateur est membre effectif).
