import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../keys.dart';
import '../../../routes/data/gpx_file_source.dart';
import '../../../routes/domain/gpx_check.dart';
import '../../../routes/presentation/widgets/editor/gpx_refused_banner.dart';
import '../../../routes/providers/route_changes.dart';
import '../../data/gpx_preview_repository.dart';
import '../../data/received_gpx_file.dart';
import '../../providers/gpx_preview_provider.dart';
import '../widgets/gpx_preview_save_as_route_sheet.dart';

/// Ouvre « Fichier reçu » par-dessus l'écran courant, sur le navigateur
/// racine (docs/LEDGER_*.md MOB-191). Pas une route du contrat : l'écran n'a
/// pas d'adresse sur le site, il n'existe que le temps de décider quoi faire
/// du fichier.
Future<void> showReceivedGpxPage(NavigatorState navigator, GpxFile file) =>
    navigator.push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (BuildContext _) => ReceivedGpxPage(file: file),
      ),
    );

/// « Fichier reçu » : un .gpx ouvert ou partagé depuis une autre app
/// (docs/LEDGER_*.md MOB-191). Le fichier, puis deux choix — le visualiser
/// (un aperçu à soi, comme « Visualiser un fichier » des outils GPX) ou
/// l'enregistrer dans une équipe (le même aperçu, puis la feuille
/// « Enregistrer comme parcours »). « Fusionner » n'est pas proposé ici.
///
/// Le fichier passe d'abord le contrôle local ([inspectGpxFile]) : refusé, le
/// bandeau le dit et les deux choix restent fermés. **Un geste à la fois**,
/// comme à l'accueil des outils. Fermer l'écran efface la copie reçue.
class ReceivedGpxPage extends ConsumerStatefulWidget {
  const ReceivedGpxPage({super.key, required this.file});

  final GpxFile file;

  @override
  ConsumerState<ReceivedGpxPage> createState() => _ReceivedGpxPageState();
}

enum _Busy { none, view, team }

class _ReceivedGpxPageState extends ConsumerState<ReceivedGpxPage> {
  /// Le contrôle local, `null` tant qu'il n'a pas répondu.
  GpxCheck? _check;

  /// L'aperçu déjà créé : « Enregistrer dans une équipe » refermé sans
  /// choisir ne renvoie pas le fichier une seconde fois.
  GpxPreviewDto? _preview;

  _Busy _busy = _Busy.none;
  GpxRefused? _refused;
  Object? _error;

  bool get _usable => _check is GpxAccepted && _refused == null;
  bool get _idle => _busy == _Busy.none;

  @override
  void initState() {
    super.initState();
    inspectGpxFile(widget.file).then((GpxCheck check) {
      if (!mounted) return;
      setState(() {
        _check = check;
        if (check is GpxRefused) _refused = check;
      });
    });
  }

  @override
  void dispose() {
    deleteReceivedCopy(widget.file);
    super.dispose();
  }

  String get _displayName {
    final GpxCheck? check = _check;
    if (check is GpxAccepted && (check.trackName ?? '').isNotEmpty) {
      return check.trackName!;
    }
    return widget.file.name;
  }

  Future<GpxPreviewDto> _ensurePreview() async {
    final GpxPreviewDto? existing = _preview;
    if (existing != null) return existing;
    final GpxPreviewDto preview = await ref
        .read(gpxPreviewRepositoryProvider)
        .createFromFile(widget.file);
    _preview = preview;
    notifyGpxPreviewChanged(ref);
    return preview;
  }

  Future<void> _view() async {
    if (!_idle || !_usable) return;
    setState(() {
      _busy = _Busy.view;
      _error = null;
    });
    try {
      final GpxPreviewDto preview = await _ensurePreview();
      if (!mounted) return;
      final GoRouter router = GoRouter.of(context);
      Navigator.of(context).pop();
      router.push(Paths.gpxToolsView(preview.id));
    } catch (error, stackTrace) {
      _failed(error, stackTrace);
    } finally {
      if (mounted) setState(() => _busy = _Busy.none);
    }
  }

