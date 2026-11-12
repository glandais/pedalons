# Tri de l'audit des cartes — trois tas (2026-11-11)

Étape 1 de la [méthode](METHODE.md). Matière : les écarts **forts et moyens** de [libelles.md](libelles.md),
[donnees.md](donnees.md), [formats.md](formats.md) et [actions.md](actions.md), dédoublonnés. Proposition à relire :
rien n'est décidé ici.

**Lire une référence** : « libelles 3.1 » = fichier `libelles.md`, ligne 3.1 ; « actions I4 » = `actions.md`, ligne I4.

**Comment j'ai tranché** :

- `KIT.md` §8 s'impose à l'app. Le ledger `WEB-165` (« Aligner le web sur les décisions des cibles mobiles ») l'étend
  au site pour ce qu'il nomme : heure de son groupe, « Changer pour A », bouton « GPS » unique, ordre des chiffres. Sur
  ces points, le site est en défaut. Sur le reste de KIT §8, la règle est une décision dont KIT §8 donne l'option
  recommandée.
- `BRANDING.md` §7 décrit le site. Quand l'app s'en écarte exprès, c'est une décision, pas un défaut.
- En cas de doute, j'ai classé en décision.

**Une correction à l'audit** : « Annulé » sur « Ma prochaine sortie » (libelles 1.4, données 2.1, écart fort) n'a
**aucun effet**. L'app et le site ne demandent que les sorties publiées (`next_ride_provider.dart:47`,
`frontend/src/pages/home/nextRideParams.ts:16`) : une sortie annulée n'apparaît jamais sur cette carte, ni d'un côté
ni de l'autre. Classé en écart voulu (V6).

---

## Décisions prises le 11 novembre 2026

Tranchées avec le propriétaire, une par une. Les règles sont écrites dans [`KIT.md` §9](../maquettes/KIT.md).

| Sujet | Décision |
|---|---|
| Lecture de `WEB-165` | Le site suit `KIT.md` §8 : D14 (« Changer pour »), D15 (« Quitter » sur une sortie annulée) et D16 (ordre des chiffres) sont bien des défauts. |
| D11, épingle d'une annonce | Icône retirée, « Secteur {lieu} » seul. Vaut aussi pour le site (`AdCard.tsx`, `IconMapPin`) : D11 passe dans « Les deux ». |
| **R8** Confirmation | Quitter ou changer de groupe : jamais. Supprimer : toujours. Le site retire la confirmation de « Ma prochaine sortie » ; l'app confirme la suppression d'un commentaire. |
| **R9** Date d'une publication, d'une annonce | Courte avec l'heure : « dim. 8 nov. · 18:30 », l'année hors année en cours. L'app s'aligne. |
| **R9** Date relative | Celle de l'app : « il y a 2 heures », sans « environ », date absolue au-delà de 7 jours. Le site s'aligne. |
| **R9** Carte de voyage | « Départ 09:00 » puis la plage de dates. Le site ajoute l'heure. |
| **R9** Ancienneté d'un membre | « Membre depuis mars 2024 ». Le site s'aligne. |
| **R14** Visibilité | « Équipe uniquement ». L'app s'aligne. |
| **R14** Notification d'inscription | « {nom} a rejoint votre sortie ». L'app s'aligne. |
| **R14** Notification de modification | Le titre dit ce qui change (« Une sortie change de date »). Le site s'aligne. |
| **R14** Webhook | Un seul badge (« Actif », « Échec », « Désactivé ») ; « Réussi » ; « JSON ». L'app s'aligne. |
| **R3** Distance d'une sortie | Calculée par l'API pour la personne qui lit : celle de son groupe si elle est inscrite, sinon celle du parcours commun, sinon rien. Entrée `API-…` à créer. |

### Décisions du 12 novembre 2026, sur les planches « Cartes — cibles »

Les planches sont `maquettes/project/cible-cartes-r*.dc.html` ; l'état réel de départ est dans
[constat-captures.md](constat-captures.md).

