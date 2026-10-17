# La suite — ce qui reste à faire

Écrit le 27 juillet 2026 (sous le nom `NEXT.md`), au moment où la v2 mobile est terminée et le
portage web livré à trois tâches près, et tenu à jour depuis (dernière relecture d'ensemble :
16 octobre 2026). Ce fichier remplace les feuilles de route des plans archivés : ceux-ci gardent le
**pourquoi** des décisions, celui-ci porte le **reste à faire**, et
[`LEDGER_DONE.md`](LEDGER_DONE.md) ce qui est livré.

Rien ici ne bloque quoi que ce soit. C'est la propriété qui compte : la v2 est livrable en l'état,
et chaque ligne ci-dessous supprime une dégradation nommée plutôt que de réparer une panne.

**Contrat d'API au 17 octobre 2026 : `11.5.3`.** Toute évolution d'API listée ici demande un bump de
`pedalons.api.version` dans `backend/src/main/resources/application.properties`, puis la
régénération des deux clients (compétence `contract-first-api`).

## La nomenclature

**Chaque entrée porte un identifiant `PRÉFIXE-n`** (`API-21`, `MOB-7`…) : c'est lui qu'on cite,
jamais un titre ni une position dans le fichier.

- **L'identifiant ne change jamais.** Il suit l'entrée quand elle est reformulée, déplacée, ou
  livrée : une entrée livrée passe dans [`LEDGER_DONE.md`](LEDGER_DONE.md) **sous le même
  identifiant**, une entrée écartée passe dans « Délibérément dehors » sous le même identifiant.
- **Un numéro ne sert qu'une fois.** Nouvelle entrée : le plus grand numéro du préfixe dans les deux
  fichiers, plus un — `grep -ohE 'API-[0-9]+' docs/LEDGER_*.md | sort -t- -k2 -n | tail -1`. Une
  entrée scindée garde son numéro pour une part et en prend un neuf pour l'autre ; un numéro
  abandonné n'est pas recyclé.
- **Un renvoi cite l'identifiant seul** — « ledger `WEB-3` » dans une doc, `docs/LEDGER_*.md WEB-14`
  dans un commentaire de code — sans dire s'il est dans `LEDGER_NEXT.md` ou `LEDGER_DONE.md` :
  c'est ce qui permet de livrer une entrée sans toucher à ceux qui la citent. `grep -rn 'WEB-14'`
  retrouve l'entrée et tous ses renvois.
- **Le préfixe dit où ranger l'entrée**, dans les deux fichiers : chacun a une section par préfixe,
  dans le même ordre. Les sous-titres à l'intérieur d'une section sont libres et peuvent changer.

| Préfixe | Domaine |
|---|---|
| `MOB` | Application mobile (Flutter) — dont la recette sur appareil |
| `WEB` | Site web (React, SSR) — dont la suite e2e Playwright |
| `API` | Contrat d'API et backend |
| `OPS` | Exploitation, déploiement, recette du backend en conditions réelles |
| `NOTIF` | Notifications (in-app, e-mail, push, webhook d'équipe) |
| `MOD` | Modération et signalement de contenu |
| `ISSUE` | « Signaler un problème » et remontée des erreurs vers GitHub |
| `MIG` | Migration biketeam → Pédalons |
| `BRAND` | Charte, code couleur métier |
| `SEC` | Sécurité applicative — dont les suites de l'audit de septembre 2026 ([`plans/archive/2026-09-security-audit.md`](plans/archive/2026-09-security-audit.md)) |
| `AUD` | Suivi de l'audit d'infrastructure de février ([`plans/2026-02-14-project-audit.md`](plans/2026-02-14-project-audit.md)) |
| `LEGAL` | Politique de confidentialité, CGU, déclarations des stores |
| `BILL` | Monétisation : paliers, facturation Qonto, suivi des abonnements, droits par équipe ([`plans/2026-10-17-monetisation.md`](plans/2026-10-17-monetisation.md)) |

Un préfixe nouveau s'ajoute à cette table (et une section aux deux fichiers) ; un préfixe existant
ne se renomme pas.

Sources : [`plans/archive/`](plans/archive/) (les trois plans du 26 juillet, avec leur §4/§5, et
les plans exécutés depuis),
[`plans/archive/audit-ux/BRIEF.md`](plans/archive/audit-ux/BRIEF.md) (l'entrant de design),
[`plans/2026-02-14-project-audit.md`](plans/2026-02-14-project-audit.md) (audit d'infrastructure,
encore ouvert), [`plans/archive/2026-09-security-audit.md`](plans/archive/2026-09-security-audit.md) (audit de sécurité de septembre 2026, archivé).

---

## MOB — Application mobile

### Recette sur une application qui tourne

Rien de ce qui suit n'est couvert par les tests automatisés — soit parce que c'est du rendu, soit
parce que ça dépend d'un vrai fournisseur (mail, tuiles, GPS), soit parce que c'est un comportement
de première ouverture. `flutter analyze` est propre, les tests mobiles (`mobile/check.sh`) passent :
ce qui suit est ce qu'ils ne peuvent pas dire.

À faire une fois **en clair** et une fois **en sombre** (le mode sombre est *dérivé*, aucune maquette
ne le fournit : c'est là que les erreurs de contraste apparaissent), sur un compte membre de
`n-peloton` *et* sur `gaby` (l'échantillon d'états vides). Les volumes diffèrent selon la base : la
base locale migrée compte 1 999 membres, 2 585 parcours et ~665 sorties sur `n-peloton` (7 membres
sur `gaby`) ; en prod, au 16 octobre 2026, `n-peloton` compte 2 696 parcours et 557 sorties mais
5 membres seulement — la migration biketeam (11-15 octobre) n'a pas apporté ses membres — et `gaby`
1 membre et 106 parcours.

**Passe partielle du 27 juillet 2026** : audit de code complet sur les douze écrans, plus un passage
en direct sur simulateur (thème sombre, compte `n-peloton` — un seul compte suffit, il est admin des
deux équipes `n-peloton` et `gaby`). Un défaut trouvé et corrigé (`MOB-21`, le `GROUP_FULL` ne
nommait pas le groupe). Restent à faire en conditions réelles, non couvrables par la lecture de
code : bascule de fuseau horaire sur l'appareil, ouverture d'un deeplink app tuée, mesure de fps
(parcours et liste de 200), rendu du text scaling ×1,3/×2,0, et la capture d'écran de preuve pour le
jeton ICS. Thème clair et compte `gaby` pas repassés en revue depuis.

**Recette du 4 octobre 2026** (prod, équipe `gaby-test1`, jeu de données « Recette — … », clair et
sombre) : seize entrées livrées, trois défauts mineurs (`MOB-44` à `MOB-46`, corrigés le même jour).
Restaient celles qu'il faut un gros volume pour juger (`MOB-5`, `MOB-13`, `MOB-20`), `MOB-15` pas
faite, et le 500 du contact vendeur (`MOB-47`). Depuis l'import de `n-peloton` en prod, `MOB-5` et
`MOB-20` se recettent en prod ; `MOB-13` reste sur la base locale migrée.

- [ ] `MOB-5` **Exploration de parcours (21)** — vue liste et vue carte, en prod sur `n-peloton`
      (2 696 parcours). Le mobile rend désormais les
      vraies tuiles `.mvt`, comme le web (jeton signé, API 2.3.0) : vérifier qu'au-delà de quelques
      centaines de tracés la carte les montre **tous**, sans plafond ni pilule de troncature, et
      qu'aucune requête ne part au tap sur un tracé. À faire **en build release au moins une fois** :
      `featuresAtPoint` a un antécédent de `ClassNotFoundException` Android corrigé en maplibre
      0.3.5, que le mode debug ne montre pas. Vérifier aussi le renouvellement du jeton : laisser la
      carte ouverte au-delà de la durée de vie, les tuiles doivent continuer d'arriver et les
      marqueurs rester **au-dessus** de la masse. Bascule automatique en compact au-delà de 200
      résultats.
- [ ] `MOB-47` **Contact du vendeur : l'échec d'envoi (500) de bout en bout** — reste de `MOB-12`,
      recetté le 4 octobre 2026 sauf ce cas. Le comportement de l'app est déjà tenu par un test de
      widget (`ad_detail_page_test.dart`, « un 500 est un échec franc, et le brouillon survit » :
      `AD_CONTACT_DELIVERY_FAILED` nomme l'échec, aucune confirmation, brouillon gardé,
      « Réessayer »). Ce qui manque est le chemin réel, que la prod ne sait pas provoquer : un test
      Patrol sur la pile e2e (`ad_contact_test` ne couvre que l'envoi réussi, `opted_out` et
      `rate_limited`), avec le mode chaos de mailpit (`axllent/mailpit:v1.31.5`,
      `docker-compose.e2e.yml`, à activer sur ce service) pour que le relais SMTP refuse l'envoi à
      la demande. Remplace la recette manuelle (pendant web : `page.route`).
- [ ] `MOB-13` **Trombinoscope (34)** — sur `n-peloton`, le pied annonce le total exact (1 999) à
      chaque page. C'est le point où le mobile chargeait 20 membres sur 1 999 **sans le dire**. À
      recetter sur la **pile locale migrée** : en prod, `n-peloton` n'a que 5 membres.
- [ ] `MOB-15` **Profil (33)** — la recette sur appareil du profil refondu (`MOB-48` : vue
      d'ensemble puis sous-pages `/profil/<sujet>`), seule entrée qui la décrit ; `MOB-62` n'en
      garde que les finitions. **Vue d'ensemble** : ligne Mon compte, tirer pour rafraîchir,
      ouverture de chaque sous-page et retour ; la cible de 44 px de `PdlChip` vaut pour toutes les
      puces de filtre de l'app. **Préférences** : les quatre réglages (unités, fuseau horaire,
      thème, langue) s'appliquent **immédiatement, sans bouton**, et la ligne d'état de la vue
      d'ensemble suit au retour ; un échec revient à la valeur précédente. **Confidentialité** :
      « Être contacté par les membres », même règle ; Utilisateurs bloqués s'ouvre en
      Profil › Confidentialité › Bloqués, y compris par lien profond, et le retour ramène à
      Confidentialité. **Connexion et sécurité** : ajouter une seconde clé d'accès **n'écrase plus
      les autres**, « Déconnecter tous les appareils » est câblé. **Notifications** : une ligne par
      type, une puce par canal déclaré par le serveur — à recetter dans les deux états, aucun canal
      configurable (le défaut en dev ; la ligne d'état dit alors que tout reste dans l'app) et push
      actif (le cas en prod). La cloche reste sur l'Accueil (`MOB-50`). Les mêmes parcours sont
      automatisés dans Patrol, verts depuis le 6 octobre 2026 (`MOB-49`).
- [ ] `MOB-20` **Performance** — liste de 200 items : rester au-dessus de 55 fps (en prod, les
      parcours ou les sorties de `n-peloton` suffisent). Si le
      `BackdropFilter` des barres épinglées coûte trop cher, le repli prévu (non implémenté à ce
      jour — `blurToolbar` est une constante fixe à 12, aucune branche conditionnelle) serait **un
      seul jeton** à faire tomber à 0 (`PdlMotion.blurToolbar`, surface opaque), aucun écran à
      rouvrir.
- [ ] `MOB-52` **Météo : recette sur appareil de ce que `MOB-68` ne couvre pas (S)** — la météo des
      sorties de `MOB-51` a été refondue par `MOB-67` et `MOB-69` : l'écran « Météo du parcours »
      n'existe plus (onglet Météo de la page du groupe) et la carte du détail est devenue
      `RideDepartureWeatherCard` ; leur recette est celle de `MOB-68`. Reste la météo des étapes de
      voyage (`MOB-57`), vérifiée par `flutter analyze` et les tests de widgets seulement, jamais
      comparée à la maquette (canevas « Intégration météo ») : carte de l'écran 25 sans place
      réservée au chargement, pull-to-refresh nouveau de l'écran 25 face au rail épinglé, clés
      `keys.ride.weather*` réutilisées par `stage_weather_page.dart` et `stage_weather_card.dart` et
      donc en double sur l'écran 24 ; clair et sombre, text scaling. À trancher avec le
      propriétaire : garder la ligne « Météo dès le … » (`NOT_YET_AVAILABLE`) sur les cartes du fil,
      qui ajoute une ligne à toutes les sorties à plus de 7 jours (`RideWeatherSummaryLine.shows`).

### Fiches des stores

- [ ] `MOB-64` **Publier Pédalons sur Google Play (S)** — la fiche est poussée sur Google Play
      (`fastlane listing`, 11 octobre 2026) : description FR/EN reprise de l'App Store, sept cartes
      1080 × 1920 capturées sur l'émulateur (`screenshots/capture-android.sh`, `koubou/play.yaml`,
      `assemble-play.sh`) et une bannière refaite (`koubou/feature.yaml`). État au 15 octobre 2026
      (fiche et images identiques au dépôt, vérifié par l'API) : aucune version en production ; le
      test fermé (`alpha`, liste de diffusion « Test Pedalons ») reçoit chaque bêta 1.1.0 de
      `publish_beta.sh` (la build en test est celle du dernier passage du script), la première
      approuvée le 15 octobre (la Console coche « Publier une version de test fermé »).
      **Bloquant** : le compte développeur est personnel, la Console refuse de demander l'accès en
      production avant **douze testeurs inscrits au test fermé pendant quatorze jours d'affilée**
      (zéro inscrit au 15 octobre), et ces testeurs doivent **réellement utiliser l'app** : la
      demande d'accès porte sur l'usage et les retours obtenus pendant le test. Les testeurs passent
      depuis le 15 octobre par le
      Google Group `pedalons-testeurs@googlegroups.com` (ouvert à tous, publication réservée aux
      gestionnaires), déclaré sur le canal Alpha : chacun rejoint
      https://groups.google.com/g/pedalons-testeurs puis accepte
      https://play.google.com/apps/testing/fr.pedalons.mobile ; seul un testeur qui a accepté le
      second lien compte. En viser une quinzaine : sous douze, les quatorze jours repartent de zéro.
      Le canal n'est ouvert que dans un pays, et l'adresse de commentaires y est `dev@pedalons.fr`
      (TestFlight : `gabriel.landais@gmail.com`). Restent aussi les formulaires de la Console
      qu'aucune API ne remplit (accès à l'application avec le compte de démo, classification du
      contenu, public cible, publicités), plus la sécurité des données (`fastlane data_safety`).
      Une fois l'accès obtenu : promouvoir la release `alpha` depuis la Console plutôt que
      `fastlane deploy`, qui renverrait le même versionCode.
- [ ] `MOB-70` **Publier la 1.1.0 sur l'App Store (XS)** — la 1.0.0 est en vente ; la version 1.1.0
      existe dans App Store Connect, fiche et captures identiques à `mobile/metadata/` et
      `mobile/screenshots/` (vérifié le 15 octobre 2026), sans build attaché. Les bêtas 1.1.0 de
      `publish_beta.sh` passent par TestFlight (groupe externe NP), la première en revue bêta depuis
      le 15 octobre. Les informations de test TestFlight (compte de démo, notes reprises de
      `mobile/metadata/review-notes.md`, description bêta FR/EN, URL de confidentialité) ont été
      remplies ce jour-là par l'API : elles ne sont **pas versionnées**, et le compte de démo est à
      changer aux deux endroits (fiche App Store et TestFlight) s'il change. Reste :
      `cd mobile/ios && bundle exec fastlane release` (attache le build du `pubspec`, donc le
      dernier publié par `publish_beta.sh`), puis soumettre à la revue dans App Store Connect. Le
      formulaire *App Privacy* n'a pas été comparé (`asc web privacy plan`, session web 2FA).

### Couverture e2e Patrol — ce que les tests ne couvrent pas encore

`mobile/patrol_test/` couvre les P0 de l'audit de couverture e2e (`WEB-26`) transposés à l'app et
les scénarios livrés depuis (65 tests au 16 octobre 2026 ; la liste à jour est dans
`mobile/patrol_test/README.md`, « Coverage »). Ce que chacun laisse de côté est dit dans son entrée
livrée. Hors périmètre, parce que l'app ne les a pas : écrire une publication (le seul écrit est un
commentaire), la file de modération (une entrée `CONTENT_REPORTED` ouvre `/…/admin/reports` dans le
navigateur), et la connexion par code e-mailé (`requestOtp` / `verifyOtp` d'`auth_provider.dart`
n'ont aucun appelant d'écran).

- [ ] `MOB-26` **Clés d'accès** — une clé ajoutée depuis le profil (`passkeys_section.dart`) connecte
      depuis `login_page.dart` ; une clé supprimée ne connecte plus (`flow-account.e2e.ts`). Demande
      un authentificateur sur le simulateur ou l'émulateur.
      **Bloqué sur la stack e2e** (évalué le 29 septembre 2026) : le RP ID y est `localhost` en HTTP,
      alors qu'iOS n'accepte une clé que pour un domaine associé (`webcredentials:`, fichier
      `apple-app-site-association` servi en HTTPS de confiance) et que `Runner.entitlements` ne
      déclare que `www.pedalons.fr` ; la correspondance Face ID du simulateur ne se pilote pas depuis
      Patrol ; Android bute de même sur `assetlinks.json`. Il faudrait un nom d'hôte HTTPS pour la
      stack (certificat mkcert ajouté au simulateur), `PEDALONS_WEBAUTHN_RP_ID` et
      `--dart-define=WEBAUTHN_RP_ID` réglés dessus, une variante d'entitlements de debug
      (`?mode=developer`) et un pas « visage reconnu » lancé par l'hôte.
- [ ] `MOB-37` **Les tests Patrol ne tournent qu'en local** — aucun workflow de `.github/` ne les
      lance : `ci.yml` ne passe que les tests unitaires. Il faudrait un runner macOS (simulateur) ou un
      émulateur Android, plus la stack e2e (`scripts/e2e.sh up`) dans le job. La piste la moins chère
      est un émulateur Android sur `ubuntu-latest`, à côté de la stack : le pendant web (`AUD-3`,
      `e2e.yml`) y tourne chaque nuit en environ 1 h, stack comprise, et `mobile-release.yml`
      construit déjà l'APK sur GitHub Actions.
- [ ] `MOB-75` **`patrol_test/README.md` en retard sur la suite (XS)** — la table
      « Coverage » n'a pas de ligne pour `ride_group_page_test` (`MOB-67`, `MOB-68`), alors que
      `ride_solo_group_test` et `ride_participants_map_test` en ont une ; « Not covered yet » cite
      encore le jeton d'accès expiré (`MOB-38`), couvert par `expired_access_token_test.dart`.

- [ ] `MOB-62` **Profil refondu (`MOB-48`, `WEB-57`) : finitions (S)** —
      reste de `MOB-49`, dont les tests Patrol sont verts depuis le 6 octobre 2026.
      - La recette sur appareil du profil refondu est portée par `MOB-15`.
      - La bascule d'une puce de canal n'est exercée nulle part : la pile e2e ne déclare aucun canal
        (e-mail coupé, pas de FCM, `NOTIF-4`).
      - Mineurs (XS, revérifiés le 16 octobre 2026) : la ligne d'état de Mon compte (« Photo, nom
        affiché, suppression du compte ») et la carte d'identité (« Photo, nom et compte ») se
        répètent un peu ; `Moderation.goBack()` (`patrol_test/modules/moderation.dart`) n'a plus
        d'appelant et repose sur `$.tester.pageBack()`, que `PdlAppBar` ne satisfait pas — à
        retirer. Clés de traduction sans appel littéral ni clé construite (`fr.json` et `en.json`) :
        `profile.security`, `profile.community`, `profile.passkeys.enabled` / `notConfigured` /
        `replace`, `notifications.preferences.inAppAlwaysOn`.
        **`profile.participations.count` reste** : `my_participations_page.dart` l'emploie.

