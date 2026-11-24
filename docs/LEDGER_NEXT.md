# La suite : ce qui reste à faire

<!-- Généré par `node scripts/ledger.mjs index` à partir de docs/ledger/ : ne pas modifier à la main. -->

Index des **165 entrées ouvertes** et des 77 entrées écartées. Chaque entrée a son fichier
dans [`ledger/`](ledger/) ; le format, les gestes et la nomenclature sont dans
[`ledger/README.md`](ledger/README.md). Ce qui est livré : [`LEDGER_DONE.md`](LEDGER_DONE.md).

47 de ces entrées ne se ferment pas par du code (*recette*, *externe*, *decision*) : elles sont
reprises [en fin de fichier](#ce-qui-ne-se-ferme-pas-par-du-code).

## MOB — Application mobile

Contexte du domaine : [`ledger/MOB/README.md`](ledger/MOB/README.md).

- [ ] [`MOB-181`](ledger/MOB/MOB-181.md) Passer à maplibre 0.4 (moteur natif unique) (M) · *recette*
- [ ] [`MOB-178`](ledger/MOB/MOB-178.md) Les outils GPX dans l'app : recette sur appareil (L) · *recette*
- [ ] [`MOB-175`](ledger/MOB/MOB-175.md) Recette sur Pixel de la 1.2.0 : défauts d'affichage des pages groupe, équipe et carte (S)
- [ ] [`MOB-174`](ledger/MOB/MOB-174.md) `maplibre_ios` appelle `setState` sur une carte déjà démontée (S) · *recette*
- [ ] [`MOB-170`](ledger/MOB/MOB-170.md) Tracer et modifier un parcours sur la carte dans l'app : recette sur appareil (S) · *recette*
- [ ] [`MOB-161`](ledger/MOB/MOB-161.md) Éditeur riche : insérer un tableau et en ajouter ou retirer lignes et colonnes (S)
- [ ] [`MOB-160`](ledger/MOB/MOB-160.md) Éditeur riche : test de widget du pont et test Patrol de l'écran plein (S)
- [ ] [`MOB-154`](ledger/MOB/MOB-154.md) Générer un parcours depuis l'app (M, plus tard)
- [ ] [`MOB-149`](ledger/MOB/MOB-149.md) Basculer l'app sur `material_ui` / `cupertino_ui` quand les dépendances y seront (M)
- [ ] [`MOB-146`](ledger/MOB/MOB-146.md) Listes homogènes : recette sur appareil de `MOB-143` (S) · *recette*
- [ ] [`MOB-141`](ledger/MOB/MOB-141.md) Cartes homogènes : recette sur appareil de `MOB-139` (S) · *recette*
- [ ] [`MOB-135`](ledger/MOB/MOB-135.md) Refonte des écrans de détail : recette sur appareil de `MOB-134` (S) · *recette*
- [ ] [`MOB-130`](ledger/MOB/MOB-130.md) Contrôles de carte : recette sur appareil de `MOB-129` (S) · *recette*
- [ ] [`MOB-95`](ledger/MOB/MOB-95.md) La météo sur la carte : recette sur appareil des paliers 1 à 3 (S) · *recette*
- [ ] [`MOB-86`](ledger/MOB/MOB-86.md) Points de parcours : recette sur appareil · *recette*

### APK hors Play

- [ ] [`MOB-73`](ledger/MOB/MOB-73.md) Vérifier l'APK sur un Android sans Google Play Services · *recette*

### Couverture e2e Patrol — ce que les tests ne couvrent pas encore

- [ ] [`MOB-163`](ledger/MOB/MOB-163.md) Éditeur de voyage : recette sur appareil, test Patrol et restes (S)
- [ ] [`MOB-159`](ledger/MOB/MOB-159.md) Éditeur d'annonce : déclarer l'adresse sur les deux stores, recette sur appareil et test Patrol (S)
- [ ] [`MOB-157`](ledger/MOB/MOB-157.md) Éditeur de publication : recette sur appareil et test Patrol (S)
- [ ] [`MOB-77`](ledger/MOB/MOB-77.md) Éditeur de sortie, modèles et parcours : recette sur appareil (S) · *recette*
- [ ] [`MOB-62`](ledger/MOB/MOB-62.md) Profil refondu (`MOB-48`, `WEB-57`) : finitions (S)
- [ ] [`MOB-37`](ledger/MOB/MOB-37.md) Les tests Patrol ne tournent qu'en local
- [ ] [`MOB-26`](ledger/MOB/MOB-26.md) Clés d'accès

### En-têtes de pages : audit du 25 novembre 2026

- [ ] [`MOB-184`](ledger/MOB/MOB-184.md) « GPS » dans l'en-tête d'une sortie sur l'app, comme sur le site (S)

### Fiches des stores

- [ ] [`MOB-64`](ledger/MOB/MOB-64.md) Publier Pédalons sur Google Play (S) · *externe*

### Recette sur une application qui tourne

- [ ] [`MOB-52`](ledger/MOB/MOB-52.md) Météo : recette sur appareil de ce que `MOB-68` ne couvre pas (S) · *recette*
- [ ] [`MOB-47`](ledger/MOB/MOB-47.md) Contact du vendeur : l'échec d'envoi (500) de bout en bout
- [ ] [`MOB-20`](ledger/MOB/MOB-20.md) Performance
- [ ] [`MOB-15`](ledger/MOB/MOB-15.md) Profil (33) · *recette*
- [ ] [`MOB-13`](ledger/MOB/MOB-13.md) Trombinoscope (34) · *recette*
- [ ] [`MOB-5`](ledger/MOB/MOB-5.md) Exploration de parcours (21) · *recette*

## WEB — Site web

Contexte du domaine : [`ledger/WEB/README.md`](ledger/WEB/README.md).

- [ ] [`WEB-203`](ledger/WEB/WEB-203.md) « GPS » dans la barre d'actions des pages parcours, sortie, groupe et étape (S) · *recette*
- [ ] [`WEB-201`](ledger/WEB/WEB-201.md) Retoucher un parcours sur le site : ajuster la distance, déplacer l'arrivée (M)
- [ ] [`WEB-199`](ledger/WEB/WEB-199.md) La souris déplace les ancres d'un tracé au lieu d'ajouter un point à côté (S) · *recette*
- [ ] [`WEB-198`](ledger/WEB/WEB-198.md) Recette du choix du calcul d'itinéraire dans le planificateur (S)
- [ ] [`WEB-183`](ledger/WEB/WEB-183.md) Planificateur embarquable dans l'app : recette iOS et poids du bundle (S)
- [ ] [`WEB-176`](ledger/WEB/WEB-176.md) Listes homogènes : recette en navigateur de `WEB-175` (S) · *recette*
- [ ] [`WEB-172`](ledger/WEB/WEB-172.md) Cartes homogènes : recette en navigateur de `WEB-167` (S) · *recette*
- [ ] [`WEB-170`](ledger/WEB/WEB-170.md) Servir la police Inter sur le site (S à M)
- [ ] [`WEB-161`](ledger/WEB/WEB-161.md) Contrôles de carte : recette à l'œil de `WEB-157` (S) · *recette*
- [ ] [`WEB-133`](ledger/WEB/WEB-133.md) La météo des aperçus GPX : recette navigateur (S) · *recette*
- [ ] [`WEB-119`](ledger/WEB/WEB-119.md) La météo sur la carte : recette navigateur des paliers 1 à 3 (S) · *recette*
- [ ] [`WEB-100`](ledger/WEB/WEB-100.md) Éditeur de parcours web, desktop et web mobile (L, en quatre lots)
- [ ] [`WEB-96`](ledger/WEB/WEB-96.md) La carte s'initialise au chargement et bloque le fil principal (S)
- [ ] [`WEB-61`](ledger/WEB/WEB-61.md) Météo des sorties : recette navigateur de ce que `WEB-94` n'a pas vu (S) · *recette*
- [ ] [`WEB-56`](ledger/WEB/WEB-56.md) Profil refondu (`WEB-55`, `WEB-57`) : recette navigateur (S) · *recette*
- [ ] [`WEB-36`](ledger/WEB/WEB-36.md) Un tap juste après l'affichage d'une page, sous charge, est ignoré (M)

### Couverture e2e — ce que l'audit du 27 septembre laisse ouvert

- [ ] [`WEB-81`](ledger/WEB/WEB-81.md) GPX à plusieurs traces : profil empilé et synchro faussée (S, priorité basse)
- [ ] [`WEB-7`](ledger/WEB/WEB-7.md) Idées de la liste « P2 (à planifier) » qui n'ont pas été retenues

### En-têtes de pages : audit du 25 novembre 2026

- [ ] [`WEB-209`](ledger/WEB/WEB-209.md) En-têtes de pages, lot 5 : une carte transactionnelle commune (M)
- [ ] [`WEB-208`](ledger/WEB/WEB-208.md) En-têtes de pages, lot 4 : bandeau d'équipe et administration (M)
- [ ] [`WEB-207`](ledger/WEB/WEB-207.md) En-têtes de pages, lot 3 : un h1 par page (M)
- [ ] [`WEB-206`](ledger/WEB/WEB-206.md) En-têtes de pages, lot 2 : un DetailHeader commun aux pages de détail (L)
- [ ] [`WEB-205`](ledger/WEB/WEB-205.md) En-têtes de pages, lot 1 : lexique et titre d'onglet (M)

### Planificateur : audit UX du choix du profil, 24 novembre 2026

- [ ] [`WEB-202`](ledger/WEB/WEB-202.md) Planificateur : refonte du volet de réglages du tracé (pratique, calcul, circulation, côtes, recalcul) (L) · *recette*

## API — Contrat d'API et backend

Contexte du domaine : [`ledger/API/README.md`](ledger/API/README.md).

- [ ] [`API-217`](ledger/API/API-217.md) Calcul d'itinéraire vélo par le moteur du générateur, en option du planificateur (L)
- [ ] [`API-216`](ledger/API/API-216.md) Carte de chaleur des parcours, pondérée par les sorties roulées (M)
- [ ] [`API-214`](ledger/API/API-214.md) Typologie des tuiles de route-details : 12,6 % des tronçons gravel sans classe de revêtement (M)
- [ ] [`API-212`](ledger/API/API-212.md) Retoucher un parcours existant : viser une distance, déplacer l'arrivée (L, lot 0 mesuré, lot 7c codé)
- [ ] [`API-209`](ledger/API/API-209.md) Carte des parcours en fréquentation : nombre de parcours par arête OSM, coloré selon le compte (L)
- [ ] [`API-207`](ledger/API/API-207.md) Générateur de parcours au-delà du réseau de l'équipe (L, proposition, décision d'abord) · *decision*
- [ ] [`API-203`](ledger/API/API-203.md) Ce qu'un jeton d'application ou d'appareil peut faire sans le membre (S, décision d'abord) · *decision*
- [ ] [`API-202`](ledger/API/API-202.md) Une application externe dans un navigateur ne peut pas appeler l'API (S, décision d'abord) · *decision*
- [ ] [`API-200`](ledger/API/API-200.md) OAuth des applications externes : l'écran de consentement dans l'app mobile (M)
- [ ] [`API-177`](ledger/API/API-177.md) Le rôle de l'appelant dans l'équipe, lu une fois par requête (S)
- [ ] [`API-154`](ledger/API/API-154.md) Plafonds de la météo des aperçus GPX qui restent ouverts (S)
- [ ] [`API-151`](ledger/API/API-151.md) Passage à osm-route-details : banc de D+ et crédit web (S)
- [ ] [`API-148`](ledger/API/API-148.md) Retirer les rustines de sécurité des dépendances une fois sur Quarkus 4 (S)
- [ ] [`API-140`](ledger/API/API-140.md) `/api/admin/teams` sans domaine forcé : décision produit à prendre · *decision*
- [ ] [`API-135`](ledger/API/API-135.md) Garder le type et la distance des `course_point` d'une pièce jointe FIT (S)