| Règle | Décision |
|---|---|
| **R1** Badges d'état | Un badge signale une exception : Supprimé → type → un état (Annulé, En cours, Terminée, Brouillon) → J'y vais. Jamais « Publié ». La visibilité seulement si elle diffère de celle de l'équipe. BRANDING §7.1 à modifier. |
| **R2** Ligne météo | Celle de l'app partout : « 9–13 °C · vent · Pluie 20 % », alerte « Pluie 60 % vers 11:00 », « Météo dès le 15 novembre ». Le site s'aligne ; sa carte de groupe perd la condition nommée et les badges Face / Dos. |
| **R4** Compteurs | Zéros masqués partout. Voyage : étapes · distance · D+ · personnes, commentaires s'il y en a. Une personne non membre voit le compte, jamais les noms. |
| **R5** Personnes inscrites | Une seule forme : « 11/12 personnes », grappe gardée même sur un groupe plein, initiales lisibles, une couleur par personne sur les deux supports (BRANDING §7.5 à modifier), capitaine hors de la grappe, « Voir tout » dès que la grappe affiche « +N ». Barre de places sous la grappe, **indigo, rouge si plein** (plus de vert ni d'orange). |
| **R6** Inscription | Les règles de l'app partout : lien rouge « Quitter le groupe » au pied de la carte, « Complet » en bouton désactivé même si l'on est inscrit ailleurs, erreur dans la carte concernée, quitter possible jusqu'à la fin de la sortie, « Se désinscrire » de « Ma prochaine sortie » en lien rouge. BRANDING §7.7 à réécrire. |
| **R7** Export | Un seul bouton « GPS » (appareil, GPX, FIT), sur la carte de son groupe, sur « Ma prochaine sortie » et sur les étapes d'un voyage où l'on est inscrit. **Visible jusqu'à la fin de la sortie** (la planche le dessine masqué au départ : à corriger). |
| **R10** Image d'en-tête | Photo, sinon carte du tracé, sinon dégradé ; pas de vignette du tracé quand le bandeau est déjà la carte ; trait de couleur du tracé sur la carte d'étape du site. Sans changement d'API. |
| **R11** Lieu et groupe | Première ligne heure · équipe · groupe ; le lieu sur sa propre ligne, nom seul (« Groupe B · Place de la Mairie » sous « Départ 09:30 ») ; la carte d'étape nomme départ → arrivée, la date sous le titre. |
| **R12** Équipe, parcours | Une seule carte d'équipe dans l'app (celle de la découverte : bandeau, extrait sur 2 lignes, vrai rôle, membres) ; extrait sur 2 lignes sur la carte de parcours de l'app. |
| **R12** Modèle de sortie | Carte commune : nom et statut, « 3 groupes · prochaine sortie #12 », groupes avec leur vitesse, description sur 2 lignes si elle existe. Ni visibilité ni tags sur la carte. |
| **R12** Commentaire | Texte brut des deux côtés ; l'app cesse de rendre le Markdown. |
| **R13** Actions | Le site gagne « Rejoindre l'équipe » sur la carte d'équipe, « Créer une sortie » sur la carte d'un modèle, et un menu ⋯ « Signaler / Bloquer » sur les lignes de membre et de personne inscrite (menu ⋯ ajouté aussi dans l'app, où l'action existe sans être montrée). |

Toutes les règles sont décidées. Restent ouverts, relevés par les planches : espace fine ou normale pour les milliers
(lisibilité en gras) ; « Groupe B » ou « B » dans les lignes compactes ; répéter ou non départ → arrivée quand le titre de
l'étape le dit déjà ; l'export depuis « Ma prochaine sortie » peut demander une donnée que son résumé n'a pas.

---

## 1. Défauts

Un seul côté a raison. Corrigés sans maquette, au lot 0.

### App

| # | Ce qui est faux | Correction | Réfs | Taille | Écran d'abord |
|---|---|---|---|---|---|
| D1 | Une sortie ou un voyage en brouillon n'a pas de badge « Brouillon » dans le fil (la publication l'a) | Tester `DRAFT` dans `_RideBody` et `_TripBody` comme `_PostBody` | actions E3, INT-A8 | XS | |
| D2 | Un voyage annulé n'a pas de badge « Annulé » (la sortie l'a) | Ajouter le badge dans `_TripBody` | actions E4, INT-A8 | XS | |
| D3 | « {count} membres » sans pluriel : « 1 membres » | Passer `teams_page` et `team_discovery_card` sur la clé plurielle `teams.membersList.count` | libelles 4.5, A2 ; formats 6.6 | XS | oui (déduit) |
| D4 | « Admin » au lieu de « Administrateur » | Clé `roles.admin` = « Administrateur » (BRANDING §8.4 : les rôles gardent leur nom) | libelles 2.1 | XS | |
| D5 | « Adhésion... » pour rejoindre un groupe de sortie : c'est le mot d'une équipe | « Inscription… », comme le voyage (`trips.joining`) | libelles 3.5, A3 ; actions I9, INT-A10 | XS | |
| D6 | Dates longues assemblées à la main, mois en minuscules : casse l'anglais (« Monday 15 january 2026 ») | Motifs `intl` par langue dans `formatFullDate`, `formatDayMonth`, `formatLongDate`, « Membre depuis » | formats A1, A2 | S | oui (déduit) |
| D7 | Hauteur de pluie toujours en mm, même en impérial (écrans de détail) | `formatPrecipitation` prend les unités, comme le site | formats 2.6 | S | |
| D8 | Lignes « Les 7 prochains jours » sans le nom du groupe, alors que l'heure affichée est celle du groupe (BRANDING §7.8) | « 09:00 · Équipe · Groupe A », comme le site | données 2.9, A.5 | XS | |
| D9 | `_TeamCard` (onglet Équipes) en style Material, badge de rôle dessiné à la main, logo lu dans `about.assets` | `PdlBadge`, logo lu dans `team.logoUrl` comme les autres cartes d'équipe | données A.7 ; libelles A8 | S | |
| D10 | Au tableau de bord, le compteur de groupes porte l'icône des personnes | Une seule icône de groupe dans toute l'app, jamais celle des personnes | données A.2 ; actions INT-A4 | XS | |
| D11 | Icône d'épingle (`location_on`) devant le lieu d'une annonce. L'invariant dit « un secteur, jamais une épingle » ; le tableau de bord l'écarte déjà | Retirer l'icône, garder « Secteur {lieu} ». Gravité faible dans l'audit, remonté parce qu'il touche un invariant | données A.10 | XS | |
| D12 | Non épicène : « Soyez prévenu… », « {name} n'en sera pas prévenu » | Reformuler (BRANDING §8.4) : « Recevez une alerte… », « {name} ne recevra aucune alerte » | libelles E1, E2 | XS | |

