import 'package:flutter/material.dart';

import '../theme/enum_colors.dart' show PdlTone;
import '../theme/pdl_colors.dart';
import '../theme/pdl_tokens.dart';
import '../theme/pdl_typography.dart';

/// Les deux tailles de la boîte du jour.
enum PdlDayBoxSize {
  /// 56 px, trois lignes — jour, chiffre en 22/700, mois (BRANDING §7.8) :
  /// cartes du tableau de bord, bloc de départ.
  regular,

  /// 44 px, deux lignes — jour, chiffre en 16/700, sans mois : l'agenda
  /// « Cette semaine » de l'accueil, dont la semaine dit déjà le mois.
  compact,
}

/// La boîte du jour, **à plat** (BRANDING §7.8, ledger `BRAND-8`) : « sam. /
/// 12 / avr. » sur le fond doux de son ton, rayon 8.
///
/// Ne formate rien : l'appelant passe les libellés déjà traduits, lus dans
/// le fuseau de l'entité (`core/widgets/day_box.dart` les fabrique d'une
/// heure murale). Sans [tone], le fond doux `primary` — une sortie.
class PdlDayBox extends StatelessWidget {
  const PdlDayBox({
    super.key,
    required this.weekday,
    required this.day,
    this.month,
    this.tone,
    this.size = PdlDayBoxSize.regular,
  });

  /// « sam. »
  final String weekday;

  /// « 12 »
  final String day;

  /// « avr. » ; ignoré en [PdlDayBoxSize.compact].
  final String? month;

  final PdlTone? tone;
  final PdlDayBoxSize size;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final Color soft = tone?.soft ?? c.primarySoft;
    final Color onSoft = tone?.onSoft ?? c.primaryOnSoft;
    final bool compact = size == PdlDayBoxSize.compact;

    return Container(
      width: compact ? PdlMetrics.tapTarget : PdlMetrics.dayBox,
      padding: EdgeInsets.symmetric(
        vertical: compact ? 6 : PdlSpacing.badgeGap,
      ),
      decoration: BoxDecoration(color: soft, borderRadius: PdlRadii.mdAll),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            weekday,
            style: (compact ? t.xs : t.dayBoxWeekday).copyWith(color: onSoft),
          ),
          Text(
            day,
            style: compact
                ? t.cardTitle.copyWith(color: onSoft)
                : t.dayBoxNumber,
          ),
          if (!compact && month != null)
            Text(month!, style: t.dayBoxMonth.copyWith(color: onSoft)),
        ],
      ),
    );
  }
}
