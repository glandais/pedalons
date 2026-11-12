import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart' show Intl;
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Charge les vraies traductions **une fois**, statiquement.
///
/// La plupart des tests s'en passent : sans easy_localization, `.tr()` rend la
/// clé, ce qui suffit à repérer un libellé et évite de faire dépendre une
/// mesure de mise en page d'un chargement d'assets.
///
/// `.plural()` ne pardonne pas la même chose : il lève un
/// `LateInitializationError` tant qu'aucune locale n'est posée. Tout écran qui
/// affiche un compteur (« 10 groupes », « 3 commentaires ») doit donc appeler
/// ceci dans son `setUpAll`.
///
/// Le fichier est lu **au disque** et non par `rootBundle` : monter le widget
/// `EasyLocalization` chargerait les assets de façon asynchrone, et son état
/// de chargement rend un conteneur vide qu'un test de widget ne sait pas
/// attendre proprement — un écran entier disparaît alors sans erreur.
Future<void> loadTestTranslations({String languageCode = 'fr'}) async {
  final File file = File('assets/l10n/$languageCode.json');
  final Map<String, dynamic> data =
      json.decode(await file.readAsString()) as Map<String, dynamic>;
  // `AppFormatters` lit `Intl.getCurrentLocale()` : sans cette ligne, les
  // séparateurs décimaux restent anglais et « 66,5 km » se lit « 66.5 km ».
  // Poser la locale **oblige** à charger ses données de date, sans quoi le
  // premier `DateFormat` lève un `LocaleDataException` — et l'écran entier
  // disparaît sans autre signe.
  await initializeDateFormatting(languageCode);
  Intl.defaultLocale = languageCode;
  Localization.load(
    Locale(languageCode),
    translations: Translations(data),
    fallbackTranslations: Translations(data),
    ignorePluralRules: false,
  );
}