### Site

| # | Ce qui est faux | Correction | Réfs | Taille | Écran d'abord |
|---|---|---|---|---|---|
| D13 | Nombres sans la langue : « 92.4 km », « 1240 m », « 6.5% », espace ordinaire avant l'unité | `Intl.NumberFormat` de la langue dans `unitFormat.ts`, insécable et fine (BRANDING §8.3, KIT §8) | formats 1.1, 1.2, 1.3, S3 | S | |
| D14 | Aucun changement de groupe : une personne inscrite ailleurs ne voit aucune action | « Changer pour {groupe} » en un appel (`API-171`), au pied des autres cartes (KIT §8, `WEB-165`) | libelles 3.1 ; actions I1 | M | vérifier l'endpoint dans le client généré |
| D15 | « Quitter » reste sur la carte du groupe d'une sortie annulée | Masquer le contrôle si la sortie est annulée ; le badge « J'y vais » reste (KIT §8, `MOB-134`) | actions I4 | XS | |
| D16 | Chiffres d'un groupe ou d'une étape dans l'ordre vitesse · distance · dénivelé | Distance · « D+ » · vitesse (KIT §8, `WEB-165`) ; ramasser au passage le suffixe « D+ » et la vitesse nulle (formats 1.4, 1.6) | données 4.1 ; formats 1.5 | XS | |
| D17 | Plage d'un voyage dans « Utilisée dans » : « ven. 20 nov. → dim. 22 nov. », assemblée dans le composant | Passer par `formatPublicationSpan`, comme le fil | formats 3.5, S1 | XS | |
| D18 | Vue téléphone du calendrier : le statut (« Annulé ») n'apparaît pas | Rendre le badge de statut dans la vue téléphone | données 3.3, S.4 | XS | |
| D19 | « 7 prochains jours » : au-delà de 5 lignes, le reste disparaît sans mention | « N autres événements au calendrier », comme l'app | données 2.11 | XS | |
| D20 | Pastille « Aujourd'hui / Demain » sur une sortie annulée ou passée | Ne pas la poser dans ces deux cas (`MOB-115`) ; idem sur « Ma prochaine sortie » | données 1.16, 2.8 ; formats 3.8 | XS | |
| D21 | `TeamCard` ignore `team.excerpt` et ne lit que `about.markdown`, vide en vue compacte | Lire `excerpt` d'abord, comme les autres cartes | données 7.2 | XS | oui (déduit) |
| D22 | Ligne d'une personne inscrite : un chevron, mais la ligne ne s'ouvre pas | Retirer le chevron (ou donner l'action, voir R13) | actions A14, INT-W10 | XS | |
| D23 | Non épicène : « n'en sera pas informé. Vous pourrez le débloquer », « posts », « Soyez certain. » | Reformuler (BRANDING §8.4), « publications » (BRANDING §8.2) | libelles E3, E4 | XS | |

### Les deux

| # | Ce qui est faux | Correction | Réfs | Taille | Écran d'abord |
|---|---|---|---|---|---|
| D24 | « a publié un article », « Article publié » dans les notifications, « Publication » sur les cartes | « publication » partout (BRANDING §8.2 : « article » à ne pas écrire) | libelles 10.4 | XS | |
| D25 | « via l'étape J1, J3 » au singulier (app) ; « via les étapes : J1 » au pluriel (site) | Pluriel calé sur le nombre d'étapes, des deux côtés ; ramasser « Utilisée dans » → « Utilisé dans » (libelles 4.7) | libelles 4.6 ; données 5.8 | XS | |
| D26 | Prix : `fr-FR` imposé dans l'app et sur la carte du site, langue de l'interface au tableau de bord du site, trois formateurs côté site | Un seul formateur par support, qui suit la langue ; garder les 2 décimales de la carte | formats 5.1, S2 | S | |

---

## 2. Décisions

Quatorze règles. Chacune se lit seule.

### R1 — Badges d'état d'une carte : lesquels, dans quel ordre

- **Question** : quels badges d'état une carte porte-t-elle, et dans quel ordre ?
- **App** : Supprimé → type → Annulé / En cours / Terminée → J'y vais. Jamais « Publié » ni la visibilité (sauf
  sur le parcours). Annonce : type, « Brouillon ». Voyage passé : rien. Agenda passé : opacité.
- **Site** : fil et annonce : Supprimé → En cours → J'y vais → type → statut (« Publié » compris) → visibilité,
  toujours. Agenda, 7 jours, calendrier : statut si ≠ publié, visibilité si ≠ public. Pas de « Terminée ». Équipe :
  visibilité si privée seulement.
