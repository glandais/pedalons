import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/material.dart' hide Visibility;
import '../../../../core/pdl/pdl.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/zone_mention_line.dart';
import '../../../../keys.dart';
import '../../../profile/presentation/widgets/confirm_sheet.dart';
import '../../../rides/data/ride_editor_repository.dart';
import '../../../rides/domain/ride_form.dart';
import '../../../rides/presentation/widgets/editor/editor_media_actions.dart';
import '../../../rides/presentation/widgets/editor/editor_section.dart';
import '../../../rides/presentation/widgets/editor/rich_markdown_editor_field.dart';
import '../../../rides/presentation/widgets/editor/ride_group_editor.dart';
import '../../../rides/presentation/widgets/editor/ride_media_section.dart';
import '../../../rides/presentation/widgets/editor/search_picker_sheet.dart';
import '../../../rides/presentation/widgets/editor/slug_edit_sheet.dart';
import '../../../rides/providers/ride_editor_providers.dart';
import '../../../routes/providers/route_changes.dart';
import '../../../routes/providers/route_detail_provider.dart';
import '../../../tags/presentation/tag_filter.dart';
import '../../../tags/providers/team_tags_provider.dart';
import '../../../teams/providers/team_providers.dart';
import '../../../visibility/domain/content_visibility.dart';
import '../../../visibility/domain/incompatible_visibility.dart';
import '../../../visibility/presentation/visibility_field.dart';
import '../../../visibility/presentation/visibility_refusal.dart';
import '../../data/trip_repository.dart';
import '../../domain/trip_form.dart';
import '../../providers/trip_detail_provider.dart';
import '../../providers/trip_editor_providers.dart';
import '../widgets/editor/trip_stage_editor.dart';

/// Créer ([tripSlug] nul) ou modifier un voyage — le pendant mobile de
/// `CreateTripPage` / `EditTripPage` du site, au même contrat, sur le modèle
/// de l'éditeur de sortie (docs/LEDGER_*.md MOB-162).
///
/// La création est ouverte aux organisateurs et administrateurs de l'équipe
/// (et à l'admin de plateforme), modules voyages **et** parcours actifs : la
/// règle de `TripAccessChecker`. La modification lit `permissions.canEdit` du
/// voyage. Quelqu'un d'autre arrivé ici par un lien lit un refus plutôt qu'un
/// formulaire qui finirait en 403.
class TripEditorPage extends ConsumerWidget {
  const TripEditorPage({super.key, required this.teamSlug, this.tripSlug});

  final String teamSlug;
  final String? tripSlug;

  bool get _isEdit => tripSlug != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TeamDetailDto> team = ref.watch(
      teamDetailProvider(teamSlug),
    );
    final TripKey? tripKey = _isEdit
        ? TripKey(teamSlug: teamSlug, tripSlug: tripSlug!)
        : null;
    final AsyncValue<TripDto>? trip = tripKey == null
        ? null
        : ref.watch(tripDetailProvider(tripKey));
    // La modification lit le droit que le backend calcule pour **ce** voyage ;
    // la création, qui n'a pas d'entité, garde la règle de rôle
    // (docs/LEDGER_*.md MOB-137).
    final bool? canManage = _isEdit
        ? trip?.value?.permissions.canEdit
        : ref.watch(canManageTripsProvider(teamSlug));

    final String title = _isEdit
        ? 'trips.editor.editTitle'.tr()
        : 'trips.editor.createTitle'.tr();

    Widget shell(Widget body) => PdlScreenScaffold(
      appBar: PdlAppBar(
        title: title,
        onBack: () => context.pop(),
        backSemanticLabel: 'common.back'.tr(),
      ),
      body: body,
    );

    final Object? error = team.error ?? trip?.error;
    if (error != null) {
      return shell(
        PdlEmptyState(
          key: keys.tripEditor.loadError,
          variant: PdlEmptyVariant.error,
          title: 'common.loadError'.tr(),
          message: getErrorMessage(error),
          actions: <Widget>[
            PdlButton(
              label: 'common.retry'.tr(),
              onPressed: () {
                ref.invalidate(teamDetailProvider(teamSlug));
                if (tripKey != null) {
                  ref.invalidate(tripDetailProvider(tripKey));
                }
              },
            ),
          ],
        ),
      );
    }

    final TeamDetailDto? teamValue = team.value;
    final TripDto? tripValue = trip?.value;
    if (teamValue == null ||
        (_isEdit && tripValue == null) ||
        canManage == null) {
      return shell(const Center(child: CircularProgressIndicator.adaptive()));
    }

