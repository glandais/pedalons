# Audit d'homogénéité des cartes — app mobile ↔ site web (2026-11-11)

> **État au 12 novembre 2026.** Fait : l'audit (ce fichier et ses quatre axes), le [tri](tri.md) en défauts,
> décisions et écarts voulus, les deux galeries de cartes et leur cahier commun ([galerie.md](galerie.md)), le
> [constat sur captures](constat-captures.md), les planches « Cartes — cibles » et les décisions sur les quatorze règles
> (R1 à R14), écrites dans [`KIT.md` §9](../maquettes/KIT.md) et reportées dans `docs/BRANDING.md` §7 et §8. En cours :
> la mise en œuvre, par lots, selon la [méthode](METHODE.md) — ledgers `MOB-139` (app) et `WEB-167` (site), `API-178`
> pour la distance d'affichage. Les écarts voulus sans source sont au ledger (`WEB-171`, `MOB-140`).

Les cartes et lignes de liste (sortie, voyage, publication, groupe, étape, parcours, annonce, équipe, membre, tableau
de bord, notification, modèle de sortie, appareil, commentaire) comparées entre l'app et le site, et à l'intérieur de
chaque support. Branche `feat/mobile-review`, après la refonte `MOB-134`. Les planches correspondantes sont sur la page
« Cartes » des [maquettes](../maquettes/README.md).

## Méthode et limites

- Quatre audits par lecture du code, un par axe, chaque ligne citant `fichier:ligne` des deux côtés :
  [libelles.md](libelles.md), [donnees.md](donnees.md), [formats.md](formats.md), [actions.md](actions.md).
- **Rien n'a été observé à l'écran** : ni app ni site lancés. Les rendus de `intl` et de `date-fns` sont déduits de
  leurs motifs. Chaque fichier a une section « Non vérifié ».
- Trois constats relus à la main après coup, confirmés : nombres du site sans la langue (`frontend/src/utils/unitFormat.ts`),
  aucun changement de groupe sur le site (`frontend/src/pages/ride/rideGroupData.ts`, `registeredElsewhere`), aucun
  « Annulé » sur « Ma prochaine sortie » du site (`frontend/src/components/home/NextRideCard.tsx`). Le reste n'a pas
  été relu.
- Les axes se recoupent : un même écart peut figurer dans deux fichiers (« Changer pour », « Annulé » sur la prochaine
  sortie). Les totaux ne s'additionnent donc pas.

| Axe | Forts | Moyens | Faibles | Pistes réfutées |
|---|---|---|---|---|
| [Libellés et vocabulaire](libelles.md) | 3 | 31 | 50 | — |
| [Données affichées](donnees.md) | 8 | 45 | 45 | 13 |
| [Formats des valeurs](formats.md) | 1 | 23 | 25 | 10 |
| [Actions, inscription, personnes, états](actions.md) | 14 | 26 | 33 | 4 lignes alignées |

Gravité : **fort** = la même information dit deux choses différentes, ou une action existe d'un côté et pas de
l'autre ; **moyen** = même sens, forme différente et visible ; **faible** = détail.

## Les écarts forts

### Une action existe d'un seul côté

| Écart | App | Site | Détail |
|---|---|---|---|
| Changer de groupe | « Changer pour {groupe} », un appel | Rien : inscrit ailleurs, la carte ne propose aucune action | actions I1 |
| Quitter une sortie annulée | Aucun contrôle | « Quitter » et « Se désinscrire » restent | actions I4 |
| Menu ⋯ des cartes de liste (modifier, publier, supprimer) | Absent | Publication, parcours, annonce | actions A1 |
| « Ajouter au calendrier » depuis une carte | Absent | Entrée du menu ⋯ | actions A2 |
| Export depuis une carte de groupe | « GPS », sur la carte de son groupe seulement | GPX, FIT, « Envoyer vers l'appareil » sur toutes | actions A4 |
| Export depuis une carte d'étape | Aucun | GPX, FIT, envoi | actions A5 |
| Rejoindre une équipe depuis sa carte | Oui (écran de découverte) | Non | actions A11 |
| Gérer un membre depuis sa ligne | Signaler, bloquer | Changer le rôle, retirer | actions A13 |
| Supprimer un commentaire | Sans confirmation | Avec confirmation | actions A15 |

### La même information dit deux choses

| Écart | App | Site | Détail |
|---|---|---|---|
| « Annulé » sur « Ma prochaine sortie » — **sans effet**, voir la note | Badge « Annulé » | Rien | données 2.1 |
| Sortie ou voyage en brouillon, dans le fil | Aucun badge | « Brouillon » | actions E3 |
| Voyage annulé, dans le fil | Aucun badge | « Annulé » | actions E4 |
| Compteurs d'un voyage | Étapes, distance, D+ ; aucun nombre de personnes | Personnes, étapes, commentaires ; pas de distance | données 1.4, 1.5 |
| Pluie | Toujours (« Pluie 20 % », ou « Pluie 60 % vers 11:00 ») | Seulement en alerte (« Averses dès 11:00 ») | formats |
| Bandeau de la carte de sortie | Carte du tracé, répétée en vignette | Photo ou dégradé, la carte en vignette | données 1.1 |
| Lieux de départ et d'arrivée d'une étape | Absents | Affichés | données 4.8 |
| Modèle de sortie | Statut, prochain numéro | Description, visibilité, groupes, tags | données 9.3 |
| Jauge de places dans le fil | Absente (voulu) | Présente | actions P4 |