- **Cartes** : fil (sortie, voyage, publication), annonce, agenda, 7 jours, calendrier, parcours, équipe.
- **Options** :
  1. *(recommandée)* Supprimé → type → un état (Annulé, En cours, Terminée, Brouillon) → J'y vais. Jamais « Publié ».
     Visibilité seulement si elle n'est pas publique. Un badge signale une exception ; le site le fait déjà dans
     l'agenda (libelles S1). « Terminée » suit SYNTHESE §6.2.
  2. BRANDING §7.1 tel quel : statut et visibilité toujours. L'app s'aligne.
- **Maquette** : oui — sortie publiée, annulée, terminée, brouillon ; annonce ; équipe privée.
- **API** : non. L'option 1 modifie BRANDING §7.1.
- **Réfs** : libelles 1.1, 1.2, 1.3, S1 ; données 1.17, 6.5, 7.3 ; actions E1, E2, E5, INT-A7.

### R2 — Ligne météo d'une carte

- **Question** : que dit la ligne météo d'une carte, et sous quelle forme ?
- **App** : « 9–13 °C » · vent · « Pluie 20 % » toujours ; en alerte « Pluie 60 % vers 11:00 ». Avant ouverture :
  « Météo dès le 15 janvier ».
- **Site** : « 9 → 13 °C » · vent ; pluie seulement en alerte, « Averses dès 11:00 », probabilité en infobulle. Ligne
  de groupe : « Averses 60 % vers 11:00 » (le site se contredit). « Météo disponible à partir du 15 janvier 2026 ».
- **Cartes** : fil (sortie, voyage), Ma prochaine sortie, groupe, étape.
- **Options** :
  1. *(recommandée)* KIT §8 : plage « 9–13 °C » · vent (flèche) · « Pluie N % » toujours. Alerte « Pluie 60 % vers
     11:00 ». « Météo dès le {date} », année hors année courante. Règle déjà écrite pour les cartes de groupe et
     d'étape.
  2. Pluie seulement en alerte, condition nommée (« Averses vers 11:00 »), probabilité en infobulle sur le site.
- **Maquette** : oui — fil sortie sans pluie, pluie faible, alerte ; carte de groupe.
- **API** : non.
- **Réfs** : libelles 5.1, 5.2, 5.3, S2 ; données 10.1, 10.2 ; formats 2.1, 2.2, 2.3.

### R3 — Quelle distance montrer pour une sortie

- **Question** : quelle distance (et quel D+) une carte de sortie affiche-t-elle ?
- **App et site, même schéma** : fil, aucune ; Ma prochaine sortie, celle du groupe ; calendrier, celle du parcours
  de la sortie ; tableau de bord, celle de la sortie ou du premier groupe. Une même sortie montre jusqu'à trois
  distances.
- **Site en plus** : la vue téléphone du calendrier ne montre ni distance ni D+.
- **Cartes** : fil, Ma prochaine sortie, calendrier, 7 jours, tableau de bord.
- **Options** :
  1. *(recommandée)* L'API calcule une distance d'affichage par sortie et pour la personne qui lit : celle de son
     groupe si elle est inscrite, sinon celle du parcours commun, sinon rien. Même logique que l'heure (BRANDING §7.8)
     et que les permissions (`API-176`). METHODE étape 5 le propose déjà.
  2. Chaque client applique la même règle à partir des champs actuels.
  3. Aucune distance sur une carte de liste.
- **Maquette** : non, un tableau carte × cas suffit.
- **API** : oui (entrée `API-…`).
- **Réfs** : données A.1, S.1, 3.2.

### R4 — Compteurs d'une carte : lesquels, et à zéro

- **Question** : quels compteurs une carte porte-t-elle, et que faire d'un compteur à zéro ?
- **App** : zéros masqués (tableau de bord : « Aucun groupe »). Voyage : étapes · distance · D+ ; aucun nombre de
  personnes (vide pour un non-membre). Parcours : pas de commentaires.
- **Site** : zéros affichés (« 0 groupe », « 0 commentaire », « 0 étape »). Voyage : personnes · étapes ·
  commentaires ; pas de distance. Parcours : commentaires, 0 compris.
- **Cartes** : fil (sortie, voyage, publication), parcours, tableau de bord.
- **Options** :
  1. *(recommandée)* Zéros masqués partout. Voyage : étapes · distance · D+ · personnes, commentaires s'il y en a.
     Un zéro n'apprend rien sur une carte. Le nombre de personnes est permis aux non-membres (invariant : le compte
     seul, `API-144`).
  2. Zéros affichés partout ; voyage comme le site.
- **Maquette** : oui — carte de voyage (membre, non-membre) ; sortie sans commentaire.
- **API** : non (`TripDto.totalDistance` existe, `API-93`).
- **Réfs** : libelles 4.1, 4.2 ; données 1.4, 1.5, 1.8, 1.9, 5.2, 8.2 ; formats 6.1, 6.5 ; actions P13.

### R5 — Personnes inscrites sur une carte : avatars, compteur, jauge, « Voir tout »

- **Question** : comment une carte dit qui vient et combien de places restent ?
- **App** : avatars teintés par nom, soi en primaire. Groupe : « 11/12 personnes » ; complet, la grappe devient une
  barre rouge « 18/18 ». Ma prochaine sortie : « 11/12 » nu, grappe et jauge. Tableau de bord : « 11 / 16 ».
  « Voir tout » sur la carte sélectionnée seulement.
