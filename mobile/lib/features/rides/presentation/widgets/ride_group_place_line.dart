import '../../../../core/material.dart';

import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../domain/group_title.dart';

/// La ligne sous « Départ 09:30 » d'une carte de sortie (règle R11, KIT §9,
/// docs/LEDGER_*.md MOB-139) : « Groupe B · Place de la Mairie ».
///
/// Le groupe seulement quand la personne y est inscrite ([groupName]), le
/// lieu seulement s'il existe ([placeName]), **son nom seul** : l'adresse est
/// sur la page de la sortie. Le groupe en 600, le lieu atténué ; le lieu
/// passe à la ligne plutôt que de se couper derrière le groupe.
class RideGroupPlaceLine extends StatelessWidget {
  const RideGroupPlaceLine._({super.key, this.groupName, this.placeName});

  /// `null` quand il n'y a ni groupe ni lieu à dire : la carte ne réserve
  /// alors aucune place.
  static Widget? maybe({Key? key, String? groupName, String? placeName}) {
    final String? group = _clean(groupName);
    final String? place = _clean(placeName);
    if (group == null && place == null) return null;
    return RideGroupPlaceLine._(key: key, groupName: group, placeName: place);
  }

  final String? groupName;
  final String? placeName;

  static String? _clean(String? s) {
    final String? v = s?.trim();
    return v == null || v.isEmpty ? null : v;
  }

  /// Le texte de la ligne, tel qu'un lecteur d'écran le lit.
  String get label => <String>[?_groupTitle, ?placeName].join(' · ');

  String? get _groupTitle => groupName == null ? null : groupLabel(groupName!);

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final String? group = _groupTitle;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              group == null ? PdlIcons.place : PdlIcons.people,
              size: 14,
              color: c.textDimmed,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  if (group != null)
                    TextSpan(
                      text: group,
                      style: t.sub.copyWith(
                        color: c.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (group != null && placeName != null)
                    TextSpan(text: ' · ', style: t.sub),
                  if (placeName != null)
                    TextSpan(text: placeName, style: t.sub),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