    final bool modulesOn = teamValue.enableTrips && teamValue.enableRoutes;
    if (!canManage || !modulesOn) {
      return shell(
        PdlEmptyState(
          key: keys.tripEditor.forbidden,
          variant: PdlEmptyVariant.empty,
          icon: PdlIcons.admin,
          title: 'rides.editor.forbiddenTitle'.tr(),
          // Le module coupé d'abord : la règle de rôle le compte déjà, et
          // dire « réservé au rôle Organisateur » à qui l'a serait faux.
          message: modulesOn
              ? 'trips.editor.forbiddenMessage'.tr()
              : 'trips.editor.modulesOffMessage'.tr(),
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

    return _TripEditorForm(
      // Un voyage rechargé sous l'écran (slug changé, autre appareil) ne
      // réécrit pas un formulaire en cours : la clé ne suit que son id.
      key: ValueKey<String>(tripValue?.id ?? 'new-$teamSlug'),
      team: teamValue,
      trip: tripValue,
      title: title,
    );
  }
}

class _TripEditorForm extends ConsumerStatefulWidget {
  const _TripEditorForm({
    super.key,
    required this.team,
    required this.trip,
    required this.title,
  });

  final TeamDetailDto team;
  final TripDto? trip;
  final String title;

  @override
  ConsumerState<_TripEditorForm> createState() => _TripEditorFormState();
}

class _TripEditorFormState extends ConsumerState<_TripEditorForm>
    with EditorMediaActions<_TripEditorForm> {
  late TripForm _form;
  late final TripForm _initial;
  late String _initialJson;

  late final TextEditingController _name;
  late final TextEditingController _markdown;

  /// Une clé locale par étape, stable au réordonnancement : c'est elle qui
  /// garde chaque carte (et ses champs) attachée à son étape.
  final List<int> _stageUids = <int>[];
  int _nextUid = 0;

  /// Les noms des parcours et des lieux choisis dans une feuille : affichés
  /// tout de suite, le temps que leur détail se charge.
  final Map<String, String> _pickedNames = <String, String>{};

  /// Le dernier fuseau résolu, gardé pendant qu'un nouveau se calcule.
  late String _lastZone;

  bool _uploading = false;
  bool _saving = false;
  bool _saved = false;
  bool _showErrors = false;
  String? _error;

  TripDto? get _trip => widget.trip;
  String get _teamSlug => widget.team.slug;
  RideEditorRepository get _repo => ref.read(rideEditorRepositoryProvider);

  @override
  void initState() {
    super.initState();
    final TripDto? trip = _trip;
    _initial = trip == null
        ? TripForm.initial(widget.team, firstStageName: _defaultStageName(1))
        : TripForm.fromTrip(trip);
    _form = _initial;
    _initialJson = _json(_initial);
    _name = TextEditingController(text: _form.name)
      ..addListener(() => _update(_form.copyWith(name: _name.text)));
    _markdown = TextEditingController(text: _form.media.markdown)
      ..addListener(
        () => _update(
          _form.copyWith(media: _form.media.copyWith(markdown: _markdown.text)),
        ),
      );
    for (int i = 0; i < _form.stages.length; i++) {
      _stageUids.add(_nextUid++);
    }
    if (trip != null) {
      for (final TripStageDto s in trip.stages) {
        final PlaceDetailDto? start = s.startPlace;
        final PlaceDetailDto? end = s.endPlace;
        final RouteDto? route = s.route;
        if (start != null) _pickedNames[start.id] = start.name;
        if (end != null) _pickedNames[end.id] = end.name;
        if (route != null) _pickedNames[route.slug] = route.name;
      }
    }
    _lastZone = trip?.timezone ?? widget.team.timezone;
  }

  @override
  void dispose() {
    _name.dispose();
    _markdown.dispose();
    super.dispose();
  }

  static String _json(TripForm form) => jsonEncode(form.toRequest().toJson());

  static String _defaultStageName(int number) => 'trips.editor.stageDefaultName'
      .tr(namedArgs: <String, String>{'number': '$number'});

  bool get _dirty => !_saved && _json(_form) != _initialJson;

  void _update(TripForm next) {
    if (identical(next, _form)) return;
    setState(() => _form = next);
  }

  // ── Fuseau du voyage ───────────────────────────────────────────────────
  //
  // Celui de sa première étape — son lieu de départ, sinon le départ de son
  // parcours —, sinon le départ du parcours d'ensemble, sinon l'équipe
  // (ledger `API-60`). Un voyage modifié dont rien de cela n'a bougé garde le
  // fuseau que le serveur lui a donné, sans appel. Il ne sert qu'à la mention
  // « heure de … » et à juger la publication programmée : les dates partent
  // en heures murales, que le serveur lit dans le fuseau qu'il résout.

  String _zone() {
    final TripDto? trip = _trip;
    final TripStageForm? first = _form.stages.firstOrNull;
    final TripStageForm? initialFirst = _initial.stages.firstOrNull;
    if (trip != null &&
        first?.startPlaceId == initialFirst?.startPlaceId &&
        first?.routeSlug == initialFirst?.routeSlug &&
        _form.routeSlug == _initial.routeSlug) {
      return _lastZone = trip.timezone;
    }
    bool pending = false;

    String? fromPoint(GeoJsonPoint? point) {
      if (point == null || point.coordinates.length < 2) return null;
      final AsyncValue<String> zone = ref.watch(
        editorTimezoneProvider(timezoneKey(_teamSlug, point)),
      );
      if (zone.isLoading) pending = true;
      return zone.value;
    }

    String? fromRoute(String? slug) {
      if (pending || slug == null) return null;
      final AsyncValue<RouteDetailDto> route = ref.watch(
        editorRouteProvider((teamSlug: _teamSlug, id: slug)),
      );
      if (route.isLoading) pending = true;
      return fromPoint(route.value?.start);
    }

    final String? placeId = first?.startPlaceId;
    if (placeId != null) {
      final AsyncValue<PlaceDetailDto> place = ref.watch(
        editorPlaceProvider((teamSlug: _teamSlug, id: placeId)),
      );
      if (place.isLoading) pending = true;
      final String? zone = fromPoint(place.value?.geometry);
      if (zone != null) return _lastZone = zone;
    }
    final String? zone =
        fromRoute(first?.routeSlug) ?? fromRoute(_form.routeSlug);
    if (zone != null) return _lastZone = zone;
    if (pending) return _lastZone;
    return _lastZone = widget.team.timezone;
  }

  // ── Dates ──────────────────────────────────────────────────────────────

  DateTime _wallOf(String wall) =>
      parseWallTime(wall) ??
      parseWallTime(
        nextWeekdayWallTime(
          kDefaultTripWeekday,
          kDefaultTripHour,
          widget.team.timezone,
        ),
      )!;

  Future<DateTime?> _pickDate(DateTime initial) {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 1),
      lastDate: DateTime(initial.year + 5),
    );
  }

