# App Links

Ce document décrit comment un lien web `https://www.pedalons.fr/...` ouvre l'app mobile au lieu du navigateur.

## Source de vérité : `contracts/routes.yaml`

Toutes les routes d'UI — leurs variantes de langue, les plateformes concernées et leur éligibilité aux deep links — sont déclarées dans `contracts/routes.yaml`. Le script `scripts/generate-routes.mjs` régénère les fichiers plateforme à partir de ce YAML.

Exécution :

```bash
cd frontend
pnpm generate-routes
```

Fichiers générés / maintenus :

| Fichier | Rôle |
|---------|------|
| `frontend/src/config/paths.generated.ts` | Builders TypeScript typés (+ `pathVariants`, `LOCALES`) |
| `mobile/lib/config/paths.generated.dart` | Classe `Paths` + `PathVariants` (Dart) |
| `frontend/public/.well-known/apple-app-site-association` | iOS Universal Links — toutes les variantes de langue — et `webcredentials` (passkeys, voir [Passkeys](#passkeys)) |
| `mobile/android/app/src/main/AndroidManifest.xml` | Section `<intent-filter>` entre les marqueurs `BEGIN/END generated-deeplinks` |

Fichiers **non** générés mais nécessaires :

| Fichier | Rôle |
|---------|------|
| `frontend/src/config/paths.ts` | Re-export de `paths.generated.ts` (point d'import stable) |
| `frontend/src/config/locale-context.ts` | Lit la locale courante via `i18next` |
| `mobile/lib/config/paths.dart` | Re-export de `paths.generated.dart` |
| `mobile/lib/config/locale_context.dart` | Variable globale de locale, synchronisée depuis `context.locale.languageCode` dans `app.dart` |
| `frontend/src/config/routes.config.ts` | Déclaration des routes web avec `pathVariants.xxx()` |
| `mobile/lib/config/router.dart` | GoRouter — enregistre toutes les variantes via `_perLocale(...)` et `_buildTeamTrees()`, et déclare les hiérarchies de deep link (`_deepLinkHierarchies`) |
| `frontend/public/.well-known/assetlinks.json` | Associe le domaine au package Android (SHA256 fingerprint) — App Links et passkeys |
| `mobile/ios/Runner/Runner.entitlements` | Domaines associés iOS (`applinks:` et `webcredentials:`) |
| `mobile/lib/main.dart` | Deep link handler (package `app_links`) |

## Ajouter ou modifier une route

### 1. Éditer `contracts/routes.yaml`

```yaml
- id: ride
  path:
    en: /teams/{teamSlug}/rides/{rideSlug}
    fr: /equipes/{teamSlug}/sorties/{rideSlug}
  params:
    - teamSlug
    - rideSlug
  web: true
  mobile: true
  deeplink: true
```

Champs :
- `id` : identifiant unique camelCase, utilisé comme nom de builder (`paths.ride`, `Paths.ride`)
- `path` : map `locale → template`. `{name}` pour les paramètres.
- `params` : liste de noms de paramètres. Chaque nom doit apparaître comme `{name}` dans toutes les locales.
- `web` / `mobile` : émettre un builder dans `paths.generated.ts` / `paths.generated.dart` (défauts : `web: true`, `mobile: false`)
- `mobileName` (optionnel) : nom de méthode Dart différent de `id` (ex. `ads` → `Paths.teamAds`)
- `appScreen` : `false` pour une page **du site** que l'app ouvre dans le navigateur de l'appareil (`openWebPage`) sans en avoir l'écran — formulaires de publication et de voyage, modèles de sortie, administration de l'équipe que propose le tableau de bord (créer et modifier une sortie sont des écrans de l'app depuis `MOB-76`) (`team_web_paths.dart`, ledger `MOB-54`). Exige `web: true` et `mobile: true`, interdit `deeplink: true`. Le builder Dart est émis comme les autres, et son nom rejoint le `webOnlyRouteIds` de `paths.generated.dart` : `link_launcher_test.dart` exige que toute entrée de `PathVariants` soit soit un motif interne (`internalRouteTemplates`), soit dans cet ensemble. Une adresse du site ouverte depuis l'app passe par là plutôt que d'être écrite à la main : un renommage côté web la suit (défaut `true`)
- `deeplink` : inclure dans AASA + AndroidManifest (défaut `false`)
- `webFallback` : pour un deeplink `web: false`, l'`id` de la route web vers laquelle un navigateur est redirigé (sans l'app, le lien universel aboutit sur le web et ne doit pas finir en 404). Ses paramètres doivent être un sous-ensemble de ceux de la route.

### 2. Régénérer

```bash
cd frontend && pnpm generate-routes
```

Le générateur :
- Émet des builders locale-aware : `paths.ride(a, b)` retourne l'URL dans la locale courante (`getCurrentLocale()`).
- Émet `pathVariants.ride(a, b)` retournant `{en: '...', fr: '...'}` pour enregistrer toutes les variantes dans les routeurs.
- Agrège et déduplique les patterns dans AASA et AndroidManifest (`*` pour iOS, `.*` pour Android).
- Place en tête de l'AASA une entrée `NOT …` pour chaque page du site **sans écran dans l'app** (`web: true`, ni `deeplink` ni écran mobile) qu'un joker de deeplink capterait : `*` traverse les `/`, et `/equipes/*` revendique toute l'équipe. Sans elles, iOS rendrait à l'app la page que `openWebPage` confie au navigateur (ledger `MOB-58`). Le générateur échoue si une exclusion couvrait le chemin d'un deeplink. La même liste est émise dans `paths.generated.dart` (`sitePagePathPatterns`) : le manifeste Android ne sait pas exclure (avant l'API 35), donc l'app reçoit ces liens et `openDeepLink` les passe au navigateur (ledger `MOB-59`) ; `openWebPage` nomme le navigateur dans `MainActivity` pour ne pas se les renvoyer.

### 3. Câbler la page dans les routeurs

**Web** — Ajouter une entrée dans `frontend/src/config/routes.config.ts` :

```ts
{
  id: 'ride-detail',
  paths: pathVariants.ride(':teamSlug', ':rideSlug'),
  component: RideDetailPage,
  auth: 'public',
  parentId: 'team-detail',
  breadcrumb: { type: 'dynamic', entity: 'ride' },
}
```

`buildRoutes()` (`RouteGenerator.tsx`) produit un `RouteObject` React Router par variante unique.

**Mobile** — Ajouter une `GoRoute` dans `mobile/lib/config/router.dart` :

- Pour une route plate : `..._perLocale(PathVariants.xxx(), (ctx, st) => MyPage())`
- Pour une route d'équipe : l'ajouter dans `_teamTree(locale)` en dérivant le segment relatif via `_underTeam(PathVariants.xxx(':teamSlug', ...), locale, teamBase)`

### 4. Vérifier

```bash
# Frontend
cd frontend && pnpm typecheck && pnpm lint && pnpm build

# Mobile
cd mobile && flutter analyze

# Android App Links
curl -s https://www.pedalons.fr/.well-known/assetlinks.json | jq .
adb shell pm get-app-links fr.pedalons.mobile
adb shell am start -a android.intent.action.VIEW \
  -d "https://www.pedalons.fr/teams/mon-equipe/rides/sortie" fr.pedalons.mobile

# iOS Universal Links
curl -s https://www.pedalons.fr/.well-known/apple-app-site-association | jq .
# Sur device : Réglages > Développeur > Universal Links > Diagnostics
```

## Multi-locale

Une URL dans n'importe quelle langue supportée (`en`, `fr`) est reconnue par l'app et par le deep linking. Les URLs **générées** par `Paths.xxx()` / `paths.xxx()` utilisent la locale courante de l'utilisateur :

- Frontend : locale de la requête en SSR, sinon `i18next.resolvedLanguage` (détecteur navigateur + préférence utilisateur), sinon `DEFAULT_LOCALE`
- Mobile : `context.locale.languageCode` propagé dans `locale_context.dart` par `PedalonsApp.build()`

Donc un user FR partage `/equipes/mon-club/sorties/balade-dimanche` ; un user EN reçoit le lien, l'OS ouvre l'app (AASA/manifest acceptent la variante FR), GoRouter/React Router la matche et affiche la bonne page.

## Deep link handler mobile

`mobile/lib/main.dart` utilise le package `app_links` :
- Au lancement : `appLinks.getInitialLink()` remplit `initialDeepLinkProvider`.
- En cours d'exécution : `appLinks.uriLinkStream` émet chaque lien reçu — **y compris le lien de
  lancement**, rejoué au démarrage.

Les deux sources convergent vers `_requestOpen()`, qui ne garde que la dernière cible et attend que
l'app soit navigable avant d'ouvrir :

1. **auth initialisée** — `app.dart` affiche son écran de chargement tant que ce n'est pas le cas,
   donc `MaterialApp.router` n'est pas monté (sans timeout : restaurer une session peut demander un
   aller-retour réseau) ;
2. **router monté** — `GoRouter.push` empile sur `routerDelegate.currentConfiguration`, vide tant
   que le `Router` n'a pas parsé sa première route. Pousser avant écrase silencieusement les
   ancêtres et laisse une pile à une seule entrée, sans retour possible.

Ensuite `ancestorsForDeepLink()` (dans `router.dart`) fournit les ancêtres à empiler sous la cible :
`go(premier ancêtre)` puis `push(...)` jusqu'à la page visée. Une page légale ouverte depuis la fiche
Play Store obtient ainsi Accueil → Confidentialité ; une sortie obtient Équipes → équipe → sortie.
Les routes qui portent déjà leur navigation (accueil, onglets du shell principal, pages d'auth) n'ont
pas d'ancêtre et sont ouvertes par un simple `go()`.

Deux règles à ne pas casser :

- **Le `GoRouter` est construit une seule fois** — `routerProvider` n'observe pas l'état d'auth, les
  changements passent par `refreshListenable`. Le recréer réinitialise la pile depuis
  `initialLocation` et efface la hiérarchie reconstruite.
- **Une chaîne d'ancêtres n'empile pas deux onglets du shell principal** — go_router les fusionne en
  un seul shell dont l'état reste sur le premier, et le mauvais onglet resterait surligné. Les
  chaînes d'équipe partent donc de l'onglet Équipes, pas de l'accueil.

Une nouvelle route deeplinkable hors shell doit déclarer sa hiérarchie dans `_deepLinkHierarchies`
(couvert par `mobile/test/deep_link_hierarchy_test.dart`).

Un lien `rideGroup` vers une sortie à zéro ou un groupe n'a pas de page propre : le web répond par
une redirection **302** vers la sortie (`dataRedirect`, query string gardé), le mobile remplace la
page du groupe par le détail de la sortie sans entrée d'historique (ledger `WEB-79`, `MOB-69`).
Jamais de 301 : un deuxième groupe ajouté plus tard refait de l'URL une vraie page.

## Passkeys

Les passkeys natives reposent sur les mêmes fichiers `.well-known` que les App Links : l'OS vérifie
que l'app a le droit d'utiliser les identifiants du domaine (le Relying Party ID, `www.pedalons.fr`,
défini par `WEBAUTHN_RP_ID` dans `mobile/lib/config/app_config.dart`).

- **iOS** — `webcredentials:www.pedalons.fr` dans `Runner.entitlements`, et un bloc `webcredentials`
  dans l'AASA, émis par `generate-routes` avec le même App ID que `applinks`.
- **Android** — la relation `delegate_permission/common.get_login_creds` dans `assetlinks.json`, à
  côté de `handle_all_urls`, avec les mêmes empreintes.

Les deux fichiers sont servis par le frontend (`frontend/server.js`, qui force `application/json`
pour l'AASA), pas par le backend.

Contraintes des deux plateformes sur ces fichiers :

- HTTPS, au chemin exact, **sans redirection**, sans authentification ;
- `Content-Type: application/json` ;
- Apple passe par son CDN, qui met en cache l'AASA **jusqu'à 24 h** : un changement n'est pas vu tout
  de suite par les appareils.

Dépannage :

- **iOS, passkeys ou domaines associés non validés** : le cache CDN d'Apple peut se contourner en
  développement avec le suffixe `?mode=developer` sur l'entrée des entitlements
  (`webcredentials:www.pedalons.fr?mode=developer`, mode développeur activé sur l'appareil) ;
  `swcutil` sur macOS aide à diagnostiquer. Tester sur un appareil réel, le simulateur a des limites.
- **Android, « credential not found »** : vérifier que `assetlinks.json` répond et que l'empreinte
  correspond à la clé qui a signé l'APK installé — un build debug est signé par la clé debug, dont
  l'empreinte doit alors figurer aussi dans `assetlinks.json` à côté de la release ; outil de vérification :
  [Asset Links Tool](https://developers.google.com/digital-asset-links/tools/generator).

## Références

- [Android App Links](https://developer.android.com/training/app-links)
- [iOS Universal Links](https://developer.apple.com/documentation/bundleresources/applinks)
- [Apple : Supporting Associated Domains](https://developer.apple.com/documentation/xcode/supporting-associated-domains)
- [Apple : Supporting Passkeys](https://developer.apple.com/documentation/authenticationservices/public-private_key_authentication/supporting_passkeys)
- [Google : Digital Asset Links](https://developers.google.com/digital-asset-links)
- [Google : Passkeys sur Android (Credential Manager)](https://developer.android.com/identity/sign-in/credential-manager)

### Empreintes de signature Android

```bash
# Debug
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android

# Release
keytool -list -v -keystore <release-keystore> -alias <alias>
```

Le SHA256 doit correspondre à ce que déclare `frontend/public/.well-known/assetlinks.json`.

Avec **Play App Signing**, Google re-signe l'app publiée avec sa propre clé : l'empreinte à déclarer
pour les installations depuis le Play Store est celle de Play Console → l'app → Configuration →
Signature de l'application (« Certificat de la clé de signature de l'application »), pas celle du
keystore d'upload.

`assetlinks.json` déclare donc **deux** empreintes : celle de Play (`18:A9:…`) et celle de l'APK hors
Play (`26:24:…`), signé sur GitHub avec la clé Karoo par `.github/workflows/mobile-release.yml`
(ledger `MOB-72`). Retirer la seconde casse les liens profonds et les passkeys de toutes les
installations par APK.
