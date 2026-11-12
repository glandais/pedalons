import 'dart:async';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/generated/export.dart';
import '../../api/pedalons_api_client.dart';
import '../../features/auth/domain/auth_state.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../material.dart';

/// Les préférences d'affichage de l'utilisateur courant.
///
/// **Une seule chaîne d'autorité**, et elle ne se court-circuite pas :
///
/// 1. `UserDto.theme` / `.language` / `.unitSystem` font autorité — le serveur
///    est la mémoire de l'utilisateur, d'un appareil à l'autre.
/// 2. Un **miroir** local (`shared_preferences`) rejoue ces valeurs pour que
///    le **premier cadre** après un démarrage à froid soit déjà dans le bon
///    mode. Sans lui, l'app s'ouvre en clair puis bascule en sombre une fois
///    `GET /api/users/me` revenu : un clignotement à chaque lancement.
/// 3. Toute modification part en `PATCH /api/users/me/preferences`.
///
/// `contactableByMembers` emprunte le même provider et le même `PATCH` mais
/// **n'a pas de miroir local** : il ne change rien au premier cadre, et le
/// mettre en cache reviendrait à afficher un état de confidentialité périmé.
@immutable
class UserPreferences {
  const UserPreferences({
    this.theme = ThemePreference.system,
    this.unitSystem = UnitSystem.metric,
    this.language,
    this.contactableByMembers = true,
  });

  final ThemePreference theme;
  final UnitSystem unitSystem;

  /// Étiquette BCP-47. `null` signifie que l'utilisateur n'a jamais choisi :
  /// on suit alors l'appareil ou le domaine.
  final String? language;

  final bool contactableByMembers;

  ThemeMode get themeMode => switch (theme) {
    ThemePreference.light => ThemeMode.light,
    ThemePreference.dark => ThemeMode.dark,
    ThemePreference.system || ThemePreference.$unknown => ThemeMode.system,
  };

  UserPreferences copyWith({
    ThemePreference? theme,
    UnitSystem? unitSystem,
    Object? language = _unset,
    bool? contactableByMembers,
  }) => UserPreferences(
    theme: theme ?? this.theme,
    unitSystem: unitSystem ?? this.unitSystem,
    language: language == _unset ? this.language : language as String?,
    contactableByMembers: contactableByMembers ?? this.contactableByMembers,
  );

  static const Object _unset = Object();

  @override
  bool operator ==(Object other) =>
      other is UserPreferences &&
      other.theme == theme &&
      other.unitSystem == unitSystem &&
      other.language == language &&
      other.contactableByMembers == contactableByMembers;

  @override
  int get hashCode =>
      Object.hash(theme, unitSystem, language, contactableByMembers);
}

/// Le miroir local, chargé **avant** `runApp` et injecté par surcharge de
/// provider. Un accès direct sans surcharge est une erreur de câblage, pas un
/// cas à traiter en douceur : d'où la levée.
final Provider<SharedPreferences> sharedPreferencesProvider =
    Provider<SharedPreferences>(
      (Ref ref) => throw StateError(
        'sharedPreferencesProvider doit être surchargé dans main() : '
        'le miroir des préférences se lit avant le premier cadre.',
      ),
    );

const String _kThemeKey = 'prefs.theme';
const String _kUnitSystemKey = 'prefs.unitSystem';
const String _kLanguageKey = 'prefs.language';

/// Relit le miroir local. Synchrone : appelé pendant la construction du
/// premier cadre.
UserPreferences readMirror(SharedPreferences prefs) {
  final String? theme = prefs.getString(_kThemeKey);
  final String? units = prefs.getString(_kUnitSystemKey);
  return UserPreferences(
    theme: theme == null
        ? ThemePreference.system
        : ThemePreference.fromJson(theme),
    unitSystem: units == null ? UnitSystem.metric : UnitSystem.fromJson(units),
    language: prefs.getString(_kLanguageKey),
  );
}

final NotifierProvider<UserPreferencesNotifier, UserPreferences>
userPreferencesProvider =
    NotifierProvider<UserPreferencesNotifier, UserPreferences>(
      UserPreferencesNotifier.new,
    );

