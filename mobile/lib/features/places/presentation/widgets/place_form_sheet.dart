import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../keys.dart';
import '../../../geocoding/presentation/geocoded_place_picker.dart';
import '../../../rides/presentation/widgets/editor/ride_group_editor.dart'
    show EditorClearButton;
import '../../data/places_repository.dart';
import '../../domain/place_form.dart';
import '../../providers/places_provider.dart';

/// Ouvre le formulaire d'un lieu de [teamSlug] : un nouveau lieu, ou [place]
/// à modifier (docs/LEDGER_*.md MOB-168). Rend le lieu enregistré, ou `null`
/// si la feuille a été fermée sans enregistrer.
Future<PlaceDetailDto?> showPlaceFormSheet(
  BuildContext context,
  String teamSlug, {
  PlaceDetailDto? place,
}) {
  return PdlFullSheet.show<PlaceDetailDto>(
    context: context,
    builder: (BuildContext _) =>
        PlaceFormSheet(teamSlug: teamSlug, place: place),
  );
}

/// Le formulaire d'un lieu — le pendant mobile de `PlaceForm` du site : nom,
/// adresse, lien, position et les deux usages (départ, arrivée).
///
/// Les erreurs de champ n'apparaissent qu'après une tentative
/// d'enregistrement ; ce que le serveur refuse se lit dans un bandeau, la
/// saisie gardée.
class PlaceFormSheet extends ConsumerStatefulWidget {
  const PlaceFormSheet({super.key, required this.teamSlug, this.place});

  final String teamSlug;

  /// Le lieu à modifier ; `null` pour un nouveau lieu.
  final PlaceDetailDto? place;

  @override
  ConsumerState<PlaceFormSheet> createState() => _PlaceFormSheetState();
}

class _PlaceFormSheetState extends ConsumerState<PlaceFormSheet> {
  late PlaceForm _form = widget.place == null
      ? PlaceForm.initial()
      : PlaceForm.fromPlace(widget.place!);

  late final TextEditingController _name = TextEditingController(
    text: _form.name,
  );
  late final TextEditingController _address = TextEditingController(
    text: _form.address,
  );
  late final TextEditingController _link = TextEditingController(
    text: _form.link,
  );

  bool _saving = false;
  bool _showErrors = false;
  String? _error;

  /// La position de l'adresse choisie est en cours de lecture :
  /// « Enregistrer » attend, sans quoi l'ancienne position partirait.
  bool _locating = false;

  /// Le nom de l'adresse choisie dans cette feuille ; une position déjà
  /// enregistrée n'en a pas.
  String? _pickedPlaceName;

  bool get _editing => widget.place != null;

  @override
  void initState() {
    super.initState();
    _name.addListener(
      () => setState(() => _form = _form.copyWith(name: _name.text)),
    );
    _address.addListener(
      () => setState(() => _form = _form.copyWith(address: _address.text)),
    );
    _link.addListener(
      () => setState(() => _form = _form.copyWith(link: _link.text)),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    if (_saving || _locating) return;
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
      // La position précédente reste en place, et l'écran le dit.
      case GeocodedPlaceFailure(:final GeocodeFailure reason):
        setState(() => _error = reason.message);
      case GeocodedPlace():
        setState(() {
          _pickedPlaceName = pick.name;
          _form = _form.copyWith(location: () => pick.coordinates);
        });
    }
  }

