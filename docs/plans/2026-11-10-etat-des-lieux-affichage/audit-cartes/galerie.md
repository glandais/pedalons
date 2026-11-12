# Galeries de cartes — cahier commun à l'app et au site (2026-11-12)

Étape 2 de la [méthode](METHODE.md). Une galerie rend **les vraies cartes** de chaque support, avec des données fixes,
pour les capturer et les comparer entre elles et aux maquettes. Ce fichier fixe ce que les deux galeries ont en commun :
les sections, les cas et les données. Chaque galerie construit ses objets dans son code (pas d'appel réseau) à partir de
ce cahier.

## Règles

- **Outil de développement** : jamais atteignable dans une version livrée (app : seulement en mode debug, à côté de
  `mobile/lib/dev/pdl_gallery_page.dart` ; site : seulement en développement, exclu du build de production).
- **Les vraies cartes**, pas des copies : la galerie instancie les widgets et composants de production avec des objets
  du client d'API généré. Si une carte ne peut pas être montée sans réseau, la galerie remplace ses fournisseurs de
  données par des valeurs fixes ; elle ne modifie pas la carte.
- **Un cas = une légende + une carte.** La légende porte l'identifiant du cas (`fil-sortie-inscrite`), en petit, au-dessus.
- **Même ordre** de sections et de cas des deux côtés. Un cas sans objet sur un support est omis, pas remplacé.
- **Horloge figée à J 12:00 pendant la capture**, pour que « En cours » et les dates ne dépendent pas de l'heure.
- **Dates relatives au jour de la capture** (J = aujourd'hui) : les cartes calculent « Demain », « En cours »,
  « Terminée » d'après l'horloge. Les deux galeries capturées le même jour montrent donc les mêmes dates.
- Lecteur : **Camille Durand**, membre de l'équipe, fuseau des sorties (pas de mention de fuseau), unités métriques,
  français.

## Données

- Équipe : **Vélo Club des Monts** (24 membres, privée). Deuxième équipe pour les listes : **Gravel Bretagne** (publique, 112 membres).
- Personnes : Léa Martin, Karim Benali, Camille Durand, Noé Perrin, Inès Roche, Sacha Morel, Jeanne Colin, Malo Guérin.
- Parcours **Boucle des Monts d'Arrée** : 92,4 km, 1 240 m D+, route, public, tags « vallonné », « Finistère », par Léa Martin.
  Parcours du groupe B : 78,0 km, 980 m D+. Groupe C : 61,0 km, 720 m D+.
- Sortie **Boucle des Monts d'Arrée** : J+4 à 09:00, départ « Place de la Mairie, Huelgoat », publiée, visible de l'équipe, 2 commentaires.
  Groupes : **A** 28 km/h, 8/12, capitaine Léa Martin, 09:00 · **B** 25 km/h, 11/12, 09:30 · **C** 22 km/h, 12/12 (complet), 10:00.
- Météo de la sortie : 9 à 13 °C, vent d'ouest 18 km/h, pluie 20 %. Variante alerte : pluie 60 % vers 11:00.
- Voyage **Traversée du Morvan** : J+10 → J+12, départ 08:30, 12 personnes, 201 km, 3 340 m D+.
  Étapes : « Autun → Château-Chinon » (J+10 08:30, 74 km, 1 380 m, 22 km/h) · « Château-Chinon → Saulieu » (J+11 09:00, 68 km,
  1 120 m) · « Saulieu → Avallon » (J+12 09:00, 59 km, 840 m).
- Voyage d'une étape **Aller-retour au mont Beuvray** : J+5 à 08:30, 96 km, 1 650 m D+. C'est son étape qui figure dans
  « Les 7 prochains jours » (la Traversée du Morvan est au-delà de la semaine).
- Publication **Bilan de la saison** : publiée J−2 à 18:30 par Léa Martin, 4 commentaires, extrait de deux lignes.
- Annonce **Vélo de route carbone taille M** : vente, 1 200 €, secteur « Brest », publiée J−5 ; **Remorque enfant** : location,
  15 € par jour ; **Roues gravel 700** : recherche, prix à négocier.

## Sections et cas

| Section | Cas (identifiant → ce qu'il montre) |
|---|---|
| **fil** | `fil-sortie` nominale, non inscrite · `fil-sortie-inscrite` (groupe B, 09:30) · `fil-sortie-demain` (J+1) · `fil-sortie-en-cours` (partie il y a 1 h) · `fil-sortie-terminee` (J−2) · `fil-sortie-annulee` · `fil-sortie-brouillon` · `fil-sortie-sans-groupe` (ni groupe ni parcours) · `fil-sortie-alerte-pluie` · `fil-voyage` · `fil-voyage-inscrit-en-cours` · `fil-voyage-annule` · `fil-publication` (avec photo) · `fil-publication-brouillon` (sans photo) · `fil-supprime` |
| **accueil** | `prochaine-sortie` (inscrite au B) · `prochaine-sortie-sans-maximum` · `prochaine-sortie-vide` · `semaine` (5 lignes : sortie, inscrite, annulée, étape, brouillon) · `semaine-vide` · `mes-equipes` (2 équipes, rôles différents) · `mes-equipes-vide` |
| **agenda** | `agenda-sortie` · `agenda-inscrite` · `agenda-annulee` · `agenda-etape` · `agenda-passee` |
| **groupes** | `groupes-inscrite-b` (les trois cartes, heures différentes, Camille dans le B) · `groupes-non-inscrite` (même heure) · `groupe-sans-parcours` · `groupe-sans-meteo` |
| **etapes** | `etapes` (les trois) · `etape-sans-parcours` · `etape-alerte-pluie` |
| **parcours** | `parcours` · `parcours-sans-vignette` · `parcours-supprime` · `parcours-ligne` (densité compacte) · `usages` (« Utilisé dans » : une sortie, un voyage) |
| **annonces** | `annonce-vente` · `annonce-location` · `annonce-recherche` · `annonce-brouillon` |
| **equipes** | `equipe` (membre) · `equipe-admin` · `equipe-decouverte` (non membre, si la carte existe) · `invitations` (une invitation) · `membre` · `membre-admin` · `inscrits` (8 personnes, capitaine) |
| **tableau** | `a-traiter` (les quatre tuiles) · `mes-sorties` (sortie, voyage) · `sortie-a-venir` · `sortie-a-venir-inscrite` · `sortie-a-venir-complet` · `sortie-a-venir-sans-parcours` · `dernieres-publications` · `nouveaux-parcours` · `annonces-tableau` |
| **divers** | `notification-non-lue` · `notification-lue` · `notification-modification` · `modele` · `modele-brouillon` · `appareils` · `commentaires` (un commentaire, une réponse, un supprimé) |

## Capture

- **App** : simulateur iPhone 17 Pro Max, mode clair, une capture par section en faisant défiler.
- **Site** : largeur 1280 px et largeur 390 px, mode clair, une capture pleine page par section.
- Les captures vont dans `captures/app/` et `captures/site/` de ce dossier, nommées par section.
