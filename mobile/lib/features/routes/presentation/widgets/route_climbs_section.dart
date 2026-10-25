import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/utils/formatters.dart';

/// « Cols et montées (N) », au singulier pour une seule montée (`MOB-45`).
///
/// `TrackDto.climbs` **existe au contrat et n'avait jamais été lu** par le
/// mobile : cette section l'active.
///
/// Une montée porte le nom du waypoint que l'auteur du parcours a posé à son
/// sommet (`ClimbDto.name`, `docs/LEDGER_*.md API-10`) ; sans lui, « Montée N »,
/// dérivé de l'index. Le serveur ne devine rien d'autre : inventer un toponyme
/// à partir de la position serait une donnée fausse.
class RouteClimbsSection extends ConsumerWidget {
  const RouteClimbsSection({super.key, required this.climbs, this.onTapClimb});

  final List<ClimbDto> climbs;

  /// Pointe la montée sur la carte et le profil.
  final ValueChanged<ClimbDto>? onTapClimb;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (climbs.isEmpty) return const SizedBox.shrink();

    final PdlColors c = context.pdl;
    final UnitSystem units = ref.watch(unitSystemProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PdlSectionHeader(
          title: 'routes.climbs'.plural(climbs.length),
          padding: const EdgeInsets.only(bottom: 4),
        ),
        for (int i = 0; i < climbs.length; i++)
          PdlClimbRow(
            // Les badges de catégorie sont la **seule** série rendue en aplat
            // de la charte : HC raisin jusqu'à Cat.4 vert, Cat.3 à texte
            // sombre parce que le jaune ne porte pas de blanc.
            categoryLabel: _categoryLabel(climbs[i].category),
            categoryTone: ClimbCategory.fromJson(climbs[i].category ?? '')
                .tone(c),
            name:
                climbs[i].name ??
                'routes.climbNumber'.tr(
                  namedArgs: <String, String>{'index': '${i + 1}'},
                ),
            range: 'routes.climbRange'.tr(
              namedArgs: <String, String>{
                'from': AppFormatters.formatDistance(
                  climbs[i].startDistance.toDouble(),
                  units,
                ),
                'to': AppFormatters.formatDistance(
                  climbs[i].endDistance.toDouble(),
                  units,
                ),
              },
            ),
            figures: <PdlClimbFigure>[
              PdlClimbFigure(
                value: AppFormatters.formatElevation(
                  climbs[i].elevationGain.toDouble(),
                  units,
                ),
                label: 'units.elevationGain'.tr(),
              ),
              PdlClimbFigure(
                value: AppFormatters.formatGrade(climbs[i].averageGradient),
                label: 'routes.gradeAverage'.tr(),
              ),
              PdlClimbFigure(
                value: AppFormatters.formatGrade(climbs[i].maxGradient),
                label: 'routes.gradeMax'.tr(),
              ),
            ],
            showDivider: i < climbs.length - 1,
            onTap: onTapClimb == null ? null : () => onTapClimb!(climbs[i]),
          ),
      ],
    );
  }

  /// « HC », « Cat. 1 »… `category` nulle signifie « non catégorisée » : la
  /// montée existe, le serveur ne lui a pas donné de rang.
  String _categoryLabel(String? category) => switch (category) {
    'HC' => 'routes.climbCategory.hc'.tr(),
    'CAT1' => 'routes.climbCategory.cat1'.tr(),
    'CAT2' => 'routes.climbCategory.cat2'.tr(),
    'CAT3' => 'routes.climbCategory.cat3'.tr(),
    'CAT4' => 'routes.climbCategory.cat4'.tr(),
    _ => 'routes.climbCategory.none'.tr(),
  };
}