Note du tri (11 novembre 2026) : l'écart « Annulé » sur « Ma prochaine sortie » existe dans le code mais ne se voit
jamais. Les deux supports ne demandent que les sorties publiées (`next_ride_provider.dart`, `nextRideParams.ts`,
`status: PUBLISHED`) : une sortie annulée n'arrive pas dans cette carte. Le badge de l'app est du code mort.

### La même sortie, quatre cartes, des chiffres différents — sur les deux supports

Fil : aucune distance. Prochaine sortie : celle du groupe. Calendrier : celle du parcours de la sortie. Tableau de
bord : celle de la sortie ou du premier groupe. Le schéma est le même dans l'app et sur le site (données A.1, S.1) :
ce n'est pas un écart entre supports, c'est une incohérence commune.

## Les écarts moyens qui reviennent partout

- **Nombres** : le site ignore la langue (« 92.4 km », « 1240 m ») ; l'app écrit « 92,4 km », « 1 240 m ».
- **Compteurs à zéro** : le site affiche « 0 groupe », « 0 commentaire » ; l'app les masque.
- **Dates** : publication et annonce en date longue avec l'année dans l'app, en date courte avec l'heure sur le site ;
  date relative « il y a environ 2 heures » sans bascule sur le site, « il y a 2 heures » puis date absolue après
  7 jours dans l'app.
- **Voyage** : l'app donne « Départ 09:00 » puis la plage ; le site la plage seule.
- **Température** : « 9–13 °C » contre « 9 → 13 °C ».
- **Vocabulaire** : « Admin » / « Administrateur » ; « Équipe » / « Équipe uniquement » ; « GPS » / « Envoyer vers
  l'appareil » ; « Membre depuis » / « A rejoint le » ; « Météo dès le » / « Météo disponible à partir du » ;
  « Inactif » / « Désactivé » ; textes des notifications et des états vides.
- **Badges** : le site montre toujours le statut (« Publié ») et la visibilité ; « Terminée » n'existe que dans l'app.
- **Personnes inscrites** : avatars colorés par nom dans l'app, tous de la couleur primaire sur le site ; « Voir
  tout » sur la carte sélectionnée dans l'app, au-delà de 5 personnes sur le site.
- **Groupe et étape** : distance · D+ · vitesse dans l'app, vitesse · distance · dénivelé sur le site.
- **Commentaires** : Markdown rendu dans l'app, texte brut sur le site.

## Défauts propres à un support

**App**
- `teams.members` sans pluriel : « 1 membres » (déduit).
- « Adhésion... » pour rejoindre un groupe de sortie, « Inscription... » pour un voyage.
- Dates longues assemblées à la main, mois en minuscules : casse l'anglais (« Monday 15 january 2026 »).
- Hauteur de pluie jamais convertie en impérial.
- État « passé » rendu de trois façons (opacité, « Terminée », rien) ; compteur de groupes sur deux icônes.
- `_TeamCard` de l'onglet Équipes encore en style Material, logo lu ailleurs que les autres cartes d'équipe.
- Nom du groupe absent des lignes « Les 7 prochains jours ».

**Site**
- Plage d'un voyage écrite de deux façons (« ven. 20 → dim. 22 nov. » dans le fil, « ven. 20 nov. → dim. 22 nov. »
  dans « Utilisée dans »).
- Prix formaté de trois façons.
- Guillemets droits dans deux confirmations de suppression.
- Distance et D+ absents de la vue téléphone du calendrier.
- Confirmation de désinscription sur « Ma prochaine sortie » seulement, pas sur les cartes de groupe.

**Les deux**
- « … » et « ... » mélangés.
- « Utilisée dans » au féminin pour un parcours.
- « Publication » sur les cartes, « article » dans les notifications.
- Restes non épicènes : « Soyez prévenu », « n'en sera pas prévenu » (app) ; « n'en sera pas informé », « Soyez
  certain. » (site).

## Pistes réfutées

- Les trois formats d'heure de départ de l'app existent à l'identique sur le site : un choix commun, pas un écart.
- L'heure en 12 h ou 24 h selon la langue, la boîte du jour, « 11/12 personnes » d'un groupe, l'arrondi de la vitesse
  et les unités impériales sur les cartes sont alignés.
- « Se désinscrire sans confirmation dans l'app, avec sur le site » : vrai seulement pour « Ma prochaine sortie ».
- La coche de « J'y vais » ne diffère que sur la carte des 7 prochains jours.

## Suite

Rien n'est décidé ni corrigé ici. Le tri des écarts est dans [tri.md](tri.md) : 26 défauts, 14 règles à décider, 7 écarts voulus. La marche à suivre
proposée est dans [METHODE.md](METHODE.md) : tri en trois tas,
galeries de cartes, maquettes avant / cible, lots par règle. L'alignement du site est suivi par le ledger `WEB-165` ;
les défauts propres à l'app n'ont pas encore d'entrée.
