import 'package:easy_localization/easy_localization.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../api/generated/export.dart';
import '../material.dart';
import '../units/unit_system.dart';
import 'zone_label.dart';

/// **Le** point d'entrée du formatage de l'app.
///
/// Il n'y en a pas d'autre : pas de `toStringAsFixed` dans une page, pas de
/// `'km'` codé en dur dans un widget, pas de second fichier de libellés de
/// filtres. Tout ce qui se lit à l'écran sous forme de nombre, d'unité, de
/// date ou de prix passe par ici.
///
/// Trois règles typographiques, appliquées sans exception :
///
/// * **espace insécable** (U+00A0) entre la valeur et son unité — « 46,3 km »
///   ne se coupe jamais en fin de ligne ;
/// * **espace insécable normale** (U+00A0) comme séparateur de milliers —
///   « 1 240 m », « 1 200,00 € ». `NumberFormat` du français produit l'espace
///   fine (U+202F), illisible en gras sur une carte : [_groupingSpace] la
///   remplace à la sortie de chaque nombre et de chaque prix (décision du
///   2026-11-12, KIT §9). Les heures anglaises (« 6:30 PM ») ne passent pas
///   par là et gardent l'espace de CLDR ;
/// * la locale est celle d'`Intl` — les tests peuvent donc la fixer avec
///   `Intl.withLocale`, et rien n'est mis en cache au-delà de sa locale.
///
/// Les unités viennent de `UserDto.unitSystem` via `unitSystemProvider`. Elles
/// se passent explicitement en argument : un formateur qui irait lire un
/// provider tout seul ne serait plus testable, et une valeur par défaut
/// implicite finirait par afficher des kilomètres à un utilisateur américain.
/// Le défaut [UnitSystem.metric] n'est là que pour les rares appels qui n'ont
/// aucun utilisateur sous la main.
class AppFormatters {
  AppFormatters._();

  /// Espace insécable, entre une valeur et son unité.
  static const String nbsp = ' ';

  /// Espace fine insécable : ce que `NumberFormat` du français met entre les
  /// milliers, et que l'app n'affiche plus (voir [_groupingSpace]).
  static const String narrowNbsp = ' ';

  /// Séparateur de milliers affiché : l'espace insécable normale, comme
  /// devant l'unité (décision du 2026-11-12, KIT §9).
  static String _groupingSpace(String formatted) =>
      formatted.replaceAll(narrowNbsp, nbsp);

  // ─────────────────────────────────────────────────────────────────────────
  // Nombres
  // ─────────────────────────────────────────────────────────────────────────

  static final Map<String, NumberFormat> _decimalCache =
      <String, NumberFormat>{};

  /// `NumberFormat` de la locale courante, à nombre de décimales fixé.
  ///
  /// Mis en cache **par locale**, sans quoi un changement de langue
  /// continuerait d'afficher les séparateurs de l'ancienne.
  static NumberFormat _decimal(int fractionDigits) {
    final String locale = Intl.getCurrentLocale();
    return _decimalCache.putIfAbsent(
      '$locale/$fractionDigits',
      () => NumberFormat.decimalPattern(locale)
        ..minimumFractionDigits = fractionDigits
        ..maximumFractionDigits = fractionDigits,
    );
  }

  /// Nombre seul, sans unité.
  static String formatNumber(num value, {int fractionDigits = 0}) =>
      _groupingSpace(_decimal(fractionDigits).format(value));

  /// Assemble une valeur et son unité avec l'espace insécable qui les lie.
  static String withUnit(String value, String symbol) => '$value$nbsp$symbol';

  // ─────────────────────────────────────────────────────────────────────────
  // Distances, dénivelés, vitesses, pentes
  // ─────────────────────────────────────────────────────────────────────────

  /// Distance d'un parcours, au dixième près : « 46,3 km », « 28.8 mi ».
  ///
  /// L'entrée est **toujours en mètres**, comme l'API.
  static String formatDistance(
    num meters, [
    UnitSystem units = UnitSystem.metric,
  ]) => withUnit(
    formatNumber(units.longDistance(meters), fractionDigits: 1),
    units.longDistanceSymbol,
  );

  /// Distance arrondie, pour les bornes de filtre et les puces : « 30 km ».
  static String formatDistanceRounded(
    num meters, [
    UnitSystem units = UnitSystem.metric,
  ]) => withUnit(
    formatNumber(units.longDistance(meters)),
    units.longDistanceSymbol,
  );

  /// Dénivelé ou altitude, à l'unité près : « 9 840 m », « 32 283 ft ».
  static String formatElevation(
    num meters, [
    UnitSystem units = UnitSystem.metric,
  ]) => withUnit(
    formatNumber(units.shortDistance(meters)),
    units.shortDistanceSymbol,
  );