class UserPreferencesNotifier extends Notifier<UserPreferences> {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  /// Le miroir donne l'état du premier cadre ; l'utilisateur connu, quand il
  /// arrive, l'écrase et le rafraîchit.
  ///
  /// Un champ nul côté serveur signifie « jamais choisi » : on conserve alors
  /// la valeur du miroir plutôt que de retomber sur le défaut, sans quoi un
  /// utilisateur qui n'a jamais ouvert ses préférences verrait son thème
  /// réinitialisé à chaque connexion.
  @override
  UserPreferences build() {
    final SharedPreferences prefs = ref.watch(sharedPreferencesProvider);
    final UserPreferences mirror = readMirror(prefs);
    final UserDto? user = ref.watch(
      authProvider.select((AuthState s) => s.user),
    );
    if (user == null) return mirror;
    final UserPreferences adopted = mirror.copyWith(
      theme: user.theme == null ? null : ThemePreference.fromJson(user.theme!),
      unitSystem: user.unitSystem == null
          ? null
          : UnitSystem.fromJson(user.unitSystem!),
      language: user.language ?? mirror.language,
      contactableByMembers: user.contactableByMembers,
    );
    if (adopted != mirror) unawaited(_writeMirror(adopted));
    return adopted;
  }

  Future<void> setTheme(ThemePreference value) => _apply(
    state.copyWith(theme: value),
    UserPreferencesRequest(theme: value.json),
  );

  Future<void> setUnitSystem(UnitSystem value) => _apply(
    state.copyWith(unitSystem: value),
    UserPreferencesRequest(unitSystem: value.json),
  );

  Future<void> setLanguage(String? value) => _apply(
    state.copyWith(language: value),
    UserPreferencesRequest(language: value),
  );

  Future<void> setContactableByMembers(bool value) => _apply(
    state.copyWith(contactableByMembers: value),
    UserPreferencesRequest(contactableByMembers: value),
  );

  /// Le fuseau d'affichage (`UserDto.timezone`, nom IANA). Il n'a ni état
  /// local ni miroir : `app.dart` le lit sur l'utilisateur connecté et le pose
  /// dans `AppFormatters`, et c'est la réponse du serveur, adoptée par
  /// `setUser`, qui le fait changer. Le même champ que le site.
  Future<void> setTimezone(String value) async {
    final UserDto user = await ref
        .read(usersClientProvider)
        .updateMyPreferences(body: UserPreferencesRequest(timezone: value));
    ref.read(authProvider.notifier).setUser(user);
  }

  /// Applique en optimiste, puis persiste. En cas d'échec réseau l'état revient
  /// à sa valeur précédente et l'exception remonte : c'est à l'écran d'en
  /// rendre compte, pas au provider de l'avaler.
  Future<void> _apply(
    UserPreferences next,
    UserPreferencesRequest request,
  ) async {
    final UserPreferences previous = state;
    if (next == previous) return;
    state = next;
    await _writeMirror(next);
    try {
      final UserDto user = await ref
          .read(usersClientProvider)
          .updateMyPreferences(body: request);
      ref.read(authProvider.notifier).setUser(user);
    } catch (error, stackTrace) {
      state = previous;
      await _writeMirror(previous);
      log(
        'Échec de la mise à jour des préférences',
        name: 'UserPreferences',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// `contactableByMembers` n'est volontairement pas miroité : voir la
  /// documentation de [UserPreferences].
  Future<void> _writeMirror(UserPreferences p) async {
    await _prefs.setString(_kThemeKey, p.theme.json ?? 'SYSTEM');
    await _prefs.setString(_kUnitSystemKey, p.unitSystem.json ?? 'METRIC');
    if (p.language == null) {
      await _prefs.remove(_kLanguageKey);
    } else {
      await _prefs.setString(_kLanguageKey, p.language!);
    }
  }
}

/// Raccourcis de lecture, pour que les écrans n'aient pas à reconstruire la
/// dérivation à chaque fois.
final Provider<ThemeMode> themeModeProvider = Provider<ThemeMode>(
  (Ref ref) => ref.watch(userPreferencesProvider).themeMode,
);

final Provider<UnitSystem> unitSystemProvider = Provider<UnitSystem>(
  (Ref ref) => ref.watch(userPreferencesProvider).unitSystem,
);
