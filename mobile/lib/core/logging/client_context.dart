import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/generated/export.dart';
import '../../config/locale_context.dart';
import '../utils/device_description.dart';
import 'app_log.dart';

/// Longueurs maximales imposées par `ClientContextDto`.
const int _kShortFieldMax = 50;
const int _kLongFieldMax = 200;

/// Construit le `ClientContextDto` joint aux rapports — **de façon
/// synchrone**.
///
/// La description de l'appareil se lit une fois, au démarrage ([init]) ; la
/// route courante est tenue à jour par le routeur ([recordNavigation]). Un
/// rapport d'erreur peut alors capturer son contexte à l'instant de l'erreur,
/// sans attendre un plugin — attendre, c'est laisser la route changer entre
/// l'erreur et la photo.
class ClientContextBuilder {
  ClientContextBuilder({
    this._device,
    String? Function()? locale,
    this._platform,
    this._log,
  }) : _locale = locale ?? getCurrentLocale;

  static final ClientContextBuilder instance = ClientContextBuilder(
    log: AppLog.instance,
  );

  DeviceDescription? _device;
  final String? Function() _locale;
  final String? _platform;
  final AppLog? _log;

  String? _route;

  /// Le chemin affiché, sans query string.
  String? get route => _route;

  Future<void> init() async {
    _device ??= await DeviceDescription.load();
  }

  /// Retient le chemin affiché et le note au journal. Le chemin est pris
  /// **sans** query string : les jetons de vérification d'e-mail et de mot de
  /// passe oublié voyagent là.
  void recordNavigation(String location) {
    final String path = stripQuery(location);
    if (path == _route) return;
    _route = path;
    _log?.info('navigation', path);
  }

  ClientContextDto build() {
    final DeviceDescription device = _device ?? const DeviceDescription();
    final String? route = _route;
    return ClientContextDto(
      platform: _platform ?? _currentPlatform(),
      appVersion: truncate(device.appVersion ?? 'unknown', _kShortFieldMax),
      buildNumber: _clip(device.buildNumber, _kShortFieldMax),
      osVersion: _clip(device.osVersion, _kShortFieldMax),
      device: _clip(device.model, _kShortFieldMax),
      route: _clip(route, _kLongFieldMax),
      locale: _clip(_locale(), _kShortFieldMax),
      teamSlug: _clip(teamSlugOf(route), _kShortFieldMax),
    );
  }

  /// Le contexte réduit, quand le membre refuse de joindre les informations
  /// techniques : le contrat exige la plateforme et la version, rien d'autre.
  ClientContextDto buildMinimal() {
    final ClientContextDto full = build();
    return ClientContextDto(
      platform: full.platform,
      appVersion: full.appVersion,
      buildNumber: full.buildNumber,
      locale: full.locale,
    );
  }

  static String _currentPlatform() =>
      (Platform.isIOS ? ClientPlatform.ios : ClientPlatform.android).toJson();

  static String? _clip(String? value, int max) =>
      value == null || value.isEmpty ? null : truncate(value, max);
}

/// `/equipes/gaby/sorties?x=1#y` → `/equipes/gaby/sorties`.
String stripQuery(String location) {
  final int cut = location.indexOf(RegExp(r'[?#]'));
  final String path = cut < 0 ? location : location.substring(0, cut);
  return path.isEmpty ? '/' : path;
}

/// Le slug d'équipe d'un chemin `/equipes/{slug}/…` ou `/teams/{slug}/…`.
String? teamSlugOf(String? path) {
  if (path == null) return null;
  final List<String> segments = path
      .split('/')
      .where((String s) => s.isNotEmpty)
      .toList();
  if (segments.length < 2) return null;
  if (segments[0] != 'equipes' && segments[0] != 'teams') return null;
  // La découverte partage le préfixe, pas le sens.
  if (segments[1] == 'decouvrir' || segments[1] == 'discover') return null;
  return segments[1];
}

final Provider<ClientContextBuilder> clientContextBuilderProvider =
    Provider<ClientContextBuilder>((Ref ref) => ClientContextBuilder.instance);
