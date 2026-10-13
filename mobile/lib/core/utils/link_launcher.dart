import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';
import '../../config/paths.dart';
import '../pdl/pdl_banner.dart';
import '../pdl/pdl_button.dart';
import '../theme/pdl_icons.dart';
import 'push_location.dart';

/// F-TE-10 — Le routeur de liens de l'application (plan §1.3.5).
///
/// Il vit dans `core/utils` et non dans `core/pdl` : ouvrir une application
/// tierce, pousser une route et traduire un libellé sont trois choses que la
/// bibliothèque de composants s'interdit. `PdlMarkdownBody` reçoit donc un
/// simple `ValueChanged<String>`, et c'est ici qu'il pointe.
///
/// La résolution se fait en trois temps, **dans cet ordre** :
///
/// 1. une URL **du domaine courant** dont le chemin est reconnu par un motif de
///    `paths.generated.dart` → [pushLocation] : rester dans l'app, ne pas
///    partir dans le navigateur pour revenir sur la même page en moins bien ;
/// 2. sinon `launchUrl(mode: externalApplication)` — `http`, `https`, mais
///    aussi `mailto:`, `tel:` et `webcal:`, les schémas déclarés dans
///    `Info.plist` et dans le bloc `<queries>` Android par F-TE-1 ;
/// 3. schéma inconnu, URL illisible ou lancement refusé → un [PdlBanner] `warn`
///    qui **montre l'URL en clair** et propose de la copier.
///
/// **Jamais d'échec silencieux.** Un lien qui ne mène nulle part le dit ; le
/// défaut d'origine (`LinkConfig` sans `onTap`) était précisément un lien
/// stylé qui ne faisait rien, et cassait toutes les inscriptions annoncées
/// dans les publications.

/// Ce qu'un tap sur un lien a produit. Retourné pour que l'appelant — un test,
/// une trace — puisse le constater ; aucun écran n'a besoin de le lire.
enum LinkOutcome {
  /// Poussé sur le `GoRouter` sans quitter l'application.
  internal,

  /// Confié au système (navigateur, client mail, téléphone, calendrier).
  external,

  /// Ni l'un ni l'autre : le bandeau a été affiché.
  refused,
}

/// Marque de position d'un segment variable dans un motif de route.
///
/// Un caractère de contrôle, donc absent de tout slug réel, et qui survit à
/// `RegExp.escape` puisqu'on découpe *avant* d'échapper.
const String _slot = '\u0001';