### Cache, fraîcheur et images — quatre briques indépendantes

- [ ] [`API-27`](ledger/API/API-27.md) Coût du lot de géométries — ce qui reste après 2.0.0
- [ ] [`API-26`](ledger/API/API-26.md) Carte multi-entités `GET /api/map/features` (M)
- [ ] [`API-25`](ledger/API/API-25.md) `blurHash` (S)
- [ ] [`API-24`](ledger/API/API-24.md) URLs d'images signées (M)
- [ ] [`API-23`](ledger/API/API-23.md) `updatedAt` en liste + `?updatedSince=` (M)
- [ ] [`API-22`](ledger/API/API-22.md) `ETag` / `If-None-Match` (M)

### Envoi automatique des parcours vers les services GPS : ce qui reste après `API-120`

- [ ] [`API-126`](ledger/API/API-126.md) L'envoi manuel vers un service GPS traite 401, 412 et 429 comme la synchronisation (S)
- [ ] [`API-125`](ledger/API/API-125.md) Les restes d'`API-120` : nom envoyé, envoi manuel d'une route suivie, étape 0 (S)
- [ ] [`API-122`](ledger/API/API-122.md) L'état « déjà chez le service GPS » de « Prochaines sorties » éprouvé sur un vrai Karoo et un vrai Edge (S) · *recette*

