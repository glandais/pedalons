# Le fait — ce qui a été livré depuis la v2

Pendant de [`LEDGER_NEXT.md`](LEDGER_NEXT.md) : quand une entrée du reste à faire est livrée, elle
vient ici avec les décisions qui la tiennent, **sous le même identifiant** (`WEB-14`, `NOTIF-9`…),
dans la section de son préfixe. La nomenclature — préfixes, attribution des numéros, forme des
renvois — est décrite en tête de `LEDGER_NEXT.md`, et vaut pour les deux fichiers. Ce qui a été
écarté délibérément n'est pas ici : c'est la section « Délibérément dehors » de `LEDGER_NEXT.md`.

Une entrée livrée s'écrit au passé, avec sa date, la version d'API si le contrat a changé, le test
qui la couvre, et les décisions qu'il ne faut pas défaire.

Les plans archivés ([`plans/archive/`](plans/archive/)) gardent le **pourquoi** détaillé ; ce
fichier garde **ce qui est fait**, et ce qu'il ne faut pas défaire.

---

## MOB — Application mobile

- `MOB-21` **Sortie (12), corrigé pendant la passe partielle du 27 juillet 2026** — le bandeau
  `GROUP_FULL` affichait « Groupe complet. » sans jamais dire lequel : `rides.failure.full` prend
  maintenant `{group}`, comme les bandeaux voisins. Le reste de la recette de l'écran est `MOB-2`.
- [x] `MOB-40` **Un lien universel ouvrait l'app et Safari** (2 octobre 2026, issues feedback #6 et
  #7, build 62, iOS) — le QR d'appairage Karoo ouvrait la validation dans l'app **et** dans Safari.
  Le deep linking intégré de Flutter (actif par défaut depuis 3.27) poussait la route en plus
  d'`app_links` ; au lancement, sur le `MaterialApp` de chargement d'`app.dart` (pas de routeur),
  `_onUnknownRoute` levait « Null check operator », et le moteur iOS renvoyait alors le lien non
  géré au système (`relayToSystemIfUnhandled`), qui l'ouvrait dans Safari. Désactivé :
  `FlutterDeepLinkingEnabled` = `false` (`ios/Runner/Info.plist`) et `flutter_deeplinking_enabled`
  = `false` (`AndroidManifest.xml`, où chaque lien était traité deux fois). Pas de test automatisé :
  à vérifier par un scan du QR sur iPhone (build 64). **À ne pas défaire** : `_DeepLinkHandler` (`main.dart`) est
  le **seul** à recevoir les liens — réactiver le deep linking de Flutter rouvre Safari à chaque
  lien reçu avant la fin de l'initialisation de l'auth.
- [x] `MOB-41` **Les données du compte des relecteurs des stores ne se périment plus** (3 octobre
  2026, contrat inchangé) — le seed prod de `mobile/screenshots/seed.py` était un passage unique :
  trois semaines plus tard, `marketplace-tester@pedalons.fr` n'était plus inscrit à rien, la sortie
  commentée que citent les notes App Review était passée, et la reconstruction elle-même ne passait
  plus, l'API refusant depuis `80670273` l'inscription à une sortie passée. `--refresh` remet les
  deux clubs à jour sans rien supprimer, par l'API seule : le compte de test inscrit à sa prochaine
  sortie (plus deux sur cinq dans les trois semaines), un fil de commentaires d'autres membres sur
  celle-ci tel que lui le voit, ses blocages levés, les sorties proches complétées, un voyage
  toujours à venir, la publication du mois, la fin du calendrier qui avance (quinze mois glissants
  au lieu du 31 décembre 2027). La reconstruction part désormais de demain ; l'historique est ce que
  les rafraîchissements laissent derrière eux. Pas de test automatisé : `--dry-run` et une
  vérification hors ligne du calendrier et des inscriptions. **À ne pas défaire** : une sortie tire
  ses membres et son calendrier **d'une graine par date** (`calendar-{fr}-{jour}`,
  `{locale}-{AAAAMMJJ}`), et les lève-tôt sont un préfixe des inscrits finaux — c'est ce qui rend
  `--refresh` idempotent et ne fait qu'ajouter. L'installation sur l'hôte est `OPS-28`.
- [x] `MOB-63` **Fiche App Store et captures refaites sur l'app d'octobre** (9 octobre 2026, contrat
  inchangé) — les captures du 25 septembre montraient un fil d'équipe remplacé depuis par le
  tableau de bord, l'Agenda et les Publications (`MOB-60`), et ni la description ni les captures ne
  disaient rien de la météo. Description FR/EN réécrite (météo au départ et le long du parcours à
  l'allure du groupe, météo des étapes, tableau de bord, Agenda, compteurs Karoo et Garmin
  nommés, réglages de notification par type), mots-clés `météo,vent` / `weather,wind` à la place de
  `groupe,randonnée` / `group,events` — pas de marque tierce dans les mots-clés (règle 2.3.7). Sept
  cartes au lieu de six, iPhone et iPad : accueil (iPad : voyage), groupes d'allure, **météo du
  parcours**, profil et montées, **tableau de bord**, bibliothèque, calendrier. Trois correctifs en
  chemin :
  - le mode capture pousse un écran sans URL par-dessus le chemin ouvert (`push` dans le fichier de
    lancement, `screenshotTakePush`, consommé une fois) : la « Météo du parcours » n'est qu'un
    `Navigator.push` depuis le détail ;
  - `seed.py` cherchait le conteneur postgres sous son nom compose, qu'une tâche Swarm n'a pas, et
    envoyait des instants que l'API refuse en 400 depuis le contrat 11.0.0 (`API-60`) : conteneur
    trouvé par son label de service comme `scripts/_backup_common.sh`, heures murales de Paris
    (`wall()`). Le rafraîchissement quotidien de la prod (`OPS-28`) passe par le même script : il
    échouait à chaque nuit depuis le déploiement du 11.0.0 et ne repart qu'une fois le checkout
    `~/prod` de l'hôte à jour ;
  - `PdlSectionHeader` donnait la moitié de la ligne au titre (un `Flexible` face à un `Spacer`) :
    « Vos prochaines … » tronqué sur l'iPhone le plus large, « Voir tout » décollé du bord droit
    sur iPad. Titre et compteur prennent désormais tout ce que l'action laisse.
  `capture.sh` ne cherche plus le simulateur iPad pour une capture iPhone seule. Pas de test
  automatisé : relecture des 28 captures. Poussé le jour même : `asc metadata apply` (description et
  mots-clés, FR/EN), puis `asc screenshots upload --replace` sur les quatre jeux. **À ne pas défaire** : la troisième carte suppose une
  sortie à moins de sept jours — le seed la place au samedi suivant, capturer juste après lui.
- [x] `MOB-65` **Sens des tracés sur les cartes de l'app, comme au web** (11 octobre 2026, contrat
  inchangé) — le pendant mobile de `WEB-49` : un chevron répété le long de chaque tracé, dans
  l'ordre de ses points, sur toutes les cartes que dessine `PdlMapController` (sortie, parcours,
  voyage et étape). Même dessin que le site (`map/pdl_route_arrow.dart`, 16 points), mais
  `symbol-spacing` à 50 au lieu de 90 : MapLibre natif mesure l'espacement sur la tuile, et au
  cadrage d'une étape de 65 km il ne posait qu'un chevron, caché sous une borne kilométrique, teintes `mapArrow` / `mapArrowRim` dans `PdlColors`, identiques
  dans les deux thèmes comme l'ombrage. Pas sur la couche de masse (tous les parcours) : sans
  survol, il n'y a pas de tracé « courant » à flécher. Couvert par `pdl_map_controller_test.dart`
  (groupe « sens des tracés »). **À ne pas défaire** : les chevrons ont leur **propre source**, une
  entité par ligne entière — posés sur les tronçons d'un tracé colorisé par pente, ils tomberaient
  au hasard des coupures ; l'image est dessinée à 3× puis réduite par `icon-size`, parce que les
  greffons iOS et Android posent une image à un pixel par point (floue sur un écran 3× sinon) ; elle
  est reposée à chaque pose, un changement de fond de carte effaçant les images du style ; et
  `_raise` repasse la couche de chevrons au-dessus du tracé sélectionné qu'il vient de remonter.
- [x] `MOB-66` **Cartes sans voile sombre, plein écran sur la carte d'une étape** (11 octobre 2026,
  contrat inchangé) — relevé sur l'iPhone : le haut de la carte d'une étape de voyage était assombri
  et elle n'offrait pas de plein écran. `PdlMapHero` perd `topScrim` (il assombrissait les cartes de
  parcours et des pages plein écran) et `bottomScrim`, qui n'avait plus d'appelant. `RouteMap` prend
  `allowFullscreen`, que passe `EmbeddedRouteSheet` (la vignette d'une étape) : la fiche parcours,
  qui est déjà la carte en plein écran, reste sans bouton. Sans voile, la barre système suit le
  thème (icônes sombres en thème clair) au lieu d'être forcée en clair, et la page plein écran garde
  la barre hors de la carte (`SafeArea`). **Gestes** : une carte encastrée dans une page qui défile
  ne se déplace ni ne zoome (double tap compris) hors plein écran — la vignette d'une étape
  (`RouteMap.allowFullscreen`) et la carte d'un voyage (`TripMap`) rejoignent les groupes d'une
  sortie et l'annonce ; le tap (choix d'étape, réticule) reste actif. La fiche parcours et la carte
  des parcours, qui occupent l'écran, restent libres. Pas de test automatisé : relu sur
  simulateur (voile, chevrons) et sur iPhone (gestes).

### Recette sur une application qui tourne — 4 octobre 2026

Passe manuelle sur la prod, compte administrateur, en clair et en sombre, dans l'équipe `gaby-test1`
garnie pour l'occasion d'un jeu de données « Recette — … » créé par l'API : sorties à trois groupes
(dont un mené par un autre membre et un à une place), du jour, sans meneur, passée et annulée ; un
col synthétique et treize parcours d'étape ; un voyage de 13 étapes et deux voyages « Fuseaux » ;
une publication à liens et tableau, une autre faite de pièces jointes seules (image 1920 × 1080 et
PDF de 12 Mo) ; trois annonces ; une page d'équipe et un « à propos » à pièce jointe seule. Pas de
test automatisé : ce qui suit est ce que les tests ne savent pas dire. Trois défauts mineurs
relevés, `MOB-44` à `MOB-46`. Restent ouvertes `MOB-5`, `MOB-13`, `MOB-15`, `MOB-20` et `MOB-47` (le 500 de `MOB-12`).

- [x] `MOB-1` **Accueil (11)** — « Ma prochaine sortie » apparaissait inscrit et disparaissait
  désinscrit, le badge `INSCRIT` marquait les cartes du fil, la barre supérieure se rétractait sous
  la barre d'outils épinglée, cinq squelettes au chargement.
- [x] `MOB-2` **Sortie (12)** — les six états du bouton, dont `Complet` désactivé (un groupe à une
  place rempli par un autre membre), le `GROUP_FULL` qui restaure l'état et nomme le groupe ; rien sur
  une sortie passée (« Terminée ») ni annulée, pas même « Quitter » ; un tracé par groupe, sélection
  au tap.
- [x] `MOB-3` **Pastille « Organisateur »** — rendue sur le seul groupe qui a un `leader`, avec son
  nom ; rien sur les autres groupes ni sur une sortie sans meneur, jamais le créateur de la sortie.
- [x] `MOB-4` **Parcours (13)** — profil colorisé par pente, réticule fluide au glissement, section
  « Cols et montées » (son titre au pluriel avec une montée est `MOB-45`).
- [x] `MOB-6` **Calendrier (22)** — le mois s'affiche, les étapes du voyage y sont et pas le voyage,
  l'anneau « inscrit » marque l'événement, le jour à la fois « aujourd'hui » et « inscrit » porte les
  deux marqueurs.
- [x] `MOB-7` **Jeton ICS (22)** — après « Copier le lien », la capture d'écran ne montre pas le
  jeton, le presse-papiers porte l'URL réelle.
- [x] `MOB-8` **Fuseaux horaires (22, 24, 25)** — appareil en `Pacific/Auckland` puis
  `America/Los_Angeles` : l'étape du lundi 17 août 2026 à 08:00 n'a pas glissé d'un jour ; un fuseau
  posé dans le profil, différent de celui de l'appareil, l'emportait.
- [x] `MOB-9` **Voyage et étape (24, 25)** — tracé et profil ; à 13 étapes, le tracé du voyage s'est
  arrêté à 12, comme voulu.
- [x] `MOB-10` **Publication (31)** — liens interne absolu → route interne, externe → navigateur,
  `mailto:` → client mail, schéma inconnu → bandeau ; aucun lien inerte (le lien relatif vers une
  section d'équipe est `MOB-46`). Tableau à 4 colonnes défilant sans déborder la page.
- [x] `MOB-11` **Annonces (32)** — `1 200,00 €`, « 25,00 € / semaine », « Prix à négocier » ; la
  carte rend un secteur, jamais une punaise.
- [x] `MOB-12` **Contact du vendeur (32)** — sur une annonce d'un autre membre : 204 (confirmation),
  `AD_CONTACT_OPTED_OUT` (vendeur ayant coupé « Être contacté »), `AD_CONTACT_RATE_LIMITED` (11ᵉ
  message de l'heure, `Retry-After` dit « Réessayez dans 1 heure ») rendaient chacun leur écran ;
  bouton absent sur sa propre annonce ; 9 et 2 001 caractères refusés côté client. Le 500
  (`AD_CONTACT_DELIVERY_FAILED`), impossible à provoquer en prod, est scindé en `MOB-47`.
- [x] `MOB-14` **Découverte d'équipes (34)** — la loupe et le CTA d'état vide mènent quelque part,
  chip `joinable=true`, adhésion optimiste avec bandeau d'échec nommant la cause.
- [x] `MOB-16` **Deeplinks à froid** — application tuée, un lien de sortie, de parcours et d'annonce
  ouvraient le bon écran, onglet surligné et pile de retour cohérente.
- [x] `MOB-17` **Text scaling ×1,3 puis ×2,0** — badges, lignes de col, en-têtes épinglés : aucun
  débordement.
- [x] `MOB-18` **Pièces jointes** — le bloc apparaissait sur les huit écrans à `MediaDto` (sortie,
  publication, annonce, parcours, voyage, étape, page d'équipe, « à propos ») avec un fichier et
  disparaissait sans ; une publication et un « à propos » faits d'une seule pièce jointe sans texte
  affichaient le bloc. Noté en chemin : un asset ne s'attache qu'à un contenu : le joindre à un second
  est ignoré sans erreur (l'API répond 200 et le second contenu ne le porte pas) — `API-68`.
- [x] `MOB-19` **Une image jointe se regarde dans l'app** — sur une publication visible des seuls
  membres : visionneuse zoomable, sous-titre « 1920 × 1080 », le bouton rapportait l'originale vers
  la feuille de partage ; pour un PDF de 12 Mo, bandeau « Téléchargement en cours… » tenu, échec
  réseau en bandeau rouge, jamais de feuille de partage vide.

### Défauts trouvés par la recette du 4 octobre 2026

Corrigés le 4 octobre 2026, contrat inchangé. Les deux défauts de navigation n'en font qu'un.

- [x] `MOB-44` **Toucher l'équipe depuis un détail laissait une page vide** — une page de détail
  (sortie, parcours, publication, voyage, annonce) vit sur le navigateur racine, au-dessus du shell ;
  y faire `context.push` d'une page **d'onglet** (l'équipe, une de ses sections, de n'importe quelle
  équipe) recréait la branche sous le détail avec des clés de page déjà prises : assertion
  `!keyReservation.contains(key)` en debug, écran vide et `pop` qui lève, « parfois » en release.
  `pushLocation` (`core/utils/push_location.dart`) garde le `push` partout ailleurs et, dans ce seul
  cas, ouvre la page dans son onglet par `openWithHierarchy`, la pile d'un lien profond (Équipes →
  équipe → section) ; tous les `context.push(Paths.team(…))` passent par lui. Test :
  `test/core/utils/push_location_test.dart`, sur un routeur de même forme et les vrais chemins —
  ses trois cas « depuis une sortie » échouent sans le correctif. **À ne pas défaire** : ne pas
  revenir à `context.push` vers une page du shell depuis une page plein écran ; la pile affichée se
  lit en déroulant les `ImperativeRouteMatch`, jamais par `currentConfiguration.uri`, qui reste sur
  la base après un `push` impératif.
- [x] `MOB-45` **« Cols et montées (1) »** — `routes.climbs` est un pluriel (`one` « Col ou montée
  ({}) », « Climb ({}) » en anglais) lu par `.plural()` dans `route_climbs_section.dart`. Test :
  `route_climbs_section_test.dart` (une montée, deux montées).
- [x] `MOB-46` **Un lien relatif vers une section d'équipe ouvrait une page vide sans retour** — même
  cause que `MOB-44` : `openLink` (`core/utils/link_launcher.dart`) poussait par `context.push` toute
  route interne reconnue, depuis une publication plein écran. Il passe désormais par `pushLocation`.

### Erreurs remontées automatiquement — 6 octobre 2026

Issues du dépôt `pedalons-feedback`, corrigées le 6 octobre 2026, contrat inchangé.

- [x] `MOB-55` **La carte des parcours levait à chaque ouverture sous Android** (feedback #8) —
  `maplibre_android` 0.3.6 ne construit un `VectorSource` que sur `url` (`source.url!`) et la
  couche de masse est définie par `tiles` : `TypeError`, et toute la pile de couches qui suit
  (tracés, marqueurs, réticule) n'était pas posée. Sous Android, `PdlMassTiles.platformSource`
  écrit un TileJSON équivalent dans le cache de l'app et passe son URL `file://` ; iOS garde
  `tiles`. Une masse qui ne se pose pas n'emporte plus le reste (`_applyMassLayer` rattrape et
  journalise). Test : `pdl_mass_layer_test.dart` (le document TileJSON) ; constaté sur un Pixel 6a
  (Android, build debug) le 6 octobre 2026. **À ne pas défaire** : ne pas revenir à `tiles` sous Android tant que
  le greffon ne lit pas `VectorSource.tiles` (la liaison JNI sur `TileSet` existe, c'est
  `style_controller.dart` qui ne l'emploie pas).
- [x] `MOB-56` **La connexion levait quand Firebase n'avait pas démarré** (feedback #4) —
  `main.dart` tolère l'échec de `Firebase.initializeApp()`, mais le constructeur de
  `FirebasePushGateway` lisait `FirebaseMessaging.instance`, qui lève alors `[core/no-app]` :
  `pushGatewayProvider` passait en erreur à chaque connexion. `_messaging` est paresseux,
  `ensureInitialized` retente l'initialisation et, en cas d'échec, le push est simplement
  `unsupported`. **À ne pas défaire** : rien de Firebase ne doit être lu avant
  `ensureInitialized`.

### Couverture e2e Patrol

Écrits le 29 septembre 2026 par-dessus les P0 de l'audit de couverture e2e (`WEB-26`), un test
Patrol par scénario sous `mobile/patrol_test/` (tableau « Coverage » de son README). Ils ont trouvé
sept défauts de l'app, tous corrigés le même jour et nommés dans les entrées qui les ont trouvés,
plus un huitième hors scénario : un appui au-dessus d'une `PdlSheet` ne la refermait pas (la feuille
couvrait la barrière modale, dd207d81). Ce que chaque entrée laisse de côté est dit en « Non
couvert » ; les tests ne tournent qu'en local (`MOB-37`).

- [x] `MOB-25` **Annonces : carte de localisation et contact du vendeur** (29 septembre 2026) — la
  carte d'une annonce localisée montre son lieu, la légende « Localisation approximative », un
  secteur sur une carte qui ne dessine aucun point (ni repère, ni départ, ni arrivée, ni
  surcouche), centrée sur la cellule floutée à moins d'un kilomètre du point saisi et jamais
  dessus ; une annonce sans lieu n'a ni en-tête « Localisation », ni carte, ni secteur. Le contact :
  9, 2 001 et dix espaces laissent « Envoyer » désactivé, 10 et 2 000 l'activent ; un envoi réussi
  ferme la feuille et remplace le bouton par la confirmation, un seul mail relayé porte le
  brouillon, `Reply-To` l'acheteur, `From` jamais l'acheteur, aucune des deux adresses dans le
  corps, et l'annonce lue par l'API ne porte pas l'adresse du vendeur ; `AD_CONTACT_OPTED_OUT`
  (vendeur non contactable) ferme la feuille, pose le bandeau à la place du bouton et n'envoie
  rien ; le 11ᵉ message de l'heure (`RATE_LIMITED`, `Retry-After` 3 600) dit « Réessayez dans
  1 heure », garde le brouillon, passe le bouton à « Réessayer » et la page garde « Contacter le
  vendeur » — `ad_location_map_test.dart`, `ad_contact_test.dart`,
  `ad_contact_opted_out_test.dart`, `ad_contact_rate_limited_test.dart`. *Non couvert :
  `DELIVERY_FAILED` (500) — mailpit accepte tout, la stack réelle ne sait pas faire échouer le
  relais sans un crochet de test (le web le simule par `page.route`) ; le rendu en pixels du
  secteur (le web mesure la teinte du canvas, ici seul l'arbre de widgets est vérifié).*
- [x] `MOB-27` **Sorties passées et annulées** (29 septembre 2026) — une sortie de la veille, restée
  `PUBLISHED`, affiche « Terminée » et aucun de ses deux groupes ne propose « Rejoindre », « Quitter »
  ni « Complet » ; une sortie annulée derrière l'app (PUT du `RideRequest` complet, statut
  `CANCELLED`, comme l'éditeur web) affiche son bandeau, et la carte du groupe n'offre rien, pas même
  « Quitter » à un inscrit que l'API compte toujours comme tel — `ride_past_cancelled_test.dart`.
  *Non couvert : le refus `409 RIDE_PAST` de l'API (couvert côté web), la carte « Ma prochaine sortie »
  d'une sortie annulée.*
- [x] `MOB-28` **Écrans d'erreur sur un 5xx** (29 septembre 2026) — un 500 sur l'équipe puis sur la
  sortie est retenté trois fois par `providerRetry` (au moins 3 s, quatre requêtes pour la sortie),
  puis la page affiche son erreur — « Erreur de chargement » pour la sortie, pas l'« introuvable »
  d'un 404 ; une fois le serveur rétabli, « Réessayer » charge la page — `load_error_retry_test.dart`.
  Le 500 est fabriqué côté app par un intercepteur que le test ajoute au `Dio` authentifié
  (`patrol_test/server_errors.dart`), comme `page.route` côté web : la stack e2e ne sait pas échouer
  à la demande, et `lib/` ne porte aucun crochet de test. *Non couvert : un 5xx réellement émis par
  le serveur, l'erreur hors ligne (`errors.offline`), les autres écrans en erreur (voyage, article,
  parcours, annonce).*
- [x] `MOB-29` **Notifications des autres sujets** (29 septembre 2026) — `RIDE_CANCELLED` : une
  sortie annulée par son organisatrice (PUT du `RideRequest`, statut `CANCELLED`) n'atteint que
  l'inscrit, jamais le membre non inscrit ; l'entrée dit « Une sortie est annulée » avec le nom de la
  sortie, et ouvre la sortie sous son bandeau d'annulation — `notification_ride_cancelled_test.dart`.
  `RIDE_JOINED` : un cycliste s'inscrit depuis l'app ; la notification, qui nomme le cycliste et porte
  le groupe en `excerpt`, atteint le créateur de la sortie **et** le meneur du groupe
  (`RideGroupDto.leader`, distinct du créateur), jamais le cycliste lui-même ; l'entrée lue par le
  meneur nomme le cycliste et le groupe, et ouvre la sortie — `notification_ride_joined_test.dart`.
  *Non couvert : les autres types du sujet sortie (`RIDE_PUBLISHED`, `RIDE_UPDATED` et ses variantes
  de libellé, `RIDE_REMINDER`, `RIDE_GROUP_REMOVED`), `TRIP_*`, `CONTENT_REPORTED` (qui ouvre le web),
  et la réception push (FCM absent de la stack e2e).*
- [x] `MOB-30` **Parcours** (29 septembre 2026) — un cycliste d'aucune équipe cherche dans l'onglet Parcours : le parcours public d'une équipe publique sort, jamais son parcours réservé aux membres ni celui d'une équipe privée (aussi vérifié par `/api/routes`) ; la bascule liste/carte garde la recherche ; la fiche du parcours dessine son profil altimétrique (tiré du GPX téléversé) et « Utilisée dans » ne nomme que la sortie publique. Un membre trouve les deux parcours de l'équipe ; un filtre de revêtement réduit la liste, un filtre sans résultat mène à l'état vide filtré ; « Utilisée dans » ajoute la sortie réservée aux membres et le voyage (« via l'étape … »), jamais la sortie sans parcours — `routes_visibility_test.dart`. *Non couvert : le tracé sur la carte et le popup de la vue Carte (tuiles et valhalla absents de la stack e2e, seule la présence de la vue est vérifiée), la section Parcours d'une équipe, les autres filtres (distance, dénivelé, vent, « Autour de moi »), le tri et la densité.*
- [x] `MOB-31` **Calendrier** (29 septembre 2026) — l'onglet Calendrier d'un membre de deux équipes montre les sorties des deux, jamais la sortie publique d'une équipe publique dont il n'est pas ; chaque carte nomme son équipe, « Inscrit · Groupe A » sur la seule sortie rejointe ; un événement ouvre sa sortie. La section Calendrier de l'équipe ne montre que cette équipe ; « Copier le lien » met au presse-papiers l'URL du flux d'équipe (`teamFeedUrlTemplate`, slug inséré, chemin `/api/teams/{slug}/calendar/ics`), « Régénérer le lien » change le jeton (vérifié par l'API) et la copie suivante donne la nouvelle URL — `calendar_test.dart`. *Non couvert : « S'abonner » (`webcal://`, rien pour le recevoir sur le simulateur), le contenu du flux ICS lui-même (déjà couvert côté web), les étapes de voyage et les filtres de type du calendrier.*
- [x] `MOB-32` **Réglages du profil** (29 septembre 2026) — le nom affiché s'enregistre ; unités
  impériales (l'exemple chiffré passe en milles), thème sombre (l'app se redessine en sombre),
  « Être contacté par les membres » coupé et langue anglaise (la ligne dit « English »), puis
  retour au français : tout arrive sur `/api/users/me`, et l'interrupteur coupé fait refuser le
  relais d'annonce `AD_CONTACT_OPTED_OUT`. L'export de données : « Jamais demandé », « Demander
  un export » → « En préparation… », le mail du scheduler porte le lien de téléchargement, et le
  profil rouvert dit « Prêt » (l'API `READY`) — `profile_preferences_test.dart`, `profile_data_export_test.dart`.
  « Déconnecter tous les appareils » ramène à la connexion, refuse le refresh token de cet
  appareil et celui d'un autre, et le mot de passe connecte toujours —
  `profile_logout_all_test.dart`. Trois défauts trouvés en chemin et corrigés le même jour : un export `READY` restait « En préparation… » (le
  code attendait un statut `COMPLETED` absent du contrat, 8ef911d0) ; `logout-all` partait sans jeton et
  ne révoquait rien (1dab921c) ; les appels authentifiés sous `/api/auth/` (`getMe`,
  gestion des clés d'accès, `logout-all`) ne rafraîchissaient pas un jeton expiré (08aa46ef). *Non couvert : l'avatar (sélecteur de photos natif du
  système) ; les services GPS connectés (OAuth Strava/Garmin hors stack) ; le téléchargement de
  l'archive (lien du mail, pas de bouton dans l'app).*
- [x] `MOB-33` **Signalement au-delà des publications et commentaires, suppression par un modérateur** (29 septembre 2026) — un membre signale une sortie, un voyage, un parcours et une annonce depuis leur `⋯` (`showDetailModerationMenu`) : chaque page se ferme derrière le signalement et l'administrateur de l'équipe trouve chacun dans la file ouverte (`/api/teams/{slug}/reports`) — `report_details_test.dart` ; il signale un coéquipier depuis la section « Membres » (le menu propose aussi de le bloquer) et un participant depuis la feuille des participants d'une sortie, les deux signalements de membre arrivant dans la file — `report_members_test.dart` ; un organisateur (pas l'auteur de l'article) supprime le commentaire d'un membre depuis son `⋯`, qui le retire du fil et de l'API — `comment_moderator_delete_test.dart`. *Non couvert : le signalement depuis une étape de voyage et depuis la feuille des participants d'un voyage, ce que le modérateur voit de la file dans l'app (elle n'a pas d'écran de file : vérifié par l'API).*
- [x] `MOB-34` **Listes : pagination et filtres** (29 septembre 2026) — sous une équipe dédiée, le défilement atteint l'entrée que l'API place en page 2 (demandée à l'API, pas déduite du tri) : fil d'équipe et fil d'accueil (21 articles et une sortie), annonces (22), membres (22), commentaires d'un article (21) ; les puces de type du fil (« Sorties », « Articles ») et des annonces (« Recherche ») filtrent, une recherche sans résultat mène à l'état vide filtré (fil, annonces), la recherche des membres réduit la liste à un nom — `feed_pagination_test.dart`, `ads_members_pagination_test.dart`, `comments_pagination_test.dart`. Le test des commentaires a mis au jour un défaut, corrigé le même jour (231c2188) : le fil ne chargeait jamais sa deuxième page, les commentaires au-delà du 20ᵉ étaient inaccessibles. Sur Android, ce correctif ne tenait pas : le pied du fil se mesurait dans l'écouteur de défilement, avant la mise en page de la frame, donc en retard d'un cran, et au dernier cran (sans rebond comme sur iOS) il se croyait encore loin. Il se mesure depuis le 29 septembre après la frame (`_NearViewportTrigger._onScroll`), testé sur une liste à slivers comme les pages (« un seul cran jusqu'en bas, sans rebond ») ; **ne pas remesurer dans l'écouteur**. *Non couvert : la portée « rôle minimum » du fil d'accueil, les filtres de prix et de proximité des annonces, les puces de rôle des membres, le bouton « Voir plus de commentaires » (défiler suffit), les listes de découverte des équipes et de mes participations.*
- [x] `MOB-35` **Détail d'une sortie : participants et exports** (29 septembre 2026) — « Voir la
  liste » réunit les inscrits des deux groupes (total 2, une ligne chacun, ni le lecteur ni le
  créateur) ; la pastille de la carte des groupes nomme le premier groupe, puis celui dont on touche
  la carte ; la carte de groupe propose « GPX » (et « FIT » si le parcours en a un) d'après les assets
  du parcours, pas « Envoyer vers un appareil » sans service GPS connecté, et « GPX » ouvre la feuille
  de partage du système sur un fichier GPX (lue dans l'arbre natif) — `ride_participants_map_test.dart`.
  Deux défauts trouvés en chemin et corrigés : les exports n'étaient pas câblés sur la carte de groupe
  (05b20faf), et changer de groupe levait « pdl-track-src already exists » (poses de la carte non
  sérialisées, ec5df0df). *Non couvert : l'envoi vers un appareil (il faut un service GPS connecté
  par OAuth, hors de portée de la stack e2e), l'export FIT jusqu'à la feuille de partage, les tracés
  eux-mêmes (vue native MapLibre, illisible par Patrol) et le plein écran de la carte.*
- [x] `MOB-36` **Écrans périphériques** (29 septembre 2026) — la page Applications, ouverte depuis le
  profil, refuse une adresse mal formée (« Email invalide ») et enregistre l'inscription à la
  bêta (« Inscription enregistrée ») ; la même adresse en capitales répond pareil et la liste
  d'administration ne la compte qu'une fois. Déconnecté, depuis le formulaire d'inscription,
  « Confidentialité » et « Lire les conditions » ouvrent leur texte et le retour ramène au
  formulaire. « Signaler un problème » garde « Envoyer » désactivé sous 10 caractères, envoie
  une suggestion (`POST /api/feedback`), se ferme et remercie. Sans `PUSH` dans les canaux du
  serveur, la boîte de réception ne montre aucun bandeau d'activation —
  `apps_beta_signup_test.dart`, `legal_pages_test.dart`, `report_problem_test.dart`,
  `push_banner_absent_test.dart`. *Non couvert : le bandeau d'activation du push dans ses états
  `notDetermined` → dialogue système → `granted`, et `denied`. Il faudrait une stack e2e qui
  pousse (compte de service FCM, `PEDALONS_PUSH_ENABLED=true`) et des APNs sur le simulateur.
  Le signalement n'est vérifié que par le 204 et l'interface : aucune API ne relit un
  signalement (il part en issue GitHub). Le bouton « Télécharger l'APK » ouvre un lien externe
  et n'est pas suivi.*
- [x] `MOB-38` **Un jeton d'accès refusé, de bout en bout** (30 septembre 2026, contrat inchangé)
  — l'app ouverte et connectée reçoit un jeton d'accès que le serveur refuse, le jeton de
  rafraîchissement restant valide (`replaceAccessToken` de `patrol_test/common.dart`) : le profil
  charge quand même (le badge « Mes sorties à venir », `GET /api/users/me/participations`) avec un
  jeton neuf, et « Déconnecter tous les appareils », sous `/api/auth/`, atteint le serveur — la
  session d'un autre appareil ne se rafraîchit plus. C'est le cycle 401 → rafraîchissement → nouvel
  essai que l'intercepteur fait sur son propre `Dio`, hors de portée des tests unitaires de
  08aa46ef. `expired_access_token_test.dart`, lancé sur la pile e2e le 30 septembre 2026 (`fixes`
  @ `4d9b4db2`) : vert sur le simulateur iOS (iPhone 17 Pro Max, iOS 26.5) et sur l'émulateur
  Android (Pixel 7, API 36), dans les passes Patrol complètes, 57 / 57 sur chacune. *Non couvert : un jeton réellement expiré (signé, `exp` passé) plutôt que
  refusé, et plusieurs appels en file pendant un même rafraîchissement.*

### Tags d'équipe

- [x] `MOB-39` **Tags d'équipe dans l'application** (1er octobre 2026, API 10.1.0, plan archivé
  [`2026-10-01-tags.md`](plans/archive/2026-10-01-tags.md) §6) — affichage et filtre, ni
  étiquetage ni admin (D20). Les tags d'un contenu sont rendus par `PdlTagRow` (`core/pdl/pdl_tag.dart`)
  via `ContentTagRow` (`features/tags/presentation/content_tags.dart`) : en carte (sortie, post,
  voyage du fil d'équipe, parcours, annonce) les `kCardTagLimit` = 3 premiers puis « +n », en fiche
  tous. Filtre par tag (`tag_filter.dart`, feuille multi-sélection, OU) sur les listes d'équipe
  dédiées : sorties, posts et voyages (le fil restreint à un type), parcours (`route_filter_chips_bar`),
  annonces (`ads_toolbar`) ; pas de chip quand l'équipe n'a aucun tag du type, ni sur le fil mixte
  (D13). Tests : `pdl_tag_test.dart`, `tag_filter_test.dart`, `team_list_tag_filter_test.dart` —
  `flutter test` vert (724 tests). **À ne pas défaire** : un tag est une **pastille** de la famille
  et un libellé neutre, jamais un `PdlBadge` (D10, un tag vert ne doit pas se lire « Publié ») ; la
  troncature est la même que sur le web — « +n » seulement quand au moins **deux** tags seraient
  cachés (4 tags pour une limite de 3 : les 4 montrés), pour qu'un contenu ait la même carte partout.

### Accueil membre

- `MOB-42` **Accueil membre : « Cette semaine », « Mes équipes », envoi vers l'appareil** (3 octobre
  2026, **API 10.6.0**). « Cette semaine » (`weekEventsProvider` : un `GET /api/calendar/events`,
  aujourd'hui 00:00 → +7 jours dans le fuseau d'affichage, événements finis retirés, prochaine
  sortie exclue, 5 lignes au plus, « rien d'autre » quand elle est seule) ; « Mes équipes »
  (`myTeamsProvider`, badge de rôle via `TeamRoleTone`, ligne d'activité depuis `upcomingRideCount`
  / `upcomingTripCount` / `recentPostCount` sans les zéros, repli `teams.membersList.count`,
  « Trouver une équipe » seulement si `ConfigDto.singleTeam == false`) ; action d'envoi sur « Ma
  prochaine sortie » (parcours du groupe, sinon de la sortie ; `pickGpsService` /
  `uploadRouteToService`). L'écran de connexion ouvre `/fonctionnalites` du site
  (`openWebPage(Paths.features())`). Tests : `home_member_sections_test.dart`,
  `login_discover_features_test.dart`, `link_launcher_test.dart`. **À ne pas défaire** : aucun appel
  par équipe ni par événement, tout vient des listes ; `weekEventsProvider` est rechargé dans
  `notifyParticipationChanged` et `refreshAfterReport` ; `features` est dans `webOnlyRouteIds`
  (l'app n'a pas d'écran pour elle) ; `calendarEventTap` est partagé par `AgendaCard` et l'agenda
  d'accueil.

- `MOB-43` **Carrousel « À venir » retiré de l'accueil** (4 octobre 2026, décidé avec le
  propriétaire). Il doublait « Cette semaine » (`MOB-42`). Supprimés avec lui : `upcomingProvider`,
  le widget, ses clés, les libellés `home.upcoming`, `home.upcomingScope`, `home.chooseGroup`, et
  l'inscription automatique qu'ouvrait son bouton « Rejoindre » sur `RideDetailPage` (seul
  appelant). Tests : `participation_changes_test.dart` vérifie qu'une inscription recharge « Cette
  semaine » ; `upcoming_action_test.dart` et le test Patrol `upcoming_carousel_order_test.dart` sont
  supprimés. **À ne pas défaire** : plus aucun test de bout en bout ne couvre le tri « plus proches
  d'abord » (`sortDir=ASC`) de `/api/publications`, dont l'app ne dépend plus.

### Profil

- `MOB-48` **Le profil en vue d'ensemble et sous-pages, même arbre que le site** (4 octobre 2026,
  **API 10.7.0**, maquette validée du 4 octobre). L'onglet Profil est une **racine** (plus de flèche
  retour sur `/profil`) : carte d'identité (vers Mon compte), puis des raccourcis groupés, chacun
  avec sa **ligne d'état** — Mon activité (Mes sorties : « Prochaine : … » et compteur ; Mes équipes,
  qui ouvre l'onglet Équipes), Réglages (Préférences, Notifications, Appareils et services),
  Sécurité et confidentialité (Connexion et sécurité, Confidentialité), Compte (Mon compte — ligne
  ajoutée le 4 octobre, clé `keys.profile.accountRow`, statut fixe « Photo, nom affiché, suppression
  du compte » —, Aide et à propos, Se déconnecter). Une route par sujet dans la branche Profil du
  shell (`config/router.dart`), sous `ProfileSubpage` (retour : `pop`, sinon `go` vers `/profil` ;
  flèche retour de `PdlAppBar` clé `keys.profile.backButton` via le nouveau paramètre `backKey`) :
  `/profil/sorties` (À venir ·
  Historique), `/profil/preferences` (unités, **fuseau horaire, nouveau dans l'app**, même champ
  `UserDto.timezone` que le site, feuille de recherche `timezone_sheet.dart`), `/profil/notifications`
  (`notification_settings_page.dart` : une ligne par type groupée en familles Sorties, Voyages,
  Publications, Équipes et modération, une **puce à bascule par canal** E-mail/Push, Annonces des
  équipes, « Ouvrir mes notifications » ; la boîte de réception a un bouton Réglages),
  `/profil/appareils`, `/profil/securite` (Clés d'accès, `LogoutAllCard`), `/profil/vie-privee`
  (Être contacté par les membres, Utilisateurs bloqués, Rapports d'erreur, Mes données), et sa
  sous-route **`/profil/vie-privee/bloques`** (EN `/profile/privacy/blocked`, déplacée de
  `/profil/bloques` le 4 octobre) : route go_router **enfant** de `profilePrivacy`
  (`_profilePrivacyRoutes()`), ancêtres de lien profond Profil › Confidentialité, plus de repli
  spécial du retour ; `/profil/compte` (identité, `DeleteAccountSection`), `/profil/aide`. Les
  lignes d'état lisent `/me` et `profileSummaryProvider` (`GET /api/users/me/profile-summary`,
  `API-69`) ; `participationCountProvider` est supprimé. Tirer pour rafraîchir la vue d'ensemble
  relit le résumé **et** `/me` (`refreshCurrentUser`, échec de `/me` ignoré) ;
  `ProfileSummaryRefreshOnLeave` (`profile_subpage.dart`, autour de `ProfileSubpage`,
  `MyParticipationsPage` et `BlockedUsersPage`) invalide `profileSummaryProvider` quand **toute**
  sous-page quitte l'arbre, lien profond suivi d'un `pop` compris — la vue d'ensemble n'invalide
  plus après son `push`. `PdlChip` répond sur toute sa boîte de 44 px (un `GestureDetector` opaque
  autour de la pastille de 34 px), pour **toutes les puces de l'app** (tests de filtres
  `route_filters`, `route_filter_chips_bar`, `route_filter_sheet`, `tag_filter`,
  `team_list_tag_filter`, `publication_feed_toolbar` verts). Le lexique vaut aussi hors du profil
  (`WEB-57`). Tests : `test/features/profile/profile_overview_test.dart` (ligne Mon compte,
  tirer pour rafraîchir), `profile_summary_refresh_test.dart` (sous-page ouverte par lien froid
  puis `pop` : le résumé est relu), `profile_subpages_test.dart`,
  `profile_page_test.dart` (fuseau envoyé au serveur), `profile_summary_provider_test.dart`,
  `test/features/notifications/notification_settings_page_test.dart`,
  `test/deep_link_hierarchy_test.dart` (les nouvelles routes, `blockedUsers` → [profile,
  profilePrivacy]), `test/core/pdl/tap_target_test.dart`
  (« PdlChip répond aussi dans les 5 px autour de sa pastille »),
  `test/features/rides/participation_changes_test.dart` ; Patrol `notification_settings_test`,
  `profile_timezone_test`, `block_user_test` (lien froid vers les bloqués, retour sur
  Confidentialité) et les tests du profil repris (modules `Profile.openX` / `backToOverview` et
  `Moderation.backToPrivacy`, qui touchent `keys.profile.backButton`), verts depuis le 6 octobre
  2026 (`MOB-49`). **Tranché avec le propriétaire le 4 octobre** : ligne « Mon compte » dans le groupe
  Compte (en plus de la carte d'identité) ; **pas de cloche dans l'en-tête du Profil** (un `push`
  d'une branche à l'autre empilerait les branches — la boîte de réception reste à un onglet) ;
  Utilisateurs bloqués **sous** Confidentialité, dans l'URL comme dans la pile. **À ne pas
  défaire** : pas de cloche dans l'en-tête du Profil (`MOB-50`) ; la route des bloqués reste imbriquée sous
  `profilePrivacy` (c'est ce qui met Confidentialité sous elle quand elle est ouverte par `go`) ;
  l'invalidation de `ProfileSummaryRefreshOnLeave` passe par `scheduleMicrotask` (invalider dans
  `dispose` lève « markNeedsBuild called when widget tree was locked ») ; un **arbre unique et un
  lexique commun** aux deux clients (Profil, Nom affiché, Adresse e-mail, Clés d'accès, Mon compte,
  Demander mes données, Être contacté par les membres, Résumé quotidien par e-mail, Annonces des
  équipes) — un sujet change de place ou de nom des deux côtés à la fois ; une route `/profil/<sujet>`
  par sujet, jamais d'ancre ; les canaux affichés sont **ceux que le serveur déclare**
  (`channels`) : sans `EMAIL`, ni puce E-mail ni résumé quotidien, `IN_APP` jamais réglable ; une
  puce n'écrit que sa cellule ; les lignes d'état viennent de `/me` + profile-summary, jamais d'un
  appel par sujet ; `notifyParticipationChanged` et `refreshAfterBlockChange` invalident
  `profileSummaryProvider`, qui se recharge aussi quand l'ensemble de mes équipes change
  (`myTeamsProvider`) ; Se déconnecter une seule fois dans le profil ; la navigation entre branches
  (profil → boîte de réception ou Équipes, boîte → réglages) passe par `go`, jamais `push` ; l'ouverture
  d'une sous-page passe par `pushLocation` (`MOB-44`), qui reprend la pile du lien profond quand on
  part d'une page plein écran (`test/core/utils/push_location_test.dart`).
- `MOB-49` **Tests Patrol du profil refondu lancés** (6 octobre 2026) — les dix-sept tests que
  `MOB-48` et `WEB-57` touchent (`notification_settings_test`, `profile_timezone_test`,
  `profile_preferences_test`, `profile_data_export_test`, `profile_logout_all_test`,
  `profile_paired_devices_test`, `profile_participations_count_test`,
  `profile_participations_list_test`, `account_deletion_test`, `expired_access_token_test`,
  `notification_mute_test`, `block_user_test`, `report_problem_test`, `apps_beta_signup_test`,
  `login_with_password_test`, `sign_up_verify_test`, `password_reset_test`) sont verts dans la
  suite Patrol iOS complète (63/63 à `c3532d63`, pile e2e remise à zéro, iPhone 17 Pro Max), et
  de nouveau le 7 octobre à `86788c92` (les deux échecs de ce run, `calendar_test` et
  `user_timezone_test`, sont hors du profil).
  `profile_paired_devices_test` attendait la ligne d'un appareil par `scrolledTo`, qui touche son
  centre : seule la croix « délier » y prend les touchers, il passe par `scrolledIntoView`
  (`7efc822c`) — l'app n'était pas en cause. La recette sur appareil et les finitions restent en
  `MOB-62`. **À ne pas défaire** : une ligne sans centre touchable s'attend par `scrolledIntoView`,
  pas par `scrolledTo`.

### Météo des sorties

- `MOB-51` **Météo des sorties au mobile** (5 octobre 2026, contrat `10.9.0`, `API-74`).
  `RideRepository.getRideWeather` et `rideWeatherProvider` (`FutureProvider.autoDispose.family` par
  `RideKey`) nourrissent une carte compacte sous le bloc date et lieu du détail (groupe =
  `selectedRideGroupProvider`) et l'écran « Météo du parcours » (`ride_weather_page.dart`, poussé
  par `Navigator.push`, sans route au contrat) : sélecteur de groupe, départ avec lever et coucher
  du soleil, étape (heures, vitesse et mention de la vitesse par défaut, vent dominant, alerte
  pluie), exposition au vent (`PdlSegmentBar`), frise des points avec `PdlWindArrow` teintée par
  `RelativeWind` et doublée d'un badge, attribution Open-Meteo.com. Une étape qui n'est ni `OK` ni
  `STALE`, ou sans point, n'affiche qu'un bandeau `rides.weather.legUnavailable`. Le détail a gagné
  un pull-to-refresh, qui recharge aussi la météo. `RideWeatherSummaryLine` est dans
  `PublicationCard` (fil et fil d'équipe) et `NextRideCard`, avec une icône discrète pour `STALE`.
  °C/°F dans `unit_system.dart`, `AppFormatters.formatTemperature` (sans « -0 »),
  `formatTemperatureRange`, `formatPrecipitation`, `formatPercent`. Tests :
  `ride_weather_display_test`, `ride_weather_page_test`, `ride_weather_summary_line_test`,
  `ride_card_weather_test`, `pdl_weather_widgets_test`, les cas météo de `ride_detail_page_test`,
  `unit_system_test`, `formatters_test`. **À ne pas défaire** : une seule table de rendu
  (`features/rides/domain/ride_weather_display.dart`), qui passe chaque enum reçu par le `fromJson`
  généré et omet une valeur inconnue ; `NO_LOCATION` n'est montré qu'aux organisateurs,
  administrateurs d'équipe et de la plateforme (`canSeeWeatherNoLocation`) ; aucun appel pour une
  sortie terminée ou annulée ; `PdlWindArrow` et `PdlSegmentBar` restent génériques (aucun DTO,
  aucune traduction dans `core/pdl`) ; les précipitations restent en mm même en impérial ; pas de
  teinte par condition (voir `WEB-60`). `RideCard`, d'avant la v2 et sans écran qui l'utilise, n'a
  pas reçu la ligne de résumé.
- `MOB-57` **Météo des étapes de voyage au mobile** (6 octobre 2026, contrat `10.11.0`, `API-76`).
  `TripRepository.getTripWeather` et `tripWeatherProvider` (`FutureProvider.autoDispose.family` par
  `TripKey`). L'écran 24 apparie `stages[].summary` aux étapes par `stageId` et affiche
  `RideWeatherSummaryLine` sur chaque `StageCard`. L'écran 25 montre `StageWeatherCard` sous le bloc
  date et lieux (état propre de l'étape : badge ancien, date d'ouverture, « Réessayer »,
  `NO_LOCATION` aux seuls organisateurs, rien pour `OUT_OF_RANGE`), qui pousse `StageWeatherPage`
  (`Navigator.push`, le seul leg de l'étape, sans sélecteur de groupe ni bloc départ). Les sections
  de `ride_weather_page.dart` sont sorties dans `weather_leg_sections.dart` et les cartes de
  `ride_weather_card.dart` rendues génériques (`WeatherForecastCard`…), partagées par les deux.
  Pull-to-refresh : le détail de voyage recharge aussi la météo ; l'écran 25 en a gagné un. Aucun
  appel pour un voyage terminé ou annulé. Clés `trips.weather.*` (fr, en). Test :
  `trip_weather_test.dart`. Un voyage sans étape (une entrée sans `stageId`) n'affiche rien.

---

### Tableau de bord d'équipe

- `MOB-53` **Tableau de bord d'équipe, parité avec le web** (6 octobre 2026, **API 10.8.0**,
  `API-79`, `WEB-63`). Pour un membre, l'adresse de l'équipe ouvre le tableau de bord
  (`team_dashboard_page.dart`, `widgets/dashboard/`, `teamDashboardProvider`) ; le fil est à
  `?tab=publications`, comme au web, pour que les liens du site ouvrent la même vue. Mêmes sections
  et mêmes variations par rôle qu'au web, modes clair et sombre, sans débordement à 320 px. Les
  actions d'édition, de modération et d'administration ouvrent le site dans le navigateur intégré
  (`team_web_paths.dart`), l'app n'ayant pas ces écrans (`MOB-24`). Tests :
  `team_dashboard_test.dart`, `team_web_paths_test.dart` ; suite complète verte (809 tests) avant
  les dernières retouches, `test/features/teams` (55) après. **À ne pas défaire** : les blocs
  organisateur et admin ne s'affichent que si l'API les envoie, l'écran ne déduit pas le rôle ;
  `notifyParticipationChanged` invalide `teamDashboardProvider` ; « Inviter » n'apparaît qu'avec
  `team.addMemberAllowed` ; la barre de remplissage d'un groupe est lue comme une seule phrase.
- `MOB-54` **Adresses du site du tableau de bord générées depuis `routes.yaml`** (6 octobre 2026,
  sans changement de contrat d'API). Les pages du site qu'ouvre le tableau de bord (`rideNew`,
  `rideEdit`, `postNew`, `postEdit`, `tripEdit`, `rideTemplates`, `teamAdminReports`,
  `teamAdminMembers`, `teamSettings`) sont déclarées `mobile: true` + **`appScreen: false`** dans
  `contracts/routes.yaml` — un nouveau champ de `scripts/generate-routes.mjs`, documenté dans
  `docs/APP_LINKS.md` : le builder Dart est émis, mais la route n'a pas d'écran dans l'app, ne
  peut pas être un deeplink, et son nom rejoint l'ensemble `webOnlyRouteIds` désormais **généré**
  dans `paths.generated.dart` (il était écrit à la main dans `link_launcher.dart`, avec `features`
  seul). `team_web_paths.dart` ne fait plus que déléguer à `Paths.*` et ajouter les paramètres de
  requête (`?template=`, `?invite=1`) ; `NotificationDisplay.webPath` passe aussi par
  `Paths.teamAdminReports`. Les chemins suivent donc la langue de l'app (`/equipes/…` en
  français), que le site sert comme l'anglais. Tests : `team_web_paths_test.dart` (les deux
  langues, et chaque page du tableau de bord dans `webOnlyRouteIds`), `link_launcher_test.dart`
  (« couvre toutes les entrées de PathVariants »), `notifications_page_test.dart`. **À ne pas
  défaire** : une adresse du site ouverte depuis l'app vient de `Paths`, jamais d'une chaîne ;
  une page sans écran est `appScreen: false`, pas ajoutée à la main à `webOnlyRouteIds` ni à
  `internalRouteTemplates` (la pousser sur le routeur mènerait à une route inconnue). La
  reconnexion que peut demander le navigateur intégré n'est pas traitée ici : ledger `MOB-58`.

- `MOB-60` **L'équipe découpée en Agenda et Publications, comme au web** (6 octobre 2026, contrat
  inchangé — il lit `when` et `endDateTime` de la `10.15.0` et le tableau de bord public de la
  `10.16.0`), plan [`2026-10-06-team-agenda.md`](plans/archive/2026-10-06-team-agenda.md) §6, publié avec
  `WEB-68`.
  - **Sections** (`team_sections.dart`) : `TeamSectionKind` perd `feed` et `calendar`, gagne
    `agenda` et `posts`, dans l'ordre du site — Tableau de bord, Agenda (sorties ou voyages, et les
    parcours), Publications (`enablePosts`), Parcours, Annonces (membres), Membres, À propos. Le
    tableau de bord est à l'adresse de l'équipe **pour tout le monde** (`API-86`) ; un visiteur n'y
    a ni badge de rôle ni « S'abonner au calendrier ». « Voir tout » : « Mes prochaines » →
    `teamAgenda?w=me`, « Prochaines sorties » → `teamAgenda`, « Dernières publications » →
    `teamPosts` ; la cellule « sorties à venir » de l'en-tête mène à l'Agenda.
  - **Agenda** (`team_agenda_page.dart`) : `PublicationFeedView` avec la période « À venir /
    Je participe / Passées » (`when=UPCOMING|PAST` + `participating`, le serveur triant), les
    chips Tout / Sorties / Voyages, les tags du type choisi et la recherche ; le nombre de
    résultats (« 5 sorties et voyages à venir », les neuf tournures du site) ; l'état vide « Rien à
    l'agenda pour le moment » et « Voir les passées ». Une bascule Liste / Calendrier, icônes
    seules (`PdlSegment.iconOnly`), rend `CalendarPage` filtré sur l'équipe — membres seulement ;
    en calendrier la période devient « Tout / Je participe », filtrés en mémoire comme le type
    (`CalendarMonth.filtered(registeredOnly:)`). **Publications** : `PublicationFeedView` sur
    `type=POST`, sans chip de type ni filtre de date.
  - **`PublicationFeedView`** gagne `when`/`participating` (dans `PublicationFeedKey`), un type
    piloté par l'appelant (`selectedType` + `onTypeChanged`), `typeOptions`, `filterScope`
    (`agenda/<slug>`, `posts/<slug>` : recherche et tags d'une section ne passent pas à l'autre),
    `toolbarHeader`, `countLabel` et un état vide paramétrable. `initialType` et `TeamFeedPage`
    sont supprimés.
  - **Adresses** (`router.dart`) : `teamAgenda` (lit `?type=` et `?w=`), `teamPosts`,
    `teamCalendar` (l'Agenda en vue Calendrier), `teamRides` → l'Agenda, `teamTrips` → l'Agenda
    sur les voyages ; l'adresse nue lit encore `?tab=publications`, `?type=` et `?w=` avec les
    redirections du site (`resolveTeamRootSection`). Le relais provisoire vers le fil est retiré.
    `_deepLinkHierarchies` range une sortie, un voyage et une étape sous l'Agenda, une publication
    sous les Publications — l'Agenda est un parent **logique** d'une sortie, pas un préfixe de
    son adresse, ce que `deep_link_hierarchy_test.dart` admet pour lui seul.
  - **« En cours »** (`teams/domain/publication_timing.dart` `isUnderWay`) : départ passé et
    `endDateTime` à venir, sortie annulée exclue, comparés en UTC — badge vert doux à pastille
    (`PdlDerivedTones.underWay`, `PdlBadge.dot`) à la place de « Terminée », sur les cartes de
    sortie et de voyage. La fin s'affiche « demain 08:30 → retour vers 14:10 » (`rideTimeSpan`),
    un voyage « ven. 16 → dim. 18 oct. » (`tripDaySpan`) ; `PdlStat` laisse passer sa valeur à la
    ligne au lieu de déborder.

  Tests : `team_agenda_test.dart` (chaque adresse et chaque ancienne adresse, `when` et
  `participating` envoyés, le type du lien servi dès la première page sans être écrit dans
  `publicationFeedTypeProvider`, la bascule en calendrier qui garde type et « Je participe », pas
  de calendrier pour un visiteur), `publication_timing_test.dart`, `team_dashboard_test.dart`
  (ordre et icônes des puces, sections d'un visiteur, tableau de bord visiteur),
  `deep_link_hierarchy_test.dart`, `sign_in_resume_test.dart` ; Patrol adapté (à lancer sur la
  stack e2e) : `feed_pagination_test.dart`. **À ne pas défaire** : le type de l'Agenda reste
  **local** à la page (ouvert sur celui du lien, gardé d'une vue à l'autre) et n'est jamais écrit
  dans `publicationFeedTypeProvider` (leçon de `WEB-64`) ; l'Agenda et les Publications gardent
  chacun leur `filterScope` ; le calendrier d'une équipe reste aux membres (plan §7) ; « En cours »
  se calcule sur les instants du contrat, jamais sur leur heure de cadran.

## WEB — Site web

### La recette web, automatisée

**Le web est automatisé depuis le 25 septembre 2026** par une suite Playwright qui tourne contre
l'application entière (SSR, backend, postgres, MinIO, mailpit) sur une base vide :
`scripts/e2e.sh up` puis `scripts/e2e.sh test`, voir `frontend/e2e/README.md`. Elle a trouvé onze
défauts, tous corrigés sauf un arbitré (la page d'équipe, `WEB-18`).

Chaque ligne est couverte par un fichier de `frontend/e2e/`, sur desktop et sur mobile (Pixel 7).
Ce qui reste hors de portée de l'automatisation est dit sous la ligne concernée : c'est ce qu'une
recette à la main aurait encore à regarder.

- [x] `WEB-13` Les 5 écrans qui affichent le tracé complet d'un parcours : détail de parcours, carte
      plein écran de parcours et d'étape (les 4 via `useGetRoute`), carte de groupe d'une sortie (via
      `useRoutesBulk` sans `geometry:false`, `RoutesMapView.tsx`). — `route-maps.e2e.ts` : chaque
      écran lit la géométrie entière (aucun paramètre qui la réduise, chaque point du GPX à moins
      de 15 m) et la carte dessine le tracé. *Non couvert : une simplification qui serait ajoutée
      plus tard dans le chemin de dessin lui-même — le test compte des pixels, pas des sommets.*
- [x] `WEB-14` « Ma prochaine sortie », badge `Inscrit` et « Mes participations » se rendent **dans
      le HTML initial** pour une requête porteuse d'un cookie de session, en sont **absents** sans
      cookie, et survivent à l'hydratation sans erreur `[hydration]`. — `ssr-session.e2e.ts`, dont
      le contrôle `curl` fait à la lettre (avec `Cache-Control: no-store` et `Vary: Cookie`).
- [x] `WEB-15` Modale « Contacter le vendeur » : les quatre issues, brouillon conservé sur 429 et
      500, un seul message (le contact coupe le toast global, `skipErrorToast`), `Alert` persistante
      sur la page pour le succès et `AD_CONTACT_OPTED_OUT`, bouton absent sur sa propre annonce, 9 et
      2 001 caractères refusés sans appel réseau ; le mail relayé porte l'auteur en `Reply-To` et
      ne l'imprime jamais. — `ad-contact.e2e.ts`. *Le 500 est simulé : mailpit accepte tout, la
      pile ne sait pas faire échouer un envoi. Les clés `en` ont été vérifiées à la lecture, la
      suite tourne en `fr`.*
- [x] `WEB-16` Annonces, détail : galerie aux flèches et aux vignettes, **dans l'ordre d'ajout**,
      plein écran en 1920 ; disque sans punaise, cadré sur son emprise, légendé « à environ 1 km
      près » ; aucune section vide. — `ads-browse.e2e.ts`. *Le fond de carte (style tiers) est
      remplacé par un fond uni pendant le test.*
- [x] `WEB-17` Annonces, liste : tri et bornes de prix survivent au retour arrière et au partage du
      lien, « Effacer les filtres » conserve le tri, et des changements rapprochés arrivent tous
      dans l'URL. — `ads-browse.e2e.ts`.
- [x] `WEB-18` Page d'équipe en 1440×900 : **arbitré le 25 septembre 2026, l'objectif de 220 px
      n'est pas tenu** — le contenu commence à ~283 px (~300 avant le portage). Gagner les 60 px
      restants voudrait dire refaire la navigation d'équipe (le carré de 40 px et son libellé font
      ~78 px), un chantier de design et non de portage. — `team-misc.e2e.ts` fige **< 300 px** pour
      attraper une régression.
- [x] `WEB-19` Une sortie à plus de 20 commentaires n'en charge que 20 au premier rendu. —
      `rides.e2e.ts`, avec la pastille de meneur (absente sans meneur, jamais le créateur),
      l'inscription et le « Complet ».
- [x] `WEB-20` **Trombinoscope, la matrice rôle × réglage** : réglage désactivé, un membre ordinaire
      prend un 403 ; un organisateur voit la liste sans rôles ni dates ; le sélecteur de meneur
      propose toujours des candidats. Réglage activé, le membre voit tout. `?search=` avec l'adresse
      exacte d'un coéquipier ne remonte rien en membre ni en organisateur, et le remonte en admin
      d'équipe. — `member-directory.e2e.ts`, sur une équipe de test et non sur `gaby`. *L'entrée
      « Membres » est un écran mobile (`web: false`), hors de portée de Playwright ; sur le web, le
      403 est vérifié sur l'API, l'écran d'admin redirigeant vers la page d'équipe.*
- [x] `WEB-21` **Invitation par e-mail** : réponse et écran identiques avec et sans compte, seul le
      mail diffère ; « Renvoyer » remplace le jeton, « Annuler » retire l'invitation ; accepter
      depuis un autre compte donne un message dédié et un bouton « se déconnecter », qui **ramène à
      l'invitation** ; accepter deux fois ne crée qu'une adhésion, et le lien rejoué dit « Vous
      faites déjà partie de… ». — `invitations.e2e.ts`. *Non couvert : l'invitation expirée
      (14 jours d'horloge).*
- [x] `WEB-22` **Invitation d'une adresse sans compte, parcours complet** : inscription par le lien,
      vérification de l'adresse, pas encore membre, invitation visible sur `/equipes`, acceptation.
      — `invitations.e2e.ts`.

### `WEB-26` Audit de couverture e2e du 27 septembre — exécuté

[Archivé](plans/archive/2026-09-27-e2e-coverage-audit.md) : P0, P1 et P2 écrits, 54 défauts
relevés, tous corrigés ou tranchés, le dernier (`WEB-6`) le 29 septembre. Les idées P2 non retenues sont `WEB-7`.

- [x] `WEB-6` **Erreur d'hydratation React #418 (texte), intermittente — corrigée le 29 septembre
      2026.** Vue d'abord sur `/equipes/{slug}` en membre (point 40 de l'audit), puis sous charge
      (`--workers=5`) sur `postEdit` et `gpxToolsEdit`, deux requêtes parties à la même
      milliseconde et servies en 2,5 s. Leur HTML serveur n'avait ni le nom du site (« © 2026 . »)
      ni la version, sans aucune erreur au journal : le `QueryClient` du SSR avait un `gcTime` de
      2 s, et la config et la version, lues avant le prefetch de la route et observées seulement au
      rendu, étaient ramassées entre les deux dès que le prefetch dépassait 2 s. Elles manquaient
      donc aussi à l'état déshydraté ; le client, qui lit la config avant d'hydrater
      (`entry-client.tsx`), rendait le nom, d'où #418 sur n'importe quelle page. Le serveur ne
      ramasse plus rien (`gcTime: Infinity`) : son client ne vit qu'une requête et `entry-server`
      le vide en fin de rendu. — `src/lib/queryClient.test.tsx` (« a server query nothing observes
      yet »). **À ne pas défaire** : aucune fenêtre finie n'est sûre côté serveur, elle ne fait que
      déplacer le seuil de charge. L'occurrence d'origine n'a pas été rejouée ; un #418 qui
      reviendrait sur une page dont le SSR contient bien nom et version est une autre cause, à
      ouvrir sous un nouvel identifiant.

### Le résidu du portage web

#### `WEB-23` T5.5 — Compléments d'annonces : livrée (juillet 2026)

L'alignement du web sur le mobile est fait :

- **Liste** — tri (les six options à plat, comme la feuille de tri du mobile : personne ne pense
  « prix, ascendant », on pense « les moins chères d'abord ») et bornes de prix, tous dans la query
  string via `useUrlFilters` (alias `sort`/`dir`/`pmin`/`pmax`). Le tri **ne participe pas** à
  `isAdFiltered` et « Effacer les filtres » ne le remet pas à zéro : il ne peut pas vider une liste.
  La liste passe en `view=COMPACT` et la carte lit `excerpt` / `thumbnailUrl`.
- **Détail** — galerie sur `AdDto.images` (`Image` + `Group`, vignettes, plein écran en `Modal` —
  `@mantine/carousel` n'a pas été ajouté pour une galerie), sections Description / Localisation /
  Annonceur, auteur par `createdByDisplayName`, et `AdLocationMap`.
- **Contact** — la confirmation est un **état de la page** (`Alert` persistante) et non plus un
  toast qui disparaît avant d'être lu ; `AD_CONTACT_OPTED_OUT` ferme la modale et **retire** le
  bouton, puisque réessayer n'y changerait rien. Les échecs récupérables (429, 500) restent traités
  dans la modale, brouillon en main.

Les deux contraintes qui tenaient la tâche sont respectées et à ne pas perdre : `AdLocationMap` rend
un **polygone GeoJSON de 500 m** (remplissage translucide, contour 1 px), **aucun `Marker` ni couche
`symbol`**, cadrage sur l'emprise du cercle via `initialViewState.bounds`, carte non interactive, et
une légende qui dit « à environ 1 km près ».

#### `WEB-24` T3.5 — Abandonnée, puis tranchée dans l'autre sens (2.0.0)

Alimenter `ElevationChart` par `…/elevation-profile` au lieu de la géométrie complète. **La prémisse
ne tenait pas** : il n'existe aucune vue web qui rende un profil *sans* rendre de carte, donc la
géométrie est de toute façon nécessaire et l'appel supplémentaire **ajoutait** une requête au lieu
d'en retirer une.

C'est finalement l'inverse qui a été fait, et pour la même raison : `…/elevation-profile` a été
**supprimé** de l'API en 2.0.0, et le mobile dérive désormais son profil de la géométrie comme le
web le faisait déjà. Voir `API-40`. Ne pas rouvrir : le sujet est clos dans les deux clients.

#### `WEB-25` Refonte sémantique de `NavButtons` — instruite **et livrée** le 31 juillet 2026

**[`plans/archive/2026-07-31-navbuttons.md`](plans/archive/2026-07-31-navbuttons.md)** (mesures prises dans le
navigateur, pas déduites du code). La prémisse de cette ligne était fausse et le chantier s'est
re-taillé.

`NavButtons` doit **rester des liens** : chaque item est une URL distincte, rendue par le serveur et
inscrite dans l'historique. `Tabs` Mantine promettrait des panneaux échangés sur place — c'est
sémantiquement faux, et la navigation clavier fléchée qui va avec **casserait** la tabulation
attendue sur des liens. Ce qui manque vraiment est `<nav>` + `<ul>/<li>` + `aria-current="page"` :
**aucun changement visuel**, donc pas un chantier de design. **S.**

L'inspection a en revanche sorti ce qui n'était pas dans l'énoncé : sur écran large un libellé de
plusieurs mots **perd tous ses mots sauf le premier** (« Fil d'actualités » rend « Fil… » à 1 722 px,
`line-clamp: 1` sur une boîte de 80 px), l'item actif **n'est jamais ramené dans le champ** quand la
rangée déborde, le fondu de bord est **inconditionnel** donc il ment, et les libellés inactifs
échouent AA dans les deux thèmes (4,04 sombre / 3,32 clair). **S** de plus.

Le menu de débordement est écarté avec un motif : le nombre d'items est plafonné à 8 (3 pages
d'équipe maximum), donc la rangée **ne déborde jamais** sur écran de bureau, et le repli mobile
existe déjà — c'est le menu du fil d'Ariane, alimenté par le même `useNavItems`.

**Livré** : repère `nav` + `ul`/`li` + `aria-current="page"`, `maxWidth` à 130 px au-dessus de 48 em
(mesuré sur le plus large libellé livré, « Modèles de sortie » à 126 px), recalage de l'item actif,
fondu piloté par la position de défilement, et libellés inactifs sortis du `dimmed` (4,04/3,32 →
**9,37/21**). L'anneau de focus global, hors de ce chantier, a été traité à part : `WEB-2`.

#### `WEB-1` Trombinoscope : la page web des membres (2026-09-30)

Le dernier reste de T5.4 (`API-39`). La route `teamMembers` (`/equipes/{slug}/membres`) passe à
`web: true` dans `contracts/routes.yaml` et perd son `webFallback` : elle ne redirige plus vers
l'équipe mais rend `TeamDirectoryPage`, route `team-directory` (`auth: 'authenticated'`, sous
« À propos »), que `scripts/routes-ssr.yml` crawle en `user1` sur `gaby`. Les deeplinks ne changent
pas (AASA et `AndroidManifest.xml` régénérés à l'identique), ni le mobile.

La page est `TeamMembersPage` sans invitations, changement de rôle ni retrait : `TeamMemberList` y
reçoit un rôle nul, donc aucune action. Elle affiche **ce que l'API renvoie** : un 403 est un état de
la page (« Liste des membres non partagée », retour vers « À propos »), jamais contourné ; un
`joinedAt` nul n'est plus rendu « A rejoint le inconnu » (`TeamMemberList`) ; le filtre de rôle
n'apparaît que si les rôles sont rendus au lecteur (admin d'équipe ou de plateforme, ou trombinoscope
ouvert), et la recherche ne promet l'e-mail qu'à un admin. Le prefetch (`prefetchTeamDirectory`,
`teamMembersData.ts`) ne demande pas les invitations, réservées aux admins.

Le lien « N membres » de `TeamAboutPage` est actif pour un admin, un organisateur, ou un membre d'une
équipe qui a ouvert son trombinoscope — la règle de `UserTeamAccessChecker` et de la puce du mobile
(`buildTeamSections`) : un lien qui mène toujours à un 403 est pire que pas de lien. Il n'y a pas
d'onglet « Membres » dans la navigation d'équipe, dont la largeur est mesurée pour huit items au
plus (`WEB-25`).

Couvert par trois scénarios de `frontend/e2e/member-directory.e2e.ts` (membre sur trombinoscope
fermé : pas de lien, page de refus sans aucun nom ; organisateur sur trombinoscope fermé : les noms,
sans rôle, date ni filtre de rôle, sans action d'admin ; membre sur trombinoscope ouvert : les
rôles), et par l'entrée `teamMembers` de `routes-render.e2e.ts` (anonyme renvoyé à la connexion ;
sur l'équipe du jeu de données, trombinoscope ouvert, rendu pour les membres, organisateur, admin et
admin plateforme ; refus sur place pour un extérieur), lancés le 2026-09-30, verts sur desktop et
mobile ; `appOnlyFallbacks.test.ts` et `smoke.e2e.ts` ne comptent plus `/membres` parmi les liens réservés à
l'app. Ne pas déduire les rôles ou l'accès côté client pour élargir ce que le serveur donne.

### Accessibilité

- `WEB-2` **L'anneau de focus passe 3:1 en thème sombre** (2026-09-30) — Mantine le dessine en
  `--mantine-primary-color-filled`, indigo-8 (`#3b5bdb`) en sombre : **2,74:1** sur la page
  (`#242424`), **2,40:1** sur les surfaces élevées et les champs (`#2e2e2e`), sous le 3:1 de SC 1.4.11.
  `index.css` repeint le contour des deux classes de Mantine (`.mantine-focus-auto:focus-visible`,
  `.mantine-focus-always:focus`) en `--mantine-color-primary-text` : la nuance que Mantine emploie
  déjà pour le texte primaire en sombre, indigo-4 (`#748ffc`, charte §3), soit **5,23:1** sur
  `#242424`, **4,58:1** sur `#2e2e2e`, **5,55:1** sur `#1f1f1f` et **3,78:1** sur le survol
  `#3b3b3b`. En clair la variable vaut la nuance pleine, indigo-6 (`#4c6ef5`) : l'anneau clair ne
  change pas (**4,32:1** sur blanc, **4,10:1** sur `#f8f9fa`). Indigo-5 (`#5c7cfa`) passait aussi,
  mais à 3,05:1 seulement sur `#3b3b3b`. Pas de nouvelle couleur : la ligne « Anneau de focus » de
  [`BRANDING.md`](BRANDING.md) §3.2 la consigne. Ne pas reposer l'anneau sur
  `--mantine-primary-color-filled`, ni le mettre dans `lib/theme.ts` (le thème Mantine n'a pas de
  réglage de couleur d'anneau). Pas de test automatique : ni vitest (jsdom) ni la suite e2e ne
  mesurent un contour ; la sortie de `pnpm build` a été vérifiée (la règle suit celle de Mantine),
  `pnpm typecheck`, `pnpm lint` et `npx vitest run` passent.

### Outillage

- `WEB-53` **Le crawl SSR manuel retiré, `routes-render` sur des données de vraie équipe**
  (2026-10-04) — `scripts/ssr-audit.mjs`, `scripts/routes-ssr.yml` et les scripts `pnpm ssr-audit*`
  sont supprimés : `routes-render.e2e.ts` (`WEB-52`) les remplace, chaque nuit, sans comptes réels.
  La seule chose que le crawl voyait encore, des requêtes qui ne partent que si la donnée existe,
  est couverte en enrichissant `buildDataset()` (`e2e/support/routes-render.ts`) : équipe avec logo,
  description illustrée et position ; un lieu ; un tag par type ; deux parcours ; une sortie avec son
  parcours, ses lieux de départ et d'arrivée, deux groupes (l'un avec parcours et meneur) et un
  inscrit ; un voyage à deux étapes avec parcours (et lieux sur la première) et un inscrit ; une
  publication et une page d'équipe illustrées ; une annonce avec photo et position ; un modèle à deux
  groupes ; un commentaire sur chaque contenu commentable. Trou révélé et fermé : le parcours propre
  de la sortie, lu par l'aperçu de `RideEditor` (`rideFormRouteSlug`, `rideFormData.ts`) ; le même
  aperçu dans `TripEditor` est préchargé par symétrie (`tripFormRouteSlug`, `tripFormData.ts`) mais
  **n'est couvert par aucun test permanent** : un voyage avec parcours propre n'affiche plus sur sa
  carte ceux des étapes, et le jeu de données garde la branche des étapes (vérifié une fois à la
  main, 18/18). `frontend/docs/SSR-BUGS.md` est dissous : son défaut ouvert accepté devient `WEB-54`
  (« Délibérément dehors »), ses leçons encore vraies la section « Reading a prefetch gap » de
  `frontend/docs/SSR-data-loading.md`, et `frontend/e2e/README.md` décrit le contrôle (image à
  reconstruire après le passage de l'audit à `true`, filtre d'une route, date d'un vert).
  Le fichier de mots de passe des comptes du crawl, `scripts/.env.users`, est supprimé des checkouts
  avec sa ligne de `.gitignore`. Tests : `routes-render.e2e.ts` 898/898 (desktop et mobile) après la dernière reconstruction
  de l'image ; `pnpm typecheck`, `pnpm lint`, `pnpm e2e:typecheck`, `npx vitest run` (217) passent.
  À ne pas défaire : **`routes-render` n'échoue pas sur une `console.error`** quelconque, seulement
  sur `[hydration]` (décidé le 2026-10-04 : le bruit qu'ajouterait le reste n'est pas mesuré) ; un
  écran qui se met à lire un nouveau champ donne ce champ au jeu de données plutôt que de laisser
  sa requête hors audit ; pas de second outil d'audit SSR à maintenir à côté de la suite e2e.

- `WEB-52` **Le préchargement SSR vérifié chaque nuit par la suite e2e** (2026-10-04) — l'audit
  `[prefetch-audit]` n'était lu que par le crawl `scripts/ssr-audit.mjs`, lancé à la main, pas
  relancé depuis le 2026-08-04 : toutes les pages d'un visiteur connecté, et quinze écrans de plus,
  avaient pris des trous depuis sans que rien ne le dise. L'image e2e est désormais construite avec `FRONTEND_PREFETCH_AUDIT=true` (`.env.e2e`), et
  `routes-render.e2e.ts` exige le verdict `covered` pour chaque écran rendu sur son propre chemin,
  pour chacun des six rôles (`watchPrefetchAudit`, `e2e/support/ui.ts`) ; une redirection ou le
  repli d'un refus ne sont pas mesurés. Trous fermés : le compteur de la cloche
  (`/api/notifications/unread-count`, toutes les pages d'un visiteur connecté, préchargé par
  `entry-server.tsx` avec la session, comme `/api/version`) ; le `TagPicker` des douze
  formulaires de création et d'édition (`prefetchCreate…Form` / `prefetchEdit…Form` des modules
  `pages/*/…FormData.ts`) ; la liste `/notifications` (`prefetchNotificationList`) ; les préférences
  de notification et les appareils appairés du profil (`profileData.ts`) ; le webhook des réglages
  d'équipe, pour un admin seulement (`prefetchTeamSettings`). Après rebase, la carte de fin de l'accueil membre
  (`FeaturesPromoCard`, `WEB-51`) lisait les appareils appairés hors préchargement : ajoutés à
  `prefetchHomeFeed`. `routes-render.e2e.ts` reçoit la
  route `features`, qui y manquait, et l'accueil anonyme y attend désormais la présentation visiteur (`seesAs`) : sur
  `develop`, `home` échouait en anonyme depuis le nouvel accueil. `ads-browse.e2e.ts` (« the exact
  point of an ad… ») ouvre l'annonce depuis la liste : ouvertes par leur URL, les deux pages ne
  lisent plus rien après hydratation, et son contrôle « au moins une réponse API » tombait à vide.
  Tests : `routes-render.e2e.ts` 898/898 (desktop et mobile) ; suite complète avec l'audit actif,
  1 628 réussis, 4 échecs, dont 2 `ads-browse` corrigés depuis (repassés) et 2
  `gpx-planner.e2e.ts`, faute de Valhalla et de tileserver sur le poste (exclu en CI,
  `E2E_NO_ROUTING`) ; `pnpm typecheck`, `pnpm lint`, `npx vitest run` passent. À ne pas défaire : l'audit actif dans l'image
  e2e (son seul autre effet : pas de préchargement au survol pendant les 5 premières secondes d'une
  page) ; un écran nouveau ou modifié qui lit une requête au premier affichage la précharge dans son
  module de données, il ne s'exempte pas du test.

- `WEB-5` **`pnpm ssr-audit:verify` repasse** (2026-09-30) — `notifications`, `web: true` dans
  `contracts/routes.yaml`, manquait à `scripts/routes-ssr.yml` ; la vérification a sorti trois
  autres absentes, venues avec le signalement et le support : `support`, `teamAdminReports`,
  `adminReports`. Les quatre y sont, rangées comme leurs voisines : `notifications` pour les trois
  comptes connectés (la boîte est par utilisateur), `support` pour tous (page publique),
  `teamAdminReports` pour `user1` sur `gaby`, `adminReports` pour `admin`. Couvert par
  `pnpm ssr-audit:verify` lui-même (69 routes), qui tourne sans pile ; le crawl, lui, n'a pas été
  relancé.

- `WEB-35` **Les e2e ne cliquent plus avant la fin de l'hydratation** (2026-09-30) — le tiroir
  mobile de `flow-notifications.e2e.ts` (:59, puis :475 en relance) ne s'ouvrait pas une fois sur
  quelques centaines sous charge : le burger disait encore « Ouvrir le menu » juste après le clic,
  avant toute réponse réseau. Cause : `hydrated()` (`e2e/support/ui.ts`) attendait la clé
  `__reactProps` du nœud, que React pose **pendant le rendu d'hydratation, avant son commit** ; un
  clic dans cet intervalle est perdu, pas rejoué. Mesuré par une sonde (clic dès `hydrated()`,
  mobile, ×40) : 3 clics perdus, tous sur une fibre pas encore validée (`alternate` nul), 37 réussis,
  tous sur une fibre validée. Correctif à la cause, sans retry ni délai : `HydrationMarker`
  (`src/components/common/HydrationMarker.tsx`, dernier enfant de la racine dans
  `entry-client.tsx`) pose `<html data-hydrated="true">` dans un effet, donc après le commit de tout
  l'arbre, côté client seulement (jamais dans le HTML du SSR), une fois ; le rendu sans hydratation
  (`createRoot`) le pose aussi. `hydrated()` attend ce marqueur **et** la clé, `pageHydrated()` le
  marqueur au lieu de la clé du conteneur (posée dès l'appel à `hydrateRoot`). Même sonde après :
  40/40. Validation : `flow-notifications`, `flow-moderation`, `flow-account` et `flow-posts` en mobile ×20 sous charge (les ouvertures du burger comprises), 1 280/1 280 ; puis la suite complète, 1 580 réussis, 0 échec. À ne pas défaire : ne pas revenir à la seule clé
  `__reactProps` comme signal d'interactivité. Le défaut côté utilisateur (un tap trop tôt est
  ignoré) reste ouvert : `WEB-36`.
  **Instables observés une fois sous charge, non reproduits, non désactivés** : les 10 tests relevés
  pendant `API-16` — `routes-render.e2e.ts:692` (8 cas : l'onglet des modèles de l'admin d'équipe,
  refus « only the team organizers/admins manage it », `rideNew` en organisateur, une redirection
  d'`unauthenticated route`), `ssr-session.e2e.ts:191` (« home: the server blocks survive hydration
  untouched ») et `flow-rides.e2e.ts:1267` (mobile) — 0 échec dans la suite complète sur `b167aa06`
  puis 0 sur 40 exécutions sous charge (`--repeat-each=4`, 8 workers) ; leurs traces d'origine sont
  perdues, la cause n'est pas établie. `flow-posts.e2e.ts:69` (mobile, dialogue « Supprimer » sans
  nom accessible, menu resté ouvert) : 0 sur 6 sous charge ; hypothèse non prouvée, un clic tombé
  avant un commit, ce que `WEB-35` ferme aussi. À rouvrir sur une nouvelle occurrence, trace en main.

### Défauts d'interface

- `WEB-66` **Un onglet ouvert avant un déploiement tombait sur l'écran d'erreur** (feedback #9,
  2026-10-06) — les chunks paresseux de l'ancien build (`UserProfilePage-<hash>.js`) ne sont plus
  servis après un déploiement, et la route suivante levait « Failed to fetch dynamically imported
  module ». `lib/staleChunk.ts` recharge la page, sur `vite:preloadError` comme dans
  `ErrorBoundary`, au plus une fois par 30 s (garde en `sessionStorage`) : si le chunk manque encore
  après le rechargement, l'erreur s'affiche et se remonte normalement. Test :
  `staleChunk.test.ts`. **À ne pas défaire** : la garde anti-boucle.

- `WEB-59` **« Lien invalide » sur un changement d'adresse pourtant appliqué** (2026-10-04) —
  `VerifyEmailPage` confirmait le changement, puis relisait `/me` avec le jeton d'accès en mémoire.
  Ce jeton porte l'ancienne adresse, que le backend ne résout plus (`API-73`) : un 403, que
  l'intercepteur ne rafraîchit pas (il ne réagit qu'aux 401), tombait dans le `catch` de la
  confirmation et affichait l'erreur. Le changement d'adresse est maintenant affiché dès la
  confirmation, puis la session est renouvelée par `refresh` (nouveau jeton et nouvel utilisateur),
  dont un échec n'est plus montré. Constaté en prod le 4 octobre 2026. Pas de test : aucun parcours
  e2e ne couvre le changement d'adresse. **À ne pas défaire** : rien après `confirmEmailChange`
  ne doit pouvoir faire basculer la page en erreur, le lien étant déjà consommé.

- `WEB-29` **Les sélecteurs d'image annoncent HEIC/HEIF, et c'est désormais vrai** (2026-09-29,
  sans changement de code) — `MediaEditor.tsx`, `tiptap/ImageUploadControl.tsx` et
  `UserProfilePage.tsx` proposaient `accept="image/*,.heic,.heif"` alors que le backend les
  refusait. `API-53` les fait accepter (convertis en JPEG au stockage) : la promesse est tenue,
  rien à retirer. Ne pas convertir côté client : le backend le fait pour tous les clients.

- `WEB-3` **Le survol des cartes web a un effet** (2026-09-30) — l'ombre `md` des cartes était
  déclarée en `'&:hover'` dans la prop `styles`, que Mantine rend en style inline : le
  pseudo-sélecteur était ignoré. Elle passe par une classe de `Card.module.css` (mixin `hover` de
  `postcss-preset-mantine` : `:hover` sous `(hover: hover)`, `:active` sous `(hover: none)`), qui
  porte aussi le reste du style du lien (`display`, couleur, transition). Même motif corrigé pour le
  soulignement au survol de `CardTeamLink` (même module), `TeamContextBanner` et `TripStageCard`
  (un module chacun). [`BRANDING.md`](BRANDING.md) §5.2 et §7.1 décrivent désormais l'ombre au
  survol comme acquise. Ne pas remettre de pseudo-sélecteur dans `styles` ou `style` : il n'y a
  aucun effet et rien ne le signale. Pas de test : ni vitest (jsdom ne calcule pas `:hover`) ni la
  suite e2e ne mesurent un style au survol ; `pnpm typecheck`, `pnpm lint` et `npx vitest run`
  passent, et la sortie de `postcss-preset-mantine` sur le module a été vérifiée.

- `WEB-46` **Le tiroir mobile dit que la ligne avatar + nom mène au profil** (4 octobre 2026,
  relevé dans `docs/BUGS.md`) — dans le burger (`Layout.tsx`), le seul accès au profil était la
  pastille et le nom, sans rien qui le signale. La ligne garde son lien et gagne « Voir mon profil »
  (`nav.viewProfile`) sous le nom, et un chevron. **À ne pas défaire** : le nom affiché reste dans le
  nom accessible du lien, `openProfileInApp` (`e2e/support/moderation.ts`) le trouve par lui.

- `WEB-47` **Le nom de « Ma prochaine sortie » est un lien** (4 octobre 2026, relevé dans
  `docs/BUGS.md`) — seul le bouton « Voir la sortie » y menait (`NextRideCard.tsx`). Le titre
  `h3` contient désormais un `Anchor` vers la sortie ; la carte elle-même reste non cliquable (les
  specs e2e la lisent par le parent du titre « Ma prochaine sortie », et le lien de carte est celui
  du fil).

- `WEB-48` **« Cette semaine » devient « Les 7 prochains jours », site et application** (4 octobre
  2026, relevé dans `docs/BUGS.md` comme « la semaine commence le dimanche ») — le bloc n'a jamais
  été une semaine calendaire : c'est une fenêtre glissante de sept jours à partir d'aujourd'hui
  (`WeekAgenda.tsx`, `week_events_provider.dart`), qui un dimanche commence donc un dimanche. Le
  libellé seul était faux : titre et phrases (`home.week.*`, `home.member.summary.*`) parlent des
  « 7 prochains jours », en FR et EN, et le titre mobile (`home.week.title`) suit ; le test
  `home_member_sections_test.dart` lit le nouveau titre. **Écarté** : une semaine lundi–dimanche,
  qui le dimanche n'aurait montré que la journée en cours.

- `WEB-49` **Carte d'une sortie : sens des parcours, contrôles visibles, plein écran sur iPhone,
  choix des traces** (4 octobre 2026, relevé dans `docs/BUGS.md`) —
  - *Sens* : un chevron répété le long de chaque trace, dans l'ordre de ses points, sur **toutes**
    les cartes qui dessinent une trace (sortie et voyage `RoutesMapView`, parcours `RouteTrackMap`,
    planificateur et sa loupe). Image dessinée au canvas (`map/RouteArrows.tsx`), enregistrée par
    `PedalonsMap` via `setMissingStyleImageResolver` **et** un `addImage` immédiat — le résolveur
    seul laisse sans flèches une couche qui a demandé l'image avant l'effet (constaté sur la page
    parcours) ; mise en page commune `map/routeArrowLayout.ts`. Sur la carte de tous les parcours
    (`RoutesTileMap`), seul le parcours survolé ou ouvert en a : sur toutes les traces à la fois
    elles noieraient la carte. `RouteTrackMap` les pose sur une source des pistes entières, pas sur
    les segments du dégradé.
  - *Contrôles cachés* : le profil d'altitude de `RoutesMapView` était en haut à droite, en pleine
    largeur sous `sm`, donc par-dessus toute la colonne de boutons (zoom, fonds, plein écran) sur
    téléphone. Il passe en bas à gauche (laisse le ⓘ de l'attribution visible), le cadrage réserve
    le bas au lieu du haut, et il disparaît quand aucune trace n'est affichée.
  - *Plein écran* : sans API Fullscreen (Safari iPhone), MapLibre passe la carte en
    `position: fixed; z-index: 99999` (`maplibregl-pseudo-fullscreen`), mais dans le contexte
    d'empilement de sa boîte (`z-index: 0` inline) et du `.detail-map` collant : les pastilles des
    participants passaient devant. Les deux montent au `--mantine-z-index-max` tant que la carte est
    en plein écran (`index.css`, `:has()`, `!important` contre le style inline).
  - *Traces* : le panneau des fonds (`MapStyleSwitcher`) liste les traces quand il y en a plus
    d'une, une case et la couleur chacune ; une trace décochée garde sa couche (`visibility: none`,
    le clic interroge toujours la même liste de couches), sort du profil, des marqueurs départ et
    arrivée, et du choix de la trace mise en avant.
  Vérifié à la main dans Chrome sur staging (sortie à 8 groupes, page parcours, carte des
  parcours ; plein écran simulé par la classe). Pas de test automatisé : jsdom ne rend pas MapLibre.

- `WEB-50` **« Fonctionnalités » quitte l'en-tête d'un membre connecté** (4 octobre 2026, relevé
  dans `docs/BUGS.md`) — la page vend le produit à un visiteur ; un membre l'a déjà adopté.
  `useMainNavItems` (`hooks/useNavItems.ts`) ne l'ajoute plus quand la session est ouverte (en-tête
  et tiroir) ; la page reste accessible par son URL et le pied de page. Test : `MainNav.test.tsx`.

- `WEB-72` **« Outils GPX » passe dans l'en-tête d'un membre connecté, à la place de
  « Fonctionnalités »** (6 octobre 2026) — les outils n'étaient atteignables que par le menu de
  l'avatar (et le tiroir mobile). `useMainNavItems` (`hooks/useNavItems.ts`) les ajoute en dernière
  entrée quand la session est ouverte — l'emplacement que `WEB-50` a libéré —, en-tête et tiroir ;
  l'entrée s'allume sur toute la section (`gpx-tools` et ses sous-routes). Retirés du menu de
  l'avatar et du tiroir (`Layout.tsx`) pour ne pas les lister deux fois. Un visiteur n'a toujours
  que « Fonctionnalités » : les outils exigent une session. Test : `MainNav.test.tsx`.

- `WEB-51` **La carte « Envoyez vos parcours vers votre compteur » de l'accueil ne s'adresse plus
  qu'à qui n'a rien branché, et mène au profil** (4 octobre 2026, relevé dans `docs/BUGS.md`) —
  `FeaturesPromoCard` s'affichait à tous les membres et menait à la page Fonctionnalités. Elle ne
  s'affiche plus que sans service GPS connecté (`UserDto.connectedServices`) **ni** appareil appairé
  (`GET /api/users/me/devices`, masquée tant qu'il charge pour ne pas clignoter chez ceux qui en
  ont), et mène aux services GPS du profil — d'abord par l'ancre `/profil#gps`, depuis le 4 octobre
  2026 à la page `/profil/appareils` (`WEB-55`, l'ancre et `profileAnchors.ts` sont supprimés). Texte (`home.member.promo.text`) réécrit pour dire où se
  fait le branchement. Pas d'équivalent mobile à aligner. Non vérifié à l'écran (pas de session
  connectée pendant la correction).

- `WEB-28` **« Déconnecter tous les appareils » sur le site** (2026-09-30, contrat inchangé) — le
  profil web (`UserProfilePage.tsx`, section « Actions du compte ») a le bouton du mobile, avec la
  même confirmation et une ligne qui dit ce qu'il ferme (ce navigateur, l'app, le Karoo ou le Garmin
  appairé : ce sont tous des `AuthSession`, que `AuthService.logoutAll` révoque). L'action
  `authStore.logoutAll` retire d'abord l'enregistrement Web Push du navigateur, comme `logout`, puis
  appelle `POST /api/auth/logout-all` par le client **authentifié** et recharge sur la connexion.
  **Un refus du serveur laisse la session ouverte** et le dit (« vos sessions sont toujours
  ouvertes ») au lieu d'annoncer une déconnexion qui n'a pas eu lieu — d'où `skipErrorToast` sur
  l'appel. Trouvé en chemin, le défaut que le mobile avait corrigé en `MOB-32` : l'intercepteur web
  ne rafraîchissait jamais le jeton sur `/api/auth/*`, si bien qu'un jeton d'accès expiré faisait
  échouer en 401 `logout-all`, la demande de changement d'e-mail et la gestion des clés d'accès.
  `refreshesOn401` (`lib/authRefresh.ts`) reprend la table du mobile, plus
  `email/change-request`. La politique (§1, extensions GPS) cite désormais le site et l'app, en
  parité FR/EN. Tests : `lib/authRefresh.test.ts` (la table), et `flow-account.e2e.ts` « signing
  out of every device from the profile closes the other sessions too » (desktop et mobile) : la
  session du navigateur **et** une session ouverte ailleurs ne se rafraîchissent plus. Non couvert
  de bout en bout : le rafraîchissement d'un jeton expiré avant l'appel (pendant web de `MOB-38`).

- `WEB-32` **Une image se glisse ou se colle dans l'éditeur** (2026-09-30, sans changement de
  contrat) — seul le bouton de la barre d'outils téléversait une image. `MarkdownEditor` prend
  maintenant les fichiers déposés (`handleDrop`, à l'endroit du lâcher) et collés (`handlePaste`, au
  curseur) par le même téléversement : `tiptap/insertAsset.ts` (`imageFiles`, `uploadAndInsert`),
  que le bouton utilise aussi. Plusieurs images arrivent dans l'ordre, **l'une après l'autre** : chaque
  téléversement ajoute à la liste d'assets du formulaire, des écritures parallèles s'y
  marcheraient dessus. Un fichier qui n'est pas une image, un éditeur sans équipe ou en lecture
  seule laissent l'événement à ProseMirror ; un déplacement d'image à l'intérieur de l'éditeur
  aussi. Couvert par `tiptap/insertAsset.test.ts` (filtre, HEIC sans type MIME, ordre, échec
  isolé) ; le glisser-déposer réel n'a pas de test e2e.

- `WEB-37` **Changer de groupe vite ne se solde plus par un 409** (2026-09-30, contrat inchangé) —
  « Quitter » met la sortie à jour de façon optimiste : les autres groupes affichaient
  « Rejoindre » avant que le serveur ait libéré le premier, et un « Rejoindre » tapé dans cet
  intervalle partait pendant le `leave` et revenait en `ALREADY_REGISTERED`, la carte montrant
  « Inscrit » jusqu'au retour arrière. Relevé par `rides.e2e.ts` « changing group » (mobile, sous
  5 workers : `join` parti à +113 ms d'un `leave` de 220 ms). `RideDetailPage` désactive désormais
  les boutons de **toutes** les cartes tant qu'une inscription ou une sortie est en vol, plus
  seulement celle touchée (l'état `joiningGroupId` disparaît). Ne pas revenir à une désactivation
  par carte : l'optimisme rend les autres cartes actionnables trop tôt.

- `WEB-38` **Une réponse de `/me` arrivée après la déconnexion ne rouvre plus la session**
  (2026-09-30, contrat inchangé) — `useAuth` recopiait l'utilisateur de `/me` dans le store dès sa
  réponse ; un `/me` parti juste avant `logout()` et revenu après remettait
  `isAuthenticated: true` sans jeton. Les requêtes de la page partaient alors en 401, le
  rafraîchissement échouait (403) et l'intercepteur renvoyait le visiteur, déjà déconnecté, vers
  `/login?next=/connexion`. Relevé par `flow-account.e2e.ts` « a deleted passkey… » (mobile,
  instable). L'effet ne recopie `/me` que si le store est **encore** authentifié au moment où la
  réponse arrive (`useAuthStore.getState()`, pas la valeur du rendu). Pas de test unitaire : le
  hook tire `useGetMe`, Mantine et i18n ; la course reste couverte, sans garantie, par ce e2e.

- `WEB-71` **Calculs de jours hors du fuseau effectif** (2026-10-06, lot 0 du plan
  [fuseau des événements](plans/archive/2026-10-06-event-timezones.md)) — trois endroits comptaient les
  jours dans le fuseau du navigateur ou par pas de 24 h. `WeekAgenda` construit ses sept jours en
  jours calendaires (midi UTC de la date du fuseau effectif, relu en UTC) : `now + i × 24 h` sautait
  un jour le soir du passage à l'heure d'été. `getVisibleRange` (`components/calendar/calendarRange.ts`)
  prend le fuseau effectif et rend les minuits de ce fuseau, en comptant les jours sur des dates
  UTC ; `CalendarView` le lui passe. « Ajouter une étape » (`TripEditor.handleAddStage`) passe par
  `addCalendarDays` : J+n à la même heure murale du fuseau effectif, au lieu de `setDate` dans
  celui du navigateur — remplacée depuis par `addDaysToWallTime` (`utils/wallTime.ts`), qui
  compte sur la chaîne d'heure murale (`API-60`, lot 2). `toDateTimeLocalValue` / `fromDateTimeLocalValue`,
  sans appelant, sont supprimées. Couvert par `calendarRange.test.ts` (minuits de Tokyo, semaine du
  passage à l'heure d'été), `useCalendarDateRange.test.ts` (grille dans la fenêtre préchargée, à
  Honolulu et Kiritimati), `wallTime.test.ts` (`addDaysToWallTime`) ; `WeekAgenda` n'a pas de test.
  **À ne pas défaire** : un jour se compte en arithmétique de calendrier, jamais en millisecondes
  ni sur un `Date` local.

### Référencement

- `WEB-4` **`PUBLIC_UNLISTED` n'est plus indexé** (2026-09-30) — `frontend/index.html` servait un
  `<meta name="robots" content="index, follow">` statique et rien n'émettait de `noindex` : une page
  non listée, rendue en SSR, était indexable. La balise statique est retirée ; `buildMetaTags`
  (`lib/seo.ts`) émet maintenant **l'unique** balise robots de la page, dans le bloc injecté à
  `<!--ssr-head-->` (dans le `<head>`, donc lue sans JavaScript) : `noindex` si `RouteMeta.noindex`,
  sinon `index, follow`. Les `meta()` de `routeMeta.ts` le posent d'après la visibilité du contenu
  (équipe, page d'équipe, publication, sortie, voyage, étape — celle de son voyage —, parcours), et
  `withIndexing`, appliqué par `entry-server` après le `meta()` de la route, l'ajoute à **toute**
  page d'une équipe qui n'est pas `PUBLIC`, y compris celles sans `meta()` (listes, calendrier…) :
  l'équipe est déjà dans le cache de la requête, lue pour la décision 404/301. Seul `PUBLIC` est
  indexable : `TEAM` ne se rend que pour une session de membre, jamais pour un robot. Couvert par
  `frontend/src/config/routeMeta.test.ts` (une seule balise robots dans le bloc, `noindex` pour un
  contenu non listé, pour un contenu public d'une équipe non listée, et pour une page sans `meta()`
  de cette équipe). Ne pas remettre de balise robots dans `index.html` : elle côtoierait la balise
  par page et la contredirait. Le mode dev SPA sans SSR n'a pas de balise robots, ce qui vaut
  `index, follow`.

- `WEB-30` **Un bouton de partage sur le site** (2026-09-30, sans changement de contrat) — le mobile
  partageait déjà un lien (`share_link.dart`), le web n'avait rien. `components/common/ShareButton.tsx`
  est posé dans l'en-tête des pages de sortie, d'article, de voyage, d'étape et de parcours, et dans
  celui de l'équipe (`TeamLayout`) : la feuille de partage du système quand `navigator.share`
  existe, la copie du lien sinon (Firefox et Chrome de bureau), avec un bandeau qui dit si la copie
  a échoué. Le lien est celui de la **barre d'adresse**, pas un `paths.xxx()` : sur un hôte épinglé
  à une équipe, le chemin du routeur est préfixé et l'adresse visible ne l'est pas — c'est elle qui
  marche chez le destinataire. Pas de bouton sur les annonces, comme au mobile : elles ne se lisent
  qu'entre membres. Couvert par `ShareButton.test.tsx` (feuille, fermeture sans bandeau, copie,
  copie refusée).

- `WEB-31` **Un `sitemap.xml` par site** (2026-09-30, API `6.2.0`) — `GET /api/sitemap`
  (`SitemapService`) liste ce qu'un moteur peut indexer sur le site de la requête : les équipes
  `PUBLIC`, leur page « à propos », leurs pages, sorties, articles, voyages et étapes publics. Chaque type passe par la requête de liste de son dépôt (`TeamEntityRepository.findIndexable`,
  requête anonyme, projection seule) : visibilité, statut, modération et modules sont ceux de la
  liste, le sitemap ne peut pas annoncer une page que le site refuserait. S'y ajoute
  `te.team.visibility = 'PUBLIC'` même sur un hôte épinglé, où la liste laisse passer une équipe non
  listée dont toutes les pages sont pourtant `noindex` (`WEB-4`). Une étape n'a pas de visibilité
  propre : elle est listée sous un voyage qui l'est. Plafond de 50 000 entrées (limite du protocole),
  les plus récentes d'abord. **Jamais les annonces** (lues entre membres seulement), **ni les
  parcours** (une carte et un GPX plutôt qu'un texte à indexer ; décision du 30 septembre 2026),
  **ni les pages carte** (`…/carte`) : aucun type d'entrée ne les désigne. Le serveur SSR sert `/sitemap.xml`
  (`renderSitemap` dans `entry-server.tsx`, XML par `lib/sitemap.ts`) avec les chemins **français**
  seulement — la langue servie à un robot, et les deux variantes de chemin rendent la même page —,
  sans préfixe d'équipe sur un hôte épinglé (`toBrowser`), en cache public une heure ; et
  `/robots.txt`, dont les règles restent dans `public/robots.txt`, avec la ligne `Sitemap:` de l'hôte
  ajoutée à la volée (le protocole veut une URL absolue). Couvert par `SitemapServiceTest`
  (contenu, parcours, annonces, contenu non public, équipes non publiques, étapes d'un voyage caché, hôte
  épinglé, hôte épinglé d'une équipe non listée) et `lib/sitemap.test.ts` (chemins, ni parcours ni
  page carte, hôte épinglé, échappement). Ne pas y ajouter les parcours, les pages carte ni les
  annonces ; ne pas
  construire les entrées par une requête écrite à la main plutôt que par `findIndexable`.

- `WEB-34` **Un `llms.txt` par site** (2026-09-30, sans changement de contrat) — le résumé
  (https://llmstxt.org) qu'un modèle de langage lit avant le site. Servi par `server.js` comme
  `/sitemap.xml`, **par hôte** et non en fichier statique (décision du 30 septembre 2026) : le nom du
  site, des liens absolus sur l'hôte de la requête, et sur un hôte épinglé sa seule équipe, à la
  racine. `renderLlmsTxt` (`entry-server.tsx`) interroge l'API en anonyme (seuls les en-têtes d'hôte
  passent, réponse en cache public une heure) : `GET /api/config` pour le nom, `GET /api/teams`
  pour les équipes `PUBLIC` (la liste anonyme), les 200 plus grandes, avec leur extrait et leur
  chemin anglais ; au-delà, un renvoi au plan du site. Le texte (`lib/llmsTxt.ts`) dit les deux
  locales et ce qui n'est listé nulle part — annonces, parcours et cartes, espaces personnels — puis
  pointe `/sitemap.xml`. Il n'expose rien que `robots.txt` et le sitemap (`WEB-31`) n'exposent déjà.
  Couvert par `lib/llmsTxt.test.ts` (titre et résumé, liens et extrait, équipes au-delà de la page,
  hôte épinglé, ni annonce ni parcours). Ne pas y lister de contenu que le sitemap ne liste pas.

- `WEB-33` **Actions sur les cartes : modifier, publier, supprimer, ajouter au calendrier**
  (2026-09-30, API 9.1.0, ajouts seulement ; ligne « Card CTAs » de [`BACKLOG.md`](BACKLOG.md)) —
  un menu `⋯` en haut à droite des cartes, posé **à côté** du lien de la carte et non dedans
  (`Card`, prop `actions`) : un bouton dans un `<a>` est du HTML invalide et ses clics ouvraient la
  carte. Seules les **listes d'équipe** en portent (fil, parcours en vue cartes, annonces), parce
  qu'elles ont déjà chargé le rôle du lecteur (`TeamDetailDto.role`) : l'accueil, le profil et
  « tous les parcours » n'en ont pas, aucun DTO de liste ne disant ce que le lecteur peut faire.
  Qui voit quoi (`components/card/CardActions.tsx`) : Modifier, Supprimer — et Publier sur un
  brouillon — pour un ADMIN ou ORGANIZER de l'équipe, l'auteur ou l'admin pour une annonce (la
  règle des `*AccessChecker`) ; « Ajouter au calendrier » pour tout lecteur d'une sortie ou d'un
  voyage publié et pas encore `finished`. Une ligne supprimée (vue des admins) n'a pas de menu : on
  la restaure depuis sa page. Supprimer passe toujours par `ConfirmDialog`. `CardAction.tsx`, qui
  n'était utilisé nulle part, est retiré au profit de `CardActionsMenu`.
  Le bouton `⋯` porte le nom de sa carte (« Actions — {titre} », `cards.actions.menu`) et **jamais**
  « Options de gestion » : c'est le chevron des pages de détail, que le helper e2e `actionsMenu`
  cible dans `main` ; sur une liste, chaque carte en aurait porté un de plus.
  **Publier passe par un nouvel endpoint** `PATCH …/{slug}/status` (`StatusChangeRequest`) sur les
  sorties, voyages, publications et annonces, et **jamais par la mise à jour complète** : une ligne
  de liste est une projection COMPACT sans les groupes d'une sortie ni les étapes d'un voyage, et la
  renvoyer en `PUT` les supprimerait (et préviendrait les inscrits d'un groupe retiré). Mêmes
  effets qu'un changement de statut par la mise à jour : `publishAt` effacé hors brouillon,
  `publicationStatusChanged` dans la boîte d'envoi des notifications, les étapes qui suivent leur
  voyage ; une annonce refuse `CANCELLED`. **Le `.ics` unitaire** est un autre endpoint,
  `GET …/rides/{slug}/ics` et `…/trips/{slug}/ics` (`PublicationIcsService`), en
  `Content-Disposition: attachment` : il se construit sur le DTO de la page de détail, donc lisible
  par qui peut lire la sortie — un visiteur anonyme sur une sortie publique compris — et **sans le
  jeton d'abonnement** des flux de `CalendarService` ; le web le télécharge par un simple lien (le
  cookie de rafraîchissement authentifie un `@PermitAll`). Un voyage y donne un événement « journée
  entière » par étape. Tests : `api/common/StatusAndIcsResourceTest` (backend : statut par rôle, 401,
  400, groupes et étapes conservés, étapes qui suivent, annonce `CANCELLED` refusée, `.ics` par
  visibilité et par étape) et `components/card/CardActions.test.tsx` (Publier appelle l'endpoint de
  statut et jamais `updateRide`, qui voit quoi, confirmation). **Ne pas** publier depuis une liste
  par la mise à jour complète, ni faire passer le `.ics` unitaire par le jeton d'abonnement.

- `WEB-70` **Dates des métadonnées SEO et `og:` en UTC** (2026-10-06, lot 0 du plan
  [fuseau des événements](plans/archive/2026-10-06-event-timezones.md)) — `formatDate` de
  `config/routeMeta.ts` formatait sans `timeZone`, donc en UTC sur le serveur SSR : une sortie à
  00:30 heure de Paris était annoncée la veille dans le titre et l'aperçu de lien. Les dates y sont
  formatées en `Europe/Paris` (`META_TIME_ZONE`) en attendant le fuseau de l'entité (`API-60`).
  Couvert par `routeMeta.test.ts` (« ride date in the link preview »). **À ne pas défaire** : ni le
  fuseau du serveur ni celui du lecteur pour un aperçu de lien.

### Tags d'équipe

- `WEB-40` **Tags d'équipe côté site** (1er octobre 2026, API 10.1.0, plan archivé
  [`2026-10-01-tags.md`](plans/archive/2026-10-01-tags.md) §5) — affichage, filtre, étiquetage et
  admin du vocabulaire (D20).
  - **Affichage** : `components/tag/TagList` (`TagChip` : pastille `TagDot` de la famille et libellé
    neutre, D10), en carte (3 tags, puis « +n » seulement si au moins deux seraient cachés — même
    règle que `PdlTagRow`) et en fiche (tous) ; rendu en SSR, visible des anonymes (D19).
  - **Filtre** : `TagFilter`, synchronisé avec `?tags=<id>,<id>` (`tagIdsField`, D18), sur les
    listes d'équipe dédiées — publications restreintes à un type, parcours, annonces ; masqué quand
    l'équipe n'a aucun tag du type et sur le fil mixte (D13), où un `?tags=` d'URL n'est ni envoyé
    ni compté comme filtre actif (`PublicationListPage.hasNonSearchFilters`).
  - **Étiquetage** : `TagPicker` dans les formulaires des cinq types et du modèle de sortie, parmi
    les tags existants seulement (D4) ; sans tag du type, un renvoi vers l'admin pour un admin. Un
    id que le vocabulaire chargé n'a plus est **retiré de la valeur du formulaire**, pas seulement
    masqué. La création d'une sortie depuis un modèle pré-remplit `tagIds` depuis
    `RideTemplateDto.tags` : c'est **la** copie D14, l'API n'en a pas d'autre. Les boutons de statut
    des fiches sortie et voyage passent par `rideStatusRequest`/`tripStatusRequest`, qui
    n'envoient pas `tagIds` (« inchangé » côté API).
  - **Admin** : `pages/team/TeamTagsPage` (`/equipes/{slug}/admin/tags`, route `teamAdminTags`), un
    onglet par type, `TagFormModal` (libellé ≤ 32 après trim, 9 couleurs), suppression avec
    confirmation qui annonce le nombre de contenus détachés (D11) ; renommer, recolorer ou
    supprimer invalide aussi les contenus en cache (`lib/tagCacheInvalidation.ts`).

  Tests : `TagList.test.tsx`, `TagPicker.test.tsx`, `hooks/filters/tagFilters.test.ts` (vitest
  vert, 182 tests) ; e2e `tags.e2e.ts` « an admin creates a tag, a member puts it on an ad, the
  list filtered by URL finds it » (plan §8). **À ne pas défaire** : aucun formulaire de contenu ne
  crée de tag ; ne pas renvoyer depuis le cache des tags que le vocabulaire n'a plus (l'API refuse
  la requête entière en `TAG_INVALID`) ; pas de filtre par tag hors d'une liste d'équipe d'un seul
  type (D7, D13).

### Profil

- `WEB-41` **Services connectés et appareils appairés, deux sections distinctes** (3 octobre 2026,
  site et app mobile, sans changement de contrat). Le profil titrait « Appareils GPS » la liste des
  *services* OAuth (Hammerhead, Garmin Connect, Wahoo), et le site y glissait « Appareils appairés »
  en simple sous-titre : on lisait une seule section, avec les mêmes logos des deux côtés. Les deux
  clients disent désormais **« Services connectés »** (des comptes où « Envoyer vers l'appareil »
  dépose le parcours) et **« Appareils appairés »** (les Karoo et Garmin où l'app Pédalons est liée
  par un code), chacun avec sa phrase d'explication ; sur le site, deux titres de même niveau
  séparés par un `Divider` (`UserProfilePage`, `PairedDevicesManager`), sur mobile la phrase
  `profile.devices.hint` dans `PairedDevicesCard`. Tests : `PairedDevicesManager.test.tsx` (titre et
  description) et `paired_devices_card_test.dart` (la phrase). **À ne pas défaire** : un service
  OAuth n'est jamais appelé « appareil » (titre, confirmation de déconnexion, aide).

- `WEB-55` **Le profil en vue d'ensemble et sous-pages, même arbre que l'app** (4 octobre 2026,
  **API 10.7.0**, maquette validée du 4 octobre). `/profil` (`ProfileOverviewPage`) : carte
  d'identité (vers Mon compte), Mes sorties (prochaine sortie, à venir, historique), Mes équipes avec
  le rôle (bureau), puis un raccourci par sujet avec sa **ligne d'état** (`profileStatus.ts`), lue
  dans `/me` et `GET /api/users/me/profile-summary` (`API-69`). Neuf sous-pages
  (`pages/profile/`) : `/profil/sorties` (`myParticipations`, onglets À venir · Historique, onglet et
  page dans l'URL `?vue=` / `?p=`), `/profil/preferences` (unités, fuseau, thème Système / Clair /
  Sombre, langue), `/profil/notifications` (Sur cet appareil, tableau type × canal groupé par famille
  — `notificationFamilies.ts`, `CONTENT_REPORTED` ajouté sous « Équipes et modération » —, Résumé
  quotidien par e-mail, Annonces des équipes, lien vers la boîte de réception, qui renvoie ici),
  `/profil/appareils`, `/profil/securite`, `/profil/vie-privee` et sa sous-page
  **`/profil/vie-privee/bloques`** (EN `/profile/privacy/blocked`, `blockedUsers`, désormais web,
  `parentId: 'profile-privacy'` — déplacée de `/profil/bloques` le 4 octobre, fil d'Ariane Profil ›
  Confidentialité › Utilisateurs bloqués), `/profil/compte` (Nom affiché toujours éditable, plus de
  mode « Modifier le profil », adresse en lecture seule, zone de danger : titre `c="danger"`, carte
  bordée par le nouveau `tone="danger"` de `ProfileCard`), `/profil/aide`. Les actions destructives
  du profil (déconnecter un service, désappairer, erreur de connexion GPS — `GpsConnectionsManager`,
  `PairedDevicesManager`) prennent aussi le jeton `danger`. Le tableau des notifications
  (`NotificationPreferences.module.css`) enveloppe chaque case d'un `<label>` qui remplit sa cellule :
  **cible de 44 × 44 px** sous `48em` ou en `pointer: coarse`, case visible à 20 px, densité
  inchangée au bureau. Bureau : barre
  latérale groupée (`ProfileShell.tsx`, non collante, `aria-current` sur l'entrée active) ;
  téléphone : liste groupée sur `/profil` terminée par Se déconnecter. Fil d'Ariane Profil ›
  Sous-page, le lien « ← Retour » (`navigate(-1)`) est supprimé. Préchargement serveur de chaque page
  dans `pages/profile/profileData.ts` et `myRidesData.ts`, câblé dans `config/routes.config.ts`.
  Supprimés : `UserProfilePage`, `pages/auth/profileData.ts`, `MyParticipations.tsx`,
  `profileAnchors.ts`. `FeaturesPromoCard` (`WEB-51`) mène à `/profil/appareils` ; les pages d'aide
  et la politique (`privacy/*.md`) citent les nouveaux chemins. Le thème et la langue de l'en-tête
  mettent à jour le `/me` en cache. Tests : vitest `profileStatus.test.ts`, `ProfileShell.test.tsx`,
  `NotificationPreferences.test.tsx`, `notificationFamilies.test.ts` (chaque `NotificationType` dans
  exactement une famille), `ProfileOverviewPage.test.tsx` ; e2e `profile-navigation.e2e.ts`,
  `ssr-session.e2e.ts` (HTML serveur de `/profil` et de `/profil/sorties` porteur de la sortie,
  hydratation propre), `routes-render.e2e.ts` (une ligne par route du profil), `flow-account`,
  `auth`, `flow-moderation` (`support/moderation.ts`, nouvelle URL des bloqués), `flow-device`,
  `flow-notifications`, `pwa` repris — **pas encore lancés** (`WEB-56`). **Tranché le 4 octobre**
  avec le propriétaire : Utilisateurs bloqués sous Confidentialité, même place que dans l'app. **À
  ne pas défaire** : les actions destructives du profil utilisent le jeton `danger`, jamais `red`
  brut ; la cible de 44 px des notifications est le `<label>` de la cellule, pas une case agrandie
  (le tableau du bureau garde sa densité) ; **arbre unique et lexique commun** aux deux clients
  (source web unique : `components/profile/profileNav.ts`) ; une route `/profil/<sujet>` par sujet,
  **sans redirection** des anciennes ancres `/profil#notifications`, `#gps` ni de
  `/profil/participations` (`WEB-58`) ; seuls les canaux de `NotificationPreferencesDto.channels`
  ont une colonne, pas de résumé quotidien sans `EMAIL`, un type sans réglage serveur n'a pas de
  ligne ; la bascule bureau / téléphone est **CSS seulement** (`visibleFrom` / `hiddenFrom`), jamais
  un `matchMedia` lu en JS (hydratation) ; le thème de Préférences lit `user.theme`, pas l'état
  local de Mantine ; `TimezonePreference` ne remplit le fuseau du navigateur qu'après hydratation
  et `ErrorReportingPreference` lit `localStorage` dans un effet ; Se déconnecter une seule fois
  dans le profil (le menu avatar et le tiroir gardent le leur) ; lignes du profil à `mih={44}`.

- `WEB-57` **Le lexique du profil vaut hors du profil, sur les deux clients et dans les e-mails**
  (4 octobre 2026, pas de changement de contrat). En français, partout : « Nom affiché » (plus
  « Nom d'affichage » : `auth.form.displayName`, `admin.users.displayName`,
  `admin.domains.namePlaceholder`), « Clé d'accès / Clés d'accès » (plus « Passkey » : connexion,
  `auth.errors.passkeyFailed`, `errors.api.PASSKEY_NOT_FOUND`, admin, pages Fonctionnalités ; sur
  l'app, connexion, activation par e-mail), « Adresse e-mail » pour tout champ et ses erreurs
  (connexion, inscription, mot de passe oublié, inscription bêta, colonnes d'admin ;
  `INVALID_CREDENTIALS`, `EMAIL_ALREADY_EXISTS`, `EMAIL_NOT_VERIFIED`, `PASSWORD_NOT_SET` sur l'app),
  et « e-mail » avec trait d'union dans toute phrase. En anglais : « Display name », « Email
  address », « passkey ». Fichiers : `frontend/src/locales/{fr,en}/common.json`,
  `mobile/assets/l10n/{fr,en}.json`, `privacy/privacy-policy.fr.md` (« nom affiché », source de
  `frontend/src/assets/legal/` via `pnpm copy-legal`). Le gabarit `ad-contact.{fr,en}.{html,txt}`
  du backend nomme le réglage et sa place : « désactivez « Être contacté par les membres » dans
  Profil › Confidentialité » (EN « Profile › Privacy »), sans lien (il faudrait un paramètre d'URL
  passé par le service). Tests repris : e2e `flow-account` (inscription, connexion, code e-mail,
  mot de passe oublié, compte existant, clé d'accès supprimée), `invitations`, `pwa`,
  `flow-device`, `flow-platform-admin` (inscriptions bêta) ; Patrol `modules/peripheral.dart`
  (« Adresse e-mail invalide », `apps_beta_signup_test`) ; widget
  `test/features/teams/pending_invitations_card_test.dart` — e2e et Patrol **pas encore lancés**
  (`WEB-56`, `MOB-49`). **À ne pas défaire** : le lexique est le même dans le profil et hors du
  profil, sur le site, l'app et les e-mails ; un terme change partout à la fois.

### Accueil et page Fonctionnalités

- `WEB-42` **Accueil visiteur, accueil membre, formulaire de connexion partagé** (3 octobre 2026,
  **API 10.6.0**, revue du 4 octobre intégrée). `HomePage` rend une version visiteur ou membre selon
  l'authentification ; le SSR anonyme rend la version visiteur. Visiteur : héros (pitch et
  formulaire, puis « Découvrir les fonctionnalités » sur téléphone), tuiles vers `/fonctionnalites`,
  fil public, bandeau des compteurs (Karoo, Garmin, Wahoo, téléphone), bandeau « créer une équipe »
  masqué en mono-équipe. Membre : salutation datée et résumé de la semaine, actions rapides pour
  organisateurs et admins seulement (sélecteur d'équipe s'il y en a plusieurs), `NextRideCard`
  refaite (section titrée, `registeredGroup`, menu « Envoyer vers l'appareil », états chargement,
  erreur et vide sous le même h2), `WeekAgenda` (`GET /api/calendar/events`, maintenant aligné sur
  l'heure → +7 jours, sans la prochaine sortie dans ses lignes), `MyTeamsCard`
  (`GET /api/teams?minRole=MEMBER&size=20`, ligne d'activité depuis `upcomingRideCount`,
  `upcomingTripCount`, `recentPostCount` — `API-66`), puis le fil (`HomeFeedSection`, région titrée,
  filtre de type en puces `radiogroup` « Type ») et une carte promo des fonctionnalités. Le
  formulaire est extrait dans `components/auth/LoginForm.tsx` (avec `OtpLogin`) : `afterSignIn`
  `'redirect'` (LoginPage, `?next=` et `from`) ou `'stay'` (héros), étape pilotable par
  `mode`/`onModeChange`, `initialMode` (LoginPage lit `mode: 'register'` ou `?mode=register`). Le
  prefetch SSR de `homeFeedData.ts` ajoute événements, équipes et services GPS pour une requête
  connectée. Tests : `LoginForm.test.tsx`, `HomePage.test.tsx`, `memberHome.test.tsx`, e2e
  `rides.e2e.ts` (« Aucune sortie à venir »). **À ne pas défaire** : la logique de connexion est
  partagée, jamais dupliquée ; le titre de `NextRideCard` reste enfant direct du corps de carte (les
  e2e lisent la carte par son parent) ; le lien de l'agenda s'appelle « Voir le calendrier » (pas de
  collision avec l'onglet « Calendrier ») ; les locators e2e du fil passent par `homeFeed(page)` ; la
  fenêtre de semaine part de `hourAlignedNowIso` pour que les clés de requête SSR et client
  coïncident ; les parcours prennent la couleur neutre `primary`, pas de couleur métier locale.
- `WEB-43` **Page publique `/fonctionnalites` (`/features`) et sa navigation** (3 octobre 2026, sans
  changement de contrat). Route `features` dans `contracts/routes.yaml` (web, builder Dart, pas de
  deeplink), ajoutée à `scripts/routes-ssr.yml`, au `sitemap.xml` après `/` et à `llms.txt`.
  Statique et sûre en SSR : ni prefetch ni appel d'API, méta SEO `featuresMeta`. Héros, puces de
  section, 8 fonctionnalités (sorties, parcours, voyages, publications, annonces, calendrier,
  compteurs, vie privée), rôles, appel final (variante mono-équipe), barre collante
  inscription/connexion pour les visiteurs sur téléphone ; « Retour au fil » une fois connecté ;
  « Parcourir les équipes » masqué en mono-équipe ; chaque « Créer un compte » ouvre l'étape
  d'inscription. Liens dans l'en-tête, le tiroir mobile et le pied de page. Tests :
  `FeaturesPage.test.tsx`, `sitemap.test.ts`, `llmsTxt.test.ts`. **À ne pas défaire** : les
  illustrations sont décoratives (`aria-hidden`, rien de focalisable, boutons en `span` via
  `DemoButton`) ; l'annonce montre un secteur flouté, jamais une épingle ni d'adresse de contact ;
  Karoo, Garmin et Wahoo sont listés à l'identique, sans mention de disponibilité ni description de
  l'envoi ; le CSS vit dans `index.css` (classes `features-*`), pas dans un module CSS qui
  arriverait après le premier rendu SSR d'une page paresseuse ; les puces défilent par
  `scrollIntoView` + `history.replaceState`, pas par une navigation de hash (lue comme un POP).

- `WEB-45` **Navigation principale dans l'en-tête** (4 octobre 2026, décidé avec le propriétaire).
  Fil · Équipes · Calendrier (connecté) · Parcours · Fonctionnalités passent de la rangée d'onglets
  de l'accueil à l'en-tête (`MainNav`, libellés à partir de `lg`, icônes avec info-bulle entre `sm`
  et `lg`) et au tiroir mobile ; `HomeLayout` est supprimé. `useHomeNavItems` reste la source unique
  (fil d'Ariane compris), `useMainNavItems` y ajoute Fonctionnalités ; l'entrée active vient de
  l'URL (`activeMainNavId`, remontée de `parentId` dans `routes.config.ts`), « Équipes » s'allume
  sur les pages d'équipe. Tests : `MainNav.test.tsx` ; e2e via `mainNavLink` (`e2e/support/ui.ts`).
  **À ne pas défaire** : un seul endroit définit les entrées de navigation ; le nom affiché près de
  l'avatar reste visible à partir de `md` car l'e2e desktop trouve le menu du compte par ce nom.

- `WEB-60` **Météo des sorties au web** (5 octobre 2026, contrat `10.9.0`, `API-74`). Le détail
  d'une sortie lit `getRideWeather` dans `useRideDetailData`, préfetché en phase 1 de
  `prefetchRideDetail` (même clé, `skipErrorToast`), et montre `RideWeatherSection` sous un
  `ErrorBoundary variant="inline"`, entre l'en-tête et la carte : météo au départ (lever et coucher
  du soleil compris), choix du groupe (celui de l'inscrit, sinon le premier ; `SegmentedControl`
  jusqu'à 4 groupes, `Select` au-delà), frise des points, bandeau pluie, barre d'exposition au vent
  dans les couleurs générées `RELATIVE_WIND_COLORS`, mention de la vitesse par défaut, attribution
  Open-Meteo.com en lien. `STALE` porte un badge « Prévision ancienne », `NOT_YET_AVAILABLE` la date
  d'ouverture, `UNAVAILABLE` (ou une lecture en échec) un « Réessayer » ; `NO_LOCATION` n'apparaît
  qu'avec `canEdit`. `RideWeatherSummaryLine` est dans `PublicationCard` (sorties) et `NextRideCard`.
  Température dans `unitFormat.ts` / `useUnits` (°F en impérial, jamais « -0 »), `formatTime` et
  `FormattedTime`. `invalidateRideWeather` est appelé après chaque action sur la sortie et après
  `EditRidePage` (sa clé ne commence pas par celle de la sortie). Tests : `weatherDisplay.test.ts`,
  `RideWeatherSummaryLine.test.tsx`, `RideWeatherSection.test.tsx`, cas de température de
  `unitFormat.test.ts`. **À ne pas défaire** : une seule table `weatherDisplay.ts` (condition ×
  jour/nuit → icône Tabler, repli `IconCloud`) ; les icônes de condition n'ont **pas de teinte**
  (elles prennent la couleur du texte, comme au mobile) : une teinte passerait par
  `contracts/brand-colors.yaml`, jamais par une table locale ; le vent relatif est toujours doublé du
  libellé et de la flèche ; le client ne calcule rien d'autre que l'affichage ; le bloc est masqué
  pour une sortie terminée ou annulée et pour un statut inconnu ; la requête part quand même (le
  serveur répond `OUT_OF_RANGE` sans rien lire), pour garder la clé du préfetch.
- `WEB-67` **Météo des étapes de voyage au web** (6 octobre 2026, contrat `10.11.0`, `API-76`).
  `useGetTripWeather` est lu (et préfetché en phase 1, `TRIP_WEATHER_REQUEST` sans toast) par
  `useTripDetailData` et `useStageDetailData`. La page d'étape montre `StageWeatherSection` sous un
  `ErrorBoundary variant="inline"`, entre l'en-tête et le parcours : l'état propre de l'étape
  (badge `STALE`, date d'ouverture, « Réessayer », `NO_LOCATION` aux organisateurs seulement, rien
  pour `OUT_OF_RANGE` ni un statut inconnu) puis `LegWeather` libellé pour une étape. Chaque
  `TripStageCard` du détail de voyage porte `RideWeatherSummaryLine` nourrie par
  `stages[].summary`. `LegWeather` et `WeatherAttribution` sont sortis de `RideWeatherSection` pour
  être partagés. `invalidateTripWeather` suit chaque invalidation du voyage (statut, édition).
  Clés `trips.weather.*` (fr, en). Test : `StageWeatherSection.test.tsx`.

---

### Tableau de bord d'équipe

- `WEB-63` **Tableau de bord d'équipe selon le rôle** (6 octobre 2026, **API 10.8.0**, `API-79`).
  Pour un membre connecté, `/equipes/{slug}` ouvre le tableau de bord (`TeamDashboardPage`,
  composants `components/team/dashboard/`) ; visiteurs et non-membres gardent le fil, que les membres
  trouvent à `?tab=publications` (`teamFeedPath`, `showsTeamDashboard` dans
  `pages/team/teamHomeData.ts`, `tab` gardé par les filtres du fil). Membre : prochaines sorties
  (envoi vers l'appareil), sorties à venir avec remplissage par groupe, publications, parcours,
  annonces (« Prix à négocier », secteur en texte). Organisateur et admin : « Créer une sortie »,
  « Nouvelle publication », bande « À traiter » (brouillons, sans parcours, groupe complet,
  signalements), « Modifier », « Créer depuis un modèle ». Admin : panneau Administration (rôles,
  nouveaux membres, fonctionnalités, webhook, « Inviter »), onglet « Membres ». Sous `sm`, les
  actions d'en-tête passent en icônes avec `aria-label`. `CreateRidePage` lit `?template=` et
  `TeamMembersPage` `?invite=1` (adresses utilisées par le mobile). Tests : `TeamDashboard.test.tsx`,
  `useTeamNavItems.test.tsx`, `CreateRidePage.test.tsx` ; e2e `team-dashboard.e2e.ts` (trois rôles,
  non-membre, fil à `?tab=publications`) et `list-filters`, `pagination`, `pinned-host`,
  `flow-posts` adaptés ; `routes-render` de la route `team` vert. **À ne pas défaire** : toute
  mutation qui change ce que montre le tableau de bord l'invalide (`lib/teamDashboardCache.ts`,
  `routeCacheInvalidation`, `moderationCacheInvalidation`) ; `prefetchTeamHome` s'arrête quand
  l'équipe n'a pas pu être lue — sinon le fil la relit et une 404 est demandée deux fois
  (`error-states.e2e.ts`) ; pas de route nouvelle dans `contracts/routes.yaml` (levé pour les
  deux listes par type de `WEB-64`).
- `WEB-64` **Onglets « Sorties » et « Voyages » de la maquette** (6 octobre 2026, sans changement
  de contrat d'API). Décision de l'utilisateur : deux routes de liste par type plutôt que le seul
  fil filtré. `contracts/routes.yaml` gagne `teamRides` (`/equipes/{teamSlug}/sorties`,
  `/teams/{teamSlug}/rides`) et `teamTrips` (`/equipes/{teamSlug}/voyages`, `/teams/{teamSlug}/trips`),
  en `mobile` et `deeplink` : l'app n'a pas de liste par type, mais les motifs de lien profond de
  l'équipe (`/equipes/*` dans l'AASA, `/equipes/.*` dans le manifeste Android) captent ces chemins
  quoi que dise `routes.yaml` — publiées web seulement, elles ouvraient l'app sur sa page d'erreur
  (corrigé après relecture, même jour). Le `GoRouter` les rend en `TeamHomePage` section `feed`,
  avec `feedType` (`PublicationFeedView.initialType`, type de départ que les chips peuvent
  changer) ; elles sont dans `internalRouteTemplates` et `_deepLinkHierarchies` (équipes → équipe).
  Ce type initial reste **local au fil** jusqu'au premier choix sur les chips — ne pas le recopier
  dans `publicationFeedTypeProvider`, partagé par tous les fils de l'équipe : le fil de l'équipe
  empilé dessous par le lien profond passait aussi sur « Sorties » et y restait au retour (corrigé
  après relecture, même jour).
  Test mobile : `team_kind_tab_links_test.dart` (lien interne, ancêtres, écran résolu, première
  page déjà filtrée, fil du dessous resté sur « Tout »), `deep_link_hierarchy_test.dart`. Les
  routes `team-rides` et `team-trips` (`routes.config.ts`, publiques, sous `team-detail`) rendent
  `PublicationListPage` avec `kind` (`TeamRidesPage`, `TeamTripsPage`) : le même fil, le même
  `publicationListData.ts`, où `withListKind` impose le type de la route à la place de `?type=`
  côté page comme côté prefetch — mêmes clés de requête. Sur un onglet, le sélecteur de type
  disparaît, le titre, l'état vide et le total (`ResultCount` `rides`/`trips`) suivent le type,
  le bouton de création ne propose que ce type, et un module coupé renvoie à la page de l'équipe.
  Les onglets suivent « Fil d'actualités » dans `useTeamNavItems`, pour tous les visiteurs,
  gardés comme le sélecteur de type et le backend (`enableRides`/`enableTrips` **et**
  `enableRoutes`). « Voir tout » des sorties à venir du tableau de bord mène à
  `/sorties?w=upcoming`. Les anciens liens `?tab=publications&type=ride` marchent toujours : le
  fil garde son sélecteur. Tests : `useTeamNavItems.test.tsx` ; e2e `team-dashboard.e2e.ts`
  (onglet « Sorties », lien « Voir tout ») et `routes-render.e2e.ts` (`teamRides`, `teamTrips`).
  **À ne pas défaire** : un onglet par type n'a pas de lecture à lui — il passe par
  `usePublicationListData`/`prefetchPublicationList` avec son `kind`, sinon page et prefetch
  divergent ; une sortie ou un voyage reste sous `team-detail` dans le fil d'Ariane (on y arrive
  aussi du fil et du tableau de bord) ; `teamRides` et `teamTrips` restent `mobile` avec un
  écran dans l'app tant que `/equipes/*` est un motif de lien profond — repassées web seules,
  le lien ouvrirait de nouveau l'app sur sa page d'erreur.

### Agenda et Publications

Plan [`2026-10-06-team-agenda.md`](plans/archive/2026-10-06-team-agenda.md) §4, §5 et §7.

- `WEB-68` **Le fil d'équipe remplacé par « Agenda » (sorties et voyages) et « Publications »**
  (6 octobre 2026, sans changement de contrat d'API : lit `when` et `endDateTime` d'`API-85`,
  contrat `10.15.0`, et le tableau de bord ouvert d'`API-86`, `10.16.0`). Le fil mélangeait deux
  temporalités : « À venir » y triait du plus lointain au plus proche, « Je participe » ne bornait
  pas la date, et ces filtres s'appliquaient aux publications. `contracts/routes.yaml` gagne
  `teamAgenda` (`/equipes/{teamSlug}/agenda`) et `teamPosts` (`/equipes/{teamSlug}/articles`,
  parent des adresses de publication existantes), `web`, `mobile` et `deeplink`.
  - **Agenda** (`pages/team/TeamAgendaPage.tsx`, `teamAgendaData.ts`) : « À venir » (défaut) ·
    « Je participe » (connecté) · « Passées », projetés par `agendaApiParams`
    (`hooks/filters/agendaFilters.ts`) sur `when=UPCOMING|PAST` (+ `participating`) — le serveur
    trie ; plus de `from=now`, donc plus d'horloge dans la clé de requête. Type Tout / Sorties /
    Voyages (chaque type selon ses modules), bouton « Filtres » (recherche, tags du type choisi ;
    sans type, champ désactivé et « Choisissez Sorties ou Voyages pour filtrer par tag. »), nombre
    de résultats par période et type (« 5 sorties et voyages à venir »), `ListViewSwitch`
    Vignettes · Lignes (`?view=`) · Calendrier. État vide : « Rien à l'agenda pour le moment ».
  - **Publications** (`TeamPostsPage.tsx`, `teamPostsData.ts`, `teamPostFilters.ts`) : les
    publications seules, la plus récente d'abord, recherche et tags, sans filtre de date.
  - **Tableau de bord pour tous** : `TeamHomePage` le rend toujours (visiteur : ni badge de rôle,
    ni « S'abonner au calendrier », ni blocs de membre) ; `prefetchTeamHome` lit l'équipe et le
    tableau de bord côte à côte. « Voir tout » : « Mes prochaines » → `teamAgenda?w=me`,
    « Prochaines sorties » → `teamAgenda`, « Dernières publications » → `teamPosts`.
  - **Redirections** (`pages/team/teamLegacyRedirects.ts`) : nouvelle option `redirect` des routes
    (`routes.types.ts`), lue par le loader avant le prefetch, qui lève `replace()` — 302 côté SSR
    (traduit en espace navigateur sur un hôte épinglé), entrée d'historique remplacée côté client.
    `team?tab=publications&type=post` → `teamPosts` ; `…&type=ride|trip` → `teamAgenda?type=…` ;
    `?tab=publications` seul → `team` ; `w=me` gardé, `w=upcoming`/`w=all` → « À venir » ;
    `teamRides` → `teamAgenda`, `teamTrips` → `teamAgenda?type=trip`. Recherche et tags suivent.
  - **Supprimés** : `PublicationListPage`, `publicationListData.ts`, `TEAM_FEED_TAB`,
    `teamFeedPath`, `showsTeamDashboard`, le schéma `teamPublicationFiltersSchema` et l'onglet
    « Calendrier ». Le fil d'accueil transverse (`home`) n'est pas touché (plan §7).
  - **Onglets** (`useTeamNavItems`) : Tableau de bord, Agenda, Publications, Parcours, Annonces
    (membres), Membres (administrateurs), À propos, pages perso — icônes de la charte (`BRAND-6`).
    Fil d'Ariane : sortie et voyage sous l'Agenda, publication sous les Publications, calendrier
    sous l'Agenda.
  - **« En cours »** (`utils/publicationTiming.ts` `isUnderWay`, `components/agenda/InProgressBadge`)
    : départ passé et `endDateTime` à venir, sortie annulée exclue — état dérivé client, vert doux
    à pastille, sur les cartes et les lignes. La fin s'affiche « 08:30 → retour vers 14:10 », un
    voyage « ven. 16 → dim. 18 oct. » (`PublicationTimeSpan`) ; vue Lignes `AgendaRow` avec le
    `DayBox` partagé avec « Mes prochaines ».

  Tests : `agendaFilters.test.ts`, `teamLegacyRedirects.test.ts`, `publicationTiming.test.ts`,
  `useTeamNavItems.test.tsx`, `TeamDashboard.test.tsx` (visiteur, « Voir tout »),
  `tagFilters.test.ts` ; e2e adaptés (à lancer sur la stack e2e) : `team-dashboard`,
  `list-filters`, `pagination`, `pinned-host`, `flow-posts`, `routes-render`, et `flow-rides`,
  `flow-trips`, `flow-team`, `flow-moderation`, `team-misc`, `slug-change`. **À ne pas défaire** :
  page et prefetch de l'Agenda passent par le même `agendaApiParams` — le défaut « À venir » vit
  dans le schéma, jamais dans la page seule ; une ancienne adresse se redirige dans le loader
  (`replace()`), pas par un `<Navigate>` après rendu, sinon le serveur rend une page que le
  client quitte et l'ancienne adresse reste dans l'historique ; `teamRides` et `teamTrips`
  restent au contrat (`mobile`, `deeplink`) pour les liens déjà diffusés ; le calendrier reste
  aux membres (plan §7) : pas de vue Calendrier pour un visiteur.
- `WEB-69` **Un seul sélecteur de vue pour Parcours et Agenda** (6 octobre 2026, sans changement
  de contrat d'API). `ListViewSwitch` (`components/common/`, icônes seules dans un
  `SegmentedControl` libellé « Affichage », chaque vue nommée par un texte masqué dans le
  `<label>` de sa radio, infobulle) remplace `RouteViewToggle` et `RouteDensityToggle`. Parcours
  (`RouteViewSwitch`, les quatre pages) : Vignettes · Lignes · Carte, à droite du nombre de
  résultats ; la densité vit dans `?view=card|row`, qui remplace `?d=` ; Carte garde
  `routesMap`/`allRoutesMap` et le sélecteur y navigue en gardant les filtres. Agenda :
  Vignettes · Lignes · Calendrier ; Calendrier mène à `teamCalendar` en gardant le type et
  « Je participe », la page Calendrier (titrée « Agenda », filtres « Tout / Je participe » et type
  appliqués aux événements de la fenêtre) ramène aux lignes ou aux vignettes ; un visiteur n'a pas
  la vue Calendrier, et `teamCalendar` le renvoie à l'Agenda. Tests : `ListViewSwitch.test.tsx`,
  `RouteViewSwitch.test.tsx` ; e2e `list-filters`, `flow-routes`, `routes-render`
  (`teamCalendar`), `team-dashboard` (pas de Calendrier pour un visiteur). **À ne pas défaire** :
  le composant reste présentationnel — où vit la vue (`?view=`, un chemin) appartient à la page ;
  Carte et Calendrier gardent leur chemin pour les liens existants. Le mock `ResizeObserver` de
  `src/test/setup.ts` est une classe : Mantine le construit avec `new`.

## API — Contrat d'API et backend

### Concurrence : constats de la modélisation formelle du 11 octobre 2026

Une modélisation TLA+/TLC et Lean 4 du backend ([`formal/`](formal/) ; deux instances pendant un
déploiement start-first, READ COMMITTED) a mis au jour dix-sept défauts ; chacun a été reproduit par un test qui échouait
avant le correctif. Les constats de sécurité sont sous `SEC-34` à `SEC-38`, les autres sous `NOTIF-10`,
`ISSUE-8`, `ISSUE-9`, `MIG-15`.

- `API-94` **Une réponse de refresh perdue ne révoque plus la session** (2026-10-11, **API 11.0.1**, patch : description de `POST /auth/refresh` ; pas de migration ; constat de la modélisation formelle TLA+/Lean) — quand la réponse d'un refresh se perdait après la rotation (réseau cellulaire coupé, app tuée en pleine requête, Karoo derrière le Bluetooth du téléphone), le client gardait l'ancien jeton t0, devenu le jeton précédent de la session ; un nouvel essai dans la grâce répondait `IN_GRACE` sans nouveau jeton, et le refresh suivant, passé les 60 s (démarrage à froid du mobile, expiration du jeton d'accès, chargement des parcours du Karoo), était pris pour un rejeu : la session était révoquée et le Karoo désappairé, sans qu'aucun tiers ait jamais détenu le jeton. Avec un seul emplacement de jeton précédent, le serveur ne peut pas distinguer ce cas d'une copie volée : un successeur déjà présenté aurait fait sortir t0 de la session. Désormais, un jeton précédent présenté passé la grâce **est renouvelé à nouveau à partir de lui-même** (`RefreshTokenRotation.refresh`, `AuthSessionRepository.rotateFromPrevious`, `update` conditionnel sur le jeton précédent **et** le jeton courant) : il reste le jeton précédent et ouvre une nouvelle grâce (un doublon concurrent ou un nouvel essai tombe en `IN_GRACE`), le successeur perdu meurt (inconnu, 403 / `TOKEN_INVALID`, sans révocation), et t0 meurt dès que le nouveau jeton est présenté. `Outcome.REPLAYED` et `AuthSessionRepository.revokeById` disparaissent. Arbitrage de sécurité assumé, qui amende la décision « rejeu = révocation » de `SEC-27` : la détection étroite (voleur puis titulaire, dans cet ordre) cède la place à « le dernier qui présente le jeton précédent reprend la chaîne, l'autre est refusé à son refresh suivant » ; l'expiration de la session et `logoutAll` bornent toujours un jeton volé. Conséquence assumée : un jeton précédent volé n'est plus inutilisable passé la grâce, il reprend la chaîne en silence ; le titulaire est refusé à son refresh suivant (403, sans révocation) et doit se reconnecter, et ce jeton reste « précédent » tant que le titulaire ne rafraîchit pas — toute la vie de la session pour un Karoo ou un onglet inactifs. Les commentaires des supports e2e (`data.ts`, `flow-account.ts`, `ssr.ts`, `fixtures.ts`, `global-setup.ts`) sont mis à jour. Tests : `RefreshLostResponseReplayRaceTest` (nouvel essai dans la grâce puis refresh après, démarrage à froid après la grâce, même chose pour un appareil), et `AuthServiceTest.refreshToken_previousTokenAfterTheGrace_rotatesAgainFromIt` et `DeviceRefreshRotationTest.refresh_previousTokenAfterTheGrace_rotatesAgainFromIt`, qui remplacent les deux tests `…revokes…`. Les commentaires `ssrSession.ts`, `auth.e2e.ts` et `frontend/e2e/README.md` sont mis à jour. **À ne pas défaire** : ne pas rétablir la révocation sur le jeton précédent passé la grâce tant que le serveur ne sait pas prouver que le successeur a été livré ; ne pas remplacer le jeton précédent par le successeur abandonné lors du nouveau renouvellement (un t0 concurrent, ou une seconde réponse perdue, déconnecterait le client) ; garder la condition sur le jeton courant dans `rotateFromPrevious`, sans quoi deux refresh simultanés avec t0 émettraient deux jetons dont un seul survit.

- `API-95` **Un échec du mail « export prêt » ne jette plus l'export RGPD terminé** (2026-10-11, contrat inchangé, constat de la modélisation formelle TLA+/Lean) — l'envoi du mail et `markEmailSent` étaient dans le même `try` que la construction : une panne SMTP (ou de base sur `markEmailSent`) tombait dans le `catch`, `markFailed` repassait la ligne READY en PENDING (puis FAILED au troisième essai), annulait `storageKey` et `safeDelete` supprimait l'archive, que `retryPendingEmails` ne voyait donc jamais. Le mail part désormais par `UserExportService.sendReadyMail`, qui ne lève jamais, et un drapeau `ready` posé juste après `markReady` empêche le `catch` de rien annuler ni supprimer une fois la ligne READY (même si le commit a eu lieu et que l'appel lève quand même) : sur échec, `markEmailFailed` inscrit l'erreur dans `errorMessage` et la ligne reste READY avec son archive, reprise au tick suivant. `markFailed` n'agit plus que sur une ligne PROCESSING. Couvert par `UserExportMailFailureKeepsArchiveTest` (3 cas). **À ne pas défaire** : le drapeau `ready` : rien après `markReady` ne doit pouvoir faire supprimer l'archive par le `catch`, et `markFailed` garde sa garde `status == PROCESSING`.

- `API-96` **La reprise des mails d'export ne remplace plus le lien d'un mail encore en cours d'envoi** (2026-10-11, contrat inchangé, constat de la modélisation formelle TLA+/Lean) — pendant un déploiement, `retryPendingEmails` sur l'autre instance prenait toute ligne READY sans `emailSentAt`, y compris celle dont l'instance A envoyait le mail. Elle changeait le hash du jeton et envoyait un second mail, et le lien du premier tombait en 404. La reprise passe désormais par `UserExportRepository.findEmailRetryDue` : seules les lignes dont le dernier envoi a échoué (`errorMessage` renseigné) ou dont le lien a été émis il y a plus de `pedalons.export.email-retry-grace-minutes` (10 min) sont reprises. L'heure d'émission se déduit de `expiresAt - expiryDays`, donc aucune migration n'est nécessaire. La rotation passe par un compare-and-set, `claimEmailRetry`, dont le WHERE reprend le même prédicat et qui remet `errorMessage` à null, si bien que deux instances qui relancent en même temps n'envoient qu'un mail. Couvert par `UserExportEmailRetryRaceTest`. **À ne pas défaire** : la reprise ne touche pas un lien récent sans échec enregistré ; markReady et la reprise posent tous deux `expiresAt = now + expiryDays` (la garde en dépend) ; la rotation reste une mise à jour conditionnelle, pas un findById suivi d'un set.

- `API-97` **`AssetCleanupScheduler` ne supprime plus le fichier S3 avant le commit** (2026-10-11, contrat inchangé, constat de la modélisation formelle TLA+/Lean) — `AssetRemoveListener` effaçait l'objet S3 dans `@PreRemove`, donc dès `em.remove()` et avant le flush. Pendant le balayage nocturne, une sauvegarde qui rattachait un asset orphelin committait, le DELETE versionné du balayage échouait (`OptimisticLockException`) et tout le lot était annulé. L'asset rattaché gardait sa ligne sans fichier (image cassée pour de bon), et chaque autre orphelin du lot restait une ligne sans fichier qu'une sauvegarde pouvait encore rattacher. Même chose pour tout rollback après un `orphanRemoval` ou dans `AccountErasureService`. Désormais le listener calcule la clé tout de suite, puis inscrit une `Synchronization` (`TransactionSynchronizationRegistry`) qui ne supprime le fichier qu'en `afterCompletion(STATUS_COMMITTED)`. Sans transaction JTA, la suppression reste immédiate ; une transaction déjà marquée pour rollback ne supprime rien. Couvert par `AssetCleanupPreCommitFileDeleteRaceTest` et, dans `AssetServiceTest`, par `shouldDeleteS3WhenAssetIsDeleted` (fichier présent jusqu'au commit), `shouldKeepS3WhenAssetDeleteRollsBack` et `shouldDeleteS3WhenOrphanRemoved`. **À ne pas défaire** : ne jamais supprimer un fichier de stockage depuis un callback JPA ou avant le commit de la transaction qui supprime sa ligne. Un fichier orphelin après un échec S3 vaut mieux qu'une ligne sans fichier.

- `API-98` **Des inscriptions simultanées ne dépassent plus `maxParticipants`** (2026-10-11, contrat inchangé, constat de la modélisation formelle TLA+/Lean) — `RideService.joinGroup` vérifiait la capacité (`RideGroup.hasCapacity()`, taille de la collection) puis insérait sans aucun verrou : deux membres rejoignant la dernière place en même temps voyaient chacun N-1 < N et validaient tous deux, l'index unique `(ride_group_id, user_id)` ne couvrant pas deux utilisateurs distincts et le `@Version` du groupe n'étant pas incrémenté par une collection `mappedBy`. `joinGroup` verrouille maintenant la ligne de la sortie (`RideRepository.lockForJoin`, `refresh` en `PESSIMISTIC_WRITE`, soit `SELECT … FOR UPDATE`) avant de lire le groupe et de charger ses participations : les inscriptions à une même sortie passent l'une après l'autre et la seconde reçoit `GROUP_FULL`. Sous ce verrou, `joinGroup` revérifie aussi que la sortie est toujours publiée (403 sinon) : une annulation validée entre le contrôle d'accès et le verrou ne laisse plus passer d'inscription. Pas de migration. Test : `RideGroupCapacityRaceTest`. **À ne pas défaire** : le verrou est pris avant toute lecture des participations (une collection chargée avant lui compterait des lignes périmées), et c'est un `refresh` et non un `lock()`, pour qu'une modification de la sortie par un organisateur entre-temps ne fasse pas échouer l'inscription sur le contrôle de version.

- `API-99` **Un membre ne peut plus être inscrit dans deux groupes d'une même sortie par deux inscriptions simultanées** (2026-10-11, contrat inchangé, constat de la modélisation formelle TLA+/Lean) — le contrôle `findByUserAndRide` de `joinGroup` ne voyait pas l'inscription non encore validée d'une requête concurrente (téléphone et onglet web, deux onglets) vers un autre groupe, et rien en base n'interdit deux lignes (g1,u) et (g2,u) : la place était prise deux fois, `registeredGroup` montrait un groupe au hasard, et « Quitter » laissait l'autre inscription. Le même verrou sur la ligne de la sortie qu'`API-98` (`RideRepository.lockForJoin`) sérialise les inscriptions : la seconde voit la première et reçoit `ALREADY_REGISTERED`. Test : `RideJoinTwoGroupsRaceTest`. **À ne pas défaire** : le verrou porte sur la sortie et non sur le groupe, la règle couvrant tous les groupes de la sortie ; une colonne `ride_id` dénormalisée avec un index unique a été écartée (migration et rétro-remplissage compatibles avec la version précédente pendant un déploiement progressif, et elle ne règle pas `API-98`).

- `API-100` **Le planificateur météo ne verrouille plus les `weather_cells` contre le stockage du fetch** (2026-10-11, contrat inchangé, constat de la modélisation formelle TLA+/Lean) — `WeatherPlanner.plan` était une seule transaction `@Transactional` : chaque `upsertDemand` (`INSERT … ON CONFLICT DO UPDATE`) gardait le verrou de sa ligne jusqu'à la fin de la passe, dans l'ordre du `HashMap`. La transaction de stockage de `WeatherFetchWorker.fetchAndStore` prend les mêmes lignes dans l'ordre non trié du claim : PostgreSQL détectait un deadlock (40P01). Quand la victime était le worker, la réponse Open-Meteo déjà payée était jetée et `markFailed` mettait tout le lot en backoff (`attempts = 1`, `store: …`). Désormais la demande est lue dans une transaction, puis chaque cellule est upsertée dans la sienne (`QuarkusTransaction.requiringNew()`) : le planificateur ne tient plus aucun verrou de cellule pendant qu'il en attend un autre, et ne peut donc plus fermer de cycle, ni avec le stockage, ni avec `markFailed`/`release`, ni avec l'autre planificateur d'un déploiement roulant. Couvert par `WeatherPlannerStoreDeadlockRaceTest`. **À ne pas défaire** : ne pas remettre `plan()` dans une seule transaction ; trier la demande ne suffirait pas, car les `UPDATE … where id in` multi-lignes de `markFailed`/`release` verrouillent sans ordre garanti. Une passe interrompue ne perd rien : les upserts sont idempotents et le tick suivant les réécrit.

- `API-101` **Réenregistrer une sortie passée après un changement de fuseau de l'équipe ne décale plus ses groupes de ±24 h** (2026-10-11, contrat inchangé, constat de la modélisation formelle TLA+/Lean). Le changement de fuseau (`TeamTimezoneChange.rewriteRide`) réétiquette une sortie passée à instant constant sans toucher à ses groupes. Un groupe peut alors partir à une autre date locale que sa sortie, par exemple Paris → Martinique : sortie le 11 à 23 h 30, groupe le 12 à 0 h 30. L'heure propre du groupe (`RideGroupDto.time`, `EventTimezoneResolver.ownTime`) ne porte pas de date, et `updateRide` la reposait sur la date de la sortie. Un simple réenregistrement sans modification déplaçait donc le groupe de 24 h, parfois avant la sortie elle-même, puis recalculait la fin stockée à partir de là. Désormais `EventTimezoneResolver.dayOffset` mesure l'écart en jours entre la date locale du groupe et celle de sa sortie, lu sur l'état stocké avant l'enregistrement. `RideService.updateRide` le conserve pour chaque groupe existant (`setStart(…, dayOffset)`), et la branche « à venir » de `rewriteRide` le reporte aussi. Les groupes saisis normalement ont un écart nul, donc rien ne change pour eux. Couvert par `TeamZoneChangePastRideResaveTest`, vers l'ouest (Martinique, −24 h) et vers l'est (Tokyo, +24 h). **À ne pas défaire** : l'écart se lit dans l'ancien fuseau, sur l'ancienne date de la sortie, *avant* `setTimezone`/`setDateTime`. Il ne faut pas remplacer ce mécanisme par « l'occurrence la plus proche de la sortie », ce qui changerait le sens des groupes saisis loin de l'heure de la sortie. Il ne faut pas non plus ajouter de date au DTO, ce qui casserait le contrat.

### Reprises immédiates

Le détail de chacune est dans l'historique git de ce fichier et de `LEDGER_NEXT.md` (ex-`NEXT.md`).

- `API-35` Le compteur `GET /api/teams/{teamSlug}/classifieds/count` (contrat `2.3.0`).
- `API-36` `Retry-After` déclaré sur le 429 de `POST /api/users/me/export` (contrat `2.3.1`).
- `API-37` Le document d'API archivé, laissé tel quel à `1.5.0` avec une note de tête.
- `API-38` Les slugs réservés (`SlugService.RESERVED_SLUGS`) — vérifié le 31 juillet 2026 sur la
  base de production, aucune route ni page d'équipe n'en portait, pas de backfill.

### Petites évolutions d'API

| ID | Livré | Écrans |
|---|---|---|
| `API-1` | URL de tuile authentifiable — **API 2.3.0** : `POST /api/tiles/token` puis `?t=` sur les deux `.mvt`. Le repli GeoJSON et son plafond ont été supprimés, le tap lit les propriétés de la tuile comme le web | 21 |
| `API-2` | **Logo d'équipe sur `TeamPublicationDto`** (2026-09-30) — **API 5.8.0** : `logoUrl`, nullable, même valeur que `TeamDetailDto.logoUrl` (le logo de la page « À propos », gabarit `{size}`). Il vient de deux `@Formula` de `Team` (`logoAssetId`, `aboutPageVisibility`), des sous-requêtes corrélées lues dans le `SELECT` même qui charge l'équipe : aucune requête ni entité de plus par ligne, ni par équipe, et `Team.aboutPage` reste LAZY. Ne pas le remplacer par une marche sur `aboutPage.assets` (c'est ce que le LAZY évite), ni par une table de correspondance à passer à la douzaine de fabriques qui construisent `TeamPublicationDto`. Le mobile passe le logo à `PdlTeamLine` (fiche et carte de sortie, publication, voyage, annonce via `TeamBanner`, page d'équipe, carrousel, prochaine sortie, carte et fiche de parcours) avec les initiales en repli. Le web n'avait pas ce repli : ses fiches lisent l'équipe entière (`TeamContextBanner`), ses cartes n'ont qu'une icône, rien à changer. Couvert par `PostResourceTest.getPost_carriesTheTeamLogo_sameAsTheTeamDetail` (fiche et liste compacte, identique à la fiche d'équipe), les `…QueryCountTest` verts, et `post_detail_page_test.dart` (logo, puis initiales sans logo) | 11, 12, 13, 24, 31, 32 |
| `API-3` | **Vignette du parcours du groupe** (2026-09-30) — **API 5.10.0** : `RideGroupDto.thumbnailLightUrl`, `thumbnailDarkUrl` et `thumbnailUrl` (la claire d'abord, sinon la sombre — la règle de `RideDto`), tous nullables, les vignettes du parcours du groupe. Les deux variantes thémées sont là en plus du champ réduit parce que le mobile rend la sombre en thème sombre. Nuls pour un groupe sans parcours : **jamais la vignette de la sortie en repli côté serveur**, le client l'a déjà. Résolues pour tous les groupes de la sortie par **une** requête `ThumbnailLookup.forTeamEntities` (`RideService.toDto`) ; ne pas remplacer par une marche sur `route.getAssets()` par groupe. Les groupes n'étant rendus que sur le détail, la liste n'est pas touchée. Le mobile (`next_ride_card.dart`, « Ma prochaine sortie ») rend la vignette du groupe, celle de la sortie en repli (`nextRideThumbnailUrl`). Le web ne rendait pas de vignette par groupe : rien à changer. Couvert par `RideResourceTest.getRide_groupsCarryTheirOwnRouteThumbnail` (deux variantes, sombre seule, groupe sans parcours), `PublicationQueryCountTest.rideDetail_groupRouteThumbnails_costDoesNotScaleWithGroupCount` (1 puis 6 groupes sur 6 parcours) et `next_ride_thumbnail_test.dart` | 11 |
| `API-4` | **Le groupe rejoint sur les lignes de liste** (2026-10-01) — **API 9.3.0** : `RideDto.registeredGroup`, nullable, le `RideGroupDto` complet du groupe que l'utilisateur courant a rejoint (nom, horaire, parcours et ses chiffres, vignettes, capacité, aperçu des inscrits, meneur). Forme tranchée : **un seul groupe complet** plutôt que `groups[]` sur chaque ligne — seul celui-là sert à « Ma prochaine sortie », et le type est celui du détail, que la carte rendait déjà. Il est aussi rempli sur le détail (le même objet que l'entrée correspondante de `groups`). Nul pour un anonyme ou un non-inscrit. Résolu **par page** par `ParticipationLookup.forListPage`, que seul le chemin de liste (`PublicationService.list`) appelle : une projection (`RideGroupRepository.findGroupRows`, groupe, chiffres du parcours et meneur par jointures externes, **aucune entité hydratée** — charger `RideGroup` amènerait sa route EAGER, une par ligne), les aperçus d'inscrits en deux requêtes (`ParticipantPreviewLookup`), les vignettes en une (`ThumbnailLookup`) ; rien du tout quand l'appelant n'a rejoint aucune sortie de la page. Le détail et le calendrier gardent `forPublications`, sans ce coût. À ne pas défaire : pas de `getGroups()` ni de chargement d'entité par ligne, et le meneur est celui du groupe, nul s'il n'y en a pas — jamais `createdBy`. Mobile : `nextRideProvider` ne fait plus qu'**un** appel (`listMyParticipations`, `size: 1`, `COMPACT`) et rend la carte depuis la ligne (`rideFromListRow`) ; le bouton « Quitter » de la carte passe par `nextRideLeaveProvider`, pas par `rideRegistrationProvider`, qui écoute `rideDetailProvider` dès sa création et réintroduirait le `getRide`. L'extension `RideTiming.registeredGroup` est renommée `joinedGroup` (le champ généré l'aurait masquée) : `groups` d'abord, que la bascule optimiste tient à jour, `registeredGroup` ensuite ; `_withRegistration` tient aussi `registeredGroup`. Le web ne rendait pas de prochaine sortie : rien à changer. Tests : `RideMeFieldsTest.registeredGroup_onListRowsAndDetail_isTheJoinedGroupInFull` et `registeredGroup_onAListRow_withoutLeaderNorRoute_carriesNeither`, `ParticipationQueryCountTest.listMyParticipations_registeredGroups_costAPageNotARow` (**écrits, non lancés**) ; `participation_changes_test.dart` (« sans getRide », quitter depuis la carte sans détail) | 11 |
| `API-5` | **Capacité de la sortie sur les lignes de liste** (2026-09-30) — **API 5.11.0** : `RideDto.maxParticipants`, nullable, la **somme des `maxParticipants` des groupes**, **nulle dès qu'un groupe est sans limite** (ou sans groupe) : la sortie n'a alors pas de plafond. C'est exactement l'ensemble des sorties pour lesquelles `full` peut être vrai — ne pas sommer les seuls groupes plafonnés, un « 12/20 » sur une sortie qui a un groupe illimité serait faux. `full` reste la vérité sur « complet » (il compare groupe par groupe). Même règle sur le détail (repli sur `ride.getGroups()`) et sur la liste, où elle est calculée dans `RideSummaryRepository.loadListSummaries` à partir des lignes par groupe déjà lues pour `full` : aucune requête de plus. Le mobile rend « N/M » dans le carrousel de l'accueil (`upcomingParticipants`), le nombre seul quand la capacité est nulle ; la carte de fil garde son compteur brut, sans barre. Le web (`PublicationCardProgress`) sommait `ride.groups`, **vide sur une ligne de liste** : sa barre « N/M places » ne s'affichait jamais ; elle lit désormais `maxParticipants` et `full`. Couvert par `RideMeFieldsTest.maxParticipants_sumsTheGroupCapacities_nullWhenOneGroupIsUncapped_listAndDetailAgree` (liste et détail), les `…QueryCountTest` verts, `upcoming_action_test.dart` et `PublicationCardProgress.test.tsx` | 11 |
| `API-6` | **Auteur d'une publication, ou signature de l'équipe** (2026-09-30) — **API 7.2.0** : `PostDto.createdBy` (`PublicUserDto` : id, nom, avatar — le même objet que `RouteDetailDto.createdBy`, préféré aux deux scalaires d'abord notés ici parce que la maquette montre l'avatar) et `PostDto.signedAsTeam`. Décision produit : une publication est signée **par son auteur ou par l'équipe** (`Post.signedAsTeam`, `PostRequest.signedAsTeam` optionnel : omis à la création, il prend `Team.postsAsTeamByDefault` ; omis à la modification, il reste tel quel), et le réglage d'équipe `postsAsTeamByDefault` (`TeamRequest` optionnel, `TeamDetailDto`) est **activé par défaut**. Signée par l'équipe, la publication **ne nomme son auteur qu'aux administrateurs de l'équipe (`ADMIN`, pas `ORGANIZER`), à un administrateur de la plateforme et à l'auteur lui-même** ; tout autre lecteur, anonyme compris, reçoit `createdBy` absent. Signée par l'auteur, elle le nomme à quiconque peut la lire. Migration V52 : `team_entities.signed_as_team` et `teams.posts_as_team_by_default`, `not null default true` — **les publications existantes passent au nom de l'équipe** (aucun nom n'apparaît rétroactivement sur des textes écrits quand l'auteur n'était jamais montré), et la version précédente insère sans connaître les colonnes. Ne pas passer le défaut de la colonne à `false` : ce sont les lignes écrites pendant un déploiement progressif qui se mettraient à nommer leur auteur. Résolu **par page** par `PostAuthorLookup` (au plus deux requêtes : les équipes administrées parmi celles qui signent un post de la page, puis les auteurs) ; ne pas le remplacer par `post.getCreatedBy()` dans `PostDto.from`, qui chargerait un utilisateur par ligne au-delà du lot Hibernate. Le mobile (écran 31, `post_detail_page.dart`) rend l'auteur par `PdlPersonRow` (avatar, nom, date ; « Au nom de l'équipe » en sous-titre pour un administrateur), la date seule sinon. Le web : case « Publier au nom de *l'équipe* » dans `PostEditor` (partant du réglage d'équipe), réglage dans `TeamForm`, ligne « Par *nom* » sur `PostDetailPage`. Les cartes de liste restent sans auteur. La case d'équipe (« Publications au nom de l'équipe par défaut ») a un rôle et un nom accessible distincts du champ « Nom de l'équipe » : ce sont les sélecteurs e2e `getByLabel` (sous-chaîne) qu'il a fallu corriger en `getByRole('textbox')`, pas le composant. Couvert par `PostResourceTest` (`aPostSignedByItsAuthor_namesThemToEveryReader`, `aPostSignedByTheTeam_namesItsAuthorOnlyToTheAdminsAndToThemself`, `theTeamDefaultDecidesWhenThePostSaysNothing_andAnUpdateSayingNothingKeepsIt`), `TeamServiceTest.postsAsTeamByDefault_startsOn_andOnlyAnExplicitValueChangesIt`, `PublicationQueryCountTest.listTeamPosts_authorsCostAPageNotARow` (et anonyme : trente auteurs distincts, un sur deux signé par l'équipe) et `post_detail_page_test.dart` | 31 |
| `API-7` | **Poids des pièces jointes** (2026-09-30) — **API 6.3.0** : `AssetDto.size`, nullable, en octets, **le poids du fichier tel que stocké** — donc de ce qu'un téléchargement renvoie, une image comptée après son ré-encodage (`API-43`), pas telle qu'envoyée. Colonne `assets.file_size` (V49, nullable ; l'attribut s'appelle `fileSize` parce que `size` est une fonction HQL). `StorageService.store` rend désormais le nombre d'octets écrits, et chaque chemin d'écriture le relève : envoi (`addAssetStream`), fichier temporaire (`uploadAssetFile` : vignettes, import biketeam), GPX/FIT d'un parcours (`uploadTempFileToS3` → `persistAsset`), ré-encodage par `AssetMetadataBackfill`, réécriture par `GpxSanitizationBackfill`. L'existant est rempli par `AssetSizeBackfill` (un HEAD par asset, rien de téléchargé, 200 par minute) ; son curseur **ne revient jamais en arrière** — un fichier manquant n'est regardé qu'une fois par démarrage — et les lignes qu'une release précédente écrit pendant un déploiement roulant, d'id plus grand, sont prises au passage suivant. Sa mise à jour ne s'applique **que si la taille est encore nulle** (`recordSizeIfUnknown`) : ne pas la rendre inconditionnelle, un ré-encodage concurrent verrait sa taille écrasée par une lecture antérieure. Nul = inconnu : **les clients omettent le poids, ne l'estiment jamais**. Le mobile (`media_attachments.dart`, les huit écrans à pièces jointes) rend « PDF · 240 ko », « JPG · 1,2 Mo · 1920 × 1080 » ; le web (`MediaDisplay`) le poids à droite du nom. Unités décimales, « ko » en français (`AppFormatters.formatFileSize`, `formatFileSize` web). Couvert par `AssetSizeBackfillTest`, les assertions de taille d'`AssetServiceTest` (envoi, image ré-encodée ≠ taille envoyée, fichier temporaire), `AssetMetadataBackfillTest.aTiffBecomesAJpegAndItsAssetFollows`, `GpxSanitizationBackfillTest.sanitizeAll_rewritesARouteStoredWithTimestampsAndSensors` (import puis réécriture), `formatters_test.dart` et `unitFormat.test.ts` | 31, 32 |
| `API-9` | **Plage de dates d'un voyage dans « Utilisée dans »** (2026-09-30) — **API 5.9.0** : `RouteUsageDto.endDate`, nullable, la date de la dernière étape non supprimée — la règle de `TripDto.endDate` (le maximum des dates, pas la dernière par rang). Nul pour une sortie et pour un voyage sans étape, qui dure un jour. Aucune requête de plus : `fromTrip` parcourait déjà les étapes pour `viaChildNames`. Le mobile (`route_usages_section.dart`) rend « 1 août → 4 août » comme la carte de voyage, le web (`RouteUsages.tsx`) les deux dates au lieu de la date et l'heure de début ; une sortie garde sa date et son heure. Couvert par `RouteResourceTest.getRouteUsages_trip_carriesItsEndDate_rideDoesNot` (une étape supprimée plus tardive ignorée, voyage sans étape et sortie à nul) et `route_usages_section_test.dart` | 13 |
| `API-10` | **Nom des montées** (2026-10-01) — **API 9.3.0** : `ClimbDto.name`, nullable, le nom du **waypoint du parcours le plus proche du sommet de la montée, à 300 m au plus** (`ClimbNaming`, point du tracé le plus proche de `endDist`, distance haversine). C'est le nom que l'auteur du GPX a posé au col ; sans waypoint au sommet, pas de nom, et les clients gardent « Montée N ». **Tranché : pas de géocodage inverse** — un appel réseau par montée à chaque lecture (ou une colonne et son rattrapage), et le lieu le plus proche d'un sommet est souvent un hameau en contrebas ; un nom faux est pire que pas de nom. Calcul pur à la lecture, sur ce que le détail charge déjà (points du tracé, waypoints de la route) : aucune requête, aucune migration ; même règle sur l'aperçu GPX (`GpxPreviewDto`). Web : `RouteDetailView` rend le nom, l'infobulle du profil (`ElevationChart`) dit « *Nom* (i/n) : … » (`map.tooltip.climbNamed`). Mobile : `RouteClimbsSection`. Tests : `ClimbNamingTest` (sommet, plus proche gagnant, seuil, pied de montée, nom vide, `TrackDto.of`), `RouteResourceTest.getRoute_climbs_areNamedAfterTheWaypointAtTheirTop` (**écrit, non lancé** — fixe aussi l'ordre latitude/longitude du point PostGIS) ; `route_climbs_section_test.dart` | 13, 25 |
| `API-11` | **Commentaires d'étape** (2026-10-02) — **API 10.2.0** : `GET/POST /api/teams/{teamSlug}/stages/{stageSlug}/comments` et `DELETE …/{commentId}` (tag `Trip Stage Comments`), et `TripStageDto.commentCount`, nullable, absent pour qui ne peut pas lire les commentaires comme `TripDto.commentCount`. **Le chemin ne nomme pas le voyage** : le slug d'étape est unique dans l'équipe (`uk_team_entity_slug`, la règle qu'utilisait déjà `TripStageAccessChecker`) ; l'étape est lue comme son voyage (`TripService.findStageBySlug` : une étape d'un voyage brouillon, supprimé ou invisible, ou une étape supprimée, répond 404). Le fil est **propre à l'étape**, distinct de celui du voyage. Le compte de chaque étape vient du même `CommentCountLookup.forEntities` que celui du voyage, deux requêtes pour tout le détail. **Une étape n'est pas une publication**, et `CommentThreads.publicationOf` la ramène à son voyage partout où le reste de l'application en attend une : la notification `COMMENT_ON_MY_PUBLICATION` va à l'**auteur du voyage** et ouvre le voyage (`subjectType` `TRIP` — pas de `NotificationSubjectType` d'étape, qui demanderait un second slug dans l'événement stocké), un signalement de commentaire est lu selon la visibilité du voyage, et la file de modération ouvre le voyage ; les voyages de ces étapes y sont chargés par une requête de plus, seulement s'il y en a. Web : `CommentSection` sur `StageDetailPage` (membres seulement) et préchargement SSR dans `prefetchStageDetail`. Mobile : `CommentEntity.stage`, le fil sur l'écran 25 à la place du renvoi « Commenter ce voyage ». À ne pas défaire : un fil par étape, la notification et la modération rapportées au voyage. Tests : `TripStageCommentResourceTest` (le contrat commun d'`AbstractCommentResourceTest`, brouillon et étape supprimée en 404, fil distinct de celui du voyage, `commentCount` par étape), `NotificationPhase5Test.topLevelCommentOnAStage_notifiesTheTripAuthor_andOpensTheTrip`, `ModerationResourceTest.reportedCommentOnAStage_opensItsTrip` (**écrits, non lancés**) ; `trip_screens_test.dart` (« le fil est celui de l'étape, pas celui du voyage ») ; e2e (**écrits, non lancés**) : `flow-trips.e2e.ts` « a member comments on a stage… » (fil propre à l'étape, comptes, notification de l'auteur du voyage), `outsider.e2e.ts` (l'étape publique ajoutée aux entités commentées : rien dans le document serveur ni par l'API pour un visiteur ou un non-membre, et le contrôle positif du membre vérifie le préchargement SSR du fil), Patrol `stage_comments_test` | 25 |
| `API-12` | **Participants paginés et cherchables côté serveur** (2026-09-30) — **API 9.0.0**, majeure : deux endpoints dédiés, forme tranchée avec le propriétaire, `GET /api/teams/{teamSlug}/rides/{rideSlug}/participants?groupId=&search=&page=&size=` (la sortie entière, ou un groupe ; un groupe d'une autre sortie répond 404) et `GET …/trips/{tripSlug}/participants?search=&page=&size=`, qui renvoient `ParticipantListResponse` `{ participants, total, page, size }` (taille par défaut 50, bornée comme toute page par `BaseRepository.effectivePageSize`). Ordre d'inscription (`registeredAt`, puis id), recherche insensible à la casse sur le nom affiché, `%` et `_` littéraux (`LikePatterns`). Lus comme la sortie ou le voyage (`@CheckAccess` `READ`, 404 pour qui ne la voit pas), `Cache-Control: private, no-store`. **La rupture** : `RideGroupDto.participants` et `TripDto.participants` ne sont plus la liste complète mais un **aperçu des 8 premiers inscrits**, de quoi dessiner des avatars ; `countParticipants` et `participantCount` restent les totaux. Le détail ne parcourt plus `group.getParticipations()` ni `trip.getParticipations()` : `ParticipantPreviewLookup` donne le compte et les premiers de **tous les groupes d'une sortie en deux requêtes** (fonctions de fenêtre, puis les utilisateurs par id), d'où aussi `full`, `participantCount` et `topParticipants`. Les listes sélectionnent les utilisateurs eux-mêmes (`ParticipantPages`), une entité par ligne. Web : `ParticipantListModal` lit l'endpoint page par page, avec recherche et pied « 1–50 sur M » ; « +N » des avatars compté sur le total (`UserAvatarGroup.total`) ; `TripDetailPage` lit `registered` au lieu de chercher l'utilisateur dans la liste. Mobile : `ParticipantsSheet` lit `participantListProvider` (`PagedListNotifier`, 50 par page), recherche serveur, « N participants sur M » et un bouton « Afficher plus » plutôt qu'un préchargement au défilement (la feuille construit toutes ses lignes d'un coup) ; `PdlAvatarStack.total` pour le « +N ». **Les deux ruptures partent dans la même republication mobile que `SEC-2`, `SEC-3` et `MOB-38`.** À ne pas défaire : ne pas recompter ni prévisualiser en parcourant les collections de participations (c'est ce que mesurent les tests de coût), ne pas réembarquer la liste complète. Tests (**écrits, non lancés**) : `ParticipantListResourceTest` (aperçu borné et comptes réels, pagination dans l'ordre d'inscription, filtre par groupe, recherche, `%` littéral, 404 d'un groupe étranger, visibilité), `ParticipantListQueryCountTest` (les deux listes à plat, et le détail de la sortie et du voyage à 3 puis 30 participants avec le budget resserré `MAX_BOUNDED_ENTITY_GROWTH`) ; `participants_sheet_test.dart` (meneur, recherche débattue envoyée au serveur, « Afficher plus ») ; e2e `rides.e2e.ts` « the participant list is read and searched on the server » | 24, 34 |
| `API-13` | **Tri de l'annuaire des équipes** (2026-09-30) — **API 5.12.0** : `GET /api/teams?sortBy=NAME\|MEMBER_COUNT&sortDir=ASC\|DESC`, sur le modèle des parcours et des annonces (`TeamSortBy`, `SortDirection`, DESC par défaut quand `sortBy` est donné). Sans `sortBy`, l'ordre historique (nom croissant). **La clé se termine toujours par l'id de l'équipe**, dans le même sens (`TeamRepository.orderClause`), y compris dans l'ordre par défaut qui ne l'avait pas : sans elle, deux équipes à égalité peuvent changer de place d'une page à l'autre, et la pagination par décalage en répète une et en saute une autre. `MEMBER_COUNT` trie sur la **même sous-requête corrélée** que le `memberCount` que portent les lignes — l'ordre correspond aux nombres affichés — dans l'unique requête de liste, sans compte par équipe. Le mobile (écran 34, découverte) demande `MEMBER_COUNT DESC` et rétablit la mention de la maquette, « 3 équipes · triées par nombre de membres » ; la requête et la mention lisent la même constante `kTeamDiscoverySort`. Le web n'annonçait aucun tri : rien à changer. Couvert par `TeamResourceTest.listTeams_sortByMemberCount_isTotalAcrossPages` (trois ex æquo départagés par l'id, page par page, puis ASC), `listTeams_withoutSort_keepsTheNameOrder`, `TeamMemberQueryCountTest.listTeams_sortedByMemberCount_costDoesNotScaleWithRowCount`, `team_repository_sort_test.dart` et `teams_discover_page_test.dart` | 34 |
| `API-14` | **Logo des services GPS** (2026-10-02) — sans changement de contrat. **Tranché avec le propriétaire : côté clients, pas de `logoUrl` au contrat** — `GpsServiceType` est un enum fermé, une URL n'apporterait rien. Les trois logos (Garmin, Wahoo, Hammerhead) sont des **tuiles carrées à fond sombre**, lisibles dans les deux thèmes ; celui de Hammerhead, fourni en tracé blanc sur fond transparent (invisible sur fond clair), a été posé sur une tuile `#212121`, le fond du logo Wahoo. Web : `frontend/src/assets/gps/*.svg`, `GPS_SERVICE_LOGOS` dans `GpsConnectionsManager` à la place de l'icône générique. Mobile : PNG 32 px en 1x/2x/3x (`mobile/assets/gps/`, rasterisés des mêmes SVG — pas de `flutter_svg` pour trois images), `gpsServiceLogoAsset`, et un emplacement `leading` (un widget) sur `PdlSettingRow`. Le logo est décoratif (`alt=""`, `ExcludeSemantics`) : le nom du service est à côté. `SocialIdentityDto.externalUsername`, l'autre moitié de l'entrée d'origine, était devenu sans objet avec le retrait de Strava (API `5.0.0`). Un nouveau service ajouté à l'enum n'aura pas de logo tant qu'on ne l'aura pas ajouté aux deux tables. Test : `gps_service_logo_test.dart` (chaque service connu a un logo réellement embarqué) | 33 |
| `API-15` | **Fuseau des dates : celui de l'utilisateur, sinon l'appareil, sur le mobile aussi** (2026-10-02) — sans changement de contrat. **Tranché avec le propriétaire : pas de `Team.timezone` ni de dates zonées au contrat** (`API-60`). **Décision revue le 6 octobre 2026** : `API-60` est rouvert pour les heures de rendez-vous (départs de sortie, de groupe, d'étape), lues dans le fuseau de l'événement ; la préférence et `toDisplayTime` restent la règle pour tout le reste, et la règle « pas de `.toLocal()` » tient toujours. Le mobile applique désormais `UserDto.timezone` comme le web (`useEffectiveTimezone`) : `app.dart` le passe à `AppFormatters.setDisplayTimezone`, et tout instant du contrat est ramené par `AppFormatters.toDisplayTime` / `tryParseDisplayTime` — les 23 `.toLocal()` des écrans y passent. La valeur rendue est une **heure murale** (un `DateTime` local portant les champs du fuseau choisi) : les regroupements par jour et `DateFormat` restent justes sans connaître `package:timezone`, mais elle ne se compare pas à un instant — « passé » vient du serveur (`API-16`). « Maintenant » se prend par `displayNow()` (le calendrier), et les bornes de mois envoyées à l'API repassent par `displayWallClockToUtc`. `package:timezone` redevient une dépendance directe, sans coût de taille : `flutter_local_notifications` l'embarquait déjà ; la base n'est chargée qu'au premier fuseau posé. Un nom inconnu de la base embarquée retombe sur l'appareil. À ne pas défaire : pas de `.toLocal()` ni de `DateTime.now()` comparé à une date convertie (règle dans `mobile/CLAUDE.md`). Tests : `display_timezone_test.dart` (l'étape du lundi à Auckland reste un lundi, dimanche à Los Angeles ; pas de double conversion ; bornes de mois ; repli sur l'appareil), Patrol `user_timezone_test` (**écrit, non lancé** : une étape à 08:00 d'Auckland lue « 08:00 » par un membre réglé sur `Pacific/Auckland`) | 22, 24, 25 |
| `API-16` | **« Terminée » dite par le serveur** (2026-09-30) — **API 7.3.0** : un booléen `finished`, obligatoire, calculé au moment où la réponse est construite, sur `RideDto` (départ passé), `TripDto` (dernière étape commencée : `endDate`, sinon `dateTime`) et `CalendarEventDto` (fin passée, sinon début). **Tranché avec le propriétaire : pas de valeur `TERMINÉE` dans `Status`**, ni stockée ni calculée. `Status` est le cycle de publication, partagé par tous les contenus, lu et écrit par les formulaires et les filtres `status=` ; « terminée » est une autre dimension — une sortie annulée et passée est les deux. Une valeur stockée aurait demandé une tâche planifiée idempotente et une migration, et aurait été en retard sur l'horloge ; une valeur calculée dans l'enum aurait changé le sens du filtre `status=PUBLISHED` et demandé un enum de réponse distinct. Aucune requête de plus : le calcul ne lit que des champs du DTO, `PublicationDto` (le fil) en hérite par `RideDto` et `TripDto`. `CalendarEventDto` est un record : `finished` y est un accesseur dérivé (`@JsonProperty`), pas un composant, pour ne pas changer ses constructeurs. Les clients lisent le champ au lieu de l'horloge : web `RideDetailPage` et `CalendarView` (même réponse au rendu serveur et à l'hydratation), mobile `RideTiming.isPast`, `TripTiming.isPast`, `AgendaCard` et la carte du fil. À ne pas défaire : ne pas réintroduire de dérivation locale, et ne pas « compléter » `Status`. Tests : `RideResourceTest.getRide_finished_followsTheStartTime` (**écrit, non lancé**), `CalendarView.test.tsx`, `mobile/check.sh` (685 tests, fixtures calculant `finished` selon la règle du serveur) | 11, 12, 22 |
| `API-20` | **Pagination du calendrier** (relevé le 9 octobre 2026, livré le 27 juillet 2026) — sans changement de contrat depuis : `GET /api/calendar` et le calendrier d'équipe prennent `from` et `to` (`CalendarResource`, `TeamCalendarResource`, `QueryInstants.parse`), et `CalendarService.resolveFrom`/`resolveTo` ne retombent sur la fenêtre −30 j / +180 j que si le paramètre manque. Le mobile charge un mois par appel (`calendar_month_provider.dart`, `8a04d8f1`), le web passe la plage visible (`useCalendarDateRange`). L'entrée était restée ouverte faute d'avoir été relue. À ne pas défaire : la fenêtre par défaut reste celle du flux ICS (`generateIcs`, `generateIcsForTeam`), qu'un abonnement ne peut pas paginer. Aucune borne maximale sur l'écart `from`–`to` ; le filtre sur le départ plutôt que la fin reste ouvert sous `API-88` | 22 |
| `API-81` | **Vitesse facultative par étape de voyage** (2026-10-06) — **API 10.10.0** : `StageRequest.averageSpeed` et `TripStageDto.averageSpeed`, nullables, en km/h, `@Positive` — la forme et l'unité de `RideGroupDto.averageSpeed`. Colonne `team_entities.average_speed` (V62, `float4` nullable : la version précédente insère sans la connaître pendant un déploiement progressif). Comme tout champ d'étape, un PUT l'applique tel quel : nul l'efface. Exportée avec l'étape (`content/trip-stages.json`). Web : champ « Vitesse moyenne » dans l'onglet de chaque étape de `TripEditor` (unités de l'utilisateur, `useUnits`), rendue à côté de la date sur `StageDetailPage` ; `tripToRequest` la reporte — **à ne pas retirer**, le menu publier/dépublier/annuler de la fiche l'effacerait. Mobile : statistique de `StageCard` et ligne de départ de l'écran 25 ; le mobile n'édite pas les voyages. C'est la vitesse que la météo des voyages (`API-76`) prendra pour une étape, 25 km/h à défaut. Test : `TripServiceTest.shouldCreateWithStages` (vitesse posée sur une étape, nulle sur l'autre) | 25 |

- `API-41` **Le meneur de groupe** est livré en 1.5.0 (`RideGroupDto.leader`, nullable). Les
  **gabarits de sortie n'ont volontairement pas de meneur** — décision produit :
  `RideTemplateGroupRequest` reste sans champ, instancier une sortie depuis un gabarit ne désigne
  personne. Le repli sur `createdBy` est interdit (`API-30`).
- `API-42` **« Compléter le compte » retiré** (2026-09-29) — **API 6.0.0** : `UserDto.requiresEmail`
  (qui valait `!user.isEmailVerified()`) a disparu du contrat, avec la page web
  « Compléter le compte » (`/completer-le-compte`, `CompleteAccountPage`) et le bandeau qui y
  menait. C'était du code mort : plus aucun compte non vérifié ne peut ouvrir de session —
  l'inscription et le bootstrap vérifient l'e-mail, l'OTP et la réinitialisation du mot de passe
  refusent un compte non vérifié (`AuthService`), les comptes migrés non vérifiés n'ont pas de mot
  de passe, et les comptes factices `strava_<id>@…` ne peuvent plus se connecter depuis le retrait
  de Strava (`7cd2bf3a`), l'import par dump qui les créait ayant lui-même été retiré (`d93fd3af`).
  **Décision à ne pas défaire** : `POST /api/auth/email/change-request`,
  `AuthService.requestEmailChange` et la vérification du changement d'e-mail **restent** — le profil
  mobile s'en sert (`profile_identity_section.dart`) ; seul le parcours « compléter » est parti. Aucune
  migration Flyway ne supprime les comptes `strava_<id>@…`, mais staging et prod n'en ont plus
  (vérifié le 2026-09-29 : aucun compte factice ni non vérifié, bases reparties de zéro depuis
  l'import) ; seule une vieille base locale ou une restauration antérieure en porterait encore.

### Défauts relevés

- `API-28` **NPE 500 sur un `media` incomplet** (2026-09-30) — `POST /api/teams/{slug}/rides` avec
  `media.assets = {}` levait une `NullPointerException` dans `AssetService.updateAssets` : Jackson
  construit un record par son constructeur canonique, jamais par le builder qui posait les listes
  vides, et `@Schema(required = true)` ne valide rien sur `AssetsDto` ni `MediaDto` (pas de
  `@ValidateSchema`). Les deux records ont maintenant un constructeur compact qui **normalise à
  vide** : `images` et `attachments` nuls deviennent des listes vides, `assets` nul un inventaire
  vide, `markdown` nul la chaîne vide (la valeur par défaut du builder et de l'entité, dont la colonne
  est `NOT NULL`). Normaliser plutôt que répondre 400 : les clients envoient toujours les listes, et le
  contrat ne change pas. Couvert par `RideResourceTest.createRide_withEmptyAssetsObject_shouldSucceed`
  et `createRide_withEmptyMediaObject_shouldSucceed`. Un `media` nul, lui, reste un 400 là où la
  requête porte `@ValidateSchema` (`RideRequest`…).

- `API-71` **Changement d'adresse e-mail en 500** (2026-10-04) — `POST
  /api/auth/email/change-request` échouait pour tout le monde, web comme mobile
  (`profile_identity_section.dart`) : `AuthTokenType.EMAIL_CHANGE` avait été ajouté sans migration,
  et la contrainte `auth_tokens_token_type_check` (V4) n'admettait que `EMAIL_VERIFICATION`, `OTP` et
  `PASSWORD_RESET`. Le jeton était refusé à l'insertion, la transaction annulée avant tout envoi de
  mail. Constaté en prod sur une vraie demande, pas par les tests : ceux-ci créent le schéma depuis
  les entités (`drop-and-create`, Flyway coupé en `%test`), donc avec une contrainte générée à
  partir de l'enum. `V60__auth_token_type_email_change.sql` élargit la contrainte, rien d'autre (la
  release précédente reste compatible pendant le déploiement). Pas de changement de contrat. Aucun
  test ne la couvre ; le garde-fou est `API-72`. **À ne pas défaire** : une valeur ajoutée à un enum
  persisté en `varchar` sous contrainte CHECK (`AuthTokenType`, `AssetType`, `GpsServiceType`…)
  part avec sa migration Flyway, dans le même commit.

- `API-73` **Un changement d'adresse coupait les sessions ouvertes pendant 15 min** (2026-10-04) —
  `PedalonsQueryContext.doInit` retrouvait l'utilisateur par la valeur `email` du JWT : après
  `confirmEmailChange`, chaque jeton d'accès encore valide (web, mobile, autres appareils) ne
  résolvait plus personne et prenait un 403, qu'aucun client ne rafraîchit (ils ne le font que sur
  401). Il le résout maintenant par le claim `userId` (`findActiveByIdAndDomain`), le contrôle du
  `domainId` du jeton restant en tête ; `UserService.lookupUserByEmailAndDomain`, qui ne servait
  qu'à ça, a disparu. Tous les jetons émis portent déjà `userId` (`JwtService`, `DeviceJwtService`) :
  rien à migrer, et un déploiement roulant n'en coupe aucun. Pas de changement de contrat. Couvert par
  `AuthResourceTest.confirmEmailChange_keepsTheAccessTokensIssuedBeforeIt`, le cloisonnement par
  `AccessTokenDomainTest`. Le contournement web (`WEB-59`) reste : il renouvelle aussi l'utilisateur
  affiché. **À ne pas défaire** : le claim `email` d'un jeton n'identifie personne — il périme au
  premier changement d'adresse.

- `API-68` **Un asset déjà attaché ailleurs était ignoré sans erreur** (2026-10-06, contrat
  `10.12.0`) — relevé à la recette mobile (`MOB-18`) : un `MediaDto` citant une pièce jointe d'un
  autre contenu ou d'une autre équipe répondait 200/201 sans la porter, et un client d'API (seed,
  migration, futur « dupliquer ») croyait le fichier joint. `AssetService.addAssetToEntity` refuse
  maintenant par un **400 `ASSET_NOT_AVAILABLE`** dont `errorDetails` (`AssetNotAvailableDetails`,
  nouvelle variante de l'union `ErrorDetails`) ne porte que `type` et `assetId`, l'id tel que la
  requête l'a cité. Même réponse pour un id inconnu (avant : 404 `NOT_FOUND` de l'asset) ou
  illisible : l'API n'est pas un oracle de ce que tiennent les autres contenus. La transaction de
  la requête est annulée, le contenu garde ses pièces jointes d'avant. Contrat (10.11.0 → 10.12.0,
  mineur) : la valeur d'enum, la variante d'erreur, la description d'`AssetsDto` ; messages
  `errors.api.ASSET_NOT_AVAILABLE` au web. Aucun client actuel ne réutilise un asset (web et app
  téléversent pour chaque contenu), donc rien à changer côté écrans. Couvert par
  `AssetResourceTest.attachAsset_*` (autre contenu, autre équipe, inconnu : même corps ; recité
  par son propre contenu : 200) et `AssetServiceTest.UpdateAssets.shouldRefuse*`. **À ne pas
  défaire** : un asset n'a qu'un propriétaire, et le refus ne nomme ni le contenu ni l'équipe qui le
  tient — une seule forme de réponse pour les trois cas. Les images non citées par le markdown sont
  toujours écartées *avant* ce contrôle, sans erreur (comportement voulu, pas un défaut).

- `API-80` **Miniatures des lignes de sortie hors `ThumbnailLookup`** (2026-10-06, pas de
  changement de contrat) — relevé pendant `API-79` : `RideDto` construisait chaque ligne de liste
  en parcourant `ride.getAssets()`, puis `ride.getRoute().getAssets()` en repli, une collection
  chargée par ligne que seul `fetch.batch-size=32` regroupait. `PublicationService.list` résout
  maintenant les miniatures de toutes les sorties de la page en une requête,
  `ThumbnailLookup.forRides` (ids des sorties et de leurs parcours, la sortie d'abord, son parcours
  en repli — la règle d'avant, celle du calendrier) ; `RideDto.fromListItem` lit cette carte, comme
  les autres lookups de page. Le détail d'une sortie garde le parcours des assets
  (`ownOrRouteThumbnail`, une seule sortie, inventaire déjà lu par `MediaDto`). Couvert par
  `PublicationQueryCountTest.listTeamRides_routeThumbnails_costAPageNotARow` (30 sorties sur 30
  parcours à miniatures, une sur trois avec la sienne : chaque ligne porte la bonne image, et le
  nombre de requêtes ne croît pas avec la page). Le test ne budgète que les requêtes, pas les
  entités : `MediaDto` lit toujours l'inventaire de chaque sortie, et le rôle de collection
  `TeamEntity.assets` étant partagé avec les parcours, le batch fetch peut encore hydrater leurs
  assets au passage. Les voyages ont le même parcours par ligne : `API-83`. **À ne pas défaire** :
  une ligne de liste ne lit pas `getAssets()` pour sa miniature, et la miniature propre de la sortie
  passe avant celle de son parcours, variantes claire et sombre comprises.

- `API-83` **Miniatures des lignes de voyage hors `ThumbnailLookup`** (2026-10-06, pas de
  changement de contrat) — reste de `API-80` : `TripDto.build` parcourait `trip.getAssets()`, puis
  `trip.getRoute().getAssets()` en repli, pour chaque ligne de liste. `PublicationService.list`
  résout maintenant les miniatures de tous les voyages de la page en une requête,
  `ThumbnailLookup.forTrips` (filtrée par domaine ; le voyage d'abord, son parcours en repli — la
  règle d'avant), que `TripDto.fromListItem` lit comme les autres lookups de page. `forRides` et
  `forTrips` partagent la même méthode (`ownElseRoute`, le `route` de la publication étant un
  to-one eager déjà chargé). Le détail d'un voyage garde le parcours des assets
  (`TripDto.ownOrRouteThumbnail`). Couvert par
  `PublicationQueryCountTest.listTeamTrips_routeThumbnails_costAPageNotARow` (30 voyages sur 30
  parcours à miniatures, un sur trois avec la sienne : chaque ligne porte la bonne image, et le
  nombre de requêtes ne croît pas avec la page). Même réserve que pour les sorties : le test ne
  budgète que les requêtes, `MediaDto` lit toujours l'inventaire d'assets de chaque ligne, et le
  rôle de collection `TeamEntity.assets`, partagé par sorties, voyages et parcours, laisse le batch
  fetch hydrater les assets des parcours au passage. **À ne pas défaire** : une ligne de liste ne
  lit pas `getAssets()` pour sa miniature, et la miniature propre du voyage passe avant celle de son
  parcours, variantes claire et sombre comprises.

- `API-78` **`DeviceRouteService.computeRideStartInstant` ne convertissait rien** (2026-10-06, pas
  de changement de contrat) — la méthode cherchait le fuseau du départ du parcours (un appel à
  `TimezoneService`) pour faire `ride.getDateTime().atZone(zone).toInstant()`, qui rend l'instant
  reçu. Le défaut n'était qu'apparent : `Ride.dateTime` est un `Instant` absolu, et les deux apps le
  lisent comme tel — Karoo (`MainActivity.formatDateTime`) fait `Instant.parse` puis l'affiche dans
  le fuseau de l'appareil, Garmin (`FormatUtils.parseIsoDateTime`) construit un `Gregorian.moment`
  en UTC que `Gregorian.info` rend à l'heure locale ; le tri des sorties par proximité de « maintenant »
  compare aussi des instants. La méthode et l'injection de `TimezoneService` sont supprimées,
  `startDateTime` reçoit `ride.getDateTime()` tel quel. Couvert par
  `DeviceRoutesResourceTest.getRoutes_rideStart_isTheRideInstantUnshifted` (parcours à Nantes,
  sortie à 7 h 30 heure de Paris, un groupe à 9 h : l'instant rendu est celui de la sortie, ni
  décalé, ni remplacé par celui du groupe). L'heure propre de chaque groupe sur les appareils est
  `API-84`. **À ne pas défaire** : `startDateTime` est un instant absolu, jamais relu au fuseau du
  lieu de départ — c'est l'appareil qui le rend à son heure locale ; seule une heure **sans fuseau**
  (le `LocalTime` d'un `RideGroup`) se lit au fuseau du départ, par `RideWeatherCalculator.legStart`.

- `API-84` **Les appareils n'avaient que l'heure de la sortie, pas celle du groupe** (2026-10-06,
  contrat `10.14.0`) — `DeviceRideDto.startDateTime`, l'instant de la sortie, était la seule heure
  de toutes ses entrées : Garmin (`RouteDetailView`) l'affichait sous le parcours d'un groupe parti
  plus tard. Chaque `DeviceRideEntryDto` porte maintenant son `startDateTime`, un instant UTC
  requis : pour un groupe qui a une heure, `RideWeatherCalculator.legStart` (l'heure du groupe lue
  au fuseau du lieu de départ, sur la date locale de la sortie — la règle de `RideWeatherPlans`,
  fuseau cherché au plus une fois par sortie, UTC sans lieu de départ) ; l'instant de la sortie pour
  le parcours de la sortie elle-même et pour un groupe sans heure (`DeviceRouteService`). Karoo
  (`DeviceRide.startOf`) et Garmin (`ApiClient.parseRideDto`) lisent le champ et retombent sur
  l'heure de la sortie quand il manque (serveur antérieur à `10.14.0`) ; Karoo l'affiche sous le
  nom du groupe dans la liste des entrées et sous le titre du parcours, Garmin sur l'écran du
  parcours, par les deux chemins qui y mènent. La liste des sorties garde l'heure de la sortie.
  Couvert par `DeviceRoutesResourceTest.getRoutes_entryStart_isTheGroupTimeAtTheDepartureZone`
  (et `getRoutes_rideStart_isTheRideInstantUnshifted` pour l'heure de la sortie) ; aucun test côté
  appareils (Karoo `assembleDebug` et Garmin `make build-all` sur les 13 appareils compilent, pas
  d'essai sur appareil ni au simulateur). **À ne pas défaire** : `DeviceRideDto.startDateTime` reste
  l'instant de la sortie (`API-78`) ; l'heure par entrée vient de `legStart`, jamais d'une
  relecture de l'instant de la sortie au fuseau du départ ; les appareils rendent les deux à leur
  heure locale.

- `API-85` **Aucune heure de fin : « À venir » comparait le départ à maintenant** (2026-10-06,
  contrat `10.15.0`, plan [Agenda d'équipe](plans/archive/2026-10-06-team-agenda.md) §3.1–3.2) — une
  sortie partie depuis dix minutes ou un voyage commencé la veille sortaient de « À venir », le
  calendrier et l'ICS envoyaient `end = null`. Colonne `team_entities.end_date_time` (V63,
  nullable, index `(team_id, end_date_time)`), écrite par un seul service,
  `PublicationEndCalculator` : sortie = le plus tard des groupes (départ du groupe lu par
  `RideWeatherCalculator.legStart`, + distance de son parcours, à défaut celui de la sortie, à sa
  `averageSpeed`) ; voyage = la plus **tardive** de ses étapes vivantes (chaque étape stocke aussi
  la sienne) — décision : la plus tardive plutôt que la dernière triée, identiques sur un voyage
  bien rangé, et la seule qui ne rend jamais « passé » un voyage dont une étape est encore devant ;
  groupe ou étape sans vitesse ou sans parcours (supprimé compris), sortie sans groupe, voyage sans
  étape : départ + `DEFAULT_DURATION` = 3 h. Recalculée à la création et à la modification d'une
  sortie (`RideService`, gabarits compris : le client préremplit puis crée) et d'un voyage
  (`TripService.updateTrip` porte ajout, modification, suppression et réordonnancement d'étapes), à
  la publication programmée (`PublicationPublishScheduler`), au remplacement du GPX d'un parcours
  (`RouteService.updateRoute` → `refreshUsersOf` : sorties, groupes et étapes qui le citent) et à
  l'import biketeam (qui passe par les deux services). `PublicationEndBackfill` remplit au démarrage,
  par lots de 200 et par mise à jour conditionnelle (`where end_date_time is null`, sans toucher à
  la version), ce qu'un backend antérieur laisse nul ; les requêtes lisent la fin stockée, sinon
  `date_time + 3 h`. `GET /api/teams/{slug}/publications`, `GET /api/publications` et leurs
  `/count` acceptent `when=UPCOMING|PAST` (fin ≥ / < maintenant ; ne garde que sorties et voyages),
  tri fixé par le serveur — départ croissant / décroissant —, `sortDir` prioritaire s'il est donné,
  `participating=true` combinable. `RideDto.endDateTime` et `TripDto.endDateTime` (requis) ;
  `CalendarEventDto.end` porte la fin de la sortie ou de l'étape, `finished` s'en sert ; l'ICS écrit
  `DTEND` (une étape « journée entière » couvre chaque jour jusqu'à sa fin,
  `IcsGenerationService.allDayEnd`). Le tableau de bord (« Mes prochaines », « Prochaines sorties »
  et les tuiles organisateur) passe sur `notEndedAt(now)`. Couvert par
  `PublicationEndCalculatorTest` (la règle), `PublicationEndStoredTest` (valeur relue en base à
  chaque point d'entrée, et le remplissage), `PublicationPublishSchedulerTest.autoPublish_storesTheEndOfARideThatHadNone`,
  `BiketeamLiveMigrationTest.importedRidesAndTrips_haveTheirEndStored`, `PublicationWhenFilterTest`,
  `CalendarEventFieldsTest` (fin et `DTEND`), `IcsGenerationServiceTest.allDayEnd_coversEveryDayUpToTheEnd`,
  `TeamDashboardResourceTest.aRideUnderWay_staysInTheUpcomingSections`. **À ne pas défaire** :
  `PublicationEndCalculator` est le seul auteur de la colonne — tout nouveau chemin qui déplace un
  départ, un groupe, une étape ou la longueur d'un parcours l'appelle ; les lectures gardent le repli
  `date_time + DEFAULT_DURATION` (déploiement à chaud) ; le remplissage ne touche que les lignes
  nulles et jamais la version. `RideDto.finished` reste « départ passé » (`API-16`) : la fin sert
  aux listes, au calendrier et à l'ICS.

- `API-86` **Le tableau de bord d'équipe fermé aux visiteurs** (2026-10-06, contrat `10.16.0`,
  plan [Agenda d'équipe](plans/archive/2026-10-06-team-agenda.md) §3.3) — `TeamDashboardService` levait
  403 pour tout non-membre et la ressource exigeait une connexion, si bien qu'un visiteur n'avait
  que le fil. `TeamDashboardResource` est passée en `@PermitAll` (le 401 a quitté le contrat) et
  `getDashboard` porte `@CheckAccess(TEAM, READ)`, la règle de `GET /api/teams/{slug}` : une
  équipe `TEAM` répond 403 aux anonymes comme aux non-membres connectés, une équipe `PUBLIC` ou
  `PUBLIC_UNLISTED` répond à tous, une équipe d'un autre domaine ou supprimée 404. Pour un
  visiteur, `roleOf` renvoie `null` et `myUpcoming`, `latestAds`, `organizer` et `admin` ne sont
  **pas calculés** ; `upcomingRides`, `latestPosts` et `newRoutes` sortent des mêmes
  `listTeamSection`, donc des règles de `TeamEntityRepository` (seules les entités `PUBLIC`
  publiées ou annulées, sans annonces ni contenu masqué par la modération). `TeamDashboardDto.role`
  devient nullable ; le mobile masque le badge de rôle sans rôle. Version mineure malgré `role`
  devenu nullable : le web et le mobile (hors stores) sont republiés avec le backend. Relecture
  `security-reviewer` du 6 octobre 2026 sans problème : comportement 403/404 identique à la fiche
  d'équipe (pas d'énumération en plus), pas de rôle intermédiaire qui passerait pour membre, rien
  que les listes publiques (`PUBLICATION LIST`, `ROUTE LIST`) n'exposent déjà, réponse en
  `Cache-Control: private, no-store`, coût fixe par visiteur. Couvert par
  `TeamDashboardResourceTest` (`anonymous_shouldGetThePublicPart`, `nonMember_shouldGetThePublicPart`,
  `formerMember_shouldGetThePublicPartOnly`, `visitor_shouldNotSeeWhatIsNotPublic`,
  `membersOnlyTeam_shouldStayClosedToVisitors`, `privateTeam_member_shouldGetIt_outsiderNot`) et
  `TeamDashboardQueryCountTest` (`dashboard_asNonMember_costDoesNotScaleWithTheTeam`,
  `dashboard_anonymously_costDoesNotScaleWithTheTeam`).
  **À ne pas défaire** : l'accès suit `TEAM READ`, jamais une règle propre au tableau de bord ;
  les blocs réservés aux membres ne sont pas construits pour un visiteur (pas calculés puis vidés) ;
  les sections publiques passent par les mêmes requêtes que les listes d'équipe ; la réponse reste
  `private, no-store`, puisque son contenu dépend de l'appelant.

- `API-90` **iCal : les dates des étapes « journée entière » étaient calculées en UTC** (2026-10-06,
  sans changement de contrat, lot 0 du plan [fuseau des événements](plans/archive/2026-10-06-event-timezones.md))
  — une étape partant avant 02:00 heure de Paris commençait la veille dans l'agenda, une finissant
  après 22:00 y perdait son dernier jour. `IcsGenerationService` date `DTSTART` et `DTEND` des
  événements `allDay` dans le fuseau de l'étape, que `StageTimezones` résout : lieu de départ →
  1er point du parcours (non supprimé) → `Europe/Paris`. `TimezoneService.findZoneId` rend un
  `Optional` pour ce repli (`getZoneId` garde son repli UTC pour la météo). `allDayEnd` compte
  désormais en `LocalDate` dans ce fuseau. Les flux d'abonnement (`CalendarService.Feed`) et
  l'ICS d'un voyage (`PublicationIcsService`) passent la table id → fuseau ; les sorties restent en
  UTC avec `Z`. `X-WR-TIMEZONE:Europe/Paris` reste en dur, le fuseau d'équipe d'`API-60` le
  remplacera. Couvert par `StageTimezonesTest` et `IcsGenerationServiceTest`
  (`allDayEnd_countsDaysInTheStageZone`, `generateIcs_allDayStage_isDatedInParisByDefault`,
  `generateIcs_allDayStage_isDatedInItsOwnZone`). **À ne pas défaire** : une date d'événement
  journée entière se calcule dans un fuseau de lieu, jamais en UTC ni dans celui du serveur.

- `API-91` **`from` / `to` malformés donnaient une 500** (2026-10-06, sans changement de contrat)
  — `Instant.parse` lève une `DateTimeParseException`, que `GlobalExceptionMapper` ne traite pas en
  400. Les six ressources (`CalendarResource`, `TeamCalendarResource`, `PublicationResource`,
  `TeamPublicationResource`, `AdResource`, `UserResource`) lisent leurs bornes par
  `QueryInstants.parse`, qui lève `BadRequestException`. Décision : pas de `format: date-time` au
  contrat — il changerait le type des paramètres dans les clients générés pour un gain nul —, ni de
  traduction globale de `DateTimeParseException` en 400, qui ferait passer pour l'erreur de
  l'appelant une donnée invalide lue en base. Couvert par
  `CalendarResourceTest.getEvents_withMalformedBound_shouldReturn400` et
  `listPublications_withMalformedBound_shouldReturn400`.

- `API-92` **Mail d'export : date en heure de Paris et au format français pour tout le monde**
  (2026-10-06, sans changement de contrat) — l'expiration du lien suit la langue et le fuseau du
  destinataire par `NotificationTexts.formatDateTime` (« dimanche 11 octobre à 08h30 », « Sunday,
  October 11 at 3:30 PM »), le formateur des notifications rendu public ; `ExportJobContext` porte
  `user.timezone`, lu au chargement du job. Les quinze `@Scheduled(cron = …)` déclarent
  `timeZone = Crons.ZONE` (`UTC`) : comportement inchangé en production, où la JVM est en UTC, mais
  plus dépendant du fuseau de la machine. Couvert par
  `NotificationTextsTest.formatDateTime_followsTheReadersLanguageAndZone`. **À ne pas défaire** :
  un nouveau cron prend `timeZone = Crons.ZONE` ; les heures des tâches de nuit sont des heures UTC.

### Vie privée : les métadonnées retirées à l'import

- `API-43` **Les images perdent leurs métadonnées au stockage** (2026-09-29, contrat inchangé) —
  `S3StorageService.store`, le seul chemin par lequel un fichier atteint le bucket (upload
  d'asset, pièce jointe, avatar et son original temporaire, vignettes, import biketeam via
  `addAsset`/`uploadAssetFile`, `uploadTempFileToS3`), **fait réencoder toute image par imgproxy**
  (`ImgProxyClient.reencode` : `sm:1`, `kcr:0` — imgproxy garde le copyright par défaut —,
  `ar:1`, `q:90`, format imposé par l'extension) : seuls les pixels sont réécrits, redressés selon
  l'orientation, et rien de l'envoi ne subsiste (EXIF, GPS, XMP, IPTC, MPF, commentaires,
  miniatures, octets après la fin de l'image, polyglottes). JPEG, PNG, WebP et GIF (animé compris)
  gardent leur format ; TIFF (et les RAW qui en dérivent), HEIF/HEIC/AVIF et JPEG XL deviennent des
  JPEG, l'asset prenant `image/jpeg` et l'extension `.jpg` (`ImageFormat.storedFileName`). Seul le
  JPEG 2000, qu'imgproxy ne lit pas, est **refusé** (`FILE_TYPE_REJECTED`) ; une image qu'imgproxy
  refuse de décoder (4xx) est refusée en `INVALID_FORMAT`, une panne d'imgproxy (5xx) remonte en
  500. imgproxy lisant ses sources dans S3, l'original est déposé sous `tmp/reencode/<uuid>` le
  temps de l'appel et effacé dans un `finally` (orphelins en cas de JVM tuée : `OPS-17`) ; Varnish
  laisse passer ces URL sans les cacher. `FileTypeDetector` reconnaît ces images à leurs premiers
  octets **avant** Magika, qui n'a pas d'étiquette HEIC/AVIF/JXL, et les accepte pour les
  catégories `IMAGE` et `ATTACHMENT` avec le type sous lequel elles seront stockées. Rattrapage :
  V47 ajoute `assets.metadata_pending` (images et types `LOGO`/`IMAGE`/`ATTACHMENT`, index
  partiel) ; `AssetMetadataBackfillScheduler` (toutes les 5 min, lots de 100, curseur en mémoire)
  lit l'en-tête par une lecture partielle (`StorageService.retrieveHead`), ne télécharge que les
  images, les réécrit sous la même clé par `store`, met à jour nom et type de l'asset si le format
  change, puis efface le drapeau ; une erreur de stockage ou d'imgproxy transitoire le laisse posé.
  Tests : `StorageImageReencodingTest` (un corpus réel de huit formats chargés de métadonnées dans
  `src/test/resources/images/metadata`, rotation, animation, orphelin effacé), `ImageFormatTest`,
  `FileTypeCategoryTest`, `AssetServiceTest.MetadataRemoval`, `AssetMetadataBackfillTest`.
  **Décisions à ne pas défaire** : le nettoyage reste dans la couche de stockage, pas dans
  `AssetService` ni `UserAvatarService` (un futur chemin d'écriture le contournerait) ; le format se
  lit sur les octets (`ImageFormat.sniff`), jamais sur le type déclaré ni l'étiquette de Magika —
  un JPEG envoyé en `application/octet-stream` est réencodé aussi ; **réencoder plutôt que
  nettoyer** : un premier nettoyeur maison sans perte (`ImageMetadataStripper`, par liste blanche
  de segments et de chunks, ~700 lignes) a été livré puis retiré le même jour, jugé trop
  compliqué et pas assez sûr sur tous les cas ; la perte de qualité d'un réencodage à `q:90` est
  acceptée. Limites connues : les vidéos (`API-46`), documents (`API-47`), SVG/ICO (`API-48`)
  restent tels quels ; un GIF de plus de `IMGPROXY_MAX_ANIMATION_FRAMES` (100) images est
  tronqué ; un JPEG tronqué, que les navigateurs affichaient, est refusé ; la restauration d'une
  vieille sauvegarde MinIO est `OPS-15`. Les exports déjà générés (7 jours) et les sauvegardes
  antérieures (30 jours) gardent les originaux jusqu'à leur expiration.
- `API-53` **HEIC, HEIF, AVIF, TIFF et JPEG XL acceptés, stockés en JPEG** (2026-09-29, contrat
  inchangé) — refusés un temps par `API-43` faute de savoir en retirer les métadonnées sans perte,
  alors qu'iOS produit du HEIC par défaut. Le réencodage par imgproxy d'`API-43` les lit tous
  (conversion vérifiée sur un corpus réel) et les écrit en
  JPEG : format lu partout, y compris par les apps et les visionneuses de téléchargement, et sans
  la limite de 16 383 px du WebP qui aurait refusé les panoramas. Une transparence (AVIF, TIFF)
  est aplatie. Tests : `AssetServiceTest.MetadataRemoval.acceptsAHeicPhotoAndStoresAJpeg` et
  `acceptsATiffAnAvifAndAJpegXl`, `StorageImageReencodingTest`.
- `API-44` **Les GPX importés ne gardent que la trace et les waypoints** (2026-09-29, contrat
  inchangé) — `GpxSanitizer`, appelé en tête de `GpxProcessingService.computeGpx` (dans son `try`,
  donc une erreur donne `GPX_FAILURE`), avant l'écriture d'`original.gpx` : chaque point garde
  latitude, longitude et altitude, son instant devient `Instant.EPOCH`, ses extensions (fréquence
  cardiaque, cadence, puissance, température) disparaissent ; les waypoints gardent position et
  nom. Tous les fichiers stockés d'un parcours et d'un aperçu de l'outil GPX (original, filtré,
  FIT) en sortent : upload, planificateur, promotion d'un aperçu en parcours, import biketeam. Les
  métadonnées du document (auteur, e-mail, lien, `creator`) ne survivaient déjà pas au lecteur.
  Le constat d'origine était inexact : `original.gpx` était déjà une resérialisation ; la fuite
  était le `<time>` de chaque point dans les deux GPX, les extensions de `filtered.gpx` (celui des
  téléchargements, des routes d'appareil et des envois aux services GPS) et l'heure et la puissance
  du FIT. Rattrapage : `GpxSanitizationBackfill` (`service/gpx`, 4 h 15, après la purge des aperçus,
  `SKIP`) réécrit en place, sous la même clé, tout parcours (supprimés et tous domaines compris) et
  tout aperçu dont un fichier porte encore `<extensions>` ou un `<time>` autre qu'epoch, en
  régénérant le FIT **avant** le GPX filtré (qui est le seul signal de saleté) ; le pipeline
  (SRTM, simplification, montées) n'est pas rejoué. Le marqueur `maintenance/api-44-gpx-sanitized`
  n'est écrit qu'après une passe sans échec ; une restauration du bucket le fait disparaître et la
  passe repart. Tests : `GpxSanitizerTest`, `GpxSanitizationBackfillTest`,
  `GpxProcessingServiceTest#createTracks_shouldStripTimestampsAndSensorsFromEveryStoredFile`,
  `GpxPreviewServiceTest#create_shouldStripTimestampsAndSensorsFromStoredFiles`.
  **Décisions à ne pas défaire** : un seul point d'entrée (`computeGpx`), pas chez un appelant ;
  nettoyage **en place** (les appelants écrivent le FIT depuis le même objet `GPX`) ; `EPOCH` et
  non `null` (le rédacteur FIT et `computeArrays` exigent un instant, et c'est déjà la valeur d'un
  point sans `<time>`) ; pas de rejeu du pipeline dans le rattrapage. Rien n'utilisait les
  horodatages : distances, dénivelés, montées, vent, simplification sont de la géométrie. Limites
  connues : un GPX/FIT déposé en pièce jointe (`API-49`, `API-55`, depuis nettoyés) ; le rédacteur de la bibliothèque
  (`API-50`) ; la pose du marqueur n'a pas de test (`API-51`) ; les copies déjà envoyées à Garmin,
  Wahoo ou Hammerhead avant le correctif ne se réparent pas de notre côté.

- `API-51` **La pose du marqueur du rattrapage GPX est testée** (2026-09-30) — trois tests dans
  `GpxSanitizationBackfillTest` sur `runOnce` : après une passe sans échec, les fichiers sont
  nettoyés et `maintenance/api-44-gpx-sanitized` existe ; marqueur présent, un fichier sale reste
  sale (la passe ne tourne pas) ; un fichier sale et illisible fait échouer la passe
  (`failed() == 1`) et aucun marqueur n'est écrit. Le bucket de test étant partagé, le marqueur est
  effacé avant et après chaque test de la classe (`@AfterEach`) : ne pas retirer ce nettoyage, un
  marqueur oublié ferait sauter la passe à tout test qui appellerait `runOnce`. **Écrits sans avoir
  été lancés** (les tests backend sont au propriétaire du dépôt) : `mvn test
  -Dtest=GpxSanitizationBackfillTest`.

- `API-46` **Les vidéos ne sont plus acceptées** (2026-09-30, contrat inchangé, pas de migration) —
  une pièce jointe MP4/MOV était stockée telle quelle, avec le lieu de la prise dans `udta`/`meta`.
  Décision de l'utilisateur : **refuser les vidéos plutôt que les nettoyer**. Retirer `udta`/`meta`
  (même en les remplaçant par des boîtes `free` de même taille) aurait laissé les dates de `mvhd` et
  surtout les **pistes GPS temporisées** des caméras d'action (GoPro `gpmd`, DJI), qui sont des
  pistes du `moov` et non des boîtes de métadonnées : les retirer demande de réécrire `moov` et les
  tables d'offsets (`stco`/`co64`). Refus sur deux lignes : les étiquettes Magika `mp4`, `qt`, `3gp`,
  `mkv`, `webm` et `flv` entrent dans la liste noire `ATTACHMENT` ; et `FileTypeDetector.refuseVideo`
  refuse, en image comme en pièce jointe, tout conteneur vidéo lu à ses premiers octets, quels que
  soient l'étiquette et le nom : ISO base media (`ftyp`) qui n'est pas une image fixe (HEIF et AVIF
  sont reconnus avant par `ImageFormat`), EBML (Matroska, WebM), AVI, FLV. **Effet de bord
  assumé** : l'audio M4A, qui partage le conteneur ISO base media, est refusé avec eux. **Rien
  d'existant** : la production ne contenait aucune vidéo. **Politique de confidentialité modifiée**
  (§1, français et anglais ensemble) : les vidéos ne sont pas acceptées, et pourquoi ; les autres
  pièces jointes restent conservées telles quelles. Couvert par `FileTypeDetectorTest.Videos` (MP4,
  MOV, 3GP, WebM, AVI, FLV, un conteneur MP4 nommé `.pdf`, une WebP qui n'en est pas une) et
  `FileTypeCategoryTest.Attachment.rejectsVideoLabels`.

- `API-48` **Une icône est réencodée en PNG** (2026-09-30, contrat inchangé, pas de migration) —
  un ICO passait la liste blanche `IMAGE` sans être réencodé, et ses images peuvent être des PNG
  avec leurs blocs `tEXt`/`eXIf`. `ImageFormat` le reconnaît à son en-tête (réservé 0, type 1, au
  moins une image, octet réservé de la première entrée à 0 — pour ne pas le confondre avec un flux
  MPEG qui s'ouvre aussi sur `00 00 01`) et `S3StorageService.store` le fait réencoder par imgproxy
  **en PNG** : `favicon.ico` est stocké `favicon.png`, `image/png`. L'autre moitié de l'entrée,
  les SVG, est réglée par `SEC-1` (refusés à l'envoi). **Rien d'existant à rattraper** : la
  production ne contenait encore aucun fichier (décision de l'utilisateur, pas de rattrapage ni de
  migration). **La politique de confidentialité ne change pas** : son §1 disait déjà que toute image
  est réencodée ou refusée, ce qui devient exact pour les icônes. Couvert par
  `ImageFormatTest.anIconBecomesAPng`, `StorageImageReencodingTest` (`photo.ico`, le `photo.png` de
  test et ses métadonnées dans un conteneur ICO) et `AssetServiceTest.storesAnIconAsAPngWithoutItsMetadata`.

- `API-49` **Un GPX joint en pièce jointe ne garde que sa trace** (2026-09-30, contrat inchangé) —
  `API-44` ne couvrait que les parcours et l'outil GPX ; un `.gpx` déposé comme `ATTACHMENT` était
  stocké tel quel, horodatages et capteurs compris. `AssetService.addAssetStream` le passe
  maintenant par `TrackAttachmentSanitizer` avant le stockage : lu, nettoyé par `GpxSanitizer`,
  réécrit, **sans** rééchantillonnage ni correction d'altitude — une pièce jointe n'est pas un
  parcours, elle garde tous ses points. Un fichier `.gpx` illisible est refusé (`GPX_FAILURE`), un
  GPX sans trace ni point d'intérêt aussi (`GPX_EMPTY`) : le réécrire ne garderait rien. Les pièces
  jointes déjà stockées passent par `GpxSanitizationBackfill`, dont le marqueur devient
  `maintenance/api-49-gpx-sanitized` pour que la passe tourne une fois de plus là où
  `maintenance/api-44-gpx-sanitized` existe (parcours et aperçus déjà propres n'y sont que lus). Une
  pièce jointe y est jugée propre par `TrackAttachmentSanitizer.isClean`, pas par `isDirty` (un
  auteur ou un appareil n'est pas un `<time>`) ; une pièce jointe illisible est laissée et
  journalisée, **sans** faire échouer la passe, sinon le marqueur ne serait jamais posé. La politique
  (§1, FR et EN) dit désormais que ces fichiers sont nettoyés. Couvert par `AssetServiceTest`
  (`shouldStripClockSensorsAndAuthorFromAnAttachedGpx`, `shouldRefuseAGpxAttachmentThatIsNotAGpx`)
  et `GpxSanitizationBackfillTest` (`sanitizeAll_rewritesAGpxAttachmentStoredAsUploaded`,
  `sanitizeAll_leavesAnUnreadableAttachmentWithoutFailingThePass`), **écrits sans avoir été
  lancés** ; nettoyage idempotent vérifié hors suite sur la fixture `activity_with_sensors.gpx`.

- `API-55` **Un FIT joint en pièce jointe est réécrit en parcours** (2026-09-30, contrat inchangé,
  scindé d'`API-49`) — même chemin que le GPX. Le FIT est décodé par le SDK Garmin (déjà sur le
  classpath, par gpx2web), réduit à ses enregistrements positionnés (latitude, longitude,
  altitude) et à ses `course_point`, puis réécrit par le `FitFileWriter` de `route.fit` : tours,
  séances, informations d'appareil, VFC et tous les autres messages d'une activité disparaissent,
  le fichier se charge toujours sur un GPS, comme parcours à suivre. Le rédacteur date le fichier à
  sa création, donc un FIT propre n'est pas reconnu aux octets : `isClean` le tient pour propre
  quand c'est un parcours de notre rédacteur (même `file_id`), fait des seuls messages qu'il écrit,
  sans heure ni capteur sur aucun enregistrement — et `sanitize` le rend alors tel quel. Couvert par
  `AssetServiceTest.shouldStripClockAndSensorsFromAnAttachedFit` et
  `GpxSanitizationBackfillTest.sanitizeAll_rewritesAFitAttachmentStoredAsUploaded` (réécrit une
  fois, laissé la seconde), **écrits sans avoir été lancés**. Ne pas comparer un FIT aux octets pour
  décider de le réécrire : il serait réécrit à chaque passe.

- `API-45` **Plus de jeton dans un chemin d'URL** (2026-09-30, **API 6.5.0**) — le masquage du
  journal d'accès (`LEGAL-10`) ne porte que sur les paramètres de requête : deux jetons passaient
  en clair, dans le chemin, pendant 14 jours.
  - **Jeton FCM** : `POST /api/push-devices/unregister`, jeton dans le corps
    (`PushDeviceUnregistration`, `operationId` `unregisterPushDevice`) ; le web (`webPush.ts`) et
    le mobile (`PushDeviceRepository.unregister`) s'en servent.
  - **Jeton d'export** : `GET /api/export/download?token=`, que Caddy masque (`token`). Le
    courriel et la redirection vers la connexion (`UserExportService.downloadPath`, seule source du
    lien) prennent cette forme. Pas d'en-tête : le lien s'ouvre depuis un client de messagerie, par
    une navigation.

  Les anciennes formes restent servies et marquées `deprecated` au contrat
  (`unregisterPushDeviceByPath`, `downloadDataExportByPath`) pour les builds mobiles installés et
  les liens déjà envoyés : elles ont été retirées le 1er octobre 2026 en 10.0.0 (`API-56`). En chemin, deux fuites que le chemin masquait
  aussi : sans session, le jeton d'export repart dans `/login?next=…`, et les ressources de cette
  page le portent en `Referer` ; le snippet Caddy d'`OPERATIONS.md` les couvre désormais, appliqué
  sur l'hôte le 30 septembre 2026 (`OPS-24`). Tests : `PushDeviceResourceTest`
  (corps, ancienne forme encore servie, jeton vide refusé) et `UserExportResourceTest` (requête,
  redirection, ancienne forme, jeton absent) — **écrits sans avoir été lancés** : `mvn test
  -Dtest=PushDeviceResourceTest,UserExportResourceTest,UserExportServiceTest` ; e2e `pwa.e2e.ts`
  (la déconnexion envoie le jeton dans le corps, pas dans l'URL) et `flow-account.e2e.ts` (lien du
  courriel, aller-retour par la connexion) ; `mobile/check.sh` (684 tests).

- `API-56` **Les formes dépréciées d'`API-45` retirées** (2026-10-01, **API 10.0.0**, majeure) —
  `DELETE /api/push-devices/{token}` (`unregisterPushDeviceByPath`) et `GET
  /api/export/download/{token}` (`downloadDataExportByPath`) ne sont plus servies : plus aucun
  jeton dans un chemin d'URL. Retirées une fois la nouvelle app mobile déployée et sans export en
  attente de téléchargement (confirmé par le mainteneur). Clients web et mobile régénérés ; aucun
  appel manuscrit ne les utilisait (le web et le mobile passaient déjà par les formes d'`API-45`,
  karoo et garmin-app ne les connaissent pas). Tests : `PushDeviceResourceTest
  .unregisteringThroughTheFormerPath_isNotServed` (404/405, l'appareil reste enregistré) et
  `UserExportResourceTest.download_throughTheFormerPath_isNotServed` (404), lancés le 1er octobre
  avec `UserExportServiceTest` (39 tests verts) ; `mobile/check.sh` (698 tests). **À ne pas
  défaire** : ne pas rétablir de jeton dans un chemin, même « déprécié » — le masquage du journal
  d'accès ne porte que sur les paramètres de requête.

- `API-57` **`AuthToken` ne mappe plus `pending_password_hash`** (2026-10-01, livré avec l'API
  10.0.0, contrat inchangé, pas de migration) — le champ, inutilisé depuis `SEC-24` (le mot de
  passe se choisit à l'activation), est retiré d'`AuthToken`, et `AccountExport.AuthTokenEntry`
  ne le mentionne plus (il ne l'exportait déjà pas : la forme de `auth-tokens.json` ne change pas).
  La colonne reste, nullable depuis `V15` (aucune contrainte `NOT NULL` ajoutée ensuite) : la
  nouvelle release peut insérer sans elle. Sa suppression est `API-58`. Tests :
  `AuthResourceTest.register_storesNoPassword` et `verifyEmail_setsThePasswordChosenOnActivation`
  (le jeton d'avant `SEC-24` portant un hachage n'est plus représentable : l'aide de test
  `createVerificationTokenWithPassword` devient `createSignUpVerificationToken`),
  `UserExportServiceTest`, `UserExportResourceTest` — 81 tests verts le 1er octobre. **À ne pas
  défaire** : ne pas supprimer la colonne dans la même release que le champ — la 9.3.0, encore en
  service pendant le recouvrement start-first, l'écrit à chaque `INSERT` ; et ne pas la rendre
  `NOT NULL`.
- `API-58` **La colonne `auth_tokens.pending_password_hash` est supprimée** (2026-10-01, migration
  `V54__drop_pending_password_hash.sql`, contrat inchangé) — livrée une release après `API-57`,
  une fois 10.0.0 déployée en prod et en staging : pendant le recouvrement start-first, la release
  précédente (10.0.0) ne mappe plus la colonne. Les tests ne passent pas par Flyway (schéma
  généré depuis les entités) : la migration a été vérifiée sur la base locale, dans une
  transaction annulée. **À ne pas défaire** : ne pas réintroduire de mot de passe stocké avant la
  vérification de l'e-mail (`SEC-24`).

- `API-59` **Tags d'équipe sur les cinq types de contenu** (2026-10-01, **API 10.1.0**, mineure,
  migration `V55__tags.sql`, tables nouvelles seulement ; plan archivé
  [`2026-10-01-tags.md`](plans/archive/2026-10-01-tags.md), décisions D1 à D23) —
  - **Modèle** : `Tag` (`BaseEntity`, pas `TeamEntity` : pas de corbeille, D11) — équipe, `type`
    (`TagTarget` : `RIDE`, `POST`, `TRIP`, `ROUTE`, `AD`, D3), libellé, `color` (`TagColor`, les 9
    familles de `brand-colors.yaml`, D10) ; index unique `uk_tags_team_type_label` sur
    `(team_id, type, lower(label))` (D17). Liaisons `team_entity_tags` (les cinq types, tous dans
    `team_entities`) et `ride_template_tags` (D14), en cascade des deux côtés.
  - **Vocabulaire** : `GET /api/teams/{teamSlug}/tags?type=` (qui voit l'équipe ; trié par libellé,
    `usageCount` par tag en une requête), `POST`, `PATCH /{tagId}` (libellé, couleur ; jamais le
    type), `DELETE /{tagId}` → `TagDeletedDto.detachedCount` — admins seulement (`TagAccessChecker`,
    D4, D12). Bornes vérifiées par `TagService` (D16) : libellé non vide et ≤ 32 caractères
    **après trim**, comptés en points de code comme le `varchar(32)` (`TAG_LABEL_INVALID` ; le
    `@Size(max = 255)` des requêtes n'est qu'un plafond brut), ≤ 100 tags par équipe et type
    (`TAG_LIMIT_REACHED`), unicité insensible à la casse (409 `TAG_LABEL_TAKEN`, y compris quand
    deux admins écrivent le même libellé au même instant : le `flush` dans `createTag`/`updateTag`
    fait remonter l'index en 409 et non en 500 à la validation).
  - **Étiquetage** : `tagIds` sur les requêtes des cinq types et de `RideTemplateRequest` —
    `null`/absent laisse les tags tels quels (un client plus ancien ne les efface pas), `[]` les
    retire ; ≤ 10 (`TOO_MANY_TAGS`), tous de l'équipe et du type du contenu (`TAG_INVALID`). Droits
    = ceux d'édition du contenu, sans cas particulier (D5). `tags: TagDto[]` (`id`, `label`,
    `color`, triés par libellé) sur la liste et le détail de chaque type, et sur `RideTemplateDto`.
  - **Filtre** : `?tags=<id>,<id>` (ou répété) en OU par `EXISTS` (`TagFilter.andTaggedWithAny`,
    pas de doublon, compte cohérent) sur `/api/teams/{t}/publications` **avec un `type`**, `/routes`
    (+ `count`, `bounds`, tuiles) et `/classifieds` (+ `count`) ; les ids inconnus, d'une autre équipe ou d'un autre
    type sont ignorés et un filtre sans id connu ne filtre rien (D18). Absent des listes
    multi-équipes et ignoré par le fil mixte (D7, D13).
  - **Par page** : `TagLookup` résout les tags d'une page de liste (et d'un voyage avec les parcours
    de ses étapes) en une requête ; les constructeurs de lignes (`RideDto`/`TripDto.fromListItem`,
    `PublicationDto.from`, `TripStageDto.from`) n'ont plus de surcharge sans `ContentTags`, pour
    qu'un appelant de liste ne puisse pas rendre `tags: []` par oubli.
  - **Migration biketeam** : voir `MIG-14`.

  Tests (verts le 1er octobre 2026, suite backend complète comprise) :
  `TagResourceTest` (droits admin, bornes après trim, unicité par casse, détachement à la
  suppression), `ContentTaggingTest` (droits d'édition, type et équipe du tag, > 10, `tagIds`
  absent vs `[]`, `aTemplatesTags_areAnswered_andARideCreatedWithThem_carriesThem` pour D14),
  `TagFilterTest` (OU sans doublon, ids inconnus, fil mixte, listes multi-équipes),
  `TagLookupQueryCountTest`. La course de deux créations simultanées n'est pas testable : les tests
  construisent le schéma depuis les entités, sans l'index sur `lower(label)`. **À ne pas défaire** :
  la copie modèle → sortie (D14) est celle du client — pas de « création depuis un modèle » côté
  API ; le fil mixte ignore `?tags=` ; un id inconnu ne filtre rien plutôt que de vider la liste ;
  un changement de tags ne notifie pas (D23 : ne pas l'ajouter à `RIDE_UPDATED`) ; les tags d'une
  page se résolvent par page, jamais par ligne.

- `API-62` **Garmin par OAuth 1.0a, au choix du domaine** (2026-10-02, **API 10.3.0**, mineure,
  migration `V56__garmin_oauth1.sql`, colonnes nullables ou à défaut seulement) — le programme
  OAuth 2.0 de Garmin est en pause et n'admet pas notre application (`API-61`) ; seules les
  applications déclarées avant, en OAuth 1.0a, fonctionnent. Le code OAuth 2.0 est **conservé**.
  - **Credential** : `DomainGpsCredential.oauthVersion` (`GpsOAuthVersion`, `OAUTH2` par défaut,
    toutes les lignes existantes le restent). En `OAUTH1`, `clientId` est la consumer key et le
    secret la consumer secret. L'admin le règle (`oauthVersion` sur `CreateGpsCredentialRequest`,
    `null` = `OAUTH2` ; sur `UpdateGpsCredentialRequest`, `null` = inchangé ; renvoyé par
    `AdminGpsCredentialDto`) ; `OAUTH1` est refusé hors Garmin (`GPS_OAUTH_VERSION_NOT_SUPPORTED`)
    et sans secret (`GPS_CLIENT_SECRET_REQUIRED`). Sur le site, un sélecteur « Protocole »
    n'apparaît que pour Garmin, avec l'avertissement qu'en changer oblige chacun à reconnecter.
  - **Flux** (`GarminOAuth1Client`, mêmes endpoints que biketeam) : request token
    (`connectapi.garmin.com/oauth-service/oauth/request_token`, `oauth_callback` = le callback
    habituel `/api/gps/callback/garmin`), consentement sur `connect.garmin.com/oauthConfirm`, access
    token contre `oauth_verifier`. Le request token **tient lieu de state** : c'est lui que Garmin
    renvoie, il est stocké dans `gps_oauth_states.state` avec son secret chiffré
    (`request_token_secret_encrypted`), à usage unique et vérifié contre le service et le domaine
    comme un state OAuth 2.0. Le callback accepte `oauth_token`/`oauth_verifier` en plus de
    `code`/`state` ; un `oauth_token` sans verifier est un refus (`gps_error=access_denied`).
  - **Connexion** : le secret de l'access token est chiffré dans
    `gps_service_connections.access_token_secret_encrypted` ; sa présence fait d'une connexion une
    connexion OAuth 1.0a (`GpsServiceConnection.oauthVersion()`), sans expiration ni refresh.
  - **Envoi** : même requête `POST …/training-api/courses/v1/course` pour les deux protocoles
    (`GarminClient.uploadCourse`), signée HMAC-SHA1 (`OAuth1Signer`, écrit à la main, sans
    dépendance) au lieu d'un `Bearer`. **Le JSON était faux pour les deux** : `lat`/`lon`/`altitude`
    sont devenus `latitude`/`longitude`/`elevation`, et `coordinateSystem: "WGS84"` est envoyé,
    conformément à la Courses API et au format de biketeam.
  - **Changement de protocole** : une connexion faite sous l'autre protocole n'empêche pas de se
    reconnecter (la nouvelle remplace l'ancienne), et elle est supprimée à son prochain envoi, qui
    répond `success: false` sans lever d'exception pour que la suppression soit validée.

  Tests (**écrits, non lancés**) : `OAuth1SignerTest` (vecteur publié de Twitter, vérifié à part :
  `hCtSmYh+iHYCEqBWrE7C7hYmtUk=`), `GpsServiceOAuth1Test` (Garmin mocké : URL de consentement,
  stockage du jeton et du secret, usage unique, request token inconnu, request token refusé par le
  callback OAuth 2.0, envoi signé avec les bons jetons, connexion OAuth 2.0 abandonnée à l'envoi ou
  remplacée à la reconnexion), `AdminGpsCredentialResourceTest` (défaut `OAUTH2`, refus hors Garmin
  et sans secret, bascule et conservation à la mise à jour). L'échange réel avec Garmin n'est pas
  testé. **À ne pas défaire** : ne pas mettre la consumer secret dans le code ni dans une app ;
  garder le request token comme clé du state (Garmin ne renvoie pas de `state`) ; garder le code
  OAuth 2.0 jusqu'à `API-61`.
- `API-64` **Les appareils appairés, listés et déliés un par un** (2026-10-03, **API 10.5.0**,
  mineure, migration `V58__auth_session_device_client.sql`, colonne nullable ; **10.5.1**, patch :
  descriptions « Karoo, Garmin ») — un Karoo ou un Garmin appairé par code (RFC 8628) n'apparaissait nulle part : l'appairage ne laissait
  qu'une `AuthSession` anonyme (`userAgent = "karoo Device"`), et seul « Déconnecter tous les
  appareils » pouvait le délier, en fermant aussi le navigateur et l'app.
  - **Backend** : `AuthSession.deviceClient` (le `clientId` de l'appairage, null pour le site et
    l'app), renseigné par `DeviceAuthService.createTokenResponse` ; la migration le reprend des
    sessions existantes depuis `user_agent`. `GET /api/users/me/devices` (`PairedDeviceDto` : `id`,
    `type` `KAROO`/`GARMIN`/`OTHER` — le device flow accepte tout `clientId` —, `pairedAt`,
    `lastUsedAt` tenu par la rotation du refresh), sessions vivantes seulement, plus récentes
    d'abord ; `DELETE /api/users/me/devices/{deviceId}` révoque cette session
    (`PairedDeviceService`). Le jeton d'accès de l'appareil, un JWT, reste valide jusqu'à son
    expiration (15 min), comme après un logout-all.
  - **Clients** : sous les services GPS du profil, « Appareils appairés » — logo (Hammerhead pour
    un Karoo, Garmin pour un Garmin), « Appairé le … · utilisé il y a … », une croix « Délier »
    nommant l'appareil derrière une confirmation, et sans appareil un renvoi vers `/applications`.
    Le type s'affiche « Garmin », jamais « montre Garmin » : l'appareil appairé est le plus souvent un
    compteur Edge.
    Web `PairedDevicesManager`, mobile `PairedDevicesCard` (`paired_devices_section.dart`).
  - **Tests** : `PairedDevicesTest` (liste sans les sessions web ni celles d'un autre, ordre,
    `lastUsedAt` après un refresh, déliaison d'un seul appareil dont le refresh échoue en
    `TOKEN_INVALID`, 404 pour l'appareil d'un autre, une session web ou un second appel) ; vitest
    `PairedDevicesManager.test.tsx` ; widget `paired_devices_card_test.dart` ; e2e
    `flow-device.e2e.ts` (« the profile lists each paired device… », « a device of someone
    else… ») ; Patrol `profile_paired_devices_test.dart`. **À ne pas défaire** : identifier un
    appareil par `device_client`, jamais en analysant `user_agent` ; un seul 404 pour tout ce qui
    n'est pas un appareil vivant de l'appelant (rien ne dit qu'une session existe) ; délier ne
    touche qu'une session.

- `API-64` **QR code d'appairage sur l'app Garmin** (2026-10-03, sans changement de contrat) —
  l'écran de connexion (`garmin-app/source/LoginView.mc`) affiche, comme le Karoo, un QR de
  `verificationUriComplete` au-dessus du code, sur tous les Edge du manifest. Il affichait une URL
  écrite en dur (`pedalons.fr/garmin`), fausse sur tout autre domaine : c'est maintenant l'hôte de
  `verificationUri`, celle que renvoie le backend. Toybox n'a pas d'API de code-barres :
  `QrCode.mc` encode en Monkey C, réduit à l'utile — mode octet, niveau L, versions 3 et 4 (un
  seul bloc Reed-Solomon, au-delà de 78 octets l'écran retombe sur l'URL et le code) et **masque 0
  toujours**. Tests : `QrCodeTest.mc` (`make test`, simulateur lancé), comparé module par module à
  `python-qrcode` sur quatre URL aux bornes des deux versions, vecteurs produits par
  `garmin-app/scripts/qr-vectors.py`, qui vérifie aussi qu'ils se décodent (OpenCV). Le rendu et
  le scan sur l'écran d'un Edge n'ont pas été vérifiés. **À ne pas défaire** : ne pas ajouter
  l'évaluation des huit masques (n'importe quel masque se lit, et c'est le calcul qui exposerait au
  watchdog Connect IQ) ; garder le code en clair sous le QR, la page web demande de le comparer
  avant d'appairer (`SEC-2`) ; ne pas prendre segno comme référence, il bourre autrement et produit
  un autre QR, valide lui aussi.

- `API-65` **Délier un appareil le coupe aussitôt, et un Karoo s'affiche « Karoo »** (2026-10-03,
  **API 10.5.2**, patch : description de `unpairDevice` ; migration `V59__auth_session_device_client_karoo.sql`)
  — après « Délier », l'appareil marchait encore jusqu'à 15 minutes (son JWT n'était pas révocable,
  `API-64` l'avait accepté), et un Karoo apparaissait « Autre ».
  - **Jeton lié à l'appairage** : le JWT d'un appareil porte la claim `sid` (l'id de l'`AuthSession`
    de l'appairage), à l'émission comme au refresh ; `DeviceSessionFilter` (filtre JAX-RS global,
    `Priorities.AUTHENTICATION`) répond 401 dès que cette session est révoquée ou expirée — délier,
    ou « Déconnecter tous les appareils ». Une requête indexée par appel d'appareil ; les jetons du
    site et de l'app n'ont pas de `sid` et ne sont pas touchés, ceux émis avant le déploiement non
    plus (15 min au plus). 401 et non 403 : Karoo et Garmin y lisent « réappairer ».
  - **Karoo** : `DeviceCodeRequest.clientId` avait une valeur par défaut `"karoo"`, que
    kotlinx.serialization n'écrit pas (`encodeDefaults = false`) : le backend recevait `{}` et
    appairait sous `device`. Plus de valeur par défaut ; V59 renomme les appairages `device` en
    `karoo` (Garmin a toujours envoyé `garmin`). Il faut republier l'app Karoo, sinon les nouveaux
    appairages restent « Autre ».
  - **Tests** : `PairedDevicesTest.unpair_refusesThatDevicesAccessToken_atOnce`,
    `unpair_refusesTheAccessTokenOfARefresh` (écrits sans avoir été lancés). **À ne pas défaire** :
    ne pas retirer `sid` du jeton d'appareil ni le contrôle du filtre ; ne pas remettre de valeur par
    défaut à un champ Kotlin sérialisé que le backend doit recevoir.

### `API-39` T5.4 — Trombinoscope : débloqué par un réglage d'équipe (contrat `3.0.0`)

**Livré** — la page web des membres est venue ensuite, `WEB-1`. L'oracle
d'énumération est traité, l'autorisation est graduée, et l'ajout d'un membre par sélection
d'utilisateur a été remplacé par une invitation par e-mail.

**Le réglage.** `Team.enableMemberDirectory` (`V33`), famille des `enable*`, éditable par l'admin
d'équipe — mais **`DEFAULT FALSE`**, le seul du lot : ouvrir le trombinoscope montre l'annuaire
complet à chaque membre, c'est un geste de l'équipe et pas un effet de bord de la migration.

**L'autorisation, graduée sur deux axes** (`UserTeamAccessChecker`, `TeamMembershipService`) :

| Rôle | Accès | `search` porte sur | `role` / `joinedAt` |
|---|---|---|---|
| admin (d'équipe ou plateforme) | toujours | nom **ou e-mail** | présents |
| organisateur | toujours | nom seul | présents si le réglage est activé |
| membre | si le réglage est activé | nom seul | présents |
| non-membre | 403 | — | — |

L'organisateur voit la liste quoi qu'il arrive : il lui faut des candidats pour désigner un meneur de
groupe, et `RideService` refuse un meneur non-membre. Ce que le réglage lui retire, ce sont les rôles
et les dates, pas les gens. `LIST` a dû être **extrait** de sa branche commune avec
`CREATE`/`UPDATE`/`DELETE` : les laisser fusionnés aurait ouvert l'ajout et le retrait de membres.

**L'oracle est fermé** : `UserTeamRepository.findByTeam` prend un `searchEmail` que seul un admin
reçoit. `MemberDto.role` et `joinedAt` deviennent nullables — c'est, avec la suppression ci-dessous,
la raison du **MAJOR**.

**`GET /api/users/search` est supprimé.** Son seul appelant produit était `UserAutocomplete`, sur deux
écrans qui n'existent plus sous cette forme. Le sélecteur de meneur passe par
`TeamMemberAutocomplete`, qui interroge `…/members`. Le garde-fou serveur reste
`RideService.resolveLeader` (`RIDE_GROUP_LEADER_NOT_MEMBER`).

**L'ajout d'un membre est devenu une invitation** (`V34`, table `team_invitations`) : `POST`/`GET`/
`DELETE /api/teams/{teamSlug}/invitations`, `POST /api/invitations/preview` (public) et `/accept`,
plus `GET /api/users/me/invitations`. Quatre décisions à ne pas défaire :

- **Personne ne rejoint une équipe sans un clic à soi**, compte préexistant ou non. `AuthService`
  n'est pas touché : s'inscrire n'est pas accepter, et avec deux invitations en attente il n'y aurait
  rien pour choisir. D'où `/me/invitations`, qui est le seul rattrapage de l'inscription spontanée.
- **La création répond à l'identique que le compte existe ou non** — seul le gabarit d'e-mail change.
  Sinon tout admin d'une équipe qu'il vient de créer dispose d'une sonde d'existence de compte, ce que
  `requestOtp` / `requestPasswordReset` / `requestEmailChange` refusent déjà. Prix assumé : une faute
  de frappe ne se signale pas — d'où la liste des invitations en attente, qui la rend visible.
- **`addMemberAllowed` n'est pas revérifié à l'acceptation.** Il garde l'acte de l'admin, pas le
  consentement de l'invité. Idem pour le rôle de l'inviteur : le recours est la révocation, explicite.
- **L'acceptation est idempotente et n'écrase jamais le rôle** : une invitation MEMBER ne rétrograde
  pas un ADMIN.

Trois plafonds (`pedalons.teams.invitations.*`) : 20/h par inviteur et 50/j par équipe → **429** ;
5/j **par adresse** → **échec silencieux** (l'invitation existe, le mail n'est pas envoyé), sinon on
révélerait à l'admin A que l'admin B, d'une autre équipe, vient d'inviter la même personne.

Le mobile est fonctionnel : l'écran existait déjà, seule l'entrée de navigation a été conditionnée au
réglage. La recette web est `WEB-20` à `WEB-22`.

### `API-40` Coût par parcours de la géométrie — tranché en 2.0.0

**Résolu autrement que prévu, et il vaut mieux savoir comment.** Ce point demandait de borner
`simplify` et les climbs, dont un Douglas-Peucker superlinéaire relancé en lecture sur la trace
stockée (9,9 s pour une trace adverse de 100 k points) et un `simplify=NaN` qui passait les gardes.

La mesure a montré que le paramètre lui-même ne servait à rien : les points stockés sont **déjà**
rééchantillonnés puis filtrés Douglas-Peucker à l'import (`GpxProcessingService.computeGpx`), ce qui
les laisse à **88,7 m de médiane entre deux sommets** (p05 59 m, p95 120 m) sur les 5 493 parcours de
staging — 681 points pour le parcours médian, 65 Ko de JSON. Le mobile demandait `simplify: 5 /
points: 3000` sur sa fiche : un no-op complet. Et cette passe en lecture est purement 2D, donc elle
rabotait l'altitude que les mêmes coordonnées transportent en Z et M — d'où l'existence même de
`…/elevation-profile`.

`simplify`, `points`, `GET …/elevation-profile` et `elevation`/`elevationSamples` ont donc été
**supprimés**, avec `TrackGeometry`, `GeometryOptions`, `ElevationProfileDto` et tout le budget
`DEFAULT_BULK_MAX_POINTS_PER_ROUTE` / `perRouteBudget`. D1, D2 et D4 disparaissent avec eux. Un
drapeau `geometry=false` sur `/routes/bulk` remplace l'astuce `points: 2` des trois écrans web qui ne
voulaient que les métadonnées.

Côté mobile, la carte de masse ne paie plus ce coût : depuis le passage aux tuiles `.mvt` (API
2.3.0, `API-1`), elle ne charge plus aucune fiche de géométrie. Seuls les écrans de détail (parcours,
voyage plafonné à 12 étapes par `kTripTrackStageCap`) lisent la géométrie complète.

Ce qui reste ouvert (`MAX_BULK_SLUGS` comme seul garde-fou) est `API-27`.

---

### `API-66` Compteurs d'activité sur `TeamDetailDto` (contrat `10.6.0`)

Livré le 3 octobre 2026 (10.5.2 → 10.6.0, mineur, rétrocompatible) : `upcomingTripCount` (voyages
commençant à partir de maintenant) et `recentPostCount` (publications PUBLISHED datées dans
[maintenant − 7 j, maintenant]), sous les règles de visibilité, à 0 quand le module est coupé. Ils
nourrissent la ligne d'activité de « Mes équipes » (`WEB-42`, `MOB-42`). Tests (`TeamStatsResourceTest`) :
`getTeam_shouldCountUpcomingTripsAndRecentPosts`, `getTeam_admin_shouldNotCountADraftPostAsRecent`,
`listMyTeams_shouldCarryTheActivityCounters`, `getTeam_disabledModules_shouldCountNothing` ;
`TeamListQueryCountTest` (requêtes constantes pour `GET /api/teams?minRole=MEMBER` et anonyme) ;
aide `TestDataService.setTeamModules`. **À ne pas défaire** : les compteurs sont chargés par page
dans `TeamStatsRepository.load` (4 requêtes d'agrégat, jamais par ligne), via
`TeamEntityRepository.getPedalonsQuery` qui apporte les filtres domaine, visibilité, module et
suppression ; `recentPostCount` ne compte jamais un brouillon, même pour un admin ;
`RECENT_POST_WINDOW` = 7 jours.

### `API-69` Résumé du profil en un appel (contrat `10.7.0`)

Livré le 4 octobre 2026 (10.6.0 → 10.7.0, mineur, rétrocompatible) : `GET
/api/users/me/profile-summary` (`getMyProfileSummary`, `Cache-Control: private, no-store`) rend un
`ProfileSummaryDto` — `participations` (`upcomingCount`, `pastCount`, `next` : 0 ou 1 sortie en vue
COMPACT), `teams` (slug, nom, rôle, équipes du domaine triées par nom), `passkeyCount`,
`pairedDevices`, `blockedUserCount` (comptes non supprimés), `notifications` (`channels` que le
serveur sait envoyer, `enabledChannels`, `emailDigest` à false sans `EMAIL`). Il nourrit les lignes
d'état de la vue d'ensemble du profil (`WEB-55`, `MOB-48`) avec `/me`. Avec lui :
`NotificationLinks.PREFERENCES_PATH` = `/profile/notifications` (lien des e-mails) et
`GpsConnectReturn.PROFILE` revient sur `/profile/devices` (enum inchangé). Tests :
`ProfileSummaryResourceTest` (compteurs, filtre de domaine, bloqués supprimés, e-mail coupé côté
serveur), `ProfileSummaryQueryCountTest`, `GpsResourceTest.handleCallback_withoutReturnTo_shouldRedirectToProfileDevices`,
helper `TestDataService.createPairedDevice` — verts le 4 octobre 2026 (`API-70`). **À ne pas
défaire** : chaque compteur reste une requête `count`, jamais le chargement de la liste ; la
prochaine sortie passe par `listMyParticipations` (taille 1, lookups par page) ; `teams` filtré
par domainId ; `emailDigest` à false quand `EMAIL` n'est pas disponible (le champ brut de
`NotificationPreferencesDto.emailDigest`, lui, ne l'est pas : les clients le masquent) ; les
préférences d'affichage, `contactableByMembers` et `connectedServices` restent dans `/me`, sans
doublon. Le compteur « à venir » est borné par `Instant.now()`, l'onglet web par
`hourAlignedNowIso()` : un écart d'au plus une heure est accepté.

- `API-70` **Tests backend du résumé du profil lancés** (2026-10-04) — `ProfileSummaryResourceTest`,
  `ProfileSummaryQueryCountTest`, `GpsResourceTest` et `AdContactResourceTest` (gabarit
  `ad-contact.*` réécrit par `WEB-57`) sont passés dans la suite backend complète sur `b954747c`
  (3128 tests, 0 échec). Le budget d'entités de `ProfileSummaryQueryCountTest` (3 par ligne ajoutée,
  plus 8) a tenu sans ajustement. **À ne pas défaire** : si Hibernate charge un jour plus
  d'entités, on ajuste le budget, jamais en réintroduisant une requête par ligne.

### `API-79` Tableau de bord d'équipe en un appel (contrat `10.8.0`)

Livré le 6 octobre 2026 (10.7.0 → 10.8.0, mineur, rétrocompatible) : `GET
/api/teams/{teamSlug}/dashboard` (`getTeamDashboard`, `@RolesAllowed("user")`, `Cache-Control:
private, no-store` ; 401 anonyme, 403 non-membre, 404 équipe inconnue) rend un `TeamDashboardDto` :
`team` (le `TeamDetailDto` de `GET /api/teams/{slug}`), `role`, les sections membre `myUpcoming`
(sorties et voyages à venir où l'appelant est inscrit, du plus proche au plus lointain, 3),
`upcomingRides` (sorties publiées à venir, 3), `latestPosts`, `newRoutes`, `latestAds` (3 chacune,
`null` quand le module est coupé), un bloc `organizer` (brouillons, sorties sans parcours, sorties
avec un groupe complet, signalements ouverts, modèles de sortie ; 5 chacun) et un bloc `admin`
(3 nouveaux membres, webhook), `null` en dessous du rôle requis. Un admin de plateforme non membre
reçoit le tableau ADMIN. Briques ajoutées pour le servir, utilisables seules : `sortDir` sur
`GET /api/teams/{slug}/publications` (pas sur `/count`, qu'un ordre ne change pas) ; filtres
`withoutRoute` (ni parcours sur la sortie ni sur aucun groupe) et `withFullGroup` sur la liste et le
compteur ; `RideDto.groupSummaries` (`RideGroupSummaryDto`, remplis aussi sur les lignes de liste,
sans meneur ni participants) et `distance` / `elevationGain` / `surfaceType` du parcours de la
sortie, sinon du premier groupe qui en a un ; `TeamDetailDto.memberCountByRole` (admin d'équipe ou
de plateforme, `null` sinon et dans les listes) ; `sortBy=JOINED_AT` + `sortDir` sur les membres
(départage par id). Tests : `TeamDashboardResourceTest` (14), `TeamDashboardQueryCountTest` (ADMIN,
ORGANIZER, MEMBER), `TeamPublicationFiltersResourceTest`, `RideListGroupSummariesTest`,
`TeamMemberCountByRoleResourceTest`, `TeamMemberSortResourceTest` — verts dans la suite complète
du 5 octobre 2026 (2 088 tests, 0 échec). **À ne pas défaire** : chaque section est une page bornée
construite par les services existants, avec leurs lookups par page — jamais une requête par ligne ;
les effectifs par groupe sortent de la requête groupée de `RideSummaryRepository.loadGroupCounts`,
les mesures du parcours de la même requête de résumé ; le sélecteur d'équipes, le compteur de
non-lues et le jeton de calendrier restent **hors** de l'agrégat (partagés avec le reste de
l'application) ; `upcomingRides` et les tuiles organisateur ne montrent que du PUBLISHED, alors que
`myUpcoming` garde une sortie annulée où l'on est inscrit ; « Prix à négocier » = `price` nul, sans
champ dédié (décidé le 5 octobre 2026 avec le propriétaire). Le test de coût du membre fait signaler
les publications par un compte non mesuré : la liste cache à l'appelant ce qu'il a signalé, et ses
sections resteraient vides.

### `API-74` Météo des sorties : cache Open-Meteo et `getRideWeather` (contrat `10.9.0`)

Livré le 5 octobre 2026 (10.8.0 → 10.9.0, mineur, ajouts seulement), d'après le plan
[`2026-10-05-weather.md`](plans/archive/2026-10-05-weather.md), qui garde les arbitrages détaillés. Le
backend tient un **cache global** en Postgres (`V61__weather_cache.sql` : `weather_cells`,
`weather_hourly`, `weather_daily`, tables nouvelles seulement) rempli en tâche de fond depuis l'API
forecast d'Open-Meteo : `WeatherPlanner` (toutes les 5 min, sans HTTP) déduit des sorties PUBLISHED
de `[now, now+7 j]` les mailles nécessaires (~5 km, `CellKey`, bande d'altitude de 100 m) et leur
passage le plus proche ; `WeatherFetchWorker` (toutes les minutes) les réserve
(`for update skip locked` + bail `claimed_until`) et les récupère par lots de 100 lieux, au centre de
la maille ; TTL de 1 h, 3 h ou 6 h selon la distance du passage (`WeatherRefreshPolicy`), backoff
`min(5 min·2^attempts, 1 h)`, 429 jusqu'à l'heure pleine suivante, coupe-circuit et budgets par jour
UTC, heure et minute glissantes (`OpenMeteoCircuitBreaker`) ; `WeatherHousekeeping` purge la nuit.
Une cellule n'est réservée que si le planificateur l'a demandée depuis moins de 20 min et que son
passage est à venir : une orpheline n'est plus jamais récupérée, seulement purgée.

`GET /api/teams/{teamSlug}/rides/{rideSlug}/weather` (`getRideWeather`, `@CheckAccess(RIDE, READ)`)
rend un `RideWeatherDto` : météo au départ (`DepartureWeatherDto`), une `WeatherLegDto` par groupe
(heure de départ du groupe lue à l'heure locale du point de départ, vitesse du groupe ou **25 km/h**
avec `speedIsDefault`, points tous les 15 km et l'arrivée, vent relatif segment par segment, exposition
en mètres, vent dominant, alerte pluie ≥ 50 %) et l'attribution Open-Meteo.com (CC BY 4.0). Toujours
200 hors 404, l'état dans `status` (`OK`, `STALE`, `NOT_YET_AVAILABLE` + `availableFrom`,
`UNAVAILABLE`, `NO_LOCATION`, `OUT_OF_RANGE`) ; `Cache-Control: private, no-cache` et ETag faible,
`no-store` sans ETag pour `UNAVAILABLE`. Les listes portent un résumé `RideDto.weather`
(`RideWeatherSummaryDto`, min → max sur la fenêtre départ → dernière arrivée estimée), chargé par
`RideWeatherLookup.forRides` dans `PublicationService.list` et `RideService.toDto`. Les enums
`WeatherStatus`, `WeatherCondition` (table WMO dans la description du schéma), `RelativeWind`,
`CompassPoint` et `WeatherCheckpointKind` sont dans `fr.pedalons.enums`. Tests (lancés le 6 octobre, verts :
`API-75`) : purs — `CellKeyTest`, `RouteSampleLookupTest`, `RideWeatherCalculatorTest`
(changements d'heure, vitesse par défaut, aller-retour), `WeatherRefreshPolicyTest`,
`OpenMeteoGatewayTest`, `OpenMeteoClientTest`, `OpenMeteoCircuitBreakerTest` ; `@QuarkusTest` —
`WeatherCacheTest`, `WeatherPlannerTest`, `WeatherFetchWorkerTest`, `WeatherHousekeepingTest`,
`OpenMeteoGatewayHttpTest` (vrai client sur un serveur local qui répond 429), `RideWeatherResourceTest`
(dont `weather_withAForecast_isOk_andCarriesNoCoordinate`) et
`PublicationQueryCountTest.listTeamRides_inTheForecastWindow_weatherCostsAPageNotARow`.

**À ne pas défaire** :

- **Cache global, sans `domainId`** : une ligne n'est fonction que de (maille, heure), et n'est lue
  qu'en partant d'une sortie que l'appelant a le droit de lire. C'est l'exception explicite à
  « toutes les requêtes filtrent par domainId », écrite dans la javadoc de `domain/weather` ; deux
  domaines au même départ partagent une cellule (`WeatherPlannerTest`).
- **Aucune coordonnée dans les DTO météo** : une sortie PUBLIC peut pointer sur un parcours TEAM.
  Les points se placent côté client par `distance` sur la géométrie lisible ; le fournisseur n'est
  interrogé qu'au centre de la maille, jamais au lieu de rendez-vous.
- **Tous les calculs côté serveur** (`RideWeatherCalculator`, fonctions pures) : heures de passage,
  échantillons, vent relatif, exposition, alerte pluie, rose des vents. Les clients n'affichent,
  ne traduisent et ne convertissent que les unités.
- **Jamais d'appel à Open-Meteo ni d'écriture en base pendant une requête HTTP** : la lecture ne
  touche que le cache, ce qui permet au SSR web de la préfetcher sans risque.
- La liste coûte **0 requête** si aucune sortie de la page n'est dans la fenêtre, **1** sinon
  (`WeatherHourlyRepository.findRideWindowHours`, tout en SQL natif) ; ne pas charger les groupes
  par ligne. Dans ce chemin l'heure locale d'un groupe se lit dans le fuseau rendu par Open-Meteo
  pour la maille (pas `TimezoneService`) : écart accepté en limite de fuseau.
- L'ETag est un condensé SHA-256 du corps (calculé dans `RideService`, rendu par
  `RideWeatherAnswer`), pas « version + `fetchedAt` » : modifier un groupe ne change pas la
  `version` de la sortie, et un passage en `STALE` non plus.
- Le client REST `open-meteo` a `disable-default-mapper=true`, et `OpenMeteoGateway` relit une
  `WebApplicationException` comme la réponse qu'elle porte : sinon un 429 passe pour un échec
  ordinaire. La clé (`OPEN_METEO_API_KEY`) part en paramètre de requête : l'URL n'est jamais
  journalisée.
- Une sortie partie, annulée ou en brouillon est `OUT_OF_RANGE` (fenêtre du planificateur alignée
  sur `[now, now+7 j]`) ; une étape sans parcours est `NO_LOCATION` sans compter dans le statut
  global ; une étape dont certains points manquent est `STALE`. Un échantillon à 5 km pile de
  l'arrivée est omis. À rouvrir ensemble si la lecture sert un jour les sorties en cours.
- Sur échec, rien n'est supprimé : on sert le cache périmé (`STALE` au-delà de deux intervalles de
  rafraîchissement).

### `API-75` Tests backend de la météo, lancés

Lancés le 6 octobre 2026 : les 16 classes de la météo des sorties et des voyages
(`TripWeatherResourceTest`, `CellKeyTest`, `RouteSampleLookupTest`, `RideWeatherCalculatorTest`,
`WeatherRefreshPolicyTest`, `OpenMeteoGatewayTest`, `OpenMeteoClientTest`,
`OpenMeteoCircuitBreakerTest`, `OpenMeteoGatewayHttpTest`, `WeatherCacheTest`,
`WeatherFetchWorkerTest`, `WeatherPlannerTest`, `WeatherHousekeepingTest`, `RideWeatherResourceTest`,
`PublicationQueryCountTest`, `ArchitectureTest` : 166 tests) puis la suite complète (3 312 tests),
sans un échec ni correction : le SQL natif de V61 (upsert `NULLS NOT DISTINCT`, backoff, fenêtre de
la liste) tient sur la base de test. **À ne pas défaire** : un échec futur de
`PublicationQueryCountTest` se corrige dans `RideWeatherLookup`, jamais en desserrant le test.

### `API-76` Météo des voyages, étape par étape : `getTripWeather` (contrat `10.11.0`)

Livré le 6 octobre 2026 (10.10.0 → 10.11.0, mineur, ajouts seulement), sur les briques de `API-74`
et le §6 du plan [`2026-10-05-weather.md`](plans/archive/2026-10-05-weather.md). Constat préalable :
`TripStage.dateTime` est un vrai instant de départ (l'éditeur saisit date **et** heure ; une étape
migrée de biketeam reçoit l'heure de rendez-vous du voyage ou 8 h), donc aucun fuseau n'entre en jeu.
`GET /api/teams/{teamSlug}/trips/{tripSlug}/weather` (`getTripWeather`, `@CheckAccess(TRIP, READ)`,
mêmes en-têtes de cache que `getRideWeather`) rend un `TripWeatherDto` : une `TripStageWeatherDto`
par étape vivante, dans l'ordre de `TripDto.stages` (`stageId`, `leg` : `WeatherLegDto` du parcours
de l'étape à sa vitesse `averageSpeed` (`API-81`) ou 25 km/h, `summary` : `RideWeatherSummaryDto`
d'une ligne pour sa carte) ; un voyage sans étape a une seule entrée sans `stageId`, sur son propre
parcours. Chaque étape a **son** statut : partie → `OUT_OF_RANGE`, au-delà de 7 jours →
`NOT_YET_AVAILABLE` avec `WeatherLegDto.availableFrom` (champ nouveau, générique), sans parcours →
`NO_LOCATION`. Le statut global ne compte que les étapes à venir avec parcours dans l'horizon
(`RideWeatherCalculator.trip`) ; brouillon ou annulé → `OUT_OF_RANGE`. Pas de bloc « départ » : le
premier point du parcours est le départ. `WeatherPlanner` demande aussi les mailles des étapes
partant dans `[now, now+7 j]` (`TripStageRepository.findForWeather`) et des voyages sans étape
(`TripRepository.findStagelessForWeather`), via `TripWeatherPlans`, que la lecture
(`TripWeatherService`) partage. Au passage : lecture du cache extraite dans `WeatherSeriesLoader`,
ETag dans `WeatherEtag`, communs aux sorties et aux voyages. Tests (lancés, verts : `API-75`) : `TripWeatherResourceTest`, cas `trip_*` et `legSummary_*` de
`RideWeatherCalculatorTest`, `plan_shouldPlanTheStagesOfPublishedTripsLeavingInTheWindow` de
`WeatherPlannerTest`.

**À ne pas défaire** :
- Une étape partie reste dans la liste (`OUT_OF_RANGE`) : la liste suit `TripDto.stages` un pour un,
  les clients apparient par `stageId`.
- Le nombre de requêtes ne dépend pas du nombre d'étapes (traces, mailles, heures : une chacune) ;
  les heures sont lues sur une seule fenêtre couvrant les étapes dans l'horizon, bornée à ~7 jours.
- `RideWeatherSummaryDto.rainAlert.distance` est absente sur une sortie, présente sur une étape.
- Le résumé dans `TripDto` pour les cartes de liste n'est **pas** fait : c'est `API-82`.

### `API-82` Météo des voyages sur les cartes de liste (contrat `10.13.0`)

Livré le 6 octobre 2026 (10.12.0 → 10.13.0, mineur : un champ optionnel), reste de `API-76`.
`TripDto.weather` (`RideWeatherSummaryDto`, optionnel) porte la ligne météo d'une carte de voyage :
celle de sa **prochaine étape** — la première étape vivante partant à `now` ou après (par date, puis
rang), sinon le voyage lui-même s'il n'a pas d'étape. `TripWeatherLookup.forTrips` la calcule pour
toute la page dans `PublicationService.list` : **aucune** requête quand aucun voyage de la page n'a
d'étape restant à partir (brouillon, annulé, dernière étape partie — lu dans le `TripListSummary`
déjà chargé), **une** sinon (`WeatherHourlyRepository.findTripNextLegHours`), sans charger les
étapes : la prochaine étape, sa maille de départ et sa fenêtre (départ → départ + distance du
parcours à sa `averageSpeed`, 25 km/h à défaut) sont écrites en SQL. La maille de départ est celle
que le détail lit pour le premier point de contrôle de l'étape : premier point de la première trace
non vide du parcours, **avec** sa tranche d'altitude (aucune si la trace n'a pas d'altitude) — la
maille que le planificateur rapatrie déjà ; une étape sans parcours ne donne rien (`NO_LOCATION` au
détail). Au-delà de 7 jours, `NOT_YET_AVAILABLE` avec `availableFrom`. Absente sur la fiche du voyage
(`getTripWeather` y suffit). Résultat dans `RideWeatherSummaries` (nouvelle méthode `forTrip`).
Web : `PublicationCard` rend `RideWeatherSummaryLine` pour `TRIP` comme pour `RIDE`. Mobile :
`_TripBody` de `publication_card.dart` passe `trip.weather` au `RideWeatherSummaryLine` de la carte
de sortie (ni voyage terminé, ni annulé). Tests :
`PublicationQueryCountTest.listTeamTrips_inTheForecastWindow_weatherCostsAPageNotARow` (30 voyages dont la 1ʳᵉ étape est partie
et la 2ᵉ part demain : chaque carte `OK` à 14 °C, coût plat entre 3 et 30 lignes), mobile
`ride_card_weather_test.dart` (carte de voyage, terminée, annulée).

**À ne pas défaire** :
- Une requête par page au plus, jamais une par voyage, et jamais `trip.getStages()` sur une ligne de
  liste : un échec de `PublicationQueryCountTest` se corrige dans `TripWeatherLookup` / le SQL.
- La maille lue est celle du premier point de la trace, tranche d'altitude comprise : une maille sans
  tranche (comme pour le point de rendez-vous d'une sortie) n'est jamais rapatriée pour une étape, la
  ligne resterait vide.
- Le chemin JSON de `jsonb_path_exists` passe en paramètre : son `?` littéral serait lu comme un
  paramètre JDBC.
- Comme pour une sortie, les extrêmes sont ceux d'une seule maille (le départ) et l'alerte pluie n'a
  pas de `distance` ; la ligne de l'étape elle-même (`getTripWeather`) reste la référence.

### `API-60` Fuseau horaire des événements — livré du 6 au 7 octobre 2026 (contrats `10.17.0` → `11.0.0`)

**Clos le 7 octobre 2026**, les lots 0 à 7 en production. Une heure de rendez-vous (départ de
sortie, de groupe, d'étape, publication programmée) se saisit en heure murale, se stocke en instant
avec le fuseau de saisie que le backend résout (lieu de départ → parcours → étape précédente →
équipe), et se lit dans le fuseau de l'entité, avec la mention « heure de Tokyo (… chez vous) »
quand le décalage du lecteur diffère. Plan archivé :
[`2026-10-06-event-timezones.md`](plans/archive/2026-10-06-event-timezones.md).

Historique tel que le ledger l'a suivi :

Une heure de départ est saisie dans le fuseau de celui qui la tape, affichée dans le fuseau de celui
qui la lit, sans jamais nommer ni l'un ni l'autre ; l'heure d'un groupe (`LocalTime`) n'en a aucun.
Consulter la sortie de son équipe parisienne depuis Tokyo affiche 16:30 pour la sortie et 09:30 pour
son groupe ; préparer une étape au Japon depuis Paris oblige à convertir de tête. Le plan
[`2026-10-06-event-timezones.md`](plans/archive/2026-10-06-event-timezones.md) donne un fuseau obligatoire à
l'équipe (`Europe/Paris` à la migration), stocke sur chaque entité son *fuseau de saisie* résolu par
le backend (lieu de départ → parcours → étape précédente → équipe), fait passer
`ride_groups.time` en instant, saisit en heure murale et affiche les rendez-vous dans le fuseau de
l'entité avec une mention quand il diffère de celui du lecteur. Les instants restent la vérité
stockée, la fin stockée d'`API-85` comprise. Contrat en deux versions (ancien format de requête
toléré une version).
**Rouvert le 6 octobre 2026** : écarté le 2 octobre au profit de la préférence `UserDto.timezone`
(`API-15`), avec pour condition de réouverture « des voyages à l'étranger qui rendent l'heure locale
de l'étape nécessaire » — c'est le cas qui a déclenché l'audit. Le fuseau résolu est bien celui du
lieu de départ, comme la note d'alors le demandait ; celui de l'équipe n'est que le repli.
Plan validé le 6 octobre 2026 (décisions au §12). **Lot 0 livré le 6 octobre 2026** (`API-90`,
`API-91`, `API-92`, `WEB-70`, `WEB-71`).

**Lot 1 (backend) livré le 6 octobre 2026, contrat `10.17.0`** (mineure : l'ancien format de
requête est toléré). Livré :

- **Colonnes** (`V64__event_timezones.sql`) : `teams.timezone varchar(64) NOT NULL DEFAULT
  'Europe/Paris'`, `team_entities.timezone` et `ride_groups.start_at` nullables le temps d'une
  version, `users.timezone` élargie à 64 ; remplissage SQL du §8.2 (fuseau de l'équipe, `start_at`
  depuis `time` sur la date locale de la sortie). Les lignes que l'ancienne version écrit pendant la
  bascule sont remplies au démarrage par `EventTimezoneBackfill` (modèle de
  `PublicationEndBackfill`) ; les lectures retombent sur l'équipe et sur `legStart` en attendant.
- **Résolution** : `EventTimezoneResolver` (chaînes du §4, jamais UTC ; en mer, `timeshape` rend le
  fuseau nautique `Etc/GMT±n`, pas l'équipe). Sorties, voyages, étapes et articles stockent le
  fuseau de leur enregistrement ; `ride_groups.start_at` est écrit à chaque enregistrement de la
  sortie.
- **Contrat** : `dateTime` et `publishAt` des requêtes sont un `EventDateTime` (chaîne sans
  `format: date-time`) — heure murale lue dans le fuseau résolu, ou instant avec `Z`/offset gardé
  tel quel (ancien SPA) ; `TeamRequest.timezone` / `TeamDetailDto.timezone` ; `timezone` sur
  `RideDto`, `TripDto`, `TripStageDto`, `PostDto`, `RouteUsageDto`, `CalendarEventDto` ; `startAt`
  sur `RideGroupDto` et `RideGroupSummaryDto` (`time` servi, déprécié) ; nouvel appel
  `GET /api/teams/{teamSlug}/timezone?lat=&lon=` (organisateur au minimum).
- **Changement de fuseau d'équipe** (§9) : `TeamTimezoneChange`, dans la même transaction —
  entités à venir, sans lieu, stockées dans l'ancien fuseau, réécrites à heure murale constante ;
  seuls les instants encore à venir bougent ; la fin stockée est recalculée.
- **Tests** (écrits, à lancer) : `EventTimezoneResolverTest`, `EventDateTimeTest`,
  `RideTimezoneTest`, `TripTimezoneTest`, `PostTimezoneTest`, `TeamTimezoneResourceTest`,
  `TeamTimezoneChangeTest`, `EventTimezoneBackfillTest`, `PublicationEndStoredTest` étendu
  (changement de lieu, de fuseau d'équipe ; remplacement de GPX qui ne touche ni le fuseau ni le
  départ).

**Lot 2 (web) livré le 6 octobre 2026, contrat `10.18.0`** (mineure : un appel d'aperçu). Les
éditeurs de sortie, de voyage et de publication saisissent et renvoient des heures murales
(`WallDateTimePicker`, fin d'`InstantDateTimePicker`), y compris les menus publier / dépublier /
annuler (`rideToRequest`, `tripToRequest`, `postToRequest`) ; la mention « heure de Tokyo »
(`zoneLabel.ts`, `useZoneMention`) n'apparaît que si les décalages diffèrent ; pendant l'édition,
`useEventTimezone` suit la chaîne du §4 et interroge `…/timezone` (délai, un appel par point
distinct, aucun à l'ouverture d'une entité existante) ; « Ajouter une étape » = étape précédente
J+1 sur la chaîne (`addDaysToWallTime`, qui remplace `addCalendarDays` de `WEB-71`). Réglage du
fuseau d'équipe dans `TeamForm` (`TimezoneSelect`, villes nommées par la règle du §7), pré-rempli
avec le fuseau du navigateur à la création ; un changement passe par une confirmation qui montre
l'aperçu du §9, calculé par `GET /api/teams/{teamSlug}/timezone/change-preview` (admin, sans
écriture) : `TeamTimezoneChange.plan()` est la sélection que `apply()` réécrit, les deux ne
peuvent pas diverger. Vitest tourne en `Europe/Paris`. Tests : `wallTime.test.ts`,
`zoneLabel.test.ts`, `useEventTimezone.test.ts`, `useZoneMention.test.tsx`,
`TimezoneChangePreview.test.tsx`, `TeamTimezoneChangeTest` (aperçu = ce que le changement
réécrit, 403, 400). **À ne pas défaire** : le front ne calcule jamais le fuseau d'une donnée — il
envoie des heures murales et le backend résout ; le fuseau qu'il demande ou déduit ne sert qu'à
l'étiquette (et au contrôle « publication dans le futur »), et l'aperçu du §9 vient du backend, pas
d'un calcul client. Le scénario Playwright du §11 a suivi le 7 octobre 2026 :
`event-timezones.e2e.ts` (une équipe à Paris lue depuis un navigateur à Tokyo — heure de Paris,
mention avec le jour qui change, absente du rendu serveur et sans erreur d'hydratation, heure du
groupe seulement quand il part à la sienne, saisie de l'éditeur rendue telle quelle ; et l'inverse,
une équipe à Tokyo lue depuis Paris).

**Lot 3 (web) livré le 7 octobre 2026** (sans changement de contrat). Les rendez-vous se lisent dans
le fuseau de l'entité, les horodatages restent dans celui du lecteur : `useRendezvousFormat(zone)`
(formateurs dans le fuseau de l'entité, mention à l'instant de l'événement), `rendezvousMention`
(`utils/rendezvous.ts` : « heure de Tokyo (sam. 23:00 chez vous) », le jour seulement quand il
change, rien quand les décalages sont égaux) et `<Rendezvous>` (`detail` : mention en ligne ;
`card` : icône `IconWorld` + infobulle ; `ZoneMentionIcon` pour une plage ou un texte composé).
Appliqué aux détails (sortie, voyage et sa fin dans le fuseau de la dernière étape — `tripEndZone`,
étape, article, publication programmée), aux cartes et lignes (`PublicationCard`, tableau de bord,
`NextRideCard`, `RouteUsages`, profil, onglets d'étape), aux plages de l'Agenda
(`formatPublicationSpan`, une seule icône ; `DayBox` prend le fuseau de l'entité à côté d'une plage
en mode `time`), à l'heure des groupes (`startAt`, fin du « 08:30:00 » brut et de `shortTime`), au
calendrier (heure de l'événement en `p` selon la langue au lieu de `HH:mm` figé, mention dans
l'infobulle et en seconde ligne sur téléphone ; la grille reste celle du lecteur) et à la semaine de
l'accueil (jour et heure de la ligne dans le fuseau de l'entité ; bandeau, points et « aujourd'hui »
du lecteur). Décidé au passage : les heures de la météo (départ, passages, alerte pluie) suivent le
fuseau de la sortie ou de l'étape, sans mention (l'en-tête du détail la porte) ; la date SEO /
`og:` (`routeMeta.ts`) passe au fuseau de l'entité (une ligne, prise sur le lot 4). Tests :
`rendezvous.test.ts` (Paris lu depuis Bruxelles muet, Tokyo lu depuis Paris avec le jour qui change,
Londres/UTC selon l'heure d'été, plages et voyage multi-fuseaux), `Rendezvous.test.tsx`,
`routeMeta.test.ts` étendu. **À ne pas défaire** : la mention compare des décalages à l'instant de
l'événement, jamais des identifiants ; le texte dans le fuseau de l'entité est identique côté
serveur et client, seule la mention dépend du lecteur.

**Lot 3 (mobile) livré le 7 octobre 2026** (sans changement de contrat). Même règle que le web :
`zone_label.dart` reprend la table des villes françaises et la règle « de / d' / du / des » de
`zoneLabel.ts` (à garder en phase), les rendez-vous passent par `AppFormatters` dans le fuseau de
l'entité avec la mention (en ligne au détail, en seconde ligne sur les cartes), l'heure d'un groupe
vient de `startAt`, et l'heure suit le réglage 12 h / 24 h du téléphone
(`MediaQuery.alwaysUse24HourFormat`) au lieu de `DateFormat.Hm`. Un fuseau inconnu se lit dans
celui du lecteur, sans mention. Les heures de la météo restaient dans le fuseau du lecteur
(passées au fuseau de l'entité par le lot 4) ; la grille du calendrier y reste, journées entières
comprises. Tests : `display_timezone_test.dart` étendu
(Paris lu depuis Bruxelles muet, Tokyo lu depuis Paris avec le jour qui change), détail d'article,
fin de voyage par l'étape la plus tardive.

Arbitré à la relecture du lot 3 (web et mobile) : **pas de mention tant que le fuseau du lecteur
est le substitut du serveur** (`useEffectiveTimezone().isPlaceholder` : rendu SSR anonyme et rendu
d'hydratation) — calculée contre `UTC`, elle affirmait un « 06:00 chez vous » faux à tout visiteur
d'une équipe européenne ; elle apparaît au rendu qui suit l'hydratation (`Rendezvous.test.tsx`,
`renderToString`). **Un fuseau que l'`Intl` du navigateur ignore** (la base tz du JDK peut le
devancer : `Europe/Kyiv` sur un vieux Safari) se lit dans le fuseau du lecteur, sans mention, au
lieu de lever pendant le rendu (`isSupportedZone`, `zoneLabel.ts`) — la règle du mobile. **La date
d'un article est un rendez-vous complet sur les deux clients** : date et heure dans le fuseau de
l'article, puis la mention (`post_detail_page.dart` rejoint le détail web). **L'heure d'un groupe**
ne s'affiche que si `startAt` est un autre instant que le départ de la sortie
(`groupLeavesAtOwnTime`, web et mobile, jamais le `time` déprécié) et porte sa mention sur les deux
clients (icône à infobulle, focalisable au clavier, sur le web ; seconde ligne sur mobile). La fin
d'un voyage se lit dans le fuseau de l'étape **la plus tardive par instant**, pas la dernière par
ordre, sur les deux clients (`tripEndZone`, `TripTiming.endTimezone`).

**Lot 4 (consommateurs backend) livré le 7 octobre 2026** (contrat 10.19.0 → 10.21.0). **Une
seule source de départ** : la météo (détail et liste en SQL), les appareils
(`DeviceRouteService.departureZone`) et `PublicationEndCalculator` partent de `ride_groups.start_at`
via `EventTimezoneResolver.startAt` (repli, pour une ligne d'une version antérieure : `time` à la
date locale de la sortie dans son fuseau stocké, sinon celui de l'équipe) ; `legStart`,
`RideWeatherPlans.departure()` et `TimezoneService.getZoneId` (repli UTC) disparaissent, le fuseau de
`weather_cells` ne date plus que ses lignes journalières. `V65__ride_end_from_group_start.sql` vide
la fin stockée des sorties à venir ayant un groupe à l'heure, recalculée au démarrage par
`PublicationEndBackfill`. **10.19.0** : `DeviceRideDto.timezone` (Karoo et Garmin peuvent l'ignorer).
**10.20.0** : `NotificationDto.subjectTimezone`, figé au fan-out dans
`notification_events.subject_timezone` (`V66`, nullable sans défaut ni rattrapage : sûr en
déploiement start-first) ; `NotificationTexts` écrit l'heure du sujet dans son fuseau, nommé
(« heure de Tokyo », `ZoneLabels`) avec l'équivalent du lecteur quand il a un fuseau et qu'il
diffère. Les webhooks d'équipe écrivent dans le fuseau du sujet (plus Paris en dur), nommé quand ce
n'est pas celui de l'équipe, et le `subject.timezone` du format `GENERIC`. iCal : les étapes
« journée entière » sont datées dans le fuseau de `CalendarEventDto.timezone` (fin de
`StageTimezones`), `X-WR-TIMEZONE` vaut le fuseau de l'équipe pour un flux d'équipe, celui de la
sortie ou du voyage pour un ICS unitaire, et disparaît du flux personnel (plusieurs équipes). **10.21.0** :
`RideWeatherSummaryDto.timezone`, posé sur la carte d'un voyage — le fuseau de sa prochaine étape,
calculé dans la même requête de page (`findTripNextLegHours`), qui n'est pas `TripDto.timezone`
(la première) ; les deux clients le préfèrent au fuseau de la carte. Clients : `NotificationItem`
(web) et `subjectDateLine` (mobile) lisent la date du sujet dans `subjectTimezone` avec la mention ;
les heures de la météo mobile (départ, arrivée, passages, alerte pluie, chronologie, lever et
coucher du soleil) dans le fuseau de la sortie ou de l'étape, sans mention. Tests :
`NotificationTextsTest` (`rendezvousAbroad_readsInItsZone_withTheReadersEquivalent`,
`subjectWithoutAZone_readsInParis`…), `ZoneLabelsTest`, `NotificationPipelineTest`
(`publishedRide_freezesItsZone_andTheInboxCarriesIt`), `NotificationPhase5Test`
(`webhook_writesTheRideInItsZone_namedWhenNotTheTeams`), `IcsGenerationServiceTest`,
`CalendarServiceTest` (`icsFeeds_dateAnAllDayStage_inItsStoredZone`), `EventTimezoneResolverTest`
(`startAt_*`), `PublicationEndCalculatorTest`, `PublicationEndStoredTest`, `RideWeatherCalculatorTest`,
`WeatherCacheTest` (`forRides_aTimedGroup_startsWhereTheDetailStartsIt`),
`DeviceRoutesResourceTest`, `PublicationQueryCountTest` (le fuseau de la prochaine étape sur la
carte d'un voyage), `NotificationItem.test.tsx`, `RideWeatherSummaryLine.test.tsx`,
`ride_weather_summary_line_test.dart`, `notifications_page_test.dart`. Arbitré à la relecture : la
**grille** du calendrier reste celle du lecteur sur les deux clients, journées entières comprises
(plan §7 : une grille ne porte qu'un fuseau) — seule la date iCal d'une journée entière suit le
fuseau de l'étape (`calendar_month_test.dart`).

**Rattrapage du §8.3 mesuré le 7 octobre 2026, inutile** : en production comme en staging (V66,
`8fa64c44`), aucun `team_entities.timezone` ni `ride_groups.start_at` nul, et aucune sortie ni étape
à venir n'a de lieu de départ ou de parcours hors de la France métropolitaine (197 sorties et 18
étapes en production) : la requête en commentaire à la fin de `V64__event_timezones.sql` ne trouve
rien à ré-résoudre. Le rattrapage Java n'a pas été écrit.

**Lot 5 (version N+1) livré le 7 octobre 2026, contrat `11.0.0`** (majeure : l'ancien format de
requête est refusé). `V67__event_timezones_not_null.sql` refait le remplissage SQL de V64 (filet de
sécurité, zéro ligne attendue) puis pose `NOT NULL` sur `team_entities.timezone` et
`ride_groups.start_at` ; `EventTimezoneBackfill` et tous les replis disparaissent (`TeamEntity.zone()`
sans l'équipe, `EventTimezoneResolver.startAt` et `applyGroupStarts` retirés : chaque lecteur prend
`RideGroup.startAt`, que la météo SQL lit sans `coalesce`). `EventDateTime.parse` n'accepte plus
qu'une heure murale (`ISO_LOCAL_DATE_TIME`) : un instant avec `Z` ou un offset est un 400. Retirés :
les surcharges `Instant` de `RideRequest`, `TripRequest`, `PostRequest` et du builder de
`StageRequest`, les constructeurs de compatibilité de `TeamRequest` et `CalendarEventDto` (les tests
passent par `WallTimes.wall`). Le départ d'un groupe s'écrit au moment où la requête le donne
(`EventTimezoneResolver.setStart`, dans `RideService.setProperties`) ; l'heure propre d'un groupe se
relit depuis `startAt` (`EventTimezoneResolver.ownTime` : nulle quand le groupe part avec la sortie)
pour `RideGroupDto.time`, `RideGroupSummaryDto.time` et l'export RGPD (qui gagne `startAt`) ; un
changement de fuseau d'équipe garde l'heure propre de chaque groupe d'une sortie à venir.
**Écart au plan** : `ride_groups.time` n'est **pas** supprimée par ce lot. La version précédente la
mappe encore pendant la minute de bascule start-first (la supprimer ferait échouer chacune de ses
requêtes sur `ride_groups`) et après un retour arrière : elle est écrite (`RideGroup.legacyTime`) et
jamais lue, jusqu'au lot 6. Conséquence acceptée : un groupe dont l'heure saisie égale le départ de
la sortie se relit « part avec la sortie », et suit donc la sortie si son heure change ensuite (le
test de migration biketeam le dit). Tests (lancés le 7 octobre 2026, suite backend verte) : `EventDateTimeTest` (Z, offset et
`[Europe/Paris]` refusés, JSON en `InvalidFormatException`), `RideTimezoneTest`
(`anInstantWithZ_is400`, `anInstantWithAnOffset_is400`), `EventTimezoneResolverTest` (`setStart`,
`ownTime`, aller-retour), `PublicationEndCalculatorTest`, `WeatherCacheTest`, `WeatherPlannerTest`,
`TeamTimezoneChangeTest`, `BiketeamLiveMigrationTest` ; supprimés : `EventTimezoneBackfillTest` et
les tests des replis (groupe sans `start_at`, entité sans fuseau).

**Lot 5 vérifié en production et en staging le 7 octobre 2026** (`5fb6003e`, `/api/version`
`11.0.0`, V67 appliquée : les deux colonnes `NOT NULL`, aucune erreur au démarrage).

**Lot 6 livré le 7 octobre 2026** (sans changement de contrat ni migration) : `RideGroup.legacyTime`
retiré, Hibernate ne lit ni n'écrit plus `ride_groups.time` ; `EventTimezoneResolver.setStart` ne
pose plus que `startAt`, et `TeamTimezoneChange.rewriteRide` ne touche plus aux groupes d'une sortie
passée. La colonne reste en base, nullable et ignorée : un retour au lot 5 la retrouve (il ne la
lit pas non plus). Sa suppression est le lot 7, dans un déploiement suivant.

**Reste du lot 4 livré le 7 octobre 2026** (sans changement de contrat : l'export RGPD n'est pas
au contrat) : `notifications/inbox.json` porte `subjectTimezone` à côté de `subjectDateTime`
(`NotificationExport.InboxEntry`), nul pour une entrée antérieure à `V66`, comme dans la boîte de
réception. Test : `UserExportBuilderTest.build_shouldIncludeTheNotificationInboxWithItsDeliveries`.

**Lot 7 livré le 7 octobre 2026** (sans changement de contrat) : `V68__drop_ride_groups_time.sql`
supprime `ride_groups.time`, déployé seulement après le lot 6 — la version en service ne mappait
plus la colonne. Le départ d'un groupe n'existe plus que dans `ride_groups.start_at`.

À ne pas défaire :

- **Un seul départ d'un groupe** : `RideGroup.startAt` (`NOT NULL` depuis V67), écrit par
  `EventTimezoneResolver.setStart`, lu par la météo, les appareils, la fin stockée et le détail —
  jamais un fuseau tiré du point de départ ni un repli UTC, sans quoi la fin, la météo et l'heure
  affichée divergent. L'heure d'un groupe se relit de `startAt` (`ownTime`) ; `time` n'existe plus (V68).
- **Une requête ne porte que des heures murales** : `EventDateTime` refuse `Z` et les offsets
  (400) ; le client ne décide jamais du fuseau d'un rendez-vous.
- **`X-WR-TIMEZONE` seulement sur un flux d'équipe ou un ICS unitaire**, jamais sur le flux
  personnel, qui mêle des équipes de fuseaux différents.
- **`subject_timezone` nul se lit à Paris dans les textes du serveur** (toutes les équipes l'étaient
  avant `V66`), dans le fuseau de l'équipe pour un webhook, dans celui du lecteur côté client ; ne
  pas le rattraper ni lui donner de défaut (sûreté du déploiement start-first).
- **`ZoneLabels` est la troisième copie de la table des villes**, après `zoneLabel.ts` et
  `zone_label.dart` : les trois restent en phase.
- **La ligne météo d'un voyage se lit dans le fuseau de sa prochaine étape**
  (`RideWeatherSummaryDto.timezone`), pas dans `TripDto.timezone`.
- **La grille du calendrier est dans le fuseau du lecteur**, journées entières comprises, sur le
  web comme sur mobile ; la date de l'étape dans son propre fuseau ne vaut que pour iCal.
- **Le fuseau stocké est un fuseau de saisie, pas un cache** : figé à l'enregistrement de l'entité,
  recalculé seulement par un nouvel enregistrement (ou un changement de fuseau d'équipe, §9) ;
  jamais par effet de bord — un GPX remplacé, un lieu modifié ne déplacent ni fuseau ni départ
  (`PublicationEndStoredTest#replacingARoutesTrack_movesTheEnd_butNeitherTheZoneNorTheStart`).
- **Le backend est la seule autorité du fuseau** : les clients envoient des heures murales et
  n'en calculent aucun ; `…/timezone` ne sert qu'à étiqueter un champ.

## OPS — Exploitation, déploiement, recette du backend

- `OPS-11` **`BACKUP_KEEP` retiré de `.env.example`** (2026-09-30) — le modèle de
  `/root/pedalons-backup.env` décrivait une variable que rien ne lit : la rétention est le second
  argument de `scripts/backup-prune.sh` (30 par défaut), sur l'hôte de sauvegarde, comme le dit
  [`OPERATIONS.md`](OPERATIONS.md). Pas de test : `grep -rn BACKUP_KEEP` ne trouve plus que ce
  ledger.
- `OPS-12` **Commentaire du cache gpx2web corrigé** (2026-09-30, scindé de `OPS-10`) —
  `.env.example` disait encore que gpx2web écrit les tuiles directement à leur chemin final ; depuis
  gpx2web 1.5.1 les tuiles de carte sont écrites puis renommées. Le commentaire le dit, et garde
  l'interdiction de partager `DATA_CACHE_PATH` entre environnements tant que les tuiles d'élévation
  ne sont pas revues (`OPS-10`, toujours ouvert) : ne pas la lever avant. Pas de test (commentaire).
- `OPS-13` **Sauvegardes chiffrées au repos** (2026-09-29, relevé avec `LEGAL-12`) — les 30 copies
  nocturnes étaient en clair sur l'hôte de sauvegarde, au domicile du responsable, `ENCRYPTION_KEY`
  comprise dans le même lot que la base : un vol du matériel était une violation à notifier à
  chaque membre (art. 34). Deux couches, retenues ensemble :
  - **à la source** : `scripts/backup.sh` chiffre `postgres.dump.age` et `secrets.tar.gz.age` en
    flux avec `age` vers une clé publique (`BACKUP_AGE_RECIPIENT`, obligatoire : sans elle, pas de
    sauvegarde plutôt qu'une sauvegarde en clair) ; la clé privée est hors ligne et
    `scripts/restore.sh` l'exige (`BACKUP_AGE_IDENTITY`). Le gpg symétrique optionnel, jamais
    activé en production, est retiré. Pas de compatibilité avec les anciennes copies ;
  - **sur l'hôte** : `<backup-root>` est le point de montage d'un conteneur LUKS2 (fichier sur le
    SSD, déverrouillé à la main par SSH après redémarrage, jamais par TPM ni fichier de clé local),
    qui protège `minio/`. Le point de montage sous-jacent est `chattr +i` : conteneur fermé, les
    sauvegardes échouent au lieu d'écrire en clair. Les copies en clair ont été recopiées
    (`rsync -aH`), supprimées, et le SSD trimé.

  `minio/` n'est **pas** chiffré à la source : ça casserait l'incrémental `--link-dest`, c'est le
  rôle de LUKS — ne pas « compléter » le chiffrement age en y passant MinIO. §6 et §9 de la
  politique réécrits, ainsi que la phrase du runbook qui prétendait que la production ne peut pas
  supprimer son historique (elle le peut : `SEC-16`). Pas de rotation des secrets déjà exposés :
  `OPS-18`. Pas de test automatisé (scripts d'exploitation) : vérifié à la main le 29 septembre
  2026 — copie de la production écrite dans le volume chiffré, taille inchangée (liens durs
  conservés).
- `OPS-6` **Journal d'accès de l'hôte masqué et borné à 14 jours** (2026-09-29) — le Caddy de
  l'hôte de production journalise `pedalons.fr` (redirection), `www.pedalons.fr` (l'application)
  et les deux domaines de staging, par le snippet `pedalons_access_log` d'
  [`OPERATIONS.md`](OPERATIONS.md#access-logs) : `t`, `token`, `code`, `state` → `REDACTED`,
  coordonnées supprimées, **et `resp_headers>Location` supprimé** — sans lui, la ligne d'une
  redirection gardait la query brute dans l'en-tête. Un fichier par pile
  (`pedalons-access.log`, `pedalons-staging-access.log`), rotation par
  `/etc/logrotate.d/caddy-access`. Vérifié par `curl …?lat=1&t=x` sur les trois domaines :
  `t=REDACTED`, pas de `lat`, pas de `Location`. Sauvegarde de l'ancienne config :
  `/etc/caddy/Caddyfile.bak-20260929`. Les jetons dans le **chemin** restent en clair : `API-45`.
  Ne pas retirer la ligne `Location`, et refaire le `chown caddy:caddy` des fichiers après tout
  `caddy validate` lancé en root. Pas de test (configuration hors dépôt).
- `OPS-7` **Journal d'accès Traefik coupé** (2026-09-29, audit de février I13) — il n'était pas
  persisté (pas de volume : il mourait avec le conteneur) et Traefik ne sait pas masquer un
  paramètre de requête. `docker-compose.yml` passe `--accesslog=false` : le journal du Caddy de
  l'hôte est le seul, et c'est lui que la politique décrit (`LEGAL-10`, application sur l'hôte :
  `OPS-6`). Ne pas le rallumer sans filtre ni rotation : il redoublerait, en clair et sans borne,
  ce que la politique promet de masquer. Pas de test (configuration).
- `OPS-20` **Le backend attend postgres et MinIO au démarrage** (2026-09-29) — le premier
  déploiement de `AUD-7` sur le staging a été annulé par Swarm : la limite mémoire changeait la spec
  de postgres et de minio, que Swarm arrête avant de les relancer (stop-first), et le nouveau backend,
  démarré au même moment, a échoué dans Flyway (`UnknownHostException: postgres`, exit 1). Flyway a
  maintenant `connect-retries=15` (espacement plafonné à 5 s, environ une minute) et
  `S3StorageService.init` retente le contrôle du bucket 12 fois toutes les 5 s sur une
  `SdkClientException`. Les deux attentes restent bien en deçà des 180 s du `start_period`. Le premier
  déploiement d'une stack ne voit donc plus de backend en échec. Ne pas retirer ces retries : Swarm
  ignore `depends_on`. Pas de test automatisé (le cas demande un redéploiement Swarm).
- `OPS-22` **Monitoring mis en service sur l'hôte** (2026-09-30) — la stack `pedalons-monitoring`
  (`AUD-11`, `AUD-12`, `AUD-13`) tourne en prod, dans l'ordre de
  [`OPERATIONS.md`](OPERATIONS.md#setting-it-up) : pare-feu réinstallé (3300 et 2020 en `DROP` sur
  l'interface publique, v4 et v6, et en timeout vus de l'extérieur — en IPv4 seulement : en IPv6, 3300 répondait encore, voir `SEC-29`), `metrics { per_host }` et site
  `:2020` dans le Caddyfile, check Healthchecks du `Watchdog` au vert, relais d'alertes Scaleway TEM
  — **le même que l'application**, contrairement au conseil d'`OPERATIONS.md` : une panne de TEM
  tairait les alertes qui la signalent (le `Watchdog`, qui passe par Healthchecks, n'en dépend
  pas ; à changer : `OPS-23`) —, Gatus sur l'hôte de sauvegarde. Recetté ce qui ne
  l'avait été qu'hors Swarm : un backend découvert par environnement (label `env`), cAdvisor avec
  les deux labels Swarm sur les quatre stacks, `agroal_awaiting_count` et
  `jvm_gc_live_data_size_bytes` des deux backends, journaux JSON dans Loki (`level`, `job="caddy"`),
  courriel d'alerte reçu (`amtool alert add`). La mise en service a corrigé quatre choses : Grafana
  13 tient ~235 Mo au repos (`ContainerNearMemoryLimit` dès le démarrage à 256M) mais a été
  tué par l'OOM killer à 512M (`anon-rss` 490 Mo) en calculant quelques gros tableaux de bord à la
  fois : la limite passe à 1G ; `deploy.sh --monitoring` refuse un `ALERT_SMTP_SMARTHOST` sans
  port, qu'Alertmanager rejette et que Swarm relançait en boucle ; le panneau « Part de 5xx »
  affiche 0 % au lieu de « No data » quand un site n'a aucune erreur ; et surtout la nouvelle alerte
  **`BackendMissing`** — la recette prévue (`scale pedalons-staging_backend=0` → `TargetDown`) ne
  pouvait pas marcher : la découverte Swarm ne garde que les tâches en cours, si bien qu'un backend
  sans tâche n'est pas une cible `down` mais plus de cible du tout. `BackendMissing` (un
  environnement scrapé dans les dernières 24 h sans tâche backend depuis 5 min) a été déclenchée
  pour de vrai sur le staging, courriel reçu. Ne pas la retirer au profit de `TargetDown`, qui ne
  voit pas ce cas ; après un démontage volontaire, la mettre en silence (elle se résout seule 24 h
  après). Le tableau de bord « Quarkus Micrometer Prometheus registry » du Dev Service LGTM est
  provisionné à côté du nôtre, copié tel quel du dépôt Quarkus : le recopier pour le mettre à jour,
  ne pas le modifier. Test : `promtool test rules` (`services/monitoring/prometheus/tests/pedalons.test.yml`).
- `OPS-24` **`next` et `Referer` masqués dans le journal de Caddy** (2026-09-30) — un lien d'export
  ouvert sans session renvoie vers `/login?next=/api/export/download?token=…` : le jeton, dans la
  *valeur* de `next`, échappait à `replace token`, et les ressources de la page de connexion
  repartaient avec l'URL entière en `Referer` (`API-45`). Le Caddyfile de l'hôte a reçu les deux
  lignes du snippet `pedalons_access_log` d'[`OPERATIONS.md`](OPERATIONS.md#access-logs),
  `replace next REDACTED` et `request>headers>Referer delete`, puis `caddy validate`, `chown
  caddy:caddy` des fichiers de journal et rechargement ; vérifié par le propriétaire avec
  `curl …/login?next=/x?token=abc -H 'Referer: …?token=abc'`, dont la ligne ne porte plus le
  jeton. Le snippet sert la prod et le staging. Pas de test automatisé (configuration de l'hôte,
  hors dépôt) : ne pas retirer ces lignes, ni ajouter un paramètre porteur de jeton sans son
  `replace`.
- `OPS-10` **Cache gpx2web revu : partageable entre backends** (2026-09-30) — lu dans gpx2web
  1.5.2 (la version du dépôt) : `HttpTileFetcher` (tuiles d'élévation Mapterhorn) et
  `TileMapProducer.downloadTile` (tuiles de carte) téléchargent chacun dans un fichier temporaire
  **unique** du même répertoire (`Files.createTempFile`), ne le gardent que sur un 2xx et le
  renomment en place (`ATOMIC_MOVE`, `REPLACE_EXISTING`) ; une tuile en cache illisible est effacée
  et retéléchargée. Deux backends sur le même répertoire ne voient donc jamais de fichier partiel,
  et le verrou interne à la JVM (`TileLruCache`, `synchronized`) n'évite qu'un double
  téléchargement. Deux backends d'un même environnement partagent d'ailleurs déjà le répertoire
  pendant un déploiement start-first. L'interdiction de `.env.example` et d'`OPERATIONS.md` est
  levée ; **le cache reste par environnement**, partager entre environnements serait un choix
  d'exploitation, pas fait. Condition à garder : un seul système de fichiers (le renommage n'est
  atomique que là), et ne pas redescendre sous gpx2web 1.5.2. Pas de test (revue de code).
- `OPS-15` **Restaurer MinIO sous une base plus récente : la marche à suivre écrite** (2026-09-30) —
  la section « Restoring » d'[`OPERATIONS.md`](OPERATIONS.md#restoring) dit qu'un volume MinIO
  plus ancien que la base (une copie antérieure à la fin du rattrapage `API-43`) ramène des photos
  avec leur EXIF que rien ne revisitera, et donne l'`UPDATE assets SET metadata_pending = true` qui
  les remet dans le rattrapage. Précisé à l'écriture : **pas après une restauration ordinaire** —
  `restore.sh` prend base et objets dans le même instantané, les drapeaux concordent, et chaque
  passe est un réencodage avec perte. Les GPX se réparent seuls (le marqueur de
  `GpxSanitizationBackfill` vit dans le bucket). Pas de test (documentation).
- `OPS-16` **imgproxy : copyright retiré, limite de résolution réelle** (2026-09-30) —
  `docker-compose.yml` passe `IMGPROXY_KEEP_COPYRIGHT: "false"` (le défaut `true` laissait
  `Copyright` et `Artist` dans les images servies des originaux pas encore rattrapés) et
  `IMGPROXY_MAX_SRC_RESOLUTION` de `"50000000"` à `"50"`. L'unité est bien le **mégapixel** en v4,
  vérifié sur `imgproxy:v4.0.14` : `0.01` refuse un PNG de 200 × 200 (422), `1` le sert (200). La
  valeur précédente ne bornait donc rien contre une image géante ; 50 Mpx est ce que le
  dimensionnement mémoire (`IMGPROXY_WORKERS`, 1536M) supposait déjà. Ne pas remettre une valeur
  en pixels. Pas de test automatisé (configuration) ; prend effet au prochain `deploy.sh`.
- `OPS-17` **Les originaux orphelins de `tmp/reencode/` expirent en un jour** (2026-09-30) — au
  lieu d'un `mc ilm rule add` à passer à la main sur chaque environnement,
  `S3StorageService.init` pose la règle au démarrage, juste après le contrôle du bucket :
  expiration à 1 jour sur `REENCODE_PREFIX` (règle `expire-reencode-originals`), si bien que
  production, staging, pile locale et pile e2e l'ont sans geste. Elle **remplace** la configuration
  de cycle de vie du bucket, qui n'en porte pas d'autre : une règle ajoutée un jour à la main
  serait effacée au redémarrage suivant — l'ajouter dans ce code. Un échec est journalisé en WARN,
  pas fatal. Vérifié contre le MinIO local (`pgsty/minio`) avec le SDK du backend : règle acceptée,
  relue, appel répété idempotent ; puis sur la pile e2e, où le backend reconstruit l'a posée au
  démarrage (`mc ilm rule ls`). Pas de test automatisé.

- `OPS-25` **Un health check lent ne coupe plus tout `/api`** (2026-09-30) — traefik retire un
  serveur dès son **premier** check en échec, avec un délai par défaut de 5 s ; avec une seule
  réplique, une réponse lente de `/q/health/ready` sous charge faisait répondre `503 no available
  server` à tout `/api` jusqu'au check réussi suivant (pile e2e : `WRN Health check failed …
  context deadline exceeded serviceName=quarkus`, trois fois dans une passe ; même configuration en
  production, labels partagés). `docker-compose.yml` pose désormais
  `loadbalancer.healthcheck.timeout=10s` sur le backend et le frontend. **Invariant à garder** :
  intervalle + timeout (3 s + 10 s) sous le délai où la tâche se dit non prête avant de drainer,
  sinon un check lent en vol au SIGTERM laisse router vers une tâche qui s'arrête —
  `quarkus.shutdown.delay` passe à 15 s (`stop_grace_period` 40 s couvre 15 + 20), le drain de
  `server.js` à 15 s (`stop_grace_period` 25 s). traefik n'a pas de seuil d'échecs : ne pas
  raccourcir le timeout pour « détecter plus vite », une tâche qui draine répond DOWN tout de suite.
  Vérifié : `docker compose config`. Pas de test automatisé ; à valider par la passe e2e suivante
  et au prochain déploiement (`scripts/deploy.sh`, sans 5xx pendant le roulement).

- `OPS-14` **Recette des deux rattrapages de métadonnées** (2026-10-06) — en production :
  `SELECT count(*) FROM assets WHERE metadata_pending` vaut 0 ; le marqueur
  `maintenance/api-49-gpx-sanitized` est dans le bucket depuis le 1er octobre 2026 (04:15 UTC),
  à côté de celui d'`api-44` ; dernier passage `GPX sanitization backfill: 28 file sets checked, 0
  rewritten, 0 failed`. Aucun `left as is`, `cannot be re-encoded` ni `imgproxy cannot decode`
  dans Loki depuis le 28 septembre : aucune pièce jointe ni image à supprimer ou convertir à la
  main. Varnish a redémarré au déploiement du 6 octobre, il porte le `pass` des réencodages. La
  phrase du §1 sur les photos antérieures (`API-43`, `API-44`) est donc vraie. Pas de test
  automatisé (recette sur l'hôte).
- `OPS-28` **Rafraîchissement quotidien des données des relecteurs des stores installé**
  (2026-10-06, scindé de `MOB-41`) — `store-demo.env`, `store-demo-accounts.json` (0600) et la
  ligne de crontab de `pedalons` étaient en place depuis le 3 octobre, mais **le cron n'a jamais
  tourné** : `~/logs` n'existait pas, la redirection `>> ~/logs/store-demo.log` échouait et le
  shell ne lançait pas le script. Dossier créé, et la ligne d'[`OPERATIONS.md`](OPERATIONS.md#store-reviewers-demo-data)
  est désormais précédée du `mkdir`. Le premier lancement a ensuite échoué comme prévu par le
  runbook : `marketplace-tester@pedalons.fr` n'était plus membre de `vc-du-lac-d-annecy` (403 dans
  les journaux le matin même, cause inconnue — quitter un club ne laisse pas d'événement). Remis
  `MEMBER` par une insertion SQL dans `user_teams`, puis `seed.py --target prod --refresh` →
  `✔ refreshed` (une inscription de plus par club, fil de commentaires des deux sorties des
  Glières). Le check Healthchecks n'est pas créé : `OPS-30`. Pas de test automatisé.
- `OPS-26` **Recette de la promotion des sauvegardes** (2026-10-11, `SEC-32`) — vérifiée a
  posteriori sur dix nuits, sur l'hôte de sauvegarde : une ligne `promoting … (hard-linked against
  <veille>)` puis `promoted <stamp>` chaque nuit à 01:30 UTC du 2 au 11 octobre, aucune `ERROR` ; le
  plancher de 20 h n'a rien bloqué à tort. Le snapshot du 11 est `root:<backup-user>`, répertoires
  `0750` et fichiers `0440` sans exception, `COMPLETE` au nom du snapshot. Hardlinks effectifs :
  1 189 fichiers sur 1 197 ont plus d'un lien (jusqu'à 14), les 8 autres sont des objets nouveaux
  ou les caches internes de MinIO ; chaque snapshot quotidien pèse 6 à 7 Mo en propre (26 Mo le 5,
  jour d'ajout de photos), 4,4 Go pour les 30. La purge de 04:30 retire chaque nuit le plus ancien
  et en garde 30. `restore.sh --list`, lancé en root depuis le checkout de la prod, liste les
  mêmes 30 snapshots (du 18 septembre au 11 octobre), sans `incoming/`. Non lu :
  `/var/log/backup/pedalons-backup.log` de la prod ; une promotion n'ayant lieu que sur un
  `COMPLETE` écrit en dernier par `backup.sh`, les dix promotions attestent les dix envois. Pas de
  test automatisé (recette sur l'hôte).
- `OPS-27` **Check Healthchecks de la promotion des sauvegardes** (2026-10-11, `SEC-32`) —
  `backup-promote.sh` savait pinguer, mais `/etc/default/pedalons-backup-promote` n'existait pas :
  une nuit sans promotion, ou une promotion refusée, ne prévenait personne, le check de `backup.sh`
  restant vert. Check quotidien créé (période 1 jour, grâce 2 h), son URL mise dans ce fichier sur
  l'hôte de sauvegarde (`root:root`, `0600`), ping manuel depuis l'hôte → `OK`, check au vert ; le
  script relancé à la main avec ce fichier sort en 0 sans ping (rien à promouvoir). La promotion
  tourne vers 01:30 UTC ; le premier ping d'une vraie promotion est celui du 12 octobre. Pas de
  test automatisé (recette sur l'hôte).

---

## NOTIF — Notifications

- `NOTIF-10` **Une modification de sortie faite pendant l'envoi du `RIDE_UPDATED` précédent est de nouveau annoncée** (2026-10-11, contrat inchangé, constat de la modélisation formelle TLA+/Lean). Avant, `claimNextPending` gardait la clé de dédoublonnage du `RIDE_UPDATED` réservé jusqu'au commit de `fanOut`. Une seconde modification faite pendant ce temps voyait son `insert … on conflict do nothing` ne rien faire, et le fan-out, qui avait lu l'ancienne valeur, l'annonçait. Variante : la modification se fusionnait dans l'événement encore PENDING, mais le dispatcher le réservait et lisait la sortie avant qu'elle soit commitée. Dans les deux cas, les inscrits gardaient une mauvaise heure ou un mauvais lieu, sans correction. Désormais, pour les types qui coalescent (`NotificationType.coalescesWhilePending()`, qui fait foi : `RIDE_UPDATED`, `CONTENT_REPORTED`), la réservation rend la clé dans sa propre transaction : une modification ultérieure met en file son propre événement, avec l'état d'avant cette modification. Une fusion dans un événement PENDING le verrouille jusqu'au commit de la modification (`NotificationEventRepository.lockPending`, `for update`), donc le `skip locked` du dispatcher ne peut plus le prendre avant. Si plus aucune ligne PENDING ne porte la clé, c'est qu'une réservation l'a rendue entre-temps, et la publication réinsère (3 essais au plus, puis un warn, le temps d'un déploiement roulant). `releaseDedupKey` est devenu idempotent. Test : `RideUpdatedFoldIntoClaimedEventRaceTest`. **À ne pas défaire** : rendre la clé d'un type coalescent au moment de la réservation, pas au commit du fan-out, et verrouiller la ligne PENDING lors d'une fusion. Chacun seul laisse l'autre fenêtre ouverte (vérifié sur le modèle). Limite connue : un événement coalescent remis en file après un échec garde sa clé rendue, et une nouvelle modification peut alors donner deux notifications, qui finissent toutes deux sur le bon état. C'est un doublon sur un chemin d'échec, pas une perte. Même chose sur le chemin normal quand la seconde modification est validée entre la réservation et la lecture de la sortie : deux notifications annoncent le même état final. Les deux sont préférés à une perte.

### `NOTIF-9` Notifications — livrées, en production depuis le 21 septembre 2026

Repris le 18 septembre 2026 par
[`plans/archive/2026-09-18-notifications.md`](plans/archive/2026-09-18-notifications.md), où le push est devenu un
canal d'un pipeline commun (boîte de réception, e-mail, push). Les phases 1 à 5 (dont le rappel J-1)
sont en production depuis le 21 septembre 2026, le Web Push depuis le 29. Ce qui reste est
`NOTIF-1` à `NOTIF-4`.

Le ledger du chantier (`plans/2026-09-18-notifications-ledger.md`, phase par phase avec ses
recettes) a été rapatrié ici et supprimé le 29 septembre 2026 ; il reste dans l'historique git. Les
invariants qu'il portait sont déjà dans le plan de conception, dans `mobile/CLAUDE.md` et dans les
commentaires du code (`V39__push_devices.sql`, `PushNotificationSender`, `FcmClient`,
`NotificationPublisher.silently`) ; ce qui n'était écrit que là suit.

| Phase | Livré | Contrat, migration |
|---|---|---|
| 1 — socle backend | Pipeline évènement → notification → livraison, canaux in-app et e-mail, six endpoints | 3.5.0, V37, V38 |
| 2 — web | Cloche, page Notifications, matrice de préférences, ancre des e-mails | — |
| 3 — mobile | Cloche, écran, matrice, deeplink `/notifications` | — |
| 4 — push serveur | `push_devices`, `FcmClient` (FCM HTTP v1, sans dépendance nouvelle), purge des jetons morts | 3.6.0, V39 |
| 4 bis — push mobile | `firebase_messaging` derrière `PushGateway`, autorisation depuis la boîte, tap qui ouvre `data.path` | — |
| 5 | Rappel J-1, modification retardée, inscription, commentaire, invitation, équipes coupées, résumé quotidien, webhook d'équipe | 3.8.0, V40 |
| Web Push | Site installable, push navigateur par le même FCM (plateforme `WEB`) | 5.4.0 |

Deux types sont venus ensuite, hors de ce chantier : `RIDE_GROUP_REMOVED` et `CONTENT_REPORTED`
(`NotificationType` en compte 13).

**Pièges iOS, à ne pas rejouer** (recette sur iPhone du 21 septembre 2026) :

- **Tap perdu sur application tuée.** Un `content-available: 1` réveillait parfois l'app tuée dès
  l'arrivée du push ; `firebase_messaging` retenait alors le message comme « initial »,
  `getInitialMessage()` — appelé à ce réveil — répondait `null`, et au tap le plugin n'émettait pas
  `onMessageOpenedApp`. Correctif double : `FirebasePushGateway` refait un `getInitialMessage()` à
  chaque retour au premier plan sur iOS, et le serveur n'envoie plus `content-available`
  (`UIBackgroundModes: remote-notification` est parti avec lui). Le push s'affiche sans mode
  d'arrière-plan.
- **Ne pas poser `UNUserNotificationCenter.delegate = self` dans `AppDelegate`** : cela a coupé la
  réception des pushes sur l'iPhone. Agrandir le tampon du canal était l'autre fausse piste (le
  message n'atteignait pas Dart du tout).
- **Une build *debug* iOS ne se relance pas** depuis l'écran d'accueil sans débogueur : le cas
  « application tuée » se recette sur une build *release* signée développement.

**Autres décisions de mise en œuvre** :

- `register` est un upsert natif `ON CONFLICT (token) DO UPDATE` : deux `POST /api/push-devices`
  concurrents au lancement (ouverture de session et `onTokenRefresh`) faisaient échouer l'un des
  deux sur le verrou optimiste.
- `google-services.json` et `GoogleService-Info.plist` sont **commités** : identifiants d'app
  publics et clé API restreinte au bundle, les tenir hors dépôt aurait cassé toute build faite
  ailleurs. Le compte de service FCM et la clé APNs `.p8` vivent hors dépôt, dans
  `~/Documents/pedalons/firebase/`.
- L'export RGPD contient les appareils push **sans le jeton** (c'est l'adresse de l'appareil).

**Préalables hors dépôt** :

- Projet Firebase `pedalons-9e595`, **Analytics et Gemini désactivés** : le push n'en a pas besoin,
  et Analytics aurait ouvert une déclaration de collecte de plus dans les deux formulaires de
  confidentialité.
- Clé APNs créée en **Sandbox & Production** — la portée ne se change plus après coup, et une clé
  Sandbox seule ne livre rien en TestFlight — et téléversée dans Firebase sur les deux lignes
  (développement et production).
- Activer une capacité sur l'App ID `fr.pedalons.mobile` **invalide le profil de provisionnement**.
  Le profil de développement a été réémis le 21 septembre 2026 et **expire le 21 septembre 2027** ;
  le profil de distribution est généré par fastlane à l'archivage (`-allowProvisioningUpdates`).

**Web Push** (fusionné dans `develop` le 28 septembre 2026, en production et testé depuis le
29 septembre) : le site s'installe comme une application et reçoit le push par le même FCM
(plateforme `WEB`).

La cloche de l'accueil, la section Notifications du profil et l'écran « Notifications » (non maquetté)
sont livrés depuis la phase 3 du même plan.

L'analyse d'origine, pour mémoire : le seul mécanisme qui ramène un membre sans qu'il ouvre l'app.
Trois déclencheurs : rappel J-1, annulation de sortie, réponse à un commentaire. Ce qui allongeait le
délai réel n'était pas le code : entitlement `aps-environment` et clé APNs `.p8` côté Apple,
`google-services.json` et permission runtime `POST_NOTIFICATIONS` côté Android 13+, mise à jour des
deux formulaires de confidentialité, et une nouvelle soumission aux deux stores. Voir
`mobile/store-metadata/data-safety.md`, qui est la source de vérité des déclarations. Deux pièges qui
cassent en production et pas en test : l'**idempotence** du rappel J-1 (sans marque « rappel
envoyé », un redémarrage renotifie tout le monde) et la purge des jetons périmés (retour
`UNREGISTERED` de FCM), sans quoi la table grossit indéfiniment.

---

## MOD — Modération et signalement

- `MOD-6` **Modération** — livrée le 24 septembre 2026 (V41,
  [spécification archivée](plans/archive/2026-09-24-signalement.md)) : signalement, blocage et
  filtre de publication exigés par la directive App Store 1.2. Quatre défauts mineurs y ont été
  notés, `MOD-1` à `MOD-4`.
- `MOD-1` **La file plateforme regroupe par (type, id, équipe)** (2026-09-30, **API 5.7.0**) — un
  membre signalé dans deux équipes devenait une seule carte, étiquetée avec la première équipe, et
  une seule décision closait les signalements des deux. `ModerationService` regroupe maintenant par
  `TargetKey(type, id, teamId)` ; seul un membre peut tomber dans deux cartes, une publication ou un
  commentaire n'ayant qu'une équipe. Une carte s'adresse par ce qu'elle expose déjà : `targetType`,
  `targetId` et `teamSlug`. `ModerationDecisionRequest` gagne un `teamSlug` **facultatif** (ajout,
  d'où le mineur) : sur `POST /api/admin/reports/resolve` il limite la décision aux signalements de
  cette équipe (équipe inconnue : 404) ; absent, la décision vaut pour toutes les équipes comme
  avant ; la file d'une équipe l'ignore, son chemin nomme déjà l'équipe. Le web
  (`ModerationQueue.tsx`) envoie toujours `teamSlug` et met l'équipe dans la clé de la carte ; le
  mobile n'a pas de file de modération, son client est seulement régénéré. Couvert par
  `ModerationResourceTest.platformQueue_aMemberReportedInTwoTeams_isTwoItems_decidedOneByOne`
  (deux cartes, rejeter celle de team2 laisse celle de team1 ouverte) et
  `platformResolve_withAnUnknownTeam_is404`. Ne pas rendre `teamSlug` obligatoire sans bump majeur,
  et ne pas retirer l'équipe de la clé de regroupement.
- `MOD-2` **Plus de signalements orphelins après suppression** (2026-09-30) — `REMOVE_CONTENT` sur
  une publication laissait `OPEN` les signalements de ses commentaires, qui pointaient alors vers un
  contenu supprimé. `ModerationService.remove` les clôt maintenant en `REMOVED`, dans la même
  transaction, par une seule requête (`ContentReportRepository.resolveOpenCommentsOf`, un `update`
  sur les commentaires de la publication), comme il le faisait déjà pour les réponses d'un
  commentaire retiré. La clôture ne regarde pas l'auteur du commentaire : la décision porte sur la
  publication, un organisateur qui la retire clôt aussi le signalement d'un de ses propres
  commentaires dessous. Si un admin plateforme restaure la publication, ces signalements restent
  clos. Couvert par `ModerationResourceTest.removeContent_ofAPublication_closesTheReportsOfItsComments`
  (un commentaire d'une autre publication garde son signalement ouvert).
- `MOD-3` **Seuil de masquage tenu sous concurrence** (2026-09-30) — le nombre de signalants était
  compté dans la transaction de chaque signalement : deux signalements validés au même instant
  pouvaient chacun voir 2 signalants, et le contenu n'était pas masqué avant un 4e.
  `ReportService.hideIfReportedEnough` verrouille maintenant la ligne de la publication ou du
  commentaire signalé avant de compter (`ContentReportRepository.lockReported`,
  `refresh(…, PESSIMISTIC_WRITE)`, soit un `SELECT … FOR UPDATE`) : le second signalement attend le
  commit du premier, et son comptage, une nouvelle instruction en `READ COMMITTED`, voit alors le
  signalement de l'autre. Un `refresh` et non un `lock()` : la ligne a pu être masquée par la
  transaction qui tenait le verrou, et `lock()` échouerait sur la vérification de version là où le
  `refresh` relit cet état. Un signalement de membre ne verrouille rien (rien n'est masqué). Pas de
  test de concurrence, qui serait instable : le chemin séquentiel reste couvert par
  `ModerationResourceTest.thirdDistinctReporter_hidesTheContentFromMembers_butNotFromModerators` et
  `thirdDistinctReporter_hidesACommentFromMembers`, qui passent par le verrou ; l'exclusion
  elle-même repose sur la sémantique de PostgreSQL. Garder le verrou **avant** le comptage.
- `MOD-4` **Aucun signalant d'une rafale n'est notifié de son signalement** (2026-09-30) —
  `ContentReported` fusionne tant qu'il attend la diffusion (clé : équipe + cible), et le résolveur
  ne lisait que le premier signalement : seul son auteur était exclu, et un organisateur qui avait
  signalé en second recevait la notification de son propre signalement.
  `NotificationRecipientResolver.resolveReport` exclut maintenant tous les auteurs d'un signalement
  ouvert sur cette cible dans cette équipe (`ContentReportRepository.findOpenReporterIds`, une
  requête quelle que soit la rafale), en plus du premier. Un signalant d'une rafale précédente encore
  ouverte est exclu aussi : il connaît déjà le contenu. Couvert par
  `ModerationNotificationTest.aBurstOfReports_notifiesNoneOfItsReporters_notOnlyTheFirst` (un
  extérieur signale, puis l'organisateur : une notification, à l'admin et à l'admin plateforme,
  aucune aux deux signalants). Ne pas revenir à l'exclusion du seul `report.getReporter()`.

---

## ISSUE — Signaler un problème → issues GitHub

- `ISSUE-8` **`FeedbackGithubWorker` réserve la ligne avant d'appeler GitHub** (2026-10-11, contrat inchangé, migration `V69__feedback_github_lease.sql`, constat de la modélisation formelle TLA+/Lean). Avant, `ConcurrentExecution.SKIP` ne protégeait qu'une JVM. Le worker relisait PENDING dans une transaction courte, appelait `createIssue` hors transaction et n'écrivait CREATED qu'après. Pendant la minute d'un déploiement start-first, le second backend relisait donc la ligne en PENDING et ouvrait une seconde issue, celle du dernier écrivain gagnant et l'autre restant orpheline (même course sur `reopen` et sur le résumé de 07:00). Désormais chaque ligne (`error_signatures`, `feedback_reports`) est louée avant ses appels GitHub, comme dans `WeatherFetchWorker` : colonne nullable `github_claimed_until`, `claim` est un update conditionnel (libre ou bail expiré), `release` est en `finally` et ne libère que son propre bail, et le bail dure 5 min. La publication d'une signature ou d'un signalement, la réouverture d'une régression et le résumé quotidien passent tous sous ce bail, puis relisent la ligne. Couvert par `FeedbackGithubWorkerDoublePublishRaceTest` (deux ticks qui se chevauchent : un seul `createIssue`, pour une signature comme pour un signalement). **À ne pas défaire** : ne pas remplacer le bail par un statut PUBLISHING (l'ancienne release ne sait pas mapper la valeur et `reportError` y casse), ne pas tenir de transaction ni de `FOR UPDATE` pendant l'appel GitHub, et ne pas appeler GitHub pour une ligne sans avoir pris son bail. L'ancienne release ignore le bail : la course reste possible une dernière fois, pendant le déploiement qui livre ce correctif.

- `ISSUE-9` **Le worker n'écrase plus les compteurs qu'un `reportError` concurrent vient d'écrire** (2026-10-11, contrat inchangé, constat de la modélisation formelle TLA+/Lean). Avant, `ErrorSignature` n'avait ni `@Version` ni `@DynamicUpdate`, et chaque transaction du worker lisait la ligne par un simple `findById` : marque CREATED, essais, réouverture, résumé, `markClosed`. Son UPDATE de toutes les colonnes réécrivait donc `occurrence_count`, `last_seen_at`, `versions` et `regression_version` tels qu'il les avait lus, et perdait l'occurrence qu'un `reportError` (verrouillé `FOR UPDATE`) avait commitée entre-temps. `markClosed` pouvait en plus figer un `versions_at_close` sans cette version et rater la régression. Désormais `ErrorSignature` porte `@DynamicUpdate`, si bien que chaque écrivain n'écrit que les colonnes qu'il a changées. Toute écriture du worker passe aussi par `ErrorSignatureRepository.lock` (PESSIMISTIC_WRITE, le verrou que prend `lockOrCreate`), et `markClosed` verrouille la ligne avant de lire les occurrences. Couvert par `ErrorSignatureWorkerLostUpdateRaceTest`. **À ne pas défaire** : garder `@DynamicUpdate` sur `ErrorSignature` (deux écrivains se partagent la ligne), verrouiller avant toute lecture-modification-écriture du worker, ne pas remplacer ces protections par un `@Version` qui ferait seulement échouer le worker.

- `ISSUE-7` **Un bug se signale sans description (API 6.1.0)** (2026-09-29) —
  `FeedbackRequest.message` devient facultatif pour un `BUG` : qui tombe sur une erreur ne sait
  pas forcément ce qui s'est passé, et le contexte, l'erreur jointe et le journal parlent pour lui.
  Une `SUGGESTION` l'exige toujours (`FeedbackService.submit`, 400 `VALIDATION`) ; un message
  donné garde ses bornes 10–5000. Colonne `feedback_reports.message` nullable (V48). Sans message,
  l'issue est titrée par l'erreur (`TypeError: …`), à défaut par l'écran, et son corps dit « Pas de
  description du membre ». Web et app : le champ est marqué facultatif pour un bug, « Envoyer »
  s'active champ vide, un champ vide part en `null`. Couvert par
  `FeedbackResourceTest.feedback_bugWithoutMessage_isPublishedUnderItsError`,
  `…suggestionWithoutMessage_isRejected` et `feedback_sheet_test.dart` (« un bug part sans
  message, une suggestion non »).
- `ISSUE-6` **Signaler un problème → issues GitHub (API 4.6.0)** — en service en production
  (constaté le 29 septembre 2026). Suites possibles : `ISSUE-1` à `ISSUE-5`.

---

## MIG — Migration biketeam

- `MIG-15` **Un reset relancé après un échec de `setTargetTeam` reconnaît l'équipe qu'il vient de créer** (2026-10-11, contrat inchangé, constat de la modélisation formelle TLA+/Lean) — la mise de côté de l'ancienne équipe, la nouvelle équipe et sa ligne de correspondance `TEAM` sont validées dans une même transaction (`ensureLiveTargetTeam`), mais `target_team_id` est écrit ensuite dans une transaction à part (`BiketeamMigrationJobService.setTargetTeam`). Si cette écriture était perdue (SIGKILL d'un déploiement, coupure base, job perdu au profit de `recoverStuck`), l'essai suivant mettait de côté l'équipe tout juste créée. Il la renommait en `<slug>-reset-<jobTsid>`, déjà pris par la première, butait sur `uk_teams_domain_slug` à chaque essai et finissait en FAILED INTERNAL_ERROR. Pour une équipe renommée sur Pédalons, il la jetait et en créait une troisième. Désormais `BiketeamLiveMigrationWorker.prepareTarget` ne rejoue pas le reset quand une équipe **à la corbeille** du domaine porte déjà le suffixe de mise de côté de ce job (`setAsideByThisJob`, `TeamRepository.existsTrashedBySlugSuffixAndDomain` — une équipe mise de côté l'est toujours dans la transaction qui la renomme, si bien qu'une équipe vivante renommée à la main ne peut pas se faire passer pour elle) : l'équipe migrée est alors son résultat, et l'essai la reprend. Couvert par `BiketeamResetRetryAfterLostTargetRaceTest` (même slug et équipe renommée). **À ne pas défaire** : le suffixe `-reset-<jobTsid>` sert de marqueur durable du reset, donc `setAsideSlug` doit garder le tsid du job en entier. La mise de côté doit rester dans la transaction qui crée l'équipe qui lui succède et sa ligne `TEAM` : c'est ce qui garantit que l'équipe pointée par la correspondance est celle de ce job.

- `MIG-14` **Les tags de parcours biketeam sont importés** (2026-10-01, API 10.1.0 ; détaché de
  `MIG-6`, qui garde la ville et le pays ; plan archivé
  [`2026-10-01-tags.md`](plans/archive/2026-10-01-tags.md) §7, D21) — à l'import d'un parcours,
  `TagService.importTags` retrouve chaque libellé de `BtMap.tags` (trim, vides écartés) dans le
  vocabulaire `ROUTE` de l'équipe, sans tenir compte de la casse, ou le crée en `GRAY` avec la
  première graphie rencontrée, puis **remplace** les tags du parcours : un rejeu ne double ni tag ni
  liaison, et un tag retiré sur biketeam quitte le parcours (il reste au vocabulaire). Au-delà des
  bornes (D16) la migration n'échoue pas : un libellé de plus de 32 caractères est coupé (sur les
  points de code — jamais au milieu d'une paire de substitution), au-delà de 10 tags sur le
  parcours ou de 100 dans l'équipe les premiers sont gardés dans l'ordre de l'instantané, et
  l'avertissement `TAGS_TRUNCATED` le dit. `defaultSearchTags` n'est ni exporté ni importé (D8).
  Tests (verts le 1er octobre 2026) : `BiketeamLiveMigrationTest.routeTags_*` (fusion de casse,
  rejeu, coupe et troncature avec un libellé non BMP, équipe à 100 tags). **À ne pas défaire** :
  livré avant les bascules de production (D22) — aucun rattrapage n'est prévu pour une équipe
  basculée avant.

- `MIG-5` **Une équipe migrée ne se supprime plus** (2026-09-30, API `7.1.0`) — `DELETE
  /api/teams/{slug}` mettait à la corbeille une équipe basculée depuis biketeam, qui aurait alors
  redirigé ses anciennes adresses vers des 404. `TeamService.delete` refuse désormais toute équipe
  qu'une ligne `TEAM` de `biketeam_migration_map` désigne (`BiketeamMigrationMapRepository.isMigratedTeam`),
  en 400 `MIGRATED_TEAM`, **à tout le monde, admins de plateforme compris** (décision du
  30 septembre 2026). La seule issue est d'annuler la bascule sur biketeam : son reset met l'équipe
  à la corbeille lui-même (`BiketeamLiveMigrationWorker`), sans passer par `TeamService`. La garde
  est dans `delete(Team)`, donc elle couvre aussi l'effacement de compte, qui écartait déjà ces
  équipes (`SOLE_MIGRATED_TEAM_ADMIN`). Le web affiche le message du code dans son bandeau d'erreur
  ; le mobile ne supprime pas d'équipe mais a la traduction. Couvert par `TeamResourceTest`
  (`deleteTeam_migratedFromBiketeam_isRefusedToItsAdmin_andTheTeamStays`,
  `deleteTeam_migratedFromBiketeam_isRefusedToAPlatformAdminToo`), **écrits sans avoir été
  lancés**. Ne pas ajouter d'échappatoire pour un admin plateforme : c'est la bascule qu'il faut
  annuler, pas l'équipe qu'il faut supprimer.

- `MIG-13` **Une équipe migrée naît avec le planificateur d'itinéraire** (2026-09-29,
  `BiketeamMigrationService.createTargetTeam`) — `enableRoutePlanner` restait à `false` ; il est
  maintenant `true`, à côté de `addMemberAllowed` et `visibilityEditable` (déjà `true`). `joinable`
  garde sa règle : toute visibilité sauf `TEAM`. À la création seulement : un rejeu ne touche pas
  aux réglages Pédalons, et les équipes déjà migrées n'ont pas été rattrapées. Pas de changement de
  contrat. Couvert par `BiketeamLiveMigrationTest.firstRun_createsTheTeam_…` (`TeamFlags`).
- `MIG-12` **L'ancien import biketeam** a été supprimé le 2026-09-28 : seule la migration en direct
  reste ([plan](plans/2026-09-22-biketeam-live-migration.md)), en service en staging et dont la mise
  en production attend biketeam (§10 du plan, `MIG-1`) ; `biketeam_migration_map` sert encore au
  direct, et les lignes `USER`, `USER_TEAM`, `COMMENT`, `…_PARTICIPATION` qu'écrivait l'import n'existent
  plus en staging ni en prod (vérifié le 2026-09-29, bases reparties de zéro).
- `MIG-10` **Javadoc de `contentVisibility` corrigée** (2026-09-30, `BiketeamMigrationService`) —
  elle disait que rabattre le `PUBLIC_UNLISTED` de l'équipe sur ses contenus ne changerait rien ;
  elle dit maintenant que le fil de l'équipe se viderait, les listes limitées à l'équipe exigeant
  `te.visibility = 'PUBLIC'`, comme [`MIGRATE_BIKETEAM.md`](MIGRATE_BIKETEAM.md). Le code n'a pas
  changé : la visibilité d'un contenu vient de son propre `listed_in_feed`, jamais de celle de
  l'équipe — ne pas la rabattre. Pas de test (commentaire).
- `MIG-11` **Javadoc de `isPlaceholderLogo` corrigée** (2026-09-30, `BiketeamMigrationService`) —
  elle citait encore « 70 of the 187 exported teams », un décompte du dump de 2026-07 que l'import
  live n'a plus ; elle dit seulement que beaucoup d'équipes n'ont jamais remplacé l'image par
  défaut, comme [`MIGRATE_BIKETEAM.md`](MIGRATE_BIKETEAM.md). Pas de test (commentaire).

- `MIG-4` **Vignettes redessinées seulement si leur source change** (2026-09-30) — `updateRide` et
  `updateTrip` redessinaient les vignettes claire et sombre à chaque écriture, donc à chaque rejeu de
  la migration : son dernier coût. `ThumbnailService.rideInput`/`tripInput` décrivent ce dont elles
  sont tirées — les parcours dans l'ordre de dessin, chacun avec les ids de ses traces — et sont lus
  avant la modification ; `refreshRideThumbnails`/`refreshTripThumbnails` ne redessinent que si
  cette entrée a changé, ou si l'une des deux vignettes manque (un rendu raté la dernière fois est
  retenté). Les ids de traces suffisent à dire que la géométrie a changé : une trace n'est jamais
  modifiée en place, un nouveau GPX remplace les lignes (`RouteService.updateRoute`). La création
  dessine toujours. Couvert par `ThumbnailRefreshTest` (sortie et voyage : création, deux rendus ;
  mise à jour au même parcours, aucun ; changement de parcours, deux), où le rendu est remplacé par
  un PNG de 1×1 compté par Mockito. Ne pas comparer la `version` du parcours : le rejeu la fait
  monter (nom, visibilité) sans toucher au tracé.

---

## BRAND — Charte

- `BRAND-1` **Types d'annonce réalignés sur la charte** (2026-09-30) — `AdDetailPage.tsx` gardait
  sa propre table `adTypeColors` (SALE `primary`, RENTAL `grape`, WANTED `yellow`) ; son badge lit
  maintenant `TYPE_COLORS` de `badgeColors.ts` (SALE green, RENTAL indigo, WANTED orange, comme le
  §3.6 de [`BRANDING.md`](BRANDING.md), qui ne signale plus la divergence). Ne pas remettre de table
  locale dans une page : la couleur d'une énumération se lit dans `badgeColors.ts`, en attendant la
  source unique de `BRAND-2`. Pas de test : rien ne compare encore les couleurs (c'est `BRAND-2`) ;
  `pnpm typecheck` et `pnpm lint` passent.

- `BRAND-2` **Code couleur métier : source unique et générateur** (2026-09-30, contrat inchangé) —
  [`contracts/brand-colors.yaml`](../contracts/brand-colors.yaml) porte, pour chaque énumération du
  contrat, la famille de chaque valeur et le style de la série (`soft`, ou `filled` pour les seules
  catégories de col), plus les dégradés de repli en nuances Mantine. `pnpm generate-brand-colors`
  (`scripts/generate-brand-colors.mjs`, sur le modèle de `generate-routes`) en tire
  `frontend/src/lib/badgeColors.generated.ts` et `mobile/lib/core/theme/enum_colors.generated.dart`,
  et refuse une valeur hors contrat, une valeur sans famille ou une famille hors liste. Au web, il
  remplace `badgeColors.ts` (supprimé), `getClimbCategoryColor` (`RouteDetailView.tsx`), les
  dégradés de `CardImage.tsx`, et aussi des tables que la tâche n'avait pas relevées : les
  `statusColors` locales de cinq pages de détail, le `PUBLIC` badgé `primary` (indigo) de
  `VisibilityBadge` et le `PUBLIC` vert des gabarits de sortie — tous deux `blue` désormais, comme
  la charte. Au mobile, les extensions `StatusTone`… sont générées et seul le rendu d'une famille
  reste écrit à la main (`PdlFamilyTone` dans `enum_colors.dart`) ; `PdlGradients` lit
  `PdlFallbackGradients`. **Arbitrage `ROAD`** : gris doux partout — badge web (`dark` avant) comme
  trait de rappel mobile (near-black `accentDark` avant) ; `accentDark` et
  `PedalonsColors.darkLight/darkDark`, devenus sans usage, sont retirés. Les états dérivés
  (« Inscrit », « Terminée », « Supprimé ») restent hors du YAML : aucune énumération ne les porte.
  [`BRANDING.md`](BRANDING.md) §3.6 renvoie au YAML au lieu de recopier les tableaux. Test :
  `mobile/test/core/theme/pdl_tokens_test.dart` (ROAD gris, aplat compris ; cols seuls en aplat ;
  valeurs inconnues en gris) ; au web, `pnpm typecheck` vérifie chaque table générée par
  `satisfies Record<Enum, BadgeFamily>`. **Ne pas** réintroduire de table de couleurs locale dans
  un composant, ni éditer les deux fichiers générés : on édite le YAML et on régénère.

- `BRAND-4` **Vent relatif au code couleur métier** (2026-10-05, contrat `10.9.0`) —
  `RelativeWind` est entré dans [`contracts/brand-colors.yaml`](../contracts/brand-colors.yaml),
  style `soft` : `TAIL` teal, `CROSS` gray, `HEAD` orange ; les deux tables générées sont
  régénérées et lues par la barre d'exposition et les flèches de vent des deux clients (`WEB-60`,
  `MOB-51`). **À ne pas défaire** : la couleur n'est jamais seule, toujours doublée du libellé et de
  la flèche ; les conditions météo (`WeatherCondition`) n'ont pas de couleur — si on leur en donne,
  c'est ici, dans le YAML, jamais dans une table d'un client.

- `BRAND-5` **Un nouvel enum coloré passe en une seule régénération** (2026-10-06, contrat
  inchangé) — `scripts/generate-brand-colors.mjs` lit le modèle Freezed de chaque enum coloré
  (`mobile/lib/api/generated/models/<enum>.dart`), or `pnpm check` le lançait avant que le client
  mobile ne soit généré : un nouvel enum demandait deux passes. Corrigé par l'ordre, pas par le
  générateur : [`regenerate.sh`](../regenerate.sh) génère le client mobile (`pub get`,
  `openapi_retrofit_generator`, `build_runner`) entre le backend et `pnpm check`, et
  [`check.sh`](../check.sh) lance `mobile/clean.sh` (qui régénère le client) après le backend au
  lieu d'avant. Le générateur, s'il ne trouve pas le modèle, le dit et renvoie à cet ordre.
  **À ne pas défaire** : ne pas rendre le générateur tolérant à l'absence du Dart — il produirait
  un `enum_colors.generated.dart` sans l'enum, ou faux, sans échouer ; il doit continuer à lire les
  identifiants dans le modèle Freezed plutôt que de les deviner. Vérifié : `pnpm
  generate-brand-colors` laisse les deux `.generated.*` inchangés ; message d'erreur contrôlé en
  retirant `relative_wind.dart`. Pas de test automatisé (outillage).

- `BRAND-6` **Les icônes des sections d'équipe suivent la charte, les mêmes sur les deux clients**
  (6 octobre 2026, avec `WEB-68` et `MOB-60`, contrat inchangé). Au web, `useTeamNavItems` prend
  les icônes de la table du [`BRANDING.md`](BRANDING.md) §6 (`useTeamNavItems.test.tsx`) ; au
  mobile, `buildTeamSections` prend l'équivalent `PdlIcons` de chacune — `dashboard`, `agenda`
  (nouveau, `event_outlined` pour `IconCalendarEvent`), `post`, `route`, `ad`, `people`, `info` —
  au lieu des `Icons.*` choisis à part (`dynamic_feed`, `sell`, `calendar_today`…) ; la table du
  §6 porte désormais la colonne mobile (`team_dashboard_test.dart`, « les puces suivent l'ordre du
  site »). « Agenda » et « En cours » sont au lexique (§8). **À ne pas défaire** : une icône de
  section vient de `PdlIcons`, jamais d'un `Icons.*` posé dans l'écran ; changer une icône de
  section se fait dans la table du §6 et sur les deux clients à la fois.

---

## SEC — Audit de sécurité

Les constats corrigés avant l'ouverture du ledger sont dans l'audit de septembre 2026, archivé :
[`plans/archive/2026-09-security-audit.md`](plans/archive/2026-09-security-audit.md).

- `SEC-34` **compteur d'essais OTP rendu sûr face aux devinettes concurrentes** (2026-10-11, contrat inchangé, constat de la modélisation formelle TLA+/Lean). Avant, `verifyOtp` lisait le code sans verrou. `recordFailedAttempt` incrémentait le compteur en mémoire, puis Hibernate réécrivait toute la ligne depuis cet instantané (pas de `@Version` sur `AuthToken`). Une mauvaise devinette lue avant l'épuisement du code (5 échecs) ou avant la connexion du titulaire, mais validée après, réécrivait donc `failed_attempts=1, used_at=NULL`. Le code redevenait valide et son compteur repartait de zéro : une rafale parallèle obtenait bien plus de 5 essais par code. Désormais, `verifyOtp` verrouille d'abord le compte (`UserRepository.findByEmailAndDomainForUpdate`), puis le code vivant le plus récent (`AuthTokenRepository.findValidByEmailAndTypeForUpdate`, `PESSIMISTIC_WRITE`, même idiome que `AUD-16`). Les devinettes sur une même adresse passent donc l'une après l'autre. Sous READ COMMITTED, une devinette qui attendait relit `used_at is null and expires_at > now` et ne trouve plus un code épuisé ou utilisé. `dontRollbackOn = BadRequestException` reste en place pour que l'échec compté soit validé. Couvert par `OtpFailedAttemptLostUpdateRaceTest` et par `OtpVerifyRequestDeadlockRaceTest`. **À ne pas défaire** : l'ordre des verrous, compte puis code, identique à `createOtp`. Verrouiller le code d'abord interbloque une connexion valide contre une demande de nouveau code : la connexion tient le code et attend le compte pour `recordLogin`, la demande tient le compte et attend le code pour l'invalider. PostgreSQL abandonne alors l'une des deux, d'où une 500 côté connexion ou côté `requestOtp`. Ne pas remplacer ce verrou par un `@Version` (migration, et une 500 `OptimisticLockException` sous contention).

- `SEC-35` **limite de demandes OTP et « un seul code vivant » sérialisées par adresse** (2026-10-11, contrat inchangé, constat de la modélisation formelle TLA+/Lean). Avant, `createOtp` comptait les codes récents, invalidait les codes vivants puis insérait le nouveau, sans verrou : c'était un check-then-act. Deux demandes simultanées (un onglet web et l'app) ne voyaient chacune que les lignes déjà validées. Elles émettaient alors plus de 3 codes par fenêtre et laissaient plusieurs codes vivants à la fois, ce qui multipliait le budget de devinettes de l'audit H1. Désormais, `createOtp` charge le compte avec `UserRepository.findByEmailAndDomainForUpdate` (`SELECT … FOR UPDATE`) avant de compter. La seconde demande attend le commit de la première, puis elle est limitée ou invalide le code de la première. Le verrou ne couvre que la courte transaction de `createOtp` : le mail part après le commit et n'est jamais envoyé sous verrou. Une adresse inconnue ou non vérifiée ne verrouille rien, et l'anti-énumération est inchangée. Aucune migration. Couvert par `OtpRequestRateLimitRaceTest` et par `OtpVerifyRequestDeadlockRaceTest`. **À ne pas défaire** : tout chemin qui verrouille un code OTP prend d'abord ce verrou de compte, sinon on retombe dans l'interblocage décrit en `SEC-34`. Ni verrou consultatif (`pg_advisory_xact_lock`, SQL natif), ni index unique partiel : il demanderait une migration et ne couvrirait que la moitié « un seul code vivant ». `createEmailChangeToken` et `createPasswordResetToken` ont le même motif compter-puis-insérer et restent à traiter à part.

- `SEC-36` **Les limites d'échecs d'authentification tiennent sous concurrence** (2026-10-11, contrat inchangé, constat de la modélisation formelle TLA+/Lean). Avant, `AuthThrottle` comptait les échecs déjà commités, puis le bcrypt (ou la recherche du code d'appairage) avait lieu, puis l'échec était inscrit en `requiringNew`. Rien ne sérialisait ce contrôle-puis-inscription par sujet : N connexions simultanées sur une même adresse lisaient toutes un compte inférieur à 5 et passaient, soit environ une par connexion du pool (≈ 20 par instance, 40 pendant un déploiement) au lieu de 5. `POST /api/device/oauth/complete`, `deny` et `verify` dépassaient de la même façon le budget de 5 par compte. Désormais, `admitPassword` et `admitDeviceCode` réservent l'essai d'avance : une transaction `requiringNew` courte prend un verrou consultatif `pg_advisory_xact_lock` par budget (adresse hachée pour le mot de passe, domaine pour les codes d'appairage, verrou qui couvre aussi le budget par compte), compte les échecs, puis inscrit l'échec avant le bcrypt ou la recherche, ou bien répond 429 sans rien inscrire. Le bon mot de passe efface l'ardoise (`clearPassword`), un code connu rend son essai (`forgetDeviceCode`), dans la transaction de l'appelant. `findPendingUserCode` devient `@Transactional`. Pas de migration. Couvert par `AuthThrottleConcurrentGuessRaceTest` (8 essais simultanés, exactement 5 vont jusqu'au bcrypt), ainsi que par les tests SEC-4/SEC-7 existants d'`AuthResourceTest` et `DeviceOAuthThrottleTest`. **À ne pas défaire** :
  - l'échec est inscrit **avant** le bcrypt, dans la même section verrouillée que le compte ; le réinscrire après le bcrypt rouvre la course ;
  - le verrou vit dans la transaction `requiringNew` et non dans celle de l'appelant : tenu jusqu'à la fin de l'appelant, les requêtes en attente garderaient leur connexion pendant que le détenteur en réclame une seconde pour inscrire l'échec, ce qui épuise le pool, fait échouer l'inscription et laisse l'essai non compté ;
  - une requête qui meurt en route laisse son essai compté, ce qui est voulu (on se trompe du côté de la limite).

- `SEC-37` **Le challenge d'authentification par passkey est strictement à usage unique** (2026-10-11, contrat inchangé, constat de la modélisation formelle TLA+/Lean). Avant, `PasskeyService.verifyAuthentication` lisait le challenge sans verrou puis le supprimait en `requiringNew` par `deleteById`, dont il ignorait le résultat. Deux soumissions simultanées d'une même assertion signée lisaient toutes deux le challenge. Pour la seconde, `deleteById` ne trouvait plus rien et répondait `false` sans lever d'exception, puis webauthn4j validait l'assertion une deuxième fois. Le compteur de signatures ne protégeait pas : `Passkey` n'a pas de `@Version`, et les passkeys synchronisées envoient 0. Résultat : deux sessions pour un seul challenge. Désormais, `WebAuthnChallengeRepository.consume(id)` émet un unique `DELETE … WHERE id = ?`, qui attend le verrou de ligne d'un consommateur concurrent et renvoie `true` seulement s'il a supprimé la ligne. La vérification refuse en `400 TOKEN_INVALID` quand il renvoie `false`, et cela **avant** `webAuthnManager.verify`. `verifyRegistration`, qui avait le même défaut, passe aussi par `consume`. Couvert par `PasskeyChallengeDoubleUseRaceTest` (`challengeConsumedConcurrentlyAfterLookup_isRefused` ; le test témoin `control_validAssertionAuthenticatesOnce` prouve que l'authentificateur logiciel est valide). **À ne pas défaire** : on ne vérifie l'assertion que si **cette** requête a supprimé la ligne. Ni revenir à `deleteById` en ignorant son résultat, ni se contenter de tester son booléen : dans l'autre entrelacement, il lève une exception au lieu de renvoyer `false`.

- `SEC-38` **Quitter un groupe ne vérifiait pas que le groupe appartenait à la sortie contrôlée** (2026-10-11, contrat inchangé, constat de la modélisation formelle TLA+/Lean) — `RideAccessChecker` (LEAVE) validait la sortie de l'URL (publiée, membre de l'équipe, sorties activées), puis `RideService.leaveGroup` supprimait la participation de l'appelant par `findByUserAndGroup(userId, groupId)` seul, sans lien avec la sortie : `DELETE /teams/A/rides/<sortie publiée de A>/groups/<groupe d'une sortie annulée, en brouillon, ou d'une équipe B quittée ou aux sorties désactivées>/participation` désinscrivait l'appelant de cette autre sortie en contournant les règles PUBLISHED, d'appartenance et d'activation des sorties (sa propre ligne seulement, même domaine : ni autre utilisateur ni autre tenant). `leaveGroup` résout désormais l'équipe et la sortie de l'URL et exige `rideGroupRepository.findByIdAndRide(groupId, ride.getId())` (404 `RIDE_GROUP` sinon), comme `joinGroup`. Test : `RideLeaveGroupScopeTest` (sortie annulée de la même équipe, sortie d'une autre équipe). **À ne pas défaire** : un identifiant de groupe venu de l'URL n'est jamais utilisé sans être rattaché à la sortie que le contrôle d'accès a validée.

- `SEC-26` **L'édition d'une annonce ne donne la position exacte qu'au vendeur : M2 (annexe)**
  (2026-10-01, **API 9.2.1**, patch : descriptions de `AdEditDto.locationGeometry` et
  `AdDto.locationGeometry` ; pas de migration) — `GET …/classifieds/{slug}/edit` servait le point
  exact à quiconque pouvait modifier l'annonce, admins d'équipe et de plateforme compris. `AdEditDto`
  porte désormais le point exact pour l'**auteur** seul ; tout autre éditeur reçoit
  `CoarseLocation.blur`, le même centre de cellule que `AdDto` (`AdService.toEditDto`, aussi pour la
  réponse de `undeleteAd`). Pour qu'un enregistrement par un non-auteur n'écrase pas le point exact
  par le centre flouté reçu, `AdService.updateAd` compare la position soumise au flou du point
  stocké (tolérance 1e-7°) : identique, le point exact est conservé ; différente ou nulle, elle est
  appliquée telle quelle (un admin peut toujours déplacer ou effacer la position). Choix : la
  comparaison côté serveur plutôt qu'un indicateur dans `AdRequest` — le serveur seul sait ce qu'il a
  servi, et l'éditeur web, qui renvoie le formulaire tel quel, n'a pas eu à changer ; le mobile
  n'édite pas d'annonce. Limite assumée : un non-auteur qui choisirait exactement le centre de la
  cellule du vendeur garde le point exact — même cellule, rien de publié ne change. **À ne pas
  défaire** : ne servir le point exact qu'à `ad.createdBy`, jamais sur le rôle ; garder la
  comparaison sur `CoarseLocation.blur` (si le flou change, elle suit). Tests (**écrits, non
  lancés**) : `AdServiceTest` (`GetAdEditDto.shouldReturnExactLocationToAuthor`,
  `…shouldReturnBlurredLocationToNonAuthorAdmin`, `…shouldReturnBlurredLocationOnUndeleteByNonAuthorAdmin`,
  `UpdateAd.adminSaveWithoutMovingKeepsExactLocation`, `…adminMovingLocationReplacesIt`,
  `…adminClearingLocationRemovesIt`, `…authorSavingCellCentreReplacesExactLocation`) et
  `AdDetailsAndFiltersTest.getAdEdit_asNonAuthorAdmin_givesTheBlurredPointAndARoundTripKeepsTheExactOne`
  (aller-retour JSON par HTTP, comme l'éditeur web).

- `SEC-6` **Le traitement GPX est borné avant d'allouer : M3** (2026-10-01, **API 9.2.0**, mineur :
  code d'erreur `GPX_TOO_LONG`, `minimum`/`maximum` sur `GeoPoint`, `maxItems` sur les points du
  planificateur) — la chaîne GPX rééchantillonne chaque tracé à un point tous les 10 m : ce qu'elle
  alloue suit la *distance* du tracé, pas la taille de la requête, si bien que quelques points très
  éloignés suffisaient à épuiser la mémoire du backend partagé. Trois bornes, réunies dans
  `GpxLimits` et vérifiées avant toute allocation : **10 Mo** par fichier téléversé, désormais sur
  toutes les routes HTTP qui en prennent un (création *et* mise à jour d'un aperçu des outils GPX,
  création et mise à jour d'un parcours d'équipe — seule la création d'aperçu l'appliquait), refus
  `FILE_TOO_LARGE` ; **4 000 km** de longueur cumulée pour tous les tracés d'un GPX, quelle que soit
  sa source (fichier, points du planificateur, routeur, import biketeam), soit au plus ~400 000
  points rééchantillonnés, refus `GPX_TOO_LONG` — vérifié dans `parseGpx` et `fromPoints`, avant
  tout travail, puis répété dans `computeGpx`, l'entonnoir, et dans `RouterService` ; **100 000
  points** par requête du planificateur (`@Size` sur `RouteRequest.points`,
  `GpxPreviewFromPointsRequest.points`, `GpxPreviewUpdateRequest.points`), chacun validé dans les
  bornes WGS84 (`@DecimalMin`/`@DecimalMax` sur `GeoPoint`, `@Valid` en cascade, routeur compris) ;
  un point hors bornes ou non numérique dans un fichier est un `GPX_FAILURE`. Les plafonds visent
  le vélo réel : 4 000 km couvrent un brevet d'ultra-distance d'un seul tenant (Paris-Brest-Paris,
  London-Edinburgh-London), un périple plus long est un voyage en étapes. Au passage, la mise à jour
  d'un parcours lit le nouveau tracé *avant* son `try` : un fichier refusé garde son code d'erreur
  (tout devenait `GPX_FAILURE`) et ne supprime plus les fichiers actuels du parcours. L'import
  biketeam n'est pas soumis aux 10 Mo (il lit ses fichiers de serveur à serveur) mais l'est aux
  4 000 km, rangés en avertissement `GPX_FAILURE`. Correction sur le code actuel, pas sur la
  bibliothèque vcyclist (migration non planifiée). À ne pas défaire : la vérification de la
  distance avant `computeOnePointPerDistance` (elle s'écrit `!(total <= max)` pour refuser aussi
  un NaN) ; relever `MAX_TRACK_DISTANCE_METERS` relève d'autant la mémoire qu'une requête peut
  prendre. Tests (**écrits, non lancés**) : `GpxLimitsResourceTest` (fichier trop gros sur les
  quatre routes, tracé trop long par fichier et par points, trop de points, latitude et longitude
  hors bornes, parcours intact après un refus) et `GpxLimitsTest` (unitaire : tracé réaliste
  accepté, somme sur plusieurs tracés, coordonnée hors bornes ou NaN).

- `SEC-33` **Un saut de ligne dans un nom ne fait plus échouer un courriel** (2026-10-01, contrat
  inchangé, relevé en vérifiant V7 sous `SEC-16`) — le client SMTP (Vert.x Mail) refuse un sujet qui
  contient CR ou LF, ce qui exclut toute injection d'en-tête mais faisait lever l'envoi : les sujets
  interpolent `senderName`, `adName`, `inviterName`, `teamName` et le `subject` des notifications,
  et l'API accepte ces noms avec un saut de ligne (ni `@AcceptableText` ni `@Size` ne l'interdisent).
  `EmailService.sendEmail` remplace désormais toute suite de sauts de ligne (`\R+`, donc aussi
  `U+0085`, `U+2028`) par une espace avant d'envoyer. Choix : au rendu du sujet, seul point commun
  à tous les courriels, plutôt qu'une validation de chaque champ de nom — un nom existant ou importé
  est couvert aussi, et le corps du message garde ses sauts de ligne. Test :
  `EmailServiceTest.lineBreaksInANameBecomeSpacesInTheSubject`, lancé le 1er octobre 2026 (la
  classe passe) ; sans le correctif il échoue sur l'erreur même du client (« Single-line text contains
  the LF char », puis « Mail not sent »).

- `SEC-16` **Les faits hors dépôt de l'audit, V3 à V8, tous tranchés** (2026-09-30 → 2026-10-01,
  contrat inchangé) — vérifiés sur les hôtes, chacun avec son statut dans l'audit de septembre (archivé) :
  V3 conforme par Caddy (`X-Forwarded-*` forgés sans effet), avec une faille annexe, Traefik joignable
  en IPv6, fermée sous `SEC-29` ; V4 confirmé puis corrigé sous `SEC-30` (la CSP des scripts reste
  `SEC-31`) ; V5 confirmé puis corrigé sous `SEC-32` (recette `OPS-26`, alerte `OPS-27`) ; V6 sans
  tenants voisins (un domaine par base), mais d'autres sites de l'hôte sont des sous-domaines de
  `pedalons.fr`, donc « same-site » pour la prod ; V7 non confirmé — Vert.x Mail 4.5.34 refuse CR et LF
  dans un sujet et encode les autres séparateurs en RFC 2047, essayé sur son `MailEncoder` (annexe :
  `SEC-33`, corrigé) ; V8 caduc — aucun SVG stocké en prod ni en staging, leur envoi refusé depuis `SEC-1`.
  **À ne pas défaire** : V7 repose sur le client SMTP ; un changement de bibliothèque de courriel
  doit reverser la question, ou `SEC-33` la régler côté application.

- `SEC-32` **Les snapshots de sauvegarde hors d'atteinte de la production : V5** (2026-09-30,
  contrat inchangé) — vérifié sur l'hôte de sauvegarde : la clé de la prod (`rrsync <root>`, sans
  `-no-del`) écrivait les snapshots datés eux-mêmes, qui appartenaient au compte de sauvegarde ; un
  root de prod compromis pouvait les effacer ou les réécrire, et un fichier réécrit en place l'était
  dans tous les snapshots qui le partagent par hardlink. Choix de l'utilisateur : **dépôt et
  promotion par root**. `backup.sh` ne pousse plus que dans `<root>/incoming/`, miroir mis à jour en
  place (`COMPLETE`, qui porte désormais le nom du snapshot, retiré d'abord et écrit en dernier) ;
  `backup-promote.sh`, dans la crontab root de l'hôte de sauvegarde toutes les 15 minutes, copie
  `incoming/` en snapshot daté, hardlinké contre le précédent, `root:<compte>` en `0750`/`0440`,
  vérifié par `SHA256SUMS`, renommé en place d'un bloc. La même clé lit toujours les snapshots
  (restauration inchangée) mais ne peut plus ni les écrire, ni les effacer, ni les renommer, ni en
  changer les droits, ni les hardlinker (`fs.protected_hardlinks`). **Au plus une promotion par
  20 heures**, un nom postérieur au dernier snapshot et pas dans le futur : le nom vient de la prod
  et la purge garde un nombre, si bien que sans plancher une prod compromise pousserait trente
  snapshots en une nuit et ferait purger tous les vrais. Écarté : `fs.protected_hardlinks=0` avec un
  verrouillage après coup (moins de code, mais une protection du noyau affaiblie sur un hôte à
  plusieurs comptes) et `-no-del` seul (n'empêche pas la réécriture). Coût : une copie de plus du
  magasin d'objets (`incoming/`, ~1,7 Go). **À ne pas défaire** : rien dans `<root>` hors
  d'`incoming/` n'appartient au compte de sauvegarde ; ne pas lever le plancher de 20 heures ni
  faire tourner la promotion depuis un fichier que la prod peut écrire. Vérifié sur l'hôte de
  sauvegarde, dans un répertoire jetable, avec `rrsync` réel sous le compte de sauvegarde et les
  fonctions de `_backup_common.sh` : deux promotions et le hardlink d'un objet inchangé, la liste et
  la relecture de `restore.sh`, les refus (réécriture, `--inplace`, `--delete`, nouveau répertoire à
  la racine), les noms forgés (`../../etc`, futur, antérieur), un dump altéré, la purge. Pas de test
  automatisé (scripts d'exploitation).

- `SEC-30` **En-têtes de sécurité HTTP : V4** (2026-09-30, contrat inchangé, prend effet au prochain
  `deploy.sh`) — vérifié le même jour sur la prod : ni HSTS, ni CSP, ni `X-Frame-Options`, ni `nosniff`
  sur les pages et l'API, et `X-Powered-By: Express`. Posés par Traefik (`docker-compose.yml`), un
  middleware `headers` par routeur, **chacun défini sur son propre service** (`api-headers` sur le
  backend, `site-headers` sur le frontend) : un middleware partagé, défini sur l'un et utilisé par
  l'autre, faisait tomber le site avec le backend (« middleware does not exist » vu au redémarrage).
  HSTS un an (`forceSTSHeader` : Caddy parle HTTP à Traefik, qui ne l'enverrait sinon qu'en TLS ;
  sans `includeSubDomains`), `nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy:
  strict-origin-when-cross-origin`, `Permissions-Policy` (caméra, micro, paiement, USB fermés ;
  géolocalisation au site). Le site seul reçoit une CSP, limitée aux directives qui ne contraignent
  aucun script : `frame-ancestors 'none'; base-uri 'self'; object-src 'none'; form-action 'self'`
  (rien n'embarque le site en iframe, aucun formulaire ne poste ailleurs) ; la contrainte des scripts
  est `SEC-31`. `server.js` ne dit plus `X-Powered-By`. **À ne pas défaire** : pas de CSP sur le
  routeur de l'API — elle écraserait la CSP bac à sable des téléchargements (`UploadedContentHeaders`,
  `SEC-1`) et empêcherait la visionneuse PDF de démarrer. Vérifié sur la pile locale, puis en prod
  et en staging le 1er octobre 2026 après déploiement : les en-têtes sur `/` et `/api/version`, plus
  de `X-Powered-By`, et la CSP bac à sable d'un téléchargement réel arrive intacte. Pas de test
  automatisé (configuration du proxy).

- `SEC-29` **Les ports Swarm fermés aussi en IPv6** (2026-09-30, contrat inchangé, relevé en
  vérifiant V3 sous `SEC-16`) — en IPv6, Traefik (8089, 8090) et Grafana (3300) répondaient depuis
  Internet : sans NAT IPv6 dans le routing mesh, Docker sert un port publié par un `docker-proxy` qui
  écoute sur l'hôte, si bien que le trafic passe par `INPUT` et jamais par `DOCKER-USER`, où
  `pedalons-firewall.sh` posait ses règles. Caddy était contourné : pas de journal filtré, des
  `X-Forwarded-*` forgés crus par Traefik (`forwardedHeaders.insecure`, `AUD-6`), et la limite de
  débit de `SEC-28` sans effet. Le script pose désormais, pour chacun de ces ports, un DROP dans
  `INPUT` en plus de `DOCKER-USER`, v4 et v6 (sans effet en IPv4, que le mesh fait passer par
  `FORWARD`). Installé sur l'hôte et vérifié le même jour depuis une autre machine : 8089, 8090,
  3300 et 2020 ne répondent plus ni en IPv4 ni en IPv6, le site et le staging répondent par Caddy,
  Grafana et Traefik restent joignables sur la boucle locale (tunnel SSH, Caddy). **À ne pas
  défaire** : toute vérification du pare-feu se fait aussi en IPv6 et d'une autre machine — l'absence
  d'enregistrement AAAA ne protège pas ; un nouveau port publié par Swarm s'ajoute à
  `TRAEFIK_PORTS` ou `MONITORING_PORTS`, qui le ferment sur les deux chemins. Pas de test
  automatisé (pare-feu de l'hôte) : `OPERATIONS.md`, « Only Caddy may reach traefik », donne les
  contrôles.

- `SEC-5` **Les clés JWT de prod et de staging ne viennent pas de l'historique public : V1 non
  confirmé** (2026-09-30, rien de changé dans le code) — deux paires de clés RSA ont été commitées
  puis retirées, et restent lisibles dans l'historique du dépôt public : celle de
  `backend/src/main/resources/` (`c0ac99fe`) et celle de dev (`7978afb1`) ; un parcours de tous les
  `.pem` de l'historique, toutes branches, n'en trouve pas d'autre. Si la prod en avait été une
  copie, n'importe qui aurait pu forger un jeton d'administrateur. Vérifié sur l'hôte en comparant
  l'empreinte SHA-256 de la forme DER de chaque clé publique (tirée aussi de la clé privée, pour
  vérifier la paire) : les clés de prod et de staging sont générées sur l'hôte par
  `data/keys/generate-keys.sh`, distinctes l'une de l'autre et des deux clés publiées, et ce sont
  bien celles que lisent les backends (`/mnt/keys/publicKey.pem` identique dans le conteneur et sur
  l'hôte). Aucun `.pem` n'est plus suivi par git. **À ne pas défaire** : les deux clés publiées sont
  compromises pour toujours — ne jamais les réemployer, pas même pour un environnement de test
  exposé ; une nouvelle clé se génère, elle ne se copie pas d'un environnement à l'autre. Pas de
  test automatisé (fait de l'hôte, hors dépôt).

- `SEC-8` **Le filtre de proximité des annonces mesure depuis la position floutée : M2**
  (2026-09-30, **API 8.0.1**, patch : description d'`AdDto.locationGeometry` seulement, aucune migration) — la
  décision `API-31` quantifiait la sonde et le rayon sur la grille du flou, mais le filtre mesurait
  encore depuis la position **exacte** : chaque réponse coupait la cellule le long d'un cercle, et
  des cercles de centres différents la découpaient plus fin qu'elle. `AdRepository` mesure
  désormais depuis `coarse_location(te.locationGeometry)`, une fonction HQL
  (`PedalonsFunctionContributor`) qui refait `CoarseLocation.blur` en SQL à partir des mêmes
  constantes (`CoarseLocation.SQL_PATTERN`) ; la sonde et le rayon restent quantifiés. La réponse ne
  dépend donc plus que de cellules publiées : deux annonces d'une même cellule reviennent toujours
  ensemble. Choix de l'utilisateur : **le calcul dans la requête**, pas une colonne stockée (même
  résultat, sans migration ni fenêtre de déploiement progressif). **Décisions** : aucun filtre, tri
  ou calcul ne lit la position exacte d'une annonce hors de son édition ; toute modification de
  `blur` se reporte dans `SQL_PATTERN`. Tests : `CoarseLocationSqlTest` (parité Java/SQL, pôles,
  hémisphères, bords de cellule), `AdDetailsAndFiltersTest.list_withProximity_neverTellsApartTwoAdsOfTheSameCell`.
  Le point annexe de l'audit, la position exacte servie aux admins par l'édition, est `SEC-26` (corrigé).

- `SEC-11` **Le jeton d'accès des appareils vit 15 minutes, et leur refresh token tourne : M9**
  (2026-09-30, **API 9.1.2**, patch : description de `DeviceTokenResponse.refreshToken` ; pas de migration — celle de `SEC-27` suffit) — le JWT d'un Karoo ou d'une montre
  Garmin vivait 60 minutes sans pouvoir être révoqué. Décisions de l'utilisateur : **15 minutes**,
  comme le site (`DeviceJwtService`, `pedalons.device.jwt.access-token-expiry-minutes`), et **la
  rotation du refresh token des appareils tout de suite**, par le même composant que le site et
  l'app (`RefreshTokenRotation`, extrait d'`AuthService` : tolérance d'une minute, rejeu révoqué ;
  pour un appareil, un rejeu ou un jeton inconnu répond `TOKEN_INVALID`). L'app Garmin gardait déjà
  un `refreshToken` renvoyé ; **Karoo l'ignorait** (`updateAccessToken`) : il enregistre désormais
  toute la réponse (`AuthManager.saveTokens`, aux trois appels de refresh). Aucun Karoo n'avait
  l'app installée le 30 septembre 2026 : personne à réappairer. Karoo doit être republié
  avec ce changement avant tout nouvel appareil ; Garmin n'a rien à changer. M8 et M10, d'abord rangés ici, sont
  livrés sous `SEC-25` et `SEC-28`, M7 sous `SEC-27`. Tests : `DeviceRefreshRotationTest`
  (rotation, 15 minutes, tolérance, rejeu) — **écrit sans avoir été lancé** ; `flow-device.e2e.ts`
  attend désormais un jeton renouvelé. Ne pas rallonger le jeton d'accès d'un appareil tant qu'il
  n'est pas révocable.

- `SEC-27` **Le refresh token est renouvelé à chaque usage : M7** (2026-09-30, **API 9.1.1**, patch — `AuthResponse.refreshToken` rempli par `POST /api/auth/refresh` pour le
  flux à en-tête ; migration `V53__auth_session_rotation` ; détaché de `SEC-11`) — un refresh token
  volé ouvrait la session 30 jours. Décision de l'utilisateur : **rotation avec une tolérance** —
  chaque refresh émet un nouveau jeton ; l'ancien, gardé en `previous_refresh_token_hash`, obtient
  encore un access token **sans nouvelle rotation** pendant 60 s (`…rotation-grace-seconds`) : les
  autres onglets, le rendu SSR, l'app qui reprend, partis avec le même jeton ; présenté après, c'est
  une copie rejouée, et **la session est révoquée** (pour le voleur comme pour le titulaire, dans sa
  propre transaction). La rotation est un `update` conditionnel (`AuthSessionRepository.rotate`) :
  de deux refresh simultanés, un seul la gagne, l'autre tombe dans la tolérance. Un jeton plus vieux
  de deux rotations est inconnu (403, sans révocation). La déconnexion accepte aussi le jeton
  précédent. Web : le nouveau jeton ne va que dans le cookie `HttpOnly`, jamais dans le corps ;
  **le SSR relaie le `Set-Cookie` de son refresh** dans toute réponse de document, redirection et
  erreur 500 comprises (`resolveSsrSession` → `RenderSink` → `server.js`), faute de quoi le cookie
  du navigateur deviendrait un rejeu. Mobile : le jeton revient dans `refreshToken`, que l'app
  enregistrait déjà (`auth_interceptor.dart`, `auth_provider.dart`) : pas de code mobile, mais **le
  comportement de `/auth/refresh` change et entre dans le train mobile** ; le Patrol `MOB-38`
  (jeton d'accès expiré) couvre ce cycle et **doit être relancé à la recette**. V53 ajoute aussi les
  index de `refresh_token_hash`, qui n'en avait pas. Colonnes nulles : pendant un déploiement,
  l'ancienne version ne fait pas tourner les jetons ; un jeton précédent présenté à elle échoue (403)
  et renvoie à la connexion. **Les appareils** tournent aussi, depuis `SEC-11`, par le même
  `RefreshTokenRotation`. Suite e2e réécrite pour le modèle « une session, un
  détenteur » (`frontend/e2e/README.md`, « How sessions work ») : plus de session enregistrée et
  partagée ; mot de passe pour les rôles, admin compris ; session propre à chaque contexte et à
  chaque `signIn` ; jeton renouvelé réécrit dans le cookie ou l'objet qui le détient. Tests :
  `AuthServiceTest` (rotation, tolérance, rejeu après tolérance, jeton de deux rotations,
  déconnexion avec le jeton précédent), `AuthResourceTest` (cookie renouvelé et absent du corps,
  en-tête), `ssrSession.test.ts`, `auth.e2e.ts` (document qui renouvelle le cookie, refresh
  simultanés) — les tests backend **écrits sans avoir été lancés**. Ne pas mettre le jeton dans le
  corps d'une réponse à cookie, ni rendre une réponse SSR sans le `Set-Cookie` de son refresh.

- `SEC-28` **Une limite de débit par client devant tout le site : M10** (2026-09-30, contrat
  inchangé, pas de migration ; détaché de `SEC-11`) — rien ne bornait le débit d'un client hors des
  compteurs d'authentification (`SEC-4`, `SEC-7`). Décision de l'utilisateur : **au proxy, pas dans
  l'application** — un middleware `ratelimit` de Traefik sur chacun des deux routeurs de
  `docker-compose.yml`, 50 requêtes/s en rafales de 200 sur `/api`, 100/s en rafales de 400 sur le
  site, `429` avec `Retry-After` au-delà. Larges exprès : une carte tire ses tuiles par rafales, une
  première visite charge tous les chunks, un club derrière une adresse reste un seul client. Réglables
  par `RATE_LIMIT_API_AVERAGE`, `…_BURST`, `RATE_LIMIT_FRONTEND_AVERAGE`, `…_BURST` (`.env.example`) ;
  `.env.e2e` les lève, la pile e2e n'ayant rien devant elle. Le client est le **dernier** saut de
  `X-Forwarded-For` (`ipStrategy.depth=1`), celui que pose le Caddy de l'hôte, seul point d'entrée,
  qui remplace l'en-tête reçu — un premier saut forgé ne change pas de compteur. Vérifié le 30
  septembre 2026 sur un Traefik v3.7 jetable (dépassement, `Retry-After`, client voisin intact,
  premier saut forgé ignoré), puis **recetté sur l'hôte** le même jour après déploiement, la
  vérification d'`OPERATIONS.md` (« Rate limiting ») : 300 requêtes `/api/config` à 50 en parallèle
  finissent en `429` (~250 servies, staging comme prod) et 5 s après tout repasse ; le même lot avec
  un `X-Forwarded-For` forgé différent à chaque requête est limité pareil ; 1 500 requêtes sur le
  site en 5,2 s donnent 872 `200` (400 + 100/s) ; et pendant que 3 000 requêtes d'une adresse
  prenaient 2 268 `429`, une seconde machine, d'une autre adresse, a reçu 40 `200` sur 40 : chaque
  client a bien son propre compteur. Ne pas prendre le premier saut de l'en-tête, et
  ajouter `trusted_proxies` à Caddy si un proxy vient un jour devant lui. `API-27` (lot de
  géométries) reste ouvert : cette limite borne le nombre de lots, pas le poids de chacun.

- `SEC-25` **Un identifiant ne résout plus un compte ni une passkey d'un autre site : M8**
  (2026-09-30, contrat inchangé, pas de migration ; détaché de `SEC-11`) — `UserRepository.findActiveById`
  et `PasskeyRepository.findByCredentialId` cherchaient sur toute la table, et chaque appelant
  devait penser à comparer le domaine après coup. `findActiveById` est remplacé par
  `findActiveByIdAndDomain` partout où l'on sert un site : utilisateur de la requête et du jeton de
  tuiles (`PedalonsQueryContext`), retrait d'un membre (`TeamMembershipService`), connexion GPS et
  son retour OAuth (`GpsService`), migration biketeam en direct (`BiketeamLiveMigrationWorker`, le
  domaine du job). Seule l'administration plateforme, transverse par construction, garde une
  recherche tous sites, renommée `findActiveByIdOnAnyDomain` pour que l'exception se voie. La
  connexion par passkey cherche par `findByCredentialIdAndDomain` ; la vérification de domaine qui
  suivait reste en seconde barrière. L'enregistrement garde une recherche tous sites
  (`existsByCredentialId`) : la colonne `credential_id` est unique sur toute la table. Tests :
  `UserRepositoryTest.findActiveByIdAndDomain_shouldNotReachAnotherSitesAccount`,
  `PasskeyRepositoryTest.findByCredentialIdAndDomain_shouldNotFindAnotherSitesPasskey` —
  **écrits sans avoir été lancés**. Ne pas réintroduire de recherche par identifiant sans domaine
  dans un chemin de requête.

- `SEC-1` **Un fichier téléversé ne s'exécute plus dans l'origine de l'application : H2**
  (2026-09-30, contrat inchangé, pas de migration) — la route de téléchargement des assets servait
  tout fichier `inline`, sous son type d'origine, sans `nosniff` ni CSP, et un SVG ou un XML s'y
  rendait en page. Décisions de l'utilisateur : **seuls les images matricielles (PNG, JPEG, GIF,
  WebP, AVIF) et le PDF s'ouvrent dans le navigateur**, tout le reste part en
  `Content-Disposition: attachment` (avec `filename*` RFC 5987) ; et **le SVG est refusé à
  l'envoi**, pas rastérisé. Au service (`UploadedContentHeaders`, appelé par
  `AbstractDownloadAssetResource`) : `X-Content-Type-Options: nosniff` partout, CSP
  `default-src 'none'; img-src 'self'; style-src 'unsafe-inline'; sandbox` partout sauf sur le PDF
  — elle empêche la visionneuse des navigateurs de démarrer, et les scripts d'un PDF tournent dans
  cette visionneuse, pas dans l'origine. Les images d'imgproxy (`/images/…`) portent le même
  `nosniff` et la même CSP : un SVG stocké avant le correctif y sort nettoyé par imgproxy, et
  sandboxé en plus. **Ce volet couvre les fichiers déjà stockés** ; ne pas le retirer au motif que
  l'envoi refuse désormais les SVG. À l'envoi : `svg` quitte la liste blanche `IMAGE`, `svg` et
  `xml` entrent dans la liste noire `ATTACHMENT`, et `FileTypeDetector` refuse en plus, pour une
  image ou une pièce jointe, tout type résolu `image/svg+xml`, `application/xml`, `text/xml`,
  `text/html` ou `application/xhtml+xml` — un petit SVG que Magika étiquette `txt` prenait sinon
  son type du seul nom de fichier. Seule exception : un **GPX joint** (étiquette `xml`, nom en
  `.gpx`), accepté parce que `TrackAttachmentSanitizer` le réécrit intégralement depuis sa trace
  (`API-49`) ; ne pas élargir l'exception à d'autres extensions. La moitié SVG d'`API-48` s'en
  trouve réglée pour l'avenir, le reste y demeure. Couvert par `UploadedContentHeadersTest`,
  `AssetResourceTest.downloadAsset_aGpxIsSavedSandboxed_neverRenderedInPlace` et
  `downloadAsset_anSvgStoredBeforeTheFix_isSavedSandboxed`, `FileTypeDetectorTest.ActiveDocuments`
  et `FileTypeCategoryTest`.

- `SEC-3` **Le jeton d'accès mobile ne part plus que vers l'API : H4** (2026-09-30, contrat
  inchangé) — l'app mobile posait son `Authorization: Bearer` sur toute image qu'elle chargeait,
  quel que soit son hôte, et une image de markdown pointe où son auteur le veut. Désormais le jeton
  ne part que vers l'**origine** de l'API — même schéma, même hôte, même port que `API_BASE_URL`
  (`mobile/lib/api/credential_scope.dart`, `carriesCredentials` et `authHeadersFor`) : les trois
  chargeurs d'`authenticated_image.dart` et l'intercepteur Dio (`AuthInterceptor`) passent par elle,
  et un 401 venu d'un autre hôte ne déclenche plus de rafraîchissement, dont le nouvel essai aurait
  porté le jeton neuf là-bas. **Décisions** (choisies par l'utilisateur) : une image externe
  s'affiche quand même, sans jeton, comme sur le web ; l'hôte seul ne suffit pas, un `http://` vers
  le même hôte ferait circuler le jeton en clair. Ne jamais reposer l'en-tête à la main hors de ces
  deux fonctions. Tests : `test/api/credential_scope_test.dart`. Livré avant la republication
  mobile qu'impose `SEC-2`.

- `SEC-2` **Un appareil n'est appairé que sur un « Autoriser » explicite : H3** (2026-09-30,
  **API 8.0.0**, contrat cassant) — la page d'appairage (`/karoo`, `/garmin`), sur le web comme
  dans l'app, autorisait l'appareil d'elle-même dès qu'un utilisateur connecté l'ouvrait avec un
  code valide. Elle affiche désormais une carte de confirmation (RFC 8628 §5.4) : l'appareil
  (« un Karoo », « un appareil Garmin »), le compte, le code en grand, depuis quand il a été demandé,
  un avertissement (« si quelqu'un vous a envoyé ce lien, refusez »), et deux boutons. Côté serveur,
  `CompleteRequest` exige `confirmed: true` (`@NotNull @AssertTrue`) : un client ancien qui
  approuvait seul reçoit 400 au lieu d'appairer. `VerifyResponse` gagne `clientId` et
  `requestedAt`. Nouveau `POST /api/device/oauth/deny` : le code **expire** (plutôt que d'être
  supprimé), si bien que l'appareil qui interroge `/token` entend `TOKEN_EXPIRED`, que Karoo et
  Garmin traitent déjà en recommençant — ni la requête ni la réponse de `/device` et `/token`
  n'ont changé, les deux apps d'appareil n'ont pas à être republiées ; `/deny` compte les codes
  inconnus comme `/complete` (`SEC-4`). Décisions de l'utilisateur à garder : garde **à la fois**
  dans l'interface et sur le serveur ; le code du lien reste pré-rempli, confirmé par un bouton
  (pas de ressaisie, qui ôterait son intérêt au QR code). **Contrat cassant : le mobile doit être
  republié en même temps que le backend.** Tests : `DeviceOAuthConfirmationTest` (sans
  confirmation ou `false` refusé et rien d'appairé, confirmé appairé, `verify` nomme l'appareil et
  l'heure, refus qui fait expirer le code pour tous, code inconnu, refus anonyme) — **écrits sans
  avoir été lancés** ; `DeviceOAuthThrottleTest` adapté ; e2e `flow-device.e2e.ts` (confirmation
  attendue après connexion, aucun `/complete` avant le clic, nouveau test du refus) et Patrol
  (`device_link_test`, `device_link_signed_out_test`, `device_manual_code_test`, étape
  `authorize()`) — **non lancés**.

- `SEC-17` **Le jeton du flux ICS meurt après 90 jours de silence** (2026-09-30, contrat
  inchangé, migration `V51__calendar_token_last_used`) — il n'expirait jamais. Chaque consultation
  du flux (`/api/calendar/ics`, `/api/teams/{slug}/calendar/ics`) note `last_used_at`, au plus une
  fois par jour et par une requête `update` qui ne touche pas la version de la ligne (deux
  applications qui interrogent le même flux ne se heurtent pas au verrou optimiste) ; un jeton
  dont la dernière consultation, ou à défaut la création, date de plus de
  `pedalons.calendar.token.inactivity-days` (90) est refusé comme un jeton inconnu (403), effacé
  par `AuthCleanupScheduler`, et `GET /api/calendar/token` en crée un neuf plutôt que d'afficher
  une adresse morte. Politique choisie par l'utilisateur : **l'inactivité**, pas une durée fixe ni
  une rotation — une application de calendrier interroge son abonnement indéfiniment et ne peut
  pas apprendre une nouvelle adresse, donc une échéance fixe couperait sans prévenir les
  abonnements vivants ; seul le jeton que plus personne ne consulte meurt. Ne pas y revenir sans
  prévoir d'avertir l'utilisateur. La migration donne à tout jeton existant une période neuve à la
  date du déploiement (aucun abonnement coupé) ; la colonne est nullable pour la version
  précédente, et `null` vaut la date de création. Politique de confidentialité (§1, §4, §6) et
  `OPERATIONS.md` mises à jour. Tests : `CalendarResourceTest`, bloc « Token inactivity » (jeton
  silencieux refusé sur les deux flux, jeton jamais consulté daté de sa création, vieux jeton
  toujours consulté vivant et marqué, marquage au plus quotidien, jeton mort remplacé, purge
  sélective) — **écrits sans avoir été lancés**.

- `SEC-7` **La connexion par mot de passe se ferme après cinq échecs : M4** (2026-09-30, API
  6.4.0, mineur : `LOGIN_RATE_LIMITED`, réponse 429 sur `POST /api/auth/login` ; migration
  `V50__auth_failures`) — chaque mot de passe erroné, adresse inconnue comprise, est noté dans
  `auth_failures` (`AuthThrottle`) ; au cinquième en 15 minutes pour une adresse, `/login` répond
  `429 LOGIN_RATE_LIMITED` avec `Retry-After: 900`, **avant** tout bcrypt : la rafale ne coûte plus
  de CPU. Un bon mot de passe efface les échecs de l'adresse. Décisions à garder : le compteur est
  **par adresse** (casse ignorée), jamais par IP — le premier `X-Forwarded-For` est celui que le
  client envoie (`forwardedHeaders.insecure`), une limite par IP n'arrêterait que les attaquants
  honnêtes ; il compte aussi les adresses sans compte, sinon la limite dirait lesquelles existent ;
  la table ne garde qu'une **empreinte SHA-256** de l'adresse, 24 heures (purge dans
  `AuthCleanupScheduler`, annoncée par la politique de confidentialité, §1, §6, §9) ; l'échec est
  écrit dans sa **propre transaction** (`QuarkusTransaction.requiringNew`), sans quoi le rollback de
  l'erreur l'effacerait ; en base et non en mémoire, puisque deux backends coexistent pendant un
  déploiement. Le prix assumé : un tiers peut fermer 15 minutes la connexion *par mot de passe*
  d'une adresse — le code par e-mail et les passkeys restent ouverts. Reste hors de portée le
  bourrage d'identifiants réparti sur beaucoup d'adresses : c'est la limite globale de M10
  (`SEC-28`). Tests : `AuthResourceTest` (bloc « Password throttle » : refus même avec le bon mot de
  passe, casse, adresse inconnue, remise à zéro, indépendance des adresses) — **écrits sans avoir
  été lancés**. Seuils réglables : `pedalons.auth.password.max-failures`,
  `…failure-window-minutes`.

- `SEC-4` **Les codes d'appairage ne se devinent plus : H5** (2026-09-30, API 6.4.0, mineur :
  `DEVICE_CODE_RATE_LIMITED`, réponse 429 sur `POST /api/device/oauth/complete` et
  `GET /api/device/oauth/verify` ; même table que `SEC-7`) — un code à 6 caractères (32⁶) se
  devinait sans limite : par `/complete` pour rattacher l'appareil d'un autre à son compte, ou par
  `/verify`, anonyme, qui révélait les codes en attente. Chaque code inconnu compte désormais contre
  le compte (5 en 10 minutes, durée de vie d'un code) et contre le **domaine entier** (300 en
  10 minutes, signés ou non) ; au-delà, 429 avant la recherche. Le budget par domaine est ce qui
  arrête une foule de comptes jetables — et `/verify`, qui n'a pas d'autre clé fiable ; son prix,
  assumé : une rafale ferme l'appairage du domaine le temps que la fenêtre glisse (300 essais
  trouvent un code donné une fois sur 3,5 millions de fenêtres). `/verify` filtre en outre par
  domaine (`DeviceCodeRepository.findValidByUserCode(domainId, …)`) : le code d'un autre site y
  répondait. `/token` n'est pas freiné (`device_code` de 256 bits) : pas de `slow_down`, voir
  `AUD-27`. Tests : `DeviceOAuthThrottleTest` (limite par compte même avec le bon code, codes justes
  jamais comptés, budget du domaine sur `/verify` puis `/complete`, budget propre à chaque domaine,
  code d'un autre domaine inconnu) — **écrits sans avoir été lancés**. Seuils :
  `pedalons.auth.device-code.*`.

- `SEC-9` **Un lien de vérification ne connecte plus personne à lui seul : M5** (2026-09-30,
  **API 7.0.0**, livré avec `SEC-24`) — charger la page d'un lien d'inscription ouvrait une session
  sur le compte du lien : l'attaquant qui transmettait **son** lien connectait sa victime à son compte
  (qui y enregistrait ensuite passkey, sorties, connexions GPS). Désormais la page **lit** le lien sans
  le consommer (`POST /api/auth/verify-email/preview` → `EmailLinkPreviewResponse` : adresse et
  `EmailLinkKind`), **montre l'adresse**, et n'active le compte qu'au clic, mot de passe choisi (voir
  `SEC-24`). Si un autre compte est connecté, la page le dit avant de basculer. La porte voisine était
  la même faille : le lien de **changement d'adresse** ouvrait lui aussi une session ; il passe par
  `POST /api/auth/confirm-email-change` (204) qui applique l'adresse **sans session** — un client
  connecté relit seulement son profil. Chaque endpoint refuse le jeton de l'autre, et un lien n'est
  valable que sur le site qui l'a émis (`AuthTokenRepository.findValidByTokenHashAndDomain`).
  **Décisions** : aucune requête au chargement de la page ne doit ouvrir de session ; ne pas
  réintroduire l'appel automatique à l'activation. Reste une victime qui ignorerait l'adresse
  affichée et choisirait un mot de passe pour le compte d'un autre — assumé, l'adresse est en tête de
  page. Tests : `AuthResourceTest` (`preview_showsTheAddress_opensNoSession_andSpendsNothing`,
  `…_ofALinkFromAnotherSite_isRefused`, `confirmEmailChange_changesTheAddress_andOpensNoSession`,
  `eachLinkOpensOnlyItsOwnDoor`), `flow-account.e2e.ts` (« a sign-up link opened while signed in
  shows its address, warns, and changes nothing until clicked »), `verify_email_page_test.dart`,
  Patrol `sign_up_verify_test`. **Contrat cassant : le mobile doit être republié en même temps que le
  déploiement** (une app antérieure ne sait plus activer un compte).

- `SEC-24` **Le mot de passe se choisit sur la page du lien, plus à l'inscription : L4**
  (2026-09-30, **API 7.0.0**, scindé de `SEC-12`, livré avec `SEC-9`) — n'importe qui pouvait
  s'inscrire avec l'adresse d'un autre en choisissant le mot de passe : si le propriétaire cliquait le
  lien reçu, le compte naissait avec le mot de passe de l'attaquant. `RegisterRequest` perd
  `password` ; `POST /api/auth/verify-email` prend `ActivateAccountRequest` (`token`, `password`) et
  ouvre la session (`AuthService.activateAccount`). Le mot de passe vient donc de qui tient la boîte
  aux lettres. Web (`LoginPage`, `VerifyEmailPage`) et mobile (`login_page.dart`,
  `verify_email_page.dart`) déplacent les deux champs. La colonne `pending_password_hash` n'est plus
  écrite mais reste, pour le déploiement progressif et les liens émis avant — `activateAccount`
  ignore leur hachage ; le champ a été retiré en 10.0.0 (`API-57`), la colonne ensuite par `V54` (`API-58`). La politique de confidentialité (§1, liens envoyés
  par e-mail) ne dit plus qu'un mot de passe haché est gardé en attente, en parité FR/EN.
  **Décision** : ne jamais recréer un compte avec un mot de passe venu de l'inscription. Tests :
  `AuthResourceTest.verifyEmail_setsThePasswordChosenOnActivation_neverTheOneFromSignUp` (un jeton
  d'avant portant un hachage : l'ancien mot de passe est refusé, le nouveau ouvre la session ;
  devenu `verifyEmail_setsThePasswordChosenOnActivation` sous `API-57`, le hachage n'étant plus
  mappé),
  `register_storesNoPassword`, `verifyEmail_withoutAPassword_isRefusedAndSpendsNothing`.
  Trois scénarios e2e restés sur l'ancien parcours (texte « activer votre compte », champs de mot
  de passe à l'inscription) ont été remis au nouveau le 2026-09-30 : `flow-account.e2e.ts`
  (inscription puis connexion, nouvel essai après un e-mail non parti) et `invitations.e2e.ts`
  (inscription depuis une invitation, mot de passe choisi sur la page du lien).

- `SEC-23` **Les échecs de connexion sont journalisés : L14** (2026-09-30, contrat inchangé,
  scindé de `SEC-12`) — chaque échec de connexion par mot de passe, code OTP ou passkey écrit une
  ligne `WARN` `Login failed method=… reason=… email=… domain=… ip=…` (`AuthService.logFailedLogin`),
  que Loki garde 14 jours : `{stack="pedalons-prod", service="backend"} |= "Login failed"`. Le motif
  distingue ce que la réponse au visiteur confond à dessein (`unknown_account`, `no_password`,
  `wrong_password` ; `no_valid_code`, `wrong_code` ; pour une passkey, le code d'erreur, sans
  adresse). **Jamais le mot de passe ni le code dans cette ligne** : la politique de confidentialité
  promet qu'aucun identifiant de connexion n'est écrit dans les journaux (elle annonce déjà « parfois
  votre adresse e-mail » et l'IP). L'IP est celle que lit `AuthResource.getClientIp`, donc aussi
  fiable que les en-têtes `X-Forwarded-*` (V3, `SEC-16`). Journaliser ne limite rien : la limitation
  reste `SEC-7`. Tests : `AuthServiceTest` (`…_logsTheFailureWithout…`, `…_unknownAccount_isLoggedToo`,
  `…_success_logsNoFailure`, `…_unknownCredential_isLogged`), qui capturent le journal de
  `AuthService`. **La ligne ne touche jamais la base** : chaque méthode résout le domaine *avant*
  la vérification qui peut échouer et le passe à `logFailedLogin`. Une passkey refusée laisse la
  transaction inutilisable, et résoudre le domaine après coup changeait le 403 en 500 — couvert par
  `PasskeyResourceTest.authenticate_withInvalidCredential_shouldReturn403` (les tests de service
  fixent le domaine d'avance et ne pouvaient pas le voir).

- `SEC-19` **Le markdown d'un contenu est borné à 100 000 caractères** (2026-09-30, audit M6,
  API 6.3.0, mineur : `maxLength` ajouté) — `MediaDto.markdown` (publications, sorties,
  parcours, voyages et étapes, pages, annonces, équipes) et `RideTemplateRequest.markdown` portent
  `@Size(max = MediaDto.MAX_MARKDOWN_LENGTH)` ; au-delà, `400 VALIDATION` sur le champ `markdown`.
  Seul le corps de requête (100 Mo) bornait jusque-là ce que le filtre de publication et la lecture
  des directives parcouraient : l'expression de `SEC-10` est linéaire, cette borne est la défense de
  fond. Les réponses ne sont pas validées (ni côté serveur ni par les schémas zod du web, qui ne
  servent qu'aux formulaires) : un contenu plus long déjà en base reste lisible, il ne se
  réenregistre qu'une fois raccourci. Mesuré sur la base locale (restauration biketeam) : 4 342
  caractères au plus — **à revérifier en production avant de déployer**
  (`select max(length(markdown)) from team_entities` et `ride_templates`). Ne pas relever la borne
  sans raison : elle est partagée par les deux champs via la constante. Tests :
  `PostResourceTest.createPost_markdownPastTheBound_shouldReturn400` (la borne passe, un caractère
  de plus est refusé) et `RideTemplateResourceTest.createTemplate_markdownPastTheBound_shouldReturn400`
  — **écrits sans avoir été lancés**.

- `SEC-22` **Recherches sans jokers, nom de fichier d'appareil sûr : L12 et L13** (2026-09-30,
  contrat inchangé, scindé de `SEC-12`) — **L12** : les cinq recherches qui bâtissaient un motif
  `LIKE` à partir de la saisie (`SearchClause`, donc publications, annonces, parcours… ;
  trombinoscope, lieux, gabarits de sortie, comptes de l'admin plateforme) passent par
  `LikePatterns.contains`, qui échappe `%`, `_` et le caractère d'échappement lui-même avec `!`,
  déclaré par `escape '!'` (`LikePatterns.ESCAPE`) dans chaque clause. `%` renvoyait tout, `_`
  n'importe quel caractère. **Ne pas compter sur l'échappement par défaut de PostgreSQL** (la barre
  oblique inverse) : essayé d'abord, il n'est pas en vigueur dans le SQL que génère Hibernate — un
  `%` littéral n'était plus trouvé du tout. Toute nouvelle clause qui prend un motif de
  `LikePatterns` doit porter `ESCAPE`. **L13** : `DeviceRoutesResource` construit le nom du fichier
  FIT/GPX de `Content-Disposition` à partir du slug de l'URL ; il est ramené à `[a-zA-Z0-9._-]`
  (un vrai slug n'y perd rien). Test : `search-wildcards.e2e.ts` (vu échouer avant le correctif :
  `%` et `_` sur le trombinoscope, `_` et `100%` sur les publications, recherche ordinaire
  intacte) ; les suites de listes, filtres, pagination, trombinoscope, admin plateforme et
  appareils passent (169 tests). L13 n'a pas de test dédié.

- `SEC-20` **Six constats faibles de l'audit corrigés : L1, L5, L6, L7, L8, L9** (2026-09-30,
  contrat inchangé, scindé de `SEC-12`, qui garde le reste) —
  - **L1** : `AuthService.resetPassword` révoque toutes les sessions du compte (navigateurs, app,
    appareils GPS appairés) avant d'ouvrir celle du navigateur qui réinitialise. Avant, pas après :
    la mise à jour en masse la révoquerait aussi. La politique (§6, sessions d'un appareil GPS) le
    dit, en parité FR/EN.
  - **L5** : `AssetAccessChecker` exige que l'asset appartienne à l'équipe que nomme l'URL, résolue
    sur le site courant (redirections de slug comprises). L'identifiant seul atteignait l'asset
    d'un autre site — et, pire que ce que disait l'audit, la suppression vérifiait le rôle de
    l'appelant dans l'équipe **de l'URL**, pas dans celle de l'asset.
  - **L6** : `TeamMembershipService.addMember` cherche la cible par `findActiveByIdAndDomain` :
    un compte d'un autre site répond le même 404 qu'un identifiant inconnu.
  - **L7** : `server.js` insère le rendu, l'état déshydraté, la session et le bloc `<head>` par des
    fonctions de remplacement. Une chaîne interprétait `` $` ``, `$'` et `$&` : un titre qui en
    contenait dupliquait le gabarit dans la page (reproduit : 12 `<!DOCTYPE html>` dans un
    document). React échappe `'` mais pas le backtick, et le JSON de l'état n'échappe ni l'un ni
    l'autre.
  - **L8** : le callback OAuth des services GPS ne recopie plus l'`error` du fournisseur dans sa
    redirection : `access_denied` ou `provider_error` (aucun client ne lit la valeur).
  - **L9** : le nom de fichier de `AssetDto.url` est encodé comme un segment de chemin
    (`AssetService.encodePathSegment`) ; le téléchargement l'ignore, mais un `?`, un `#` ou un `/`
    coupaient l'URL.

  Tests (suite e2e, passée : 271 tests sur les specs concernées) : `ssr-session.e2e.ts` « user
  content holding $` and $' is rendered as text » (L7, vu échouer avant le correctif) ;
  `flow-account.e2e.ts` « forgotten password », qui vérifie désormais que la session ouverte avant
  la réinitialisation ne se rafraîchit plus (L1). L5, L6, L8 et L9 n'ont pas de test dédié ; les
  suites multi-tenant, équipe, publications et parcours passent.

- `SEC-21` **Deux points informationnels de l'audit corrigés** (2026-09-30, scindé de `SEC-14`,
  qui garde les images externes) — le `DocumentBuilderFactory` de `GarminCourseConverter` refuse
  tout DOCTYPE (donc toute entité externe), sans XInclude ni expansion d'entités : l'entrée est un
  GPX que nous écrivons, qui n'en a pas ; et `DeviceVerifyPage` encode le code saisi
  (`encodeURIComponent`). Couvert par `flow-device.e2e.ts` (passé) pour le second ; pas de test du
  premier (l'envoi vers Garmin n'est pas exercé en e2e).

- `SEC-10` **L'expression régulière des directives d'image est linéaire** (2026-09-30, audit M6,
  contrat inchangé) — `AssetService` repérait les `::asset{…}` du markdown, à chaque enregistrement
  d'un contenu, par un motif qui cherchait `id="…"` entre deux suites gourmandes : sur une suite de
  directives non fermées, son temps croissait au cube de la longueur (mesuré : 7 Ko, 0,9 s ; 14 Ko,
  7,4 s ; 28 Ko, 78 s de CPU par requête). Le motif est désormais possessif et arrêté par une
  accolade ouvrante comme par la fermante (`::asset\{([^{}]*+)\}`), l'`id` étant lu à part dans
  les attributs — le dernier, comme avant. 280 Ko piégés : 12 ms. Même garde sur le motif
  d'`MarkdownExcerpt`, qui était quadratique. Ne pas revenir à un motif qui cherche l'attribut dans
  la directive d'un seul tenant. Reste la borne de taille du markdown : `SEC-19`. Test :
  `AssetMarkdownDirectiveTest` (identifiants lus, directive non fermée ignorée, dernier `id` gardé,
  entrée piège sous 2 s) — **écrit sans avoir été lancé** (`mvn test
  -Dtest=AssetMarkdownDirectiveTest,MarkdownExcerptTest`) ; la logique a été vérifiée à la main
  sur les classes compilées.

- `SEC-15` **Reliquat V2 (comptes rattachés par l'ancien import biketeam) : sans objet**
  (2026-09-29) — vérifié en staging et en prod : aucun compte venu de l'import (ni adresse factice,
  ni compte non vérifié, aucune ligne `USER` dans `biketeam_migration_map`) ; les bases sont
  reparties de zéro depuis l'import par dump, retiré par `d93fd3af`. Même constat que `LEGAL-1`.

- `SEC-18` **Le filtre de rôle du trombinoscope révélait des rôles masqués** (2026-09-30, **API
  5.7.1**, hors audit) — relevé en livrant `WEB-1`. Quand la réponse masque les rôles (un lecteur
  que `API-39` n'autorise pas à les voir), `GET /api/teams/{slug}/members` refuse désormais le
  paramètre `role` par un 403 `FORBIDDEN` (`TeamMembershipService.getTeamMembers`), comme tout ce
  que ce lecteur ne peut pas faire, au lieu de l'appliquer ; seuls la description du paramètre et
  celle du 403 changent au contrat, d'où le correctif. Le filtre reste ouvert à qui reçoit les
  rôles (admin d'équipe ou de plateforme, ou trombinoscope ouvert). Les deux clients ne le proposent
  plus dans ce cas : le web ne l'affichait déjà pas (`TeamDirectoryPage`), le mobile masque ses
  chips de rôle (`TeamMembersPage.rolesShown`). Couvert par
  `TeamMembershipServiceTest.getTeamMembers_roleFilter_isRefused_whenTheRolesAreHidden` (refus,
  et le même filtre accepté pour l'admin) et `getTeamMembers_roleFilter_works_onceTheDirectoryIsOpen`,
  et côté mobile par `team_members_page_test.dart` (« sans les rôles, aucune chip de rôle »). Ne pas
  remplacer le refus par un filtre ignoré en silence : un résultat filtré « pour rien » se lit comme
  une réponse.

---

## AUD — Audit d'infrastructure de février

Les lignes corrigées avant l'ouverture du ledger sont cochées dans
[`plans/2026-02-14-project-audit.md`](plans/2026-02-14-project-audit.md), qui porte aussi le ✅ de
celles d'ici. Même colonnes que la table de `LEDGER_NEXT.md`, le constat remplacé par ce qui a été
fait.

| ID | Thème | Audit | Gravité | Livré |
|---|---|---|---|---|
| `AUD-2` | CI/CD | I4 | Critique | **Retour arrière par version** (2026-09-29) — les hôtes passent en Docker Swarm mono-nœud. `./build.sh` tague chaque image `${ENV_NAME}-<sha12>`, jamais déplacé, en plus de l'alias `${ENV_NAME}` du poste (depuis un arbre modifié, l'alias seul) ; `scripts/deploy.sh` déploie le tag du commit extrait (`--rev` pour un build antérieur), garde les cinq derniers builds par image et attend la fin du rollout, en erreur sur un rollback ou au bout de `DEPLOY_TIMEOUT`. backend et frontend roulent en start-first avec healthcheck et `failure_action: rollback` ; `docker service rollback` revient à la spec précédente. Pas de registry : sur un seul nœud, les images locales suffisent. Conséquence à ne pas défaire : pendant une minute deux backends partagent la base — migrations Flyway rétrocompatibles, tâches planifiées idempotentes ou réclamant leur travail en base (`PublicationPublishScheduler` réclame chaque brouillon par un update conditionnel sur la version, `AllPublicationRepositoryTest`). Procédure dans [`OPERATIONS.md`](OPERATIONS.md#rolling-updates-and-rollback) |
| `AUD-3` | CI/CD | — | — | **La suite e2e tourne en CI** (2026-09-30) — `.github/workflows/e2e.yml`, **la nuit sur develop** (02:17 UTC) **et à la main** (`workflow_dispatch`), jamais sur les PR : trop longue pour les bloquer, et un test intermittent (« signing up with an address that has an account » est déjà tombé sous charge) n'y bloque personne à tort. Runner GitHub hébergé (`ubuntu-latest`, gratuit sur un dépôt public, jetable : aucun accès à l'infra ni à la base locale) ; pas de runner auto-hébergé, qui exécuterait le code d'une PR externe chez nous. Le job construit les deux images (`scripts/e2e.sh build all`) et démarre la pile `tribly-e2e` par `scripts/e2e.sh up`, base vide, suite complète sur les deux projets, une relance par test (`retries` sous `CI`) ; rapport, traces et journaux de la pile en artefact sur échec (14 jours). **Aucun secret** : `.env.e2e` est jetable et commité, la paire JWT générée dans le job. **Aucun mail ne sort** : une première étape échoue si `.env.e2e` ne pointe pas le mailer sur `mailpit` ou si l'overlay ne donne plus `.env.e2e` seul au backend. Sans valhalla (17 Go de tuiles), `E2E_NO_ROUTING` fait écarter `gpx-planner.e2e.ts` par `playwright.config.ts` ; le fond de carte est déjà simulé par les tests. `.e2e/` est créé et cédé à l'UID 1000 avant `up` : le backend tourne en `PUID` 1000, pas l'utilisateur du runner. **Pas encore vu tourner** : `workflow_dispatch` n'existe qu'une fois le fichier sur la branche par défaut — au premier run, surveiller la durée (`timeout-minutes: 120`) et les tests intermittents. Pendant mobile : `MOB-37` |
| `AUD-4` | CI/CD | I9 | Important | **Même Node en CI que dans l'image** (2026-09-30) — la CI installait Node 24, l'image du frontend tourne sur `node:26.9.0-alpine`. Le Dockerfile fait référence : `frontend/.nvmrc` porte `26.9.0`, et `ci.yml` le lit (`node-version-file`) au lieu d'une version en dur ; le Dockerfile rappelle de changer les deux ensemble (ses deux `FROM`). Pas de champ `engines` : il n'est lu nulle part en CI ni dans l'image, et ne ferait qu'avertir en poste de travail ; `packageManager` (`pnpm@11.20.0`) était déjà la seule source de pnpm, pour la CI (`pnpm/action-setup`) comme pour l'image (corepack). Pas de test : la CI elle-même, au prochain passage |
| `AUD-5` | Docker | I5 | Critique | **Un healthcheck sur chaque service** (2026-09-30) — minio, imgproxy, varnish et traefik rejoignent backend, frontend et postgres, chacun avec l'outil que son image embarque déjà : `mc ready local` (l'alias `local` est livré avec l'image `pgsty/minio`), `imgproxy health`, `varnishadm ping` (le socket de gestion du `varnishd` en cours, dans le répertoire de travail par défaut, qu'il soit en tmpfs sous compose ou dans l'image sous Swarm), `traefik healthcheck --ping`. traefik prend `--ping=true`, sur son entrypoint interne `:8080`, ni publié ni routé — **jamais sur `web`**, que Caddy ouvre à tout Internet ; les deux overlays (`docker-compose.local.yml`, `docker-compose.e2e.yml`), qui remplacent sa commande, le répètent. 10 s d'intervalle, 3 essais, 10 à 20 s de `start_period`. Sous Swarm, une tâche qui échoue son healthcheck est remplacée : c'est le gain, et le risque si une commande est fausse. Vérifié sur la pile e2e (les quatre `healthy`, `smoke.e2e.ts` et les tests d'avatar, qui passent par MinIO → imgproxy → varnish, verts) et par `docker stack config` ; **pas encore vu sous Swarm** — au premier `deploy.sh`, regarder `docker service ps` des quatre services. Pas de test automatisé |
| `AUD-31` | Garmin | G6 | Important | **Le Makefile Garmin ne nomme plus de version du SDK** (2026-09-30, scindé de `AUD-27`) — `simulator-docker` et `run-docker` appelaient `connectiq-sdk-lin-8.4.0-2025-12-03-5122605dc` en dur. `DOCKER_CIQ_HOME` prend le nom du répertoire du SDK détecté (`CIQ_HOME`, déjà utilisé par les cibles natives) sous le point de montage du conteneur, `/root/.Garmin/ConnectIQ/Sdks/`. Vérifié par `make -n` avec le SDK installé et avec un `CIQ_HOME` fictif en 9.0.0. Pas de test automatisé |
| `AUD-32` | Karoo | K13 | Mineur | **`navigation-compose` retiré** (2026-09-30, scindé de `AUD-24`) — déclaré dans `app/build.gradle.kts` et `gradle/libs.versions.toml`, importé nulle part (ni `NavHost` ni `androidx.navigation`). À redéclarer le jour où le découpage de `MainActivity` (`AUD-22`) en fait usage. Vérifié : `./gradlew assembleDebug` et `testDebugUnitTest` passent |
| `AUD-7` | Docker | I14 | Important | **Limites mémoire** (2026-09-29) — chaque service de `docker-compose.yml` porte `deploy.resources.limits.memory`, appliqué par Swarm comme par compose : backend `BACKEND_MEMORY` (1536M), varnish `VARNISH_MEMORY` (1536M), imgproxy 1536M, postgres et minio 1G, frontend 512M, traefik 256M ; le tileserver de la stack partagée 3G. Le heap du backend n'a **pas de `-Xmx`** : l'entrypoint `run-java.sh` de l'image Jib (`ubi9/openjdk-25-runtime`) passe `-XX:MaxRAMPercentage=$JAVA_MAX_MEM_RATIO`, que `application.properties` fixe à 60 dans l'image (`quarkus.jib.environment-variables`, avec `GC_MAX_METASPACE_SIZE=256`) — sans limite, ce même entrypoint prenait 80 % de la RAM de l'hôte, ~24 Go mesurés sur un poste de 30 Go. Le cache Varnish, en mémoire (malloc), passe de 20G sans limite à `VARNISH_SIZE` 1G par défaut ; imgproxy est plafonné à 4 images simultanées (`IMGPROXY_WORKERS`, au lieu de deux par CPU de l'hôte) pour que sa limite tienne. À ne pas défaire : pas de `-Xmx` en dur (il faudrait le tenir à la main en phase avec la limite), ni de ratio à 80 (le non-heap — metaspace ~115 Mo mesurés, threads, buffers Netty, runtime ONNX de Magika — n'y tiendrait plus, et un kill par le cgroup ne passe pas par `ExitOnOutOfMemoryError`) ; pas de limite sur valhalla, dont le rebuild en demande bien plus que le service. Pas de test : `docker compose config` et `docker stack config` acceptent les deux fichiers. Tableau et budget d'un hôte dans [`OPERATIONS.md`](OPERATIONS.md#memory). La limite CPU reste ouverte (`AUD-30`) |
| `AUD-11` | Observabilité | I6 | Critique | **Métriques** (2026-09-29) — une stack `pedalons-monitoring` (`docker-compose.monitoring.yml`), déployée depuis `~/shared` par `scripts/deploy.sh --monitoring` : Prometheus (15 jours, 4 Go au plus), node-exporter, cAdvisor, Grafana et son tableau de bord « Pédalons — vue d'ensemble » provisionné depuis le dépôt (`services/monitoring/grafana/`). Le backend expose `/q/metrics` (`quarkus-micrometer-registry-prometheus`, pool Agroal compris par `quarkus.datasource.metrics.enabled`) ; Prometheus trouve chaque tâche backend de chaque environnement par l'API Swarm, sur `pedalons-shared`, étiquetée `env` du nom de la stack — un nouvel environnement ne demande aucun changement. Le trafic se mesure chez **Caddy** (`metrics { per_host }`, site `:2020`), seul point d'entrée de tous les environnements, pas chez traefik. À ne pas défaire : `/q` n'est pas routé par traefik, ce qui garde `/q/metrics` privé — ne pas y ajouter de route ; Grafana n'est publié que derrière la règle `DOCKER-USER` de `MONITORING_PORTS` (Swarm publie sur toutes les interfaces), et le port de métriques de Caddy derrière celle d'`HOST_PORTS` — jamais l'admin `:2019`, qui réécrit la configuration. Pas de test automatisé du déploiement : configurations validées par `promtool check config`, `amtool check-config`, `loki -verify-config`, `alloy validate` et `docker stack config`, et la chaîne Loki/Alloy/Grafana essayée hors Swarm. Mise en service sur l'hôte : `OPS-22` ; ce qui reste hors champ (PostgreSQL, frontend, erreurs client) : `OPS-21`. Procédure dans [`OPERATIONS.md`](OPERATIONS.md#monitoring) |
| `AUD-12` | Observabilité | I7 | Critique | **Alertes** (2026-09-29) — Alertmanager envoie par courriel (`ALERT_SMTP_*`) onze règles de `services/monitoring/prometheus/rules/pedalons.yml` (5xx et latence par site vus de Caddy, OOM, conteneur près de sa limite mémoire, disque, mémoire de l'hôte, heap après GC, pool de connexions saturé, cible injoignable) et une règle de journaux évaluée par Loki (`BackendErrors`). Deux pièces **hors de l'hôte**, parce qu'une alerte levée sur un hôte tombé n'en sort pas : l'alerte `Watchdog`, toujours active, pingue Healthchecks toutes les 5 minutes, qui écrit quand elle cesse ; Gatus, sur l'hôte de sauvegarde (`services/monitoring/gatus/`), sonde l'API, l'accueil, la redirection du domaine nu et staging, et l'expiration des certificats. Les sauvegardes n'y sont pas : leur propre check Healthchecks les couvre déjà. Alertmanager ne lit pas l'environnement : `deploy.sh` rend sa configuration dans `data/monitoring/` et y écrit le mot de passe SMTP et l'URL de ping **en fichiers** (`smtp_auth_password_file`, `url_file`), pour qu'aucune valeur ne casse le YAML. Couvert par `services/monitoring/prometheus/tests/pedalons.test.yml` (`promtool test rules` : les rapports dont les deux membres doivent partager leurs labels, faute de quoi l'alerte ne se déclenche jamais) ; Gatus essayé contre les vrais sites, quatre succès |
| `AUD-13` | Observabilité | §9.3 | — | **Journaux JSON centralisés** (2026-09-29) — le backend journalise en JSON en `%prod` (`quarkus-logging-json`, `quarkus.log.console.json.enabled` faux hors `%prod`), une entrée par événement, trace de pile comprise. Alloy envoie à Loki les journaux de tous les conteneurs de toutes les stacks (labels `stack`, `service`, et `level` pour le backend) et les journaux d'accès de Caddy, **lus tels que Caddy les écrit, donc déjà filtrés** (`OPS-6`). À ne pas défaire : la rétention de Loki est de **14 jours**, la promesse de la politique de confidentialité pour le journal d'accès — ne pas la relever, et ne jamais brancher Alloy sur une source non filtrée ; peu de labels (ni statut, ni chemin, ni utilisateur), le reste se cherche dans la ligne avec `\| json`. Conséquence acceptée : la pile complète d'un poste de travail tourne en `%prod`, donc journalise aussi en JSON. Essayé hors Swarm : un conteneur étiqueté comme une tâche Swarm et un fichier d'accès Caddy arrivent dans Loki avec les labels attendus, la règle du ruler est chargée |
| `AUD-14` | Backend | B4 | Important | **`@Transactional` retiré des resources** (2026-09-30) — il était posé sur dix classes de `api/` : au niveau de la classe sur les quatre `*CommentResource`, sur la méthode de mise à jour de `RideResource`, `PostResource`, `TripResource`, `AdResource`, `TeamResource` et `TeamMemberResource`. Chacune de ces méthodes n'appelle **qu'une** méthode de service, elle-même `@Transactional` et qui construit son DTO dans la transaction (`CommentService.listComments`/`createComment`/`deleteComment`, `RideService.updateRide`, `PostService.updatePost`, `TripService.updateTrip`, `AdService.updateAd`, `TeamService.updateTeam`, `MembershipService.updateMemberRole`) : aucune ne compose plusieurs appels qui devraient être atomiques, donc aucune n'a été gardée. La frontière de transaction est la méthode de service ; une resource qui aurait besoin de plusieurs appels atomiques doit recevoir une méthode de service qui les fait, pas une transaction de resource. Deux règles d'`ArchitectureTest` le gardent (`resources_should_not_be_transactional`, `resource_methods_should_not_be_transactional`, vérifiées en réintroduisant l'annotation). Couvert par les tests de ressource des classes touchées, verts : `AdResourceTest`, les quatre `*CommentResourceTest`, `CommentPaginationTest`, `CommentCountTest`, `PostResourceTest`, `RideResourceTest`, `RideGroupLeaderTest`, `TeamMembershipResourceTest`, `TeamResourceTest`, `TripResourceTest` |
| `AUD-16` | Backend | B12 | Important | **Le device flow a ses tests backend** (2026-10-01) — `DeviceOAuthFlowTest` parcourt RFC 8628 par HTTP comme Karoo et Garmin : émission (code à six caractères sans 0/O ni 1/I, URL de vérification du domaine et de l'appareil, `expiresIn` 600, `interval` 5, `device_code` gardé seulement haché), polling `AUTHORIZATION_PENDING` répété, approbation puis échange (jetons du bon utilisateur, session `karoo Device`, jeton d'accès accepté par `/api/device/me`, refresh qui marche), `device_code` consommé une seule fois (`TOKEN_INVALID` au rejeu, aucune seconde session), code expiré avant ou après approbation (`TOKEN_EXPIRED` au polling, rien d'émis), code inconnu, `grantType` inconnu ou `deviceCode` vide, code d'un autre domaine que le compte ne peut pas approuver. Il complète `DeviceOAuthConfirmationTest` (`SEC-2`), `DeviceOAuthThrottleTest` (`SEC-4`) et `DeviceRefreshRotationTest` (`SEC-11`). **Un défaut corrigé au passage** : `completeDeviceCodeFlow` ne regardait pas si le code était déjà approuvé, si bien qu'un second compte confirmant le même code avant le polling suivant s'y substituait et l'appareil s'ouvrait sur son compte. La première approbation tient désormais jusqu'à l'échange ; le même utilisateur qui confirme deux fois reçoit 200 sans effet, un autre `TOKEN_INVALID` (400, déjà au contrat : pas de changement de version). Le site ne rappelle jamais `/complete` sur un code que `/verify` dit approuvé. À ne pas défaire : ne pas laisser une seconde approbation réécrire `user`. Écrit sans avoir été lancé : `mvn test -Dtest='DeviceOAuth*Test'`. **Suite de relecture (2026-10-01)** : la règle était un check-then-act sans verrou — deux comptes confirmant le même code au même instant lisaient tous deux `authorized = false` et le second écrasait `user`. `completeDeviceCodeFlow` lit désormais le code par `DeviceCodeRepository.findValidByUserCodeForUpdate` (`PESSIMISTIC_WRITE`, `SELECT … FOR UPDATE`, toujours filtré par `domainId`) : la seconde approbation attend la première et voit le code approuvé. À ne pas défaire : ne pas revenir à une lecture sans verrou dans ce chemin. `DeviceOAuthFlowTest`, `DeviceOAuthConfirmationTest`, `DeviceOAuthThrottleTest` lancés le 1er octobre : 28 tests verts (la concurrence elle-même n'a pas de test). |
| `AUD-17` | Backend | B15 | Mineur | **Index en double retirés** (2026-09-30) — V5 déclarait `device_code_hash` et `user_code` `UNIQUE`, ce qui crée déjà un index pour chacune (`device_codes_device_code_hash_key`, `device_codes_user_code_key`), puis ajoutait `idx_device_codes_device_code_hash` et `idx_device_codes_user_code` par-dessus. `V46__drop_redundant_device_codes_indexes.sql` les supprime (`DROP INDEX IF EXISTS`) ; `idx_device_codes_expires_at`, qui sert au ménage, reste. Ne pas les recréer : l'unicité suffit aux recherches par hash et par code. Pas de test : les tests backend montent le schéma en `drop-and-create` depuis les entités, sans Flyway, donc la migration n'y passe pas ; elle joue au prochain démarrage en production (`validate`, qui ne regarde pas les index) |
| `AUD-18` | Web | F1 | Critique | **Zoom rendu** (2026-09-30) — `maximum-scale=1.0` retiré du viewport de `frontend/index.html`, seul gabarit HTML du frontend : le SSR (`server.js`) injecte son rendu dans ce même fichier, bâti en `dist/client/index.html`. Ne pas le remettre, ni `user-scalable=no` (WCAG 1.4.4). Conséquence connue et acceptée : iOS Safari zoome sur un champ dont la police fait moins de 16 px, ce qui est le cas des champs Mantine `sm` ; la parade est une taille de police, pas un viewport bloqué. Pas de test : aucune assertion ne lit le viewport ; `pnpm typecheck`, `pnpm lint` et `npx vitest run` passent |
| `AUD-19` | Web | F7 | Important | **Lien d'évitement** (2026-09-30) — premier élément focalisable de `Layout.tsx`, libellé `nav.skipToContent` (« Aller au contenu principal » / « Skip to main content »), hors écran jusqu'au focus (`Layout.module.css`, au-dessus de l'en-tête), il cible `<main id="main-content" tabIndex={-1}>`, sans anneau puisqu'il n'est pas un contrôle. Le clic appelle `focus()` sur la cible au lieu de suivre l'ancre : un changement de hash serait lu par React Router comme une navigation POP, et `useScrollRestoration` avec. Garder le lien **premier** dans le DOM, avant l'en-tête. Couvert par `frontend/e2e/smoke.e2e.ts` (« the first Tab reaches the skip link… » : premier Tab sur le lien, Entrée met le focus sur `main`), écrit sans avoir pu être lancé — la pile e2e tourne sur des images. L'anneau de focus lui-même est `WEB-2` |
| `AUD-28` | Garmin | G11, G12 | Mineur | **Code mort retiré de l'app Garmin** (2026-09-30) — les quinze `System.println` commentés (`ApiClient.mc`, `AuthManager.mc`, `PedalonsApp.mc`) sont supprimés, et la chaîne `Back` des deux `strings.xml`, qu'aucun `Rez.Strings` ni layout ne lit (grep). `AM` et `PM` sont **gardées** alors qu'elles ne servent pas encore : `FormatUtils.mc` code `"AM"`/`"PM"` en dur, et la correction de G5 (`AUD-26`) consiste justement à lire ces deux ressources ; les retirer l'obligerait à les recréer. Ne pas les supprimer tant que `AUD-26` est ouvert. Pas de test : l'app n'en a pas ; `make build` (edge1040) passe |

---

## LEGAL — Politique de confidentialité

- `LEGAL-1` **Import biketeam et « pas de données de tiers » : sans objet** (2026-09-29) — la
  question (responsable du traitement, base légale, information des membres importés) portait sur
  les comptes créés par l'import par dump. Il n'en reste aucun : staging et prod n'ont ni compte à
  adresse factice `strava_`/`facebook_`/`google_` ni compte non vérifié, et `biketeam_migration_map`
  n'y a aucune ligne `USER` (bases reparties de zéro depuis l'import, qui a été retiré par
  `d93fd3af`). La migration en direct n'importe aucune personne ; la politique (§1 « Équipes venues
  de Biketeam », §2) ne décrit plus que ce transfert d'équipe. Si une restauration antérieure ou
  une nouvelle forme d'import ramenait des comptes de membres, la question se rouvre sous un nouvel
  identifiant.
- `LEGAL-2` **Relais des messages d'annonce : finalité et durée annoncées** (2026-09-29) — la
  politique dit au §3 « Relay messages about classified ads | Performance of contract » et au §6
  que la trace (expéditeur, annonce, date — le message n'est pas stocké) vit tant que l'annonce est
  en base, donc jusqu'à son effacement définitif. Option retenue : annoncer, pas de purge ; une
  purge raccourcirait la ligne du §6 (voir `LEGAL-12`).
- `LEGAL-3` **Position précise de l'app Garmin décrite** (2026-09-29) — §1 de la politique : lue à
  l'affichage de l'écran principal et au chargement des parcours, envoyée pour les trier par
  distance, soumise à la permission « Positioning » ; base légale au §3 (consentement, connexion
  volontaire). La phrase « we do not track your real-time location » a disparu. Qu'elle finisse
  dans les logs d'accès est `LEGAL-10`.
- `LEGAL-4` **Contenu public et non listé lisible sans compte** (2026-09-29) — §4 de la politique :
  « unlisted » lisible par quiconque a le lien, sans compte ; « public » accessible à tous, rendu
  par le serveur et indexable.
- `LEGAL-8` **Jeton de calendrier exclu de la phrase sur les hachages** (2026-09-29) — option
  « exclure » : le §9 dit que deux secrets font exception et sont stockés lisibles, dont ce jeton,
  décrit au §1 et au §4 comme une clé qui ne s'expire pas et se régénère. Le hacher reste possible
  (l'URL ne se réafficherait plus) ; son expiration est `SEC-17`.
- `LEGAL-5` **Services push des navigateurs : destinataires, pas sous-traitants** (2026-09-29) —
  §4, nouvelle sous-section « Services push des navigateurs » : Google (Chrome), Mozilla (Firefox),
  Apple (Safari), Microsoft (Edge) remettent la notification web ; c'est le navigateur qui choisit
  le service, qui ne reçoit que le message chiffré (RFC 8291), l'adresse d'abonnement et l'IP de
  l'appareil, et agit en responsable de traitement indépendant. Le §5 y renvoie. Ils ne vont **pas**
  au tableau des sous-traitants : nous ne les choisissons pas et ils ne lisent pas le contenu. FCM,
  qui le lit, y reste.
- `LEGAL-6` **Wahoo ajouté à la FAQ** (2026-09-29) — actif sur pedalons.fr ; `privacy/support.{fr,en}.md`
  le cite avec Karoo et Garmin, comme les CGU (§2) et la politique (§4, §5).
- `LEGAL-7` **Message à l'auteur d'une annonce aussi déclaré en « Messages »** (2026-09-29) —
  `mobile/store-metadata/data-safety.md` : ligne Play *Messages → Other in-app messages*
  (facultatif, non partagé, *App functionality*) **en plus** de *Other user-generated content*.
  Déclarer en trop ne coûte rien, déclarer trop étroit expose à un rejet. À reporter dans la Play
  Console à la prochaine mise à jour de la fiche.
- `LEGAL-11` **Garanties de transfert confirmées, §5 réécrit** (2026-09-29) — vérifiées service
  par service, sources publiques : Garmin International, Esri, GitHub, Slack, Discord et Cloudflare
  adhèrent au Data Privacy Framework ; Firebase (FCM) repose sur ses *Data Processing and Security
  Terms* (clauses types), qui s'appliquent d'office avec les conditions de Firebase — aucune
  acceptation séparée dans la console, vérifié le 29/09/2026 —, et sur le DPF de Google LLC ; Apple
  répond pour l'Europe par Apple Distribution International (Irlande), dont les transferts reposent
  sur les clauses types, **pas** sur le DPF ; Google Play Console aussi sur les clauses types ;
  l'adéquation du Royaume-Uni (fond OSM) a été renouvelée le 19/12/2025 jusqu'en 2031. Décisions à
  ne pas défaire : l'envoi vers Hammerhead, Garmin et Wahoo repose sur l'art. 49-1-b (nécessaire au
  service demandé) et non plus sur le consentement, parce que ni SRAM ni Wahoo n'affichent de DPF ou
  de clauses types ; les tuiles de relief de Mapterhorn, servies par Cloudflare (R2, Workers), sont
  **mentionnées** au §4 et au §5, pas mises derrière un proxy ; les canaux Slack/Discord sont un
  transfert sur instruction des administrateurs de l'équipe. Connect IQ n'a pas de service de test
  par e-mail (une bêta n'est visible que du compte développeur) : il a quitté la phrase sur les
  bêtas du §1 et du §5. CyclOSM (OpenStreetMap France) et VersaTiles ne publient pas le pays de leurs
  serveurs ; la politique n'en dit rien de plus.
- `LEGAL-10` **Journaux d'accès : 14 jours, sans coordonnées ni jetons en paramètres** (2026-09-29)
  — la politique (§1 « Données de session » et « Données de localisation », §6) le dit ; le journal
  de Traefik est coupé (`OPS-7`), celui du Caddy de l'hôte est décrit dans
  [`OPERATIONS.md`](OPERATIONS.md#access-logs) : `t`, `token`, `code`, `state` remplacés par
  `REDACTED`, `lat`, `lon`, `nearLat`, `nearLon` supprimés, rotation par
  `scripts/caddy-access.logrotate` (quotidienne, 13 fichiers + le courant = 14 jours).
  Appliqué sur l'hôte le même jour (`OPS-6`).
  Les jetons dans le **chemin** (push FCM, export) restent visibles : `API-45`. Ne pas remonter la
  rotation au-delà de 14 jours sans changer le §6. Pas de test (configuration hors dépôt).
- `LEGAL-12` **Purges des conservations sans borne** (2026-09-29) — nettoyage nocturne : codes
  d'appairage et challenges WebAuthn expirés (`AuthCleanupScheduler`, 3 h), inscriptions bêta après
  un an (`BetaSignupScheduler`, 3 h 45, `pedalons.beta.signups.retention-days`), demandes de
  transfert biketeam un an après leur fin (`BiketeamMigrationRetentionScheduler`, 3 h 50,
  `pedalons.biketeam.retention-days`) — fin = `finishedAt` des jobs `SUCCEEDED`/`FAILED`,
  `grantExpiresAt` des `EXPIRED` ; jamais un `GRANTED`, `QUEUED` ou `RUNNING`, et
  `biketeam_migration_map` n'est pas touchée (le rejeu en dépend). La purge biketeam tourne même
  migration désactivée. §6 mis à jour, la phrase « pas encore couverts par un nettoyage » a disparu.
  Tests : `AuthCleanupSchedulerTest.CleanupAbandonedPairingsAndChallenges`,
  `BetaSignupSchedulerTest`, `BiketeamMigrationRetentionSchedulerTest`. Le chiffrement des
  sauvegardes, relevé en chemin (hôte au domicile, copies en clair), est `OPS-13`.
- `LEGAL-9` **Métadonnées des fichiers téléversés retirées à l'import** (2026-09-29) — les photos
  perdent EXIF, XMP, IPTC et commentaires, orientation gardée (`API-43`) ; les GPX ne gardent que
  la trace et les waypoints (`API-44`) ; les deux rattrapages nettoient ce qui était déjà stocké.
  Le §1 de la politique (« Fichiers GPX que vous importez », « Photos et images », fichiers
  téléchargés par l'app mobile) dit désormais ce qui est retiré et ce qui est gardé, à la place des
  avertissements sur l'EXIF, les photos d'annonce et les données de santé ; il dit aussi que les
  formats non nettoyables sont refusés et que les autres pièces jointes (vidéos, documents, GPX
  joints) sont gardées telles quelles (`API-46`, `API-47`, `API-49`). Opportunités #5 et #6.
- `LEGAL-15` **Textes légaux élagués du verbiage et des redites** (2026-09-29) — audit par
  section de `privacy/*.md` (14 agents, 116 remarques), puis réécriture en parité FR/EN. Chaque
  information a désormais **un seul endroit** : le stockage du navigateur est dans le tableau du §8
  (le §1 y renvoie), les durées au §6 (le nettoyage nocturne et les 30 jours de sauvegarde n'y
  sont dits qu'une fois), la visibilité de la liste des membres au §4, la suppression d'un compte
  au §7 (les CGU §9 y renvoient) ; le §9 Sécurité ne redit plus le §1 ni le §6, le §5 ne donne
  plus que pays et garantie de chaque transfert. Retirés : les noms de logiciels et d'en-têtes
  (HttpOnly, Cache-Control, SameSite, AAGUID, Keystore, imgproxy, Valhalla…), les allusions à
  l'historique (« avant ce changement »), la liste des notifications dans les CGU. Corrigé au
  passage : la politique disait qu'un contenu signalé « peut être masqué », il l'est à partir de
  trois signaleurs (`ReportService.AUTO_HIDE_REPORTERS`), comme le disaient les CGU. À ne pas
  défaire : les mentions de l'art. 13 RGPD, les engagements vérifiables (zone d'~1 km des
  annonces, clé privée qui ne quitte pas l'appareil, secrets hachés et leurs deux exceptions)
  restent. Pas de test (texte).
- `LEGAL-13` **Gouvernance : âge déclaré, violation de données, responsable unique** (2026-09-29)
  — quatre décisions ([opportunités](plans/2026-07-25-privacy-improvement-opportunities.md) #15 à
  #17 et #19). **Âge** : la case d'inscription dit désormais « J'ai au moins 16 ans et j'accepte… »
  (`auth.register.acceptTerms` au web, `auth.terms.accept` au mobile) ; la déclaration est horodatée
  par le `termsAcceptedAt` existant, sans champ ni changement de contrat. Le §10 de la politique le
  dit, ainsi que le §3 des CGU, et précise qu'on ne vérifie rien et qu'on ne demande pas la date de
  naissance : la demander serait une collecte de plus. **Violation** : le §9 s'engage à notifier la
  CNIL sous 72 h et les personnes concernées si le risque est élevé (art. 33 et 34, dus de toute
  façon). **Responsable** : le §12 dit qu'il est le même sur tous les sites hébergés, y compris le
  domaine propre d'un club, et que les clubs ne sont pas responsables du traitement. **Admins
  plateforme** : texte du §4 inchangé (un seul admin, le responsable lui-même), pas de journal
  (`LEGAL-16`) ; responsable par domaine écarté (`LEGAL-17`). Test : `flow-account.e2e.ts` (libellé
  de la case et message d'erreur). Les comptes créés avant n'ont pas déclaré leur âge : c'est
  admis, la politique ne prétend pas le contraire.
