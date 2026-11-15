import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/material.dart' hide Visibility;
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../keys.dart';
import '../../../auth/domain/auth_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../geocoding/presentation/geocoded_place_picker.dart';
import '../../../profile/presentation/widgets/confirm_sheet.dart';
import '../../../profile/presentation/widgets/timezone_sheet.dart';
import '../../../rides/presentation/widgets/editor/editor_media_actions.dart';
import '../../../rides/presentation/widgets/editor/editor_section.dart';
import '../../../rides/presentation/widgets/editor/rich_markdown_editor_field.dart';
import '../../../rides/presentation/widgets/editor/ride_group_editor.dart'
    show EditorClearButton;
import '../../../rides/presentation/widgets/editor/ride_media_section.dart';
import '../../../rides/presentation/widgets/editor/slug_edit_sheet.dart';
import '../../../visibility/presentation/visibility_badge.dart';
import '../../data/team_repository.dart';
import '../../domain/team_form.dart';
import '../../providers/team_access_probe.dart';
import '../../providers/team_change.dart';
import '../../providers/team_permission_providers.dart';
import '../../providers/team_providers.dart';
import '../widgets/team_timezone_change_sheet.dart';
import '../widgets/team_visibility_sheet.dart';
import '../widgets/team_webhook_sheet.dart';

/// Créer une équipe ([teamSlug] nul) ou en modifier les paramètres — le
/// pendant mobile de `CreateTeamPage` et de `TeamSettingsPage` du site.
///
/// **Création** (docs/LEDGER_*.md MOB-165) : nom, description, localisation,
/// fuseau et modules. Ouverte à toute personne connectée ; ce que le serveur
/// refuse (`TEAM_CREATION_DISABLED`, `USER_TEAM_LIMIT_REACHED`) se lit dans le
/// bandeau, la saisie gardée. Comme au site, ni logo ni image (l'upload exige
/// une équipe), pas de slug (le serveur le génère) et pas de visibilité (une
/// équipe naît `TEAM`).
///
/// **Paramètres** (docs/LEDGER_*.md MOB-166) : les mêmes champs, plus
/// l'adresse (slug), le logo, les images et les pièces jointes, la visibilité,
/// le webhook et la suppression. Réservés à l'administration de l'équipe (et
/// à l'admin de plateforme) ; quelqu'un d'autre arrivé ici par un lien lit un
/// refus, tranché avant toute autre chose. De la section « Paramètres
/// plateforme » du site, seule la visibilité est ici (ledger `MOB-171`).
class TeamEditorPage extends ConsumerWidget {
  const TeamEditorPage({super.key, this.teamSlug});

  /// L'équipe dont on modifie les paramètres ; `null` pour une création.
  final String? teamSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? slug = teamSlug;
    if (slug != null) return _settings(context, ref, slug);

    // Le fuseau de la personne : sa préférence de profil. L'app ne connaît pas
    // le nom IANA du fuseau de l'appareil ; sans préférence, le formulaire
    // propose le défaut du serveur, visible et modifiable.
    final String timezone =
        ref.watch(authProvider.select((AuthState s) => s.user?.timezone)) ??
        kTeamDefaultTimezone;