- [ ] `MOB-68` **Page d'un groupe de sortie (`MOB-67`) : recette sur appareil (S)** — les tests
      Patrol et la suite `flutter test` complète sont verts (16 octobre 2026). Reste :
      - **Recette sur appareil**, clair et sombre, pour une sortie à plusieurs groupes et pour une
        sortie à un seul groupe (`MOB-69` : le lien du groupe renvoie au détail, `?tab=weather` y
        fait défiler jusqu'à la météo) : onglets et `?tab=weather` depuis un lien profond à froid
        (le détail de la sortie reconstruit dessous), puces de groupe, barre d'inscription (cibles
        de 44 px). Les captures des stores (`rideGroupWeather`) sont refaites le 14 octobre 2026.
      - **Mineur** : la pastille pluie de la ligne météo est bleue (`PdlFamily.blue` en dur dans
        `ride_group_weather_line.dart`, comme au web) quand le bandeau pluie de l'onglet Météo
        (`weather_leg_sections.dart`) reste jaune ; si la pluie doit porter une couleur, la mettre
        dans `contracts/brand-colors.yaml` pour les deux clients, sinon passer l'écart en
        « Délibérément dehors ».

### APK hors Play

- [ ] `MOB-73` **Vérifier l'APK sur un Android sans Google Play Services** — l'APK de
      `mobile-release.yml` (`MOB-72`, publié dans la release `mobile-latest`) n'a encore tourné sur
      aucun appareil sans GMS. Sur un émulateur d'image `default` (sans Google APIs) ou un vrai
      appareil (/e/OS, Huawei) : démarrage (Firebase doit échouer en silence, `main.dart`),
      connexion par mot de passe et réinitialisation, carte, localisation (`geolocator`, appelé sans
      option dans `location_service.dart`, doit basculer sur `LocationManager`), écran des
      notifications sans jeton FCM, lien profond `www.pedalons.fr` (empreinte `26:24:…` de
      `assetlinks.json`, servie en prod). Les **passkeys** passent par Credential Manager, qui n'a
      souvent aucun fournisseur sans GMS : le bouton de connexion est déjà masqué quand
      `canAuthenticate()` échoue (`passkey_service.dart`, `login_page.dart`) ; vérifier qu'il renvoie
      bien faux sans fournisseur, et qu'ailleurs un échec donne un message clair plutôt qu'une erreur
      brute. À décider ensuite : l'écran des notifications devrait-il dire que le push est
      impossible, et faut-il signaler une nouvelle version aux installations par APK (rien ne les
      met à jour aujourd'hui). Taille : S pour la recette, inconnue pour les suites.

---

## WEB — Site web

La recette du web est automatisée par une suite Playwright depuis le 25 septembre 2026
(`WEB-13` à `WEB-22`, livrés, avec ce que l'automatisation ne voit pas) : voir
`frontend/e2e/README.md`.

- [ ] `WEB-36` **Un tap juste après l'affichage d'une page, sous charge, est ignoré (M)** — le HTML
      du SSR est à l'écran et cliquable avant que React l'ait adopté ; avec l'hydratation
      concurrente de React 19, un clic qui tombe pendant le rendu d'hydratation, avant son commit,
      n'atteint pas son gestionnaire et **n'est pas rejoué** (mesuré par la sonde de `WEB-35` : 3 clics
      sur 40 dans les premières centaines de millisecondes, pile e2e chargée, sur le burger de
      `Layout.tsx`). Rien ne se passe, sans message : l'utilisateur retape. `WEB-35` ne corrige que
      les tests (ils attendent le commit). Pistes : capturer les clics sur `document` entre
      l'affichage et `HydrationMarker` puis les rejouer sur leur cible au commit (attention aux
      doubles déclenchements et aux liens, que le navigateur suit déjà sans JS), ou raccourcir la
      fenêtre (hydratation par îlots, moins de travail au premier rendu). Mesurer d'abord sur un
      vrai téléphone moyen de gamme, hors pile e2e. La mesure est à refaire après `WEB-95`
      (chargement initial de 836 à 406 Ko gzip, sans gain sur le TBT) et `WEB-96` (carte montée en
      différé), qui raccourcit justement cette fenêtre. Un rejeu doit rester compatible avec la CSP
      (`SEC-31`, `SEC-40`) : nonce, aucun script inline libre.
- [ ] `WEB-56` **Profil refondu (`WEB-55`, `WEB-57`) : recette navigateur (S)** — les e2e sont
      passés (voir la part livrée sous le même identifiant). Plus rien à trancher : Utilisateurs
      bloqués est sous Confidentialité (`/profil/vie-privee/bloques`), la zone de danger suit le
      jeton `danger` et les cases des notifications ont leur cible de 44 px sur téléphone
      (`WEB-55`). Reste la **recette à l'œil** : mise en page, point de rupture `md`, mode sombre (la
      bordure `danger-outline` de la zone de danger y compris) ; sur un téléphone, une touche
      n'importe où dans la cellule coche la case des notifications (le `<label>` enveloppe le `div`
      racine du `Checkbox` Mantine : HTML pas strictement valide, toléré par les navigateurs). Avec
      un fuseau non enregistré, Préférences montre celui du navigateur, que le serveur ne connaît
      pas (`WEB-54`). Les mineurs relevés au passage sont sortis dans `WEB-98` ; les renvois
      imprécis des textes légaux (« depuis votre profil ») relèvent de la section `LEGAL`.

- [ ] `WEB-98` **Deux clés i18n mortes et un e-mail qui nomme un réglage sans lien (XS)** —
      `auth.login.tabs.passkey` et `auth.passkey.login` ne servent plus nulle part dans
      `frontend/src` (`frontend/src/locales/{fr,en}/common.json`, lignes 286 et 301 en français ;
      le mobile a son propre catalogue) : les supprimer des deux langues. L'e-mail de contact d'une
      annonce (`backend/src/main/resources/templates/mail/ad-contact.{fr,en}.{txt,html}`) dit
      « désactivez « Être contacté par les membres » dans Profil › Confidentialité » sans lien, le
      gabarit ne recevant que `params.adUrl` : passer l'URL absolue de `/profile/privacy` (sur le
      domaine de l'équipe, comme `adUrl`) et en faire un lien dans la version HTML.

- [ ] `WEB-61` **Météo des sorties : recette navigateur de ce que `WEB-94` n'a pas vu (S)** —
      `WEB-94` a refait la météo de la page d'un groupe (`GroupWeatherSection` pleine largeur sous
      la grille statistiques/carte) et l'a vérifiée dans un navigateur sur une vraie sortie (clair,
      sombre, 390 px) ; la disposition d'origine (bloc entre l'en-tête et la carte, frise
      horizontale des points) n'existe plus sur cette page. Reste à voir dans un navigateur :
      `RideWeatherSection` sur le détail d'une sortie à plusieurs groupes, la ligne météo des
      cartes de groupe (`GroupWeatherLine`), et la météo des étapes (`WEB-67`) : bloc de la page
      d'étape, ligne des cartes d'étape ; mode sombre et téléphone pour chacune. À trancher avec le
      propriétaire : le libellé « Pluie dès 10:00 » / « Neige dès … »
      (`rides.weather.summary.rainAlert`, probabilité en info-bulle seulement ; la maquette disait
      « Averse 70 % »). Aucun e2e ne couvre la météo : la pile e2e coupe le fournisseur, il
      faudrait remplir le cache par SQL.

- [ ] `WEB-75` **Hauteur de pluie avec un point décimal en français (XS)** — la météo de départ
      écrit « Pluie 60 % · 2.3 mm » : `DepartureWeather.tsx` passe `precipitation.toFixed(1)` à la
      clé `rides.weather.precipitationWithAmount`, sans tenir compte de la langue. Le mobile écrit
      bien « 2,3 mm » (`AppFormatters.formatPrecipitation`). Formater avec `Intl.NumberFormat`
      selon la langue de l'interface (une décimale), comme `formatFileSize`.

- [ ] `WEB-78` **Page d'un groupe de sortie (`WEB-77`) : recette navigateur des états restants
      (S)** — les e2e sont passés (voir la part livrée sous le même identifiant) et `WEB-94` a
      vérifié la section météo de la page dans un navigateur (clair, sombre, 390 px). Restent à
      voir à l'œil : la colonne de carte collante à partir de 64em, le sélecteur de groupe (4 puis
      `Select`), un groupe supprimé (état vide), un inscrit dans un autre groupe, en mode sombre et
      sur téléphone. Recoupe `WEB-61`.

- [ ] `WEB-83` **« Groupe Groupe intermédiaire » : le libellé d'un groupe répète son préfixe (XS)** —
      `rides.group.title` (« Groupe {{name}} », « Group {{name}} ») est posé devant un nom qui
      commence souvent déjà par ce mot : les groupes de démo, et tout club qui nomme les siens
      « Groupe A ». Quatre appels : l'en-tête et le partage de `pages/ride/RideGroupPage.tsx`, le
      fil d'Ariane (`hooks/useBreadcrumbData.ts`), le titre de la page (`config/routeMeta.ts`).
      Reprendre la règle du mobile, corrigé le 14 octobre 2026 (`mobile/lib/features/rides/domain/group_title.dart`,
      `group_title_test.dart`) : le nom seul quand il commence par le mot du gabarit, casse ignorée,
      mot entier (« Groupement » garde le préfixe) ; une fonction partagée et son test vitest. Deux
      tests figent aujourd'hui le libellé fautif et sont à mettre à jour avec le correctif :
      `frontend/e2e/routes-render.e2e.ts` (`rideGroup` attend `heading('Groupe Groupe A')`) et
      `frontend/src/config/routeMeta.test.ts` (titre de `rideGroupMeta`). Le nom envoyé aux
      services GPS (`GpsSyncNames.autoName`, « date · groupe · route ») pose le nom du groupe nu,
      sans gabarit : il ne double pas le préfixe, et le point d'`API-120` qui lui applique cette
      règle est à revoir dans cette entrée-là.