- **Site** : avatars tous en primaire (BRANDING §7.5). Groupe : « 11/12 personnes », grappe gardée, badge gris
  « Complet ». Ma prochaine sortie : « Groupe A · 11/12 personnes », ni grappe ni jauge. Fil : « 8/12 places ».
  « Voir tout » au-delà de 5 personnes. « Complet » gris, rouge ou texte selon la carte.
- **Cartes** : groupe, Ma prochaine sortie, fil, tableau de bord.
- **Options** :
  1. *(recommandée)* Une forme de compte, « 11/12 personnes » (« 12 personnes » sans maximum). Un seul « Complet »,
     grappe gardée. « Voir tout » dès que la grappe ne montre pas tout le monde. Avatars teintés par nom (KIT §8 les
     colore) ; BRANDING §7.5 à modifier.
  2. Garder la forme de chaque support, n'unifier que « Complet ».
- **Maquette** : oui — groupe ouvert, groupe complet, Ma prochaine sortie.
- **API** : non.
- **Réfs** : libelles 4.3 ; données 2.2, 4.4, A.3, S.3 ; actions P1, P5, P6, P8, INT-A2, INT-A3, INT-W4, INT-W5.

### R6 — Contrôles d'inscription : carte de groupe et « Ma prochaine sortie »

- **Question** : quels contrôles d'inscription une carte montre, sous quelle forme, et quand ?
- **App** (KIT §8, `MOB-134`) : ma carte : « J'y vais » en haut, lien « Quitter le groupe » en bas. « Complet »
  désactivé même si je suis ailleurs. Erreur en bandeau de section. Quitter permis après le départ sur le groupe,
  masqué sur Ma prochaine sortie. « Changer pour » plein sur la carte, contour sur la page de groupe.
- **Site** (BRANDING §7.7) : « Quitter » en contour dans le coin. « Complet » seulement si je ne suis nulle part.
  Erreur dans la carte. Quitter toujours permis. Ma prochaine sortie : « Se désinscrire » gris, en dernier.
- **Cartes** : groupe, Ma prochaine sortie.
- **Options** :
  1. *(recommandée)* KIT §8 sur les deux supports, comme le veut `WEB-165`. En plus : erreur dans la carte concernée,
     « Complet » visible même si je suis ailleurs, quitter permis jusqu'à « Terminé » (SYNTHESE §6.2) sur les deux
     cartes.
  2. Le site garde BRANDING §7.7 ; seul « Changer pour » est porté (D14).
- **Maquette** : oui — groupe : inscrite, inscrite ailleurs et complet, erreur ; boutons de Ma prochaine sortie.
- **API** : non.
- **Réfs** : libelles 3.2 ; actions I2, I5, I7, A6, A18, INT-A1, INT-A5.

### R7 — Export du parcours depuis une carte

- **Question** : depuis quelles cartes exporte-t-on un parcours, et par quel bouton ?
- **App** : « GPS » (feuille : appareil, GPX, FIT) sur la carte de son groupe seulement ; rien sur une étape ; Ma
  prochaine sortie : avant le départ seulement.
- **Site** : « GPX », « FIT », « Envoyer vers l'appareil » sur chaque groupe et chaque étape ; Ma prochaine sortie :
  aussi après le départ.
- **Cartes** : groupe, étape, Ma prochaine sortie.
- **Options** :
  1. *(recommandée)* KIT §8 et `MOB-134` : un seul bouton « GPS », sur la carte de son groupe. `WEB-165` le demande
     déjà au site. Reste ouvert : sur une étape, « GPS » si je participe au voyage ; masqué après le départ.
  2. Le site garde les fichiers sur toutes les cartes (téléchargement au bureau) ; l'app reste telle quelle.
- **Maquette** : oui — carte de groupe (le mien, un autre), carte d'étape.
- **API** : non.
- **Réfs** : libelles 6.1 ; données 4.9 ; actions A3, A4, A5.

### R8 — Confirmation avant de quitter ou de supprimer

- **Question** : quelles actions demandent une confirmation ?
- **App** : jamais pour quitter ou changer de groupe (décidé, `MOB-134`). Supprimer un commentaire : sans
  confirmation. Supprimer un modèle, délier un appareil : avec.
- **Site** : se désinscrire : confirmé sur Ma prochaine sortie, pas sur les cartes de groupe. Supprimer : toujours
  confirmé (`WEB-33`).
- **Cartes** : Ma prochaine sortie, groupe, commentaire.
- **Options** :
  1. *(recommandée)* Quitter et changer : jamais confirmés (action réversible, `MOB-134`). Supprimer : toujours
     confirmé (irréversible, `WEB-33`). Le site retire la confirmation de Ma prochaine sortie ; l'app confirme la
     suppression d'un commentaire.
  2. Confirmer aussi la désinscription, partout.
- **Maquette** : non.
- **API** : non.
- **Réfs** : libelles 3.8 ; actions I3, A15, INT-A9, INT-W1.

### R9 — Date et heure d'une carte, hors boîte du jour