    return _TeamEditorForm(
      // Une préférence rechargée sous l'écran ne réécrit pas un formulaire en
      // cours.
      key: const ValueKey<String>('new-team'),
      initial: TeamForm.initial(timezone: timezone),
      title: 'teams.editor.createTitle'.tr(),
    );
  }

  Widget _settings(BuildContext context, WidgetRef ref, String slug) {
    final String title = 'teams.editor.settingsTitle'.tr();

    // [teamReadable] faux : l'équipe elle-même s'est refusée, sa page ne
    // dirait qu'« Équipe indisponible » — le retour mène à « Mes équipes ».
    void back({bool teamReadable = true}) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(teamReadable ? Paths.team(slug) : Paths.teams());
      }
    }

    Widget shell(Widget body) => PdlScreenScaffold(
      appBar: PdlAppBar(
        title: title,
        onBack: back,
        backSemanticLabel: 'common.back'.tr(),
      ),
      body: body,
    );

    Widget forbidden({required bool teamReadable}) => shell(
      PdlEmptyState(
        key: keys.teamEditor.forbidden,
        variant: PdlEmptyVariant.empty,
        icon: PdlIcons.admin,
        title: 'teams.editor.forbiddenTitle'.tr(),
        message: 'teams.editor.forbiddenMessage'.tr(),
        actions: <Widget>[
          PdlButton(
            key: keys.teamEditor.forbiddenBack,
            label: 'common.back'.tr(),
            variant: PdlButtonVariant.outline,
            onPressed: () => back(teamReadable: teamReadable),
          ),
        ],
      ),
    );

    final AsyncValue<TeamDetailDto> team = ref.watch(teamDetailProvider(slug));
    final TeamDetailDto? teamValue = team.value;
    final Object? error = team.error;
    // Une fiche déjà lue reste le formulaire en cours : une relecture en
    // échec (l'équipe vient d'être supprimée, d'être renommée) ne le remplace
    // pas par une erreur.
    if (teamValue == null && error != null) {
      // Une équipe que le serveur refuse (403, ou 404 pour une équipe privée
      // dont on n'est pas membre) : un refus, pas une panne à réessayer.
      if (isTeamAccessRefusal(error)) return forbidden(teamReadable: false);
      return shell(
        PdlEmptyState(
          key: keys.teamEditor.loadError,
          variant: PdlEmptyVariant.error,
          title: 'common.loadError'.tr(),
          message: getErrorMessage(error),
          actions: <Widget>[
            PdlButton(
              label: 'common.retry'.tr(),
              onPressed: () => ref.invalidate(teamDetailProvider(slug)),
            ),
          ],
        ),
      );
    }

    // `null` tant que la fiche charge : ni formulaire, ni refus.
    final bool? admin = ref.watch(isTeamAdminProvider(slug));
    if (teamValue == null || admin == null) {
      return shell(const Center(child: CircularProgressIndicator.adaptive()));
    }
    if (!admin) return forbidden(teamReadable: true);

    return _TeamEditorForm(
      // Une équipe rechargée sous l'écran ne réécrit pas un formulaire en
      // cours : la clé suit son id — et l'adresse de la route, pour qu'un
      // changement d'adresse reparte d'un formulaire neuf, sans la saisie
      // abandonnée juste avant.
      key: ValueKey<String>('${teamValue.id}@$slug'),
      team: teamValue,
      initial: TeamForm.fromTeam(teamValue),
      title: title,
      platformAdmin: ref.watch(isPlatformAdminProvider),
    );
  }
}

class _TeamEditorForm extends ConsumerStatefulWidget {
  const _TeamEditorForm({
    super.key,
    required this.initial,
    required this.title,
    this.team,
    this.platformAdmin = false,
  });

  final TeamForm initial;
  final String title;

  /// L'équipe modifiée ; `null` pour une création.
  final TeamDetailDto? team;
  final bool platformAdmin;

  @override
  ConsumerState<_TeamEditorForm> createState() => _TeamEditorFormState();
}

