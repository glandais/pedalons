import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
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
import '../../../tags/presentation/tag_filter.dart';
import '../../../tags/providers/team_tags_provider.dart';
import '../../../teams/providers/team_providers.dart';
import '../../data/ride_editor_repository.dart';
import '../../data/ride_repository.dart';
import '../../domain/markdown_edit.dart';
import '../../domain/ride_form.dart';
import '../../providers/ride_changes.dart';
import '../../providers/ride_detail_provider.dart';
import '../../providers/ride_editor_providers.dart';
import '../widgets/editor/markdown_editor_field.dart';
import '../widgets/editor/ride_group_editor.dart';
import '../widgets/editor/ride_media_section.dart';
import '../widgets/editor/search_picker_sheet.dart';

/// Créer ([rideSlug] nul) ou modifier une sortie — le pendant mobile de
/// `CreateRidePage` / `EditRidePage` du site, au même contrat
/// (docs/LEDGER_*.md MOB-76).
///
/// Ouvert aux organisateurs et administrateurs de l'équipe (et à l'admin de
/// plateforme), modules sorties **et** parcours actifs : la règle de
/// `RideAccessChecker`. Quelqu'un d'autre arrivé ici par un lien lit un refus
/// plutôt qu'un formulaire qui finirait en 403.
///
/// [templateSlug] (`?template=` à la création) pré-remplit le formulaire
/// depuis un modèle, comme « Créer depuis un modèle » au tableau de bord.
class RideEditorPage extends ConsumerWidget {
  const RideEditorPage({
    super.key,
    required this.teamSlug,
    this.rideSlug,
    this.templateSlug,
  });

  final String teamSlug;
  final String? rideSlug;
  final String? templateSlug;

  bool get _isEdit => rideSlug != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TeamDetailDto> team = ref.watch(
      teamDetailProvider(teamSlug),
    );
    final RideKey? rideKey = _isEdit
        ? RideKey(teamSlug: teamSlug, rideSlug: rideSlug!)
        : null;
    final AsyncValue<RideDto>? ride = rideKey == null
        ? null
        : ref.watch(rideDetailProvider(rideKey));
    final bool? canManage = ref.watch(canManageRidesProvider(teamSlug));

    final String title = _isEdit
        ? 'rides.editor.editTitle'.tr()
        : 'rides.editor.createTitle'.tr();

    Widget shell(Widget body) => PdlScreenScaffold(
      appBar: PdlAppBar(
        title: title,
        onBack: () => context.pop(),
        backSemanticLabel: 'common.back'.tr(),
      ),
      body: body,
    );

    final Object? error = team.error ?? ride?.error;
    if (error != null) {
      return shell(
        PdlEmptyState(
          key: keys.rideEditor.loadError,
          variant: PdlEmptyVariant.error,
          title: 'common.loadError'.tr(),
          message: getErrorMessage(error),
          actions: <Widget>[
            PdlButton(
              label: 'common.retry'.tr(),
              onPressed: () {
                ref.invalidate(teamDetailProvider(teamSlug));
                if (rideKey != null) {
                  ref.invalidate(rideDetailProvider(rideKey));
                }
              },
            ),
          ],
        ),
      );
    }

    final TeamDetailDto? teamValue = team.value;
    final RideDto? rideValue = ride?.value;
    if (teamValue == null ||
        (_isEdit && rideValue == null) ||
        canManage == null) {
      return shell(const Center(child: CircularProgressIndicator.adaptive()));
    }