- **Question** : comment une carte écrit une date qui n'est pas un départ, et l'heure d'un voyage ?
- **App** : publication et annonce « dimanche 8 novembre 2026 » (année toujours, sans heure). Membre « Membre depuis
  mars 2024 ». Relatif « il y a 2 heures », date absolue après 7 jours. Voyage « Départ 09:00 » puis la plage
  (`MOB-115`).
- **Site** : publication et annonce « dim. 8 nov. · 18:30 », année hors année courante. Membre « A rejoint le 3 mars
  2024 ». Relatif date-fns « il y a environ 2 heures », jamais de date absolue. Voyage : la plage seule.
- **Cartes** : publication, annonce, membre, notification, commentaire, appareil, tableau de bord, voyage.
- **Options** :
  1. *(recommandée)* Horodatage court au format `BRAND-8` (« dim. 8 nov. · 18:30 ») ; long, « 3 novembre 2026 »
     (KIT §8). Relatif de l'app, avec bascule à 7 jours. Voyage : « Départ 09:00 » et la plage (`MOB-115`).
  2. Date seule, sans heure, sur publication et annonce ; relatif sans bascule.
- **Maquette** : non (texte).
- **API** : non.
- **Réfs** : libelles 10.1 ; données 1.6 ; formats 3.3, 3.4, 3.6, 3.13, 4.1, 4.2, A4.

### R10 — Image d'en-tête et repère visuel d'une carte

- **Question** : quelle image ouvre une carte, et que montrer sans image ?
- **App** : sortie et voyage : carte du tracé en bandeau, répétée en vignette (sortie seulement). Parcours sans
  vignette : dégradé et icône. Équipe : pas de bandeau, ou dégradé. Étape : repère de couleur du tracé.
- **Site** (BRANDING §7.1, §7.6) : photo, sinon dégradé (presque toujours en vue compacte), carte du tracé en vignette
  à droite (voyage compris). Parcours sans vignette : rien. Équipe : première photo, sinon dégradé. Étape : numéro ou
  logo.
