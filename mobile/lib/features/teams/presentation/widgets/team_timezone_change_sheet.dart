import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/locale_context.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/zone_label.dart';
import '../../../../keys.dart';
import '../../data/team_repository.dart';

/// Ce qu'un changement de fuseau fait à l'équipe, dans les mots du site
/// (`TimezoneChangePreview`, ledger `API-60`) : « 3 rendez-vous à venir sans
/// lieu de départ, par exemple la sortie « Boucle » du sam. 11 oct. restera à
/// 09:30, désormais heure de Montréal. »
///
/// La date et l'heure de l'exemple sont lues dans l'**ancien** fuseau
/// (`preview.from`) : c'est l'heure murale que le rendez-vous garde dans le
/// nouveau. L'app ne calcule aucun fuseau ici — la liste de ce qui bouge vient
/// du serveur.
List<String> timezoneChangeLines(
  TeamTimezoneChangePreviewDto preview,
  String languageCode,
) {
  final String ofCity = zoneCityOf(preview.to, languageCode);
  final TeamTimezoneChangeItemDto? first = preview.upcoming.isEmpty
      ? null
      : preview.upcoming.first;
  final DateTime? start = first == null
      ? null
      : DateTime.tryParse(first.dateTime)?.toUtc();

  String upcoming() {
    if (first == null || start == null) {
      return 'teams.editor.timezoneChange.none'.tr();
    }
    final TimezoneChangeEntityType type = TimezoneChangeEntityType.fromJson(
      first.type,
    );
    final String example =
        'teams.editor.timezoneChange.example.${type.json ?? 'other'}'.tr(
          namedArgs: <String, String>{
            'title': first.title,
            'trip': first.tripTitle ?? '',
            'date': AppFormatters.formatDepartureDate(start, preview.from),
            'time': AppFormatters.formatTime(
              AppFormatters.toZoneTime(start, preview.from),
            ),
            'ofCity': ofCity,
          },
        );
    return 'teams.editor.timezoneChange.upcoming'.plural(
      preview.upcomingCount,
      namedArgs: <String, String>{'example': example},
    );
  }

  return <String>[
    'teams.editor.timezoneChange.question'.tr(
      namedArgs: <String, String>{
        'ofFrom': zoneCityOf(preview.from, languageCode),
        'ofTo': ofCity,
      },
    ),
    upcoming(),
    if (preview.pastCount > 0)
      'teams.editor.timezoneChange.past'.plural(
        preview.pastCount,
        namedArgs: <String, String>{'ofCity': ofCity},
      ),
    'teams.editor.timezoneChange.located'.tr(),
  ];
}

/// La confirmation d'un changement de fuseau, avant d'enregistrer les
/// paramètres (docs/LEDGER_*.md MOB-166) : la feuille lit l'aperçu du serveur
/// (`previewTeamTimezoneChange`) et rend `true` si la personne confirme.
///
/// « Changer le fuseau » reste inactif tant que l'aperçu n'est pas là : on ne
/// confirme pas ce qu'on n'a pas lu. Un échec se dit, avec « Réessayer ».
Future<bool> confirmTeamTimezoneChange(
  BuildContext context, {
  required String teamSlug,
  required String timezone,
}) async {
  final bool? confirmed = await PdlSheet.show<bool>(
    context: context,
    builder: (BuildContext _) =>
        _TimezoneChangeSheet(teamSlug: teamSlug, timezone: timezone),
  );
  return confirmed ?? false;
}

class _TimezoneChangeSheet extends ConsumerStatefulWidget {
  const _TimezoneChangeSheet({required this.teamSlug, required this.timezone});

  final String teamSlug;
  final String timezone;

  @override
  ConsumerState<_TimezoneChangeSheet> createState() =>
      _TimezoneChangeSheetState();
}

class _TimezoneChangeSheetState extends ConsumerState<_TimezoneChangeSheet> {
  TeamTimezoneChangePreviewDto? _preview;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final TeamTimezoneChangePreviewDto preview = await ref
          .read(teamRepositoryProvider)
          .previewTimezoneChange(widget.teamSlug, widget.timezone);
      if (mounted) setState(() => _preview = preview);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final TeamTimezoneChangePreviewDto? preview = _preview;

    final Widget body;
    if (preview != null) {
      final List<String> lines = timezoneChangeLines(
        preview,
        getCurrentLocale(),
      );
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(lines.first, style: t.bodyStrong),
          const SizedBox(height: PdlSpacing.chipGap),
          Text(
            lines[1],
            key: keys.teamEditor.timezoneChangeUpcoming,
            style: t.body,
          ),
          for (final String line in lines.skip(2)) ...<Widget>[
            const SizedBox(height: PdlSpacing.chipGap),
            Text(line, style: t.sub.copyWith(color: c.textDimmed)),
          ],
        ],
      );
    } else if (_failed) {
      body = Column(
        key: keys.teamEditor.timezoneChangeError,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('teams.editor.timezoneChange.error'.tr(), style: t.body),
          const SizedBox(height: PdlSpacing.chipGap),
          PdlButton(
            key: keys.teamEditor.timezoneChangeRetry,
            label: 'common.retry'.tr(),
            variant: PdlButtonVariant.outline,
            size: PdlButtonSize.sm,
            onPressed: _load,
          ),
        ],
      );
    } else {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: PdlSpacing.section),
        child: Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    return PdlSheet(
      key: keys.teamEditor.timezoneChangeSheet,
      title: 'teams.editor.timezoneChange.title'.tr(),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
        child: body,
      ),
      footer: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(PdlSpacing.section),
          child: Row(
            children: <Widget>[
              Expanded(
                child: PdlButton(
                  label: 'common.cancel'.tr(),
                  variant: PdlButtonVariant.outline,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: PdlSpacing.chipGap),
              Expanded(
                child: PdlButton(
                  key: keys.teamEditor.timezoneChangeConfirm,
                  label: 'teams.editor.timezoneChange.confirm'.tr(),
                  // Rien à confirmer tant que les conséquences ne sont pas
                  // lues.
                  enabled: preview != null,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
