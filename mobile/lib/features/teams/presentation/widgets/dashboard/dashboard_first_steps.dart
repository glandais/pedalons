import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../config/paths.dart';
import '../../../../../core/material.dart';
import '../../../../../core/pdl/pdl.dart';
import '../../../../../core/preferences/user_preferences_provider.dart';
import '../../../../../core/theme/pdl_colors.dart';
import '../../../../../core/theme/pdl_icons.dart';
import '../../../../../core/theme/pdl_tokens.dart';
import '../../../../../core/theme/pdl_typography.dart';
import '../../../../../keys.dart';
import '../../../../rides/presentation/ride_editor_location.dart';
import '../../../providers/team_first_steps_provider.dart';
import '../../pages/team_admin_members_page.dart';

String _dismissedKey(String teamId) => 'firstSteps.dismissed.$teamId';

/// « Premières étapes », pour qui administre une équipe encore vide
/// (docs/LEDGER_*.md WEB-195) : inviter des membres, créer une première
/// sortie, importer ou tracer un premier parcours — chacune mène à son écran,
/// et se coche d'après l'équipe ([teamFirstStepsProvider]).
///
/// Rien tant que l'état charge ou a échoué : une étape ne paraît jamais ouverte
/// faute de réponse. La liste disparaît une fois tout fait, comme « À traiter »
/// quand rien n'attend, et se masque à la main — ce choix reste sur l'appareil,
/// par équipe.
class DashboardFirstSteps extends ConsumerStatefulWidget {
  const DashboardFirstSteps({
    super.key,
    required this.teamId,
    required this.teamSlug,
  });

  final String teamId;
  final String teamSlug;

  @override
  ConsumerState<DashboardFirstSteps> createState() =>
      _DashboardFirstStepsState();
}

class _DashboardFirstStepsState extends ConsumerState<DashboardFirstSteps> {
  late bool _dismissed =
      ref
          .read(sharedPreferencesProvider)
          .getBool(_dismissedKey(widget.teamId)) ??
      false;

  void _dismiss() {
    final SharedPreferences prefs = ref.read(sharedPreferencesProvider);
    prefs.setBool(_dismissedKey(widget.teamId), true);
    setState(() => _dismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    final FirstStepsState? state = ref
        .watch(teamFirstStepsProvider(widget.teamSlug))
        .value;
    if (state == null) return const SizedBox.shrink();

    final String slug = widget.teamSlug;
    final List<_Step> steps = <_Step>[
      if (state.invite != null)
        _Step(
          key: keys.teamDashboard.firstStep('invite'),
          done: state.invite!,
          icon: PdlIcons.personAdd,
          label: 'teams.dashboard.firstSteps.invite'.tr(),
          location: teamAdminMembersInviteLocation(slug),
        ),
      if (state.ride != null)
        _Step(
          key: keys.teamDashboard.firstStep('ride'),
          done: state.ride!,
          icon: PdlIcons.ride,
          label: 'teams.dashboard.firstSteps.ride'.tr(),
          location: rideNewLocation(slug),
        ),
      if (state.route != null)
        _Step(
          key: keys.teamDashboard.firstStep('route'),
          done: state.route!,
          icon: PdlIcons.route,
          label: 'teams.dashboard.firstSteps.route'.tr(),
          location: Paths.routeNew(slug),
        ),
    ];
    final int done = steps.where((_Step s) => s.done).length;
    if (steps.isEmpty || done == steps.length) return const SizedBox.shrink();

    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    return Padding(
      padding: const EdgeInsets.only(top: PdlSpacing.section),
      child: PdlCard(
        key: keys.teamDashboard.firstSteps,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'teams.dashboard.firstSteps.title'.tr(),
                        style: t.cardTitle,
                      ),
                      Text(
                        'teams.dashboard.firstSteps.progress'.tr(
                          namedArgs: <String, String>{
                            'done': '$done',
                            'total': '${steps.length}',
                          },
                        ),
                        style: t.sub.copyWith(color: c.textDimmed),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: keys.teamDashboard.firstStepsDismiss,
                  icon: const Icon(PdlIcons.close),
                  tooltip: 'teams.dashboard.firstSteps.dismiss'.tr(),
                  onPressed: _dismiss,
                ),
              ],
            ),
            for (final _Step step in steps) _StepRow(step: step),
          ],
        ),
      ),
    );
  }
}

class _Step {
  const _Step({
    required this.key,
    required this.done,
    required this.icon,
    required this.label,
    required this.location,
  });

  final Key key;
  final bool done;
  final IconData icon;
  final String label;
  final String location;
}

/// Une étape : faite, elle reste dans la liste, cochée, mais ne mène plus
/// nulle part — c'est la suivante qu'il faut prendre.
class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});

  final _Step step;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    return Semantics(
      key: step.key,
      button: !step.done,
      checked: step.done,
      child: InkWell(
        onTap: step.done ? null : () => context.push(step.location),
        borderRadius: const BorderRadius.all(PdlRadii.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: PdlMetrics.tapTarget),
          child: Row(
            children: <Widget>[
              Icon(
                step.done ? PdlIcons.checkCircle : step.icon,
                size: 20,
                color: step.done ? c.success : c.primary,
              ),
              const SizedBox(width: PdlSpacing.chipGap),
              Expanded(
                child: Text(
                  step.label,
                  style: t.body.copyWith(
                    color: step.done ? c.textDimmed : c.text,
                    decoration: step.done ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              if (!step.done)
                Icon(PdlIcons.chevronRight, size: 18, color: c.textDimmed),
            ],
          ),
        ),
      ),
    );
  }
}
