# Constat à l'écran — galeries de cartes, app et site (2026-11-12)

Étape 2 de la [méthode](METHODE.md). Matière : `captures/app/*.png` (390 pt, ratio 2, vers 01:01) et
`captures/site/*-1280.png`, `*-390.png` (vers 00:53), les dix sections, cas par cas. Tout ce qui suit a été **vu sur
l'image**. Quand une phrase s'appuie sur autre chose (le code, une hypothèse), elle le dit.

---

## 1. Défauts du tri, vus à l'écran

### En tête : annoncés corrigés, encore visibles

| # | Statut | Ce qu'on voit | Cas |
|---|---|---|---|
| **D13** (site) | **pas corrigé pour les milliers** | La virgule est là (« 92,4 km », « 78,0 km », « 201,0 km »), mais aucun séparateur de milliers : « 1240 m », « 1380 m », « 1120 m », « 1200,00 € ». Partout sur le site, aux deux largeurs. | `groupes-*`, `etapes`, `etape-alerte-pluie`, `parcours*`, `usages`, `sortie-a-venir*`, `nouveaux-parcours`, `annonce-*`, `annonces-tableau` |
| **D26** (app) | **pas corrigé** | L'app a encore deux formateurs de prix : « 1 200,00 € » sur la carte d'annonce, « 1200,00 € » au tableau de bord. | `annonce-vente` / `annonces-tableau` |
| **D25** (app) | **corrigé pour les étapes seulement** | « via l'étape Autun → Château-Chinon » est juste, mais on lit « via les groupes : A » pour un seul groupe. | `usages` |
| **D16** (site) | **ordre corrigé, suffixe non** | L'ordre distance · dénivelé · vitesse est bon. Le dénivelé est « ↑ 980 m » sans « D+ » (l'app écrit « 980 m D+ »). | `groupes-*`, `etapes` |

### Les autres défauts

