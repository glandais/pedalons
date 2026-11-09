import 'package:flutter/widgets.dart';

import '../pdl/pdl.dart';
import '../theme/enum_colors.dart' show PdlTone;
import '../utils/formatters.dart';

/// La boîte du jour d'une heure murale [wall] — déjà ramenée au fuseau de
/// l'entité (`toZoneTime`) : « sam. / 12 / avr. » dans la locale courante,
/// plus l'année quand elle n'est pas celle de [now] (par défaut
/// `AppFormatters.displayNow()`) : sur une carte, la boîte est la seule date.
///
/// La seule fabrique de `PdlDayBox` de l'app (BRANDING §7.8) : le tableau de
/// bord, l'agenda de l'accueil, le bloc de départ et les cartes du fil en
/// passent tous par là.
PdlDayBox dayBoxFor(
  DateTime wall, {
  Key? key,
  PdlTone? tone,
  PdlDayBoxSize size = PdlDayBoxSize.regular,
  bool posed = false,
  DateTime? now,
}) => PdlDayBox(
  key: key,
  weekday: AppFormatters.dayAbbrev(wall.weekday),
  day: '${wall.day}',
  month: AppFormatters.monthAbbrev(wall.month),
  year: wall.year == (now ?? AppFormatters.displayNow()).year
      ? null
      : '${wall.year}',
  tone: tone,
  size: size,
  posed: posed,
);
