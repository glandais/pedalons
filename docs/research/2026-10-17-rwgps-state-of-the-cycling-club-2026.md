# « State of the Cycling Club 2026 » (Ride with GPS) — lecture pour Pédalons

*Analyse du 17 octobre 2026. Source : [ridewithgps.com/clubs-industry-report-2026](https://ridewithgps.com/clubs-industry-report-2026),
publié en septembre 2026. L'état de Pédalons décrit ici a été vérifié dans le code le même jour ; les
chemins sont relatifs à la racine du dépôt.*

## Sommaire

1. [En une page](#1-en-une-page)
2. [La source et ses limites](#2-la-source-et-ses-limites)
3. [Ce que dit le rapport](#3-ce-que-dit-le-rapport)
4. [Les 18 pratiques, confrontées à Pédalons](#4-les-18-pratiques-confrontées-à-pédalons)
5. [Ce qui confirme le produit](#5-ce-qui-confirme-le-produit)
6. [Les écarts, classés](#6-les-écarts-classés)
7. [Lancement et commercialisation](#7-lancement-et-commercialisation)
8. [Questions ouvertes](#8-questions-ouvertes)

---

## 1. En une page

Le rapport valide la thèse de Pédalons — **un seul outil pour le calendrier, la liste des membres et
les parcours** — et chiffre ce que les clubs y gagnent. Réduire le nombre d'outils est la deuxième
« meilleure décision des deux dernières années » citée par les clubs (23 %), juste derrière la refonte
de l'offre de sorties (27 %).

Il montre surtout que **Pédalons possède déjà la plupart des données utiles, mais les montre mal ou
pas à la bonne personne** :

| Le rapport dit… | Pédalons aujourd'hui | Écart |
|---|---|---|
| 9 titres de sortie sur 10 ne disent pas l'allure | Les groupes ont une vitesse moyenne, mais la carte du fil n'affiche que le nombre de groupes | Affichage |
| 40 % des « je viens » viennent de non-membres | Seul un membre peut s'inscrire à une sortie | Règle d'accès |
| 38 % des clubs n'ont aucun accueil des nouveaux | Aucun message, aucune notification à l'adhésion | Fonction absente |
| La liste ne bouge pas ; seuls 40 % des inscrits roulent dans le mois | Les participations sont en base, aucune vue « actifs » pour l'admin | Restitution |
| Les clubs qui utilisent des séries publient 2× plus de sorties | Les modèles pré-remplissent, ne génèrent rien | Fonction absente |
| Publier ≥ 2 semaines avant double les inscriptions | Publication programmée disponible | Couvert |
| Les clubs ont besoin d'une vitrine pour les inconnus | Page publique d'équipe en SSR, prochaines sorties, sitemap | Couvert |

Les cinq chantiers au meilleur rapport effet/coût, détaillés en [§6](#6-les-écarts-classés) :

1. **Allure sur les cartes de sortie** (S)
2. **« Rejoindre et s'inscrire » en un clic sur une sortie publique** (S–M)
3. **Accueil du nouveau membre** avec une sortie « découverte » (S–M)
4. **Membres actifs vs inscrits** et usage des parcours pour l'admin d'équipe (M)
5. **Séries de sorties** générées en brouillon pour la saison (M–L)

---

## 2. La source et ses limites

**Méthode.**
- Enquête auprès des responsables de clubs, du 21 août au 4 septembre 2026 : une réponse par club,
  anonyme, ouverte à tout club volontaire. Le texte ne donne pas l'effectif total ; une comparaison
  « environ 70 clubs contre 70 » laisse supposer **de l'ordre de 140 répondants**.
- Questions surtout ouvertes, classées par thème selon la première idée exprimée.
- Données de production Ride with GPS (RWGPS), août–septembre 2026, sur tous les comptes club actifs
  (au moins un membre connecté dans les 90 jours), agrégées.

**Géographie.** 71 % États-Unis, 13 % Canada, 11 % Royaume-Uni, le reste Australie/Nouvelle-Zélande,
Europe et Amérique du Sud. **Pratiquement aucune donnée française.** Les montants sont en dollars,
les vitesses en mph, la saison est celle de l'hémisphère nord.

**Biais déclarés par les auteurs.**
- Les clubs qui répondent à une enquête sur la gestion de club sont ceux qui sont gérés avec soin.
- Chaque fois qu'un chiffre de plateforme accompagne une pratique, c'est **une association, pas une
  cause** : âge du club, taille et qualité de gestion vont ensemble.
- Aucune des 18 pratiques n'a été testée comme intervention.
- Deux hypothèses testées et **non confirmées** : l'accueil des nouveaux ne se voit pas dans le taux de
  départ déclaré ; la taille de la bibliothèque de parcours ne prédit presque pas l'engagement.

**Biais non déclarés.** C'est un document marketing : il se termine par un essai gratuit, et le
« membre » mesuré est celui qui a rejoint le club *sur RWGPS*, souvent une partie seulement des
adhérents réels. Les chiffres de plateforme décrivent donc des clubs qui utilisent RWGPS, et parmi eux
ceux qui y tiennent leur calendrier — moins de la moitié.

**Ce qu'on peut en tirer.** Les ordres de grandeur et les mécanismes (l'inconnu ne sait pas quelle
sortie lui convient, la liste ne mesure pas l'activité, le meneur bloque sur le choix du parcours) se
transposent bien. Les pourcentages précis, non.

---

## 3. Ce que dit le rapport

### 3.1 Qui sont les clubs

- **Taille.** Environ la moitié des clubs ont 51 à 200 membres ; un tiers sont plus gros, un cinquième
  plus petits.
- **Âge.** 81 % placent les 60–69 ans dans leurs trois tranches principales ; les moins de 30 ans n'y
  figurent que pour 5 %. Le rapport considère que ce graphique explique une bonne partie du reste.
- **Femmes.** 39 % des clubs déclarent au moins 50 % de femmes ; une part comparable en déclare moins
  de 40 %. Les clubs qui ont fait bouger ce chiffre décrivent des années de travail délibéré.
- **Cotisation.** 8 clubs sur 10 en demandent une, modeste (exemples cités : 10 $ par an facultatifs,
  20 £ par an en prélèvement automatique). À ce niveau, c'est un signal d'engagement et un support
  d'assurance, pas un modèle de financement.
- **Pratique.** Le gravel apparaît dans près de 4 réponses sur 10, mais « l'avoir au programme » et
  « avoir du monde » sont deux choses différentes (§3.5).
- **Départs.** 27 % ne suivent pas le taux de départ. Ceux qui le suivent déclarent surtout moins de
  10 % par an. Près de la moitié des clubs de 200 à 500 membres ne le suivent pas.

### 3.2 Ce que voit la plateforme

**La liste n'est pas le club.** Sur 100 membres ayant rejoint un club il y a 1 à 2 ans :

| Mesure | Valeur |
|---|---|
| Toujours sur la liste | 97 |
| Connectés dans les 3 derniers mois | ~70 |
| Ayant enregistré une sortie (quelconque) dans les 30 derniers jours | ~40 (échantillon 1/100, ± 3 points) |
| Actifs sur 30 jours, tous clubs confondus | ~58 |

Un club qui perd des gens ne voit pas sa liste baisser : les gens cessent simplement de rouler, et la
perte apparaît un an plus tard, au renouvellement.

**La semaine et la saison.**
- 3,3 fois plus de sorties en juin qu'en février.
- Le samedi domine, le dimanche suit ; mais **mardi + jeudi pèsent plus que le dimanche, et plus que le
  samedi**. Le vendredi fait un quart du samedi, le lundi un peu plus d'un tiers.
- En semaine, deux créneaux presque égaux : 9–10 h et 17–18 h ; près de la moitié des sorties de
  semaine partent à 17 h ou plus tard. Le week-end, près de deux tiers partent à 8 ou 9 h.
- Un tiers des sorties viennent d'une **série récurrente** ; parmi les clubs qui publient au moins
  mensuellement, ceux qui utilisent des séries publient environ **deux fois plus**.

**Les parcours.**

| Mesure | Valeur |
|---|---|
| Parcours médian sous une sortie du samedi | 65 km, 430 m D+ |
| Mardi–jeudi | 45–50 km, environ un tiers de dénivelé en moins |
| Parcours moyen de bibliothèque | 85 km, 770 m D+ ; près de la moitié entre 50 et 100 km |
| Surface | 84 % route (≤ 10 % non revêtu), 10 % mixte, 6 % gravel |
| Taille de bibliothèque | médiane 145 ; quart supérieur > 439 |
| Part de la bibliothèque réellement roulée | environ un cinquième |
| Âge du parcours sous une sortie | médiane ~1 an ; un quart > 3 ans |
| Les 5 parcours les plus utilisés | moins d'un cinquième des sorties |
| Clubs ayant une bibliothèque / ayant déjà publié une sortie | 96 % / 72 % |

### 3.3 Les problèmes que nomment les clubs

**Le plus gros problème** (question ouverte) :
1. membres vieillissants sans relève — **25 %** ;
2. recruter et garder des membres ;
3. l'allure et le comportement en sortie ;
4. trouver des meneurs (meneurs + postes au bureau + succession ≈ **un cinquième** des réponses) ;
5. faire venir les membres existants — 10 %.

**Pourquoi les membres partent** : âge, blessure, maladie en premier (~30 %). Ensuite, environ un tiers
des réponses relèvent du club : intérêt perdu, sorties inadaptées, « adhéré mais jamais roulé avec
nous » — autant de causes logées **dans les premières sorties**, la seule partie que le club contrôle.
Scène récurrente : un nouveau se fait lâcher sur une sortie annoncée « sans lâcher » et ne revient
jamais.

**Comment les nouveaux arrivent** : bouche-à-oreille pour **42 %** — ça marche, ça ne coûte rien, mais
ça ramène surtout des gens qui ressemblent aux membres actuels, et pour la plupart des clubs c'est le
seul canal. Viennent ensuite le compte social du club, son site, et une sortie ouverte à tous. Un club
cite l'adhésion proposée en case à cocher à l'inscription de sa randonnée annuelle comme son plus gros
apport de l'année.

### 3.4 Le manque d'outillage

- **Accueil** : 38 % n'ont rien ; ailleurs, c'est surtout un e-mail de bienvenue — qui n'emmène
  personne à une sortie.
- **Partenariats locaux** : près de 3 clubs sur 10 n'en ont aucun ; le plus courant est une remise en
  magasin (~21 %), la moins susceptible d'amener quelqu'un. Ceux qui comptent produisent une sortie
  (sortie au départ du magasin, atelier mécanique, café comme point de départ) — 6 %.
- **Partage** : 54 % disent n'avoir rien trouvé qui vaille d'être transmis à un autre club. Le rapport y
  voit surtout l'absence d'endroit où comparer.
- **Culture** : les auto-évaluations (1 à 5) se concentrent aux extrémités — 21 % se notent 1, 29 % se
  notent 5. Ceux qui se notent 5 citent quelque chose de concret (devise, charte écrite, annonce de
  sortie qui va au-delà de la logistique) et ont **presque deux fois plus souvent un accueil prévu**
  (59 % contre 33 %).

### 3.5 Le programme de sorties

- **Rythme** : ~19 % des clubs roulent tous les jours, ~19 % une fois par semaine — surtout un effet de
  taille. Seuls **6 %** décrivent la semaine comme un choix délibéré ; la plupart disent qu'elle « a
  poussé » au gré des demandes.
- **Groupes** : deux tiers des clubs répartissent leurs sorties en groupes, surtout par plage de
  vitesse ; 31 % n'ont pas de groupes standard (plus de la moitié des clubs de moins de 25 membres).
- **Ce que lit un inconnu** : sur un an de titres de sorties, 8 % portent une lettre de groupe, 1 % une
  vitesse, moins de 1 % « sans lâcher » ou « débutant » ; 83 % ne disent rien d'utilisable. Avec la
  description, 68 % ne donnent toujours aucune allure. 87 % de ces sorties sont publiques, 3 sur 4 ont un
  parcours.
- **Tenir l'allure** : trop de groupes et chacun se vide ; trop peu et chacun se plaint. Le meneur qui
  roule au-dessus de l'allure annoncée fait fuir ceux qui étaient venus pour elle.
- **Parcours** : dans un quart des clubs, le meneur du jour choisit ; dans un huitième, une ou deux
  personnes font tout ; un cinquième puisent dans la bibliothèque. Les deux premiers modes sont
  fragiles. 4 clubs sur 10 gardent un noyau connu et ajoutent des nouveautés ; un tiers recyclent.
- **Gravel** : 25 % disent que ça a pris, 24 % que c'est confidentiel, 3 % ont arrêté. Dans les données,
  la part de parcours majoritairement non revêtus passe de **2,7 % (2019) à 8,9 % (2025)** ; avec les
  mixtes, environ 1 nouveau parcours sur 5 quitte le bitume. Là où ça a pris, le gravel est présenté
  comme la sortie calme, sociale, sans voitures ; là où ça a calé, comme une montée en difficulté.

### 3.6 Ce que fait le calendrier

| Sorties publiées sur RWGPS en 12 mois | Nouveaux membres / liste | Membres connectés |
|---|---|---|
| Aucune | 14 % | 65 % |
| Presque chaque semaine | 23 % | 77 % |

Plus de la moitié des clubs n'ont publié aucune sortie sur la plateforme l'an dernier ; environ 1 sur 5
publie au moins mensuellement.

- **Publier tôt** : une sortie ponctuelle est publiée en moyenne ~3 semaines avant. À un mois ou plus :
  ~11 « je viens » ; le jour même : ~3. À club égal, ≥ 2 semaines : ~6 contre 3, et l'avance l'emporte
  dans 7 clubs sur 10.
- **Qui s'inscrit** : **40 %** des « je viens » viennent de comptes absents de la liste du club ; 37 %
  dans le club médian ; **25 %** hors sorties à plus de 50 inscrits.
- **Quand on adhère** : un club de plus de 25 membres ajoute 11 à 13 % de sa liste par an, quelle que
  soit sa taille ; sous 25 membres, 61 % n'ont ajouté personne. **Avril concentre 19 %** des adhésions de
  l'année, décembre 3 %. Conseil du rapport : une campagne en mars, avec les premières sorties déjà au
  calendrier.

### 3.7 Ce qui a marché, selon les clubs

**Meilleure décision des deux dernières années** : changer les sorties (~27 %, le plus souvent en
ajoutant un type de sortie qui manquait), réduire les outils (~23 % : un calendrier et une liste au
même endroit). Seuls 8 % citent le recrutement, la fidélisation ou la culture. Aucune des deux
premières n'est une campagne de recrutement : elles rendent le club existant plus facile à rejoindre.

Exemples cités, par thème :
- **Sorties** : calendrier de la saison construit *avant* son début, parcours compris ; sortie
  d'initiation régulière (qui ramène aussi des membres dormants) ; groupe « balade » hebdomadaire ;
  sorties réservées aux femmes ; ouverture aux VAE ; « sans lâcher » par petits groupes espacés.
- **Meneurs** : programme de formation ; agrandir le vivier pour éviter l'épuisement ; remercier
  publiquement plutôt que recruter à la dure.
- **Outils** : quitter Meetup ; ne plus tenir le calendrier à deux endroits ; une date de renouvellement
  unique.
- **Site** : refaire le site pour les prospects, travailler le référencement.
- **Membres** : recontacter ceux qui n'ont pas renouvelé ; recentrer sur la participation plutôt que le
  recrutement ; définir ce qu'est un membre « actif ».

**Regrets** : surtout de l'infrastructure (site, outils, gouvernance, calendrier). Personne ne regrette
de ne pas avoir fait plus de publicité. Un club néo-zélandais tient encore sa liste sur tableur.

**Ce que les clubs voudraient demander aux autres** : comment trouver de nouveaux membres ; comment
attirer des plus jeunes et plus divers ; comment faire émerger des bénévoles ; comment passer à des
dizaines de meneurs sans perdre en qualité ; comment rivaliser avec les groupes « réseaux sociaux » qui
ne sont pas des clubs.

**Le Covid, six ans après** : changement durable de fonctionnement pour la plupart ; un cinquième a
perdu des membres jamais revenus ; seuls 13 % retiennent l'afflux.

Un club du Midwest résume la thèse de Pédalons : parcours, allure, participation et adhésions doivent
être *« on the same platform »*.

---

## 4. Les 18 pratiques, confrontées à Pédalons

Le rapport propose 18 pratiques (« Pick 3 »), chacune observée dans au moins un club, aucune testée.
État vérifié dans le code le 17 octobre 2026.

| # | Pratique du rapport | Ce que Pédalons permet | Ce qui manque |
|---|---|---|---|
| 1 | Une première sortie plutôt qu'un e-mail de bienvenue | Rien à l'adhésion | Accueil orienté vers une sortie ([§6-C](#c-accueil-du-nouveau-membre-sm)) |
| 2 | Orienter le nouveau vers le bon groupe ; par défaut, le plus lent ; prévenir le meneur | Groupes avec vitesse et meneur | Questions à l'adhésion, signal « nouveau » au meneur |
| 3 | L'allure dans le titre ; 2–3 groupes ; le meneur tient l'allure | `RideGroup.averageSpeed`, affiché en détail et au tableau de bord | Absent des cartes du fil ; pas de niveau ni de « sans lâcher » ([§6-A](#a-lallure-sur-les-cartes-s)) |
| 4 | Le gravel comme sortie facile ; % non revêtu dans l'annonce | Surface ROAD/GRAVEL/MTB/MIXED par parcours | Pas de pourcentage non revêtu |
| 5 | Un site pour les inconnus, prochaine sortie en page d'accueil | Page publique d'équipe en SSR avec prochaines sorties (API-86), page « À propos », sitemap, aperçus de liens | — (conseil éditorial aux clubs) |
| 6 | Sorties et parcours publics ; venir avant d'adhérer | Visibilité publique/non listée/équipe par contenu ; sortie publique visible en anonyme | Inscription réservée aux membres ([§6-B](#b-rejoindre-et-sinscrire-en-un-clic-sm)) |
| 7 | Demander des sorties aux magasins, pas des remises | — | Hors produit (conseil) |
| 8 | Co-organiser avec le club voisin ; relayer ses sorties | Fil unifié multi-équipes pour un membre de plusieurs équipes ; flux iCal global | Une sortie appartient à une seule équipe ([§6-I](#i-plus-loin)) |
| 9 | Concevoir la semaine ; départs échelonnés ; publier ≥ 2 semaines avant | Groupes avec heures de départ propres (`startAt`) ; publication programmée | Rien de bloquant |
| 10 | Alléger le travail du meneur : parcours attribués avant la saison ; les meneurs publient | Rôle Organisateur ; un parcours par groupe ; modèles | Génération de saison ([§6-E](#e-séries-de-sorties-ml)) |
| 11 | Rendre la culture visible (une phrase dans chaque annonce) | Markdown dans les modèles de sortie | — (conseil ; pré-remplissage déjà possible) |
| 12 | Limiter les notifications : abonnement par groupe d'allure, regroupement hebdo | Préférences par type × canal, sourdine par équipe, résumé quotidien | Filtre par groupe/tag ; résumé hebdo ([§6-F](#f-notifications-par-groupe-m)) |
| 13 | Compter les actifs, pas les noms | Participations en base | Aucune restitution ([§6-D](#d-actifs-vs-inscrits-m)) |
| 14 | Savoir pourquoi les membres partent (enquête, relance des non-renouvelés) | — | Hors produit pour l'essentiel |
| 15 | Bibliothèque de parcours en collections par niveau, élagage à l'usage | Tags de parcours, filtres distance/dénivelé/surface | Compteur d'usage, archivage ([§6-H](#h-parcours-s-chacun)) |
| 16 | Une liste, un calendrier, une date de renouvellement | Une liste et un calendrier | Cotisations : volontairement dehors ([§6-I](#i-plus-loin)) |
| 17 | VAE pour garder les membres âgés ; politique écrite | — | Mention par groupe (tag ou champ) |
| 18 | Un moins de 40 ans au bureau ; recruter les femmes tôt | — | Hors produit |

---

## 5. Ce qui confirme le produit

- **Le problème central est le bon.** La fiche produit place la dispersion des outils (WhatsApp,
  e-mail, Strava, tableurs) au cœur de la proposition ; le rapport la chiffre : 23 % des meilleures
  décisions, 13 % des regrets, et l'une des principales pistes citées pour un nouveau club.
- **Les groupes sont structurés.** RWGPS n'a pas de groupes de niveau de premier rang : ses clubs
  écrivent l'allure dans le titre, quand ils l'écrivent. Pédalons a des groupes A/B/C, chacun avec sa
  vitesse, son heure de départ, son parcours, sa jauge et son meneur (`RideGroupDto`). C'est
  l'avantage le plus net face à RWGPS — à condition de le montrer ([§6-A](#a-lallure-sur-les-cartes-s)).
- **La vitrine existe.** Page publique d'équipe en SSR avec les prochaines sorties, page « À propos »,
  `sitemap.xml`, `llms.txt`, Open Graph, bouton de partage : la pratique 5 est couverte.
- **Le calendrier est outillé pour publier tôt.** Publication programmée
  (`PublicationPublishScheduler`), brouillons, modèles numérotés (API-108), iCal par sortie, par équipe
  et global, relais Slack/Discord/Mattermost.
- **Le meneur est servi.** Météo par sortie et par étape, export FIT, envoi Garmin/Karoo/Wahoo, applis
  Garmin et Karoo.

---

## 6. Les écarts, classés

Tailles indicatives : S = quelques jours, M = une à deux semaines, L = davantage.

### A. L'allure sur les cartes (S)

**Constat.** `frontend/src/components/card/PublicationCard.tsx:110` n'affiche que le nombre de groupes.
La vitesse n'apparaît qu'en détail (`GroupStats.tsx`, `RideGroupCard.tsx`, mobile
`ride_group_card.dart`), au tableau de bord (`UpcomingRideCard.tsx:140`, mobile
`dashboard_rides.dart`) et dans la meta SEO (`frontend/src/config/routeMeta.ts:337`). C'est le
constat « 9 sur 10 » du rapport, version Pédalons.

**Proposition.**
- Sur la carte du fil (web et mobile) : « A 28 · B 25 · C 22 km/h », ou une plage min–max quand la
  place manque.
- Optionnel : un drapeau par groupe « sans lâcher » et/ou « découverte » (aucun niveau n'existe
  aujourd'hui). Touche le contrat (`RideGroupDto`, `GroupRequest`) et le modèle de groupe des modèles
  de sortie.

**Pourquoi d'abord.** C'est ce qu'un inconnu lit en premier, et c'est l'avantage de Pédalons sur RWGPS.

### B. « Rejoindre et s'inscrire » en un clic (S–M)

**Constat.** `backend/src/main/java/fr/pedalons/service/ride/RideAccessChecker.java:61-68` réserve
l'inscription aux membres ; côté web, `canJoinRide = isMember && …`
(`frontend/src/pages/ride/RideDetailPage.tsx:182`). Un connecté non membre voit un bandeau « voir
l'équipe », un anonyme un bandeau « se connecter ». Or une équipe ouverte (`joinable`) peut déjà être
rejointe sans validation (`TeamMembershipService.joinTeam`).

**Proposition.** Sur une sortie publique d'une équipe ouverte, un bouton qui fait les deux : adhésion
puis inscription au groupe choisi. Pour un anonyme, le même bouton après connexion/inscription.

**Pourquoi.** 25 à 40 % des « je viens » chez RWGPS viennent de non-membres. Pédalons ferme cette porte
alors que tout le reste du chemin existe.

**À trancher.** Une équipe non ouverte : inscription invitée sans adhésion, ou rien ? Le plus simple est
de ne rien changer pour elles.

### C. Accueil du nouveau membre (S–M)

**Constat.** Aucun message, aucune notification à l'adhésion (aucune occurrence de « welcome » /
« bienvenue » dans le backend). Les invitations par e-mail existent (`TeamInvitationService`), mais
s'arrêtent à l'acceptation.

**Proposition.**
- Une notification « Bienvenue dans <équipe> » qui pointe vers la prochaine sortie portant un tag choisi
  par l'équipe (« découverte »), ou à défaut la prochaine sortie.
- Un signal au meneur quand un membre de moins de N jours s'inscrit dans son groupe (pratique 2).
- Plus tard : un texte d'accueil rédigé par l'équipe.

**Pourquoi.** Les causes de départ que le club contrôle se logent dans les premières sorties ; les clubs
qui soignent leur culture ont presque deux fois plus souvent un accueil prévu.

### D. Actifs vs inscrits (M)

**Constat.** L'admin d'équipe ne voit que les nouveaux membres (`TeamDashboardAdminDto.newestMembers`)
et la répartition par rôle ; la liste ne se trie que par date d'adhésion (`MemberSortBy.JOINED_AT`).
Rien sur la dernière participation, le nombre de participations, les actifs sur une période, l'usage
des parcours. La dernière connexion n'existe que dans l'admin plateforme.

**Proposition.**
- Au tableau de bord admin : « X membres ont participé à une sortie dans les 90 derniers jours, sur Y ».
- Dans la liste des membres : dernière participation, tri par ce critère.
- Sur un parcours : « utilisé dans N sorties, dernière fois le … » (voir H).
- Respecter l'invariant des requêtes par page (`ParticipationLookup` et les tests `…QueryCountTest`).

**Pourquoi.** C'est la consigne qui revient le plus dans le rapport, et un argument de vente : « votre
vrai chiffre ».

**À ne pas confondre avec `WEB-91`**, qui écartait l'*audience web* (GoatCounter, exemption CNIL) pour
les admins de club. Ici, ce sont des participations internes à l'équipe, déjà visibles par sortie. La
base légale et la finalité restent à écrire (intérêt légitime de l'association pour gérer son activité ?)
et la politique de confidentialité à compléter.

### E. Séries de sorties (M–L)

**Constat.** `RideTemplate` pré-remplit et numérote (« Sortie du jeudi #42 », API-108) ; aucun
planificateur ne génère de sorties.

**Proposition.** À partir d'un modèle : « tous les jeudis du 3 avril au 25 septembre », créés en
brouillon, chacun publiable seul (publication programmée à J-14 par défaut ?), parcours attribuables à
l'avance par groupe.

**Pourquoi.** Les séries doublent le nombre de sorties publiées chez RWGPS, et un club a résolu sa
pénurie de meneurs en construisant la saison d'avance : le volontaire s'engage sur une date, pas sur
une page blanche.

**Points durs.** Modifier ou annuler une occurrence sans casser la série ; numérotation ; ce que voient
les abonnés aux notifications (une rafale de publications ?) ; déploiement à chaud si un planificateur
s'en mêle (idempotence, cf. CLAUDE.md).

### F. Notifications par groupe (M)

**Constat.** Préférences par type × canal (`NotificationPreference`), sourdine par équipe
(`NotificationTeamMute`), résumé quotidien seulement.

**Proposition.** Abonnement par tag de sortie (le vocabulaire existe déjà) ou par plage de vitesse ;
résumé hebdomadaire.

**Priorité basse** tant que seuls les organisateurs publient : le problème décrit par le rapport naît
quand les meneurs publient eux-mêmes en nombre.

### G. Le canal e-mail (décision produit)

**Constat.** Le canal e-mail est construit mais coupé en production (décision du 21 septembre 2026) ;
le push suppose l'application ou le site installé.

**Pourquoi le rouvrir.** Le cœur de cible a 60–70 ans, et les clubs du rapport font vivre leur culture
par une annonce envoyée deux jours avant chaque sortie, lue comme une lettre d'information. Au moins le
résumé quotidien par e-mail mérite d'être reconsidéré pour ce public.

### H. Parcours (S chacun)

- **Compteur d'usage** et date de dernière utilisation sur chaque parcours ; tri par usage.
- **Archivage** : `Status` ne connaît que DRAFT/PUBLISHED/CANCELLED ; élaguer veut dire supprimer.
  Un état « archivé » (hors listes, toujours lisible depuis les sorties passées) suivrait la pratique 15.
- **Pourcentage non revêtu**, si la classification de surface s'appuie sur une donnée qui le permet.
- **Collections par niveau** : les tags suffisent ; c'est du conseil aux clubs.

### I. Plus loin

À rouvrir sur une demande réelle :
- **Inter-clubs** : relayer la sortie d'une équipe voisine dans son fil, ou co-organiser (une sortie
  appartient aujourd'hui à une seule équipe).
- **Carte des clubs** pour la découverte : `Team.geometry` existe, la découverte se limite à une liste
  filtrable par `joinable`.
- **VAE** : mention par groupe ; un tag par équipe suffit pour commencer.
- **Proposer une sortie** pour un simple membre (brouillon soumis à l'organisateur).

**Volontairement dehors** : cotisations, adhésion payante, date de renouvellement. En France, licences et
adhésions passent par les fédérations (FFVélo, FFC) et les outils de gestion associative ; un export de
la liste des membres suffit comme pont.

---

## 7. Lancement et commercialisation

- **Calendrier.** Les adhésions culminent en avril, et le rapport conseille une campagne en mars. Les
  clubs décident de leurs outils pendant l'hiver (assemblées générales, préparation de saison) : c'est
  là qu'il faut leur parler, avec une saison déjà saisissable en janvier–février.
- **Discours.** « Un calendrier, une liste, des parcours, au même endroit » ; « l'allure de chaque groupe
  visible avant de venir » ; « votre vrai nombre d'actifs » (après D).
- **Reprendre la recette.** Le rapport est lui-même le meilleur outil d'acquisition de RWGPS : enquête,
  constats chiffrés, « trouvez votre propre chiffre », 18 pratiques concrètes, formulaire pour le PDF.
  Une enquête **« État des clubs cyclistes 2027 »** sur le terrain français — où RWGPS n'a presque pas de
  données — ferait la même chose pour pedalons.fr, et les chantiers A et D permettraient aux clubs de
  calculer leurs propres chiffres dans le produit.
- **Cible.** Le profil décrit ressemble probablement aux clubs de cyclotourisme français, mais le
  rapport ne le prouve pas. En conséquence : écrans lisibles, e-mail, parcours simples, et la relève
  comme argument (le carnet de parcours et le calendrier survivent au départ du président).
- **Concurrence.** RWGPS vend un compte club centré sur la bibliothèque de parcours et la navigation
  (guidage vocal, hors ligne). Pédalons se distingue par les groupes structurés, le français, la météo,
  l'envoi vers trois marques de compteurs et la vitrine publique en SSR.

---

## 8. Questions ouvertes

1. Les chantiers A à E deviennent-ils des entrées `LEDGER_NEXT.md` (préfixes `WEB`, `API`, `MOB`) ?
2. B : que faire pour une équipe fermée ou sur invitation ?
3. D : base légale et mention dans la politique de confidentialité (préfixe `LEGAL`).
4. G : réouvrir le canal e-mail, au moins pour le résumé ?
5. Enquête française 2027 : qui, quand, quel canal de diffusion ?