  /// La feuille des outils GPX, sur l'aperçu de ce fichier. Le parcours créé
  /// s'ouvre à la place de cet écran ; l'aperçu reste dans « Mes fichiers »,
  /// comme quand on enregistre depuis sa fiche.
  Future<void> _saveToTeam() async {
    if (!_idle || !_usable) return;
    setState(() {
      _busy = _Busy.team;
      _error = null;
    });
    try {
      final GpxPreviewDto preview = await _ensurePreview();
      if (!mounted) return;
      final SavedPreviewRoute? saved = await showGpxPreviewSaveAsRouteSheet(
        context,
        preview,
      );
      if (saved == null || !mounted) return;
      notifyRouteChanged(ref, teamSlug: saved.teamSlug);
      final GoRouter router = GoRouter.of(context);
      Navigator.of(context).pop();
      router.push(Paths.route(saved.teamSlug, saved.route.slug));
    } catch (error, stackTrace) {
      _failed(error, stackTrace);
    } finally {
      if (mounted) setState(() => _busy = _Busy.none);
    }
  }

  /// Un refus du serveur qui tient au fichier se dit comme un refus local ;
  /// tout autre échec, en bandeau d'erreur.
  void _failed(Object error, StackTrace stackTrace) {
    if (!mounted) return;
    if (error is PlatformException) {
      setState(() => _error = error);
      return;
    }
    final GpxRefusal? refusal = gpxRefusalOfApiCode(
      resolveApiError(error, stackTrace).code,
    );
    setState(() {
      if (refusal != null) {
        _refused = GpxRefused(widget.file.name, refusal);
      } else {
        _error = error;
      }
    });
  }

  static const Widget _spinner = SizedBox.square(
    dimension: 20,
    child: CircularProgressIndicator(strokeWidth: 2),
  );

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    const SizedBox gap = SizedBox(height: PdlSpacing.feedGap);
    final bool enabled = _usable && _idle;

    return PdlScreenScaffold(
      appBar: PdlAppBar(
        title: 'gpxTools.received.title'.tr(),
        leading: PdlAppBarAction(
          key: keys.gpxTools.receivedClose,
          icon: PdlIcons.close,
          semanticLabel: 'common.close'.tr(),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      slivers: <Widget>[
        SliverPadding(
          key: keys.gpxTools.received,
          padding: const EdgeInsets.all(PdlSpacing.section),
          sliver: SliverList.list(
            children: <Widget>[
              PdlCard(
                child: Row(
                  children: <Widget>[
                    Icon(PdlIcons.route, size: 28, color: c.text),
                    const SizedBox(width: PdlSpacing.chipGap),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            _displayName,
                            key: keys.gpxTools.receivedName,
                            style: t.bodyStrong,
                          ),
                          if (_displayName != widget.file.name)
                            Text(
                              widget.file.name,
                              style: t.sub.copyWith(color: c.textDimmed),
                            ),
                          Text(
                            'gpxTools.received.source'.tr(),
                            style: t.sub.copyWith(color: c.textDimmed),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              gap,
              if (_refused != null) ...<Widget>[
                PdlBanner(
                  key: keys.gpxTools.receivedRefused,
                  tone: PdlBannerTone.danger,
                  icon: PdlIcons.error,
                  title: 'routes.editor.refusedTitle'.tr(),
                  message: gpxRefusalMessage(_refused!),
                ),
                gap,
              ],
              if (_error != null) ...<Widget>[
                PdlBanner(
                  key: keys.gpxTools.receivedError,
                  tone: PdlBannerTone.danger,
                  message: getErrorMessage(_error!),
                  onDismiss: () => setState(() => _error = null),
                  dismissSemanticLabel: 'common.close'.tr(),
                ),
                gap,
              ],
              PdlSectionHeader(title: 'gpxTools.received.question'.tr()),
              PdlCard(
                padding: PdlCardPadding.none,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    PdlSettingRow(
                      key: keys.gpxTools.receivedView,
                      icon: PdlIcons.map,
                      title: 'gpxTools.received.view'.tr(),
                      subtitle: 'gpxTools.received.viewHint'.tr(),
                      trailing: _busy == _Busy.view ? _spinner : null,
                      onTap: enabled ? _view : null,
                      showDivider: true,
                    ),
                    PdlSettingRow(
                      key: keys.gpxTools.receivedSaveToTeam,
                      icon: PdlIcons.team,
                      title: 'gpxTools.received.saveToTeam'.tr(),
                      subtitle: 'gpxTools.received.saveToTeamHint'.tr(),
                      trailing: _busy == _Busy.team ? _spinner : null,
                      onTap: enabled ? _saveToTeam : null,
                    ),
                  ],
                ),
              ),
              gap,
              Text(
                'gpxTools.received.retention'.tr(),
                style: t.xs.copyWith(color: c.textDimmed),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