  Future<TimeOfDay?> _pickTime(TimeOfDay initial) {
    return showTimePicker(context: context, initialTime: initial);
  }

  /// La date de [current] remplacée par un jour choisi, l'heure gardée.
  Future<String?> _changeDay(String current) async {
    final DateTime wall = _wallOf(current);
    final DateTime? day = await _pickDate(wall);
    if (day == null) return null;
    return wallTimeOf(
      DateTime(day.year, day.month, day.day, wall.hour, wall.minute),
    );
  }

  /// L'heure de [current] remplacée, le jour gardé.
  Future<String?> _changeTime(String current) async {
    final DateTime wall = _wallOf(current);
    final TimeOfDay? time = await _pickTime(TimeOfDay.fromDateTime(wall));
    if (time == null) return null;
    return wallTimeOf(
      DateTime(wall.year, wall.month, wall.day, time.hour, time.minute),
    );
  }

  Future<void> _editDate() async {
    final String? next = await _changeDay(_form.dateTime);
    if (next != null) _update(_form.copyWith(dateTime: next));
  }

  Future<void> _editTime() async {
    final String? next = await _changeTime(_form.dateTime);
    if (next != null) _update(_form.copyWith(dateTime: next));
  }

  Future<void> _editPublishAt() async {
    final DateTime start =
        parseWallTime(_form.publishAt) ??
        AppFormatters.toZoneTime(
          DateTime.now().toUtc(),
          _lastZone,
        ).add(const Duration(hours: 1));
    final DateTime? day = await _pickDate(start);
    if (day == null || !mounted) return;
    final TimeOfDay? time = await _pickTime(TimeOfDay.fromDateTime(start));
    if (time == null) return;
    _update(
      _form.copyWith(
        publishAt: () => wallTimeOf(
          DateTime(day.year, day.month, day.day, time.hour, time.minute),
        ),
      ),
    );
  }

  // ── Lieux, parcours, tags ──────────────────────────────────────────────

