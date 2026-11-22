import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../api/pedalons_api_client.dart';
import '../../../../config/app_config.dart';
import '../../../../config/locale_context.dart';
import '../../../../config/paths.dart';
import '../../../../core/config/config_provider.dart';
import '../../../../core/geo/location_service.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/units/unit_system.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../keys.dart';
import '../../../auth/domain/auth_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../profile/presentation/widgets/confirm_sheet.dart';
import '../../../rides/domain/ride_form.dart';
import '../../../rides/presentation/widgets/editor/editor_section.dart';
import '../../../routes/data/gpx_file_source.dart';
import '../../../routes/data/planner_bridge.dart';
import '../../../routes/data/planner_load.dart';
import '../../../routes/data/planner_web_view.dart';
import '../../../routes/domain/gpx_check.dart';
import '../../../routes/domain/planner_quota.dart';
import '../../../routes/domain/planner_result.dart';
import '../../../routes/presentation/pages/route_planner_screen.dart';
import '../../../routes/presentation/widgets/editor/planner_quota_message.dart';
import '../../../routes/presentation/widgets/editor/route_track_section.dart';
import '../../data/gpx_preview_repository.dart';
import '../../domain/preview_departure.dart';
import '../../domain/preview_name.dart';
import '../../providers/gpx_preview_provider.dart';

/// L'éditeur d'un aperçu des outils GPX (docs/LEDGER_*.md MOB-178), le
/// pendant de `GpxPreviewEditor` du site, natif comme celui d'un parcours
/// (`RouteEditorPage`) :
///
/// * **création** ([previewId] nul, `gpxToolsNew`) : le planificateur sur une
///   carte vide — il faut au moins deux points — ou un fichier choisi, puis
///   le nom et le départ. Un fichier importé dans le planificateur et laissé
///   tel quel part par l'envoi de fichier, puis un renommage (les deux appels
///   ne sont pas atomiques : un renommage qui échoue laisse l'aperçu, et
///   l'écran y va quand même) ;
/// * **modification** (`gpxToolsEdit`) : réservée à qui a déposé l'aperçu.
///   Relu à l'ouverture, jamais pris d'un cache ; le nom, le tracé
///   (planificateur si l'aperçu n'a qu'une trace, ou un nouveau fichier — le
///   fichier passe devant), le départ. Rien ne change du tracé tant qu'on n'y
///   touche pas.
///
/// Le planificateur n'est proposé que si le domaine l'ouvre
/// (`ConfigDto.enableGpxPlanner`) ; un quota personnel épuisé le laisse en
/// vue, inactif, avec sa raison (`BILL-10`).
class GpxPreviewEditorPage extends ConsumerStatefulWidget {
  const GpxPreviewEditorPage({super.key, this.previewId});

  final String? previewId;

  @override
  ConsumerState<GpxPreviewEditorPage> createState() =>
      _GpxPreviewEditorPageState();
}

class _GpxPreviewEditorPageState extends ConsumerState<GpxPreviewEditorPage> {
  /// L'aperçu relu à l'ouverture (modification) ; `null` à la création.
  late final Future<GpxPreviewDto?> _opening = widget.previewId == null
      ? Future<GpxPreviewDto?>.value()
      : ref.read(gpxPreviewRepositoryProvider).get(widget.previewId!);

  GpxPreviewDto? _preview;
  bool _ready = false;

  final TextEditingController _name = TextEditingController();
  final TextEditingController _speed = TextEditingController();
  PreviewDeparture _initialDeparture = const PreviewDeparture();
  PreviewDeparture _departure = const PreviewDeparture();

  PlannerBridge? _planner;
  PlannerResult? _drawn;
  GpxFile? _gpx;
  GpxRefused? _refused;

  bool _reading = false;
  bool _saving = false;
  bool _saved = false;
  bool _showErrors = false;
  String? _error;

  bool get _creating => widget.previewId == null;