    final bool modulesOn = teamValue.enableRides && teamValue.enableRoutes;
    if (!canManage || !modulesOn) {
      return shell(
        PdlEmptyState(
          key: keys.rideEditor.forbidden,
          variant: PdlEmptyVariant.empty,
          icon: PdlIcons.admin,
          title: 'rides.editor.forbiddenTitle'.tr(),
          message: canManage
              ? 'rides.editor.modulesOffMessage'.tr()
              : 'rides.editor.forbiddenMessage'.tr(),
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

    return _RideEditorForm(
      // Une sortie rechargée sous l'écran (slug changé, autre appareil) ne
      // réécrit pas un formulaire en cours : la clé ne suit que son id.
      key: ValueKey<String>(rideValue?.id ?? 'new-$teamSlug'),
      team: teamValue,
      ride: rideValue,
      templateSlug: templateSlug,
      title: title,
    );
  }
}

class _RideEditorForm extends ConsumerStatefulWidget {
  const _RideEditorForm({
    super.key,
    required this.team,
    required this.ride,
    required this.templateSlug,
    required this.title,
  });

  final TeamDetailDto team;
  final RideDto? ride;
  final String? templateSlug;
  final String title;

  @override
  ConsumerState<_RideEditorForm> createState() => _RideEditorFormState();
}

class _RideEditorFormState extends ConsumerState<_RideEditorForm> {
  late RideForm _form;
  late final RideForm _initial;
  late String _initialJson;

  late final TextEditingController _name;
  late final TextEditingController _markdown;

  /// Une clé locale par groupe, stable au réordonnancement : c'est elle qui
  /// garde chaque carte (et ses champs) attachée à son groupe.
  final List<int> _groupUids = <int>[];
  int _nextUid = 0;

  /// Les noms des meneurs connus : ceux de la sortie, puis ceux choisis ici.
  final Map<String, String> _leaderNames = <String, String>{};

  /// Les noms des parcours et des lieux choisis dans une feuille : affichés
  /// tout de suite, le temps que leur détail se charge (sinon la ligne montre
  /// un slug ou « … » pendant l'aller-retour).
  final Map<String, String> _pickedNames = <String, String>{};

  /// Le dernier fuseau résolu, gardé pendant qu'un nouveau se calcule.
  late String _lastZone;

  bool _uploading = false;
  bool _saving = false;
  bool _saved = false;
  bool _showErrors = false;
  String? _error;

  RideDto? get _ride => widget.ride;
  String get _teamSlug => widget.team.slug;
  RideEditorRepository get _repo => ref.read(rideEditorRepositoryProvider);

  @override
  void initState() {
    super.initState();
    final RideDto? ride = _ride;
    _initial = ride == null
        ? RideForm.initial(widget.team, firstGroupName: _defaultGroupName(1))
        : RideForm.fromRide(ride);
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
    for (int i = 0; i < _form.groups.length; i++) {
      _groupUids.add(_nextUid++);
    }
    if (ride != null) {
      for (final RideGroupDto g in ride.groups) {
        final PublicUserDto? leader = g.leader;
        if (leader != null) _leaderNames[leader.id] = leader.displayName;
      }
    }
    _lastZone = ride?.timezone ?? widget.team.timezone;
    final String? template = widget.templateSlug;
    if (ride == null && template != null) _loadTemplateSlug(template);
  }

  @override
  void dispose() {
    _name.dispose();
    _markdown.dispose();
    super.dispose();
  }

  static String _json(RideForm form) => jsonEncode(form.toRequest().toJson());

  static String _defaultGroupName(int number) => 'rides.editor.groupDefaultName'
      .tr(namedArgs: <String, String>{'number': '$number'});

  bool get _dirty => !_saved && _json(_form) != _initialJson;

  void _update(RideForm next) {
    if (identical(next, _form)) return;
    setState(() => _form = next);
  }

  // ── Fuseau de la sortie ────────────────────────────────────────────────
  //
  // Lieu de départ, sinon départ du parcours, sinon équipe (ledger
  // `API-60`). Une sortie modifiée dont ni le lieu ni le parcours n'ont
  // bougé garde le fuseau que le serveur lui a donné, sans appel.

  String _zone() {
    final RideDto? ride = _ride;
    if (ride != null &&
        _form.startPlaceId == _initial.startPlaceId &&
        _form.routeSlug == _initial.routeSlug) {
      return _lastZone = ride.timezone;
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

    final String? placeId = _form.startPlaceId;
    if (placeId != null) {
      final AsyncValue<PlaceDetailDto> place = ref.watch(
        editorPlaceProvider((teamSlug: _teamSlug, id: placeId)),
      );
      if (place.isLoading) pending = true;
      final String? zone = fromPoint(place.value?.geometry);
      if (zone != null) return _lastZone = zone;
    }
    final String? routeSlug = _form.routeSlug;
    if (!pending && routeSlug != null) {
      final AsyncValue<RouteDetailDto> route = ref.watch(
        editorRouteProvider((teamSlug: _teamSlug, id: routeSlug)),
      );
      if (route.isLoading) pending = true;
      final String? zone = fromPoint(route.value?.start);
      if (zone != null) return _lastZone = zone;
    }
    if (pending) return _lastZone;
    return _lastZone = widget.team.timezone;
  }

  // ── Modèle ─────────────────────────────────────────────────────────────

  Future<void> _loadTemplateSlug(String slug) async {
    try {
      final RideTemplateDto template = await _repo.getTemplate(_teamSlug, slug);
      if (!mounted) return;
      _applyTemplate(template);
    } catch (_) {
      // Un modèle illisible (supprimé, renommé) laisse le formulaire vide,
      // comme au site.
    }
  }

  void _applyTemplate(RideTemplateDto template) {
    final RideForm next = _form.applyTemplate(template);
    setState(() {
      _form = next;
      _groupUids
        ..clear()
        ..addAll(<int>[for (final RideGroupForm _ in next.groups) _nextUid++]);
    });
    _name.text = next.name;
    _markdown.text = next.media.markdown;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          'rides.editor.templateApplied'.tr(
            namedArgs: <String, String>{'name': template.name},
          ),
        ),
      ),
    );
  }

