import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../keys.dart';
import '../../../auth/domain/auth_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../profile/presentation/widgets/confirm_sheet.dart';
import '../../../rides/presentation/widgets/editor/editor_media_actions.dart';
import '../../../rides/presentation/widgets/editor/editor_section.dart';
import '../../../rides/presentation/widgets/editor/markdown_editor_field.dart';
import '../../../rides/presentation/widgets/editor/ride_group_editor.dart'
    show EditorClearButton;
import '../../../rides/presentation/widgets/editor/ride_media_section.dart';
import '../../../rides/presentation/widgets/editor/slug_edit_sheet.dart';
import '../../../tags/presentation/tag_filter.dart';
import '../../../tags/providers/team_tags_provider.dart';
import '../../../teams/providers/team_providers.dart';
import '../../data/ad_repository.dart';
import '../../data/place_search_repository.dart';
import '../../domain/ad_form.dart';
import '../../providers/ad_providers.dart';
import '../widgets/ad_place_picker.dart';

/// Publier ([adSlug] nul) ou modifier une annonce — le pendant mobile de
/// `CreateAdPage` / `EditAdPage` du site (docs/LEDGER_*.md MOB-158) : titre,
/// type, prix, description, photos, lieu, tags, statut.
///
/// **Tout membre** de l'équipe publie une annonce, module annonces actif ;
/// la modifier revient à son auteur et à l'administration de l'équipe — le
/// `permissions` de l'annonce le dit. Quelqu'un d'autre arrivé ici par un
/// lien lit un refus plutôt qu'un formulaire qui finirait en 403.
class AdEditorPage extends ConsumerWidget {
  const AdEditorPage({super.key, required this.teamSlug, this.adSlug});

  final String teamSlug;
  final String? adSlug;

  bool get _isEdit => adSlug != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String title = _isEdit
        ? 'ads.editor.editTitle'.tr()
        : 'ads.editor.createTitle'.tr();

    Widget shell(Widget body) => PdlScreenScaffold(
      appBar: PdlAppBar(
        title: title,
        onBack: () => context.pop(),
        backSemanticLabel: 'common.back'.tr(),
      ),
      body: body,
    );

    Widget loading() =>
        shell(const Center(child: CircularProgressIndicator.adaptive()));

    Widget loadError(Object error, VoidCallback retry) => shell(
      PdlEmptyState(
        key: keys.adEditor.loadError,
        variant: PdlEmptyVariant.error,
        title: 'common.loadError'.tr(),
        message: getErrorMessage(error),
        actions: <Widget>[
          PdlButton(label: 'common.retry'.tr(), onPressed: retry),
        ],
      ),
    );

    // 1. L'équipe et le droit de publier — rien d'autre n'est lu avant.
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
    final bool? canCreate = ref.watch(canCreateAdsProvider(teamSlug));
    final TeamDetailDto? teamValue = team.value;
    if (teamValue == null || canCreate == null) return loading();

    Widget forbidden(String message) => shell(
      PdlEmptyState(
        key: keys.adEditor.forbidden,
        variant: PdlEmptyVariant.empty,
        icon: PdlIcons.admin,
        title: 'ads.editor.forbiddenTitle'.tr(),
        message: message,
        actions: <Widget>[
          PdlButton(
            label: 'common.back'.tr(),
            variant: PdlButtonVariant.outline,
            onPressed: () => context.pop(),
          ),
        ],
      ),
    );

    // 2. Le refus est tranché **avant** de lire l'annonce.
    if (!teamValue.enableAds) {
      return forbidden('ads.editor.modulesOffMessage'.tr());
    }
    if (!canCreate) return forbidden('ads.editor.membersOnlyMessage'.tr());

