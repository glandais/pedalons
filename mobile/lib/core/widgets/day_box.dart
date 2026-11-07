import 'package:flutter/widgets.dart';

import '../pdl/pdl.dart';
import '../theme/enum_colors.dart' show PdlTone;
import '../utils/formatters.dart';

/// La boîte du jour d'une heure murale [wall] — déjà ramenée au fuseau de
/// l'entité (`toZoneTime`) : « sam. / 12 / avr. » dans la locale courante.
///
/// La seule fabrique de `PdlDayBox` de l'app (BRANDING §7.8) : le tableau de
/// bord, l'agenda de l'accueil et le bloc de départ en passent tous par là.
PdlDayBox dayBoxFor(
  DateTime wall, {
  Key? key,
  PdlTone? tone,
  PdlDayBoxSize size = PdlDayBoxSize.regular,
}) => PdlDayBox(
  key: key,
  weekday: AppFormatters.dayAbbrev(wall.weekday),
  day: '${wall.day}',
  month: AppFormatters.monthAbbrev(wall.month),
  tone: tone,
  size: size,
);
