import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/theme/enum_colors.dart';
import 'package:pedalons/core/theme/pdl_colors.dart';

/// Le disque des points de parcours sur la carte et le profil (`MOB-84`) : la
/// teinte claire dans les deux thèmes, le glyphe foncé ou blanc selon la
/// luminance. La table des couleurs n'est jamais recopiée ici : on lit
/// l'extension.
void main() {
  test('le disque est le même en clair et en sombre', () {
    for (final WaypointType t in WaypointType.$valuesDefined) {
      expect(t.markerDisc, t.family.soft(PdlColors.light).fill);
      expect(t.family.soft(PdlColors.dark).fill, isNotNull);
    }
  });

  test('le glyphe est foncé sur les disques clairs, blanc ailleurs', () {
    final Color dark = PdlColors.light.neutralOnSoft;
    const Color white = Color(0xFFFFFFFF);
    for (final WaypointType t in <WaypointType>[
      WaypointType.split,
      WaypointType.supply,
      WaypointType.cafe,
      WaypointType.viewpoint,
      WaypointType.realStart,
    ]) {
      expect(t.markerGlyph, dark, reason: t.json);
    }
    for (final WaypointType t in <WaypointType>[
      WaypointType.regroup,
      WaypointType.danger,
      WaypointType.summit,
      WaypointType.water,
      WaypointType.info,
    ]) {
      expect(t.markerGlyph, white, reason: t.json);
    }
  });
}