- **Cartes** : fil (sortie, voyage), parcours, équipe, étape.
- **Options** :
  1. *(recommandée)* Bandeau : photo si elle existe, sinon la carte du tracé, sinon dégradé ; pas de vignette quand le
     bandeau est déjà la carte. Étape : la couleur du tracé (KIT §8 : « la couleur est sur chaque carte d'étape »).
  2. BRANDING §7.1 tel quel ; l'app passe à la photo ou au dégradé.
  3. L'app telle quelle ; le site passe à la carte du tracé.
- **Maquette** : oui — sortie avec et sans photo, voyage, parcours sans vignette, équipe, étape.
- **API** : peut-être : la vue compacte ne porte pas la première photo.
- **Réfs** : données 1.1, 1.2, 1.3, 4.10, 5.3, 7.1.

### R11 — Lieu de départ et groupe sur une carte : où, dans quel ordre

- **Question** : quelles cartes nomment le lieu et le groupe, dans quel ordre, et avec ou sans adresse ?
- **App** : Ma prochaine sortie : groupe sur sa ligne, lieu avec son adresse. Calendrier : « heure · Équipe · Lieu »,
  groupe dans le badge. Étape : aucun lieu. Fil : aucun lieu.
- **Site** : Ma prochaine sortie : lieu sans adresse, « Groupe A · 11/12 personnes ». Calendrier : « Équipe · Heure ·
  Lieu ». 7 jours : « Heure · Équipe · Groupe ». Lignes d'agenda : lieu. Étape : départ et arrivée.
- **Cartes** : Ma prochaine sortie, 7 jours, calendrier, agenda d'équipe, étape.
- **Options** :
  1. *(recommandée)* Une ligne « Heure · Équipe · Groupe · Lieu » partout où elle existe ; le lieu sans adresse
     (`MOB-136`, décidé pour les écrans de détail). La carte d'étape nomme départ → arrivée : ce sont eux qui
     distinguent les étapes.
  2. Garder l'ordre de chaque surface ; n'ajouter que les lieux de l'étape.
- **Maquette** : oui — Ma prochaine sortie (ordre des blocs), ligne des 7 jours, calendrier, étape.
- **API** : non.
- **Réfs** : données 2.4, 2.5, 3.1, 3.7, 4.8, A.4, S.2.

### R12 — Texte et champs propres à une carte d'équipe, de parcours, de modèle, de commentaire

- **Question** : quel texte libre et quels champs ces cartes portent-elles, et le Markdown est-il rendu ?
- **App** : parcours sans extrait. Trois cartes d'équipe aux champs différents ; la découverte badge « Membre » quel
  que soit le rôle. Modèle : nom, statut, « prochaine sortie n° 42 ». Commentaire rendu en Markdown.
- **Site** : parcours avec extrait (BRANDING §7.2). Équipe : aperçu de description, rôle. Modèle : description,
  visibilité, groupes avec allure, tags. Commentaire en texte brut (`**gras**` reste visible).
- **Cartes** : parcours, équipe (liste, découverte, accueil), modèle de sortie, commentaire.
- **Options** :
  1. *(recommandée)* Extrait sur 2 lignes sur parcours et équipe (BRANDING §7.2). Une seule carte d'équipe dans
     l'app, avec le rôle. Modèle : nom · groupes · prochaine n°, la description en option. Commentaire : Markdown des
     deux côtés si la saisie le propose (à vérifier).
  2. Chaque support garde ses champs ; seul le commentaire est aligné.
- **Maquette** : oui — équipe, modèle.
- **API** : non.
- **Réfs** : libelles A1 ; données 5.1, 7.2, 8.11, 9.3, 9.5, A.8.

### R13 — Actions d'une carte au-delà de l'ouvrir

- **Question** : quelles actions une carte de liste offre-t-elle, en plus de mener à sa page ?
- **App** : rejoindre une équipe depuis sa carte (découverte). « Créer une sortie depuis ce modèle » dans le ⋯ du
  modèle. Signaler ou bloquer depuis la ligne d'un membre ou d'une personne inscrite.
- **Site** : rien sur la carte d'équipe (on rejoint depuis la page). Modèle : modifier, supprimer ; pas de « Créer une
  sortie ». Ligne de membre : rôle et retrait, ni signalement ni blocage.
- **Cartes** : équipe, modèle de sortie, membre, personne inscrite.
- **Options** :
  1. *(recommandée)* Les trois actions de l'app aussi sur le site : rejoindre depuis la carte, créer depuis un modèle,
     signaler ou bloquer depuis un menu de ligne. Ce sont des actions de participation, pas d'édition.
  2. Cartes du site passives : l'action se fait sur la page.
- **Maquette** : oui — carte d'équipe.
- **API** : non.
- **Réfs** : actions A11, A13 (partie site), A14, A16.

### R14 — Vocabulaire commun

- **Question** : pour chaque paire, quel mot garder ? Le résultat va dans BRANDING §8.4.
- **Paires** :

  | Sujet | App | Site | Recommandé | Réfs |
  |---|---|---|---|---|
  | Visibilité « équipe » | « Équipe » | « Équipe uniquement » | « Équipe uniquement » (dit la restriction) | libelles 2.2 |
  | Inscription (notification) | « a rejoint une sortie » | « a rejoint votre sortie » | « a rejoint votre sortie » | libelles 7.2 |
  | Sortie modifiée (notification) | le titre dit ce qui change | titre générique, détail dessous | celui de l'app | libelles 7.4 ; données 9.1 |
  | Webhook | « Actif/Inactif » + dernier envoi ; « Envoyé » ; « générique » | un badge « Désactivé/Échec/Actif » ; « Réussi » ; « JSON » | un badge ; « Réussi » ; « JSON » | libelles 8.1–8.3 ; données 8.9 |

  Les autres paires sont dans leur règle : « Météo dès le » (R2), « Quitter » (R6), « GPS » (R7), « Membre depuis »
  (R9).
- **Maquette** : non. **API** : non.

---

## 3. Écarts voulus

À écrire dans « Délibérément dehors » de `LEDGER_NEXT.md` quand une source manque.

| # | Écart | Raison | Source | Réfs |
|---|---|---|---|---|
| V1 | Menu ⋯ (Modifier, Publier, Supprimer, Ajouter au calendrier) sur les cartes de liste du site, absent de l'app | L'app n'édite ni publications ni voyages ; ses actions sont sur la page de détail (« Ajouter à mon calendrier » sur le voyage, `trip_detail_page.dart:223`). Le site ne pose ce menu que sur les listes d'équipe | `MOB-24`, `WEB-33` | actions A1, A2 |
| V2 | Pas de jauge de places sur la carte de sortie du fil de l'app | La jauge est sur Ma prochaine sortie, qui connaît le groupe | commentaire `publication_card.dart:295-299` ; METHODE. **Pas encore au ledger** | actions P4 ; données 1.10 ; formats 6.2 |
| V3 | Changer le rôle ou retirer un membre : site seulement | Administration d'équipe hors app | `MOB-24` | actions A13 (partie app) |
| V4 | Toutes les personnes d'une sortie : feuille dans l'app, liste en ligne sur le site | Écran étroit | `MOB-134` (`ParticipantsSheet`) | actions P7 |
| V5 | Mention de fuseau : ligne visible dans l'app, infobulle sur le site | Pas de survol au doigt ; BRANDING §8.3 fixe le texte, pas la forme. La date d'une publication relève de R9 | BRANDING §8.3. **Pas au ledger** | formats 3.9 |
| V6 | « Annulé » sur Ma prochaine sortie : badge dans l'app, rien sur le site | Sans effet : les deux requêtes ne demandent que les sorties publiées. Le badge de l'app est du code mort | `next_ride_provider.dart:47`, `nextRideParams.ts:16` | libelles 1.4 ; données 2.1 |
| V7 | Lignes d'agenda du site (`AgendaRow`) sans équivalent dans l'app | L'app n'a pas de vue en lignes. Ce qui s'y voit (lieu, visibilité, « 0 groupe ») est traité par R11, R1, R4 | — **Pas au ledger** | données 3.7 |

---

## 4. Écarts faibles, par carte

Pas triés un par un. Un lot qui touche la carte les ramasse. Compte par fichier d'audit.

| Carte | libelles | donnees | formats | actions | Total |
|---|---|---|---|---|---|
| Fil (sortie, voyage, publication, météo) | 5 | 7 | 3 | 0 | 15 |
| Ma prochaine sortie | 3 | 4 | 0 | 1 | 8 |
| 7 prochains jours | 4 | 2 | 0 | 1 | 7 |
| Agenda, calendrier, abonnement | 2 | 1 | 1 | 3 | 7 |
| Groupe et étape | 5 | 6 | 4 | 11 | 26 |
| Parcours, « Utilisée dans » | 1 | 4 | 0 | 0 | 5 |
| Annonce | 0 | 5 | 1 | 0 | 6 |
| Équipe, Mes équipes, invitations | 4 | 2 | 0 | 1 | 7 |
| Membre | 2 | 2 | 1 | 0 | 5 |
| Personne inscrite | 4 | 1 | 0 | 3 | 8 |
| Tableau de bord | 7 | 7 | 4 | 4 | 22 |
| Notification | 3 | 0 | 1 | 1 | 5 |
| Modèle de sortie | 1 | 0 | 0 | 0 | 1 |
| Appareil appairé | 3 | 0 | 1 | 1 | 5 |
| Commentaire | 1 | 2 | 0 | 0 | 3 |
| Toutes cartes (ponctuation, coche « J'y vais », zone cliquable…) | 4 | 1 | 5 | 6 | 16 |
| Hors cartes (détail, aperçus de lien) | 0 | 0 | 4 | 0 | 4 |

Deux faibles sont remontés : l'épingle d'annonce (D11) et « Soyez certain » (D23). Pour « … » contre « ... »
(libelles 9.2) : BRANDING §8.3 donne lui-même « Adhésion... » en exemple, la règle est à fixer avant d'y toucher.

---

## 5. À vérifier à l'écran avant toute correction

| Constat déduit | Réfs | Ce qu'il faut voir |
|---|---|---|
| « 1 membres » dans l'app | libelles 4.5 ; formats 6.6 | une équipe d'un membre (D3) |
| « 0 groupe », « 0 commentaire » sur le site | libelles 4.1 | une sortie sans groupe ni commentaire (R4) |
| Dates anglaises « Monday 15 january 2026 » | formats A1 | l'app en anglais (D6) |
| « il y a environ 2 heures », « November 3rd, 2026 » (date-fns) | formats 4.1, S6 | le site en français et en anglais (R9) |
| Bandeau du site presque toujours un dégradé en vue compacte | données 1.1 | le fil du site sur de vraies sorties (R10) |
| `thumbnailLightUrl` de `RideDto` est la carte du tracé | données 1.1 | idem |
| `TeamCard` du site sans description en vue compacte | données 7.2 | la liste des équipes du site (D21) |
| Météo d'une sortie passée encore envoyée par le serveur | données 1.15, 2.8 | une sortie d'hier, sur les deux supports |
| Le serveur accepte-t-il de quitter une sortie annulée ? | actions I4 | appel `leave` sur une sortie annulée (D15) |
| `switchGroup` présent dans le client généré du site | actions I1 | `frontend/src/api` (D14) |
| `canRegister` d'un groupe déjà parti | actions I6 | une sortie à départs décalés |
| « Créer une sortie depuis un modèle » ailleurs sur le site | actions A16 | le formulaire de création (R13) |
| Les 7 jours de l'app excluent les événements terminés | actions, Non vérifié | `weekEventsProvider` |
| Pastille « non lue » de l'app sans libellé de lecteur d'écran | libelles 7.5 ; actions E11 | VoiceOver ou TalkBack |
| Sortie solo de l'app : lieux du groupe ou de la sortie | données 4.13 | une sortie à un seul groupe |
| Commentaires : la saisie propose-t-elle le Markdown ? | données 9.5 | le champ de saisie, deux supports (R12) |
| « Jauge du site réduite à zéro pixel » | METHODE, Limites | absent des quatre audits : retrouver la source avant de l'inscrire |

---

## 6. Récapitulatif

| | XS | S | M | Total |
|---|---|---|---|---|
| Défauts app | 9 | 3 | 0 | 12 |
| Défauts site | 9 | 1 | 1 | 11 |
| Défauts des deux | 2 | 1 | 0 | 3 |
| **Défauts** | **20** | **5** | **1** | **26** |

| | Nombre |
|---|---|
| Règles à décider | 14 (10 avec maquette ; R3 touche l'API, R10 peut-être) |
| Écarts voulus | 7 (V2, V5, V7 sans entrée au ledger : à écrire dans « Délibérément dehors ») |

**Découpage proposé du lot 0** :

| Sous-lot | Défauts | Nature |
|---|---|---|
| 0a — Mots et pluriels | D3, D4, D5, D12, D23, D24, D25 | Clés des deux fichiers de traduction ; XS, sans risque |
| 0b — États, badges et actions | D1, D2, D8, D9, D10, D11, D14, D15, D18, D19, D20, D21, D22 | Rendu des cartes ; D14 (« Changer pour » sur le site, M) peut partir seul sous `WEB-165` |
| 0c — Formats à la source | D6, D7, D13, D16, D17, D26 | Formateurs des deux supports, avec le jeu de cas partagé dans `contracts/` (METHODE étape 5) |