  void _clearLocation() => setState(() {
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
    final PlacesRepository repository = ref.read(placesRepositoryProvider);
    // Pris avant l'`await` : la feuille peut être fermée avant la réponse.
    final ProviderContainer container = ProviderScope.containerOf(
      context,
      listen: false,
    );
    final NavigatorState navigator = Navigator.of(context);
    final PlaceRequest request = _form.toRequest();
    final PlaceDetailDto? place = widget.place;
    try {
      final PlaceDetailDto saved = place == null
          ? await repository.create(widget.teamSlug, request)
          : await repository.update(widget.teamSlug, place.id, request);
      notifyPlacesChanged(
        container,
        place == null
            ? PlaceChange.created(widget.teamSlug, saved)
            : PlaceChange.updated(widget.teamSlug, saved),
      );
      if (mounted) navigator.pop(saved);
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = getErrorMessage(error, stackTrace);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Le pied (« Enregistrer ») reste au-dessus du clavier.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: PdlFullSheet(
        key: keys.teamPlaces.formSheet,
        title: _editing ? 'places.form.editTitle'.tr() : 'places.add'.tr(),
        headerAction: PdlButton(
          key: keys.teamPlaces.formClose,
          label: 'common.close'.tr(),
          variant: PdlButtonVariant.text,
          size: PdlButtonSize.sm,
          onPressed: () => Navigator.of(context).pop(),
        ),
        footer: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(PdlSpacing.section),
            child: PdlButton(
              key: keys.teamPlaces.formSubmit,
              label: _editing
                  ? 'routes.editor.save'.tr()
                  : 'places.form.create'.tr(),
              loading: _saving,
              loadingLabel: 'routes.editor.saving'.tr(),
              enabled: !_locating,
              fullWidth: true,
              onPressed: _save,
            ),
          ),
        ),
        bodyBuilder: (BuildContext context, ScrollController controller) {
          return ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(
              PdlSpacing.section,
              0,
              PdlSpacing.section,
              PdlSpacing.section,
            ),
            children: _fields(),
          );
        },
      ),
    );
  }

  List<Widget> _fields() {
    final String optionalError = 'places.form.optionalError'.tr();
    return <Widget>[
      if (_error != null) ...<Widget>[
        PdlBanner(
          key: keys.teamPlaces.formErrorBanner,
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
        key: keys.teamPlaces.formName,
        controller: _name,
        enabled: !_saving,
        textCapitalization: TextCapitalization.sentences,
        inputFormatters: <TextInputFormatter>[
          LengthLimitingTextInputFormatter(kPlaceTextMaxLength),
        ],
        decoration: InputDecoration(
          labelText: 'places.form.name'.tr(),
          hintText: 'places.form.namePlaceholder'.tr(),
          errorText: _showErrors && !_form.nameValid
              ? 'places.form.nameError'.tr()
              : null,
        ),
      ),
      const SizedBox(height: PdlSpacing.section),

      // ── Adresse ── Facultative ; vide, elle ne part pas.
      TextField(
        key: keys.teamPlaces.formAddress,
        controller: _address,
        enabled: !_saving,
        keyboardType: TextInputType.streetAddress,
        textCapitalization: TextCapitalization.sentences,
        inputFormatters: <TextInputFormatter>[
          LengthLimitingTextInputFormatter(kPlaceTextMaxLength),
        ],
        decoration: InputDecoration(
          labelText: 'places.form.address'.tr(),
          hintText: 'places.form.addressPlaceholder'.tr(),
          errorText: _showErrors && !_form.addressValid ? optionalError : null,
        ),
      ),
      const SizedBox(height: PdlSpacing.section),

      // ── Lien ── Facultatif ; vide, il ne part pas.
      TextField(
        key: keys.teamPlaces.formLink,
        controller: _link,
        enabled: !_saving,
        keyboardType: TextInputType.url,
        autocorrect: false,
        enableSuggestions: false,
        inputFormatters: <TextInputFormatter>[
          LengthLimitingTextInputFormatter(kPlaceTextMaxLength),
        ],
        decoration: InputDecoration(
          labelText: 'places.form.link'.tr(),
          hintText: 'places.form.linkPlaceholder'.tr(),
          errorText: _showErrors && !_form.linkValid ? optionalError : null,
        ),
      ),
      const SizedBox(height: PdlSpacing.chipGap),

      // ── Localisation ── La recherche d'adresse commune ; effaçable.
      PdlSettingRow(
        key: keys.teamPlaces.formLocation,
        padding: EdgeInsets.zero,
        icon: PdlIcons.place,
        title: _locationTitle(),
        subtitle: 'places.form.locationHint'.tr(),
        trailing: _locating
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator.adaptive(),
              )
            : _form.location == null
            ? null
            : EditorClearButton(
                key: keys.teamPlaces.formLocationClear,
                onTap: _clearLocation,
              ),
        onTap: _saving ? null : _pickLocation,
      ),

      // ── Usages ──
      PdlSettingRow(
        padding: EdgeInsets.zero,
        title: 'places.form.startPlace'.tr(),
        trailing: PdlSwitch(
          key: keys.teamPlaces.formStartSwitch,
          value: _form.startPlace,
          semanticLabel: 'places.form.startPlace'.tr(),
          onChanged: _saving
              ? null
              : (bool value) =>
                    setState(() => _form = _form.copyWith(startPlace: value)),
        ),
      ),
      PdlSettingRow(
        padding: EdgeInsets.zero,
        title: 'places.form.endPlace'.tr(),
        trailing: PdlSwitch(
          key: keys.teamPlaces.formEndSwitch,
          value: _form.endPlace,
          semanticLabel: 'places.form.endPlace'.tr(),
          onChanged: _saving
              ? null
              : (bool value) =>
                    setState(() => _form = _form.copyWith(endPlace: value)),
        ),
      ),
    ];
  }
}
