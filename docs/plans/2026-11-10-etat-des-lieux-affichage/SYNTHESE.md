# État des lieux de l'affichage — web ↔ mobile (2026-11-10)

Synthèse de 12 rapports produits par lecture du code (branche `feat/mobile-review`, `ef1fc9a99`).
**Rien n'a été rendu** : ni navigateur, ni simulateur. Les ordres de blocs et formats viennent du code ;
les problèmes de recouvrement signalés sur le mobile sont déduits de la mise en page et restent à confirmer à l'écran.

Rapports détaillés (ordre des blocs avec `fichier:ligne`, variantes, tableau des dates, wireframes ASCII, étonnements) :

| Écran | Web | Mobile |
|---|---|---|
| Sortie | `web-ride.md` | `mobile-ride.md` |
| Groupe | `web-group.md` | `mobile-group.md` |
| Voyage | `web-trip.md` | `mobile-trip.md` |
| Étape | `web-stage.md` | `mobile-stage.md` |
| Parcours | `web-route.md` | `mobile-route.md` |
| Dates/heures (transversal) | `web-dates.md` | `mobile-dates.md` |

---

## 1. Le modèle web de référence

Sortie, groupe, voyage et étape suivent le même gabarit :

1. Fil d'Ariane / lien retour, bandeau d'équipe.
2. **En-tête** : titre, badges, actions, **bloc Départ** (boîte du jour, « Départ 09:00 », pastille Aujourd'hui/Demain,
   mention de fuseau, lieu), lieux, faits.
3. **Grille ≥ 1024 px (64em)** : colonne de 380–440 px à gauche (consignes, groupes/étapes/stats, personnes inscrites),
   **carte sticky à droite**, profil altimétrique posé sur la carte, interrupteur Pente | Revêtement | Météo.
4. **« Météo du parcours » en pleine largeur**, sous la grille (4 verdicts, tableau heure par heure).
5. Alertes d'accès, commentaires.