| # | Statut | Où vu / pourquoi non visible |
|---|---|---|
| D1 | vu corrigé (sortie) | `fil-sortie-brouillon` : « Brouillon » sous « Sortie ». Aucun cas de voyage en brouillon. La ligne en brouillon des 7 jours n'a toujours pas de badge : voir N6. |
| D2 | vu corrigé | `fil-voyage-annule` : « Voyage » puis « Annulé ». |
| D3 | non visible | La galerie n'a pas d'équipe d'un seul membre (« 24 membres », « 112 membres »). Le même défaut de pluriel apparaît ailleurs : N7. |
| D4 | vu corrigé | `equipe-admin`, `membre-admin` : « Administrateur ». |
| D5 | non visible | L'état en cours d'inscription n'est pas capturé. |
| D6 | non visible | Galerie en français seulement. |
| D7 | non visible | Galerie en métrique, et la carte n'affiche pas de hauteur de pluie. |
| D8 | vu corrigé | `semaine` : « 09:30 · Vélo Club des Monts · B ». Le groupe s'écrit « B », pas « Groupe B », pareil sur le site. |
| D9 | vu corrigé (badge) | `equipe`, `equipe-admin` : badge de rôle en pastille. Le logo ne se vérifie pas : les données n'ont que des initiales. |
| D10 | vu corrigé | `sortie-a-venir`, fil : le nombre de groupes ne porte plus l'icône des personnes. La nouvelle icône ressemble à celle du dénivelé : N16. |
| D11 app | vu corrigé | `annonce-*`, `annonces-tableau` : « Secteur Brest », sans épingle. |
| D11 site | vu corrigé | `annonce-*` : « Secteur Brest », sans épingle. |
| D12 | non visible | Aucun de ces textes n'apparaît dans la galerie. |
| D14 | vu corrigé | `groupes-inscrite-b` (site) : « Changer pour A » en pleine largeur au pied de la carte A. |
| D15 | non visible | Aucun cas de carte de groupe d'une sortie annulée. |
| D17 | vu corrigé | `usages` (site) : « dim. 22 → mar. 24 nov. ». |
| D18 | non visible | La section `agenda` du site monte `AgendaRow`, pas la vue téléphone de `CalendarView`. |
| D19 | non visible | `semaine` a exactement 5 lignes. |
| D20 | non visible | Aucune sortie annulée ou passée ne tombe aujourd'hui ou demain. `fil-sortie-annulee` et `fil-sortie-terminee` n'ont pas de pastille, mais elles n'en auraient pas eu de toute façon. |
| D21 | vu corrigé | `equipe` (site) : « Le club des routes du centre Finistère… ». |
| D22 | vu corrigé | `inscrits` (site) : les lignes n'ont pas de chevron. |
| D23 | non visible | Textes absents de la galerie. |
| D24 | non visible | Pas de notification de publication. Les cartes disent « Publication » des deux côtés. |
| D25 site | vu corrigé | `usages` : « via l'étape : Autun → Château-Chinon », « Utilisé dans ». |
| D25 « Utilisé dans » | vu corrigé | `usages`, des deux côtés. |
| D26 site | cohérent, mais voir D13 | « 1200,00 € » sur la carte comme au tableau. |
| **R8** | non visible | Les captures sont figées : aucune confirmation ne s'y voit. « Se désinscrire » est bien sur « Ma prochaine sortie » des deux côtés. |
| **R9** publication / annonce | vu corrigé | `fil-publication` : « mar. 10 nov. · 18:30 », des deux côtés. `annonce-*` : « sam. 7 nov. · 18:42 ». |
| **R9** relatif | vu corrigé (< 7 j) | « il y a 2 heures », sans « environ », des deux côtés (`notification-*`, `commentaires`). La bascule vers la date après 7 jours n'est pas visible. |
| **R9** voyage | vu corrigé | « Départ 08:30 » puis la plage, des deux côtés. Sur le site, la ligne se coupe mal : N21. |
| **R9** membre | vu corrigé | « Membre depuis mars 2024 » (app), « Membre depuis janvier 2026 » (site). |
| **R14** visibilité | site vu, app non visible | Le site écrit « Équipe uniquement ». L'app n'affiche la visibilité d'aucune carte d'équipe privée. |
| **R14** inscription | site vu, app non visible | Site : « Karim Benali a rejoint votre sortie ». Dans l'app, `notification-lue` est un rappel (« Rappel : votre sortie part demain »). |
| **R14** modification | vu corrigé | App : « Une sortie change de date ». Site : « Une sortie change de date et de point de départ ». |
| **R14** webhook | non visible | Pas de cas dans la galerie. |

---

## 2. Nouveaux défauts