  Future<PlaceDetailDto?> _choosePlace({required bool start}) {
    return showSearchPickerSheet<PlaceDetailDto>(
      context,
      title: start
          ? 'rides.editor.startPlace'.tr()
          : 'rides.editor.endPlace'.tr(),
      searchHint: 'rides.editor.placeSearch'.tr(),
      emptyMessage: 'rides.editor.placeEmpty'.tr(),
      idOf: (PlaceDetailDto p) => p.id,
      load: (String? search, int page) async {
        final PlaceListResponse r = await _repo.searchPlaces(
          _teamSlug,
          start: start,
          search: search,
          page: page,
        );
        return (items: r.places, total: r.total);
      },
      itemBuilder: (BuildContext _, PlaceDetailDto p, VoidCallback onTap) =>
          PdlPlaceRow(
            kind: start ? PdlPlaceKind.start : PdlPlaceKind.end,
            name: p.name,
            address: p.address,
            onTap: onTap,
          ),
    );
  }

  Future<RouteDto?> _chooseRoute() {
    final UnitSystem units = ref.read(unitSystemProvider);
    return showSearchPickerSheet<RouteDto>(
      context,
      title: 'rides.editor.routePick'.tr(),
      searchHint: 'rides.editor.routeSearch'.tr(),
      emptyMessage: 'rides.editor.routeEmpty'.tr(),
      idOf: (RouteDto r) => r.slug,
      load: (String? search, int page) async {
        final RouteListResponse r = await _repo.searchRoutes(
          _teamSlug,
          search: search,
          page: page,
        );
        return (items: r.routes, total: r.total);
      },
      itemBuilder: (BuildContext _, RouteDto r, VoidCallback onTap) =>
          PdlSettingRow(
            icon: PdlIcons.route,
            title: r.name,
            subtitle: _routeStats(r.distance, r.elevationGain, units),
            onTap: onTap,
          ),
    );
  }

  static String _routeStats(double distance, double gain, UnitSystem units) =>
      '${AppFormatters.formatDistance(distance, units)} · '
      '${AppFormatters.formatElevationGain(gain, units)}';

  Future<void> _editTags(List<TagWithUsageDto> vocabulary) async {
    final List<String>? picked = await showTagPickerSheet(
      context,
      vocabulary: vocabulary,
      selected: _form.tagIds,
      title: 'trips.editor.tagsPickerTitle'.tr(),
      hint: 'rides.editor.tagsPickerHint'.tr(),
      maxSelected: kTripMaxTags,
    );
    if (picked == null) return;
    _update(_form.copyWith(tagIds: picked));
  }

  // ── Étapes ─────────────────────────────────────────────────────────────

  void _setStage(int index, TripStageForm stage) {
    final List<TripStageForm> stages = <TripStageForm>[..._form.stages];
    stages[index] = stage;
    _update(_form.copyWith(stages: stages));
  }

  void _addStage() {
    setState(() {
      _stageUids.add(_nextUid++);
      _form = _form.copyWith(
        stages: <TripStageForm>[
          ..._form.stages,
          TripStageForm(
            name: _defaultStageName(_form.stages.length + 1),
            dateTime: _form.nextStageDateTime(),
          ),
        ],
      );
    });
  }

  void _moveStage(int index, int delta) {
    final int to = index + delta;
    if (to < 0 || to >= _form.stages.length) return;
    setState(() {
      final List<TripStageForm> stages = <TripStageForm>[..._form.stages];
      final TripStageForm s = stages.removeAt(index);
      stages.insert(to, s);
      final int uid = _stageUids.removeAt(index);
      _stageUids.insert(to, uid);
      _form = _form.copyWith(stages: stages);
    });
  }

  Future<void> _removeStage(int index) async {
    // Une étape déjà enregistrée porte des commentaires que le serveur
    // supprimera avec elle : on le dit avant.
    if (_form.stages[index].id != null) {
      final bool ok = await confirmDestructive(
        context,
        title: 'trips.editor.stageRemoveTitle'.tr(),
        message: 'trips.editor.stageRemoveMessage'.tr(),
        confirmLabel: 'trips.editor.stageRemoveConfirm'.tr(),
      );
      if (!ok || !mounted) return;
    }
    setState(() {
      _stageUids.removeAt(index);
      _form = _form.copyWith(
        stages: <TripStageForm>[..._form.stages]..removeAt(index),
      );
    });
  }