  Future<void> _pickTemplate() async {
    final RideTemplateDto? template =
        await showSearchPickerSheet<RideTemplateDto>(
          context,
          title: 'rides.editor.templateTitle'.tr(),
          searchHint: 'rides.editor.templateSearch'.tr(),
          emptyMessage: 'rides.editor.templateEmpty'.tr(),
          idOf: (RideTemplateDto t) => t.id,
          load: (String? search, int page) async {
            final RideTemplateListResponse r = await _repo.searchTemplates(
              _teamSlug,
              search: search,
              page: page,
            );
            return (items: r.templates, total: r.total);
          },
          itemBuilder:
              (BuildContext _, RideTemplateDto t, VoidCallback onTap) =>
                  PdlSettingRow(
                    title: t.name,
                    icon: PdlIcons.template,
                    subtitle: 'rides.groupCount'.plural(t.groupCount),
                    onTap: onTap,
                  ),
        );
    if (template == null || !mounted) return;
    // La liste ne porte pas forcément les groupes : on relit le modèle.
    try {
      final RideTemplateDto full = await _repo.getTemplate(
        _teamSlug,
        template.slug,
      );
      if (mounted) _applyTemplate(full);
    } catch (error, stackTrace) {
      if (mounted) setState(() => _error = getErrorMessage(error, stackTrace));
    }
  }

  // ── Dates ──────────────────────────────────────────────────────────────