| # | Support | Cas | Ce qu'on voit | Ce qui serait attendu | Défaut sûr ou décision |
|---|---|---|---|---|---|
| N1 | App | `agenda-*`, `parcours*`, `sortie-a-venir*`, `nouveaux-parcours` contre `groupes-*`, `etapes`, `fil-voyage` | « 1240 m », « 1380 m » sur les unes ; « 1 240 m D+ », « 1 380 m D+ », « 3 340 m » sur les autres | Fine insécable partout (KIT §8) | Sûr |
| N2 | App | `groupes-inscrite-b`, `groupes-non-inscrite` (carte sélectionnée) | « 11/12 p… », « 8/12 p… » : le compte est tronqué pour faire place à « Voir tout » | « 11/12 personnes » en entier | Sûr |
| N3 | App | `sortie-a-venir`, `-inscrite`, `-complet`, `-sans-parcours` | « départ 10… », et « départ 0… » sur les trois lignes de `-complet` | L'heure entière | Sûr |
| N4 | App + site | `sortie-a-venir-complet` | « S'inscrire » alors que A, B et C sont complets | Pas de bouton, ou « Complet » désactivé | Sûr |
| N5 | App | `sortie-a-venir-inscrite` | La distance affichée est celle du parcours, « 92,4 km · 1240 m », alors que Camille est dans le B (78 km) | Relève de R3 (décidé, pas encore codé) | Décision prise, à coder |
| N6 | App | `semaine`, ligne « Sortie découverte » (mer. 18) | Brouillon sans badge (le site affiche « Brouillon ») | Badge « Brouillon », comme dans le fil (D1) | Sûr |
| N7 | App | `membre`, `membre-admin` | « 1 membres sur 1 » en pied de liste (l'en-tête dit bien « 1 membre ») | « 1 membre sur 1 » | Sûr |
| N8 | App | `usages` | « via les groupes : A » | « via le groupe A » | Sûr (de la famille de D25) |
| N9 | App + site | App : `mes-equipes-vide` (« n'êtes »), `equipe-decouverte` (« Rejoindre l'équipe »), `sortie-a-venir` (« S'inscrire »), `appareils` (« l'application »). Site : partout (« d'Arrée », « l'appareil », « n'êtes »…) | Apostrophes droites. Dans l'app, elles voisinent avec des apostrophes courbes (« d’Arrée », « Sortie d’hiver ») | Une seule apostrophe, la typographique | Probable (je n'ai pas vérifié que BRANDING §8.3 la fixe). Les titres du site sont peut-être saisis autrement que ceux de l'app : voir §4 |
| N10 | App | `groupes-*` carte A, `groupe-sans-meteo` | Léa Martin est dans la grappe alors que « Capitaine : Léa Martin » est écrit juste au-dessus | Grappe sans la capitaine (KIT §8) | Sûr (app) ; le site fait pareil, à décider sous R5 |
| N11 | Site | Toutes les grappes (fil, groupes, tableau) | Avatars si serrés que les initiales sont illisibles : « LI K N II SI » | Initiales lisibles (chevauchement réduit ou initiale unique) | Sûr |
| N12 | App | Fil, groupes, accueil | La deuxième lettre des initiales est mangée par l'avatar suivant (« KE », « MC », « NP ») | Comme N11, en moins grave | Décision |
| N13 | App | `prochaine-sortie-sans-maximum` | Compte « 31 » alors que la grappe montre 5 + 6 = 11 personnes (le site affiche « B · 11 personnes ») | « 11 personnes » | À vérifier : bogue ou donnée de la galerie |
| N14 | App | `dernieres-publications` | « mar. 10 nov. · 18:30 · Léa Martin · 4 », puis « commentaires » sur la ligne suivante | Pas de coupure entre le nombre et son nom (insécable) | Sûr ; même coupure sur le site à 390 |
| N15 | App | `appareils` | « Appairé le mardi 13 octobre 2026 » : date longue avec le jour de la semaine | « Appairé le 13 octobre 2026 », comme le site et KIT §8 | Sûr |
| N16 | App | Fil, tableau | Les groupes ont une icône de montagne, presque la même que celle du dénivelé | Une icône de groupe distincte | Décision |
| N17 | App | `fil-publication-brouillon` | Titre tronqué sur une ligne (« Calendrier des sorties d'hi… ») ; les titres de sortie, eux, passent à la ligne | Le même traitement du titre partout | Décision |
| N18 | App + site | `mes-equipes` | « 2 sorties à venir · 1 voyage à venir · 1… » (app) ; « 3 sorties à venir · 1 voyage à ven… » (site) | Ligne qui tient, ou moins de compteurs | Décision |
| N19 | App | `agenda-*` | « Place de la Mai… » tronqué derrière l'équipe | Relève de R11 | Décision |
| N20 | App | `groupes-inscrite-b` | Aucun bouton « GPS » sur la carte de mon groupe, ni sur « Ma prochaine sortie » | « GPS » sur la carte de son groupe (KIT §8) | À vérifier : la galerie a peut-être coupé le fournisseur des services connectés |
| N21 | Site | `fil-voyage*` (1280 et 390), `mes-sorties` à 390 | « Départ 08:30 · », puis « dim. 22 → mar. 24 » et « nov. » seul sur une troisième ligne | La plage sur sa propre ligne, insécable | Sûr |
| N22 | Site | `semaine` (1280 et 390) | « Reconnaissance du … » avec le badge tronqué « BROUI… », et « Boucle des Monts d'A… » | Badge entier ; le titre cède avant le badge | Sûr |
| N23 | Site | `sortie-a-venir*` à 1280 | « COMP… », « départ 1… », « départ 09:… » | Badge et heure entiers | Sûr si la colonne a sa largeur réelle (voir §4) |
| N24 | Site | `membre-admin` à 390 | Badge « ADMINISTRA… » | Badge entier, ou le nom qui passe à la ligne | Sûr |
| N25 | Site | `etapes`, `etape-*` | Titre d'étape tronqué (« Autun → Château-Chi… », « Autun → C… » à 390) parce que la date partage la ligne. Départ et arrivée sont répétés dessous | Date sous le titre, ou titre sans répétition | Sûr |
| N26 | Site | `modele-brouillon` | « Nocturne d'été » n'a pas de badge « Brouillon » (l'app en a un) | Badge « Brouillon » | À vérifier : donnée ou rendu |
| N27 | Site | `modele`, `modele-brouillon` | Allures en capitales : « A 28 KM/H », « TOUS 24 KM/H » | « 28 km/h » (on ne met pas une unité en capitales) | Sûr |
| N28 | Site | `mes-sorties` | Voyage : même icône pour « 3 étapes » et « 201,0 km » | Une icône par grandeur | Sûr, faible |
| N29 | Site | `groupes-*` à 390 | Les badges « Face » et « Dos » passent à la ligne, sous la météo | Relève de R2 (KIT §8 : pas de Face/Dos dans la carte) | Décision |
| N30 | Site | Cartes du fil (1280 et 390) | La colonne de badges prend la moitié de la carte : extrait réduit à « Trois groupes, trois allures : café au reto… », titre sur deux lignes | Relève de R1 (moins de badges) | Décision |

Par support : **app 17** (N1–N3, N5–N8, N10, N12–N17, N19, N20), **site 11** (N11, N21–N30), **les deux 3**
(N4, N9, N18).

---

## 3. Écarts restants, par règle ouverte

### R1 — Badges d'état

- **App** : badges en colonne, à droite du titre. Fil : « Supprimé » puis type, puis l'état (« Annulé », « En cours »,
  « Terminée », « Brouillon »), puis « J'y vais » (`fil-voyage-inscrit-en-cours` : Voyage · En cours · J'y vais).
  Jamais « Publié » ni la visibilité. Annonce : type, puis « Brouillon ». Agenda : « Annulé », « J'y vais · B » ; une
  sortie passée est grisée, sans badge. Parcours : Supprimé · Route · Public. Équipe : le rôle ; en découverte,
  « Public ». Modèle : « Publié » ou « Brouillon ».
- **Site** : fil : Supprimé, puis En cours ou J'y vais, puis type, puis « Publié » ou « Brouillon », puis « Équipe
  uniquement », toujours (`fil-voyage-inscrit-en-cours` : En cours · J'y vais · Voyage · Publié · Équipe uniquement). Pas
  de « Terminée ». Annonce : type · Publié · Équipe uniquement. Agenda : « Annulé » seulement s'il y a lieu, puis
  « J'y vais », puis « Équipe uniquement ». Aucune différence pour une sortie passée. Équipe : « Équipe uniquement » sur
  l'équipe privée, rien sur la publique, puis le rôle. Modèle : pas de statut.
- **`tri.md`** : exact. À compléter : pour la sortie passée, l'app la grise et le site ne fait rien, ni opacité ni badge.

### R2 — Ligne météo

- **App** : « 9–13 °C · ➤ 18 km/h · Pluie 20 % » sur le fil, la carte de groupe, l'étape et « Ma prochaine sortie ». En
  alerte, l'icône devient une goutte et une ligne orange s'ajoute : « ⚠ Pluie 60 % vers 11:00 ». Pas de météo sur une
  sortie en cours, terminée ou annulée, ni sur un voyage.
- **Site** : fil, étape et « Ma prochaine sortie » : « 9 → 13 °C · (vent) → 18 km/h », sans pluie. En alerte : badge bleu
  « PLUIE DÈS 11:00 » et icône de nuage de pluie. Carte de groupe : autre forme, « 9 °C · Partiellement nuageux ·
  FACE 23,4 KM · DOS 23,4 KM » (une température, une condition, deux badges, ni plage ni vent). La météo reste affichée
  sur une sortie en cours (`fil-sortie-en-cours`).
- **`tri.md`** : **inexact**. Le site écrit « Pluie dès 11:00 » en badge, pas « Averses dès 11:00 ». Sur la carte de
  groupe, on ne voit pas « Averses 60 % vers 11:00 » mais la forme Face/Dos décrite ci-dessus. « Météo dès le » n'est
  pas visible dans la galerie.

### R4 — Compteurs

- **App** : les zéros sont masqués. Sortie : « 31 personnes · 3 groupes · 2 commentaires ». Voyage : « 3 étapes ·
  201,0 km · 3 340 m », pas de nombre de personnes (la grappe seule). Parcours : pas de commentaires. Sortie sans
  groupe : aucun compteur. Tableau de bord : « 3 groupes · 2 commentaires ».
- **Site** : les zéros sont affichés : « 0 groupe » (`fil-sortie-sans-groupe`), « 0 commentaire » (voyages, parcours,
  `dernieres-publications`). Voyage du fil : « 12 personnes · 3 étapes · 0 commentaire », sans distance. Le voyage du
  tableau de bord donne pourtant la distance : « 3 étapes · 201,0 km ».
- **`tri.md`** : exact. À ajouter : sur le site, le voyage a une distance au tableau de bord et n'en a pas dans le fil.

### R5 — Personnes inscrites

- **App** : avatars teintés par nom, 5 visibles puis « +N ». Fil : « 31 personnes ». Groupe : « 8/12 personnes »
  (tronqué à « 11/12 p… » quand « Voir tout » est sur la carte, N2) ; groupe complet : barre rouge « 12/12 » à la place
  de la grappe. « Ma prochaine sortie » : « 11/12 » à côté de l'icône, grappe et jauge orange. Tableau de bord : barres
  « 8 / 12 », badge rouge « Complet ». « Voir tout » sur la carte sélectionnée seulement, et « Voir les 31 personnes
  inscrites » sous les cartes.
- **Site** : avatars tous en primaire, illisibles (N11). Groupe : « 11/12 personnes · Voir tout » sur chaque carte ;
  groupe complet : badge gris « Complet » si je ne suis nulle part, rien si je suis dans un autre groupe. « Ma prochaine
  sortie » : « B · 11/12 personnes », ni grappe ni jauge. Fil : « 31 personnes ». Tableau de bord : barres bleues
  « 8 / 12 », badge rouge « Complet ».
- **`tri.md`** : **dépassé pour le fil**. Le site n'écrit plus « 8/12 places » mais « 31 personnes », comme l'app.
  « Voir tout au-delà de 5 » ne se vérifie pas : tous les cas ont plus de 5 personnes.

### R6 — Contrôles d'inscription

- **App** : sur ma carte, badge « J'y vais » en haut et lien rouge « Quitter le groupe » en bas. Autre groupe :
  « Changer pour A » en pleine largeur, au pied. Groupe complet : bouton gris « Complet », même quand je suis inscrite
  ailleurs. Non inscrite : « Rejoindre » plein, dans l'en-tête à côté du chevron. « Ma prochaine sortie » : « Voir la
  sortie » plein et « Se désinscrire » en contour, côte à côte.
- **Site** : sur ma carte, « Quitter » en contour dans le coin. « Changer pour A » en pleine largeur au pied, comme
  l'app. Groupe complet : rien quand je suis inscrite ailleurs, badge « Complet » sinon. Non inscrite : « Rejoindre » en
  haut à droite. « Ma prochaine sortie » : « Voir la sortie », « Envoyer vers l'appareil », puis « Se désinscrire » en
  texte, sous les deux.
- **`tri.md`** : **dépassé sur « Changer pour »**, désormais sur le site. L'option 2 n'a donc plus d'objet ; le reste
  est exact.

### R7 — Export

- **App** : aucun bouton d'export sur aucune carte de groupe, la mienne comprise, ni sur « Ma prochaine sortie », ni sur
  une étape (N20).
- **Site** : « GPX · FIT · Envoyer vers l'appareil » sur chaque carte de groupe, même celles où je ne suis pas.
  Étape : « GPX · Envoyer vers l'appareil », **sans FIT**. « Ma prochaine sortie » et « Vos prochaines sorties » :
  « Envoyer vers l'appareil » seul.
- **`tri.md`** : **inexact**. Le site n'a pas de FIT sur l'étape, et « Ma prochaine sortie » ne propose que l'appareil.
  Le « GPS » de l'app sur la carte de son groupe n'apparaît pas dans la galerie.

### R10 — Image d'en-tête

- **App** : sortie : la carte du tracé en bandeau, répétée en vignette. Voyage : le tracé en bandeau, sans vignette.
  Sans parcours : dégradé bleu et vélo. Publication : illustration ; en brouillon, dégradé rose et icône. Parcours sans
  vignette : dégradé et icône. Équipe : pas de bandeau dans la liste, dégradé en découverte. Étape : numéro en pastille
  bleue, trait de la couleur du tracé après le titre.
- **Site** : sortie : toujours le dégradé bleu et le vélo, la carte du tracé en vignette à droite. Voyage : dégradé
  vert, icône, vignette. Publication et annonce : photo. Parcours sans vignette : rien. Équipe : dégradé et icône.
  Étape : numéro, sans couleur.
- **`tri.md`** : exact. La galerie confirme le constat déduit (« bandeau presque toujours un dégradé »), mais seulement
  sur ses données : aucune sortie de la galerie n'a de photo.

### R11 — Lieu et groupe

- **App** : « Ma prochaine sortie » empile badges, équipe, titre, « Départ 09:30 », « B », puis « ● Place de la Mairie »
  avec « Huelgoat » dessous, puis chiffres, météo, grappe et boutons. 7 jours : « 09:30 · Vélo Club des Monts · B ».
  Agenda : « 09:00 · Vélo Club des Monts · Place de la Mai… », le groupe dans le badge « J'y vais · B ». Étape : aucun
  lieu. Tableau de bord : « Place de la Mairie » puis « B · 25 km/h ».
- **Site** : « Ma prochaine sortie » : titre, équipe, « Départ 09:30 », « Place de la Mairie, Huelgoat » sur une ligne,
  météo, « B · 11/12 personnes », tuiles Distance et Dénivelé positif, boutons. 7 jours : « 09:30 · Vélo Club des
  Monts · B », comme l'app. Agenda (`AgendaRow`) : « Départ 09:30 » puis « Place de la Mairie, Huelgoat », sans équipe
  ni groupe. Étape : départ et arrivée. Tableau de bord : « Place de la Mairie, Huelgoat · B · 25 km/h ».
- **`tri.md`** : **dépassé pour les 7 jours**, alignés depuis D8. Le calendrier n'est pas dans la galerie : sa
  description n'est pas vérifiée.

### R12 — Champs propres

- **App** : parcours sans extrait, avec la ligne d'équipe. Carte d'équipe de la liste : « 24 membres » et le rôle, sans
  description. Découverte : description, badge « Public », « Rejoindre l'équipe ». « Mes équipes » : compteurs à venir
  et rôle. Modèle : « Sortie du dimanche » · Publié, « 3 groupes · prochaine sortie #12 », menu ⋯. Commentaire en texte
  simple.
- **Site** : parcours avec extrait (« Par Léa Martin. Le Roc’h Trévézel… »), sans équipe. `TeamCard` : description,
  « 24 membres », visibilité, rôle. Modèle : nom, description, « 3 groupes · Équipe uniquement », allures « A 28 KM/H… »
  (N27), tags, crayon et corbeille, sans statut.
- **`tri.md`** : **dépassé sur deux points**. La carte de découverte de l'app porte « Public » (la visibilité), plus
  « Membre ». Le modèle affiche « prochaine sortie #12 », pas « n° 42 ». Le Markdown des commentaires ne se vérifie pas :
  l'exemple n'en contient pas.

### R13 — Actions au-delà de l'ouverture

- **App** : « Rejoindre l'équipe » sur la carte de découverte. Menu ⋯ sur le modèle (contenu non capturé). Aucun menu
  visible sur les lignes de membre ni de personne inscrite.
- **Site** : aucune action sur la carte de découverte. Modèle : modifier, supprimer. Lignes de membre et de personne
  inscrite : aucune action visible.
- **`tri.md`** : pas vérifiable pour « signaler ou bloquer depuis la ligne » côté app : la galerie ne montre ni menu
  ni appui long.

---

## 4. Défauts de la galerie à corriger avant d'en faire une référence

**Données qui diffèrent entre les deux supports** (le cahier `galerie.md` n'est pas suivi à l'identique) :

- Description de la sortie : app « Trois groupes, trois allures, un café à l'arrivée au Roc'h Trévézel » ; site « Trois
  groupes, trois allures : café au retour… ».
- `fil-sortie-sans-groupe` : l'app l'appelle « Sortie libre du samedi », sans commentaire ; le site garde « Boucle des
  Monts d'Arrée », « Rendez-vous libre… » et 2 commentaires. Un samedi tombe ici un lundi 16.
- `fil-publication-brouillon` : app « Calendrier des sorties d'hiver », « jeu. 12 nov. · 08:00 », sans commentaire ;
  site « Bilan de la saison », « mar. 10 nov. · 18:30 », 4 commentaires.
- `semaine` : app « Sortie récupération », « Tour du lac du Drennec » (annulée), « Sortie découverte » (brouillon),
  étape le **dim. 22** ; site « Sortie du mercredi » (un vendredi), « Côtes de Crozon », « Reconnaissance du
  Ménez-Hom », étape le mer. 18. Côté app, l'étape à J+10 n'a rien à faire dans « Les 7 prochains jours ».
- `agenda-annulee` : app « Tour du lac du Drennec », 54 km ; site « Boucle des Monts d'Arrée ».
- `mes-equipes` : app VC « 2 sorties », GB **Organisateur**, « 112 membres » ; site VC « 3 sorties », GB
  **Administrateur**, « 5 sorties à venir ». `equipe-admin` : app Vélo Club des Monts, site Gravel Bretagne.
- Descriptions d'équipe (« Le gravel en Bretagne… » contre « Chemins, pistes et bonne humeur… »), invitation (Inès
  Roche contre Karim Benali), ancienneté (Noé : mars 2024 contre janvier 2026 ; Léa : mars 2021 contre septembre 2024).
- Annonces : descriptions différentes, secteurs Brest / Morlaix / Carhaix (app) contre Brest partout (site), dates toutes
  au 7 nov. (app) contre 7, 9 et 11 nov. (site), illustration (app) contre photo (site).
- `groupe-sans-parcours` : app groupe **B** (couleur du A, 11/12, sans capitaine) ; site groupe **A**. `etape-sans-parcours` :
  app étape 2, site étape 1.
- `notification-lue` : app un rappel, site « a rejoint votre sortie ». Modèles : « Sortie du dimanche » / « Sortie
  d'hiver » contre « Sortie du samedi » / « Nocturne d'été ». Appareils : 13 octobre / 14 août contre 13 septembre /
  26 avril. Commentaires : textes différents ; « 2 commentaires » (app) contre « Commentaires (3) », supprimé compris
  (site).
- `a-traiter` : app « 2 Brouillons », « 1 Signalement », sortie sans parcours « Sortie récupération, Demain » ; site
  « 1 Brouillon », « 2 Signalements », « Côtes de Crozon, mer. 18 nov. ». `nouveaux-parcours` : 2ᵉ parcours « Monts
  d'Arrée, parcours B » (app) contre « Tour du lac du Drennec » (site).
- Apostrophes : les titres sont typographiques dans l'app (« d’Arrée ») et droits sur le site (« d'Arrée »), alors que
  l'extrait du site écrit « Roc’h ». Les chaînes semblent saisies différemment : à unifier avant de juger N9.

**Cas qui ne montrent pas ce que dit leur légende** :

- `prochaine-sortie-vide` (site) monte toute la page d'accueil avec des listes vides, pas la carte. Elle affiche
  « Aucune sortie prévue… » à côté d'un « Mes équipes » qui annonce 3 sorties à venir.
- `modele`, `modele-brouillon` (site) montent toute la page de gestion de l'équipe.
- `agenda-etape` est absent du site, et la section ne montre pas la vue téléphone du calendrier (D18 invérifiable).
- `prochaine-sortie-sans-maximum` (app) : « 31 » pour un groupe de 11 (N13), si c'est la donnée.
- `modele-brouillon` (site) : pas de badge, peut-être parce que le statut n'est pas posé dans la donnée (N26).
- `notification-lue` (app) ne montre pas une inscription : la règle R14 n'y est pas testable.

**Largeur** : à 1280, les cartes `sortie-a-venir*` du site sont montées dans une colonne d'environ 260 px, ce qui coupe
« COMP… » et « départ 1… » (N23). À 390, la même carte tient en entier. Il reste à vérifier si c'est la vraie largeur
de la grille du tableau de bord.

**Heure de capture** (sans compter d'écart) : `fil-sortie-en-cours` affiche « jeu. 12 · Départ 00:00 » dans l'app
(01:01 − 1 h) et « mer. 11 · Départ 23:52 » sur le site (00:52 − 1 h ; 23:53 à 390). Les deux supports montrent donc
deux jours différents. Les relatifs diffèrent aussi un peu (« il y a 35 minutes » contre « 30 minutes », « 16 heures »
contre « 20 heures »), sans qu'on puisse séparer l'effet de l'heure d'une donnée différente. Pour les prochaines
captures, mieux vaut fixer « maintenant » à midi.

---

## 5. Ce que je n'ai pas pu voir

- **Mode sombre** : l'app a l'interrupteur, mais seule la série claire est capturée.
- Les confirmations (R8), le contenu des menus ⋯ (modèle, commentaire), l'état d'inscription en cours (D5) et les
  erreurs de carte (R6) : ce sont des interactions, une capture figée ne les montre pas.
- L'anglais (D6), l'impérial (D7), le webhook (R14), la bascule du relatif après 7 jours (R9), « Météo dès le »
  (R2), plus de 5 lignes dans les 7 jours (D19), un voyage en brouillon (D1), une sortie annulée avec groupes (D15), la
  vue téléphone du calendrier (D18), une équipe d'un seul membre (D3).
- Les espaces insécables (ordinaire, insécable ou fine) : ils ne se distinguent pas à l'œil. Je n'ai constaté que leur
  présence ou leur absence.
- Toutes les tranches étaient lisibles. Je n'ai lu les cas du site à 390 qu'en mosaïque réduite : ils reprennent ceux
  de 1280, et seuls les retours à la ligne et les troncatures y diffèrent (relevés en N21, N22, N24, N25, N29).