- [ ] `WEB-96` **La carte s'initialise au chargement et bloque le fil principal (S)** — audit
      Lighthouse mobile de la page sortie (16 octobre 2026) : `map-vendor` (MapLibre, 280 Ko gzip)
      produit les deux plus longues tâches de la page (1,16 s et 1,11 s) et la majeure partie des
      ~0,7–3 s de TBT, avant même que la carte soit à l'écran. `WEB-95` a sorti le reste du
      chargement initial ; il reste à ne monter `PedalonsMap` que lorsque son conteneur devient
      visible (IntersectionObserver), place réservée, sur les pages sortie, groupe de sortie
      (`GroupRouteMap`), parcours et voyage. Aujourd'hui `RideDetailPage`, `TripDetailPage` et
      `GroupRouteMap` chargent la carte en `React.lazy` mais la montent dès le rendu.

### Couverture e2e — ce que l'audit du 27 septembre laisse ouvert

L'audit ([archivé](plans/archive/2026-09-27-e2e-coverage-audit.md), `WEB-26`) est exécuté : P0, P1
et P2 écrits, 54 défauts relevés, tous corrigés ou tranchés — le dernier, `WEB-6`, le 29 septembre. Le canal e-mail des
notifications n'a pas de test e2e : c'est `NOTIF-4`.

- [ ] `WEB-81` **GPX à plusieurs traces : profil empilé et synchro faussée (S, priorité basse)** —
      la distance cumulée de chaque point (`p[3]`) repart à 0 à chaque trace
      (`GpxProcessingService.toTrackPoints` reprend `path.getDist()` trace par trace ;
      `RouteSampleLookup.chain` doit d'ailleurs ajouter un décalage pour les mettre bout à bout). Le
      web aplatit les traces sans ce décalage (`ElevationChart.tsx`, `useMapChartZoomSync`, l'index
      de survol de `RouteTrackMap`) : les profils s'empilent sur le même axe et une plage de
      distances désigne plusieurs traces à la fois. Le mobile est à vérifier aussi
      (`pdl_elevation_profile.dart`, `route_cursor_controller.dart`). Non reproduit sur un vrai
      fichier, et aucun cas en prod : 0 parcours à plus d'une trace sur 5 527 au 16 octobre 2026.
      L'import d'un fichier à plusieurs `<trk>` reste possible (`tracksAsPaths`). À trancher :
      enchaîner côté client comme `RouteSampleLookup`, côté API (contrat), ou fusionner les traces
      à l'import comme le fait déjà `GpxTrackMerger` (`API-112`) pour une fusion explicite.
      `trackDistanceRange` traite déjà chaque trace à part (`WEB-80`).

- [ ] `WEB-7` **Idées de la liste « P2 (à planifier) » qui n'ont pas été retenues** parmi les
      21 tests P2 écrits — quelques-unes peuvent être couvertes au passage par une autre spec, à
      vérifier avant de les écrire :
  - Sorties : modale des participants avec le meneur marqué ; publication programmée dans le passé
    refusée ; calendrier au-delà de la fenêtre préchargée ; recherche dans les modèles.
  - Articles et voyages : commentaire d'un compte supprimé ; modale des participants d'un voyage ;
    étape d'une équipe dont le module est coupé.
  - Parcours : « cul-de-sac » (`RouteDeadEnd`) ; unités impériales dans les filtres ;
    « Enregistrer comme parcours » limité aux équipes éligibles (la visibilité du bouton est
    couverte par `flow-gpx-tools`, pas la liste des équipes) ; carte d'équipe sans fuite des
    tuiles TEAM ; hub GPX face à un fichier illisible. Le plein écran et son retour sont couverts
    par `routes-render` (`fullscreenMap`).
  - Équipe : promotion en ADMIN et filtre par rôle ; page publique, suppression et restauration
    d'une page, plafond de 3 (les pages supprimées comptent-elles ?).
  - Annonces : brouillon d'autrui introuvable par son URL ; défauts du formulaire (DRAFT par
    défaut, Annuler) ; signalement puis redirection.
  - Transverse : navigation mobile (tiroir, entrée Admin selon le rôle, fil d'Ariane « Plus ») ;
    restauration du défilement au retour.

---

## API — Contrat d'API et backend

### `API-63` Onboarding d'un Karoo refait de bout en bout (M, backend + web + mobile + Karoo)

Associer un Karoo laisse l'utilisateur sans Hammerhead sans qu'il le sache : l'app mobile ne le
propose jamais, le web le propose trop tard (le Karoo a déjà affiché son second QR), et ce QR mène
au profil sans rien expliquer. Le plan [`2026-10-02-karoo-onboarding.md`](plans/2026-10-02-karoo-onboarding.md)
refait le parcours : un seul QR, l'étape Hammerhead enchaînée sur le téléphone après l'autorisation,
un retour d'OAuth paramétré (`returnTo`, contrat `10.4.0`) et un Karoo qui suit `/api/device/me`
au lieu de redemander. Hammerhead y est **obligatoire** (décision du 2 octobre 2026).

**Code livré et en prod, tous les tests automatisés verts : reste la recette manuelle.** Backend
(`GpsResourceTest`), e2e web (`flow-device.e2e.ts`) et Patrol (`device_link_test`,
`device_hammerhead_test`, `device_link_signed_out_test`, `device_manual_code_test`) sont verts.
Reste la recette sur Karoo et téléphone du §4 du plan (six scénarios), à faire sur `karoo.1.0.13`,
qui embarque aussi « Prochaines sorties » (`API-118`) et l'état de synchro GPS (`API-121`). Les
connexions Hammerhead créées en prod (trois au 16 octobre 2026) montrent un usage réel, pas que la
recette a été faite ; l'entrée passe dans `LEDGER_DONE.md` une fois celle-ci faite.

- [ ] `API-72` **Contraintes CHECK des enums vérifiées contre Flyway (S)** — les tests construisent
      le schéma depuis les entités (`%test.quarkus.flyway.migrate-at-start=false`) : un enum persisté
      en `varchar` qui gagne une valeur sans migration passe toute la suite et casse en prod (`API-71`).
      Un test qui applique `db/migration` sur une base PostGIS vierge (TestContainers) et compare chaque
      contrainte `…_check` aux valeurs de l'enum Java correspondant (`AuthTokenType`, `AssetType`,
      `GpsSyncError`, `service_type`, `platform_role`, `unit_system`, `theme`, `visibility`,
      `status`…) supprimerait cette classe de défaut. Elle s'étend : V71 a ajouté
      `ck_gps_route_syncs_last_error` (`GpsSyncError`), et `API-103` tomberait dans ce piège. Au
      16 octobre 2026, les CHECK de la prod sont alignés sur les enums Java.

### Météo : ce qui suit `API-74`

La météo des **sorties** est livrée (`API-74`, `WEB-60`, `MOB-51`, contrat `10.9.0`), celle des
**étapes de voyage** aussi (`API-76`, `WEB-67`, `MOB-57`, contrat `10.11.0`), et la ligne des
cartes de voyage (`API-82`, contrat `10.13.0`). Le plan
[`2026-10-05-weather.md`](plans/archive/2026-10-05-weather.md) est archivé : il garde les
arbitrages, ce qui suit est ici (et les recettes des sorties, `WEB-61`, `MOB-52`, `OPS-29`).

- [ ] `API-77` **Météo sur Karoo et Garmin (M)** — `DeviceRideDto` ne porte rien ; à concevoir
      (résumé seul, ou points de passage) avec les contraintes de taille des deux apps. Les aperçus
      de lien (`og:`) ne portent **jamais** de météo. Le DTO appareil a grossi depuis
      (« Prochaines sorties », `API-118` ; état de synchro, `API-121`), ce qui pèse sur le budget
      de taille Garmin ; la vue « Prochaines sorties » est un endroit naturel pour l'afficher.
- [ ] `API-102` **Pluie toujours en millimètres, même en impérial (S, web + mobile, sans contrat)** —
      le plan météo archivé ne convertit que les températures et les vitesses, si bien qu'un lecteur
      en `IMPERIAL` lit « 54 °F · 12 mph · 2.3 mm » ; aux États-Unis la pluie se compte en pouces.
      Lieux : clé `rides.weather.precipitationWithAmount` (mm dans le texte traduit) et
      `DepartureWeather.tsx` côté web, `UnitSymbols.millimeter` et
      `AppFormatters.formatPrecipitation` côté mobile (`unit_system.dart`, `formatters.dart`) ;
      seuls `DepartureWeather.tsx` et `departure_weather_section.dart` affichent la quantité, les
      autres vues n'en montrent que la probabilité. Convertir en `in` (deux décimales) dans les
      deux clients ensemble, ou bien assumer le mm partout et le noter dans « Délibérément
      dehors ». Au 16 octobre 2026, aucun utilisateur n'est en `IMPERIAL` en prod (`METRIC` : 2,
      non renseigné : 15).