class _TeamEditorFormState extends ConsumerState<_TeamEditorForm>
    with EditorMediaActions<_TeamEditorForm> {
  late TeamForm _form;
  late final String _initialJson;

  late final TextEditingController _name;
  late final TextEditingController _markdown;

  /// Le nom de l'adresse choisie pendant cette session. Une position déjà
  /// enregistrée n'en a pas : le serveur ne garde que le point.
  String? _pickedPlaceName;

  /// La position de l'adresse choisie est en cours de lecture : rien ne part
  /// tant qu'elle n'est pas là.
  bool _locating = false;

  /// Un logo, une image ou une pièce jointe est en cours d'envoi.
  bool _uploading = false;

  /// L'équipe est en cours de suppression.
  bool _deleting = false;

  bool _saving = false;
  bool _saved = false;
  bool _showErrors = false;
  String? _error;

  TeamDetailDto? get _team => widget.team;

  /// L'adresse (slug) de l'équipe est en cours de changement : un
  /// enregistrement partirait vers l'ancienne adresse, un second appui
  /// lancerait un second changement.
  bool _renaming = false;

  /// Rien ne part pendant une lecture de position, un envoi de fichier, une
  /// suppression ou un changement d'adresse.
  bool get _blocked => _locating || _uploading || _deleting || _renaming;

  /// La saisie est figée : pendant un enregistrement, et pendant un
  /// changement d'adresse — réussi, il mène à la nouvelle adresse et
  /// abandonnerait sans rien demander ce qui aurait été saisi entre-temps
  /// (revue du lot 2, ledger `MOB-166`).
  bool get _frozen => _saving || _renaming;

  @override
  void initState() {
    super.initState();
    _form = widget.initial;
    _initialJson = _json(_form);
    _name = TextEditingController(text: _form.name)
      ..addListener(() => _update(_form.copyWith(name: _name.text)));
    _markdown = TextEditingController(text: _form.media.markdown)
      ..addListener(
        () => _update(
          _form.copyWith(media: _form.media.copyWith(markdown: _markdown.text)),
        ),
      );
  }

  @override
  void dispose() {
    _name.dispose();
    _markdown.dispose();
    super.dispose();
  }

  static String _json(TeamForm form) => jsonEncode(form.toRequest().toJson());

  bool get _dirty => !_saved && _json(_form) != _initialJson;

  void _update(TeamForm next) {
    if (identical(next, _form)) return;
    setState(() => _form = next);
  }

  // ── Médias ─────────────────────────────────────────────────────────────
  //
  // Les gestes sont ceux de [EditorMediaActions] ; l'écran dit où vivent le
  // formulaire et le texte. Ils ne servent qu'aux paramètres : l'envoi exige
  // une équipe.

  @override
  String get mediaTeamSlug => _team!.slug;

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

  // ── Localisation ───────────────────────────────────────────────────────

  /// Choisit une adresse et sa position par le sélecteur commun. Un échec
  /// laisse la position précédente en place, et le dit.
  Future<void> _pickPlace() async {
    if (_blocked || _saving) return;
    final GeocodedPick? pick = await pickGeocodedPlace(
      context,
      ref,
      onResolvingChange: (bool resolving) {
        if (!mounted) return;
        setState(() {
          _locating = resolving;
          if (resolving) _error = null;
        });
      },
    );
    if (!mounted) return;
    switch (pick) {
      case null:
        return;
      case GeocodedPlaceFailure(:final GeocodeFailure reason):
        setState(() => _error = reason.message);
      case GeocodedPlace():
        setState(() {
          _pickedPlaceName = pick.name;
          _form = _form.copyWith(location: () => pick.coordinates);
        });
    }
  }

  void _clearPlace() {
    if (_frozen) return;
    setState(() {
      _pickedPlaceName = null;
      _form = _form.copyWith(location: () => null);
    });
  }

  String _locationTitle() {
    if (_locating) return 'geocoder.resolving'.tr();
    final String? picked = _pickedPlaceName;
    if (picked != null) return picked;
    return _form.location == null
        ? 'geocoder.none'.tr()
        : 'geocoder.saved'.tr();
  }

  // ── Fuseau ─────────────────────────────────────────────────────────────

  Future<void> _pickTimezone() async {
    final String? picked = await showTimezoneSheet(
      context,
      current: _form.timezone,
    );
    if (picked == null || !mounted) return;
    _update(_form.copyWith(timezone: picked));
  }

  // ── Enregistrer ────────────────────────────────────────────────────────

  Future<bool> _confirmDiscard() => confirmDestructive(
    context,
    title: 'rides.editor.discardTitle'.tr(),
    message: 'rides.editor.discardMessage'.tr(),
    confirmLabel: 'rides.editor.discardConfirm'.tr(),
  );

  Future<void> _save() async {
    if (_saving || _blocked) return;
    FocusScope.of(context).unfocus();
    if (!_form.isValid) {
      setState(() {
        _showErrors = true;
        _error = 'routes.editor.invalid'.tr();
      });
      return;
    }
    final TeamDetailDto? team = _team;
    final bool goesPrivate =
        team != null &&
        widget.initial.visibility != Visibility.team &&
        _form.visibility == Visibility.team;
    final bool zoneChanged =
        team != null && _form.timezone != widget.initial.timezone;
    final bool visibilityChanged =
        team != null && _form.visibility != widget.initial.visibility;

    // Les deux confirmations du site, dans son ordre : l'équipe devient
    // privée, puis son fuseau change.
    if (goesPrivate) {
      final bool confirmed = await confirmDestructive(
        context,
        title: 'teams.editor.goPrivate.title'.tr(),
        message: 'teams.editor.goPrivate.message'.tr(),
        confirmLabel: 'teams.editor.goPrivate.confirm'.tr(),
      );
      if (!confirmed || !mounted) return;
    }
    if (zoneChanged) {
      final bool confirmed = await confirmTeamTimezoneChange(
        context,
        teamSlug: team.slug,
        timezone: _form.timezone,
      );
      if (!confirmed || !mounted) return;
    }
    // Une confirmation a rendu la main : un autre geste a pu partir.
    if (_saving || _blocked) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    final TeamRepository teams = ref.read(teamRepositoryProvider);
    // Pris avant l'`await` : l'écran peut être démonté avant la réponse, et
    // l'équipe est écrite quand même.
    final ProviderContainer container = ProviderScope.containerOf(
      context,
      listen: false,
    );
    final TeamRequest request = _form.toRequest();
    try {
      final TeamDetailDto saved = team == null
          ? await teams.createTeam(request)
          : await teams.updateTeam(team.slug, request);
      notifyTeamChanged(
        container,
        saved.slug,
        // Le contenu déjà lu porte une visibilité, des droits ou des heures
        // d'avant.
        contentScopeChanged: visibilityChanged || zoneChanged,
      );
      if (!mounted) return;
      _saved = true;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            team == null
                ? 'teams.editor.created'.tr()
                : 'teams.editor.saved'.tr(),
          ),
        ),
      );
      // La page d'une équipe est une page d'onglet : on y **va**, on ne
      // l'empile pas sur cet écran plein écran (`mobile/CLAUDE.md`, « A shell
      // page is never opened with `context.push`… »).
      GoRouter.of(context).go(Paths.team(saved.slug));
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = getErrorMessage(error, stackTrace);
      });
    }
  }

  // ── Adresse (slug) ─────────────────────────────────────────────────────

  Future<void> _editSlug() async {
    final TeamDetailDto team = _team!;
    if (_saving || _blocked) return;
    if (_dirty && !await _confirmDiscard()) return;
    if (!mounted) return;
    final String? slug = await showSlugEditSheet(
      context,
      team.slug,
      fieldKey: keys.teamEditor.slugField,
      saveKey: keys.teamEditor.slugSave,
      hint: 'teams.editor.slugHint'.tr(),
    );
    if (slug == null || slug == team.slug || !mounted) return;
    // Une feuille a rendu la main : un autre geste a pu partir.
    if (_saving || _blocked) return;
    setState(() {
      _renaming = true;
      _error = null;
    });
    final TeamRepository teams = ref.read(teamRepositoryProvider);
    final ProviderContainer container = ProviderScope.containerOf(
      context,
      listen: false,
    );
    try {
      final TeamDetailDto updated = await teams.changeTeamSlug(team.slug, slug);
      // L'ancienne adresse et la nouvelle : les deux fiches sont à relire.
      notifyTeamChanged(container, team.slug);
      notifyTeamChanged(container, updated.slug);
      if (!mounted) return;
      _saved = true;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text('rides.editor.slugSaved'.tr())));
      // La pile repart de la nouvelle adresse : équipe, hub, paramètres.
      context.go(Paths.teamSettings(updated.slug));
    } catch (error, stackTrace) {
      if (mounted) setState(() => _error = getErrorMessage(error, stackTrace));
    } finally {
      if (mounted) setState(() => _renaming = false);
    }
  }

  // ── Visibilité ─────────────────────────────────────────────────────────

  /// La visibilité se modifie si l'équipe y est autorisée, ou pour l'admin de
  /// plateforme — la règle de `TeamService.updateTeam`.
  bool get _visibilityEditable =>
      (_team?.visibilityEditable ?? false) || widget.platformAdmin;

  Future<void> _pickVisibility() async {
    final Visibility? picked = await showTeamVisibilitySheet(
      context,
      current: _form.visibility,
    );
    if (picked == null || !mounted) return;
    _update(_form.copyWith(visibility: picked));
  }

  // ── Supprimer ──────────────────────────────────────────────────────────

  Future<void> _delete() async {
    final TeamDetailDto team = _team!;
    if (_saving || _blocked) return;
    final bool confirmed = await confirmDestructive(
      context,
      title: 'teams.editor.danger.deleteTitle'.tr(),
      message: 'teams.editor.danger.deleteWarning'.tr(
        namedArgs: <String, String>{'teamName': team.name},
      ),
      confirmLabel: 'teams.editor.danger.confirmDelete'.tr(),
    );
    if (!confirmed || !mounted) return;
    // La confirmation a rendu la main : un autre geste a pu partir.
    if (_saving || _blocked) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    final TeamRepository teams = ref.read(teamRepositoryProvider);
    final ProviderContainer container = ProviderScope.containerOf(
      context,
      listen: false,
    );
    try {
      await teams.deleteTeam(team.slug);
      // Tout ce que l'équipe portait a disparu avec elle.
      notifyTeamChanged(container, team.slug, contentScopeChanged: true);
      if (!mounted) return;
      _saved = true;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('teams.editor.danger.deleted'.tr())),
      );
      GoRouter.of(context).go(Paths.teams());
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = getErrorMessage(error, stackTrace);
      });
    }
  }

  // ── Écran ──────────────────────────────────────────────────────────────

  Widget _switchRow({
    required Key key,
    required String label,
    required String hint,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool available = true,
  }) {
    return PdlSettingRow(
      padding: EdgeInsets.zero,
      title: label,
      subtitle: hint,
      trailing: PdlSwitch(
        key: key,
        value: value,
        semanticLabel: label,
        onChanged: _frozen || !available ? null : onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final PdlTypography t = context.pdlText;
    final bool busy = _saving || _blocked;
    final TeamDetailDto? team = _team;

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
              key: keys.teamEditor.saveButton,
              label: team == null
                  ? 'teams.editor.create'.tr()
                  : 'routes.editor.save'.tr(),
              loading: _saving,
              loadingLabel: 'routes.editor.saving'.tr(),
              enabled: !_blocked,
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
                    key: keys.teamEditor.errorBanner,
                    tone: PdlBannerTone.danger,
                    icon: PdlIcons.error,
                    message: _error!,
                    onDismiss: () => setState(() => _error = null),
                    dismissSemanticLabel: 'common.close'.tr(),
                  ),
                  const SizedBox(height: PdlSpacing.section),
                ],

                // ── Nom ──
                TextField(
                  key: keys.teamEditor.nameField,
                  controller: _name,
                  enabled: !_frozen,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: <TextInputFormatter>[
                    LengthLimitingTextInputFormatter(kTeamNameMaxLength),
                  ],
                  style: t.bodyStrong,
                  decoration: InputDecoration(
                    labelText: 'teams.editor.name'.tr(),
                    hintText: 'teams.editor.namePlaceholder'.tr(),
                    errorText: _showErrors && !_form.nameValid
                        ? 'teams.editor.nameError'.tr()
                        : null,
                  ),
                ),
                if (team != null)
                  PdlSettingRow(
                    key: keys.teamEditor.slugRow,
                    padding: EdgeInsets.zero,
                    icon: PdlIcons.link,
                    title: 'rides.editor.slug'.tr(),
                    subtitle: team.slug,
                    // Le changement d'adresse en cours se voit sur sa ligne.
                    trailing: _renaming
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator.adaptive(),
                          )
                        : null,
                    onTap: busy ? null : _editSlug,
                  ),
                const SizedBox(height: PdlSpacing.section),

                // ── Description ── Sans image à la création : l'upload
                // exige une équipe.
                EditorSection(
                  title: 'teams.editor.description'.tr(),
                  child: RichMarkdownEditorField(
                    fieldKey: keys.teamEditor.markdownField,
                    controller: _markdown,
                    title: 'teams.editor.description'.tr(),
                    hintText: 'teams.editor.descriptionPlaceholder'.tr(),
                    images: _form.media.assets.images,
                    enabled: !_frozen,
                    imageBusy: _uploading,
                    onInsertImage: team == null ? null : addImage,
                    errorText: _form.markdownValid
                        ? null
                        : 'rides.editor.markdownTooLong'.tr(),
                  ),
                ),
                if (team != null)
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

                // ── Localisation ──
                EditorSection(
                  title: 'geocoder.label'.tr(),
                  child: PdlSettingRow(
                    key: keys.teamEditor.locationRow,
                    padding: EdgeInsets.zero,
                    icon: PdlIcons.place,
                    title: _locationTitle(),
                    subtitle: 'teams.editor.locationHint'.tr(),
                    trailing: _locating
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator.adaptive(),
                          )
                        // Figée, la position ne s'efface pas : pas de croix.
                        : _form.location == null || _frozen
                        ? null
                        : EditorClearButton(
                            key: keys.teamEditor.locationClear,
                            onTap: _clearPlace,
                          ),
                    onTap: busy ? null : _pickPlace,
                  ),
                ),

                // ── Fuseau ──
                EditorSection(
                  title: 'teams.editor.timezone'.tr(),
                  child: PdlSettingRow(
                    key: keys.teamEditor.timezoneRow,
                    padding: EdgeInsets.zero,
                    icon: PdlIcons.time,
                    title: _form.timezone,
                    subtitle: 'teams.editor.timezoneHint'.tr(),
                    onTap: busy ? null : _pickTimezone,
                  ),
                ),

                // ── Visibilité ── La seule ligne de la section « Paramètres
                // plateforme » du site (ledger `MOB-171`) : modifiable si
                // l'équipe y est autorisée, sinon lue.
                if (team != null)
                  EditorSection(
                    title: 'teams.editor.visibility'.tr(),
                    child: _visibilityEditable
                        ? PdlSettingRow(
                            key: keys.teamEditor.visibilityRow,
                            padding: EdgeInsets.zero,
                            icon: teamVisibilityIcon(_form.visibility),
                            title: teamVisibilityLabel(_form.visibility),
                            subtitle: 'teams.editor.visibilityHint'.tr(),
                            onTap: busy ? null : _pickVisibility,
                          )
                        : PdlSettingRow(
                            key: keys.teamEditor.visibilityRow,
                            padding: EdgeInsets.zero,
                            title: 'teams.editor.visibilityLocked'.tr(),
                            trailing: VisibilityBadge(
                              key: keys.teamEditor.visibilityBadge,
                              visibility: _form.visibility,
                            ),
                          ),
                  ),

                // ── Modules ── Sans parcours, ni sorties ni voyages.
                EditorSection(
                  title: 'teams.editor.modules'.tr(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _switchRow(
                        key: keys.teamEditor.enableRoutes,
                        label: 'teams.editor.enableRoutes'.tr(),
                        hint: 'teams.editor.enableRoutesHint'.tr(),
                        value: _form.enableRoutes,
                        onChanged: (bool v) => _update(_form.withRoutes(v)),
                      ),
                      _switchRow(
                        key: keys.teamEditor.enableRides,
                        label: 'teams.editor.enableRides'.tr(),
                        hint: 'teams.editor.enableRidesHint'.tr(),
                        value: _form.enableRides,
                        available: _form.enableRoutes,
                        onChanged: (bool v) =>
                            _update(_form.copyWith(enableRides: v)),
                      ),
                      _switchRow(
                        key: keys.teamEditor.enableTrips,
                        label: 'teams.editor.enableTrips'.tr(),
                        hint: 'teams.editor.enableTripsHint'.tr(),
                        value: _form.enableTrips,
                        available: _form.enableRoutes,
                        onChanged: (bool v) =>
                            _update(_form.copyWith(enableTrips: v)),
                      ),
                      _switchRow(
                        key: keys.teamEditor.enablePosts,
                        label: 'teams.editor.enablePosts'.tr(),
                        hint: 'teams.editor.enablePostsHint'.tr(),
                        value: _form.enablePosts,
                        onChanged: (bool v) =>
                            _update(_form.copyWith(enablePosts: v)),
                      ),
                      _switchRow(
                        key: keys.teamEditor.enableAds,
                        label: 'teams.editor.enableAds'.tr(),
                        hint: 'teams.editor.enableAdsHint'.tr(),
                        value: _form.enableAds,
                        onChanged: (bool v) =>
                            _update(_form.copyWith(enableAds: v)),
                      ),
                      _switchRow(
                        key: keys.teamEditor.enableMemberDirectory,
                        label: 'teams.editor.enableMemberDirectory'.tr(),
                        hint: 'teams.editor.enableMemberDirectoryHint'.tr(),
                        value: _form.enableMemberDirectory,
                        onChanged: (bool v) =>
                            _update(_form.copyWith(enableMemberDirectory: v)),
                      ),
                      _switchRow(
                        key: keys.teamEditor.postsAsTeamByDefault,
                        label: 'teams.editor.postsAsTeamByDefault'.tr(),
                        hint: 'teams.editor.postsAsTeamByDefaultHint'.tr(),
                        value: _form.postsAsTeamByDefault,
                        available: _form.enablePosts,
                        onChanged: (bool v) =>
                            _update(_form.copyWith(postsAsTeamByDefault: v)),
                      ),
                    ],
                  ),
                ),

                // ── Webhook ── Une feuille : il a son propre
                // « Enregistrer ».
                if (team != null)
                  EditorSection(
                    title: 'teams.editor.webhook.title'.tr(),
                    child: PdlSettingRow(
                      key: keys.teamEditor.webhookRow,
                      padding: EdgeInsets.zero,
                      icon: PdlIcons.webhook,
                      title: 'teams.editor.webhook.title'.tr(),
                      subtitle: 'teams.editor.webhook.rowHint'.tr(),
                      onTap: busy
                          ? null
                          : () => showTeamWebhookSheet(context, team.slug),
                    ),
                  ),

                // ── Zone de danger ──
                if (team != null)
                  PdlDangerZone(
                    padding: const EdgeInsets.only(top: PdlSpacing.section),
                    title: 'teams.editor.danger.title'.tr(),
                    consequence: 'teams.editor.danger.description'.tr(),
                    actionLabel: 'teams.editor.danger.delete'.tr(),
                    actionKey: keys.teamEditor.deleteButton,
                    busy: _deleting,
                    busyLabel: 'teams.editor.danger.deleting'.tr(),
                    onAction: _saving || _locating || _uploading || _renaming
                        ? null
                        : _delete,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
