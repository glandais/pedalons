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
import '../../../rides/presentation/widgets/editor/editor_section.dart';
import '../../../rides/presentation/widgets/editor/rich_markdown_editor_field.dart';
import '../../../rides/presentation/widgets/editor/ride_group_editor.dart'
    show EditorClearButton;
import '../../data/team_repository.dart';
import '../../domain/team_form.dart';
import '../../providers/team_change.dart';

/// Créer une équipe — le pendant mobile de `CreateTeamPage` du site
/// (docs/LEDGER_*.md MOB-165) : nom, description, localisation, fuseau et
/// modules. Ouvert à toute personne connectée ; ce que le serveur refuse
/// (`TEAM_CREATION_DISABLED`, `USER_TEAM_LIMIT_REACHED`) se lit dans le
/// bandeau, la saisie gardée.
///
/// Comme au site, ni logo ni image à la création (l'upload exige une équipe),
/// pas de slug (le serveur le génère) et pas de visibilité (une équipe naît
/// `TEAM`).
///
/// Le même écran portera les paramètres d'une équipe (ledger `MOB-166`) :
/// [_TeamEditorForm] part d'un [TeamForm] qu'on lui donne, et
/// `TeamForm.fromTeam` existe déjà.
class TeamEditorPage extends ConsumerWidget {
  const TeamEditorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
}

class _TeamEditorForm extends ConsumerStatefulWidget {
  const _TeamEditorForm({
    super.key,
    required this.initial,
    required this.title,
  });

  final TeamForm initial;
  final String title;

  @override
  ConsumerState<_TeamEditorForm> createState() => _TeamEditorFormState();
}

class _TeamEditorFormState extends ConsumerState<_TeamEditorForm> {
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

  bool _saving = false;
  bool _saved = false;
  bool _showErrors = false;
  String? _error;

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

  // ── Localisation ───────────────────────────────────────────────────────

  /// Choisit une adresse et sa position par le sélecteur commun. Un échec
  /// laisse la position précédente en place, et le dit.
  Future<void> _pickPlace() async {
    if (_locating || _saving) return;
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

  void _clearPlace() => setState(() {
    _pickedPlaceName = null;
    _form = _form.copyWith(location: () => null);
  });

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
    if (_saving || _locating) return;
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
    });
    final TeamRepository teams = ref.read(teamRepositoryProvider);
    // Pris avant l'`await` : l'écran peut être démonté avant la réponse, et
    // l'équipe est créée quand même.
    final ProviderContainer container = ProviderScope.containerOf(
      context,
      listen: false,
    );
    try {
      final TeamDetailDto saved = await teams.createTeam(_form.toRequest());
      notifyTeamChanged(container, saved.slug);
      if (!mounted) return;
      _saved = true;
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text('teams.editor.created'.tr())));
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
        onChanged: _saving || !available ? null : onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final PdlTypography t = context.pdlText;
    final bool busy = _saving || _locating;

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
              label: 'teams.editor.create'.tr(),
              loading: _saving,
              loadingLabel: 'routes.editor.saving'.tr(),
              enabled: !_locating,
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
                  enabled: !_saving,
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
                    enabled: !_saving,
                    errorText: _form.markdownValid
                        ? null
                        : 'rides.editor.markdownTooLong'.tr(),
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
                        : _form.location == null
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