- [ ] `API-103` **Pas de réglage d'unités pour le Royaume-Uni (S, contrat + web + mobile)** —
      `UnitSystem` ne connaît que `METRIC` et `IMPERIAL`. Un cycliste britannique compte en miles,
      en mph et souvent en pieds, mais en °C et en mm : « Impérial » lui donne des °F et
      « Métrique » des km. Piste : une troisième valeur `UK` (mi, mph, ft, °C, mm), qui ne fait
      qu'ajouter une valeur au contrat (le mobile traite déjà une valeur inconnue comme `METRIC`,
      via `$unknown`), plutôt que des réglages par grandeur à la Garmin. Lieux :
      `enums/UnitSystem.java`, `frontend/src/utils/unitFormat.ts` (`getUnitConfig`,
      `temperatureToDisplay`) et les clés `*_imperial` de `useUnits`, `mobile/lib/core/units/unit_system.dart`,
      les sélecteurs de préférences des deux clients, et une migration Flyway qui élargit
      `users_unit_system_check` (aujourd'hui `METRIC`/`IMPERIAL`), faute de quoi la mise en prod
      casse (piège `API-72`). À ne faire que si le public sort de la France : au 16 octobre 2026,
      un seul domaine (`www.pedalons.fr`) et aucun utilisateur en `IMPERIAL`.
      Le vent en m/s (prévisions scandinaves) relève de la même logique de préréglage, sans
      demande à ce jour.

### Les chantiers d'infrastructure d'API

Quatre chantiers ont été chiffrés au §4 du
[document d'API archivé](plans/archive/2026-07-26-api-v2-livraison-et-suites.md) (contrat, modèle,
déclenchement, risques). Seul le push a été livré depuis (`NOTIF-9`) ; les trois autres n'ont pas été
commencés, si ce n'est l'`ETag` privé de la météo, qui sert de modèle à `API-22`. Résumé et ordre
recommandé :

#### `API-21` Pagination par curseur — **à faire avant d'étendre le scroll infini** (L)

C'est le seul des quatre qui a une **contrainte d'ordre** : il touche `BaseRepository.getPage`,
`PedalonsQuery` et tous les `…ListResponse`. L'offset actuel duplique et saute des éléments dès que
la liste bouge sous le curseur — sur `n-peloton` ce n'est pas un cas limite.

Trois règles à tenir : `cursor` et `page` mutuellement exclusifs (les deux ⇒ **400**, pas un
comportement silencieux) ; `nextCursor` renvoyé **toujours**, y compris en mode offset (c'est le
chemin de migration des clients) ; `total` reste calculé — les compteurs de tête de liste en
dépendent, et le pied de liste mobile (« 60 membres sur 1 999 ») l'exige. La clé de tri doit
**toujours** se terminer par `id`, sinon elle n'est pas totale. Le tri variable des parcours
(`sortBy` × `sortDir` × un `price` nullable) est le point délicat : un test par critère.

Note : le plan mobile a explicitement retenu l'offset **et** l'a justifié (le curseur ne fournit pas
le `total` que le pied de liste maquetté exige). Livrer le curseur ne suffit donc pas à faire basculer
le mobile — la cohabitation ci-dessus est ce qui rend la bascule possible.

#### Cache, fraîcheur et images — quatre briques indépendantes

- [ ] `API-22` **`ETag` / `If-None-Match` (M)** — le verrou est que les champs « moi »
      (`registered`, `registeredGroupId`, `full`, `commentCount`) rendent les réponses dépendantes
      de l'appelant. Un `ETag` calculé sur le contenu métier seul serait faux et un cache partagé
      servirait à Alice la réponse de Bob. Recommandation actée : intégrer `userId` au calcul et
      servir `Cache-Control: private` — le gain visé est le cache **du client**, pas d'un CDN.
      La mécanique existe déjà pour la météo (`API-74`) : `ETag` faible, `If-None-Match` → 304 et
      `Cache-Control: private, no-cache` (`RideResource`, `TripResource`, `RideWeatherAnswer`), à
      prendre pour modèle. Reste à l'étendre aux détails sortie, parcours et voyage, puis aux
      listes, avec `userId` dans le calcul.
- [ ] `API-23` **`updatedAt` en liste + `?updatedSince=` (M)** — c'est ce qui rend une synchro
      incrémentale possible. **À décider avant de coder** : `updatedSince` ne dit rien des
      suppressions. Soit des tombstones (`deleted_at` interrogeable), soit une resynchronisation
      périodique complète.
- [ ] `API-24` **URLs d'images signées (M)** — HMAC sur `(chemin, expiration)`. Piège : une URL qui
      expire pendant qu'une image est en cache donne une image cassée **sans erreur lisible** ;
      prévoir la renégociation client. Même brique que l'imgproxy non signé (`AUD-9`).
- [ ] `API-25` **`blurHash` (S)** — 30 octets par image, calculés une fois à l'upload. Le seul point
      à trancher : faire de `thumbnailUrl` un objet `{url, blurHash, width, height}` est un
      **MAJOR** (changement de type sur un champ livré en 1.3.0) ; un champ frère
      `thumbnailBlurHash` ne l'est pas. Pour les images existantes, le backfill par lots
      d'`AssetMetadataBackfillScheduler` (`API-43`) est un schéma réutilisable.

Ensemble, elles débloquent le chargement progressif du parcours, de vrais placeholders colorés à la
place des squelettes, et le **hors-ligne — qui n'est dans aucune maquette et devrait l'être avant
d'être promis**.

#### `API-26` Carte multi-entités `GET /api/map/features` (M)

Une `FeatureCollection` légère par bbox et par types (`RIDE`, `ROUTE`, `PLACE`, `AD`), plus
`…/places/bounds`. Le point dur est de **ne pas contourner les règles de visibilité** : une union de
requêtes projetées, une par type, jamais du HQL brut sur `team_entities`. Plafond dur de features et
refus explicite des bbox trop grandes, sinon `types=ROUTE` sur le monde renvoie plus de 5 500
features (5 527 parcours en prod au 16 octobre 2026). Cet
endpoint doit rester **non paginé et borné**.

Les features `type=AD` sortent **floutées** et doivent se rendre en **secteur, jamais en punaise** —
une carte qui mélange les types est précisément l'endroit où l'on dessinerait tout le monde avec le
même marqueur.

À noter : ce n'est **pas** un prérequis de la vue carte des parcours, qui fonctionne déjà par les
tuiles MVT. C'est ce qui permet d'y **ajouter** les autres entités.

#### `API-27` Coût du lot de géométries — ce qui reste après 2.0.0

Le paramètre `simplify` et `…/elevation-profile` ont été supprimés en 2.0.0 (`API-40`).

`MAX_BULK_SLUGS = 50` est désormais le *seul* garde-fou du
lot, sur un endpoint `@PermitAll` que seule borne la limite globale par client (`SEC-28`, en nombre
de requêtes, pas en poids). Un lot réaliste de 50 parcours pèse
3,2 Mo ; les 50 plus lourds de la base pèsent 64 Mo (chiffres à remesurer : la base compte deux
fois plus de parcours depuis l'import de n-peloton). Ce cas suppose un appelant qui sait lesquels
sont les plus lourds et les nomme tous : c'est un sujet de **rate limiting**, pas de contrat. Le
levier si ça devient sensible est de descendre `MAX_BULK_SLUGS` vers ~15 (les appelants réels
plafonnent à 12, `kTripTrackStageCap`), pas de réintroduire un paramètre de finesse.

### Petites évolutions d'API qui suppriment chacune une dégradation nommée

Extrait du §5.2 du plan mobile. Aucune ne bloque un écran ; chacune retire un repli visible.
Beaucoup sont des ajouts d'un champ — le rapport valeur/effort y est bon. Les numéros reprennent
ceux du plan (`API-1`, l'URL de tuile authentifiable, est livré).

| ID | Manque | Écrans | Dégradation actuelle |
|---|---|---|---|
| `API-8` | Voisins de publication (`prev`/`next`) — absents de tout le contrat `11.5.1` (balayage de tous les schémas le 16 octobre 2026) | 31 | Navigation rendue seulement depuis un fil déjà chargé |
| `API-17` | `?format=polyline` sur la géométrie de parcours | — | La géométrie stockée est déjà allégée à l'import (`API-40` : 681 points et 65 Ko pour le parcours médian) ; ~÷4 sur le poids, au prix d'un décodeur Dart. **À rouvrir seulement sur une mesure réelle** — aucune n'a été faite au 16 octobre 2026 ; sans mesure, candidat à « Délibérément dehors » (décision du propriétaire) |
| `API-18` | Voyage comme événement multi-jour au calendrier (`CalendarEventType`, toujours `RIDE`/`TRIP_STAGE`) | 22 | Un voyage sans étape est absent du calendrier ; avec des étapes, elles y sont, le voyage en tant qu'objet non |
| `API-19` | `GET /api/search?q&types=&limit` unifié | — | Plus aucune recherche transverse : `GET /api/users/search` a été **supprimé** en `3.0.0` (`API-39`). La seule recherche de personnes est celle du trombinoscope d'une équipe |

Le meneur de groupe (`API-41`, livré en 1.5.0), l'URL de tuile (`API-1`) et la pagination du
calendrier (`API-20`) sont dans
[`LEDGER_DONE.md`](LEDGER_DONE.md). Les **gabarits de sortie n'ont volontairement pas de meneur** —
décision produit : `RideTemplateGroupRequest` reste sans champ.

### Envoi automatique des parcours vers les services GPS : ce qui reste après `API-120`

Le cœur d'`API-120` (contrat `11.5.0`, migration `V71`, planificateur et worker, envois manuels
suivis dans `gps_route_syncs`) est livré et tourne en prod depuis le 16 octobre 2026 : 3 connexions
en envoi automatique (Hammerhead, Wahoo, Garmin OAuth 1.0a), 5 parcours envoyés sans erreur.
`GPS_SYNC_ENABLED` vaut `true` en prod et en staging ; la politique le décrit depuis le
16 octobre 2026 (`LEGAL-21`), et `docs/OPERATIONS.md` le documente ; reste la recette sur
appareil (`OPS-42`, étape 7 du plan
[`2026-10-16-gps-route-autosync.md`](plans/2026-10-16-gps-route-autosync.md)).

- [ ] `API-125` **Les restes d'`API-120` : nom envoyé, envoi manuel d'une route suivie,
  étape 0 (S)** — trois écarts que la livraison a laissés ouverts :
  - **Le nom envoyé ne suit pas la règle `WEB-83`** : `GpsSyncNames.autoName` met le nom brut du
    groupe, sans le préfixe « Groupe » des clients (« 2026-10-18 · A · … » pour un groupe nommé
    « A »). Une seule règle à partager avec `WEB-83` : le préfixe, sauf quand le nom commence déjà
    par ce mot.
  - **Un envoi manuel d'une route que la synchronisation tient renvoie le nom automatique**
    (« date · groupe · route », `GpsRouteSyncExecutor` ne prend `route.getName()` que sans nom
    voulu) plutôt que celui de la route : trancher lequel est voulu, et le dire.
  - **L'étape 0 du plan n'a pas été faite comme prévue** : les envois réels de prod établissent la
    création chez les trois services ; restent supposés le code d'un `PUT`/`DELETE` sur un parcours
    supprimé par l'utilisateur (404 ?), le renommage par `PUT` chez Hammerhead, la réponse du `PUT`
    Garmin, un second `POST` Wahoo avec le même `external_id`, et l'absence de limite de débit
    Hammerhead. Les observer (sur les comptes de test ou dans les journaux de prod), puis les
    consigner au §5 du plan et ajuster le tableau du §4.4.
- [ ] `API-126` **L'envoi manuel vers un service GPS traite 401, 412 et 429 comme la
  synchronisation (S)** — la synchronisation tire déjà de `GpsCallResult.ofFailure` une connexion
  « à reconnecter » (401, 412) ou une pause qui respecte `Retry-After` (429) ; l'envoi manuel (web,
  mobile, Karoo : `GpsRouteSyncService.uploadManually`, puis `GpsCallResult.toUploadResult`) les
  réduit à un message « Upload failed: 401/412/429 », sans marquer la connexion ni retenir la pause.
  Le membre recommence sans savoir qu'il doit reconnecter le service. Vaut pour les trois services,
  OAuth 1.0a Garmin compris ; le reste de la conformité Garmin est `API-61`.
- [ ] `API-122` **L'état « déjà chez le service GPS » de « Prochaines sorties » éprouvé sur un
  vrai Karoo et un vrai Edge (S)** — l'affichage livré par `API-121` (contrat `11.5.0`, embarqué
  dans `karoo.1.0.13` et `garmin.1.0.1`) n'a aucun test côté appareils. Même écran que `API-119` :
  une seule séance pour les deux. La prod a de vraies lignes synchronisées depuis le 16 octobre
  2026. À vérifier sur Karoo : chaque libellé (déjà sur le Karoo, ancienne version, mise à jour en
  attente, envoi en échec, reconnecter) sur une ligne au repos, et une ligne synchronisée depuis le
  Karoo qui reste « Déjà sur le Karoo » après la synchro d'une autre ligne et un retour à la liste.
  Sur Edge (ou simulateur) : le libellé en tête du sous-titre, lisible sur petit écran. Puis la
  version courante contre un serveur `11.4.0` (rien d'affiché) — sur une pile locale, la prod étant
  en `11.5.1` ; le cas des apps précédentes est celui d'`API-119`.

### Garmin

- [ ] `API-61` **Mettre l'intégration Garmin OAuth 2.0 en conformité** — **bloqué** : le programme
      Garmin Connect Developer n'admet aucune nouvelle application tant qu'il est en pause (toujours
      sans date de réouverture au 16 octobre 2026) ; en attendant, les domaines passent par OAuth
      1.0a avec les applications déjà déclarées (`API-62`), qui marchent en prod. À reprendre quand
      l'application OAuth 2.0 pourra être créée, d'après la doc Garmin
      (Courses API 1.0.1, OAuth2 PKCE, Start Guide 1.2). Ce qu'il reste, tout dans
      `infrastructure/gps/GarminClient.java` et `service/gps/GpsService.java` :
      - **`externalUserId` toujours null** : la réponse du jeton n'a pas de `user_id` ; il faut
        `GET https://apis.garmin.com/wellness-api/rest/user/id` après l'échange (identifiant
        principal selon Garmin, celui que portent les webhooks).
      - **Déconnexion sans prévenir Garmin** : `GpsService.disconnect` (et l'effacement du compte)
        doit appeler `DELETE https://apis.garmin.com/wellness-api/rest/user/registration`, que
        Garmin exige dès qu'une app propose une déconnexion.
      - **Codes d'erreur** : la synchronisation automatique (`API-120`) distingue déjà 401 et 412
        (connexion à reconnecter) et 429 (pause selon `Retry-After`) ; l'envoi manuel les confond
        encore (`API-126`). Reste, propre à Garmin : un 401 (jeton révoqué) devrait
        supprimer la connexion plutôt que la laisser « à reconnecter » ; la revue de production
        vérifie la gestion des quotas.
      - **Marge de rafraîchissement** : `GpsServiceConnection.isTokenExpired()` prend 300 s, Garmin
        recommande au moins 600 s (jeton de 86 400 s ; refresh token de 90 jours, renouvelé à
        chaque refresh — déjà géré).
      - **Taille des parcours** : ~10 000 points au plus, 100 m au plus entre deux, un point tous
        les 100 m recommandé — rien ne le vérifie ni ne rééchantillonne.
      - **Webhooks** désinscription et changement de permissions (Start Guide §2.6) : sans eux une
        connexion révoquée côté Garmin reste « connectée » jusqu'au premier 401.
      - **`activityType`** toujours `ROAD_CYCLING` (biketeam le tirait du type de carte), et le D+
        de `GarminCourseConverter` saute un point à 0 m exactement (`prevEle != 0` sert de « pas
        d'altitude »).

      Les points 401, quotas, taille et `activityType` valent aussi en OAuth 1.0a. Une fois
      l'application créée, basculer le domaine se fait dans l'admin (protocole du credential
      Garmin) : les connexions OAuth 1.0a sont alors abandonnées à leur prochain envoi et chacun
      reconnecte Garmin. Taille : M.
- [ ] `API-110` **App Garmin : rendre les Edge plus anciens éligibles** — `manifest.xml` exige
      `minApiLevel="3.3.0"` sans raison trouvée dans le code : avec `3.1.0`, `edgeexplore`
      (240×400), `edge520plus` et `edge820` (200×265) compilent (essai du 15 octobre 2026 sur une
      copie, SDK 9.2.0), et la référence de l'Edge 1030 restée en API 3.2.5 recevrait aussi l'app.
      Rien n'a tourné à l'exécution : vérifier sur appareil ou simulateur l'appairage, les listes et
      le téléchargement FIT, et la lisibilité du petit écran 200×265 (QR code compris). Ajouter les
      ids au manifest **et** à `DEVICES` du `Makefile`, corriger au passage le commentaire du
      manifest (« API 3.2.0+ »), et la ligne « Connect IQ API 3.3.0 or higher (`minApiLevel`) » de
      `garmin-app/README.md`. La 1.0.1 est sortie sans changer les appareils.
      Hors d'atteinte : `edge130`/`edge130plus` (pas de type `watch-app`), `edge_1000`/`edge_520`
      (API 2.4). Taille : S.
- [ ] `API-111` **App Garmin sur les montres qui suivent un parcours** — l'app ne cible que les
      Edge, alors qu'elle compile sans changement (essai du 15 octobre 2026) pour Venu X1, fenix 6
      Pro à 9, epix 2, Enduro 3/4, Forerunner 245 à 970, Instinct 2/3/E, MARQ. Ce qui manque est
      l'interface : les décalages fixes de `VerticalLayout.mc` (`AUD-27`) sont rognés sur un écran
      rond, le QR de `LoginView.mc` doit tenir dans le carré inscrit (~0,7 × le diamètre), et la
      navigation doit marcher aux boutons seuls (fenix 6, FR 745/945, Instinct). Ordre proposé :
      `venux1` (rectangulaire, tactile) ; puis fenix 7/8, epix 2, Enduro, FR 265/965/970 ; les
      Instinct à petit écran (163–176 px, 96–128 Ko) en dernier ou jamais. Avant tout ajout,
      vérifier modèle par modèle que la montre navigue un parcours (non confirmé par une source
      Garmin) ; Venu 2–4, vivoactive et FR 165/170/55 restent dehors tant que ce n'est pas établi.
      Les GPS de randonnée (GPSMAP, Montana, Oregon) sont exclus : API trop basse, et ils prennent
      le GPX, pas le FIT (doc `PersistedContent` du SDK). Taille : M (L avec les Instinct).
- [ ] `API-119` **« Prochaines sorties » éprouvé sur un vrai Karoo et un vrai Edge (S)** — la
      liste des groupes inscrits et le chargement direct de leur trace (`API-118`, contrat `11.4.0`,
      embarqués dans `karoo.1.0.13` et `garmin.1.0.1`) n'ont aucun test côté appareils (le backend
      est couvert par `DeviceRegisteredGroupsResourceTest` et `DeviceRoutesQueryCountTest`). Même
      séance qu'`API-122`. À vérifier sur Karoo :
      l'entrée en tête, la synchro Hammerhead depuis la ligne et son état affiché, le retour à
      l'accueil. Sur Edge (ou simulateur) : l'entrée et « Aucune inscription », la barre de
      progression, le FIT présent dans les parcours, et « Autre téléchargement en cours » sur un
      second clic pendant un téléchargement. Puis les apps publiées précédentes, antérieures à
      `API-118` (`karoo.1.0.12`, `garmin.1.0.0`), contre la prod en `11.5.1` (champs inconnus
      ignorés).

### Vie privée : ce que la politique doit encore décrire faute de mieux

- [ ] `API-47` **Les documents joints gardent leurs métadonnées** — PDF (auteur, JPEG embarqués
      avec leur EXIF), fichiers bureautiques (`docProps`), PSD (EXIF/IPTC) sont stockés tels quels ;
      la politique (§1) le dit. À trancher : les nettoyer (dépendance nouvelle pour le PDF), ou
      garder la phrase. Taille : M à L. exiftool **n'aide pas** (mesuré le 29 septembre 2026,
      `API-54`) : il ajoute une mise à jour incrémentale réversible, le dictionnaire Info reste dans
      les octets, et l'EXIF des JPEG embarqués est intact. Seule voie : réécriture complète (PDFBox)
      en faisant réencoder les JPEG embarqués comme les images (`API-43`). L'enjeu est mince : au
      16 octobre 2026, la prod compte 8 PDF parmi ses pièces jointes, et aucun fichier bureautique
      ni PSD ; garder la phrase (« Délibérément dehors ») reste une issue (décision du propriétaire).

---

## OPS — Exploitation, déploiement, recette du backend

### Recette du backend en conditions réelles

Ce que les tests ne prouvent pas, parce qu'ils ne passent ni par Flyway ni par un vrai relais SMTP.

- [ ] `OPS-3` **Le relais de contact en production : regarder un message reçu** — les gabarits
      `ad-contact.{fr,en}` sont rendus par le backend (`templates/mail/`) et partent par le relais
      SMTP de Scaleway TEM comme tout le reste. L'envoi par TEM est constaté le 16 octobre 2026 :
      11 contacts d'annonce en base depuis la bascule du 22 septembre (le dernier le 4 octobre),
      aucune erreur du mailer dans les journaux de prod sur sept jours. **Reste** : un envoi réel
      vers une boîte du propriétaire, pour lire les en-têtes et le corps — le `Reply-To` doit porter
      l'adresse de l'auteur et le corps ne doit jamais l'imprimer. Se fait dans la même séance
      qu'`OPS-4`. Taille : XS.