/// Tous les motifs de route de l'app, un identifiant par entrée de
/// `PathVariants`, toutes locales confondues.
///
/// Dérivé de `paths.generated.dart` plutôt que recopié : un chemin ajouté au
/// contrat `contracts/routes.yaml` n'a qu'une ligne à ajouter ici, et
/// `link_launcher_test.dart` échoue tant qu'elle manque.
@visibleForTesting
final Map<String, List<String>> internalRouteTemplates = <String, List<String>>{
  'home': PathVariants.home().values.toList(),
  'login': PathVariants.login().values.toList(),
  'register': PathVariants.register().values.toList(),
  'verifyEmail': PathVariants.verifyEmail().values.toList(),
  'forgotPassword': PathVariants.forgotPassword().values.toList(),
  'resetPassword': PathVariants.resetPassword().values.toList(),
  'deviceVerifyGarmin': PathVariants.deviceVerifyGarmin().values.toList(),
  'deviceVerifyKaroo': PathVariants.deviceVerifyKaroo().values.toList(),
  'deviceHammerhead': PathVariants.deviceHammerhead().values.toList(),
  'apps': PathVariants.apps().values.toList(),
  'privacy': PathVariants.privacy().values.toList(),
  'terms': PathVariants.terms().values.toList(),
  'profile': PathVariants.profile().values.toList(),
  'myParticipations': PathVariants.myParticipations().values.toList(),
  'profilePreferences': PathVariants.profilePreferences().values.toList(),
  'profileNotifications': PathVariants.profileNotifications().values.toList(),
  'profileDevices': PathVariants.profileDevices().values.toList(),
  'profileSecurity': PathVariants.profileSecurity().values.toList(),
  'profilePrivacy': PathVariants.profilePrivacy().values.toList(),
  'blockedUsers': PathVariants.blockedUsers().values.toList(),
  'profileAccount': PathVariants.profileAccount().values.toList(),
  'profileHelp': PathVariants.profileHelp().values.toList(),
  'notifications': PathVariants.notifications().values.toList(),
  'calendar': PathVariants.calendar().values.toList(),
  'allRoutes': PathVariants.allRoutes().values.toList(),
  'allRoutesMap': PathVariants.allRoutesMap().values.toList(),
  'teams': PathVariants.teams().values.toList(),
  'teamsDiscover': PathVariants.teamsDiscover().values.toList(),
  'team': PathVariants.team(_slot).values.toList(),
  'teamAbout': PathVariants.teamAbout(_slot).values.toList(),
  'teamCalendar': PathVariants.teamCalendar(_slot).values.toList(),
  'teamMembers': PathVariants.teamMembers(_slot).values.toList(),
  'teamAgenda': PathVariants.teamAgenda(_slot).values.toList(),
  'teamPosts': PathVariants.teamPosts(_slot).values.toList(),
  'teamRides': PathVariants.teamRides(_slot).values.toList(),
  'teamTrips': PathVariants.teamTrips(_slot).values.toList(),
  'teamPage': PathVariants.teamPage(_slot, _slot).values.toList(),
  'ride': PathVariants.ride(_slot, _slot).values.toList(),
  'rideGroup': PathVariants.rideGroup(_slot, _slot, _slot).values.toList(),
  'trip': PathVariants.trip(_slot, _slot).values.toList(),
  'stage': PathVariants.stage(_slot, _slot, _slot).values.toList(),
  'post': PathVariants.post(_slot, _slot).values.toList(),
  'routes': PathVariants.routes(_slot).values.toList(),
  'route': PathVariants.route(_slot, _slot).values.toList(),
  'teamAds': PathVariants.teamAds(_slot).values.toList(),
  'ad': PathVariants.ad(_slot, _slot).values.toList(),
};

// Les entrées de `PathVariants` qui n'ont **pas** d'écran dans l'app sont
// absentes de la table ci-dessus : `webOnlyRouteIds`, généré depuis les routes
// `appScreen: false` de `contracts/routes.yaml`. Des pages du site seulement,
// dont le chemin n'existe côté Dart que pour les ouvrir dans le navigateur
// (`openWebPage`) — un lien vers l'une d'elles part donc dehors, et c'est
// voulu : la pousser sur le routeur mènerait à une route inconnue.

/// Les motifs compilés. `final` de haut niveau : construits à la première
/// résolution de lien, jamais à chaque tap.
final List<RegExp> _routePatterns = <RegExp>[
  for (final List<String> templates in internalRouteTemplates.values)
    for (final String template in templates) _templateToRegExp(template),
];

/// `/teams/<slot>/rides/<slot>` → `^/teams/[^/]+/rides/[^/]+/?$`.
///
/// On découpe sur la marque **puis** on échappe chaque littéral : la marque ne
/// traverse jamais `RegExp.escape`, dont le résultat n'est pas spécifié.
RegExp _templateToRegExp(String template) =>
    RegExp('^${template.split(_slot).map(RegExp.escape).join('[^/]+')}/?\$');

/// Le nom d'hôte, débarrassé de son `www.`, pour comparer deux domaines qui ne
/// diffèrent que par lui.
String _bareHost(String host) {
  final String h = host.toLowerCase();
  return h.startsWith('www.') ? h.substring(4) : h;
}