  DateTime get _wall =>
      parseWallTime(_form.dateTime) ??
      parseWallTime(
        nextWeekdayWallTime(
          kDefaultRideWeekday,
          kDefaultRideHour,
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

  Future<void> _editDate() async {
    final DateTime wall = _wall;
    final DateTime? day = await _pickDate(wall);
    if (day == null) return;
    _update(
      _form.copyWith(
        dateTime: wallTimeOf(
          DateTime(day.year, day.month, day.day, wall.hour, wall.minute),
        ),
      ),
    );
  }

  Future<void> _editTime() async {
    final DateTime wall = _wall;
    final TimeOfDay? time = await _pickTime(TimeOfDay.fromDateTime(wall));
    if (time == null) return;
    _update(
      _form.copyWith(
        dateTime: wallTimeOf(
          DateTime(wall.year, wall.month, wall.day, time.hour, time.minute),
        ),
      ),
    );
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

  // ── Lieux, parcours, meneurs, tags ─────────────────────────────────────

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

  Future<MemberDto?> _chooseLeader() {
    return showSearchPickerSheet<MemberDto>(
      context,
      title: 'rides.editor.groupLeader'.tr(),
      searchHint: 'rides.editor.groupLeaderSearch'.tr(),
      emptyMessage: 'rides.editor.groupLeaderEmpty'.tr(),
      idOf: (MemberDto m) => m.user.id,
      load: (String? search, int page) async {
        final MemberListResponse r = await _repo.searchMembers(
          _teamSlug,
          search: search,
          page: page,
        );
        return (items: r.members, total: r.total);
      },
      itemBuilder: (BuildContext _, MemberDto m, VoidCallback onTap) =>
          PdlPersonRow(
            name: m.user.displayName,
            imageUrl: m.user.avatarUrl,
            onTap: onTap,
          ),
    );
  }

  Future<void> _editTags(List<TagWithUsageDto> vocabulary) async {
    final List<String>? picked = await showTagPickerSheet(
      context,
      vocabulary: vocabulary,
      selected: _form.tagIds,
      title: 'rides.editor.tagsPickerTitle'.tr(),
      hint: 'rides.editor.tagsPickerHint'.tr(),
      maxSelected: kRideMaxTags,
    );
    if (picked == null) return;
    _update(_form.copyWith(tagIds: picked));
  }

  // ── Groupes ────────────────────────────────────────────────────────────

  void _setGroup(int index, RideGroupForm group) {
    final List<RideGroupForm> groups = <RideGroupForm>[..._form.groups];
    groups[index] = group;
    _update(_form.copyWith(groups: groups));
  }

  void _addGroup() {
    setState(() {
      _groupUids.add(_nextUid++);
      _form = _form.copyWith(
        groups: <RideGroupForm>[
          ..._form.groups,
          RideGroupForm(name: _defaultGroupName(_form.groups.length + 1)),
        ],
      );
    });
  }

  void _moveGroup(int index, int delta) {
    final int to = index + delta;
    if (to < 0 || to >= _form.groups.length) return;
    setState(() {
      final List<RideGroupForm> groups = <RideGroupForm>[..._form.groups];
      final RideGroupForm g = groups.removeAt(index);
      groups.insert(to, g);
      final int uid = _groupUids.removeAt(index);
      _groupUids.insert(to, uid);
      _form = _form.copyWith(groups: groups);
    });
  }

  Future<void> _removeGroup(int index) async {
    final String? id = _form.groups[index].id;
    final int registered = id == null
        ? 0
        : (_ride?.groups
                  .where((RideGroupDto g) => g.id == id)
                  .firstOrNull
                  ?.countParticipants ??
              0);
    if (registered > 0) {
      // Le serveur supprimera les inscriptions et préviendra les inscrits :
      // on le dit avant, comme au site.
      final bool ok = await confirmDestructive(
        context,
        title: 'rides.editor.groupRemoveRegisteredTitle'.tr(),
        message: 'rides.editor.groupRemoveRegisteredMessage'.plural(registered),
        confirmLabel: 'rides.editor.groupRemoveConfirm'.tr(),
      );
      if (!ok || !mounted) return;
    }
    setState(() {
      _groupUids.removeAt(index);
      _form = _form.copyWith(
        groups: <RideGroupForm>[..._form.groups]..removeAt(index),
      );
    });
  }

  Future<void> _editGroupTime(int index) async {
    final RideGroupForm g = _form.groups[index];
    final TimeOfDay initial = g.time == null
        ? TimeOfDay.fromDateTime(_wall)
        : TimeOfDay(
            hour: int.tryParse(g.time!.split(':').first) ?? 0,
            minute:
                int.tryParse(g.time!.split(':').elementAtOrNull(1) ?? '') ?? 0,
          );
    final TimeOfDay? time = await _pickTime(initial);
    if (time == null) return;
    final String hhmm =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    _setGroup(index, _form.groups[index].copyWith(time: () => hhmm));
  }

  Future<void> _editGroupLeader(int index) async {
    final MemberDto? member = await _chooseLeader();
    if (member == null || !mounted) return;
    _leaderNames[member.user.id] = member.user.displayName;
    _setGroup(
      index,
      _form.groups[index].copyWith(leaderId: () => member.user.id),
    );
  }

  Future<void> _editGroupRoute(int index) async {
    final RouteDto? route = await _chooseRoute();
    if (route == null || !mounted) return;
    _pickedNames[route.slug] = route.name;
    _setGroup(index, _form.groups[index].copyWith(routeSlug: () => route.slug));
  }

  // ── Médias ─────────────────────────────────────────────────────────────

  Future<AssetDto?> _upload(
    String path,
    AssetTypeRequest type, {
    String? name,
  }) async {
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      return await _repo.uploadAsset(
        _teamSlug,
        filePath: path,
        type: type,
        fileName: name,
      );
    } catch (error, stackTrace) {
      if (mounted) {
        setState(
          () => _error =
              '${'rides.editor.uploadFailed'.tr()} : ${getErrorMessage(error, stackTrace)}',
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<XFile?> _pickImage() async {
    try {
      // 1920 px : la plus grande variante que le serveur sert (visionneuse).
      return await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2560,
        maxHeight: 2560,
      );
    } on PlatformException catch (error, stackTrace) {
      if (mounted) setState(() => _error = getErrorMessage(error, stackTrace));
      return null;
    }
  }

  void _setAssets(AssetsDto assets) =>
      _update(_form.copyWith(media: _form.media.copyWith(assets: assets)));

  Future<void> _pickLogo() async {
    final XFile? file = await _pickImage();
    if (file == null) return;
    final AssetDto? asset = await _upload(
      file.path,
      AssetTypeRequest.logo,
      name: file.name,
    );
    if (asset == null || !mounted) return;
    _setAssets(_form.media.assets.copyWith(logo: asset));
  }

  /// Une image envoyée rejoint `assets.images` **et** rend sa directive,
  /// pour la barre d'outils qui l'insère dans le texte — le geste du site.
  Future<String?> _addImage() async {
    final XFile? file = await _pickImage();
    if (file == null) return null;
    final AssetDto? asset = await _upload(
      file.path,
      AssetTypeRequest.image,
      name: file.name,
    );
    if (asset == null || !mounted) return null;
    final AssetsDto assets = _form.media.assets;
    _setAssets(assets.copyWith(images: <AssetDto>[...assets.images, asset]));
    return assetDirective(asset.id);
  }

  Future<void> _addImageFromSection() async {
    final TextEditingValue before = _markdown.value;
    final String? directive = await _addImage();
    if (directive == null) return;
    _markdown.value = insertBlock(
      before.selection.isValid
          ? before
          : before.copyWith(
              selection: TextSelection.collapsed(offset: before.text.length),
            ),
      directive,
    );
  }

  void _removeImage(AssetDto image) {
    final AssetsDto assets = _form.media.assets;
    _setAssets(
      assets.copyWith(
        images: <AssetDto>[
          for (final AssetDto a in assets.images)
            if (a.id != image.id) a,
        ],
      ),
    );
    _markdown.text = removeAssetDirectives(_markdown.text, image.id);
  }

  Future<void> _addAttachments() async {
    final List<PlatformFile> files;
    try {
      files = await FilePicker.pickFiles();
    } on PlatformException catch (error, stackTrace) {
      if (mounted) setState(() => _error = getErrorMessage(error, stackTrace));
      return;
    }
    final List<AssetDto> added = <AssetDto>[];
    for (final PlatformFile file in files) {
      final String? path = file.path;
      if (path == null) continue;
      final AssetDto? asset = await _upload(
        path,
        AssetTypeRequest.attachment,
        name: file.name,
      );
      if (asset == null) break;
      added.add(asset);
    }
    if (added.isEmpty || !mounted) return;
    final AssetsDto assets = _form.media.assets;
    _setAssets(
      assets.copyWith(attachments: <AssetDto>[...assets.attachments, ...added]),
    );
  }

  void _removeAttachment(AssetDto file) {
    final AssetsDto assets = _form.media.assets;
    _setAssets(
      assets.copyWith(
        attachments: <AssetDto>[
          for (final AssetDto a in assets.attachments)
            if (a.id != file.id) a,
        ],
      ),
    );
  }

  // ── Adresse (slug) ─────────────────────────────────────────────────────

  Future<void> _editSlug() async {
    final RideDto ride = _ride!;
    if (_dirty && !await _confirmDiscard()) return;
    if (!mounted) return;
    final String? slug = await _askSlug(context, ride.slug);
    if (slug == null || slug == ride.slug || !mounted) return;
    try {
      final RideDto updated = await ref
          .read(rideRepositoryProvider)
          .changeSlug(_teamSlug, ride.slug, slug);
      if (!mounted) return;
      notifyRideChanged(
        ref,
        rideKey: RideKey(teamSlug: _teamSlug, rideSlug: ride.slug),
      );
      _saved = true;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text('rides.editor.slugSaved'.tr())));
      // L'ancienne adresse ne mène plus nulle part : la pile repart de la
      // nouvelle, détail dessous.
      context.go(Paths.rideEdit(_teamSlug, updated.slug));
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
    final RideRepository rides = ref.read(rideRepositoryProvider);
    final RideRequest request = _form.toRequest();
    final RideDto? ride = _ride;
    try {
      final RideDto saved = ride == null
          ? await rides.createRide(_teamSlug, request)
          : await rides.updateRide(_teamSlug, ride.slug, request);
      if (!mounted) return;
      final RideKey key = RideKey(teamSlug: _teamSlug, rideSlug: saved.slug);
      notifyRideChanged(ref, rideKey: key);
      _saved = true;
      final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
        context,
      );
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            ride == null
                ? 'rides.editor.created'.tr()
                : 'rides.editor.saved'.tr(),
          ),
        ),
      );
      final GoRouter router = GoRouter.of(context);
      if (ride == null) {
        // La création laisse place à la fiche de la sortie créée.
        router.pushReplacement(Paths.ride(_teamSlug, saved.slug));
      } else if (router.canPop()) {
        router.pop();
      } else {
        router.go(Paths.ride(_teamSlug, saved.slug));
      }
    } catch (error, stackTrace) {
      if (!mounted) return;
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
    final DateTime wall = _wall;
    final DateTime instant = AppFormatters.zoneWallClockToUtc(wall, zone);

    final List<TagWithUsageDto> vocabulary =
        ref
            .watch(
              teamTagsProvider((teamSlug: _teamSlug, type: TagTarget.ride)),
            )
            .value ??
        const <TagWithUsageDto>[];

    final Map<String, RouteDetailDto> groupRoutes =
        ref
            .watch(
              editorGroupRoutesProvider((
                teamSlug: _teamSlug,
                slugs: groupRoutesKey(
                  _form.groups.map((RideGroupForm g) => g.routeSlug),
                ),
              )),
            )
            .value ??
        const <String, RouteDetailDto>{};

    final String? startPlaceId = _form.startPlaceId;
    final String? endPlaceId = _form.endPlaceId;
    final String? routeSlug = _form.routeSlug;
    final PlaceDetailDto? startPlace = startPlaceId == null
        ? null
        : ref
              .watch(
                editorPlaceProvider((teamSlug: _teamSlug, id: startPlaceId)),
              )
              .value;
    final PlaceDetailDto? endPlace = endPlaceId == null
        ? null
        : ref
              .watch(editorPlaceProvider((teamSlug: _teamSlug, id: endPlaceId)))
              .value;
    final RouteDetailDto? route = routeSlug == null
        ? null
        : ref
              .watch(editorRouteProvider((teamSlug: _teamSlug, id: routeSlug)))
              .value;

    final bool teamOnly = widget.team.visibility == Visibility.team.json;
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
              key: keys.rideEditor.saveButton,
              label: _ride == null
                  ? 'rides.editor.create'.tr()
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
                    key: keys.rideEditor.errorBanner,
                    tone: PdlBannerTone.danger,
                    icon: PdlIcons.error,
                    message: _error!,
                    onDismiss: () => setState(() => _error = null),
                    dismissSemanticLabel: 'common.close'.tr(),
                  ),
                  const SizedBox(height: PdlSpacing.section),
                ],
                if (_ride == null) ...<Widget>[
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: PdlButton(
                      key: keys.rideEditor.templateButton,
                      label: 'rides.editor.loadTemplate'.tr(),
                      icon: PdlIcons.template,
                      variant: PdlButtonVariant.outline,
                      size: PdlButtonSize.sm,
                      enabled: !busy,
                      onPressed: _pickTemplate,
                    ),
                  ),
                  const SizedBox(height: PdlSpacing.section),
                ],

                // ── Nom et adresse ──
                TextField(
                  key: keys.rideEditor.nameField,
                  controller: _name,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: <TextInputFormatter>[
                    LengthLimitingTextInputFormatter(kRideNameMaxLength),
                  ],
                  style: t.bodyStrong,
                  decoration: InputDecoration(
                    labelText: 'rides.editor.name'.tr(),
                    hintText: 'rides.editor.namePlaceholder'.tr(),
                    errorText: _showErrors && !_form.nameValid
                        ? 'rides.editor.nameError'.tr()
                        : null,
                  ),
                ),
                if (_ride != null)
                  PdlSettingRow(
                    key: keys.rideEditor.slugRow,
                    padding: EdgeInsets.zero,
                    icon: PdlIcons.link,
                    title: 'rides.editor.slug'.tr(),
                    subtitle: _ride!.slug,
                    onTap: busy ? null : _editSlug,
                  ),
                const SizedBox(height: PdlSpacing.section),

                // ── Description ──
                _Section(
                  title: 'rides.editor.description'.tr(),
                  child: MarkdownEditorField(
                    controller: _markdown,
                    images: _form.media.assets.images,
                    enabled: !_saving,
                    imageBusy: _uploading,
                    onInsertImage: _addImage,
                    errorText: _form.markdownValid
                        ? null
                        : 'rides.editor.markdownTooLong'.tr(),
                  ),
                ),
                _Section(
                  title: 'rides.editor.media'.tr(),
                  child: RideMediaSection(
                    assets: _form.media.assets,
                    busy: busy,
                    onPickLogo: _pickLogo,
                    onRemoveLogo: () =>
                        _setAssets(_form.media.assets.copyWith(logo: null)),
                    onAddImage: _addImageFromSection,
                    onRemoveImage: _removeImage,
                    onAddAttachment: _addAttachments,
                    onRemoveAttachment: _removeAttachment,
                  ),
                ),

                // ── Date ──
                _Section(
                  title: 'rides.editor.when'.tr(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      PdlSettingRow(
                        key: keys.rideEditor.dateRow,
                        padding: EdgeInsets.zero,
                        icon: PdlIcons.date,
                        title: 'rides.editor.date'.tr(),
                        subtitle: AppFormatters.formatLongDate(wall),
                        onTap: busy ? null : _editDate,
                      ),
                      PdlSettingRow(
                        key: keys.rideEditor.timeRow,
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

                // ── Lieux ──
                _Section(
                  title: 'rides.editor.places'.tr(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      PdlSettingRow(
                        key: keys.rideEditor.startPlaceRow,
                        padding: EdgeInsets.zero,
                        icon: PdlIcons.placeStart,
                        title: 'rides.editor.startPlace'.tr(),
                        subtitle: startPlaceId == null
                            ? 'rides.editor.placeNone'.tr()
                            : (startPlace?.name ??
                                  _pickedNames[startPlaceId] ??
                                  '…'),
                        trailing: startPlaceId == null
                            ? null
                            : EditorClearButton(
                                onTap: () => _update(
                                  _form.copyWith(startPlaceId: () => null),
                                ),
                              ),
                        onTap: busy
                            ? null
                            : () async {
                                final PlaceDetailDto? p = await _choosePlace(
                                  start: true,
                                );
                                if (p != null) {
                                  _pickedNames[p.id] = p.name;
                                  _update(
                                    _form.copyWith(startPlaceId: () => p.id),
                                  );
                                }
                              },
                      ),
                      PdlSettingRow(
                        key: keys.rideEditor.endPlaceRow,
                        padding: EdgeInsets.zero,
                        icon: PdlIcons.placeEnd,
                        title: 'rides.editor.endPlace'.tr(),
                        subtitle: endPlaceId == null
                            ? 'rides.editor.placeNone'.tr()
                            : (endPlace?.name ??
                                  _pickedNames[endPlaceId] ??
                                  '…'),
                        trailing: endPlaceId == null
                            ? null
                            : EditorClearButton(
                                onTap: () => _update(
                                  _form.copyWith(endPlaceId: () => null),
                                ),
                              ),
                        onTap: busy
                            ? null
                            : () async {
                                final PlaceDetailDto? p = await _choosePlace(
                                  start: false,
                                );
                                if (p != null) {
                                  _pickedNames[p.id] = p.name;
                                  _update(
                                    _form.copyWith(endPlaceId: () => p.id),
                                  );
                                }
                              },
                      ),
                    ],
                  ),
                ),

                // ── Tags ── Rien à proposer sans vocabulaire, sauf à garder
                // des tags déjà posés.
                if (vocabulary.isNotEmpty || _form.tagIds.isNotEmpty)
                  _Section(
                    title: 'rides.editor.tags'.tr(),
                    child: PdlSettingRow(
                      key: keys.rideEditor.tagsRow,
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

                // ── Visibilité et statut ──
                if (!teamOnly)
                  _Section(
                    title: 'rides.editor.visibility'.tr(),
                    child: PdlSegmented<Visibility>(
                      key: keys.rideEditor.visibility,
                      value: _form.visibility,
                      onChanged: (Visibility v) =>
                          _update(_form.copyWith(visibility: v)),
                      segments: <PdlSegment<Visibility>>[
                        for (final Visibility v in Visibility.$valuesDefined)
                          PdlSegment<Visibility>(
                            value: v,
                            label: 'visibility.${v.json!.toLowerCase()}'.tr(),
                          ),
                      ],
                    ),
                  ),
                _Section(
                  title: 'rides.editor.status'.tr(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      PdlSegmented<Status>(
                        key: keys.rideEditor.status,
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
                          key: keys.rideEditor.publishAtRow,
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

                // ── Parcours ──
                _Section(
                  title: 'rides.editor.route'.tr(),
                  child: PdlSettingRow(
                    key: keys.rideEditor.routeRow,
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

                // ── Groupes ──
                _Section(
                  title: 'rides.editor.groups'.tr(),
                  hint: 'rides.editor.groupsHint'.tr(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (int i = 0; i < _form.groups.length; i++) ...<Widget>[
                        RideGroupEditor(
                          key: ValueKey<int>(_groupUids[i]),
                          index: i,
                          group: _form.groups[i],
                          leaderName: _leaderNames[_form.groups[i].leaderId],
                          routeName:
                              groupRoutes[_form.groups[i].routeSlug]?.name ??
                              _pickedNames[_form.groups[i].routeSlug],
                          isFirst: i == 0,
                          isLast: i == _form.groups.length - 1,
                          onChanged: (RideGroupForm g) => _setGroup(i, g),
                          onPickTime: () => _editGroupTime(i),
                          onPickLeader: () => _editGroupLeader(i),
                          onPickRoute: () => _editGroupRoute(i),
                          onMoveUp: () => _moveGroup(i, -1),
                          onMoveDown: () => _moveGroup(i, 1),
                          onRemove: () => _removeGroup(i),
                        ),
                        const SizedBox(height: PdlSpacing.chipGap),
                      ],
                      if (_showErrors && !_form.groupsValid)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: PdlSpacing.chipGap,
                          ),
                          child: Text(
                            'rides.editor.groupsEmpty'.tr(),
                            style: t.xs.copyWith(color: c.danger),
                          ),
                        ),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: PdlButton(
                          key: keys.rideEditor.addGroupButton,
                          label: 'rides.editor.groupAdd'.tr(),
                          icon: PdlIcons.add,
                          variant: PdlButtonVariant.outline,
                          size: PdlButtonSize.sm,
                          enabled: !busy,
                          onPressed: _addGroup,
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.hint});

  final String title;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    return Padding(
      padding: const EdgeInsets.only(bottom: PdlSpacing.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PdlSectionHeader(title: title),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(bottom: PdlSpacing.chipGap),
              child: Text(hint!, style: t.xs.copyWith(color: c.textDimmed)),
            ),
          child,
        ],
      ),
    );
  }
}

/// La feuille « Changer l'adresse » : le slug actuel, modifiable.
Future<String?> _askSlug(BuildContext context, String current) {
  final TextEditingController controller = TextEditingController(text: current);
  return PdlSheet.show<String>(
    context: context,
    builder: (BuildContext sheetContext) {
      void submit() {
        final String slug = controller.text.trim().toLowerCase();
        if (slug.isEmpty) return;
        Navigator.of(sheetContext).pop(slug);
      }

      return PdlSheet(
        title: 'rides.editor.slugEdit'.tr(),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                key: keys.rideEditor.slugField,
                controller: controller,
                autofocus: true,
                autocorrect: false,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9-]')),
                ],
                onSubmitted: (_) => submit(),
              ),
              const SizedBox(height: PdlSpacing.chipGap),
              Text(
                'rides.editor.slugHint'.tr(),
                style: sheetContext.pdlText.xs.copyWith(
                  color: sheetContext.pdl.textDimmed,
                ),
              ),
            ],
          ),
        ),
        footer: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(PdlSpacing.section),
            child: PdlButton(
              key: keys.rideEditor.slugSave,
              label: 'rides.editor.save'.tr(),
              fullWidth: true,
              onPressed: submit,
            ),
          ),
        ),
      );
    },
  );
}