  Future<void> _editStageDate(int index) async {
    final String? next = await _changeDay(_form.stages[index].dateTime);
    if (next == null || !mounted) return;
    _setStage(index, _form.stages[index].copyWith(dateTime: next));
  }

  Future<void> _editStageTime(int index) async {
    final String? next = await _changeTime(_form.stages[index].dateTime);
    if (next == null || !mounted) return;
    _setStage(index, _form.stages[index].copyWith(dateTime: next));
  }

  Future<void> _editStagePlace(int index, {required bool start}) async {
    final PlaceDetailDto? place = await _choosePlace(start: start);
    if (place == null || !mounted) return;
    _pickedNames[place.id] = place.name;
    final TripStageForm stage = _form.stages[index];
    _setStage(
      index,
      start
          ? stage.copyWith(startPlaceId: () => place.id)
          : stage.copyWith(endPlaceId: () => place.id),
    );
  }

  Future<void> _editStageRoute(int index) async {
    final RouteDto? route = await _chooseRoute();
    if (route == null || !mounted) return;
    _pickedNames[route.slug] = route.name;
    _setStage(index, _form.stages[index].copyWith(routeSlug: () => route.slug));
  }

  // ── Médias ─────────────────────────────────────────────────────────────
  //
  // Les gestes sont ceux de [EditorMediaActions] ; l'écran dit où vivent le
  // formulaire et le texte. Ils portent sur le voyage, pas sur ses étapes.

  @override
  String get mediaTeamSlug => _teamSlug;

  @override
  MediaDto get editedMedia => _form.media;

  @override
  void applyMedia(MediaDto media) => _update(_form.copyWith(media: media));

  @override
  TextEditingController get markdownController => _markdown;

  @override
  void setMediaUploading(bool uploading) => setState(() {
    _uploading = uploading;
    if (uploading) _error = null;
  });

  @override
  void showMediaError(String message) => setState(() => _error = message);

  // ── Adresse (slug) ─────────────────────────────────────────────────────