### Extension Karoo : ce que le découpage de novembre 2026 a figé sans le corriger

- [ ] [`API-190`](ledger/API/API-190.md) Karoo : finir le filet de tests (S)
- [ ] [`API-189`](ledger/API/API-189.md) Karoo : l'étape Hammerhead ne rend jamais la main (S)
- [ ] [`API-187`](ledger/API/API-187.md) Karoo : les touches agissent sous l'écran affiché (S)
- [ ] [`API-186`](ledger/API/API-186.md) Karoo : une synchro qui échoue ou réussit à tort (S)
- [ ] [`API-63`](ledger/API/API-63.md) Onboarding d'un Karoo refait de bout en bout (M, backend + web + mobile + Karoo) · *recette*

### Garmin

- [ ] [`API-119`](ledger/API/API-119.md) « Prochaines sorties » éprouvé sur un vrai Karoo et un vrai Edge (S) · *recette*
- [ ] [`API-111`](ledger/API/API-111.md) App Garmin sur les montres qui suivent un parcours
- [ ] [`API-110`](ledger/API/API-110.md) App Garmin : rendre les Edge plus anciens éligibles
- [ ] [`API-61`](ledger/API/API-61.md) Mettre l'intégration Garmin OAuth 2.0 en conformité

### Heure de départ : audit du 7 novembre 2026

- [ ] [`API-196`](ledger/API/API-196.md) Garmin : fuseau de la sortie, lieu, équipe, état — ce que `details=true` donnerait (M)
- [ ] [`API-160`](ledger/API/API-160.md) iCal : une étape n'a pas d'heure de départ (à trancher)

### Les chantiers d'infrastructure d'API

- [ ] [`API-21`](ledger/API/API-21.md) Pagination par curseur — **à faire avant d'étendre le scroll infini (L)

### Météo : ce qui suit `API-74`

- [ ] [`API-103`](ledger/API/API-103.md) Pas de réglage d'unités pour le Royaume-Uni (S, contrat + web + mobile)
- [ ] [`API-77`](ledger/API/API-77.md) Météo sur Karoo et Garmin (M)

### Petites évolutions d'API qui suppriment chacune une dégradation nommée