  /// Dénivelé positif, suffixé « D+ ».
  static String formatElevationGain(
    num meters, [
    UnitSystem units = UnitSystem.metric,
  ]) => '${formatElevation(meters, units)} ${'units.elevationGain'.tr()}';

  /// Altitude d'un point du profil : même rendu qu'un dénivelé.
  static String formatAltitude(
    num meters, [
    UnitSystem units = UnitSystem.metric,
  ]) => formatElevation(meters, units);

  /// Vitesse moyenne d'un groupe : « 25 km/h », « 16 mph ».
  ///
  /// L'entrée est en **km/h**, comme `RideGroupDto.averageSpeed`.
  static String formatSpeed(
    num kilometersPerHour, [
    UnitSystem units = UnitSystem.metric,
  ]) =>
      withUnit(formatNumber(units.speed(kilometersPerHour)), units.speedSymbol);

  /// Température, au degré près : « 14 °C », « 57 °F ».
  ///
  /// L'entrée est en **°C**, comme les prévisions du contrat. L'arrondi se
  /// fait avant le formatage, ce qui évite le « -0 °C » d'un -0,3 arrondi.
  static String formatTemperature(
    num celsius, [
    UnitSystem units = UnitSystem.metric,
  ]) => withUnit(
    formatNumber(units.temperature(celsius).round()),
    units.temperatureSymbol,
  );

  /// Plage de températures : « 12–18 °C », ou une seule valeur quand les
  /// deux bornes s'arrondissent au même degré.
  static String formatTemperatureRange(
    num minCelsius,
    num maxCelsius, [
    UnitSystem units = UnitSystem.metric,
  ]) {
    final int low = units.temperature(minCelsius).round();
    final int high = units.temperature(maxCelsius).round();
    if (low == high) return formatTemperature(minCelsius, units);
    return withUnit(
      '${formatNumber(low)}–${formatNumber(high)}',
      units.temperatureSymbol,
    );
  }

  /// Hauteur de précipitation : « 0,4 mm » au dixième de millimètre, ou
  /// « 0.05 in » au centième de pouce en impérial, comme le site
  /// (docs/LEDGER_*.md MOB-139, D7). L'entrée est **toujours en mm**, comme
  /// les prévisions du contrat.
  static String formatPrecipitation(
    num millimeters, [
    UnitSystem units = UnitSystem.metric,
  ]) => withUnit(
    formatNumber(
      units.precipitation(millimeters),
      fractionDigits: units.precipitationFractionDigits,
    ),
    units.precipitationSymbol,
  );

  /// Pourcentage entier : « 60 % ».
  static String formatPercent(num percent) =>
      withUnit(formatNumber(percent.round()), UnitSymbols.percent);

  /// Pente, au dixième de point près : « 6,5 % ». Sans conversion : un
  /// pourcentage est un rapport, il ne dépend pas du système d'unités.
  static String formatGrade(num percent) =>
      withUnit(formatNumber(percent, fractionDigits: 1), UnitSymbols.percent);

  // ─────────────────────────────────────────────────────────────────────────
  // Poids de fichier
  // ─────────────────────────────────────────────────────────────────────────

  static const List<String> _fileSizeUnits = <String>[
    'units.byte',
    'units.kilobyte',
    'units.megabyte',
    'units.gigabyte',
  ];

