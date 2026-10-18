import 'dart:convert';

import 'package:dio/dio.dart' show DioException;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../keys.dart';
import '../../../profile/presentation/widgets/confirm_sheet.dart';
import '../../../rides/presentation/widgets/editor/editor_media_actions.dart';
import '../../../rides/presentation/widgets/editor/editor_section.dart';
import '../../../rides/presentation/widgets/editor/markdown_editor_field.dart';
import '../../../rides/presentation/widgets/editor/ride_media_section.dart';
import '../../../rides/presentation/widgets/editor/slug_edit_sheet.dart';
import '../../../tags/presentation/tag_filter.dart';
import '../../../tags/providers/team_tags_provider.dart';
import '../../../teams/providers/team_providers.dart';
import '../../data/gpx_file_source.dart';
import '../../data/route_repository.dart';
import '../../domain/gpx_check.dart';
import '../../domain/route_form.dart';
import '../../providers/route_changes.dart';
import '../../providers/route_detail_provider.dart';
import '../../providers/route_editor_providers.dart';
import '../widgets/editor/gpx_pick_step.dart';
import '../widgets/editor/route_track_section.dart';

/// Créer ([routeSlug] nul) ou modifier un parcours par import d'un fichier GPX
/// — le pendant mobile de `CreateRoutePage` / `EditRoutePage` du site
/// (docs/LEDGER_*.md MOB-79). **Le tracé ne se dessine pas dans l'app** : le
/// planificateur reste au site (`points` n'est jamais envoyé).
///
/// Ouvert aux organisateurs et administrateurs de l'équipe (et à l'admin de
/// plateforme), module parcours actif : la règle de `RouteAccessChecker`.
/// Quelqu'un d'autre arrivé ici par un lien lit un refus plutôt qu'un
/// formulaire qui finirait en 403.
///
/// [replaceGpx] (modification) fait ouvrir le sélecteur de fichier dès que
/// l'écran s'affiche — « Remplacer le fichier GPX » du menu de la fiche ;
/// rien ne part sans « Enregistrer ».
class RouteEditorPage extends ConsumerWidget {
  const RouteEditorPage({
    super.key,
    required this.teamSlug,
    this.routeSlug,
    this.replaceGpx = false,
  });

  final String teamSlug;
  final String? routeSlug;
  final bool replaceGpx;

  bool get _isEdit => routeSlug != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String title = _isEdit
        ? 'routes.editor.editTitle'.tr()
        : 'routes.editor.createTitle'.tr();

    Widget shell(Widget body) => PdlScreenScaffold(
      appBar: PdlAppBar(
        title: title,
        onBack: () => context.pop(),
        backSemanticLabel: 'common.back'.tr(),
      ),
      body: body,
    );

    Widget loadError(Object error, VoidCallback retry) => shell(
      PdlEmptyState(
        key: keys.routeEditor.loadError,
        variant: PdlEmptyVariant.error,
        title: 'common.loadError'.tr(),
        message: getErrorMessage(error),
        actions: <Widget>[
          PdlButton(label: 'common.retry'.tr(), onPressed: retry),
        ],
      ),
    );

    // 1. L'équipe et le droit — rien d'autre n'est lu avant.
    final AsyncValue<TeamDetailDto> team = ref.watch(
      teamDetailProvider(teamSlug),
    );
    final Object? teamError = team.error;
    if (teamError != null) {
      return loadError(
        teamError,
        () => ref.invalidate(teamDetailProvider(teamSlug)),
      );
    }
    final bool? canManage = ref.watch(canManageRoutesProvider(teamSlug));
    final TeamDetailDto? teamValue = team.value;
    if (teamValue == null || canManage == null) {
      return shell(const Center(child: CircularProgressIndicator.adaptive()));
    }

