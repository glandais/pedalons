/// Le seul point d'entrée de Material pour l'application et ses tests.
///
/// Flutter 3.50 déprécie `package:flutter/material.dart` au profit du paquet
/// `material_ui`, qui est une **autre** implémentation : ses `Theme`,
/// `MaterialLocalizations` et `SelectionArea` ne sont pas ceux du SDK. Tant que
/// `markdown_widget`, `maplibre`, `photo_view` et `easy_localization` importent
/// l'ancien Material, basculer l'application seule fait cohabiter les deux —
/// thème de repli dans le markdown, libellés Material en anglais.
///
/// On reste donc sur le Material du SDK, importé **ici et nulle part ailleurs** :
/// la bascule se fera en changeant cette ligne (et en retirant l'`ignore`), une
/// fois les dépendances migrées.
library;

// `CupertinoPageTransitionsBuilder` appartient à Cupertino, pas à Material
// (docs.flutter.dev/release/breaking-changes/decouple-page-transition-builders) ;
// `PedalonsTheme` en a besoin pour ses transitions de page, et c'est le seul
// symbole Cupertino de l'application.
// ignore: deprecated_member_use
export 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
// ignore: deprecated_member_use
export 'package:flutter/material.dart';
