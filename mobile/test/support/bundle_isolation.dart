import 'package:easy_localization/easy_localization.dart' show Intl;
import 'package:easy_localization/src/localization.dart';
import 'package:flutter/widgets.dart';
import 'package:pedalons/core/utils/formatters.dart';

/// Rend l'état statique qu'un fichier de test peut poser à ce qu'il est au
/// lancement d'un isolate neuf.
///
/// `tool/test.sh` regroupe plusieurs fichiers `*_test.dart` dans un même
/// isolate (`tool/test_bundles.dart`) pour ne pas compiler 250 fois les mêmes
/// dépendances. Chaque fichier y passe dans un `group` qui appelle ceci en
/// premier `setUpAll`, avant ceux du fichier : un fichier qui n'appelle pas
/// `loadTestTranslations` doit lire des clés brutes, même si son voisin de
/// paquet a chargé le français.
///
/// Un nouvel état statique posé par un test (et que le test ne défait pas
/// lui-même) se remet à zéro ici.
void resetTestGlobals() {
  // Sans traductions, `.tr()` rend la clé : l'état d'un isolate neuf.
  Localization.load(const Locale('fr'));
  Intl.defaultLocale = null;
  AppFormatters.setDisplayTimezone(null);
}