**Sous 1024 px : une seule colonne, la carte passe en premier** (juste après l'en-tête), non sticky.
C'est cette disposition étroite qui sert de cible au mobile.

Groupe et étape partagent un composant : `components/publication/ChildDetailShell.tsx`
(+ `SiblingNav`, `RouteCard`, `PlacesLine`, `StatsCard`, `DepartureBlock`, `RouteMapPanel`, `RouteWeatherSection`).

Le **parcours** fait exception : une seule colonne à toutes les largeurs (`RouteDetailView`, utilisé par cette seule page).

## 2. Comparaison écran par écran

### Sortie

| | Web (étroit) | Mobile |
|---|---|---|
| Ordre | en-tête + bloc Départ → **carte** → colonne (consignes, groupes ou panneau solo, personnes) → météo → commentaires | app bar → identité → bloc Départ → bandeaux → bloc méta → **météo** → **carte + profil (6ᵉ bloc)** → groupes → description → commentaires |
| Carte | 1ᵉʳ bloc après l'en-tête | 6ᵉ bloc ; 44 % de l'écran, bornée 260–460 px |
| Sans groupe | « Groupes » état vide, « Météo au départ » + tronçon ; carte « Parcours principal » | état vide « Aucun groupe » ; carte seulement si parcours, titrée « Parcours des groupes » |
| Solo (1 groupe) | panneau du groupe → chiffres (tuile Départ) → personnes ; **« Météo du parcours » après la carte**, pleine largeur ; pas de « Météo au départ » | météo du parcours **au-dessus** de la carte ; inscription dans une barre fixe en bas |
| N groupes, même heure | cartes de groupe (le sien en tête, « Autres groupes ») → personnes → « Météo au départ » ; carte multi-tracés sans mode Météo | météo limitée au départ ; cartes sans heure, 4 max puis « Voir les N autres groupes » |
| N groupes, heures ≠ | toutes les cartes portent « Départ 09:30 » ; bloc Départ + « Votre groupe · B · 09:30 » si inscrit dans un groupe à heure propre | idem : toutes les cartes « Départ hh:mm » ; « Votre groupe : B · 09:30 » |

Écart principal : **le mobile n'a pas suivi `b76185166`** (météo du parcours après la carte, sortie solo). Carte trop basse.

### Groupe

| | Web (étroit) | Mobile |
|---|---|---|
| Existence | seulement si ≥ 2 groupes (sinon redirection vers la sortie) | idem (`leavesGroupPage`) |
| Navigation | sélecteur de groupes (segmenté ≤ 4, liste au-delà) | pastilles de groupes + **onglets** Aperçu / Météo, épinglés |
| Ordre | en-tête + bloc Départ + arrivée + places → **carte** → stats, capitaine, personnes, carte parcours → « Météo du parcours » | bloc Départ → **carte (2ᵉ)** → interrupteur, profil 110 px, chiffres, capitaine, résumé météo, personnes, export ; barre d'inscription fixe |
| Météo | section pleine largeur en bas de page | onglet séparé, carte en tête en mode Météo imposé |
| Lieu de RDV | texte dans le bloc Départ | **aucun texte**, un pin sur la carte seulement |

Écran mobile le plus proche de la cible. Écarts : météo en onglet plutôt qu'en section, lieu de RDV absent.

### Voyage

| | Web (étroit) | Mobile |
|---|---|---|
| Ordre | en-tête (bloc Départ, plage, chiffres) → **carte** → consignes, étapes, personnes → météo (1 étape seulement) → commentaires | app bar → identité → bandeaux → synthèse (Durée, Étapes, Distance, D+, participants) → **carte (3ᵉ–5ᵉ)** → profil global 110 px → étapes → description → pièces jointes → personnes → commentaires ; barre fixe |
| Carte | sélecteur « Étapes \| Météo » | 280 px, même sélecteur, légende des étapes |
| Voyage d'1 étape | disposition dédiée (`ef1fc9a99`) : « Météo du parcours » pleine largeur avant les commentaires | **aucune disposition dédiée** (seule la légende est masquée) |
| Sans parcours | colonne carte gardée, « Aucun parcours disponible » | carte absente |
| Voyage avec `routeSlug` propre, sans étape | carte du parcours du voyage | **ni carte ni profil** |

### Étape

| | Web (étroit) | Mobile |
|---|---|---|
| Structure | `ChildDetailShell`, comme le groupe | **pas de page commune** : `EmbeddedRouteSheet` (fiche parcours embarquée), sans rapport avec l'écran de groupe |
| Navigation | `SiblingNav` (flèches, Select au-delà de 4) | rail d'étapes épinglé, pas de précédent/suivant |
| Ordre | en-tête + bloc Départ + lieux → **carte** → stats, consignes, RouteCard → « Météo du parcours » → commentaires | app bar → rail → identité → bloc Départ → lieux → en-tête du parcours → **carte 240 px (tard)** → interrupteur → profil 140 px → revêtement → waypoints → exports → carte météo → cols → description → commentaires |
| Météo | section pleine largeur | carte résumé → **page poussée sans URL** (`StageWeatherPage`), sans carte |
| Arrivée estimée | affichée (deux fois) | **absente** |

Écran mobile le plus éloigné : structure différente du groupe, carte tardive, météo dans une page à part.
Tailles incohérentes entre groupe et étape mobiles : carte 44 % (260–460) vs 240 px ; profil 110 vs 140 px.

### Parcours

| | Web | Mobile |
|---|---|---|
| Structure | une colonne : titre, description, actions → **carte + profil 160 px** → Pente \| Revêtement → téléchargements → stats, badges, « Créé le » → tags → points → cols → commentaires → « Utilisée dans » | **carte plein écran en fond** + feuille à crans (0.18 / 0.5 / 0.92) : tags, interrupteur, profil 140 px, revêtement, points, cols, « Utilisée dans », Informations, description, pièces jointes ; pied fixe GPX/FIT/appareil/partager |
| Météo | aucune | aucune (`wind: false`) |
| Commentaires | oui, pour les membres | **absents** (le DTO porte `commentCount`) |

Carte déjà « au plus tôt » sur mobile. Écart : commentaires.

## 3. Dates et heures

### Ce qui est déjà aligné

- **Modèle** : instant UTC + `timezone` IANA de l'entité. Pas d'heure de RDV distincte : `dateTime` est le départ ;
  `RideGroupDto.startAt` est le départ du groupe (`time` déprécié).
- **Règle** : un rendez-vous se lit dans le fuseau de l'entité (web `useRendezvousFormat`, mobile `toZoneTime`) ;
  un horodatage dans celui du lecteur (web `useFormattedDate`, mobile `toDisplayTime`).
- **Format de départ** : « sam. 12 avr. · 09:00 », année seulement hors année en cours.
- **Relatifs** : « Aujourd'hui » et « Demain » seulement, jugés dans le fuseau de l'entité.
- **Mention de fuseau** : « heure de Tokyo (ven. 01:00 chez vous) », si les décalages diffèrent.
- **Plage de voyage** : « ven. 16 → dim. 18 oct. », fin lue dans le fuseau de la dernière étape (`endDateTime`).

### Écarts mobile ↔ web

| Donnée | Web | Mobile |
|---|---|---|
| 12 h / 24 h | selon la langue (fr 24 h, en 12 h) | selon le téléphone — sans effet en français (`jm()` = `HH:mm`) |
| Horodatage long (« Créé le ») | « 15 juin 2025 » (`PPP`) | « dimanche 15 juin 2025 » |
| Date d'un post | « sam. 12 avr. · 09:00 » | date longue sans heure, trois formats selon l'écran |
| Commentaires | relatif sans seuil (« il y a environ 2 heures ») | relatif, puis date longue après 7 jours |
| Cartes de groupe / d'étape | « Demain · 22:30 » | jamais de relatif |
| Usages d'un voyage (parcours) | « ven. 16 oct. → dim. 18 oct. » (écart interne au web) | « ven. 16 → dim. 18 oct. » |
| Bloc Départ d'une sortie | boîte du jour + « Départ 09:00 » | idem, mais aucune date en clair (« sam. 15 nov. » réservé au lecteur d'écran) |
| Bloc Départ d'une étape | comme la sortie | répète la date déjà dans la boîte du jour ; date visible trois fois en haut d'écran |