    // 3. L'annonce à modifier : d'abord le droit que le backend calcule pour
    // **cette** annonce (docs/LEDGER_*.md MOB-137), puis seulement la vue du
    // formulaire, qui porte la position.
    final String? slug = adSlug;
    AdEditDto? ad;
    if (slug != null) {
      final AdKey key = (teamSlug: teamSlug, adSlug: slug);
      final AsyncValue<AdDto> detail = ref.watch(adDetailProvider(key));
      final Object? detailError = detail.error;
      if (detailError != null) {
        return loadError(
          detailError,
          () => ref.invalidate(adDetailProvider(key)),
        );
      }
      final AdDto? detailValue = detail.value;
      if (detailValue == null) return loading();
      if (!detailValue.permissions.canEdit) {
        return forbidden('ads.editor.notYoursMessage'.tr());
      }

      final AsyncValue<AdEditDto> edit = ref.watch(adEditProvider(key));
      final Object? editError = edit.error;
      if (editError != null) {
        return loadError(editError, () => ref.invalidate(adEditProvider(key)));
      }
      ad = edit.value;
      if (ad == null) return loading();
    }

    // L'adresse ne se change que par l'administration de l'équipe, comme au
    // site (`canEditSlug={isAdmin}`).
    final bool platformAdmin = ref.watch(
      authProvider.select(
        (AuthState s) => s.user?.platformRole == 'PLATFORM_ADMIN',
      ),
    );
    final bool canEditSlug =
        platformAdmin ||
        ref.watch(teamRoleProvider(teamSlug)) == TeamRole.admin;

    return _AdEditorForm(
      // Une annonce rechargée sous l'écran ne réécrit pas un formulaire en
      // cours : la clé ne suit que son id.
      key: ValueKey<String>(ad?.id ?? 'new-$teamSlug'),
      team: teamValue,
      ad: ad,
      title: title,
      canEditSlug: canEditSlug,
    );
  }
}

class _AdEditorForm extends ConsumerStatefulWidget {
  const _AdEditorForm({
    super.key,
    required this.team,
    required this.ad,
    required this.title,
    required this.canEditSlug,
  });

  final TeamDetailDto team;
  final AdEditDto? ad;
  final String title;
  final bool canEditSlug;

  @override
  ConsumerState<_AdEditorForm> createState() => _AdEditorFormState();
}