    // 2. Le refus est tranché **avant** de lire le parcours : un simple
    // membre qui l'écouterait lirait le 403 du serveur (parcours d'équipe
    // privé) au lieu de l'écran de refus.
    if (!canManage || !teamValue.enableRoutes) {
      return shell(
        PdlEmptyState(
          key: keys.routeEditor.forbidden,
          variant: PdlEmptyVariant.empty,
          icon: PdlIcons.admin,
          title: 'routes.editor.forbiddenTitle'.tr(),
          message: teamValue.enableRoutes
              ? 'routes.editor.forbiddenMessage'.tr()
              : 'routes.editor.modulesOffMessage'.tr(),
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

    // 3. Le parcours à modifier.
    final String? slug = routeSlug;
    RouteDetailDto? route;
    if (slug != null) {
      final RouteKey key = RouteKey(teamSlug: teamSlug, routeSlug: slug);
      final AsyncValue<RouteDetailDto> detail = ref.watch(
        routeDetailProvider(key),
      );
      final Object? routeError = detail.error;
      if (routeError != null) {
        return loadError(
          routeError,
          () => ref.invalidate(routeDetailProvider(key)),
        );
      }
      route = detail.value;
      if (route == null) {
        return shell(const Center(child: CircularProgressIndicator.adaptive()));
      }
    }

    return _RouteEditorForm(
      // Un parcours rechargé sous l'écran (slug changé, autre appareil) ne
      // réécrit pas un formulaire en cours : la clé ne suit que son id.
      key: ValueKey<String>(route?.id ?? 'new-$teamSlug'),
      team: teamValue,
      route: route,
      replaceGpx: replaceGpx,
      title: title,
    );
  }
}

class _RouteEditorForm extends ConsumerStatefulWidget {
  const _RouteEditorForm({
    super.key,
    required this.team,
    required this.route,
    required this.replaceGpx,
    required this.title,
  });

  final TeamDetailDto team;
  final RouteDetailDto? route;
  final bool replaceGpx;
  final String title;

  @override
  ConsumerState<_RouteEditorForm> createState() => _RouteEditorFormState();
}

class _RouteEditorFormState extends ConsumerState<_RouteEditorForm>
    with EditorMediaActions<_RouteEditorForm> {
  late RouteForm _form;
  late final String _initialJson;

  late final TextEditingController _name;
  late final TextEditingController _markdown;

  /// Pour faire remonter l'écran jusqu'à la section Tracé quand le serveur
  /// refuse le fichier : le bouton « Enregistrer » est loin dessous.
  final GlobalKey _trackKey = GlobalKey();

  /// Le fichier GPX choisi : requis à la création, remplaçant à la
  /// modification.
  GpxFile? _gpx;

  /// Le dernier fichier refusé, localement ou par le serveur.
  GpxRefused? _refused;

  /// Le nom pris du GPX : tant que le champ le porte tel quel, une aide le
  /// dit, et un autre fichier peut le remplacer.
  String? _suggestedName;

  bool _reading = false;
  bool _uploading = false;
  bool _saving = false;
  bool _saved = false;
  bool _showErrors = false;
  String? _error;

  RouteDetailDto? get _route => widget.route;
  String get _teamSlug => widget.team.slug;

  @override
  void initState() {
    super.initState();
    final RouteDetailDto? route = _route;
    final RouteForm initial = route == null
        ? RouteForm.initial(widget.team)
        : RouteForm.fromRoute(route);
    _form = initial;
    _initialJson = _json(initial);
    _name = TextEditingController(text: _form.name)
      ..addListener(() => _update(_form.copyWith(name: _name.text)));
    _markdown = TextEditingController(text: _form.media.markdown)
      ..addListener(
        () => _update(
          _form.copyWith(media: _form.media.copyWith(markdown: _markdown.text)),
        ),
      );
    if (route != null && widget.replaceGpx) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pickGpx();
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _markdown.dispose();
    super.dispose();
  }

  static String _json(RouteForm form) => jsonEncode(form.toRequest().toJson());

  bool get _dirty => !_saved && (_gpx != null || _json(_form) != _initialJson);

  void _update(RouteForm next) {
    if (identical(next, _form)) return;
    setState(() => _form = next);
  }

  // ── Médias ─────────────────────────────────────────────────────────────
  //
  // Les gestes sont ceux de [EditorMediaActions] ; l'écran dit où vivent le
  // formulaire et le texte.

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

  // ── Fichier GPX ────────────────────────────────────────────────────────

  /// Choisit un fichier, le contrôle localement (extension, début du
  /// contenu), puis l'adopte ou le refuse. Un refus laisse en place le
  /// fichier précédent, s'il y en avait un.
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
    final GpxCheck check;
    try {
      check = await inspectGpxFile(picked);
    } catch (error, stackTrace) {
      if (mounted) {
        setState(() {
          _reading = false;
          _error = getErrorMessage(error, stackTrace);
        });
      }
      return;
    }
    if (!mounted) return;

    switch (check) {
      case final GpxRefused refused:
        setState(() {
          _reading = false;
          _refused = refused;
        });
      case final GpxAccepted accepted:
        // Le nom du fichier ne remplace qu'un nom vide ou celui qu'il avait
        // proposé : jamais ce que l'organisateur a tapé.
        final String typed = _name.text;
        if (_route == null &&
            (typed.trim().isEmpty || typed == _suggestedName)) {
          final String suggestion = suggestedRouteName(accepted);
          _suggestedName = suggestion;
          _name.text = suggestion;
        }
        setState(() {
          _reading = false;
          _gpx = accepted.file;
          _refused = null;
        });
    }
  }

  /// « Garder le tracé actuel » : renonce au fichier choisi.
  void _cancelReplace() => setState(() {
    _gpx = null;
    _refused = null;
  });

  // ── Tags ───────────────────────────────────────────────────────────────

  Future<void> _editTags(List<TagWithUsageDto> vocabulary) async {
    final List<String>? picked = await showTagPickerSheet(
      context,
      vocabulary: vocabulary,
      selected: _form.tagIds,
      title: 'routes.editor.tagsPickerTitle'.tr(),
      hint: 'routes.editor.tagsPickerHint'.tr(),
      maxSelected: kRouteMaxTags,
    );
    if (picked == null) return;
    _update(_form.copyWith(tagIds: picked));
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

  // ── Adresse (slug) ─────────────────────────────────────────────────────

  Future<void> _editSlug() async {
    final RouteDetailDto route = _route!;
    if (_dirty && !await _confirmDiscard()) return;
    if (!mounted) return;
    final String? slug = await showSlugEditSheet(
      context,
      route.slug,
      fieldKey: keys.routeEditor.slugField,
      saveKey: keys.routeEditor.slugSave,
    );
    if (slug == null || slug == route.slug || !mounted) return;
    try {
      final RouteDetailDto updated = await ref
          .read(routeRepositoryProvider)
          .changeSlug(_teamSlug, route.slug, slug);
      if (!mounted) return;
      notifyRouteChanged(
        ref,
        teamSlug: _teamSlug,
        routeKey: RouteKey(teamSlug: _teamSlug, routeSlug: route.slug),
      );
      _saved = true;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text('rides.editor.slugSaved'.tr())));
      // L'ancienne adresse ne mène plus nulle part : la pile repart de la
      // nouvelle, fiche dessous.
      context.go(Paths.routeEdit(_teamSlug, updated.slug));
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

  Future<void> _save() async {
    if (_saving || _uploading || _reading) return;
    final GpxFile? gpx = _gpx;
    final RouteDetailDto? route = _route;
    // La création part toujours d'un fichier : le formulaire n'est pas
    // affiché avant.
    if (route == null && gpx == null) return;
    FocusScope.of(context).unfocus();
    if (!_form.isValid) {
      setState(() {
        _showErrors = true;
        _error = 'routes.editor.invalid'.tr();
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _refused = null;
    });
    final RouteRepository routes = ref.read(routeRepositoryProvider);
    final RouteRequest request = _form.toRequest();
    try {
      final RouteDto saved = route == null
          ? await routes.createRoute(_teamSlug, request, gpx: gpx!)
          : await routes.updateRoute(_teamSlug, route.slug, request, gpx: gpx);
      if (!mounted) return;
      notifyRouteChanged(
        ref,
        teamSlug: _teamSlug,
        routeKey: RouteKey(teamSlug: _teamSlug, routeSlug: saved.slug),
      );
      _saved = true;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            route == null
                ? 'routes.editor.created'.tr()
                : 'routes.editor.saved'.tr(),
          ),
        ),
      );
      final GoRouter router = GoRouter.of(context);
      if (route == null) {
        // La création laisse place à la fiche du parcours créé.
        router.pushReplacement(Paths.route(_teamSlug, saved.slug));
      } else if (router.canPop()) {
        router.pop();
      } else {
        router.go(Paths.route(_teamSlug, saved.slug));
      }
    } catch (error, stackTrace) {
      if (!mounted) return;
      // Un refus du fichier par le serveur (illisible, vide, trop long, trop
      // gros) se lit dans la section Tracé, formulaire conservé ; tout autre
      // échec est une erreur de l'écran.
      final GpxRefusal? refusal = _refusalOf(error, stackTrace);
      setState(() {
        _saving = false;
        if (refusal != null && gpx != null) {
          _refused = GpxRefused(gpx.name, refusal);
          // Le fichier refusé est oublié : un nouvel appui sur Créer ou
          // Enregistrer ne le renverrait que pour un second refus. En
          // modification on revient au tracé actuel, en création à l'étape 1
          // (le reste du formulaire est gardé). Le refus local fait
          // l'inverse, exprès : il garde le fichier précédent, accepté.
          _gpx = null;
        } else {
          _error = getErrorMessage(error, stackTrace);
        }
      });
      if (refusal != null && gpx != null) _revealTrack();
    }
  }