/// `true` si [host] est le domaine servi par cette installation.
///
/// Un hôte vide est un lien **relatif** (`/equipes/x/sorties/y`) : par
/// définition le domaine courant.
bool _isCurrentHost(String host) {
  if (host.isEmpty) return true;
  final String h = _bareHost(host);
  return h == _bareHost(AppConfig.deepLinkHost) ||
      h == _bareHost(Uri.parse(AppConfig.apiBaseUrl).host);
}

/// L'emplacement `GoRouter` correspondant à [href], ou `null` si ce lien n'est
/// pas une route interne de cette application.
///
/// Pur, sans contexte : c'est lui que les tests interrogent en masse.
String? internalLocationFor(String href) {
  final String trimmed = href.trim();
  // Une ancre seule (`#section`) n'est pas une route : sans ce garde-fou elle
  // se résoudrait en `/` et renverrait l'utilisateur à l'accueil.
  if (trimmed.isEmpty || trimmed.startsWith('#')) return null;

  final Uri? uri = Uri.tryParse(trimmed);
  if (uri == null) return null;
  if (uri.hasScheme && uri.scheme != 'http' && uri.scheme != 'https') {
    return null;
  }
  if (!_isCurrentHost(uri.host)) return null;

  final String path = uri.path.isEmpty ? '/' : uri.path;
  // Avant les motifs de l'app : `/equipes/x/sorties/nouvelle` est aussi la
  // sortie de slug `nouvelle`, et c'est la page du site qui est visée.
  if (isSitePageLocation(path)) return null;
  if (!_routePatterns.any((RegExp pattern) => pattern.hasMatch(path))) {
    return null;
  }

  final StringBuffer location = StringBuffer(path);
  if (uri.hasQuery && uri.query.isNotEmpty) location.write('?${uri.query}');
  if (uri.fragment.isNotEmpty) location.write('#${uri.fragment}');
  return location.toString();
}

final List<RegExp> _sitePagePatterns = <RegExp>[
  for (final String source in sitePagePathPatterns) RegExp(source),
];

/// `true` si [location] est une page **du site** que l'app n'a pas mais que
/// ses liens d'app revendiquent quand même : le manifeste Android ne sait pas
/// l'exclure de `/equipes/.*` (docs/LEDGER_*.md MOB-59). Le système la confie
/// alors à l'app, qui doit la passer au navigateur ([openWebPage]) plutôt que
/// d'afficher « page introuvable ».
bool isSitePageLocation(String location) {
  final String path = Uri.tryParse(location)?.path ?? location;
  return _sitePagePatterns.any((RegExp pattern) => pattern.hasMatch(path));
}

/// Le lanceur système, substituable en test.
///
/// Un test ne peut pas ouvrir Safari ; il peut en revanche vérifier **quelle**
/// URL a été confiée au système, et simuler un refus.
typedef LinkOpener = Future<bool> Function(Uri url);

@visibleForTesting
LinkOpener? debugLinkOpener;

Future<bool> _launchExternally(Uri url) =>
    launchUrl(url, mode: LaunchMode.externalApplication);

/// Ouvre [href] selon les trois temps décrits en tête de fichier.
Future<LinkOutcome> openLink(BuildContext context, String href) async {
  final String trimmed = href.trim();

  final String? location = internalLocationFor(trimmed);
  if (location != null) {
    // Pas `context.push` : depuis une publication (plein écran), pousser une
    // section d'équipe laissait une page vide (docs/LEDGER_*.md MOB-46).
    pushLocation(context, location);
    return LinkOutcome.internal;
  }

  final Uri? uri = trimmed.isEmpty ? null : Uri.tryParse(trimmed);
  if (uri == null) {
    showUnopenableLinkBanner(context, href);
    return LinkOutcome.refused;
  }

  // Une page du site que revendiquent les liens d'app : confiée telle quelle
  // au système, elle reviendrait dans l'app (docs/LEDGER_*.md MOB-59).
  if ((uri.scheme == 'http' || uri.scheme == 'https' || !uri.hasScheme) &&
      _isCurrentHost(uri.host) &&
      isSitePageLocation(uri.path)) {
    final String location = uri.hasQuery
        ? '${uri.path}?${uri.query}'
        : uri.path;
    if (await openWebPage(location)) return LinkOutcome.external;
    if (context.mounted) showUnopenableLinkBanner(context, href);
    return LinkOutcome.refused;
  }

  bool opened = false;
  try {
    opened = await (debugLinkOpener ?? _launchExternally)(uri);
  } on Object catch (error, stack) {
    // Un schéma non déclaré lève plutôt qu'il ne renvoie `false` : les deux
    // aboutissent au même bandeau, mais la trace nomme la cause.
    debugPrint('openLink: $uri refusé par le système (${error.runtimeType})');
    debugPrintStack(stackTrace: stack, maxFrames: 6);
  }

  if (!opened) {
    if (context.mounted) showUnopenableLinkBanner(context, href);
    return LinkOutcome.refused;
  }
  return LinkOutcome.external;
}

