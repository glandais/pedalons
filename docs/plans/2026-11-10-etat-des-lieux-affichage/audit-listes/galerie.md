# Galeries de listes — cahier commun à l'app et au site (2026-11-12)

Étape 2 de la [méthode](../audit-cartes/METHODE.md), appliquée aux listes. Une galerie rend **les vraies pages de
liste** de chaque support, avec des données fixes et sans réseau, dans chacun de leurs états, pour les capturer, les
comparer entre elles et servir d'« avant » aux planches. Ce fichier fixe ce que les deux galeries ont en commun.

## Règles

Celles de la [galerie des cartes](../audit-cartes/galerie.md), avec ces différences :

- **Un cas = une page entière** (barre d'outils, compteur, éléments, pied), pas une carte. La légende porte
  l'identifiant du cas (`parcours-vide-filtre`).
- **Les vraies pages**, pas des copies : la galerie monte la page de production et remplace seulement sa source de
  données (fournisseurs Riverpod dans l'app, cache et requêtes React Query sur le site) par des réponses fixes : une
  page de résultats, une page vide, une erreur, une attente sans fin. Elle ne modifie pas la page.
- **Outil de développement** : jamais atteignable dans une version livrée. App : `/dev/listes/<section>/<cas>`, mode
  debug seulement, à côté de `/dev/cartes`. Site : `frontend/dev/lists.html`, serveur de développement seulement.
- **Mêmes sections, mêmes cas, même ordre** des deux côtés. Un cas sans objet sur un support est omis, avec sa raison.
- Horloge figée à J 12:00, lectrice **Camille Durand**, français, unités métriques, mode clair.

## Données

Celles de la galerie des cartes (équipe **Vélo Club des Monts**, 24 membres ; **Gravel Bretagne** ; sortie **Boucle
des Monts d'Arrée** ; voyage **Traversée du Morvan** ; etc.). Chaque liste au repos montre **trois éléments** et
annonce un total plus grand que la page (par exemple 3 affichés, 47 au total), pour que compteur, pied et pagination
soient visibles. Un total supérieur à 1 000 sur les annonces (2 585) vérifie le format des nombres.

Camille est **organisatrice** du Vélo Club des Monts (elle voit les actions de création) et membre de Gravel Bretagne.

## Cas, par liste

Chaque section décline les mêmes états, quand la liste les a :

| Suffixe | Ce qu'il montre |
|---|---|
| `-repos` | La liste à l'ouverture : barre d'outils, compteur, trois éléments, pied ou pagination |
| `-filtre` | Un filtre actif (et une recherche « monts » quand la liste cherche) : signal de filtre, compteur filtré |
| `-criteres` | La feuille (app) ou le panneau (site) de filtres ouvert, valeurs par défaut |
| `-tri` | Le contrôle de tri ouvert, quand la liste trie |
| `-vide` | Aucun élément, aucun filtre |
| `-vide-filtre` | Aucun élément à cause d'un filtre ou d'une recherche |
| `-erreur` | Le chargement a échoué (erreur serveur) |
| `-chargement` | Chargement initial |
| `-lecture` | La même liste vue par une personne simplement membre (pas d'action de création), quand cela change la page |
| `-sections` | Une liste d'événements datés en deux sections (RL15) : une page où la frontière entre « À venir » et « Plus tôt » est visible |

| Section | Liste | Cas |
|---|---|---|
| **accueil** | Fil d'accueil | `-repos` · `-sections` (« À venir » puis « Plus tôt » sur une même page, RL15) · `-plus-tot` (période « Plus tôt » : une liste simple, sans section, RL15) · `-filtre` (portée « Toutes les équipes », type « Sorties ») · `-criteres` (contrôle de portée ouvert) · `-vide` · `-vide-filtre` · `-erreur` · `-chargement` |
| **publications** | Publications d'une équipe | `-repos` · `-filtre` (recherche et un tag) · `-vide` · `-vide-filtre` · `-erreur` · `-lecture` |
| **agenda** | Agenda d'une équipe | `-repos` · `-sections` (« À venir » puis « Plus tôt » sur une même page, RL15) · `-plus-tot` (période « Plus tôt » : une liste simple, sans section, RL15) · `-filtre` (« Sorties », « Je participe ») · `-criteres` · `-vide` · `-vide-filtre` · `-erreur` · `-lecture` |
| **calendrier** | Calendrier global, calendrier d'une équipe | `-repos` (mois avec cinq événements) · `-filtre` (type « Sorties ») · `-equipe` (calendrier d'une équipe) · `-vide` (mois sans rien) · `-vide-filtre` · `-erreur` · `-chargement` |
| **parcours** | Parcours d'une équipe | `-repos` (vignettes) · `-lignes` (vue compacte) · `-carte` (vue carte : la barre seule compte) · `-filtre` (distance 50–100 km, tag « vallonné ») · `-criteres` · `-tri` · `-vide` · `-vide-filtre` · `-erreur` · `-lecture` |
| **explorer** | Tous les parcours | `-repos` · `-filtre` (portée, pratique « Route ») · `-criteres` · `-vide-filtre` · `-erreur` |
| **annonces** | Annonces d'une équipe | `-repos` (total 2 585) · `-filtre` (type « Vente ») · `-criteres` · `-tri` · `-vide` · `-vide-filtre` · `-erreur` |
| **equipes** | Mes équipes, découvrir | `-repos` (mes équipes) · `-decouvrir` (toutes les équipes) · `-filtre` (recherche « bretagne ») · `-vide` (aucune équipe) · `-vide-filtre` · `-erreur` |
| **membres** | Membres d'une équipe | `-repos` · `-filtre` (rôle « Organisateur ») · `-vide-filtre` · `-erreur` |
| **inscrits** | Personnes inscrites | `-repos` (8 personnes, groupe B) · `-filtre` (recherche) · `-vide` · `-vide-filtre` · `-erreur` |
| **notifications** | Notifications | `-repos` · `-filtre` (« Non lues ») · `-vide` · `-vide-filtre` · `-erreur` |
| **modeles** | Modèles de sortie | `-repos` · `-filtre` (recherche) · `-vide` · `-vide-filtre` · `-erreur` |

Les deux tests de galerie recopient ce tableau et échouent si un cas disparaît.

## Capture

- **App** : sans simulateur, par test (`CARD_GALLERY_CAPTURE_DIR`-like : `LIST_GALLERY_CAPTURE_DIR=<dossier> flutter test
  test/dev/list_gallery_capture_test.dart`), vraies polices, 390 × 844 pt, ratio 2, une image par cas. La carte native
  n'existe pas en test : le cas `parcours-carte` montre la barre au-dessus d'un fond neutre.
- **Site** : `pnpm dev --port 5183 --strictPort`, puis `node scripts/capture-list-gallery.mjs <dossier> --base
  http://localhost:5183`, largeurs 1280 px et 390 px, une image par cas (hauteur de la fenêtre : 900 px, pas la page
  entière).
- Les captures vont dans `captures/app/<section>/<cas>.png` et `captures/site/<section>/<cas>-1280.png` / `-390.png`.