  /// Poids d'un fichier, en unités décimales comme les gestionnaires de
  /// fichiers des deux plateformes : « 240 ko », « 2,4 Mo », « 240 kB ».
  ///
  /// Une décimale sous 10, aucune au-delà : de quoi distinguer deux fichiers,
  /// pas une mesure. « 1 000 ko » n'existe pas — on passe à l'unité suivante.
  /// docs/LEDGER_*.md API-7.
  static String formatFileSize(int bytes) {
    double value = bytes.toDouble();
    int unit = 0;
    while (unit < _fileSizeUnits.length - 1 && value.round() >= 1000) {
      value /= 1000;
      unit++;
    }
    final int fractionDigits = unit == 0 || value >= 9.95 ? 0 : 1;
    String number = formatNumber(value, fractionDigits: fractionDigits);
    // « 1,0 Mo » se lit « 1 Mo » : la décimale nulle ne dit rien.
    if (fractionDigits == 1 && value.toStringAsFixed(1).endsWith('.0')) {
      number = formatNumber(value);
    }
    return withUnit(number, _fileSizeUnits[unit].tr());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Prix
  // ─────────────────────────────────────────────────────────────────────────

  static final Map<String, NumberFormat> _currencyCache =
      <String, NumberFormat>{};

  /// Montant seul, dans la langue de l'interface : « 1 200,00 € »,
  /// « €1,200.00 » — toujours deux décimales, comme la carte du site
  /// (docs/LEDGER_*.md MOB-139, D26). Mis en cache par locale, comme
  /// [_decimal].
  static String formatAmount(num price) {
    final String locale = Intl.getCurrentLocale();
    return _groupingSpace(
      _currencyCache
          .putIfAbsent(
            locale,
            () => NumberFormat.currency(
              locale: locale,
              symbol: '€',
              decimalDigits: 2,
            ),
          )
          .format(price),
    );
  }

  /// Le prix d'une annonce, décomposé pour l'affichage.
  ///
  /// La période n'est pas concaténée au montant : elle se rend dans un
  /// `TextSpan` distinct, en graisse 400 et en couleur atténuée, tandis que le
  /// montant reste en 600. [FormattedPrice] porte donc les deux morceaux
  /// séparément — ce qui permet à `core/utils` de ne rien savoir du thème ni
  /// de `core/pdl`.
  ///
  /// `price == null` n'est **jamais** un tiret : c'est « Prix à négocier »,
  /// une information, pas une absence.
  static FormattedPrice formatPrice(num? price, {String? rentalPeriod}) {
    if (price == null) {
      return FormattedPrice(
        amount: 'ads.detail.priceNegotiable'.tr(),
        isNegotiable: true,
      );
    }
    return FormattedPrice(
      amount: formatAmount(price),
      period: rentalPeriod == null
          ? null
          : '/ ${'ads.rentalPeriod.$rentalPeriod'.tr().toLowerCase()}',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Jours et mois
  // ─────────────────────────────────────────────────────────────────────────

  /// Nom court du jour de la semaine (1 = lundi, 7 = dimanche).
  static String dayAbbrev(int weekday, {BuildContext? context}) {
    if (weekday < 1 || weekday > 7) return '?';
    // 2026-01-05 est un lundi.
    final DateTime date = DateTime(2026, 1, 4 + weekday);
    return DateFormat.E().format(date);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Rôles et revêtements
  // ─────────────────────────────────────────────────────────────────────────

  static String roleName(String role) => tr('roles.${role.toLowerCase()}');

  static String surfaceName(String surface) =>
      tr('surfaces.${surface.toLowerCase()}');

  // ─────────────────────────────────────────────────────────────────────────
  // Dates et heures
  //
  // Deux natures d'instants (docs/LEDGER_*.md API-60, plan §7) :
  //
  // * un **horodatage** (création, commentaire, notification reçue, « il y a
  //   2 h », date d'une annonce) se lit dans le **fuseau d'affichage** du
  //   lecteur : la préférence `UserDto.timezone` quand il en a choisi une, le
  //   fuseau de l'appareil sinon — la règle du web (`useEffectiveTimezone`),
  //   docs/LEDGER_*.md API-15. C'est [toDisplayTime] / [tryParseDisplayTime] ;
  // * un **rendez-vous** (départ de sortie, de groupe, d'étape, retour estimé,
  //   dates d'un voyage, date d'une publication) se lit dans le **fuseau de
  //   l'entité** (`RideDto.timezone`…), avec une mention quand son décalage
  //   diffère de celui du lecteur. C'est [toZoneTime] / [tryParseZoneTime], puis
  //   [zoneMention] et [formatZoneMention].
  //
  // Les deux rendent une heure murale que les formateurs ci-dessous prennent
  // telle quelle. « Aujourd'hui », « demain », la grille du calendrier et le
  // regroupement par jour restent relatifs au lecteur.
  //
  // Le fuseau est un réglage **global**, comme la locale d'`Intl` : `app.dart`
  // le pose à chaque reconstruction depuis l'utilisateur connecté. Le passer
  // en argument, comme les unités, obligerait chaque écran à le relire alors
  // qu'il ne varie qu'avec la session.
  // ─────────────────────────────────────────────────────────────────────────

  static tz.Location? _displayZone;
  static String? _displayZoneName;
  static bool _zonesLoaded = false;

  /// Les fuseaux d'entité déjà résolus ; `null` pour un nom inconnu.
  static final Map<String, tz.Location?> _entityZones =
      <String, tz.Location?>{};

  /// Les noms IANA que l'app sait appliquer, triés — ceux que propose le
  /// sélecteur de fuseau du profil. Charge la base au premier appel.
  static List<String> timezoneNames() {
    _ensureZonesLoaded();
    final List<String> names =
        tz.timeZoneDatabase.locations.keys
            .where((String name) => name.contains('/') || name == 'UTC')
            .toList()
          ..sort();
    return names;
  }

  static void _ensureZonesLoaded() {
    if (_zonesLoaded) return;
    tz_data.initializeTimeZones();
    _zonesLoaded = true;
  }

  /// Pose le fuseau d'affichage : un nom IANA (« Europe/Paris »), ou `null`
  /// pour le fuseau de l'appareil. Un nom que la base embarquée ne connaît pas
  /// retombe sur l'appareil plutôt que d'échouer : le serveur valide contre la
  /// base du JDK, qui peut avoir une version d'avance.
  ///
  /// La base se charge au premier nom posé, ou au premier rendez-vous rendu
  /// dans le fuseau de son entité ([toZoneTime]).
  static void setDisplayTimezone(String? name) {
    if (name == _displayZoneName) return;
    _displayZoneName = name;
    if (name == null) {
      _displayZone = null;
      return;
    }
    _displayZone = _lookupZone(name);
  }

  static const Set<String> _utcNames = <String>{
    'UTC',
    'UCT',
    'GMT',
    'Zulu',
    'Etc/UTC',
    'Etc/UCT',
    'Etc/GMT',
    'Etc/Zulu',
  };

  /// Le fuseau IANA [name], ou `null` s'il est inconnu. La base embarquée
  /// (`latest`) ne connaît pas l'alias « UTC », que le serveur peut rendre :
  /// les alias d'UTC se résolvent donc à la main.
  static tz.Location? _lookupZone(String name) {
    _ensureZonesLoaded();
    try {
      return tz.getLocation(name);
    } on tz.LocationNotFoundException {
      return _utcNames.contains(name) ? tz.UTC : null;
    }
  }

  /// Ramène un instant UTC — ce que rend le contrat — à l'**heure murale** du
  /// fuseau d'affichage : un `DateTime` local dont les champs (jour, heure…)
  /// sont ceux qu'on lirait sur une horloge de ce fuseau. Tout le code qui
  /// travaille sur les champs (`DateTime(y, m, d)`, regroupement par jour,
  /// `DateFormat`) reste donc juste sans connaître `package:timezone`.
  ///
  /// Une date non UTC est rendue telle quelle : c'est déjà une heure murale,
  /// et la reconvertir serait la double conversion que le cas de test §5.3-3
  /// traque. « Maintenant » se prend donc par [displayNow], jamais par
  /// `DateTime.now()`.
  ///
  /// Une heure murale ne sert qu'à l'affichage : comparer deux instants se
  /// fait sur les valeurs du contrat (et « passé » vient du serveur, `finished`).
  static DateTime toDisplayTime(DateTime date) {
    if (!date.isUtc) return date;
    final tz.Location? zone = _displayZone;
    if (zone == null) return date.toLocal();
    // Seule approximation : une heure murale qui tombe dans le saut d'heure
    // d'été de l'*appareil* est décalée d'une heure par le constructeur local.
    return _wall(tz.TZDateTime.from(date, zone));
  }

  /// L'heure murale courante du fuseau d'affichage.
  static DateTime displayNow() => toDisplayTime(DateTime.now().toUtc());

  /// L'inverse de [toDisplayTime] : l'instant UTC qu'une heure murale du
  /// fuseau d'affichage désigne — les bornes d'un mois envoyées à l'API.
  static DateTime displayWallClockToUtc(DateTime wall) {
    final tz.Location? zone = _displayZone;
    if (wall.isUtc || zone == null) return wall.toUtc();
    return tz.TZDateTime(
      zone,
      wall.year,
      wall.month,
      wall.day,
      wall.hour,
      wall.minute,
      wall.second,
      wall.millisecond,
      wall.microsecond,
    ).toUtc();
  }

  /// Lit un instant ISO 8601 du contrat et le ramène au fuseau d'affichage ;
  /// `null` pour une valeur absente ou illisible.
  static DateTime? tryParseDisplayTime(String? iso) {
    if (iso == null) return null;
    final DateTime? parsed = DateTime.tryParse(iso);
    return parsed == null ? null : toDisplayTime(parsed);
  }

  /// Le fuseau d'entité nommé [name], ou `null` s'il est inconnu de la base
  /// embarquée (le serveur valide contre celle du JDK, qui peut avoir une
  /// version d'avance). Charge la base au premier appel : un rendez-vous suffit.
  static tz.Location? _entityZone(String? name) {
    if (name == null || name.isEmpty) return null;
    return _entityZones.putIfAbsent(name, () => _lookupZone(name));
  }

  /// Ramène l'instant d'un **rendez-vous** à l'heure murale du fuseau de son
  /// entité [zone] (`RideDto.timezone`…) — docs/LEDGER_*.md API-60. Même
  /// contrat que [toDisplayTime] : une date non UTC est déjà une heure murale
  /// et reste telle quelle. Un fuseau inconnu retombe sur le fuseau
  /// d'affichage, et [zoneMention] ne dit alors rien.
  static DateTime toZoneTime(DateTime instant, String? zone) {
    if (!instant.isUtc) return instant;
    final tz.Location? location = _entityZone(zone);
    if (location == null) return toDisplayTime(instant);
    return _wall(tz.TZDateTime.from(instant, location));
  }

  /// Lit un instant ISO 8601 du contrat et le ramène au fuseau de l'entité
  /// [zone] ; `null` pour une valeur absente ou illisible.
  static DateTime? tryParseZoneTime(String? iso, String? zone) {
    if (iso == null) return null;
    final DateTime? parsed = DateTime.tryParse(iso);
    return parsed == null ? null : toZoneTime(parsed, zone);
  }

  /// L'inverse de [toZoneTime] : l'instant UTC que l'heure murale [wall]
  /// désigne dans le fuseau d'entité [zone] — ce qu'un éditeur montre en
  /// mention « heure de … » pendant qu'on saisit une date (ledger `API-60`).
  /// Un fuseau inconnu retombe sur le fuseau d'affichage, comme [toZoneTime].
  static DateTime zoneWallClockToUtc(DateTime wall, String? zone) {
    if (wall.isUtc) return wall;
    final tz.Location? location = _entityZone(zone);
    if (location == null) return displayWallClockToUtc(wall);
    return tz.TZDateTime(
      location,
      wall.year,
      wall.month,
      wall.day,
      wall.hour,
      wall.minute,
      wall.second,
    ).toUtc();
  }

  static DateTime _wall(tz.TZDateTime wall) => DateTime(
    wall.year,
    wall.month,
    wall.day,
    wall.hour,
    wall.minute,
    wall.second,
    wall.millisecond,
    wall.microsecond,
  );

  /// Vrai quand le fuseau [zone] a, à l'[instant] (UTC), le même décalage
  /// que le fuseau d'affichage du lecteur — la condition pour **taire** la
  /// mention (plan §7) : on compare des décalages, pas des identifiants, si
  /// bien qu'un lecteur à Bruxelles ne voit rien pour une sortie à Paris. Un
  /// fuseau inconnu compte comme identique : on l'a rendu chez le lecteur.
  static bool sameOffsetAt(DateTime instant, String? zone) {
    final tz.Location? location = _entityZone(zone);
    if (location == null) return true;
    final DateTime utc = instant.toUtc();
    final Duration entity = location
        .timeZone(utc.millisecondsSinceEpoch)
        .offset;
    final tz.Location? reader = _displayZone;
    final Duration readerOffset = reader == null
        ? utc.toLocal().timeZoneOffset
        : reader.timeZone(utc.millisecondsSinceEpoch).offset;
    return entity == readerOffset;
  }

  /// « heure de Tokyo » quand le fuseau [zone] du rendez-vous diffère, à son
  /// [instant], de celui du lecteur ; `null` sinon — le cas de presque tout le
  /// monde, presque toujours.
  static String? zoneMention(DateTime instant, String? zone) {
    if (zone == null || sameOffsetAt(instant, zone)) return null;
    final String language = Intl.getCurrentLocale();
    return 'dates.zoneMention'.tr(
      namedArgs: <String, String>{
        'city': zoneCityName(zone, language),
        'ofCity': zoneCityOf(zone, language),
      },
    );
  }

  /// L'heure du lecteur pour le rendez-vous à l'[instant] : « 01:00 », ou
  /// « ven. 01:00 » quand son jour diffère de celui du fuseau [zone].
  static String readerEquivalent(DateTime instant, String? zone) {
    final DateTime utc = instant.toUtc();
    final DateTime reader = toDisplayTime(utc);
    final DateTime entity = toZoneTime(utc, zone);
    final String time = formatTime(reader);
    final bool sameDay =
        reader.year == entity.year &&
        reader.month == entity.month &&
        reader.day == entity.day;
    return sameDay ? time : '${dayAbbrev(reader.weekday)} $time';
  }

  /// La mention complète d'un rendez-vous — « heure de Tokyo (ven. 01:00 chez
  /// vous) » — ou `null` quand le lecteur partage son décalage. C'est la
  /// seconde ligne d'une carte, et ce qui suit « · » dans un détail.
  static String? formatZoneMention(DateTime instant, String? zone) {
    final String? mention = zoneMention(instant, zone);
    if (mention == null) return null;
    return 'dates.zoneMentionWithLocal'.tr(
      namedArgs: <String, String>{
        'zone': mention,
        'local': 'dates.atYourPlace'.tr(
          namedArgs: <String, String>{'time': readerEquivalent(instant, zone)},
        ),
      },
    );
  }

  /// Le détail d'un rendez-vous en une ligne, au format unique du départ
  /// ([formatDeparture], ledgers `BRAND-8`, `MOB-115`) : « sam. 11 oct. ·
  /// 08:00 », suivi de « · heure de Tokyo (ven. 01:00 chez vous) » quand le
  /// décalage diffère de celui du lecteur. [now] ne sert qu'aux tests.
  static String formatRendezvous(
    DateTime instant,
    String? zone, {
    DateTime? now,
  }) {
    final String at = formatDeparture(instant, zone, now: now);
    final String? mention = formatZoneMention(instant, zone);
    return mention == null ? at : '$at · $mention';
  }

  /// Heure de la locale courante : 24 h en français (« 08:30 »), 12 h en
  /// anglais (« 8:30 AM »). **La langue décide**, pas le réglage du téléphone
  /// — décision du 2026-11-10 (état des lieux `SYNTHESE` §6.7), la règle du
  /// web : le motif `jm` de chaque locale porte déjà la bonne horloge.
  static String formatTime(DateTime date) =>
      DateFormat.jm().format(toDisplayTime(date));

  // Les dates longues sortent des motifs `intl` de chaque langue, jamais d'un
  // assemblage à la main : l'ordre, la virgule et la casse du mois sont ceux
  // de la langue (« lundi 15 janvier » ; « Monday, January 15 ») —
  // docs/LEDGER_*.md MOB-139, D6.

  /// « 15 janvier », « January 15 ».
  static String formatDayMonth(DateTime date) =>
      DateFormat.MMMMd().format(toDisplayTime(date));

  /// « 15 novembre », ou « 15 novembre 2027 » hors de l'année en cours :
  /// l'année seulement quand elle n'est pas celle du lecteur (KIT §9, règle
  /// R2 — « Météo dès le 15 novembre »). [now] pour les tests.
  static String formatDayMonthInYear(DateTime date, {DateTime? now}) {
    final DateTime wall = toDisplayTime(date);
    final DateTime reference = now == null
        ? displayNow()
        : toDisplayTime(now.toUtc());
    return (wall.year == reference.year
            ? DateFormat.MMMMd()
            : DateFormat.yMMMMd())
        .format(wall);
  }

  /// « lundi 15 janvier », « Monday, January 15 ».
  static String formatFullDate(DateTime date) =>
      DateFormat.MMMMEEEEd().format(toDisplayTime(date));

  /// « Janvier 2026 », « January 2026 » : un titre de mois, initiale capitale.
  static String formatMonthYear(DateTime date) {
    final String text = formatMonthAndYear(date);
    return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
  }

  /// « mars 2024 », « March 2024 » : le mois et l'année au fil d'une phrase
  /// (« Membre depuis mars 2024 », KIT §9).
  static String formatMonthAndYear(DateTime date) =>
      DateFormat.yMMMM().format(toDisplayTime(date));

  /// « lundi 15 janvier 2026 », « Monday, January 15, 2026 ».
  static String formatLongDate(DateTime date) =>
      DateFormat.yMMMMEEEEd().format(toDisplayTime(date));

  /// Date longue **sans jour de la semaine** : « 3 novembre 2026 »,
  /// « November 3, 2026 » — le « Créé le » d'un parcours, comme le web
  /// (`PPP`). Un horodatage : lu dans le fuseau d'affichage.
  static String formatLongDateWithoutWeekday(DateTime date) =>
      DateFormat.yMMMMd().format(toDisplayTime(date));

  /// « lundi 15 janvier 2026 à 08:30 ».
  static String formatLongDateTime(DateTime date) => 'dates.at'.tr(
    namedArgs: <String, String>{
      'date': formatLongDate(date),
      'time': formatTime(date),
    },
  );

  static String get today => tr('dates.today');

  static String get tomorrow => tr('dates.tomorrow');

  // ─────────────────────────────────────────────────────────────────────────
  // Départ — le format unique (docs/LEDGER_*.md BRAND-8, BRANDING §8.3)
  //
  // « sam. 12 avr. · 09:00 », l'année seulement hors de l'année en cours,
  // « Aujourd'hui · 09:00 » et « Demain · 09:00 » — jamais d'autre relatif.
  // L'heure suit la langue : 24 h en français, 12 h en anglais ([formatTime]).
  //
  // « Aujourd'hui », « demain » et l'année
  // en cours s'apprécient dans le **fuseau de la sortie** : le relatif colle
  // alors toujours au jour affiché, qui est celui de la sortie. Une personne
  // lue d'ailleurs a sa mention de fuseau pour le reste.
  // ─────────────────────────────────────────────────────────────────────────

  /// Le mois abrégé de la locale courante : « avr. », « Apr ».
  static String monthAbbrev(int month) {
    if (month < 1 || month > 12) return '?';
    return DateFormat.MMM().format(DateTime(2026, month));
  }

  /// L'heure murale de [instant] et celle de [now] (maintenant par défaut),
  /// toutes deux dans le fuseau [zone].
  static (DateTime, DateTime) _departureWalls(
    DateTime instant,
    String? zone,
    DateTime? now,
  ) => (
    toZoneTime(instant, zone),
    toZoneTime((now ?? DateTime.now()).toUtc(), zone),
  );

  /// Écart en jours civils entre deux heures murales. Compté sur des dates
  /// UTC : une différence de minuits locaux perd une heure au passage à
  /// l'heure d'été de l'appareil, et `inDays` tomberait alors à zéro.
  static int _civilDayGap(DateTime from, DateTime to) => DateTime.utc(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

  /// « Aujourd'hui » ou « Demain » quand le départ à [instant] (une valeur du
  /// contrat) tombe ce jour-là dans le fuseau [zone] de la sortie ; `null`
  /// sinon — y compris hier : aucun autre relatif n'existe (BRAND-8).
  ///
  /// [now] est un instant ; il ne sert qu'aux tests.
  static String? formatDepartureRelative(
    DateTime instant,
    String? zone, {
    DateTime? now,
  }) {
    final (DateTime wall, DateTime reference) = _departureWalls(
      instant,
      zone,
      now,
    );
    return switch (_civilDayGap(reference, wall)) {
      0 => today,
      1 => tomorrow,
      _ => null,
    };
  }

  /// La date seule du départ, jamais relative : « sam. 12 avr. », ou
  /// « sam. 10 avr. 2027 » quand l'année n'est pas l'année en cours du
  /// fuseau [zone].
  static String formatDepartureDate(
    DateTime instant,
    String? zone, {
    DateTime? now,
  }) {
    final (DateTime wall, DateTime reference) = _departureWalls(
      instant,
      zone,
      now,
    );
    final DateFormat format = wall.year == reference.year
        ? DateFormat.MMMEd()
        : DateFormat.yMMMEd();
    return format.format(wall);
  }

  /// Le départ en une chaîne : « sam. 12 avr. · 09:00 »,
  /// « sam. 10 avr. 2027 · 09:00 », « Aujourd'hui · 09:00 »,
  /// « Demain · 09:00 ». [instant] est la valeur du contrat, lue dans le
  /// fuseau [zone] de la sortie ; la mention de fuseau reste à l'appelant
  /// ([formatZoneMention]).
  static String formatDeparture(
    DateTime instant,
    String? zone, {
    DateTime? now,
  }) {
    final String date =
        formatDepartureRelative(instant, zone, now: now) ??
        formatDepartureDate(instant, zone, now: now);
    return 'dates.departureAt'.tr(
      namedArgs: <String, String>{
        'date': date,
        'time': formatTime(toZoneTime(instant, zone)),
      },
    );
  }

  /// Un horodatage court : « mar. 10 nov. · 08:30 », l'année seulement hors
  /// de l'année en cours — « Prévision du … » (KIT §8), la date d'une
  /// annonce ou d'une publication sur sa carte (KIT §9, docs/LEDGER_*.md
  /// MOB-139). Au format du départ mais **jamais relatif** : « Prévision du
  /// Aujourd'hui » ne se dit pas. D'où [formatDepartureDate] plutôt que
  /// [formatDeparture], qui dirait « Aujourd'hui · 08:30 ».
  ///
  /// Sans [zone], c'est un horodatage lu dans le fuseau du lecteur
  /// ([toDisplayTime]) ; avec, un rendez-vous lu dans celui de l'entité (la
  /// date d'une publication, `PostDto.timezone`). [now] ne sert qu'aux tests.
  static String formatTimestamp(
    DateTime instant, {
    String? zone,
    DateTime? now,
  }) => 'dates.departureAt'.tr(
    namedArgs: <String, String>{
      'date': formatDepartureDate(instant, zone, now: now),
      'time': formatTime(toZoneTime(instant, zone)),
    },
  );

  // ─────────────────────────────────────────────────────────────────────────
  // Durées
  // ─────────────────────────────────────────────────────────────────────────

  /// Une durée en minutes : « 3 h 18 », « 3 h », « 45 min » ; en anglais
  /// « 3 h 18 min », comme le web (`rides.weather.route.duration.*`). Les
  /// minutes ont deux chiffres derrière les heures (« 1 h 05 »), et chaque
  /// espace est insécable, comme entre une valeur et son unité ([withUnit]).
  /// Une valeur négative se lit comme sa valeur absolue.
  static String formatDurationMinutes(int totalMinutes) {
    final int abs = totalMinutes.abs();
    final int hours = abs ~/ 60;
    final int minutes = abs % 60;
    final String text = hours == 0
        ? 'dates.duration.minutes'.tr(
            namedArgs: <String, String>{'minutes': '$minutes'},
          )
        : minutes == 0
        ? 'dates.duration.hours'.tr(
            namedArgs: <String, String>{'hours': '$hours'},
          )
        : 'dates.duration.hoursMinutes'.tr(
            namedArgs: <String, String>{
              'hours': '$hours',
              'minutes': minutes.toString().padLeft(2, '0'),
            },
          );
    return text.replaceAll(' ', nbsp);
  }

  /// « il y a 3 jours », « dans 2 h », « à l'instant ».
  ///
  /// Au-delà de [RelativeTime.absoluteThresholdDays] jours, le relatif n'aide
  /// plus personne : on rend la date, sans jour de la semaine (« 3 novembre
  /// 2026 », KIT §9).
  static String formatRelative(DateTime date, {DateTime? now}) {
    final RelativeTime relative = RelativeTime.between(
      toDisplayTime(date),
      toDisplayTime(now ?? displayNow()),
    );
    return switch (relative.unit) {
      RelativeUnit.now => 'dates.relative.now'.tr(),
      RelativeUnit.absolute => formatLongDateWithoutWeekday(date),
      RelativeUnit.minutes ||
      RelativeUnit.hours ||
      RelativeUnit.days => 'dates.relative.${relative.translationKey}'.plural(
        relative.count,
        namedArgs: <String, String>{'count': '${relative.count}'},
      ),
    };
  }
}

/// Un prix d'annonce prêt à composer, en deux morceaux.
///
/// Le montant se rend en graisse 600, la période — quand il y en a une — en
/// 400 atténué, dans un `TextSpan` séparé. Cette classe ne connaît ni le thème
/// ni `core/pdl` : elle porte du texte, la mise en forme reste à l'appelant.
@immutable
class FormattedPrice {
  const FormattedPrice({
    required this.amount,
    this.period,
    this.isNegotiable = false,
  });

  /// « 1 200,00 € », ou « Prix à négocier ».
  final String amount;

  /// « / semaine ». `null` pour une vente, et pour une location dont la
  /// période n'a pas été renseignée.
  final String? period;

  /// Vrai quand [amount] porte « Prix à négocier » plutôt qu'un montant.
  final bool isNegotiable;

  /// Rendu d'un seul tenant, pour les contextes sans `TextSpan` sous la main
  /// (accessibilité, partage, tests).
  String get flat => period == null ? amount : '$amount $period';

  @override
  bool operator ==(Object other) =>
      other is FormattedPrice &&
      other.amount == amount &&
      other.period == period &&
      other.isNegotiable == isNegotiable;

  @override
  int get hashCode => Object.hash(amount, period, isNegotiable);

  @override
  String toString() => flat;
}

/// L'unité dans laquelle un écart de temps se raconte.
enum RelativeUnit { now, minutes, hours, days, absolute }

/// L'écart entre deux instants, réduit à ce qu'il faut pour le dire.
///
/// Pur : pas de traduction, pas de locale. C'est [AppFormatters.formatRelative]
/// qui l'habille, ce qui rend le découpage testable sans binding.
@immutable
class RelativeTime {
  const RelativeTime({
    required this.unit,
    required this.count,
    required this.isPast,
  });

  final RelativeUnit unit;

  /// Toujours positif : le sens est porté par [isPast].
  final int count;

  final bool isPast;

  /// Au-delà, un relatif désoriente plus qu'il n'informe.
  static const int absoluteThresholdDays = 7;

  /// En deçà, « à l'instant » vaut mieux que « il y a 0 minute ».
  static const int nowThresholdSeconds = 60;

  static RelativeTime between(DateTime date, DateTime now) {
    final Duration delta = now.difference(date);
    final bool isPast = !delta.isNegative;
    final Duration abs = delta.abs();
    if (abs.inSeconds < nowThresholdSeconds) {
      return RelativeTime(unit: RelativeUnit.now, count: 0, isPast: isPast);
    }
    if (abs.inMinutes < 60) {
      return RelativeTime(
        unit: RelativeUnit.minutes,
        count: abs.inMinutes,
        isPast: isPast,
      );
    }
    if (abs.inHours < 24) {
      return RelativeTime(
        unit: RelativeUnit.hours,
        count: abs.inHours,
        isPast: isPast,
      );
    }
    if (abs.inDays <= absoluteThresholdDays) {
      return RelativeTime(
        unit: RelativeUnit.days,
        count: abs.inDays,
        isPast: isPast,
      );
    }
    return RelativeTime(
      unit: RelativeUnit.absolute,
      count: abs.inDays,
      isPast: isPast,
    );
  }

  /// Segment de clé de traduction : « minutesAgo », « inDays »…
  String get translationKey => switch (unit) {
    RelativeUnit.now => 'now',
    RelativeUnit.absolute => 'absolute',
    RelativeUnit.minutes => isPast ? 'minutesAgo' : 'inMinutes',
    RelativeUnit.hours => isPast ? 'hoursAgo' : 'inHours',
    RelativeUnit.days => isPast ? 'daysAgo' : 'inDays',
  };

  @override
  bool operator ==(Object other) =>
      other is RelativeTime &&
      other.unit == unit &&
      other.count == count &&
      other.isPast == isPast;

  @override
  int get hashCode => Object.hash(unit, count, isPast);

  @override
  String toString() => 'RelativeTime($unit, $count, isPast: $isPast)';
}