- [ ] [`API-18`](ledger/API/API-18.md) Voyage comme événement multi-jour au calendrier (`CalendarEventType`, toujours `RIDE`/`TRIP_STAGE`)
- [ ] [`API-17`](ledger/API/API-17.md) `?format=polyline` sur la géométrie de parcours
- [ ] [`API-8`](ledger/API/API-8.md) Voisins de publication (`prev`/`next`) — absents de tout le contrat `11.5.1` (balayage de tous les schémas le…

## OPS — Exploitation

Contexte du domaine : [`ledger/OPS/README.md`](ledger/OPS/README.md).

- [ ] [`OPS-69`](ledger/OPS/OPS-69.md) Mettre en service osm-route-details 1.18.0 (retouche, api 1.17) (S) · *externe*

### App Garmin : Connect IQ Store

- [ ] [`OPS-35`](ledger/OPS/OPS-35.md) Publier l'app Garmin sur le Connect IQ Store · *externe*

### Exploitation

- [ ] [`OPS-58`](ledger/OPS/OPS-58.md) osm-route-details dans la pile partagée : à régler
- [ ] [`OPS-56`](ledger/OPS/OPS-56.md) Vérifier en prod le plateau du heap après `OPS-55`
- [ ] [`OPS-54`](ledger/OPS/OPS-54.md) Images Docker publiées sur un registry public, construites par la CI (étude)
- [ ] [`OPS-47`](ledger/OPS/OPS-47.md) Un `robots.txt` pour `auth.pedalons.fr`
- [ ] [`OPS-46`](ledger/OPS/OPS-46.md) (Optionnel) Alerte sur la taille du cache de tuiles du backend
- [ ] [`OPS-42`](ledger/OPS/OPS-42.md) Envoi automatique des parcours : la recette sur appareil, faite après l'allumage (S) · *recette*
- [ ] [`OPS-41`](ledger/OPS/OPS-41.md) Mesure d'audience du site : consigner la recette, puis relire au bout d'un mois (S)
- [ ] [`OPS-34`](ledger/OPS/OPS-34.md) Faire revalider la Search Console après `WEB-85`, `WEB-86` et `API-109` · *externe*
- [ ] [`OPS-30`](ledger/OPS/OPS-30.md) Check Healthchecks du rafraîchissement des données des relecteurs des stores

### Extension Karoo : catalogue Hammerhead

- [ ] [`OPS-33`](ledger/OPS/OPS-33.md) Publier l'extension Karoo dans l'Extension Library de Hammerhead · *externe*

### Recette du backend en conditions réelles

- [ ] [`OPS-29`](ledger/OPS/OPS-29.md) Météo des sorties en production : ce qui reste (S)
- [ ] [`OPS-4`](ledger/OPS/OPS-4.md) Les quatre gabarits d'invitation en production : les recevoir · *recette*
- [ ] [`OPS-3`](ledger/OPS/OPS-3.md) Le relais de contact en production : regarder un message reçu · *recette*

## NOTIF — Notifications

Contexte du domaine : [`ledger/NOTIF/README.md`](ledger/NOTIF/README.md).

- [ ] [`NOTIF-12`](ledger/NOTIF/NOTIF-12.md) Le mobile enregistre ses push par une API dépréciée
- [ ] [`NOTIF-11`](ledger/NOTIF/NOTIF-11.md) Rejouer `CoalesceRace` sur le correctif exact de `NOTIF-10`
- [ ] [`NOTIF-4`](ledger/NOTIF/NOTIF-4.md) Le canal e-mail des notifications n'a pas de test e2e
- [ ] [`NOTIF-3`](ledger/NOTIF/NOTIF-3.md) Webhook d'équipe : le *DNS rebinding* n'est pas couvert
- [ ] [`NOTIF-2`](ledger/NOTIF/NOTIF-2.md) Décision produit sur l'e-mail · *decision*
- [ ] [`NOTIF-1`](ledger/NOTIF/NOTIF-1.md) Recette du webhook d'équipe · *recette*

### Notifications datées : expiration

- [ ] [`NOTIF-18`](ledger/NOTIF/NOTIF-18.md) Une invitation acceptée ou un signalement traité reste non lu (S)
- [ ] [`NOTIF-17`](ledger/NOTIF/NOTIF-17.md) Les clients ne distinguent pas une notification expirée (S)
- [ ] [`NOTIF-15`](ledger/NOTIF/NOTIF-15.md) Une notification datée reste non lue après le rendez-vous (M)

### Onboarding : recherche du 22 novembre 2026

- [ ] [`NOTIF-19`](ledger/NOTIF/NOTIF-19.md) Activation du push proposée seulement dans la boîte de notifications (S)

## MOD — Modération et signalement de contenu

Aucune entrée ouverte. Contexte du domaine : [`ledger/MOD/README.md`](ledger/MOD/README.md).

## ISSUE — « Signaler un problème » et remontée des erreurs vers GitHub

Contexte du domaine : [`ledger/ISSUE/README.md`](ledger/ISSUE/README.md).

- [ ] [`ISSUE-5`](ledger/ISSUE/ISSUE-5.md) Visiteurs non connectés
- [ ] [`ISSUE-4`](ledger/ISSUE/ISSUE-4.md) Boucler avec le membre
- [ ] [`ISSUE-3`](ledger/ISSUE/ISSUE-3.md) Plantages natifs
- [ ] [`ISSUE-2`](ledger/ISSUE/ISSUE-2.md) Côté mobile
- [ ] [`ISSUE-1`](ledger/ISSUE/ISSUE-1.md) Piles web illisibles

## MIG — Migration biketeam → Pédalons

Contexte du domaine : [`ledger/MIG/README.md`](ledger/MIG/README.md).

### Autour de la migration

- [ ] [`MIG-18`](ledger/MIG/MIG-18.md) Une équipe migrée ne peut plus être retirée de Pédalons
- [ ] [`MIG-17`](ledger/MIG/MIG-17.md) Supprimer les colonnes `dry_run` et `reset` de `biketeam_migrations`
- [ ] [`MIG-9`](ledger/MIG/MIG-9.md) Purge physique des équipes à la corbeille

### Mise en production

- [ ] [`MIG-8`](ledger/MIG/MIG-8.md) Après l'arrêt de biketeam
- [ ] [`MIG-7`](ledger/MIG/MIG-7.md) Avant l'arrêt de biketeam · *externe*
- [ ] [`MIG-6`](ledger/MIG/MIG-6.md) Données exportées mais non importées
- [ ] [`MIG-3`](ledger/MIG/MIG-3.md) Liens internes non réécrits
- [ ] [`MIG-2`](ledger/MIG/MIG-2.md) Redirections 302 → 301 · *externe*
- [ ] [`MIG-1`](ledger/MIG/MIG-1.md) Passage réel · *externe*

## BRAND — Charte

Aucune entrée ouverte. Contexte du domaine : [`ledger/BRAND/README.md`](ledger/BRAND/README.md).

## SEC — Sécurité applicative

Contexte du domaine : [`ledger/SEC/README.md`](ledger/SEC/README.md).

- [ ] [`SEC-52`](ledger/SEC/SEC-52.md) La clé de cloisonnement du moteur de parcours circule en clair sur le réseau partagé des piles, et le moteur…
- [ ] [`SEC-50`](ledger/SEC/SEC-50.md) La désactivation d'un domaine ne s'applique pas à tous les chemins de résolution
- [ ] [`SEC-49`](ledger/SEC/SEC-49.md) Un quota d'envoi suit le motif compter-puis-insérer (même famille que `SEC-35` et `SEC-39`)
- [ ] [`SEC-48`](ledger/SEC/SEC-48.md) Un appel facturé à un fournisseur n'a pas de quota par compte. Aperçus GPX datés (API-153) : 20 à venir par…
- [ ] [`SEC-47`](ledger/SEC/SEC-47.md) Un retour de connexion à un service tiers n'est pas lié au navigateur qui l'a lancé
- [ ] [`SEC-46`](ledger/SEC/SEC-46.md) Un chemin d'envoi de trace échappe à la borne de taille posée par `SEC-6`
- [ ] [`SEC-45`](ledger/SEC/SEC-45.md) Une bibliothèque d'analyse de fichiers de trace n'est pas protégée contre l'expansion d'entités
- [ ] [`SEC-44`](ledger/SEC/SEC-44.md) Une entrée pré-authentification n'est pas bornée en mémoire avant validation
- [ ] [`SEC-41`](ledger/SEC/SEC-41.md) Une demande en cours sur un attribut d'identité survit à la récupération du compte
- [ ] [`SEC-40`](ledger/SEC/SEC-40.md) La CSP complète du site n'est encore que rapportée (`Content-Security-Policy-Report-Only`) : lire les…
- [ ] [`SEC-39`](ledger/SEC/SEC-39.md) Deux autres émissions de jetons par e-mail gardent le motif compter-puis-insérer que `SEC-35` a fermé pour…
- [ ] [`SEC-13`](ledger/SEC/SEC-13.md) Durcissement des workflows GitHub Actions — permissions minimales posées sur les quatre workflows d'alors…
- [ ] [`SEC-12`](ledger/SEC/SEC-12.md) Voir la table des constats faibles de l'audit ; L1 et L5 à L9 sont livrés sous `SEC-20`, L12 et L13 sous…

## AUD — Suivi de l'audit d'infrastructure de février

Contexte du domaine : [`ledger/AUD/README.md`](ledger/AUD/README.md).

- [ ] [`AUD-30`](ledger/AUD/AUD-30.md) Aucune limite **CPU** dans les compose (la mémoire est bornée : `AUD-7`). À poser une fois les charges…
- [ ] [`AUD-29`](ledger/AUD/AUD-29.md) Le polling du device flow s'arrête à la **première erreur réseau** : toute erreur qui n'est ni « en attente »…
- [ ] [`AUD-27`](ledger/AUD/AUD-27.md) Pas de `slow_down` (le backend n'en émet aucun à ce jour — relevé le 30 septembre 2026 : `grep slow_down…
- [ ] [`AUD-26`](ledger/AUD/AUD-26.md) `loadResource()` dans `onUpdate()` ; état comparé à une chaîne localisée ; `_tokenCallback` partagé entre…
- [ ] [`AUD-25`](ledger/AUD/AUD-25.md) `BASE_URL` de production en dur (`ApiClient.mc`) : bloque le multi-tenant
- [ ] [`AUD-24`](ledger/AUD/AUD-24.md) Pas de `slow_down` (RFC 8628 — le backend n'en émet aucun à ce jour, voir `AUD-27`)…
- [ ] [`AUD-21`](ledger/AUD/AUD-21.md) Pas de hors-ligne — voir `API-22` à `API-25`
- [ ] [`AUD-20`](ledger/AUD/AUD-20.md) Lints Flutter par défaut seulement (`analysis_options.yaml`)
- [ ] [`AUD-15`](ledger/AUD/AUD-15.md) `FetchType.EAGER` sur neuf `@ManyToOne` (`Ride`, `RideGroup`, `Trip`, `TripStage`, `UserTeam`)
- [ ] [`AUD-10`](ledger/AUD/AUD-10.md) Aucune procédure de rotation des secrets dans `OPERATIONS.md` (clés JWT, `ENCRYPTION_KEY`, mots de passe…
- [ ] [`AUD-9`](ledger/AUD/AUD-9.md) imgproxy sans signature d'URL (ni `IMGPROXY_KEY` ni `IMGPROXY_SALT`) — même brique que les URLs signées…
- [ ] [`AUD-6`](ledger/AUD/AUD-6.md) `forwardedHeaders.insecure=true` sur Traefik (atténué par les règles `DOCKER-USER` qui ne laissent que Caddy…

## LEGAL — Politique de confidentialité

Contexte du domaine : [`ledger/LEGAL/README.md`](ledger/LEGAL/README.md).

- [ ] [`LEGAL-30`](ledger/LEGAL/LEGAL-30.md) La politique ne nomme pas les tags parmi le contenu créé (XS)
- [ ] [`LEGAL-28`](ledger/LEGAL/LEGAL-28.md) La politique ne parle pas des applications externes autorisées par OAuth (S)
- [ ] [`LEGAL-26`](ledger/LEGAL/LEGAL-26.md) Revêtement des parcours : ODbL et mention de VersaTiles côté serveur (S)

## BILL — Monétisation

Contexte du domaine : [`ledger/BILL/README.md`](ledger/BILL/README.md).

- [ ] [`BILL-11`](ledger/BILL/BILL-11.md) Recette des limites de l'offre gratuite (S) · *recette*
- [ ] [`BILL-1`](ledger/BILL/BILL-1.md) Décider, vérifier, puis poser le socle (M)

## Ce qui ne se ferme pas par du code

Les mêmes entrées que plus haut, par ce qu'elles attendent : relire le code ne les fait pas avancer.

### À constater à la main (`recette`)

- [`MOB-181`](ledger/MOB/MOB-181.md) Passer à maplibre 0.4 (moteur natif unique)
- [`MOB-178`](ledger/MOB/MOB-178.md) Les outils GPX dans l'app : recette sur appareil
- [`MOB-174`](ledger/MOB/MOB-174.md) `maplibre_ios` appelle `setState` sur une carte déjà démontée
- [`MOB-170`](ledger/MOB/MOB-170.md) Tracer et modifier un parcours sur la carte dans l'app : recette sur appareil
- [`MOB-146`](ledger/MOB/MOB-146.md) Listes homogènes : recette sur appareil de `MOB-143`
- [`MOB-141`](ledger/MOB/MOB-141.md) Cartes homogènes : recette sur appareil de `MOB-139`
- [`MOB-135`](ledger/MOB/MOB-135.md) Refonte des écrans de détail : recette sur appareil de `MOB-134`
- [`MOB-130`](ledger/MOB/MOB-130.md) Contrôles de carte : recette sur appareil de `MOB-129`
- [`MOB-95`](ledger/MOB/MOB-95.md) La météo sur la carte : recette sur appareil des paliers 1 à 3
- [`MOB-86`](ledger/MOB/MOB-86.md) Points de parcours : recette sur appareil
- [`MOB-77`](ledger/MOB/MOB-77.md) Éditeur de sortie, modèles et parcours : recette sur appareil
- [`MOB-73`](ledger/MOB/MOB-73.md) Vérifier l'APK sur un Android sans Google Play Services
- [`MOB-52`](ledger/MOB/MOB-52.md) Météo : recette sur appareil de ce que `MOB-68` ne couvre pas
- [`MOB-15`](ledger/MOB/MOB-15.md) Profil (33)
- [`MOB-13`](ledger/MOB/MOB-13.md) Trombinoscope (34)
- [`MOB-5`](ledger/MOB/MOB-5.md) Exploration de parcours (21)
- [`WEB-203`](ledger/WEB/WEB-203.md) « GPS » dans la barre d'actions des pages parcours, sortie, groupe et étape
- [`WEB-202`](ledger/WEB/WEB-202.md) Planificateur : refonte du volet de réglages du tracé (pratique, calcul, circulation, côtes, recalcul)
- [`WEB-199`](ledger/WEB/WEB-199.md) La souris déplace les ancres d'un tracé au lieu d'ajouter un point à côté
- [`WEB-176`](ledger/WEB/WEB-176.md) Listes homogènes : recette en navigateur de `WEB-175`
- [`WEB-172`](ledger/WEB/WEB-172.md) Cartes homogènes : recette en navigateur de `WEB-167`
- [`WEB-161`](ledger/WEB/WEB-161.md) Contrôles de carte : recette à l'œil de `WEB-157`
- [`WEB-133`](ledger/WEB/WEB-133.md) La météo des aperçus GPX : recette navigateur
- [`WEB-119`](ledger/WEB/WEB-119.md) La météo sur la carte : recette navigateur des paliers 1 à 3
- [`WEB-61`](ledger/WEB/WEB-61.md) Météo des sorties : recette navigateur de ce que `WEB-94` n'a pas vu
- [`WEB-56`](ledger/WEB/WEB-56.md) Profil refondu (`WEB-55`, `WEB-57`) : recette navigateur
- [`API-122`](ledger/API/API-122.md) L'état « déjà chez le service GPS » de « Prochaines sorties » éprouvé sur un vrai Karoo et un vrai Edge
- [`API-119`](ledger/API/API-119.md) « Prochaines sorties » éprouvé sur un vrai Karoo et un vrai Edge
- [`API-63`](ledger/API/API-63.md) Onboarding d'un Karoo refait de bout en bout (M, backend + web + mobile + Karoo)
- [`OPS-42`](ledger/OPS/OPS-42.md) Envoi automatique des parcours : la recette sur appareil, faite après l'allumage
- [`OPS-4`](ledger/OPS/OPS-4.md) Les quatre gabarits d'invitation en production : les recevoir
- [`OPS-3`](ledger/OPS/OPS-3.md) Le relais de contact en production : regarder un message reçu
- [`NOTIF-1`](ledger/NOTIF/NOTIF-1.md) Recette du webhook d'équipe
- [`BILL-11`](ledger/BILL/BILL-11.md) Recette des limites de l'offre gratuite

### Dépend d'un tiers ou d'une opération hors du dépôt (`externe`)

- [`MOB-64`](ledger/MOB/MOB-64.md) Publier Pédalons sur Google Play
- [`OPS-69`](ledger/OPS/OPS-69.md) Mettre en service osm-route-details 1.18.0 (retouche, api 1.17)
- [`OPS-35`](ledger/OPS/OPS-35.md) Publier l'app Garmin sur le Connect IQ Store
- [`OPS-34`](ledger/OPS/OPS-34.md) Faire revalider la Search Console après `WEB-85`, `WEB-86` et `API-109`
- [`OPS-33`](ledger/OPS/OPS-33.md) Publier l'extension Karoo dans l'Extension Library de Hammerhead
- [`MIG-7`](ledger/MIG/MIG-7.md) Avant l'arrêt de biketeam
- [`MIG-2`](ledger/MIG/MIG-2.md) Redirections 302 → 301
- [`MIG-1`](ledger/MIG/MIG-1.md) Passage réel

### Attend une décision (`decision`)

- [`API-207`](ledger/API/API-207.md) Générateur de parcours au-delà du réseau de l'équipe (L, proposition, décision d'abord)
- [`API-203`](ledger/API/API-203.md) Ce qu'un jeton d'application ou d'appareil peut faire sans le membre (S, décision d'abord)
- [`API-202`](ledger/API/API-202.md) Une application externe dans un navigateur ne peut pas appeler l'API (S, décision d'abord)
- [`API-140`](ledger/API/API-140.md) `/api/admin/teams` sans domaine forcé : décision produit à prendre
- [`NOTIF-2`](ledger/NOTIF/NOTIF-2.md) Décision produit sur l'e-mail

## Délibérément dehors

À relire avant de rouvrir l'un de ces points : chacun a été écarté avec un motif, et plusieurs
sont des invariants que le code garde. Rouvert, il redevient une entrée ouverte sous le même
identifiant.

- [`MOB-171`](ledger/MOB/MOB-171.md) Paramètres plateforme d'une équipe dans l'app
- [`MOB-136`](ledger/MOB/MOB-136.md) Adresse sous le nom des lieux de départ et d'arrivée
- [`MOB-131`](ledger/MOB/MOB-131.md) « Me localiser » sur les cartes de l'app
- [`MOB-89`](ledger/MOB/MOB-89.md) Pages personnalisées d'équipe en puces de section, comme les onglets du web
- [`MOB-88`](ledger/MOB/MOB-88.md) Mode mono-équipe dans l'app
- [`MOB-85`](ledger/MOB/MOB-85.md) Nom du point sous l'info-bulle du profil
- [`MOB-74`](ledger/MOB/MOB-74.md) Exclure du manifeste Android les pages du site sans écran dans l'app
- [`MOB-61`](ledger/MOB/MOB-61.md) Recherche et tags des anciennes adresses du fil dans l'app
- [`MOB-50`](ledger/MOB/MOB-50.md) Cloche des notifications dans l'en-tête du Profil
- [`MOB-24`](ledger/MOB/MOB-24.md) Édition et création de contenu au mobile — hors sorties, modèles de sortie, parcours et publications
- [`MOB-23`](ledger/MOB/MOB-23.md) Écran de profil public d'un membre
- [`MOB-22`](ledger/MOB/MOB-22.md) Jeu d'icônes Tabler côté mobile
- [`WEB-191`](ledger/WEB/WEB-191.md) Aperçu GPX : la molette zoome la carte pleine largeur au lieu de faire défiler la page
- [`WEB-171`](ledger/WEB/WEB-171.md) Mention de fuseau en ligne sur le site, comme dans l'app
- [`WEB-159`](ledger/WEB/WEB-159.md) Interrupteur Pente · Revêtement · Météo dans l'en-tête du profil en surimpression (web)
- [`WEB-109`](ledger/WEB/WEB-109.md) POI suggérés le long d'un parcours
- [`WEB-105`](ledger/WEB/WEB-105.md) Surface dans les exports GPX et FIT, second passage de costing sur l'inconnu
- [`WEB-104`](ledger/WEB/WEB-104.md) Plafond de tuiles MNT et limite de débit propres à `POST /api/router/elevation`
- [`WEB-103`](ledger/WEB/WEB-103.md) Altitudes FAST d'un tracé rouvert sans état
- [`WEB-91`](ledger/WEB/WEB-91.md) Statistiques d'audience pour les admins de club
- [`WEB-65`](ledger/WEB/WEB-65.md) Tableau de bord pour un admin de plateforme non membre
- [`WEB-58`](ledger/WEB/WEB-58.md) Redirection des anciennes adresses du profil
- [`WEB-54`](ledger/WEB/WEB-54.md) Calendrier rendu côté serveur dans le mauvais fuseau, sans préférence `timezone`
- [`WEB-44`](ledger/WEB/WEB-44.md) Passkey en tête du formulaire de connexion
- [`WEB-12`](ledger/WEB/WEB-12.md) Mode sombre dérivé au web
- [`WEB-11`](ledger/WEB/WEB-11.md) Jetons `--pdl-*` au web
- [`WEB-10`](ledger/WEB/WEB-10.md) Minimum de 44 px sur les boutons web
- [`WEB-9`](ledger/WEB/WEB-9.md) Gabarits tactiles portés au web
- [`WEB-8`](ledger/WEB/WEB-8.md) Scroll infini côté web
- [`API-205`](ledger/API/API-205.md) Finir le générateur Java d'équipe
- [`API-201`](ledger/API/API-201.md) OAuth : enregistrer les applications, vérifier `redirect_uri`, des scopes
- [`API-192`](ledger/API/API-192.md) Les étapes de voyage dans l'app Garmin
- [`API-183`](ledger/API/API-183.md) Renvoyer tout le parc aux services GPS après `API-182`
- [`API-175`](ledger/API/API-175.md) Retirer la colonne `elevation_refresh.backfill` et la priorité qui la lit
- [`API-167`](ledger/API/API-167.md) Aligner le séparateur des sorties (` · `) sur celui des étapes (` - `)
- [`API-166`](ledger/API/API-166.md) Envoi groupé de toutes les étapes dès que la première entre dans la fenêtre
- [`API-165`](ledger/API/API-165.md) Envoi automatique d'un voyage sans étape (sa route globale)
- [`API-127`](ledger/API/API-127.md) Contourner `ROUTE_PLANNER_DISABLED` d'un aperçu tracé
- [`API-124`](ledger/API/API-124.md) `dominantHeadwindAzimuthDeg()` (vcyclist g31) dans `WindEstimator`
- [`API-116`](ledger/API/API-116.md) Couper la mesure d'audience pour un club
- [`API-114`](ledger/API/API-114.md) Import depuis OpenRunner ou VisuGPX
- [`API-113`](ledger/API/API-113.md) Import d'un GPX par URL dans les outils GPX
- [`API-93`](ledger/API/API-93.md) Statistiques de voyage stockées en base
- [`API-89`](ledger/API/API-89.md) Fin stockée pendant le déploiement à chaud
- [`API-67`](ledger/API/API-67.md) « Mes équipes » d'un admin de plateforme
- [`API-54`](ledger/API/API-54.md) exiftool pour retirer les métadonnées des images
- [`API-52`](ledger/API/API-52.md) Durcir `ImageMetadataStripper`
- [`API-47`](ledger/API/API-47.md) Les documents joints gardent leurs métadonnées
- [`API-34`](ledger/API/API-34.md) `acceptTerms` obligatoire à l'inscription (contrat `4.1.0`)
- [`API-33`](ledger/API/API-33.md) `GET /api/rides` et listes mono-type
- [`API-32`](ledger/API/API-32.md) Champ de contact libre sur une annonce
- [`API-31`](ledger/API/API-31.md) Position exacte d'une annonce
- [`API-30`](ledger/API/API-30.md) Repli sur `createdBy` pour le meneur
- [`API-29`](ledger/API/API-29.md) Liste d'attente (`waitlisted`)
- [`API-19`](ledger/API/API-19.md) `GET /api/search?q&types=&limit` unifié
- [`OPS-63`](ledger/OPS/OPS-63.md) Erreurs côté client web et mobile (GlitchTip)
- [`OPS-62`](ledger/OPS/OPS-62.md) Métriques du frontend SSR
- [`OPS-40`](ledger/OPS/OPS-40.md) Compter des visites plutôt que des pages vues
- [`OPS-39`](ledger/OPS/OPS-39.md) Mesure d'audience par les journaux d'accès
- [`OPS-38`](ledger/OPS/OPS-38.md) Matomo pour la mesure d'audience
- [`OPS-37`](ledger/OPS/OPS-37.md) Plausible CE pour la mesure d'audience
- [`OPS-18`](ledger/OPS/OPS-18.md) Rotation des secrets exposés par les sauvegardes en clair
- [`NOTIF-8`](ledger/NOTIF/NOTIF-8.md) Tests Vitest de la cloche et de la page Notifications
- [`NOTIF-7`](ledger/NOTIF/NOTIF-7.md) Temps réel des notifications (SSE)
- [`NOTIF-6`](ledger/NOTIF/NOTIF-6.md) Isolat de fond du push (`onBackgroundMessage`)
- [`NOTIF-5`](ledger/NOTIF/NOTIF-5.md) Badge iOS du push
- [`MOD-5`](ledger/MOD/MOD-5.md) Contenu masqué d'un compte effacé
- [`ISSUE-10`](ledger/ISSUE/ISSUE-10.md) Staging et la production servent publiquement leurs sourcemaps
- [`BRAND-3`](ledger/BRAND/BRAND-3.md) Test de concordance des tables de couleurs web et mobile
- [`SEC-14`](ledger/SEC/SEC-14.md) Images externes dans le markdown ; le parseur XML et le paramètre non encodé sont livrés sous `SEC-21`
- [`AUD-33`](ledger/AUD/AUD-33.md) Pagination des routes côté Karoo
- [`AUD-8`](ledger/AUD/AUD-8.md) VCL Varnish réduite à un `backend default` et une règle de contournement du cache (`API-43`) : ni purge, ni…
- [`AUD-1`](ledger/AUD/AUD-1.md) Déploiement automatique (CD) depuis GitHub
- [`LEGAL-20`](ledger/LEGAL/LEGAL-20.md) Mesure d'audience par un service SaaS
- [`LEGAL-17`](ledger/LEGAL/LEGAL-17.md) Responsable du traitement par domaine
- [`LEGAL-16`](ledger/LEGAL/LEGAL-16.md) Journal des accès des admins plateforme
- [`LEGAL-14`](ledger/LEGAL/LEGAL-14.md) Notification des changements de politique dans l'app