  Future<void> _editSlug() async {
    final TripDto trip = _trip!;
    if (_dirty && !await _confirmDiscard()) return;
    if (!mounted) return;
    final String? slug = await showSlugEditSheet(context, trip.slug);
    if (slug == null || slug == trip.slug || !mounted) return;
    try {
      final TripDto updated = await ref
          .read(tripRepositoryProvider)
          .changeSlug(_teamSlug, trip.slug, slug);
      if (!mounted) return;
      notifyTripChanged(
        ref,
        teamSlug: _teamSlug,
        tripKey: TripKey(teamSlug: _teamSlug, tripSlug: trip.slug),
      );
      _saved = true;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text('rides.editor.slugSaved'.tr())));
      // L'ancienne adresse ne mène plus nulle part : la pile repart de la
      // nouvelle, détail dessous.
      context.go(Paths.tripEdit(_teamSlug, updated.slug));
    } catch (error, stackTrace) {
      if (mounted) setState(() => _error = getErrorMessage(error, stackTrace));
    }
  }

  // ── Enregistrer ────────────────────────────────────────────────────────

  Future<bool> _confirmDiscard() => confirmDestructive(
    context,
    title: 'rides.editor.discardTitle'.tr(),
    message: 'rides.editor.discardMessage'.tr(),
    confirmLabel: 'rides.editor.discardConfirm'.tr(),
  );

  Future<void> _save(String zone) async {
    if (_saving || _uploading) return;
    FocusScope.of(context).unfocus();
    if (!_form.isValid(zone)) {
      setState(() {
        _showErrors = true;
        _error = 'rides.editor.invalid'.tr();
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    await _send(_form.toRequest());
  }

  /// Envoie [request] ; sur un refus `INCOMPATIBLE_VISIBILITY` (un voyage
  /// visible hors de l'équipe dont des parcours sont « Équipe », décision
  /// D5), demande s'il faut ouvrir ces parcours, puis rejoue **la même**
  /// requête avec `alignVisibility` (docs/LEDGER_*.md MOB-137).
  Future<void> _send(
    TripRequest request, {
    List<IncompatibleRouteDto> aligned = const <IncompatibleRouteDto>[],
  }) async {
    final TripRepository trips = ref.read(tripRepositoryProvider);
    final TripDto? trip = _trip;
    try {
      final TripDto saved = trip == null
          ? await trips.createTrip(_teamSlug, request)
          : await trips.updateTrip(_teamSlug, trip.slug, request);
      if (!mounted) return;
      notifyTripChanged(
        ref,
        teamSlug: _teamSlug,
        tripKey: TripKey(teamSlug: _teamSlug, tripSlug: saved.slug),
      );
      // Les parcours ouverts par l'alignement ont changé de visibilité.
      for (final IncompatibleRouteDto route in aligned) {
        notifyRouteChanged(
          ref,
          teamSlug: _teamSlug,
          routeKey: RouteKey(teamSlug: _teamSlug, routeSlug: route.slug),
        );
      }
      _saved = true;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            trip == null
                ? 'trips.editor.created'.tr()
                : 'trips.editor.saved'.tr(),
          ),
        ),
      );
      final GoRouter router = GoRouter.of(context);
      if (trip == null) {
        // La création laisse place à l'écran du voyage créé.
        router.pushReplacement(Paths.trip(_teamSlug, saved.slug));
      } else if (router.canPop()) {
        router.pop();
      } else {
        router.go(Paths.trip(_teamSlug, saved.slug));
      }
    } catch (error, stackTrace) {
      if (!mounted) return;
      final IncompatibleVisibility? refusal = incompatibleVisibilityOf(error);
      if (refusal != null &&
          refusal.routes.isNotEmpty &&
          request.alignVisibility != true) {
        final bool align = await confirmVisibilityAlignment(
          context,
          kind: AlignedKind.trip,
          routes: refusal.routes,
        );
        if (!mounted) return;
        if (align) {
          await _send(
            request.copyWith(alignVisibility: true),
            aligned: refusal.routes,
          );
          return;
        }
        setState(() => _saving = false);
        return;
      }
      setState(() {
        _saving = false;
        _error = getErrorMessage(error, stackTrace);
      });
    }
  }

  // ── Écran ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final UnitSystem units = ref.watch(unitSystemProvider);
    final String zone = _zone();
    final DateTime wall = _wallOf(_form.dateTime);
    final DateTime instant = AppFormatters.zoneWallClockToUtc(wall, zone);

    final List<TagWithUsageDto> vocabulary =
        ref
            .watch(
              teamTagsProvider((teamSlug: _teamSlug, type: TagTarget.trip)),
            )
            .value ??
        const <TagWithUsageDto>[];

    final Map<String, RouteDetailDto> stageRoutes =
        ref
            .watch(
              editorGroupRoutesProvider((
                teamSlug: _teamSlug,
                slugs: groupRoutesKey(
                  _form.stages.map((TripStageForm s) => s.routeSlug),
                ),
              )),
            )
            .value ??
        const <String, RouteDetailDto>{};

    final String? routeSlug = _form.routeSlug;
    final RouteDetailDto? route = routeSlug == null
        ? null
        : ref
              .watch(editorRouteProvider((teamSlug: _teamSlug, id: routeSlug)))
              .value;

    final bool busy = _saving || _uploading;

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
      child: PdlScreenScaffold(
        appBar: PdlAppBar(
          title: widget.title,
          onBack: () => Navigator.of(context).maybePop(),
          backSemanticLabel: 'common.back'.tr(),
        ),
        actionBar: PdlActionBar(
          children: <Widget>[
            PdlButton(
              key: keys.tripEditor.saveButton,
              label: _trip == null
                  ? 'trips.editor.create'.tr()
                  : 'rides.editor.save'.tr(),
              loading: _saving,
              loadingLabel: 'rides.editor.saving'.tr(),
              enabled: !_uploading,
              onPressed: () => _save(zone),
            ),
          ],
        ),
        slivers: <Widget>[
          SliverPadding(
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
                    key: keys.tripEditor.errorBanner,
                    tone: PdlBannerTone.danger,
                    icon: PdlIcons.error,
                    message: _error!,
                    onDismiss: () => setState(() => _error = null),
                    dismissSemanticLabel: 'common.close'.tr(),
                  ),
                  const SizedBox(height: PdlSpacing.section),
                ],

                // ── Nom et adresse ──
                TextField(
                  key: keys.tripEditor.nameField,
                  controller: _name,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: <TextInputFormatter>[
                    LengthLimitingTextInputFormatter(kTripNameMaxLength),
                  ],
                  style: t.bodyStrong,
                  decoration: InputDecoration(
                    labelText: 'rides.editor.name'.tr(),
                    hintText: 'trips.editor.namePlaceholder'.tr(),
                    errorText: _showErrors && !_form.nameValid
                        ? 'trips.editor.nameError'.tr()
                        : null,
                  ),
                ),
                if (_trip != null)
                  PdlSettingRow(
                    key: keys.tripEditor.slugRow,
                    padding: EdgeInsets.zero,
                    icon: PdlIcons.link,
                    title: 'rides.editor.slug'.tr(),
                    subtitle: _trip!.slug,
                    onTap: busy ? null : _editSlug,
                  ),
                const SizedBox(height: PdlSpacing.section),

                // ── Description ──
                EditorSection(
                  title: 'rides.editor.description'.tr(),
                  child: RichMarkdownEditorField(
                    title: 'rides.editor.description'.tr(),
                    fieldKey: keys.tripEditor.markdownField,
                    controller: _markdown,
                    hintText: 'trips.editor.markdownPlaceholder'.tr(),
                    images: _form.media.assets.images,
                    enabled: !_saving,
                    imageBusy: _uploading,
                    onInsertImage: addImage,
                    errorText: _form.markdownValid
                        ? null
                        : 'rides.editor.markdownTooLong'.tr(),
                  ),
                ),
                EditorSection(
                  title: 'rides.editor.media'.tr(),
                  child: RideMediaSection(
                    assets: _form.media.assets,
                    busy: busy,
                    onPickLogo: pickLogo,
                    onRemoveLogo: removeLogo,
                    onAddImage: addImageFromSection,
                    onRemoveImage: removeImage,
                    onAddAttachment: addAttachments,
                    onRemoveAttachment: removeAttachment,
                  ),
                ),

                // ── Départ ──
                EditorSection(
                  title: 'trips.editor.when'.tr(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      PdlSettingRow(
                        key: keys.tripEditor.dateRow,
                        padding: EdgeInsets.zero,
                        icon: PdlIcons.date,
                        title: 'rides.editor.date'.tr(),
                        subtitle: AppFormatters.formatLongDate(wall),
                        onTap: busy ? null : _editDate,
                      ),
                      PdlSettingRow(
                        key: keys.tripEditor.timeRow,
                        padding: EdgeInsets.zero,
                        icon: PdlIcons.time,
                        title: 'rides.editor.time'.tr(),
                        subtitle: AppFormatters.formatTime(wall),
                        onTap: busy ? null : _editTime,
                      ),
                      ZoneMentionLine(instant: instant, zone: zone),
                    ],
                  ),
                ),

                // ── Tags ── Rien à proposer sans vocabulaire, sauf à garder
                // des tags déjà posés.
                if (vocabulary.isNotEmpty || _form.tagIds.isNotEmpty)
                  EditorSection(
                    title: 'rides.editor.tags'.tr(),
                    child: PdlSettingRow(
                      key: keys.tripEditor.tagsRow,
                      padding: EdgeInsets.zero,
                      icon: PdlIcons.tag,
                      title: _form.tagIds.isEmpty
                          ? 'rides.editor.tagsNone'.tr()
                          : _tagLabels(vocabulary),
                      onTap: busy || vocabulary.isEmpty
                          ? null
                          : () => _editTags(vocabulary),
                    ),
                  ),

                // ── Visibilité et statut ── Les valeurs que le backend
                // permet à ce voyage (docs/LEDGER_*.md MOB-137).
                VisibilityField(
                  title: 'rides.editor.visibility'.tr(),
                  selectorKey: keys.tripEditor.visibility,
                  allowed: allowedVisibilitiesFor(
                    widget.team,
                    VisibilityKind.trip,
                    permissions: _trip?.permissions,
                  ),
                  value: _form.visibility,
                  onChanged: (Visibility v) =>
                      _update(_form.copyWith(visibility: v)),
                  teamPrivate: isPrivateTeam(widget.team),
                  enabled: !busy,
                ),
                EditorSection(
                  title: 'rides.editor.status'.tr(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      PdlSegmented<Status>(
                        key: keys.tripEditor.status,
                        value: _form.status,
                        onChanged: (Status s) =>
                            _update(_form.copyWith(status: s)),
                        segments: <PdlSegment<Status>>[
                          for (final Status s in Status.$valuesDefined)
                            PdlSegment<Status>(
                              value: s,
                              label: 'status.${s.json!.toLowerCase()}'.tr(),
                            ),
                        ],
                      ),
                      if (_form.status == Status.draft) ...<Widget>[
                        const SizedBox(height: PdlSpacing.chipGap),
                        PdlSettingRow(
                          key: keys.tripEditor.publishAtRow,
                          padding: EdgeInsets.zero,
                          icon: PdlIcons.reminder,
                          title: 'rides.editor.publishAt'.tr(),
                          subtitle: _form.publishAt == null
                              ? 'rides.editor.publishAtNone'.tr()
                              : AppFormatters.formatLongDateTime(
                                  parseWallTime(_form.publishAt)!,
                                ),
                          trailing: _form.publishAt == null
                              ? null
                              : EditorClearButton(
                                  onTap: () => _update(
                                    _form.copyWith(publishAt: () => null),
                                  ),
                                ),
                          onTap: busy ? null : _editPublishAt,
                        ),
                        Text(
                          !_form.publishAtValid(zone)
                              ? 'rides.editor.publishAtPast'.tr()
                              : 'rides.editor.publishAtHint'.tr(),
                          style: t.xs.copyWith(
                            color: _form.publishAtValid(zone)
                                ? c.textDimmed
                                : c.danger,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // ── Parcours d'ensemble ──
                EditorSection(
                  title: 'trips.editor.route'.tr(),
                  hint: 'trips.editor.routeHint'.tr(),
                  child: PdlSettingRow(
                    key: keys.tripEditor.routeRow,
                    padding: EdgeInsets.zero,
                    icon: PdlIcons.route,
                    title: routeSlug == null
                        ? 'rides.editor.routeNone'.tr()
                        : (route?.name ?? _pickedNames[routeSlug] ?? routeSlug),
                    subtitle: route == null
                        ? null
                        : _routeStats(
                            route.distance,
                            route.elevationGain,
                            units,
                          ),
                    trailing: routeSlug == null
                        ? null
                        : EditorClearButton(
                            onTap: () =>
                                _update(_form.copyWith(routeSlug: () => null)),
                          ),
                    onTap: busy
                        ? null
                        : () async {
                            final RouteDto? r = await _chooseRoute();
                            if (r != null) {
                              _pickedNames[r.slug] = r.name;
                              _update(_form.copyWith(routeSlug: () => r.slug));
                            }
                          },
                  ),
                ),

                // ── Étapes ──
                EditorSection(
                  title: 'trips.editor.stages'.tr(),
                  hint: 'trips.editor.stagesHint'.tr(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (_form.stages.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: PdlSpacing.chipGap,
                          ),
                          child: Text(
                            'trips.editor.stagesEmpty'.tr(),
                            style: t.sub.copyWith(color: c.textDimmed),
                          ),
                        ),
                      for (int i = 0; i < _form.stages.length; i++) ...<Widget>[
                        _stageCard(i, stageRoutes, units, busy),
                        const SizedBox(height: PdlSpacing.chipGap),
                      ],
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: PdlButton(
                          key: keys.tripEditor.addStageButton,
                          label: 'trips.editor.stageAdd'.tr(),
                          icon: PdlIcons.add,
                          variant: PdlButtonVariant.outline,
                          size: PdlButtonSize.sm,
                          enabled: !busy,
                          onPressed: _addStage,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stageCard(
    int i,
    Map<String, RouteDetailDto> stageRoutes,
    UnitSystem units,
    bool busy,
  ) {
    final TripStageForm stage = _form.stages[i];
    final RouteDetailDto? route = stageRoutes[stage.routeSlug];
    return TripStageEditor(
      key: ValueKey<int>(_stageUids[i]),
      index: i,
      stage: stage,
      isFirst: i == 0,
      isLast: i == _form.stages.length - 1,
      enabled: !busy,
      showErrors: _showErrors,
      startPlaceName: _pickedNames[stage.startPlaceId],
      endPlaceName: _pickedNames[stage.endPlaceId],
      routeName: route?.name ?? _pickedNames[stage.routeSlug],
      routeStats: route == null
          ? null
          : _routeStats(route.distance, route.elevationGain, units),
      onChanged: (TripStageForm s) => _setStage(i, s),
      onPickDate: () => _editStageDate(i),
      onPickTime: () => _editStageTime(i),
      onPickStartPlace: () => _editStagePlace(i, start: true),
      onPickEndPlace: () => _editStagePlace(i, start: false),
      onPickRoute: () => _editStageRoute(i),
      onMoveUp: () => _moveStage(i, -1),
      onMoveDown: () => _moveStage(i, 1),
      onRemove: () => _removeStage(i),
    );
  }

  String _tagLabels(List<TagWithUsageDto> vocabulary) {
    final Map<String, String> labels = <String, String>{
      for (final TagWithUsageDto t in vocabulary) t.id: t.label,
    };
    return _form.tagIds
        .map((String id) => labels[id])
        .whereType<String>()
        .join(', ');
  }
}