  @override
  void initState() {
    super.initState();
    _name.addListener(_onNameChanged);
    _opening.then(
      (GpxPreviewDto? preview) {
        if (!mounted) return;
        setState(() {
          _preview = preview;
          _ready = true;
          if (preview != null) {
            _name.text = preview.name;
            _initialDeparture = PreviewDeparture.of(preview);
            _departure = _initialDeparture;
          }
          _speed.text = _speedText(_departure.averageSpeed);
        });
      },
      onError: (Object error, StackTrace stack) {
        if (mounted) {
          setState(() {
            _ready = true;
            _error = getErrorMessage(error, stack);
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _planner?.dispose();
    _name.dispose();
    _speed.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    if (_showErrors) setState(() {});
  }

  UnitSystem get _units => ref.read(unitSystemProvider);

  /// La vitesse affichée dans l'unité de la personne ; l'état reste en km/h
  /// et n'est réécrit que si le champ est touché (un aller-retour par les
  /// miles ne passe pas pour une modification).
  String _speedText(double? kmh) => kmh == null
      ? ''
      : AppFormatters.formatNumber(_units.speed(kmh), fractionDigits: 0);

  void _onSpeedChanged(String text) {
    final String cleaned = text.trim().replaceAll(',', '.');
    final double? displayed = cleaned.isEmpty ? null : double.tryParse(cleaned);
    setState(() {
      _departure = _departure.copyWith(
        averageSpeed: () => displayed == null
            ? null
            : _units.speedToKilometersPerHour(displayed),
      );
    });
  }

  bool get _speedFieldValid {
    final String text = _speed.text.trim();
    if (text.isEmpty) return true;
    return double.tryParse(text.replaceAll(',', '.')) != null &&
        averageSpeedValid(_departure.averageSpeed);
  }

  bool get _plannerEnabled =>
      ref.watch(appConfigProvider).value?.enableGpxPlanner ?? false;

  bool get _plannerBusy => _planner?.busy.value ?? false;

  bool get _dirty =>
      !_saved &&
      (_gpx != null ||
          _drawn != null ||
          (_planner?.dirty.value ?? false) ||
          _name.text != (_preview?.name ?? '') ||
          _departure != _initialDeparture);

  // ── Planificateur ──────────────────────────────────────────────────────

  PlannerBridge _createPlanner() {
    final GpxPreviewDto? preview = _preview;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final PlannerBridge bridge = PlannerBridge(
      dio: ref.read(dioProvider),
      picker: () => ref.read(gpxFilePickerProvider),
      location: ref.read(locationServiceProvider),
      webViewFactory: ref.read(plannerWebViewFactoryProvider),
      load: () async => buildPlannerLoad(
        team: null,
        route: preview == null
            ? null
            : (
                line: preview.tracks.single.line.coordinates,
                ascend: preview.elevationGain,
                waypoints: preview.waypoints,
                distance: preview.distance,
              ),
        routeName: _name.text,
        config: await ref.read(appConfigProvider.future),
        dio: ref.read(baseDioProvider),
        apiBaseUrl: AppConfig.apiBaseUrl,
        readState: () =>
            ref.read(gpxPreviewRepositoryProvider).plannerState(preview!.id),
        dark: dark,
        locale: getCurrentLocale(),
        units: ref.read(unitSystemProvider),
      ),
      onDone: _onPlannerDone,
      onQuotaRefused: _onQuotaRefused,
    );
    for (final Listenable state in <Listenable>[
      bridge.busy,
      bridge.dirty,
      bridge.unvalidated,
      bridge.stateReadFailed,
    ]) {
      state.addListener(_onPlannerChanged);
    }
    return bridge;
  }

  void _onPlannerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _openPlanner() async {
    if (_saving || _reading) return;
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    await openRoutePlanner(context, _planner ??= _createPlanner());
  }

  void _onPlannerDone(PlannerResult result) {
    if (!mounted) return;
    // Le nom du fichier importé ne remplit qu'un nom vide.
    final String? suggestion = result.nameSuggestion;
    if (suggestion != null && _name.text.trim().isEmpty) {
      _name.text = cappedPreviewName(suggestion);
    }
    setState(() {
      _drawn = result.isEmpty ? null : result;
      if (result.hasTrack) {
        _gpx = null;
        _refused = null;
      }
    });
  }

  /// Un refus du quota personnel : la personne est relue, sa feuille s'ouvre,
  /// rien n'est perdu.
  Future<void> _onQuotaRefused(PlannerQuotaRefusal refusal) async {
    if (!mounted) return;
    await refreshPlannerQuota(ref);
    if (!mounted) return;
    await showPlannerQuotaSheet(context, refusal);
  }

  // ── Fichier ────────────────────────────────────────────────────────────

  Future<void> _pickGpx() async {
    if (_reading || _saving) return;
    final GpxFile? picked;
    try {
      picked = await ref.read(gpxFilePickerProvider).pick();
    } on PlatformException catch (error, stackTrace) {
      if (mounted) setState(() => _error = getErrorMessage(error, stackTrace));
      return;
    }
    if (picked == null || !mounted) return;
    setState(() {
      _reading = true;
      _error = null;
    });
    final GpxCheck check = await inspectGpxFile(picked);
    if (!mounted) return;
    setState(() {
      _reading = false;
      switch (check) {
        case final GpxRefused refused:
          _refused = refused;
        case GpxAccepted(:final GpxFile file):
          _gpx = file;
          _refused = null;
      }
    });
  }

  // ── Départ ─────────────────────────────────────────────────────────────

  /// Le fuseau où l'heure se lit : celui du départ du tracé s'il est connu
  /// (après un premier enregistrement daté), sinon celui de la personne —
  /// une heure murale, rien n'est converti.
  String? get _zone => _preview?.departureTimezone;

  DateTime get _wall =>
      parseWallTime(_departure.departure) ??
      () {
        final DateTime now = AppFormatters.toZoneTime(
          DateTime.now().toUtc(),
          _zone,
        );
        return DateTime(now.year, now.month, now.day, 9);
      }();

  /// La borne de la purge : un départ plus lointain partirait avec l'aperçu.
  DateTime get _lastDay {
    final DateTime from =
        DateTime.tryParse(_preview?.createdAt ?? '') ?? DateTime.now().toUtc();
    final DateTime wall = AppFormatters.toZoneTime(from, _zone);
    return DateTime(
      wall.year,
      wall.month,
      wall.day,
    ).add(const Duration(days: kPreviewRetentionDays));
  }

  Future<void> _editDeparture() async {
    final DateTime wall = _wall;
    final DateTime last = _lastDay;
    final DateTime initial = wall.isAfter(last) ? last : wall;
    final DateTime? day = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 1),
      lastDate: last,
    );
    if (day == null || !mounted) return;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(wall),
    );
    if (time == null || !mounted) return;
    setState(() {
      _departure = _departure.copyWith(
        departure: () => wallTimeOf(
          DateTime(day.year, day.month, day.day, time.hour, time.minute),
        ),
      );
    });
  }

  void _clearDeparture() =>
      setState(() => _departure = _departure.copyWith(departure: () => null));

  // ── Enregistrer ────────────────────────────────────────────────────────

  Future<bool> _confirmDiscard() => confirmDestructive(
    context,
    title: 'gpxTools.edit.discardTitle'.tr(),
    message: 'gpxTools.edit.discardMessage'.tr(),
    confirmLabel: 'rides.editor.discardConfirm'.tr(),
  );

  Future<void> _save() async {
    if (_saving || _reading || _plannerBusy) return;
    final PlannerResult? drawn = _gpx == null ? _drawn : null;
    final GpxFile? gpx =
        _gpx ?? (drawn != null && drawn.file ? _planner?.fileFor(drawn) : null);
    if (_creating && gpx == null && !(drawn?.hasTrack ?? false)) {
      setState(() => _error = 'gpxTools.edit.pointsRequired'.tr());
      return;
    }
    FocusScope.of(context).unfocus();
    if (!gpxPreviewNameValid(_name.text) || !_speedFieldValid) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final GpxPreviewRepository repository = ref.read(
      gpxPreviewRepositoryProvider,
    );
    final String name = _name.text.trim();
    final PreviewDepartureChange change = previewDepartureChange(
      _initialDeparture,
      _departure,
    );
    // Un tracé dessiné compte dans le quota personnel, pas un fichier.
    final bool drawnSave =
        gpx == null && (drawn?.plannerState != null || drawn?.points != null);
    try {
      final GpxPreviewDto? preview = _preview;
      final GpxPreviewDto saved;
      bool renamed = true;
      if (preview == null && gpx != null) {
        final GpxPreviewDto created = await repository.createFromFile(
          gpx,
          departure: change.departure,
          averageSpeed: change.averageSpeed,
        );
        // L'envoi nomme l'aperçu d'après le fichier : le nom saisi gagne, et
        // les points du parcours retouchés suivent (l'envoi n'en prend pas).
        if (name != created.name || drawn?.waypoints != null) {
          try {
            await repository.update(
              created.id,
              GpxPreviewUpdateRequest(name: name, waypoints: drawn?.waypoints),
            );
          } catch (_) {
            renamed = false;
          }
        }
        saved = created;
      } else if (preview == null) {
        saved = await repository.createFromPoints(
          GpxPreviewFromPointsRequest(
            name: name,
            points: drawn!.points,
            plannerState: drawn.plannerState,
            waypoints: drawn.waypoints,
            departure: change.departure,
            averageSpeed: change.averageSpeed,
          ),
        );
      } else {
        saved = await repository.update(
          preview.id,
          GpxPreviewUpdateRequest(
            name: name,
            points: drawn?.points,
            plannerState: drawn?.plannerState,
            waypoints: drawn?.waypoints,
            departure: change.departure,
            clearDeparture: change.clearDeparture ? true : null,
            averageSpeed: change.averageSpeed,
            clearAverageSpeed: change.clearAverageSpeed ? true : null,
          ),
          gpx: gpx,
        );
      }
      if (!mounted) return;
      _saved = true;
      notifyGpxPreviewChanged(ref, previewId: saved.id);
      if (drawnSave) await refreshPlannerQuota(ref);
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            (drawn?.tooLarge ?? false)
                ? 'routes.planner.stateTooLarge'.tr()
                : !renamed
                ? 'gpxTools.createFromScratch.renameFailed'.tr()
                : _creating
                ? 'gpxTools.createFromScratch.created'.tr()
                : 'gpxTools.edit.updated'.tr(),
          ),
        ),
      );
      final GoRouter router = GoRouter.of(context);
      if (_creating) {
        router.pushReplacement(Paths.gpxToolsView(saved.id));
      } else if (router.canPop()) {
        router.pop();
      } else {
        router.go(Paths.gpxToolsView(saved.id));
      }
    } catch (error, stackTrace) {
      if (!mounted) return;
      final PlannerQuotaRefusal? quota = plannerQuotaRefusalOf(error);
      if (quota != null) {
        setState(() => _saving = false);
        await _onQuotaRefused(quota);
        return;
      }
      final GpxRefusal? refusal = gpxRefusalOfApiCode(
        resolveApiError(error, stackTrace).code,
      );
      setState(() {
        _saving = false;
        if (refusal != null && gpx != null) {
          _refused = GpxRefused(gpx.name, refusal);
          if (drawn?.file ?? false) _drawn = null;
          _gpx = null;
        } else {
          _error = getErrorMessage(error, stackTrace);
        }
      });
    }
  }

  // ── Écran ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final String title = _creating
        ? 'gpxTools.createFromScratch.title'.tr()
        : 'gpxTools.edit.title'.tr();
    Widget shell({List<Widget>? slivers, Widget? body, Widget? action}) =>
        PdlScreenScaffold(
          appBar: PdlAppBar(
            title: title,
            onBack: () => Navigator.of(context).maybePop(),
            backSemanticLabel: 'common.back'.tr(),
          ),
          actionBar: action,
          slivers: slivers,
          body: body,
        );

    if (!_ready) {
      return shell(body: const Center(child: CircularProgressIndicator()));
    }
    final GpxPreviewDto? preview = _preview;
    if (!_creating && preview == null) {
      return shell(
        body: PdlEmptyState(
          variant: PdlEmptyVariant.error,
          icon: PdlIcons.gpx,
          title: 'gpxTools.preview.loadErrorTitle'.tr(),
          message: _error,
          actions: <Widget>[
            PdlButton(
              label: 'common.back'.tr(),
              variant: PdlButtonVariant.outline,
              onPressed: () => context.pop(),
            ),
          ],
        ),
      );
    }
    if (preview != null && !preview.owned) {
      return shell(
        body: PdlEmptyState(
          key: keys.gpxTools.editorError,
          variant: PdlEmptyVariant.empty,
          icon: PdlIcons.edit,
          title: 'gpxTools.edit.notOwner'.tr(),
          actions: <Widget>[
            PdlButton(
              label: 'common.back'.tr(),
              variant: PdlButtonVariant.outline,
              onPressed: () => context.pop(),
            ),
          ],
        ),
      );
    }

    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final bool busy = _saving || _reading;
    final bool plannerOpen =
        _plannerEnabled && (preview == null || preview.tracks.length == 1);
    final PlannerQuotaRefusal? quotaSpent = _quotaSpent(plannerOpen);

    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (bool didPop, Object? _) async {
        if (didPop) return;
        final NavigatorState navigator = Navigator.of(context);
        if (await _confirmDiscard()) {
          _saved = true;
          navigator.pop();
        }
      },
      child: shell(
        action: PdlActionBar(
          children: <Widget>[
            PdlButton(
              key: keys.gpxTools.editorSave,
              label: 'routes.editor.save'.tr(),
              loading: _saving,
              loadingLabel: 'routes.editor.saving'.tr(),
              enabled: !_reading && !_plannerBusy,
              onPressed: _save,
            ),
          ],
        ),
        slivers: <Widget>[
          SliverPadding(
            key: keys.gpxTools.editor,
            padding: const EdgeInsets.fromLTRB(
              PdlSpacing.section,
              PdlSpacing.section,
              PdlSpacing.section,
              PdlSpacing.section * 2,
            ),
            sliver: SliverList.list(
              children: <Widget>[
                if (_error != null) ...<Widget>[
                  PdlBanner(
                    key: keys.gpxTools.editorError,
                    tone: PdlBannerTone.danger,
                    icon: PdlIcons.error,
                    message: _error!,
                    onDismiss: () => setState(() => _error = null),
                    dismissSemanticLabel: 'common.close'.tr(),
                  ),
                  const SizedBox(height: PdlSpacing.section),
                ],
                if (_creating) ...<Widget>[
                  Text(
                    'gpxTools.createFromScratch.subtitle'.tr(),
                    style: t.sub.copyWith(color: c.textDimmed),
                  ),
                  const SizedBox(height: PdlSpacing.section),
                ],

                // ── Tracé ── La section de l'éditeur de parcours : à la
                // création le planificateur (un fichier s'y importe), en
                // modification le tracé actuel, « Modifier le tracé » et
                // « Remplacer le GPX ».
                RouteTrackSection(
                  current: preview == null
                      ? null
                      : (
                          name: preview.name,
                          distance: preview.distance,
                          elevationGain: preview.elevationGain,
                          thumbnailLight: preview.thumbnailUrl,
                          thumbnailDark: null,
                        ),
                  picked: _gpx,
                  refused: _refused,
                  busy: busy,
                  onPick: _pickGpx,
                  onCancelReplace: _gpx == null
                      ? null
                      : () => setState(() {
                          _gpx = null;
                          _refused = null;
                        }),
                  onDraw: plannerOpen ? _openPlanner : null,
                  quotaSpent: quotaSpent,
                  drawn: _drawn,
                  unvalidated: _planner?.unvalidated.value ?? false,
                  plannerWarning: (_planner?.stateReadFailed.value ?? false)
                      ? 'routes.planner.stateReadFailed'.tr()
                      : null,
                ),

                // ── Nom ──
                TextField(
                  key: keys.gpxTools.editorName,
                  controller: _name,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: <TextInputFormatter>[
                    LengthLimitingTextInputFormatter(kGpxPreviewNameMax),
                  ],
                  style: t.bodyStrong,
                  decoration: InputDecoration(
                    labelText: 'gpxTools.edit.nameLabel'.tr(),
                    errorText: _showErrors && !gpxPreviewNameValid(_name.text)
                        ? 'gpxTools.edit.nameTooShort'.tr()
                        : null,
                  ),
                ),
                const SizedBox(height: PdlSpacing.section),

                // ── Départ ──
                EditorSection(
                  title: 'gpxTools.departure.title'.tr(),
                  hint: 'gpxTools.departure.hint'.tr(),
                  child: _departureFields(busy),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Le quota personnel épuisé ferme le planificateur — mais pas celui déjà
  /// ouvert, où le tracé vit et son refus se lit.
  PlannerQuotaRefusal? _quotaSpent(bool plannerOpen) {
    if (!plannerOpen || _planner != null) return null;
    final PlannerQuotaDto? quota = ref.watch(
      authProvider.select((AuthState s) => s.user?.plannerQuota),
    );
    final bool platformAdmin = ref.watch(
      authProvider.select(
        (AuthState s) => s.user?.platformRole == 'PLATFORM_ADMIN',
      ),
    );
    if (!isPlannerQuotaSpent(quota, platformAdmin: platformAdmin)) return null;
    return PlannerQuotaRefusal(
      team: false,
      limit: quota!.limit!,
      resetsOn: quota.resetsOn,
    );
  }

  Widget _departureFields(bool busy) {
    final UnitSystem units = ref.watch(unitSystemProvider);
    final DateTime? wall = parseWallTime(_departure.departure);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        PdlSettingRow(
          key: keys.gpxTools.editorDeparture,
          padding: EdgeInsets.zero,
          icon: PdlIcons.date,
          title: 'gpxTools.departure.label'.tr(),
          subtitle: wall == null
              ? 'gpxTools.departure.pick'.tr()
              : '${AppFormatters.formatLongDate(wall)} · '
                    '${AppFormatters.formatTime(wall)}',
          onTap: busy ? null : _editDeparture,
        ),
        if (wall != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: PdlButton(
              key: keys.gpxTools.editorClearDeparture,
              label: 'gpxTools.departure.clear'.tr(),
              variant: PdlButtonVariant.text,
              size: PdlButtonSize.sm,
              enabled: !busy,
              onPressed: _clearDeparture,
            ),
          ),
        const SizedBox(height: PdlSpacing.chipGap),
        TextField(
          key: keys.gpxTools.editorSpeed,
          controller: _speed,
          enabled: !busy,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: _onSpeedChanged,
          decoration: InputDecoration(
            labelText: 'gpxTools.departure.speedLabel'.tr(),
            suffixText: units.speedSymbol,
            helperText: 'gpxTools.departure.speedHint'.tr(),
            helperMaxLines: 3,
            errorText: _showErrors && !_speedFieldValid
                ? 'gpxTools.departure.invalidSpeed'.tr(
                    namedArgs: <String, String>{
                      'min': AppFormatters.formatNumber(
                        units.speed(kMinAverageSpeedKmh).ceilToDouble(),
                        fractionDigits: 0,
                      ),
                      'max': AppFormatters.formatNumber(
                        units.speed(kMaxAverageSpeedKmh).floorToDouble(),
                        fractionDigits: 0,
                      ),
                    },
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