class _AdEditorFormState extends ConsumerState<_AdEditorForm>
    with EditorMediaActions<_AdEditorForm> {
  late AdForm _form;
  late final String _initialJson;

  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _markdown;
  late final TextEditingController _place;

  /// Le nom de l'adresse choisie pendant cette session. Une position déjà
  /// enregistrée n'en a pas : le serveur ne garde que le point.
  String? _pickedPlaceName;

  /// La position de l'adresse choisie est en cours de lecture : rien ne part
  /// tant qu'elle n'est pas là — enregistrer entre-temps enregistrerait
  /// l'ancienne, ou aucune.
  bool _locating = false;

  bool _priceTextValid = true;
  bool _uploading = false;
  bool _saving = false;
  bool _saved = false;
  bool _showErrors = false;
  String? _error;

  AdEditDto? get _ad => widget.ad;
  String get _teamSlug => widget.team.slug;

  @override
  void initState() {
    super.initState();
    final AdEditDto? ad = _ad;
    final AdForm initial = ad == null ? AdForm.initial() : AdForm.fromEdit(ad);
    _form = initial;
    _initialJson = _json(initial);
    _name = TextEditingController(text: _form.name)
      ..addListener(() => _update(_form.copyWith(name: _name.text)));
    _price = TextEditingController(text: adPriceText(_form.price))
      ..addListener(_onPriceChanged);
    _markdown = TextEditingController(text: _form.media.markdown)
      ..addListener(
        () => _update(
          _form.copyWith(media: _form.media.copyWith(markdown: _markdown.text)),
        ),
      );
    _place = TextEditingController(text: _form.locationDescription)
      ..addListener(
        () => _update(_form.copyWith(locationDescription: _place.text)),
      );
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _markdown.dispose();
    _place.dispose();
    super.dispose();
  }

  static String _json(AdForm form) => jsonEncode(form.toRequest().toJson());

  bool get _dirty => !_saved && _json(_form) != _initialJson;

  void _update(AdForm next) {
    if (identical(next, _form)) return;
    setState(() => _form = next);
  }

  /// Un texte illisible garde le dernier prix lu et se signale : il ne
  /// devient jamais « prix à négocier » en silence.
  void _onPriceChanged() {
    final ({bool valid, num? value}) parsed = parseAdPrice(_price.text);
    setState(() {
      _priceTextValid = parsed.valid;
      if (parsed.valid) _form = _form.copyWith(price: () => parsed.value);
    });
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

  // ── Position ───────────────────────────────────────────────────────────

  /// Choisit une adresse, puis lit sa position — une seule fois, pour
  /// l'adresse choisie (ledger `API-129`). Un échec laisse la position
  /// précédente en place, et le dit.
  Future<void> _pickPlace() async {
    if (_locating || _saving) return;
    final GeocodeResultDto? picked = await showAdPlacePicker(context, ref);
    if (picked == null || !mounted) return;

    double? lat = picked.lat;
    double? lon = picked.lon;
    if (lat == null || lon == null) {
      setState(() {
        _locating = true;
        _error = null;
      });
      try {
        final GeocodeResultDto place = await ref
            .read(placeSearchRepositoryProvider)
            .resolve(picked.id);
        lat = place.lat;
        lon = place.lon;
      } catch (error, stackTrace) {
        if (!mounted) return;
        setState(() {
          _locating = false;
          _error =
              resolveApiError(error, stackTrace).code == 'GEOCODING_UNAVAILABLE'
              ? 'ads.editor.placeUnavailable'.tr()
              : 'ads.editor.placeResolveFailed'.tr();
        });
        return;
      }
      if (!mounted) return;
    }
    if (lat == null || lon == null) {
      setState(() {
        _locating = false;
        _error = 'ads.editor.placeResolveFailed'.tr();
      });
      return;
    }
    final List<double> coordinates = <double>[lon, lat];
    setState(() {
      _locating = false;
      _pickedPlaceName = picked.displayName;
      // GeoJSON : [longitude, latitude].
      _form = _form.copyWith(location: () => adLocationOf(coordinates));
    });
  }

  void _clearPlace() => setState(() {
    _pickedPlaceName = null;
    _form = _form.copyWith(location: () => null);
  });

  // ── Tags ───────────────────────────────────────────────────────────────

  Future<void> _editTags(List<TagWithUsageDto> vocabulary) async {
    final List<String>? picked = await showTagPickerSheet(
      context,
      vocabulary: vocabulary,
      selected: _form.tagIds,
      title: 'ads.editor.tagsPickerTitle'.tr(),
      hint: 'routes.editor.tagsPickerHint'.tr(),
      maxSelected: kAdMaxTags,
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
    final AdEditDto ad = _ad!;
    if (_dirty && !await _confirmDiscard()) return;
    if (!mounted) return;
    final String? slug = await showSlugEditSheet(
      context,
      ad.slug,
      fieldKey: keys.adEditor.slugField,
      saveKey: keys.adEditor.slugSave,
    );
    if (slug == null || slug == ad.slug || !mounted) return;
    try {
      final AdDto updated = await ref
          .read(adRepositoryProvider)
          .changeSlug(_teamSlug, ad.slug, slug);
      if (!mounted) return;
      notifyAdChanged(
        ref,
        teamSlug: _teamSlug,
        adKey: (teamSlug: _teamSlug, adSlug: ad.slug),
      );
      _saved = true;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text('rides.editor.slugSaved'.tr())));
      // L'ancienne adresse ne mène plus nulle part : la pile repart de la
      // nouvelle, écran de l'annonce dessous.
      context.go(Paths.adEdit(_teamSlug, updated.slug));
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
    if (_saving || _uploading || _locating) return;
    FocusScope.of(context).unfocus();
    if (!_form.isValid || !_priceTextValid) {
      setState(() {
        _showErrors = true;
        _error = 'routes.editor.invalid'.tr();
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final AdRepository ads = ref.read(adRepositoryProvider);
    final AdRequest request = _form.toRequest();
    final AdEditDto? ad = _ad;
    try {
      final AdDto saved = ad == null
          ? await ads.createAd(_teamSlug, request)
          : await ads.updateAd(_teamSlug, ad.slug, request);
      if (!mounted) return;
      notifyAdChanged(
        ref,
        teamSlug: _teamSlug,
        adKey: (teamSlug: _teamSlug, adSlug: saved.slug),
      );
      _saved = true;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            ad == null ? 'ads.editor.created'.tr() : 'ads.editor.saved'.tr(),
          ),
        ),
      );
      final GoRouter router = GoRouter.of(context);
      if (ad == null) {
        // La création laisse place à l'écran de l'annonce créée.
        router.pushReplacement(Paths.ad(_teamSlug, saved.slug));
      } else if (router.canPop()) {
        router.pop();
      } else {
        router.go(Paths.ad(_teamSlug, saved.slug));
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

  String _positionTitle() {
    if (_locating) return 'ads.editor.placeResolving'.tr();
    final String? picked = _pickedPlaceName;
    if (picked != null) return picked;
    return _form.location == null
        ? 'ads.editor.positionNone'.tr()
        : 'ads.editor.positionSaved'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final PdlTypography t = context.pdlText;
    final AdEditDto? ad = _ad;
    final bool creating = ad == null;
    final bool busy = _saving || _uploading || _locating;

    final List<TagWithUsageDto> vocabulary =
        ref
            .watch(teamTagsProvider((teamSlug: _teamSlug, type: TagTarget.ad)))
            .value ??
        const <TagWithUsageDto>[];

    // Brouillon ou publié, comme au site ; un statut déjà autre reste proposé
    // pour que l'enregistrement ne le change pas à l'insu de l'auteur.
    final List<Status> statuses = <Status>[
      Status.draft,
      Status.published,
      if (_form.status != Status.draft && _form.status != Status.published)
        _form.status,
    ];

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
              key: keys.adEditor.saveButton,
              label: creating
                  ? 'ads.editor.create'.tr()
                  : 'routes.editor.save'.tr(),
              loading: _saving,
              loadingLabel: 'routes.editor.saving'.tr(),
              enabled: !_uploading && !_locating,
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
                    key: keys.adEditor.errorBanner,
                    tone: PdlBannerTone.danger,
                    icon: PdlIcons.error,
                    message: _error!,
                    onDismiss: () => setState(() => _error = null),
                    dismissSemanticLabel: 'common.close'.tr(),
                  ),
                  const SizedBox(height: PdlSpacing.section),
                ],

                // ── Titre et adresse ──
                TextField(
                  key: keys.adEditor.nameField,
                  controller: _name,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: <TextInputFormatter>[
                    LengthLimitingTextInputFormatter(kAdNameMaxLength),
                  ],
                  style: t.bodyStrong,
                  decoration: InputDecoration(
                    labelText: 'posts.editor.name'.tr(),
                    hintText: 'ads.editor.namePlaceholder'.tr(),
                    errorText: _showErrors && !_form.nameValid
                        ? 'posts.editor.nameError'.tr()
                        : null,
                  ),
                ),
                if (ad != null && widget.canEditSlug)
                  PdlSettingRow(
                    key: keys.adEditor.slugRow,
                    padding: EdgeInsets.zero,
                    icon: PdlIcons.link,
                    title: 'rides.editor.slug'.tr(),
                    subtitle: ad.slug,
                    onTap: busy ? null : _editSlug,
                  ),
                const SizedBox(height: PdlSpacing.section),

                // ── Type et prix ──
                EditorSection(
                  title: 'ads.editor.adType'.tr(),
                  child: PdlSegmented<AdType>(
                    key: keys.adEditor.adType,
                    value: _form.adType,
                    onChanged: (AdType type) =>
                        _update(_form.copyWith(adType: type)),
                    segments: <PdlSegment<AdType>>[
                      for (final AdType type in AdType.$valuesDefined)
                        PdlSegment<AdType>(
                          key: keys.adEditor.adTypeOption(type.json!),
                          value: type,
                          label: 'ads.adType.${type.json}'.tr(),
                        ),
                    ],
                  ),
                ),
                TextField(
                  key: keys.adEditor.priceField,
                  controller: _price,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'ads.editor.price'.tr(),
                    suffixText: '€',
                    helperText: 'ads.editor.priceHint'.tr(),
                    errorText: _priceTextValid
                        ? null
                        : 'ads.editor.priceError'.tr(),
                  ),
                ),
                const SizedBox(height: PdlSpacing.section),
                if (_form.adType == AdType.rental)
                  EditorSection(
                    title: 'ads.editor.rentalPeriod'.tr(),
                    hint: _showErrors && !_form.rentalPeriodValid
                        ? 'ads.editor.rentalPeriodError'.tr()
                        : null,
                    child: PdlSegmented<RentalPeriod?>(
                      key: keys.adEditor.rentalPeriod,
                      value: _form.rentalPeriod,
                      onChanged: (RentalPeriod? period) =>
                          _update(_form.copyWith(rentalPeriod: () => period)),
                      segments: <PdlSegment<RentalPeriod?>>[
                        for (final RentalPeriod period
                            in RentalPeriod.$valuesDefined)
                          PdlSegment<RentalPeriod?>(
                            key: keys.adEditor.rentalPeriodOption(period.json!),
                            value: period,
                            label: 'ads.rentalPeriod.${period.json}'.tr(),
                          ),
                      ],
                    ),
                  ),

                // ── Description et médias ──
                EditorSection(
                  title: 'ads.detail.description'.tr(),
                  child: MarkdownEditorField(
                    fieldKey: keys.adEditor.markdownField,
                    controller: _markdown,
                    hintText: 'ads.editor.markdownPlaceholder'.tr(),
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
                    busy: busy,
                    onPickLogo: pickLogo,
                    onRemoveLogo: removeLogo,
                    onAddImage: addImageFromSection,
                    onRemoveImage: removeImage,
                    onAddAttachment: addAttachments,
                    onRemoveAttachment: removeAttachment,
                  ),
                ),

                // ── Lieu ── Deux choses distinctes : ce qu'on en dit, et le
                // point sur la carte, que les autres ne voient que flouté.
                EditorSection(
                  title: 'ads.detail.location'.tr(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextField(
                        key: keys.adEditor.placeField,
                        controller: _place,
                        enabled: !_saving,
                        textCapitalization: TextCapitalization.sentences,
                        inputFormatters: <TextInputFormatter>[
                          LengthLimitingTextInputFormatter(
                            kAdLocationDescriptionMaxLength,
                          ),
                        ],
                        decoration: InputDecoration(
                          labelText: 'ads.editor.place'.tr(),
                          hintText: 'ads.editor.placePlaceholder'.tr(),
                        ),
                      ),
                      PdlSettingRow(
                        key: keys.adEditor.positionRow,
                        padding: EdgeInsets.zero,
                        icon: PdlIcons.place,
                        title: _positionTitle(),
                        subtitle: 'ads.editor.positionHint'.tr(),
                        trailing: _locating
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator.adaptive(),
                              )
                            : _form.location == null
                            ? null
                            : EditorClearButton(onTap: _clearPlace),
                        onTap: busy ? null : _pickPlace,
                      ),
                    ],
                  ),
                ),

                // ── Tags ── Rien à proposer sans vocabulaire, sauf à garder
                // des tags déjà posés.
                if (vocabulary.isNotEmpty || _form.tagIds.isNotEmpty)
                  EditorSection(
                    title: 'routes.editor.tags'.tr(),
                    child: PdlSettingRow(
                      key: keys.adEditor.tagsRow,
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

                // ── Statut ──
                EditorSection(
                  title: 'rides.editor.status'.tr(),
                  hint: 'ads.editor.statusHint'.tr(),
                  child: PdlSegmented<Status>(
                    key: keys.adEditor.status,
                    value: _form.status,
                    onChanged: (Status s) => _update(_form.copyWith(status: s)),
                    segments: <PdlSegment<Status>>[
                      for (final Status s in statuses)
                        PdlSegment<Status>(
                          key: keys.adEditor.statusOption(s.json!),
                          value: s,
                          label: 'status.${s.json!.toLowerCase()}'.tr(),
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
}