- [ ] `OPS-4` **Les quatre gabarits d'invitation en production : les recevoir** —
      `team-invitation.{fr,en}` et `team-invitation-signup.{fr,en}` vivent dans `templates/mail/` et
      partent par le relais SMTP de Scaleway TEM. Params des quatre : `appName`, `inviterName`,
      `teamName`, `invitationUrl`, `expiresInDays`. Un envoi réel par TEM est constaté le
      16 octobre 2026 : deux invitations créées après la bascule, toutes deux `ACCEPTED` (la
      dernière le 3 octobre), aucun `TEAM_INVITE_DELIVERY_FAILED` dans les journaux sur sept jours —
      sans savoir laquelle des quatre variantes est partie ni à quoi elle ressemblait. **Reste** :
      recevoir chacune des quatre (fr/en × compte existant/inscription) et en vérifier le rendu,
      dans la même séance qu'`OPS-3`. Si le relais refuse le message, `POST …/invitations` répond
      **500 `TEAM_INVITE_DELIVERY_FAILED`** — délibérément, plutôt qu'un `INTERNAL_ERROR` opaque —
      et la transaction est annulée : aucune invitation fantôme ne subsiste. Taille : XS.
- [ ] `OPS-44` **Un test automatisé pour « `AdDto` ne porte aucun champ de contact »** —
      l'invariant (relais d'e-mail, aucune adresse dans l'API) n'est gardé que par le `grep` et le
      script Python du §5.3 du
      [document d'API](plans/archive/2026-07-26-api-v2-livraison-et-suites.md), à lancer à la main
      (rejoués le 16 octobre 2026 sur le contrat `11.5.1` : `OPS-5`). Le jour où un champ de
      contact y entre, une adresse personnelle est publiée à toute une équipe, irrévocablement, et
      aucun build ne le voit. En faire un test backend qui lit le schéma OpenAPI généré (ou les
      composants du record `AdDto`) et échoue sur `contact|email|phone|mail|tel`. Taille : XS.
- [ ] `OPS-29` **Météo des sorties en production : ce qui reste (S)** — la recette technique est
      faite (V61 passée le 6 octobre 2026 sur `de205e4d`) et tient le 16 octobre : 63 cellules en
      prod et 12 en staging, fraîches, toutes à `attempts = 0`. Seuls échecs dans les journaux sur
      48 h : des `Open-Meteo answered 503: The service is overloaded` intermittents (6 en prod,
      au moins 4 en staging), sans dommage puisque le cache reste frais. Restent : **régler les
      budgets de staging**, dont le `.env` n'a toujours aucune clé `OPEN_METEO_*` ni `WEATHER_*` —
      prod et staging sortent par la même adresse IP et, à leurs défauts (5 000 appels par jour
      chacun, `application.properties`), atteignent ensemble les 10 000 appels par jour du plan
      gratuit (voir [OPERATIONS](OPERATIONS.md#ride-weather-open-meteo)) ; **voir** la météo d'une
      sortie à J+2 sur le web — sur la page de groupe refaite par `WEB-94` et `API-123` — et dans
      l'app (les sorties à venir sont en visibilité `TEAM`, non vérifiables sans session).
      **À trancher par le propriétaire** : l'offre gratuite d'Open-Meteo est réservée à un usage non
      commercial ; si Pédalons ne s'y range pas, un plan payant ne demande que `OPEN_METEO_URL` et
      `OPEN_METEO_API_KEY`.

### Exploitation

- [ ] `OPS-19` **Passer PostgreSQL 17 → 18** — dependabot l'a proposé (PR #338, fermée le
      29 septembre 2026 avec `ignore this major version`) en ne changeant que l'image de
      `docker-compose.yml`, ce qui empêcherait la prod de redémarrer : les fichiers d'un cluster 17
      ne s'ouvrent pas en 18, et l'image 18 attend ses données sous `/var/lib/postgresql/18/docker`,
      le volume monté sur `/var/lib/postgresql` (le montage actuel sur `…/data` la fait refuser de
      démarrer). À faire ensemble : dump avec `scripts/backup.sh`, nouveau volume au nouveau point
      de montage, restauration avec `scripts/restore.sh` ; l'image des devservices
      (`quarkus.datasource.devservices.image-name`, `application.properties`) pour que les tests
      tournent sur la même version ; la doc qui annonce « PostgreSQL 17 » (CLAUDE.md, README.md,
      backend/README.md). Rien ne presse tant que la 17 est maintenue. Taille : S.
- [ ] `OPS-45` **Les tests ne tournent pas sur le PostGIS de la prod** —
      `quarkus.datasource.devservices.image-name` (`application.properties`) est resté à
      `imresamu/postgis:17-3.5-alpine` quand `docker-compose.yml` (et donc la prod, constaté le
      16 octobre 2026) est passé à `imresamu/postgis:17-3.6-alpine`. L'aligner sur `17-3.6-alpine`,
      indépendamment d'`OPS-19`. Taille : XS.
- [ ] `OPS-21` **Ce que le monitoring ne voit pas encore** — PostgreSQL (connexions, taille, bloat,
      requêtes lentes : un `postgres_exporter` par environnement, sur `pedalons-shared`), le
      frontend SSR (ni métriques Node ni temps de rendu : seul Caddy le voit, par hôte), et les
      erreurs côté client web et mobile (un GlitchTip, compatible Sentry, pèserait une base et un
      Redis de plus : à ne faire que si le besoin se confirme). Taille : M.
- [ ] `OPS-30` **Check Healthchecks du rafraîchissement des données des relecteurs des stores**
      (scindé de `OPS-28`) — `~/.config/pedalons/store-demo.env` n'a pas de `STORE_DEMO_PING_URL` :
      le cron tourne sans que personne ne voie qu'il échoue, et il a échoué sans bruit du 3 au
      6 octobre 2026, puis de nouveau après le contrat 11.0.0, jusqu'à ce que `MOB-63` atteigne
      `~/prod` (passage du 16 octobre à 05:00 : `✔ refreshed`). Créer le check (quotidien, 05:00
      Europe/Paris, avec une marge) et ajouter son URL au fichier
      ([`OPERATIONS.md`](OPERATIONS.md#store-reviewers-demo-data)). Taille : XS.
- [ ] `OPS-46` **(Optionnel) Alerte sur la taille du cache de tuiles du backend** — le
      cache d'élévation IGN (`~/prod/data/cache/ign-lidar-hd-mnt/` et `ign-lidar-hd-mns/`) pesait
      6,8 Go le 16 octobre 2026, trois semaines après `API-104`, et n'a ni plafond ni éviction ; la
      veille manuelle d'`OPS-31` n'a rien trouvé d'alarmant (disque à 15 %), mais personne ne
      regardera la prochaine fois. Une alerte Prometheus sur la taille du répertoire (ou un plafond
      dans le code du cache) remplacerait cette veille. Taille : XS à S.
- [ ] `OPS-34` **Faire revalider la Search Console après `WEB-85`, `WEB-86` et `API-109`** — le
      rapport du 15 octobre 2026 sur pedalons.fr listait 122 URL non indexées. Les trois entrées
      sont en production, et les vérifications à la main sont faites le 16 octobre :
      `https://pedalons.fr/robots.txt` (redirigé vers www) porte les `Allow` d'images et la ligne
      `Sitemap`, une page servie sous `/teams/…` a son `<link rel="canonical">` vers `/equipes`, et
      `/api/version` répond `X-Robots-Tag: noindex`. **Reste** : dans la Search Console, cliquer
      « Valider la correction » sur les motifs « Introuvable (404) », « Page en double sans URL
      canonique sélectionnée par l'utilisateur » et « Explorée, actuellement non indexée », puis
      revenir sur le rapport quelques semaines plus tard. Le 404 d'`auth.pedalons.fr` est traité à
      part (`OPS-47`). Taille : XS (surtout de l'attente).
- [ ] `OPS-47` **Un `robots.txt` pour `auth.pedalons.fr`** (extrait d'`OPS-34`) — la
      Search Console signale le sous-domaine en 404 : il répond 404 à sa racine comme à
      `/robots.txt`. Il sert encore — le Caddyfile de l'hôte l'envoie vers `127.0.0.1:8091` et le
      conteneur `strava-auth-proxy-proxy-1` tourne (constaté le 16 octobre 2026) —, donc pas de
      retrait du DNS : lui servir un `robots.txt` `Disallow: /`, depuis son bloc du Caddyfile ou
      depuis le proxy. Taille : XS.
- [ ] `OPS-41` **Mesure d'audience du site : consigner la recette, puis relire au bout d'un mois
      (S)** — plan [`2026-10-15-web-analytics.md`](plans/2026-10-15-web-analytics.md) (§8, étapes
      5 et 6 ; scindé d'`OPS-36`). Le déploiement et l'activation sont faits et constatés le
      16 octobre 2026 (au ledger des livraisons sous le même identifiant). **Reste** :
      - les vérifications de l'étape 6, à faire ou refaire et à **consigner dans `OPERATIONS.md`**,
        où rien n'est écrit : une visite sans DNT comptée sous son gabarit, la même sous DNT non ;
        aucune IP de visiteur dans le journal du conteneur ; aucune ligne `/count` dans le journal
        de Caddy, **bloc par bloc** — le Caddyfile de l'hôte en a neuf (clubs et alias), et seule
        la présence de `log_skip @count` est constatée, pas son effet sur chacun ; `store` sans
        session après un redémarrage ; une panne de base simulée sans ligne `hit =` dans Loki ; la
        purge de rétention passée le lendemain ; le tunnel SSH jusqu'au tableau de bord ;
      - **confirmer par écrit la précondition du §5.3** — aucun membre réel n'avait accepté la
        politique précédente (comptes hors test et équipe, inscrits bêta, équipes migrées de
        biketeam, invitations acceptées) ; sinon l'e-mail du §11 à chaque membre. Aucune trace de
        cette vérification, alors que le compteur tourne déjà ;
      - mettre à jour l'en-tête du plan, qui dit encore « Rien n'est en production » ;
      - **vers le 15 novembre 2026** : relire les chiffres contre les cinq questions du §1 du plan,
        puis l'archiver (`docs/plans/archive/`, avec sa ligne dans le README des archives).
      Taille : S, surtout manuel sur l'hôte.
- [ ] `OPS-42` **Envoi automatique des parcours : la recette sur appareil, faite après
      l'allumage (S)** — `GPS_SYNC_ENABLED` est à `true` en prod et en staging depuis le 16 octobre
      2026, avant la recette que le plan
      [`2026-10-16-gps-route-autosync.md`](plans/2026-10-16-gps-route-autosync.md) prévoyait
      (étape 7). Les premiers envois réels (3 connexions, 5 parcours, aucune erreur) établissent la
      création chez les trois services ; reste à voir, sur un Karoo, un Edge et un ELEMNT, le
      parcours arriver, changer avec sa route, disparaître après la sortie, à la désinscription, à
      la désactivation et à la déconnexion, et l'état « à reconnecter » après une révocation chez
      le service. Ce qui y est seulement supposé est sous `API-125`. Le drapeau est documenté
      (« Automatic route sync to GPS services » dans `docs/OPERATIONS.md`) et la politique le
      décrit (`LEGAL-21`).

---

### Extension Karoo : catalogue Hammerhead

- [ ] `OPS-33` **Publier l'extension Karoo dans l'Extension Library de Hammerhead** (scindé
      d'`OPS-32`) — l'app ne s'installe aujourd'hui que par sideload. Créer le compte développeur
      sur dashboard.hammerhead.io, y déclarer l'URL du manifest (la GitHub directe,
      `releases/download/karoo-latest/manifest.json`, modifiable là-bas à tout moment), vérifier
      que l'app apparaît dans l'Extension Library des Karoo liés au compte, puis la soumettre à SRAM
      (accord de licence SDK, plusieurs semaines). Le processus est décrit dans `karoo/PUBLISH.md`.
      Non vérifié à cette occasion : à quelle fréquence le Karoo relit le manifest, et s'il garde
      le tag `navigation`, hors des quatre que documente karoo-ext. (S, surtout de l'attente)

### App Garmin : Connect IQ Store

- [ ] `OPS-35` **Publier l'app Garmin sur le Connect IQ Store** — la 1.0.0 (13 Edge) est soumise
      à la revue le 15 octobre 2026, remplacée en revue par la 1.0.1 (« Prochaines sorties »,
      tag `garmin.1.0.1`) le 16 octobre, fiche FR/EN tirée de `garmin-app/metadata/` ; page du store
      (démo, visible du seul compte tant qu'elle n'est pas validée) :
      `https://apps.garmin.com/fr-FR/apps/262ea335-a5b7-4a6a-bb30-fc6f5db9b115`. Le formulaire et
      ses pièges (signature « échouée » au premier dépôt, migration désactivée) sont dans
      `garmin-app/PUBLISH.md`. Le 16 octobre au soir, l'API publique du store répond encore
      `The requested app is not approved`. Reste : la décision de Garmin (jusqu'à 3 jours, donc
      attendue vers le 19 octobre ; un rejet arrive par e-mail), un essai sur un vrai Edge depuis
      la page démo (non fait avant l'envoi), puis le lien vers la fiche sur `/applications`
      (`apps.garmin.description` dit « arrive bientôt ») et dans l'app mobile, et un mot aux
      inscrits de la bêta. Ne bloque pas mais se verra sur l'appareil : `AUD-26` (AM/PM en dur).
      `AUD-25` limite l'app à pedalons.fr. Taille : XS, surtout de l'attente.

## NOTIF — Notifications

Les phases 1 à 5 de [`plans/archive/2026-09-18-notifications.md`](plans/archive/2026-09-18-notifications.md)
sont en production, le Web Push aussi depuis le 29 septembre 2026 ; ce qui en est livré, et les
pièges à ne pas rejouer, sont sous `NOTIF-9` (le ledger du chantier y a été rapatrié le
29 septembre 2026). Restent deux points qui ne sont pas du code (`NOTIF-1`, `NOTIF-2`), et trois
qui le sont (`NOTIF-3`, `NOTIF-4`, `NOTIF-11`) :

- [ ] `NOTIF-1` **Recette du webhook d'équipe** contre un vrai Slack, un vrai Discord et un vrai
      Mattermost (bouton « Envoyer un test ») — vérifier au passage qu'un `@channel` dans un nom de
      sortie ne notifie personne sur Mattermost. Peu pressant : aucune équipe n'a de webhook, ni en
      production ni en staging (`team_webhooks` vide au 16 octobre 2026).
- [ ] `NOTIF-2` **Décision produit sur l'e-mail** : `PEDALONS_NOTIFICATIONS_EMAIL_ENABLED` reste à
      `false` en production (décision du 21 septembre 2026, « pas pour le moment »). L'activer,
      c'est écrire aux équipes entières, en connaissant les défauts (annulations, voyages publiés).
- [ ] `NOTIF-3` **Webhook d'équipe : le *DNS rebinding* n'est pas couvert** — `WebhookHttpClient`
      refuse toute résolution vers une adresse interne, mais `HttpClient` résout de nouveau à la
      connexion : un nom qui change de réponse entre les deux passe. Le fermer voudrait dire
      épingler l'adresse vérifiée pour la connexion (voir la javadoc de `WebhookHttpClient`).
- [ ] `NOTIF-4` **Le canal e-mail des notifications n'a pas de test e2e** : il est coupé en
      production comme sur la stack e2e (`NOTIF-2`). Laissé ouvert par l'audit de couverture e2e
      (`WEB-26`).
- [ ] `NOTIF-11` **Rejouer `CoalesceRace` sur le correctif exact de `NOTIF-10`** : dans le modèle
      ([`formal/notif/`](formal/notif/)), la variante la plus proche du correctif livré (`FIX=2`) viole
      encore l'invariant ; la relecture du code n'a trouvé aucun entrelacement perdant, mais le modèle
      n'a pas été adapté (réinsertion quand la clé a été rendue). L'adapter, et ajouter le test de la
      variante « fusion dans la ligne en attente pendant qu'une réservation est tentée ». Taille : S.

---

## MOD — Modération et signalement

Livrée le 24 septembre 2026 (`MOD-6`). Les quatre défauts mineurs notés à la livraison sont corrigés
(`MOD-1` à `MOD-4`).

---

## ISSUE — Signaler un problème → issues GitHub

En service en production depuis le 29 septembre 2026 (`ISSUE-6`, API 4.6.0). Suites possibles, non
faites :

- [ ] `ISSUE-1` **Piles web illisibles** : le bundle est minifié et l'empreinte ne garde que le nom
      du chunk. L'option de build existe : `FRONTEND_SOURCEMAP` dans le `.env` de la stack, que
      `build.sh` passe en `VITE_BUILD_SOURCEMAP`. Elle est à `false` en production et à `true` sur
      staging, qui **sert** aujourd'hui ses `.map` (voir `ISSUE-10`). Restent : ne pas
      servir les `.map` mais les archiver avec l'image, l'activer en production, puis automatiser la
      symbolisation côté serveur.
- [ ] `ISSUE-10` **Staging sert publiquement ses sourcemaps** — `FRONTEND_SOURCEMAP=true`
      dans le `.env` de staging : le conteneur frontend contient 408 `.js.map`, servis en 200 sous
      `/assets/` (constaté le 16 octobre 2026). Décider : les retirer de l'image servie et les
      archiver à part (`ISSUE-1`), ou l'assumer, le dépôt étant public. Taille : XS.
- [ ] `ISSUE-2` **Côté mobile**, si le build release passe à `--obfuscate`, conserver les
      `--split-debug-info` par build, sans quoi les piles Dart deviennent inexploitables et
      l'empreinte change à chaque version. La consigne vaut pour les trois chemins de build
      release : `publish_test.sh`, `publish_beta.sh` et le workflow `mobile-release.yml`.
- [ ] `ISSUE-3` **Plantages natifs** (Kotlin/Swift) : non couverts, seuls les handlers Dart
      remontent.
- [ ] `ISSUE-4` **Boucler avec le membre** : le prévenir quand l'issue de son signalement est fermée
      (webhook GitHub → notification), joindre une capture d'écran, corréler avec les logs serveur
      par request-id.
- [ ] `ISSUE-5` **Visiteurs non connectés** : ni signalement ni remontée automatique (l'endpoint
      exige une session). Une erreur sur la page de connexion n'arrive donc que par e-mail.

---

## MIG — Migration biketeam

Configurée en production des deux côtés ; des essais (`dryRun`) y ont réussi sur `gaby` et
`n-peloton` du 11 au 15 octobre 2026, sans bascule. Reste le passage réel
([plan](plans/2026-09-22-biketeam-live-migration.md) §10). Source :
[`MIGRATE_BIKETEAM.md`](MIGRATE_BIKETEAM.md).

### Mise en production

- [ ] `MIG-1` **Passage réel** : les secrets sont posés des deux côtés et les essais sont faits
      (part livrée sous le même identifiant) ; reste la bascule de chaque équipe (`dryRun` décoché ;
      aucun job réel en production au 16 octobre 2026). Pour chaque équipe qui a un domaine personnalisé chez biketeam, vérifier que
      la redirection fonctionne : elle se règle au proxy, au cas par cas (plan §13, décision 11).
- [ ] `MIG-2` **Redirections 302 → 301** : une fois les bascules stabilisées, poser
      `PEDALONS_REDIRECT_STATUS=301` côté biketeam. Pas avant : un 301 est mis en cache par les
      navigateurs et ne se rattrape pas.
- [ ] `MIG-3` **Liens internes non réécrits** : les liens vers `prendslaroue.fr` dans les pages
      d'équipe (FAQ, descriptions) restent pointés vers biketeam et redirigent tant qu'il tourne. À
      corriger — à la main, par l'équipe, ou par une réécriture depuis la table d'URL — **avant**
      l'arrêt de biketeam.
- [ ] `MIG-6` **Données exportées mais non importées** : la ville et le pays de l'équipe arrivent
      dans l'instantané (`BiketeamSnapshot`) sans être utilisés (plan §13, décision 14) ; à
      décider. Un usage s'offre depuis que l'équipe a un fuseau (`API-60`) : l'initialiser à la
      migration à partir du pays et de la ville. Les tags de parcours, qui en faisaient partie, sont
      importés depuis le 1er octobre 2026 (`MIG-14`).
- [ ] `MIG-7` **Avant l'arrêt de biketeam** : outre les liens internes (`MIG-3`), les logos
      `/{t}/image` ne sont pas redirigés et restent servis par biketeam (plan, écarts biketeam,
      point 16).
- [ ] `MIG-8` **Après l'arrêt de biketeam** : retirer la migration en direct (endpoints internes,
      worker, les cinq variables, la page `biketeamMigration`, les codes `BIKETEAM_*`, peut-être
      `biketeam_migrations`), **sans** retirer `biketeam_migration_map`, dont dépendent encore
      `UserTeamRepository.findMigratedTeamsAdministeredAlone` (décision 22) et
      `BiketeamTargetResolver`. Archiver alors le plan, qui reste jusque-là le contrat en vigueur.

### Autour de la migration

- [ ] `MIG-9` **Purge physique des équipes à la corbeille** (reset de migration biketeam) — chantier
      séparé. Un `reset` de la migration en direct met l'équipe Pédalons à la corbeille et libère
      son slug (`TeamService.deleteTeam`), rien de plus : lignes `team_entities`, assets et fichiers
      S3 restent. Chaque reset en laisse un exemplaire de plus. **Quand** : si le volume le
      justifie, ou avec une politique de rétention générale de la corbeille. Décision du 2026-09-22
      ([plan](plans/2026-09-22-biketeam-live-migration.md) §13, décision 10). Le cas s'est produit
      en production : au 16 octobre 2026, trois équipes y sont à la corbeille, dont la copie de
      `n-peloton` laissée par le reset du 15 octobre, avec 3 328 lignes `team_entities` en tout, sans
      compter les assets S3.

---

## BRAND — Charte

Le code couleur métier a une source unique depuis `BRAND-2`.

---

## SEC — Audit de sécurité

Cette section fait seule foi pour les constats de sécurité ouverts. L'audit de septembre 2026 est
archivé ([`plans/archive/2026-09-security-audit.md`](plans/archive/2026-09-security-audit.md), statuts figés au 9 octobre 2026) ; la colonne
« Audit » garde l'identifiant du constat dans ce document. Le dépôt est public : une entrée ne
porte **aucun détail exploitable** (scénario, preuve, point d'entrée) tant que le constat est
ouvert, seulement sa sévérité et une phrase. Corrigé, il passe dans `LEDGER_DONE.md` sous son
identifiant, avec son détail.

| ID | Priorité (audit) | Audit | Sévérité | Constat |
|---|---|---|---|---|
| `SEC-12` | — | L3, L10 | Faible | Voir la table des constats faibles de l'audit ; L1 et L5 à L9 sont livrés sous `SEC-20`, L12 et L13 sous `SEC-22`, L14 sous `SEC-23`, L4 sous `SEC-24` |
| `SEC-13` | — | L11 | Faible | Durcissement des workflows GitHub Actions — permissions minimales posées sur les quatre workflows d'alors (`09c65ecd`, `e8fbc3be`, `8bf6fa9f` ; `karoo-release.yml` limite son seul job à `contents: write`), et sur le cinquième, `mobile-release.yml` (`80122a0d`, même limite) ; reste l'épinglage des actions par SHA, à commencer par les actions tierces des deux workflows qui décodent le keystore : `karoo-release.yml` et `mobile-release.yml` (`subosito/flutter-action`, `softprops/action-gh-release`). Le suivi `github-actions` de Dependabot tiendra les SHA à jour |
| `SEC-14` | — | Info | — | Images externes dans le markdown ; le parseur XML et le paramètre non encodé sont livrés sous `SEC-21` |
| `SEC-40` | — | Suite de `SEC-31` | Moyenne | La CSP complète du site n'est encore que rapportée (`Content-Security-Policy-Report-Only`) : lire les rapports `[csp-report]` de staging et de prod, puis passer `CSP_MODE=enforce` (procédure dans [`OPERATIONS.md`](OPERATIONS.md#content-security-policy)). Avant de basculer, vérifier dans un vrai navigateur sur staging, console ouverte et rapports lus : la carte (chaque fond, relief, mode sombre, tracé GPX), la visionneuse PDF d'une pièce jointe, un post markdown avec images externes, la PWA (installation, service worker, inscription au web push en prod), la connexion par passkey, la connexion et la synchronisation Strava, l'éditeur Tiptap. Durcir aussi la route de rapports (budget par client et dédoublonnage, le budget global de 120 lignes/min peut être épuisé par des rapports forgés) et le cache de dix minutes des hôtes raster (un changement de fournisseur de carte sans redémarrage du frontend reste bloqué jusque-là). Restera ensuite : les réponses non HTML (scripts, worker de carte) ne portent que les quatre directives de `SEC-30`. Taille : S |
| `SEC-39` | — | Suite de `SEC-35` | Faible | Deux autres émissions de jetons par e-mail gardent le motif compter-puis-insérer que `SEC-35` a fermé pour les codes à usage unique ; même remède, en respectant l'ordre des verrous compte puis jeton |

---

## AUD — Audit d'infrastructure de février

[`plans/2026-02-14-project-audit.md`](plans/2026-02-14-project-audit.md) fait foi pour le détail et
les statuts ; cette table les suit, revérifiés dans le code et en prod le 16 octobre 2026. Quand une
ligne est corrigée : ✅ dans l'audit, ligne déplacée dans `LEDGER_DONE.md` sous son identifiant. La
colonne « Audit » garde l'identifiant de l'audit (section « Problèmes » ; `P…` = plan d'action).
Deux gestes d'exploitation de l'audit sont sous `OPS` : I13 (`OPS-7`) et I20 (`OPS-8`). I3 (pas de
déploiement automatique, `AUD-1`) et K10 (routes Karoo non paginées, `AUD-33`) sont
dans « Délibérément dehors ».

| ID | Thème | Audit | Gravité | Constat |
|---|---|---|---|---|
| `AUD-6` | Docker | I10 | Important | `forwardedHeaders.insecure=true` sur Traefik (atténué par les règles `DOCKER-USER` qui ne laissent que Caddy le joindre : sous Swarm il écoute sur toutes les interfaces, voir [`OPERATIONS.md`](OPERATIONS.md#only-caddy-may-reach-traefik)) — voir V3, `SEC-16` |
| `AUD-30` | Docker | I14 | Mineur | Aucune limite **CPU** dans les compose (la mémoire est bornée : `AUD-7`). À poser une fois les charges mesurées : une limite trop basse sur le backend rallonge le démarrage (Flyway, Magika) au-delà du `start_period`, et le JVM dimensionne ses threads de GC sur elle |
| `AUD-8` | Docker | I15 | Important | VCL Varnish réduite à un `backend default` : ni purge, ni grace, ni ban |
| `AUD-9` | Docker | I17 | Important | imgproxy sans signature d'URL (ni `IMGPROXY_KEY` ni `IMGPROXY_SALT`) — même brique que les URLs signées (`API-24`) |
| `AUD-10` | Docker | I19 | Important | Aucune procédure de rotation des secrets dans `OPERATIONS.md` (clés JWT, `ENCRYPTION_KEY`, mots de passe postgres et MinIO, SMTP, compte de service FCM, clé age). La rotation d'`ENCRYPTION_KEY` doit **rechiffrer** les jetons des services GPS, que la synchronisation automatique (`API-120`) utilise en continu : une clé changée sans rechiffrement les rend illisibles |
| `AUD-15` | Backend | B9, B11 | Important | `FetchType.EAGER` sur neuf `@ManyToOne` (`Ride`, `RideGroup`, `Trip`, `TripStage`, `UserTeam`) |
| `AUD-20` | Mobile | M11 | Important | Lints Flutter par défaut seulement (`analysis_options.yaml`) |
| `AUD-21` | Mobile | M13 | Mineur | Pas de hors-ligne — voir `API-22` à `API-25` |
| `AUD-22` | Karoo | K1 | Critique | `MainActivity.kt` monolithique : 1 986 lignes en octobre 2026 (1 625 au constat de février), et il grossit à chaque fonctionnalité appareil |
| `AUD-23` | Karoo | K2, K3 | Critique | Aucun test ; aucun `ViewModel` alors que la dépendance est déclarée |
| `AUD-24` | Karoo | K7, K9 | Important | Refresh du jeton en trois endroits ; pas de `slow_down` (RFC 8628 — le backend n'en émet aucun à ce jour, voir `AUD-27`). K13 est livré sous `AUD-32` ; K10 est écarté sous `AUD-33` |
| `AUD-25` | Garmin | G1 | Critique | `BASE_URL` de production en dur (`ApiClient.mc`) : bloque le multi-tenant |
| `AUD-26` | Garmin | G4, G5, G7, G10 | Important | `loadResource()` dans `onUpdate()` ; AM/PM en dur ; état comparé à une chaîne localisée ; `_tokenCallback` partagé entre refresh et polling |
| `AUD-27` | Garmin | G8, G9 | Important | Pas de `slow_down` (le backend n'en émet aucun à ce jour — relevé le 30 septembre 2026 : `grep slow_down backend/` ne trouve rien ; `SEC-4` a limité `/complete` et `/verify`, pas `/token`, dont le `device_code` de 256 bits n'a rien à deviner : le point ne mordra que si `/token` est un jour freiné) ; offsets fixes dans les layouts. G6 est livré sous `AUD-31` |
| `AUD-29` | Appareils | §9.2 | — | Le polling du device flow s'arrête à la **première erreur réseau** : toute erreur qui n'est ni « en attente » ni « expiré » le coupe, sur Karoo (`auth/AuthActivity.kt`, `pollForToken`, l.426) comme sur Garmin (`PedalonsApp.onPollResponse`, l.164). Un flow interrompu ne reprend pas : Karoo ne garde rien, Garmin enregistre le `device_code` (`AuthManager.saveDeviceCode`) mais `getDeviceCode()` n'a aucun appelant. À faire : relancer le polling après une erreur passagère, implémenter la reprise ou retirer le stockage ; comportement sur appareil à valider à la main |

Suivis ailleurs : les lignes de sécurité S2 à S12 ont été versées dans l'audit de sécurité de septembre, donc sous
`SEC` (H5 livré sous `SEC-4`, M7 = `SEC-27`, M8 = `SEC-25`, M9 = `SEC-11`, M10 = `SEC-28`, L12 et L13 livrés sous `SEC-22`, L14 sous `SEC-23` ; S8 et S12 y sont rangées comme
conformes). K12 (= S13, jetons Karoo en clair) est L10, dans `SEC-12` ; P2-44 (en-têtes CSP/HSTS) est
V4, tranché sous `SEC-16` et corrigé sous `SEC-30` ; F12 (sitemap) est livré sous `WEB-31`.

---

## LEGAL — Politique de confidentialité

Le plan des points ouverts est [archivé](plans/archive/2026-09-29-privacy-policy-open-points.md).
Toute modification de
`privacy/privacy-policy.{fr,en}.md` se fait **en parité FR/EN**, et le texte étant un asset de
l'app mobile, un changement n'y apparaît qu'avec la build suivante.

La politique réécrite pour la mesure d'audience (`LEGAL-19`) est en ligne ; ce qui reste de la mise
en service (précondition du §5.3 du plan, vérifications de l'étape 6) est sous `OPS-41`.

- [ ] `LEGAL-22` **Renvois « depuis votre profil » rendus précis (XS)** — quatre
      phrases renvoient au profil sans dire où, alors que le profil a depuis octobre un sous-écran
      par sujet (`contracts/routes.yaml`, mêmes libellés sur le site et dans l'app) : CGU l.64
      (débloquer → **Profil → Confidentialité → Utilisateurs bloqués**) et l.83 (supprimer son
      compte → **Profil → Mon compte → Zone de danger**), politique l.20 (contact au sujet des
      annonces → **Profil → Confidentialité**) et l.170 (« Déconnecter tous les appareils » →
      **Profil → Connexion et sécurité**). `privacy/terms-of-service.{fr,en}.md` et
      `privacy/privacy-policy.{fr,en}.md`, en parité FR/EN, comme le fait déjà `support.{fr,en}.md`.

---

## BILL — Monétisation

Le plan est [`plans/2026-10-17-monetisation.md`](plans/2026-10-17-monetisation.md) : qui paie
(l'équipe, jamais le membre), trois paliers (Peloton gratuit ≤ 25 membres, Club 80 €/an HT,
Fédération sur devis), **abonnement annuel seul, facturé et encaissé par Qonto** (facture émise
par l'API, payée par virement, carte plus tard), un moteur d'abonnement écrit chez nous
(renouvellement, relances, grâce), et une seule fonction `TeamEntitlements` qui combine
l'abonnement avec les drapeaux de gouvernance existants (`enableRoutePlanner`,
`addMemberAllowed`…). **Rien n'est décidé** : les quatorze questions du §11 sont au propriétaire,
et le préfixe `BILL` lui-même (Q12) se tranche avant le premier commit de code.

- [ ] `BILL-1` **Décider, vérifier, puis poser le socle (M)** — trancher le §11 du plan (objectif,
      prix, seuil du gratuit, date de bascule et première période, échéance commune ou non,
      équipes offertes, droits avant paiement, carte, devis, majeure ou mineure, préfixe, TVA et
      mentions avec l'expert-comptable, rétractation) ; vérifier dans le bac à sable Qonto ce que
      le §9 laisse ouvert (clé d'API suffisante pour les factures et les webhooks, rapprochement
      automatique des virements, avoirs) ; puis le lot 1 du §10 : `V72` (`team_subscriptions`,
      `billing_invoices`, `billing_events`), `TeamSubscription`, `TeamEntitlements` et son
      résolveur, `plan` / `entitlements` / `memberLimit` dans `TeamDetailDto` (`11.6.0`),
      `AdminTeamDto` et `PATCH /api/admin/teams/{id}/subscription`, `BILLING_ENABLED=false`, et la
      migration de lancement qui pose « Club offert jusqu'au 31 mars 2027 » sur toute équipe
      existante — **aucun refus actif à ce stade**. Les lots suivants (`BILL-2` à `BILL-9`, §10 du
      plan) ne sont créés ici qu'une fois `BILL-1` tranché. Prérequis avant le premier euro
      encaissé : Open-Meteo en plan payant (`OPS-29`), conditions VersaTiles relues (§8 du plan ;
      le géocodage est chez Stadia Maps depuis `OPS-49`, un plan payant déjà, plus rien à relire
      côté Nominatim), et aucun environnement hors prod capable d'émettre une facture.

---

## Délibérément dehors

À relire avant de rouvrir l'un de ces points : chacun a été écarté avec un motif, et plusieurs
sont des invariants que le code garde. Chacun garde l'identifiant de son domaine : rouvert, il
redevient une entrée de sa section sous le même identifiant.

| ID | Sujet | Décision | Ce que ça implique |
|---|---|---|---|
| `API-29` | **Liste d'attente (`waitlisted`)** | N'existe pas en base ; ni colonne, ni statut, ni rang sur `RideParticipation` | « Complet » est un **état terminal**. Ne pas câbler un `waitlisted: false` en dur : un champ toujours faux rend la vraie fonctionnalité indétectable en revue |
| `API-30` | **Repli sur `createdBy` pour le meneur** | **Interdit partout** — base, DTO, client | `createdBy` vaut le créateur de la **sortie**, donc le même nom sur tous ses groupes : un repli serait faux presque partout, et faux de la façon qui ne se signale pas. C'est le défaut que `leader_id` corrige. Gardé par `groupLeader_isNotTheRideCreator` |
| `API-31` | **Position exacte d'une annonce** | Floutée à ~1 km, **et la sonde de proximité quantifiée sur la même grille** | Flouter la sortie ne suffit pas : répéter « cette annonce est-elle à moins de R de C ? » en déplaçant C multilatère la position réelle. D'où le rayon arrondi au multiple de cellule (3 km servis comme 3,33 km) : l'interface annonce un **ordre de grandeur**, pas une valeur exacte. Et **jamais de punaise**. La quantification seule ne suffisait pas (audit M2) : depuis `SEC-8`, le filtre mesure aussi depuis la position **floutée** de l'annonce, jamais l'exacte |
| `API-32` | **Champ de contact libre sur une annonce** | Écarté au profit du relais e-mail | C'était la solution la moins chère, et elle publie une donnée personnelle **irrévocablement** à toute l'équipe (jusqu'à 1 999 personnes) : ce qui a été lu ne se dépublie pas. Retirer le champ plus tard ne répare rien |
| `API-33` | **`GET /api/rides` et listes mono-type** | Non créées ; `/api/publications?type=RIDE` est la surface canonique | Deux surfaces = deux jeux de filtres à garder cohérents. `RideListResponse` / `TripListResponse` existent encore comme records retournés par **aucun endpoint** (schémas orphelins du contrat, que rien ne référence) : ils auraient pu partir avec l'une des MAJOR 9.0.0 à 11.0.0. À supprimer avec la prochaine MAJOR, pas pour eux seuls |
| `API-34` | **`acceptTerms` obligatoire à l'inscription (contrat `4.1.0`)** | Laissé en mineure | Historique : la rupture n'a touché que les builds mobiles d'avant 4.1.0, qui ne circulent plus (le mobile est republié avec le contrat, choix d'`API-42`) |
| `API-93` | **Statistiques de voyage stockées en base** (BACKLOG « Trip stats (save in DB) ») | Non (décidé le 9 octobre 2026 avec le propriétaire) | `TripDto.totalDistance` et `totalElevationGain` (contrat `1.3.0`) sont calculés à la lecture, une requête par page (`TripSummaryRepository.loadStageAggregates`), et suffisent aux écrans web et mobile. Une colonne dénormalisée devrait suivre chaque modification d'étape ou de parcours, comme la fin stockée (`API-85`, `API-87`). À rouvrir sur une mesure réelle de coût |
| `API-89` | **Fin stockée pendant le déploiement à chaud** | Acceptée le 6 octobre 2026 (`API-85`) | Pendant la minute où l'ancien et le nouveau backend partagent la base, une sortie ou un voyage **modifié** par l'ancien garde sa fin précédente, non nulle, que le remplissage au démarrage (`PublicationEndBackfill`, lignes vides seulement) ne corrige pas ; seules les lignes **créées** par l'ancien profitent du repli départ + 3 h. Fenêtre d'une minute, corrigée au prochain enregistrement. À rouvrir si un déploiement long ou un retour arrière le rendait visible |
| `API-54` | **exiftool pour retirer les métadonnées des images** | Écarté le 29 septembre 2026, après mesure sur un corpus synthétique (métadonnées marquées, pixels comparés) | exiftool (micro-service ou WASM) retire ce qu'il connaît au lieu de ne garder que ce qui est autorisé : il a laissé passer un chunk PNG privé et les octets après le trailer GIF, et refusé un WebP valide. Il ne nettoie pas les PDF, il a des CVE répétées (dont CVE-2026-7580, qui touche la 13.50) et il ajoute un conteneur. En WASM (zeroperl sur Chicory), sa sortie est identique mais il prend 17 à 19 s par image. imgproxy, écarté le même jour parce qu'il n'a pas de mode sans perte, a finalement été retenu : la perte d'un réencodage a été acceptée pour un code plus simple, qui ne laisse rien passer par construction et lit aussi HEIC, AVIF, TIFF et JPEG XL (`API-43`) |
| `API-52` | **Durcir `ImageMetadataStripper`** | Sans objet depuis le 29 septembre 2026 | Le nettoyeur maison sans perte a été supprimé : le stockage fait réencoder chaque image par imgproxy (`API-43`), qui n'écrit que les pixels. Ne pas le réintroduire pour gagner la qualité perdue : c'est lui dont les branches gardaient par défaut ce qu'elles ne connaissaient pas |
| `API-67` | **« Mes équipes » d'un admin de plateforme** | Comportement actuel gardé (décidé le 4 octobre 2026 avec le propriétaire) | `GET /api/teams?minRole=MEMBER` renvoie à un admin de plateforme toutes les équipes du domaine, qu'il voit donc toutes dans « Mes équipes » à l'accueil (web et mobile, `WEB-42`, `MOB-42`). Ne pas restreindre la requête à ses adhésions réelles sans rouvrir ce point |
| `WEB-44` | **Passkey en tête du formulaire de connexion** | Ordre actuel gardé (décidé le 4 octobre 2026 avec le propriétaire) | `LoginForm` (`WEB-42`) garde email et mot de passe en tête, puis « ou », puis la passkey et le code par e-mail. Le bouton passkey n'apparaît qu'après hydratation (`browserSupportsWebAuthn`) : en tête, il décalerait le haut de l'accueil rendu côté serveur |
| `WEB-54` | **Calendrier rendu côté serveur dans le mauvais fuseau, sans préférence `timezone`** | Accepté tel quel (décidé le 4 octobre 2026, à la dissolution de `frontend/docs/SSR-BUGS.md`) | Sans préférence `timezone`, le serveur ne connaît pas le fuseau du visiteur et rend en UTC : une sortie à 00 h 30, heure de Paris, s'affiche dans la case de la **veille**, puis change de case au rendu qui suit l'hydratation, avec le vrai fuseau (`useEffectiveTimezone`, `getServerSnapshot` en UTC ; `CalendarView`). Ce n'est pas une erreur d'hydratation : le rendu d'hydratation lit UTC des deux côtés, et le mois de la grille est calé sur `hourAlignedNow()` dans le même fuseau. Régler une préférence `timezone` supprime l'effet. Seule autre issue : ne pas rendre la grille côté serveur quand le fuseau est deviné, ce qui perd tout l'intérêt de son préchargement |
| `WEB-58` | **Redirection des anciennes adresses du profil** (`/profil#notifications`, `/profil#gps`, `/profil/participations`) | Non (4 octobre 2026, refonte du profil `WEB-55` / `MOB-48`) | Aucun lien extérieur publié ne cite ces adresses, et les e-mails envoyés avant la refonte visaient `/profil`, toujours servi. Les liens internes (e-mails `NotificationLinks.PREFERENCES_PATH`, `FeaturesPromoCard`, aide, politique) visent les nouvelles routes `/profil/<sujet>`. À rouvrir seulement si une de ces adresses a été publiée |
| `WEB-65` | **Tableau de bord pour un admin de plateforme non membre** | Tableau complet, décidé le 6 octobre 2026 avec le propriétaire (remplace la décision du 5 octobre, « les non-membres gardent la page publique », dépassée par l'Agenda d'équipe `API-86`, `WEB-68`, `MOB-60`) | Le fil a disparu et le tableau de bord est rendu à tout le monde, web et mobile ensemble. `TeamDashboardService.roleOf` donne `ADMIN` à un admin de plateforme : non membre, il reçoit le tableau ADMIN complet (blocs organisateur et admin), comme il voit toutes les équipes dans « Mes équipes » (`API-67`). C'est voulu : ne pas le ramener à la partie publique, ni dans `roleOf` ni dans un client |
| `API-124` | **`dominantHeadwindAzimuthDeg()` (vcyclist g31) dans `WindEstimator`** | Écarté de la migration gpx2web → vcyclist (renuméroté le 16 octobre 2026 : il portait par erreur `API-102`, déjà pris) | Rendrait un azimut compas directement exploitable et supprimerait `findDirectionFromVector` (le repli `-v.getY()` du repère Mercator, voir §4 de [`plans/2026-07-28-migration-vcyclist.md`](plans/2026-07-28-migration-vcyclist.md)) — mais c'est un changement de comportement, pas une migration à iso-fonctionnalité. La méthode existe toujours en vcyclist 6.9.1 |
| `API-113` | **Import d'un GPX par URL dans les outils GPX** (repris de biketeam) | Non (décidé le 15 octobre 2026 avec le propriétaire, à la reprise des outils GPX de biketeam) | Choix produit : seuls la fusion (`API-112`), la carte sans tracé (`WEB-89`) et le partage d'un aperçu (`WEB-88`) sont repris. Et un serveur qui télécharge l'URL qu'un membre lui donne est une surface SSRF (réseau interne de la stack, métadonnées d'hébergeur, redirections) à borner hôte par hôte. Le membre télécharge le fichier puis le dépose. À rouvrir seulement avec une liste d'hôtes autorisés et un client HTTP sans redirection vers une adresse privée |
| `API-114` | **Import depuis OpenRunner ou VisuGPX** (repris de biketeam) | Non (décidé le 15 octobre 2026 avec le propriétaire, avec `API-113`) | Même choix produit, et c'est un import par URL vers des hôtes tiers (même risque SSRF, plus un format de page ou d'API non contractuel qui casse sans prévenir). L'export GPX de ces services suivi d'un dépôt suffit |
| `WEB-8` | **Scroll infini côté web** | Non porté | Incompatible avec la règle structurante du frontend (filtres et pagination dans la query string, donc toute vue partageable). `usePaginatedQuery` précharge déjà la page suivante **et** la précédente |
| `WEB-9` | **Gabarits tactiles portés au web** | Non portés | Feuilles à crans, barre d'onglets basse, app bar interpolée, chips en remplacement des `Select` : ils résolvent une contrainte que le desktop n'a pas, et produiraient des composants hors Mantine |
| `WEB-10` | **Minimum de 44 px sur les boutons web** | Règle **tactile** uniquement | Le web descend à 36 px au-dessus de 768 px. Ne pas prendre `pedalons.css` pour une spécification web |
| `WEB-11` | **Jetons `--pdl-*` au web** | Non introduits | Le site a déjà la charte en thème Mantine ; une seconde couche de variables créerait deux sources de vérité |
| `WEB-12` | **Mode sombre dérivé au web** | Sans objet | Le tableau de parité est un livrable **pour Flutter**, parce qu'aucune maquette ne fournit le sombre. Mantine l'a déjà |
| `MOB-22` | **Jeu d'icônes Tabler côté mobile** | Material outline conservé | L'écart ne porte que sur la graisse du trait des icônes de badge de 11 px. `PdlIcons` (`lib/core/theme/pdl_icons.dart`) devrait être le **seul** fichier à nommer `Icons.*` (17 autres fichiers le font encore au 16 octobre 2026) : une fois ce ménage fait, basculer ne touchera qu'un fichier |
| `MOB-23` | **Écran de profil public d'un membre** | Aucune maquette ne va au-delà de la liste | Une ligne du trombinoscope ouvre le menu signaler/bloquer (`team_members_page.dart`), jamais un profil. Ne pas inventer l'écran |
| `MOB-24` | **Édition et création de contenu au mobile** | Hors brief : la v2 est une version de consultation et de participation | Le sélecteur de meneur dans l'éditeur de groupes existe **côté web** (livré hors plan) ; l'équivalent mobile n'est pas ouvert |
| `MOB-50` | **Cloche des notifications dans l'en-tête du Profil** | Non (décidé le 4 octobre 2026 avec le propriétaire, refonte `MOB-48`) | La boîte de réception est dans une autre branche du shell : un `push` depuis le Profil empilerait les branches, un `go` y ferait perdre la place. Elle reste à un onglet ; les réglages de notifications sont dans `/profil/notifications`. Ne pas ajouter de cloche au Profil |
| `MOB-61` | **Recherche et tags des anciennes adresses du fil dans l'app** (`team?tab=publications&type=…&q=…&tags=…`) | Non (décidé le 11 octobre 2026 avec le propriétaire) | Aucune de ces anciennes adresses n'a été partagée : l'app garde le type et la période (`resolveTeamRootSection`, `agendaTarget` dans `team_sections.dart`) et ignore `q` et `tags`, que seul le site reporte (`teamLegacyRedirects.ts`). À rouvrir seulement si une telle adresse circule |
| `MOB-74` | **Exclure du manifeste Android les pages du site sans écran dans l'app** (`<uri-relative-filter-group android:allow="false">`, API 35+) | Non (11 octobre 2026 ; part écartée de `MOB-59`, renumérotée le 16 octobre 2026) | L'app reçoit ces liens et les passe au navigateur (`isSitePageLocation` dans `openDeepLink`) : il ne reste qu'un bref passage par l'app. L'exclusion ne vaudrait que sous Android 15+, ne se vérifie que sur un appareil avec la vérification des App Links, et un manifeste faux casse tous les liens d'app. À rouvrir si le passage par l'app gêne |
| `OPS-18` | **Rotation des secrets exposés par les sauvegardes en clair** (`ENCRYPTION_KEY`, clé JWT, compte de service FCM) | Non (décidé le 29 septembre 2026, avec `OPS-13`) | Les 30 copies antérieures à `OPS-13` les contenaient en clair sur l'hôte de sauvegarde. Rotation jugée disproportionnée : ces copies sont supprimées et le SSD trimé. Reste un résidu physique possible sur le SSD de l'hôte ; à rouvrir si le matériel est perdu ou volé |
| `NOTIF-5` | **Badge iOS du push** | Écarté, côté serveur comme côté app | Serveur : il faudrait recompter les non-lues à l'envoi, et `NotificationMessage` ne porte ni le domaine ni ce compteur. App : `flutter_local_notifications` ne pose un badge qu'en affichant une notification, et en arrière-plan c'est le système qui affiche celle de FCM — une dépendance de plus pour un compteur que la cloche montre déjà. D'où l'absence de `content-available` (voir `NOTIF-9`) |
| `NOTIF-6` | **Isolat de fond du push (`onBackgroundMessage`)** | Non écrit | Le serveur envoie `notification` **et** `data` : le système affiche la bannière sans l'app, un isolat n'aurait rien à faire de plus |
| `NOTIF-7` | **Temps réel des notifications (SSE)** | Non fait : sondage de `unread-count` | Un flux SSE « si le besoin se confirme » ([plan](plans/archive/2026-09-18-notifications.md) §9) ; la cloche sonde au plus une fois par minute |
| `NOTIF-8` | **Tests Vitest de la cloche et de la page Notifications** | Écartés le 29 septembre 2026 | La recette navigateur les a validées ; le mobile a son test de widget (`notifications_page_test.dart`) |
| `MOD-5` | **Contenu masqué d'un compte effacé** | Reste masqué | L'effacement supprime les signalements visant le membre, mais ne touche pas `moderationHiddenAt` sur ses sorties, parcours, posts et voyages. Ce contenu, masqué par 3 signalements, n'a plus d'entrée dans la file et reste invisible pour les membres. C'est voulu : le démasquer republierait un contenu signalé 3 fois |
| `LEGAL-14` | **Notification des changements de politique dans l'app** | Non : l'e-mail seul, comme le dit le §11 (décidé le 29 septembre 2026, scindé de `LEGAL-13`) | Aucun type de notification « politique mise à jour ». Un changement important se signale par e-mail à chaque membre ; ne pas ajouter de promesse au §11 sans créer le type d'abord |
| `LEGAL-16` | **Journal des accès des admins plateforme** | Non (décidé le 29 septembre 2026, avec `LEGAL-13`) | Il n'y a qu'un admin plateforme, le responsable du traitement lui-même : un journal ne surveillerait que lui. Le §4 dit qui a accès et pourquoi, sans promettre de traçabilité. À rouvrir dès qu'un second compte reçoit `PLATFORM_ADMIN` : écrire le journal (intercepteur sur `@Admin`) **avant** d'en parler au §4 |
| `LEGAL-17` | **Responsable du traitement par domaine** | Non : un seul responsable pour tous les sites (décidé le 29 septembre 2026, avec `LEGAL-13`) | Le §12 le dit, et que les clubs ne sont pas responsables du traitement. Un club qui voudrait l'être demanderait des champs sur `Domain`, une page légale générée par domaine et un accord de sous-traitance : à rouvrir si un club le demande, pas avant |
| `OPS-37` | **Plausible CE pour la mesure d'audience** | Écarté le 15 octobre 2026 au profit de GoatCounter ([`2026-10-15-web-analytics.md`](plans/2026-10-15-web-analytics.md)) | Plausible CE demande ClickHouse : une seconde base à sauvegarder, surveiller et mettre à jour, plus gourmande en mémoire que le reste de la pile, pour quelques milliers de visites par mois. À rouvrir si l'audience change d'ordre de grandeur |
| `OPS-38` | **Matomo pour la mesure d'audience** | Écarté le 15 octobre 2026 au profit de GoatCounter | PHP et MySQL, absents de la pile ; cookies par défaut, à désactiver pour l'exemption CNIL ; des greffons à suivre. Sa présence sur la liste CNIL des outils exemptables n'apporte rien ici : la configuration exemptée de GoatCounter remplit les mêmes conditions |
| `OPS-39` | **Mesure d'audience par les journaux d'accès** (GoAccess, `goatcounter import` des journaux Caddy) | Écartée le 15 octobre 2026 | Les journaux vivent sur l'hôte, hors dépôt ; ils ne voient que le premier chargement d'une page, pas les navigations côté client du routeur ; ils portent les chemins concrets (`/outils-gpx/{previewId}`, les slugs des sorties, parcours et pages), qu'il faudrait réécrire après coup au lieu de ne jamais les envoyer |
| `LEGAL-20` | **Mesure d'audience par un service SaaS** (Plausible, Fathom…) | Écartée le 15 octobre 2026 | Un sous-traitant de plus au §4 de la politique, souvent un transfert hors UE au §5, un domaine tiers que les bloqueurs coupent, un contrat à suivre. L'auto-hébergement chez Scaleway reste couvert par le sous-traitant déjà déclaré |
| `OPS-40` | **Compter des visites plutôt que des pages vues** (un site GoatCounter par domaine et par alias, purge nocturne de `hits.session`) | Non : pages vues seulement, sessions coupées, un seul site (décidé le 15 octobre 2026, [`2026-10-15-web-analytics.md`](plans/2026-10-15-web-analytics.md) §7) | Avec un site unique, une session relierait la navigation d'un site de club à l'autre (condition 3 de la CNIL) ; un site par hôte couplerait la création d'un domaine (`AdminDomainResource`) à GoatCounter, et l'empreinte de session gardée 24 mois sur chaque page vue ferait un quasi-identifiant sur un petit club. À rouvrir si une question réelle ne se résout pas en pages vues, en écrivant d'abord la purge et la création couplée |
| `API-116` | **Couper la mesure d'audience pour un club** (drapeau par `Domain`, comme `enableGpxPlanner`) | Non, pas avant qu'un club le demande (décidé le 15 octobre 2026, plan §7) | La mesure est exemptée de consentement et chaque visiteur peut s'y opposer (DNT, GPC, interrupteur) ; un drapeau par domaine ajouterait un champ, une migration et une case d'admin sans demande. À rouvrir sur la demande d'un club : le drapeau rejoindrait `analytics` dans `/api/config` (`API-117`), résolu par domaine |
| `WEB-91` | **Statistiques d'audience pour les admins de club** | Non : tableau de bord pour le seul responsable du traitement, par tunnel SSH (décidé le 15 octobre 2026, plan §7) | La condition 1 de l'exemption CNIL limite la finalité à l'éditeur ; il n'y a qu'un site GoatCounter pour tous les hôtes, si bien qu'il faudrait soit un site par domaine, soit une page Pédalons qui lirait l'API de GoatCounter (aujourd'hui sans jeton) en filtrant par hôte et par slug ; et sur une petite équipe privée, un admin qui connaît ses membres pourrait rapprocher une page vue d'une personne. À rouvrir sur une demande réelle, après relecture de la condition 1 |
| `BRAND-3` | **Test de concordance des tables de couleurs web et mobile** | Écarté au profit du générateur (`BRAND-2`) | Un test qui parse les deux fichiers et vérifie qu'ils concordent détecte sans unifier, et repose sur des expressions régulières sur du TypeScript et du Dart |
| `AUD-1` | **Déploiement automatique (CD) depuis GitHub** (audit de février, I3, « Critique ») | Non (16 octobre 2026, relecture du ledger) : le déploiement reste lancé à la main par `scripts/deploy.sh` | Le « Critique » de février visait des images poussées à la main sans retour arrière : `AUD-2` a apporté le tag par commit et le rollback Swarm, `AUD-3` la suite e2e nocturne. Les cinq workflows (`ci.yml`, `codeql.yml`, `e2e.yml`, `karoo-release.yml`, `mobile-release.yml`) ne déploient rien, à dessein : les hôtes sont en Swarm mono-nœud sans registry, et un déploiement depuis la CI demanderait soit un runner auto-hébergé, écarté par `AUD-3` parce qu'il exécuterait le code d'une PR externe chez nous, soit une clé SSH de l'hôte dans les secrets GitHub. À rouvrir avec un registry et un second nœud, ou si les déploiements deviennent assez fréquents pour qu'un oubli coûte |
| `AUD-33` | **Pagination des routes côté Karoo** (audit de février, K10, scindé d'`AUD-24`) | Non (16 octobre 2026) : bornée côté serveur à la place | `PedalonsApiClient.getRoutes` lit une seule page, mais `DeviceRouteService` plafonne la réponse à 20 sorties, 20 routes et 20 groupes (`MAX_*_IN_RESPONSE`, commits `9f23df4d` et `007bdf3a`, `API-118`), pour tenir sous la limite de 100 Ko d'une réponse sur le Karoo — le risque que K10 nommait. À rouvrir si un écran de l'appareil doit montrer plus que ces plafonds |

---

## Les autres sources

Ce fichier ne couvre que les suites de la v2 et des chantiers qui l'ont suivie. D'autres sources
restent ouvertes :

- [`BACKLOG.md`](BACKLOG.md) — la roadmap produit (P0 → Icebox). Y figurent notamment le statut
  « Terminée » sur les sorties et voyages (livré sous `API-16`) et le système de notifications (qui
  recoupe `NOTIF`).
- [`plans/2026-02-14-project-audit.md`](plans/2026-02-14-project-audit.md) — audit d'infrastructure,
  CI/CD et qualité des modules, statuts rafraîchis le 29 septembre 2026. Ses lignes ouvertes sont
  suivies sous `AUD`.
- [`plans/archive/2026-09-security-audit.md`](plans/archive/2026-09-security-audit.md) — audit de sécurité de septembre 2026, archivé le
  9 octobre 2026 ; ses ouverts sont suivis sous `SEC`, qui fait foi. L'audit de février reste la
  référence pour l'infrastructure.
- [`plans/2026-07-28-migration-vcyclist.md`](plans/2026-07-28-migration-vcyclist.md) — remplacer
  gpx2web par vcyclist dans le backend. **Exécuté** (fusionné le 14 octobre 2026) et déployé,
  aujourd'hui contre **vcyclist 6.9.1 depuis Maven Central** : un manque côté vcyclist se corrige
  par une release amont. Contrat d'API **inchangé** par construction : les cols gardent leur forme
  JSONB actuelle via des records maison, donc ni bump de `pedalons.api.version` ni migration
  Flyway. Ce qui change pour les parcours **réimportés** : détection des cols et direction de vent,
  puis, avec les releases suivantes, les ponts, les tunnels et le D+ (`API-104`, `API-106`) ; une
  ré-importation biketeam recalcule aussi les parcours d'un ancien pipeline (`API-107`), et les
  requêtes vers l'IGN suivent un seul rythme (`API-105`). Suivi sous `OPS-31` ; plan à archiver.
- [`plans/2026-07-25-privacy-improvement-opportunities.md`](plans/2026-07-25-privacy-improvement-opportunities.md) —
  les options d'amélioration de la vie privée et leur justification ; ce qui en reste ouvert, le
  chiffrement des jetons Karoo, est suivi sous `SEC-12`. L'audit de juillet et la mise à jour de
  septembre qui ont réécrit la politique sont archivés.
