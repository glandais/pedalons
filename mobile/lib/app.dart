import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/locale_context.dart';
import 'config/router.dart';
import 'core/config/config_provider.dart';
import 'core/preferences/user_preferences_provider.dart';
import 'core/utils/formatters.dart';
import 'core/theme/theme.dart';
import 'features/auth/providers/auth_provider.dart';

class PedalonsApp extends ConsumerStatefulWidget {
  const PedalonsApp({super.key});

  @override
  ConsumerState<PedalonsApp> createState() => _PedalonsAppState();
}

class _PedalonsAppState extends ConsumerState<PedalonsApp> {
  @override
  void initState() {
    super.initState();
    // Initialize auth state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).initialize();
      // La configuration servie (fonds de carte, centre par défaut, plancher
      // de version) est demandée dès le démarrage : la première carte ouverte
      // ne doit pas attendre un aller-retour pour connaître son style.
      ref.read(appConfigProvider);
    });
  }

  /// Applique la langue choisie par l'utilisateur si elle diffère de celle du
  /// contexte. `null` signifie « jamais choisi » : easy_localization suit
  /// alors l'appareil, ce qui est le comportement attendu.
  void _syncLocale(String? language) {
    if (language == null) return;
    final String code = language.split('-').first;
    if (code == context.locale.languageCode) return;
    Locale? target;
    for (final Locale l in context.supportedLocales) {
      if (l.languageCode == code) {
        target = l;
        break;
      }
    }
    if (target == null) return;
    final Locale resolved = target;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.setLocale(resolved);
    });
  }

  @override
  Widget build(BuildContext context) {
    setCurrentLocale(context.locale.languageCode);
    // La locale d'`Intl` suit la langue de l'app, pas celle de l'appareil
    // qu'easy_localization y laisse (`findSystemLocale`) : sans quoi une app en
    // français sur un iPhone en anglais lit « heure Paris » au lieu de « heure
    // de Paris » et « 66.5 km » au lieu de « 66,5 km » — `AppFormatters` lit
    // `Intl.getCurrentLocale()`, comme le posent ses tests.
    Intl.defaultLocale = context.locale.languageCode;
    final authState = ref.watch(authProvider);
    final router = ref.watch(routerProvider);
    final preferences = ref.watch(userPreferencesProvider);
    _syncLocale(preferences.language);
    // Le fuseau de `UserDto.timezone`, sinon celui de l'appareil — comme le web
    // (docs/LEDGER_*.md API-15). Posé avant que le moindre écran ne formate une
    // date ; déconnecté, on revient à l'appareil.
    AppFormatters.setDisplayTimezone(authState.user?.timezone);
    // 12 h ou 24 h : la langue décide (français 24 h, anglais 12 h), comme
    // le web — `AppFormatters.formatTime` lit le motif `jm` de la locale
    // posée ci-dessus. Le réglage du téléphone n'est plus lu (décision du
    // 2026-11-10, docs/plans/2026-11-10-etat-des-lieux-affichage §6.7).

    final lightTheme = PedalonsTheme.build(Brightness.light);
    final darkTheme = PedalonsTheme.build(Brightness.dark);

    // Show loading while initializing
    if (!authState.isInitialized) {
      return MaterialApp(
        title: 'Pédalons',
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: preferences.themeMode,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp.router(
      title: 'Pédalons',
      theme: lightTheme,
      darkTheme: darkTheme,
      // Sans `themeMode`, l'app suivait le système sans recours possible : un
      // utilisateur qui choisissait « clair » restait en sombre.
      themeMode: preferences.themeMode,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