### Incohérences à trancher avant d'aligner (présentes des deux côtés ou dans le web lui-même)

- **Heure de la sortie vs heure du groupe** : l'en-tête lit `ride.dateTime`, la tuile/section du groupe lit `group.startAt`.
  En solo, les deux peuvent se contredire (web et mobile). Sur mobile, la « météo au départ » de l'onglet Météo prend
  l'heure de la sortie alors que l'Aperçu prend celle du groupe.
- **Lever / coucher du soleil** : fuseau du lecteur dans `DepartureWeather.tsx:89,94`, fuseau de l'entité dans `RouteVerdicts.tsx:225`.
- **`endDateTime` d'une sortie** n'est affiché nulle part ; sur le voyage mobile, la « Durée » (`endDate`) et la plage (`endDateTime`) peuvent diverger.
- **« Terminé » arrive trop tôt** : dès l'heure de départ (sortie) ou le départ de la dernière étape (voyage). Aucun état « En cours » ;
  la météo et « Rejoindre » disparaissent pendant que ça roule. Le mobile laisse à l'inverse « Rejoindre » et « N places restantes ».
- **Web, formats hors système** : `RouteUsages.tsx:118`, `ContentLists.tsx:58`, `config/routeMeta.ts` (`Intl` en-GB), `MemberHome.tsx:41`.
- **Mobile, formats hors système** : `team_members_page.dart:364`, `publication_timing.dart:70` ; `formatFullDate` sans année,
  `formatLongDate` toujours avec ; ordre jour-mois français imposé en anglais.

## 4. Doublons et défauts relevés au passage

- **Compte de personnes affiché trois fois** (sortie web, groupe web, groupe mobile) ; distance et D+ deux fois (voyage et groupe mobiles).
- **Arrivée estimée en double** sur le web (StatsCard + verdict), perdue dans StatsCard quand il n'y a pas d'allure.
- **Annulation / fin non signalées** sur les pages groupe et étape (web et mobile) : la météo disparaît sans explication.
- **Nombres non localisés sur le web** : « 245.3 km », « 6.2% », « 3120 m » ; axes du profil en anglais en dur.
- **Mobile parcours** (à confirmer à l'écran) : barre d'échelle et crédit cachés par la feuille ; bouton « Fond de carte » à moitié recouvert au cran 0.5 ;
  pied fixe chevauchant les stats au cran 0.18.
- **Mobile étape** : retour = `go(trip)` mais geste système = `pop` ; deux boutons de partage ; deux messages « pas de parcours » pour un organisateur.
- **Mobile groupe / voyage** : la barre d'action propose « Rejoindre » pendant que l'appartenance est inconnue (`isMember == null`).
- **Web parcours** : le créateur simple membre ne peut ni modifier ni supprimer son parcours.

## 5. Ce que l'alignement mobile implique, par ordre d'écart

1. **Étape** : la rebâtir sur la structure du groupe (comme `ChildDetailShell` côté web) — carte en tête, météo en section, arrivée estimée.
2. **Sortie** : remonter la carte juste après le bloc Départ ; en solo, « Météo du parcours » après la carte.
3. **Voyage** : remonter la carte avant la synthèse ; disposition dédiée au voyage d'une étape ; carte pour un voyage à parcours propre.
4. **Groupe** : lieu de RDV en texte ; décider si la météo reste un onglet ou devient une section.
5. **Parcours** : commentaires ; corriger les recouvrements de la feuille.
6. **Dates** : aligner les cinq formats du tableau ci-dessus, après avoir tranché heure de sortie vs heure de groupe.

## 6. Décisions prises (2026-11-10)

1. **Sortie à un seul groupe** : l'en-tête affiche l'heure du groupe (`group.startAt`), une seule heure sur tout l'écran.
2. **État « En cours »** : entre le départ et l'arrivée estimée, badge « En cours », météo conservée, « Rejoindre » masqué ; « Terminé » seulement après l'arrivée.
3. **Groupe mobile** : plus d'onglets ; une page qui défile, carte en haut, « Météo du parcours » en section, comme le web. Même structure pour l'étape.
4. **Maquettes `/design`** : tout — mobile, web étroit et web desktop à deux colonnes.
5. **« En cours » sans arrivée estimée** (groupe sans allure) : jusqu'à la fin du jour de départ, dans le fuseau de la sortie.
6. **Lever et coucher du soleil** : fuseau de la sortie partout.
7. **12 h / 24 h** : la langue décide, sur le web comme sur le mobile (français 24 h, anglais 12 h).
8. **Commentaires sur le parcours mobile** : à ajouter, comme sur le web.