  static GpxRefusal? _refusalOf(Object error, StackTrace stackTrace) {
    final GpxRefusal? byCode = gpxRefusalOfApiCode(
      resolveApiError(error, stackTrace).code,
    );
    if (byCode != null) return byCode;
    // Un proxy qui coupe un envoi trop gros répond 413 sans corps lisible.
    if (error is DioException && error.response?.statusCode == 413) {
      return GpxRefusal.tooLarge;
    }
    return null;
  }

  void _revealTrack() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? target = _trackKey.currentContext;
      if (!mounted || target == null) return;
      Scrollable.ensureVisible(target, duration: PdlMotion.stateChange);
    });
  }

  // ── Écran ──────────────────────────────────────────────────────────────

  static IconData _surfaceIcon(SurfaceType s) => switch (s) {
    SurfaceType.road => PdlIcons.surfaceRoad,
    SurfaceType.gravel => PdlIcons.surfaceGravel,
    SurfaceType.mtb => PdlIcons.surfaceMtb,
    SurfaceType.mixed || SurfaceType.$unknown => PdlIcons.surfaceMixed,
  };

  @override
  Widget build(BuildContext context) {
    final PdlTypography t = context.pdlText;
    final RouteDetailDto? route = _route;
    final bool creating = route == null;
    // La création commence par le choix du fichier : pas de formulaire avant.
    final bool picking = creating && _gpx == null;
    final bool teamOnly = widget.team.visibility == Visibility.team.json;
    final bool busy = _saving || _uploading || _reading;

    final List<TagWithUsageDto> vocabulary =
        ref
            .watch(
              teamTagsProvider((teamSlug: _teamSlug, type: TagTarget.route)),
            )
            .value ??
        const <TagWithUsageDto>[];

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
        actionBar: picking
            ? null
            : PdlActionBar(
                children: <Widget>[
                  PdlButton(
                    key: keys.routeEditor.saveButton,
                    label: creating
                        ? 'routes.editor.create'.tr()
                        : 'routes.editor.save'.tr(),
                    loading: _saving,
                    loadingLabel: 'routes.editor.saving'.tr(),
                    enabled: !_uploading && !_reading,
                    onPressed: _save,
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
                    key: keys.routeEditor.errorBanner,
                    tone: PdlBannerTone.danger,
                    icon: PdlIcons.error,
                    message: _error!,
                    onDismiss: () => setState(() => _error = null),
                    dismissSemanticLabel: 'common.close'.tr(),
                  ),
                  const SizedBox(height: PdlSpacing.section),
                ],
                if (picking)
                  GpxPickStep(
                    onPick: _pickGpx,
                    busy: _reading,
                    refused: _refused,
                  )
                else ...<Widget>[
                  // ── Tracé ──
                  KeyedSubtree(
                    key: _trackKey,
                    child: RouteTrackSection(
                      current: route,
                      picked: _gpx,
                      refused: _refused,
                      busy: busy,
                      onPick: _pickGpx,
                      onCancelReplace: route == null || _gpx == null
                          ? null
                          : _cancelReplace,
                    ),
                  ),

                  // ── Nom et adresse ──
                  TextField(
                    key: keys.routeEditor.nameField,
                    controller: _name,
                    enabled: !_saving,
                    textCapitalization: TextCapitalization.sentences,
                    inputFormatters: <TextInputFormatter>[
                      LengthLimitingTextInputFormatter(kRouteNameMaxLength),
                    ],
                    style: t.bodyStrong,
                    decoration: InputDecoration(
                      labelText: 'routes.editor.name'.tr(),
                      hintText: 'routes.editor.namePlaceholder'.tr(),
                      helper:
                          _suggestedName != null && _name.text == _suggestedName
                          ? Text(
                              'routes.editor.nameFromGpx'.tr(),
                              key: keys.routeEditor.nameFromGpxHint,
                            )
                          : null,
                      errorText: _showErrors && !_form.nameValid
                          ? 'routes.editor.nameError'.tr()
                          : null,
                    ),
                  ),
                  if (route != null)
                    PdlSettingRow(
                      key: keys.routeEditor.slugRow,
                      padding: EdgeInsets.zero,
                      icon: PdlIcons.link,
                      title: 'rides.editor.slug'.tr(),
                      subtitle: route.slug,
                      onTap: busy ? null : _editSlug,
                    ),
                  const SizedBox(height: PdlSpacing.section),

                  // ── Surface et visibilité ──
                  EditorSection(
                    title: 'routes.editor.surface'.tr(),
                    child: PdlSegmented<SurfaceType>(
                      key: keys.routeEditor.surface,
                      value: _form.surfaceType,
                      onChanged: (SurfaceType s) =>
                          _update(_form.copyWith(surfaceType: s)),
                      segments: <PdlSegment<SurfaceType>>[
                        for (final SurfaceType s in SurfaceType.$valuesDefined)
                          PdlSegment<SurfaceType>(
                            key: keys.routeEditor.surfaceOption(s),
                            value: s,
                            label: 'routes.surfaceType.${s.json!.toLowerCase()}'
                                .tr(),
                            icon: _surfaceIcon(s),
                          ),
                      ],
                    ),
                  ),
                  if (!teamOnly)
                    EditorSection(
                      title: 'routes.editor.visibility'.tr(),
                      child: PdlSegmented<Visibility>(
                        key: keys.routeEditor.visibility,
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

                  // ── Tags ── Rien à proposer sans vocabulaire, sauf à
                  // garder des tags déjà posés.
                  if (vocabulary.isNotEmpty || _form.tagIds.isNotEmpty)
                    EditorSection(
                      title: 'routes.editor.tags'.tr(),
                      child: PdlSettingRow(
                        key: keys.routeEditor.tagsRow,
                        padding: EdgeInsets.zero,
                        icon: PdlIcons.tag,
                        title: _form.tagIds.isEmpty
                            ? 'routes.editor.tagsNone'.tr()
                            : _tagLabels(vocabulary),
                        onTap: busy || vocabulary.isEmpty
                            ? null
                            : () => _editTags(vocabulary),
                      ),
                    ),

                  // ── Description et médias ──
                  EditorSection(
                    title: 'routes.editor.description'.tr(),
                    child: MarkdownEditorField(
                      fieldKey: keys.routeEditor.markdownField,
                      controller: _markdown,
                      hintText: 'routes.editor.markdownPlaceholder'.tr(),
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
                    title: 'routes.editor.media'.tr(),
                    child: RideMediaSection(
                      assets: _form.media.assets,
                      busy: _saving || _uploading,
                      onPickLogo: pickLogo,
                      onRemoveLogo: removeLogo,
                      onAddImage: addImageFromSection,
                      onRemoveImage: removeImage,
                      onAddAttachment: addAttachments,
                      onRemoveAttachment: removeAttachment,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