/// Ouvre une page **du site** que l'app ne sait pas afficher — la file de
/// signalements d'une équipe, par exemple.
///
/// Dans le **navigateur de l'appareil**, pas dans un navigateur intégré : ce
/// dernier ne partage la session ni de l'app ni du navigateur, et le membre
/// devait s'y reconnecter à chaque page (docs/LEDGER_*.md MOB-58). Le
/// navigateur garde au moins sa propre connexion d'une fois sur l'autre.
///
/// Pas par [openLink] pour autant : le domaine est celui des liens d'app, et
/// les motifs `/equipes/*` captent toute l'équipe (docs/LEDGER_*.md MOB-59) —
/// une adresse confiée au système reviendrait dans l'app, sur une route
/// qu'elle n'a pas. Sous Android, `MainActivity` nomme donc le navigateur ;
/// sous iOS, l'AASA exclut ces pages (`NOT …`, `generate-routes.mjs`).
/// `false` si le système a refusé, ce que l'appelant peut dire.
Future<bool> openWebPage(String path) async {
  final Uri url = Uri.parse(
    '${AppConfig.deepLinkScheme}://${AppConfig.deepLinkHost}$path',
  );
  try {
    return await (debugLinkOpener ?? _launchInBrowser)(url);
  } on Object catch (error) {
    debugPrint('openWebPage: $url refusé par le système ($error)');
    return false;
  }
}

const MethodChannel _browserChannel = MethodChannel(
  'fr.pedalons.mobile/browser',
);

Future<bool> _launchInBrowser(Uri url) async {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return await _browserChannel.invokeMethod<bool>('open', <String, String>{
          'url': url.toString(),
        }) ??
        false;
  }
  return launchUrl(url, mode: LaunchMode.externalApplication);
}

/// Le bandeau du troisième temps : `warn`, **l'URL en clair**, et de quoi la
/// copier pour l'ouvrir ailleurs.
///
/// Un `MaterialBanner` et non un `SnackBar` : c'est un état, pas un événement
/// de quatre secondes — et sous la barre d'onglets un snackbar est masqué
/// (règle transverse du plan §1.3.4).
void showUnopenableLinkBanner(BuildContext context, String href) {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  messenger.clearMaterialBanners();
  messenger.showMaterialBanner(
    MaterialBanner(
      padding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      dividerColor: Colors.transparent,
      content: PdlBanner(
        tone: PdlBannerTone.warn,
        title: 'links.unopenable.title'.tr(),
        message: href,
        onDismiss: messenger.hideCurrentMaterialBanner,
        dismissSemanticLabel: 'common.close'.tr(),
        action: PdlButton(
          label: 'links.copy'.tr(),
          variant: PdlButtonVariant.text,
          size: PdlButtonSize.sm,
          icon: PdlIcons.copy,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: href));
            messenger.hideCurrentMaterialBanner();
          },
        ),
      ),
      // `MaterialBanner` exige une action ; les nôtres sont dans le
      // `PdlBanner`, qui porte la charte. Celle-ci ne rend rien.
      actions: const <Widget>[SizedBox.shrink()],
    ),
  );
}
