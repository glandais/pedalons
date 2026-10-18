import 'package:flutter/material.dart';

/// Couche d'indirection du jeu d'icônes (§1.0.3-10 du plan v2).
///
/// Les maquettes et `docs/BRANDING.md` §6 emploient le jeu **Tabler**, servi en SVG ;
/// le brief §4.1.2 et tout le code existant emploient **Material outline**.
/// L'arbitrage retenu pour la v2 est Material outline : l'écart ne porte que
/// sur la graisse du trait des icônes de 11 px de badge, et ajouter
/// `flutter_svg` plus un jeu d'assets pour cela est disproportionné en regard
/// des ~65 composants à écrire.
///
/// Ce fichier est le **seul** endroit de la bibliothèque `core/pdl` autorisé à
/// nommer `Icons.*`. La règle de revue associée :
///
/// ```
/// grep -rn "Icons\." mobile/lib/core/pdl   # ne doit rien renvoyer
/// ```
///
/// Basculer vers Tabler devient alors mécanique : seul le corps de ce fichier
/// change.
abstract final class PdlIcons {
  // ── Navigation racine (les 5 onglets) ──────────────────────────────────
  static const IconData home = Icons.home_outlined;
  static const IconData homeActive = Icons.home;
  static const IconData teams = Icons.group_outlined;
  static const IconData teamsActive = Icons.group;
  static const IconData calendar = Icons.calendar_today_outlined;
  static const IconData calendarActive = Icons.calendar_today;
  static const IconData routes = Icons.route_outlined;
  static const IconData routesActive = Icons.route;
  static const IconData profile = Icons.person_outlined;
  static const IconData profileActive = Icons.person;

  // ── Barres et gestes ───────────────────────────────────────────────────
  static const IconData back = Icons.arrow_back;
  static const IconData close = Icons.close;
  static const IconData chevronRight = Icons.chevron_right;
  static const IconData chevronLeft = Icons.chevron_left;
  static const IconData chevronDown = Icons.expand_more;
  static const IconData chevronUp = Icons.expand_less;
  static const IconData more = Icons.more_horiz;
  static const IconData share = Icons.ios_share;
  static const IconData search = Icons.search;
  static const IconData filter = Icons.tune;
  static const IconData sort = Icons.swap_vert;
  static const IconData refresh = Icons.refresh;
  static const IconData check = Icons.check;
  static const IconData checkCircle = Icons.check_circle;
  static const IconData add = Icons.add;
  static const IconData remove = Icons.close;
  static const IconData edit = Icons.edit_outlined;
  static const IconData delete = Icons.delete_outline;
  static const IconData copy = Icons.copy_all_outlined;
  static const IconData openExternal = Icons.open_in_new;
  static const IconData settings = Icons.settings_outlined;
  static const IconData logout = Icons.logout;

  // ── Types de contenu ───────────────────────────────────────────────────
  static const IconData ride = Icons.directions_bike;
  static const IconData post = Icons.article_outlined;
  static const IconData trip = Icons.luggage_outlined;
  static const IconData stage = Icons.flag_outlined;
  static const IconData ad = Icons.sell_outlined;
  static const IconData team = Icons.group_outlined;
  static const IconData route = Icons.route_outlined;
  static const IconData page = Icons.description_outlined;
  static const IconData tag = Icons.label_outline;
  static const IconData feed = Icons.dynamic_feed_outlined;
  static const IconData dashboard = Icons.dashboard_outlined;

  /// La section « Agenda » d'une équipe — sorties et voyages (`IconCalendarEvent`
  /// au web, `docs/BRANDING.md` §6).
  static const IconData agenda = Icons.event_outlined;
  static const IconData comment = Icons.mode_comment_outlined;
  static const IconData attachment = Icons.attach_file;
  static const IconData gpx = Icons.download_outlined;
  static const IconData download = Icons.download_outlined;
  static const IconData image = Icons.image_outlined;
  static const IconData brokenImage = Icons.broken_image_outlined;

  // ── Vélo, parcours, relief ─────────────────────────────────────────────
  static const IconData distance = Icons.straighten;
  static const IconData elevationUp = Icons.trending_up;
  static const IconData elevationDown = Icons.trending_down;
  static const IconData terrain = Icons.terrain;
  static const IconData climb = Icons.landscape;
  static const IconData speed = Icons.speed;
  static const IconData surfaceRoad = Icons.add_road;
  static const IconData surfaceGravel = Icons.grain;
  static const IconData surfaceMtb = Icons.forest_outlined;
  static const IconData surfaceMixed = Icons.alt_route;
  static const IconData wind = Icons.air;

  // ── Météo ──────────────────────────────────────────────────────────────
  // Une icône par `WeatherCondition` du contrat, de jour et de nuit quand la
  // différence se voit ; [weatherUnknown] est le repli de toute valeur que
  // cette version de l'app ne connaît pas.
  static const IconData weatherClearDay = Icons.light_mode_outlined;
  static const IconData weatherClearNight = Icons.dark_mode_outlined;
  static const IconData weatherPartlyCloudyDay = Icons.filter_drama_outlined;
  static const IconData weatherPartlyCloudyNight = Icons.nights_stay_outlined;
  static const IconData weatherOvercast = Icons.cloud_outlined;
  static const IconData weatherFog = Icons.foggy;
  static const IconData weatherDrizzle = Icons.grain;
  static const IconData weatherRain = Icons.water_drop_outlined;
  static const IconData weatherHeavyRain = Icons.umbrella_outlined;
  static const IconData weatherFreezingRain = Icons.severe_cold;
  static const IconData weatherShowers = Icons.umbrella_outlined;
  static const IconData weatherSnow = Icons.ac_unit;
  static const IconData weatherThunderstorm = Icons.thunderstorm_outlined;
  static const IconData weatherUnknown = Icons.cloud_outlined;

  /// Prévision ancienne (`STALE`) sur la ligne météo des cartes — l'icône
  /// « historique » du web (`IconHistory`).
  static const IconData weatherStale = Icons.history;
  static const IconData temperature = Icons.thermostat;
  static const IconData precipitation = Icons.water_drop_outlined;
  static const IconData sunrise = Icons.wb_twilight;
  static const IconData sunset = Icons.nights_stay_outlined;

  /// La flèche de vent : pointe vers le haut, l'appelant la tourne.
  static const IconData windArrow = Icons.navigation;

  // ── Carte ──────────────────────────────────────────────────────────────
  static const IconData map = Icons.map_outlined;
  static const IconData list = Icons.view_list_outlined;
  static const IconData layers = Icons.layers_outlined;
  static const IconData fullscreen = Icons.fullscreen;
  static const IconData fullscreenExit = Icons.fullscreen_exit;
  static const IconData locate = Icons.my_location;
  static const IconData nearMe = Icons.near_me_outlined;
  static const IconData place = Icons.location_on_outlined;
  static const IconData placeStart = Icons.trip_origin;
  static const IconData placeEnd = Icons.flag_outlined;

  // ── Temps, agenda, personnes ───────────────────────────────────────────
  static const IconData time = Icons.schedule;

  /// Un rendez-vous lu dans un autre fuseau que celui du lecteur
  /// (docs/LEDGER_*.md API-60) — distinct de [visibilityPublic].
  static const IconData otherTimezone = Icons.travel_explore;
  static const IconData date = Icons.event_outlined;
  static const IconData dateBusy = Icons.event_busy;
  static const IconData people = Icons.people_outline;
  static const IconData person = Icons.person_outline;
  static const IconData personOff = Icons.person_off_outlined;
  static const IconData personAdd = Icons.person_add_alt_outlined;
  static const IconData personRemove = Icons.person_remove_alt_1_outlined;
  static const IconData reminder = Icons.alarm;
  static const IconData invitation = Icons.drafts_outlined;
  static const IconData leader = Icons.star_outline;
  static const IconData admin = Icons.shield_outlined;
  static const IconData seats = Icons.event_seat_outlined;

  // ── Statuts, états, retours ────────────────────────────────────────────
  static const IconData info = Icons.info_outline;
  static const IconData warning = Icons.warning_amber_outlined;
  static const IconData error = Icons.error_outline;
  static const IconData offline = Icons.wifi_off_outlined;
  static const IconData notFound = Icons.help_outline;
  static const IconData emptySearch = Icons.search_off;
  static const IconData draft = Icons.edit_note;
  static const IconData cancelled = Icons.block;
  static const IconData done = Icons.done_all;
  static const IconData visibilityPublic = Icons.public;
  static const IconData visibilityUnlisted = Icons.link;
  static const IconData visibilityTeam = Icons.lock_outline;

  // ── Modération ─────────────────────────────────────────────────────────
  static const IconData report = Icons.outlined_flag;

  // ── Administration d'équipe ────────────────────────────────────────────
  static const IconData webhook = Icons.webhook_outlined;
  static const IconData template = Icons.content_copy_outlined;

  // ── Édition de contenu (éditeur de sortie, ledger MOB-80) ──────────────
  static const IconData publish = Icons.publish;
  static const IconData unpublish = Icons.unpublished_outlined;
  static const IconData restore = Icons.restore_from_trash_outlined;
  static const IconData link = Icons.link;
  static const IconData formatBold = Icons.format_bold;
  static const IconData formatItalic = Icons.format_italic;
  static const IconData formatHeading = Icons.title;
  static const IconData formatBullets = Icons.format_list_bulleted;
  static const IconData formatNumbers = Icons.format_list_numbered;
  static const IconData formatQuote = Icons.format_quote;
  static const IconData imageAdd = Icons.add_photo_alternate_outlined;
  static const IconData fileAdd = Icons.upload_file_outlined;

  // ── Retours ────────────────────────────────────────────────────────────
  static const IconData bug = Icons.bug_report_outlined;
  static const IconData block = Icons.block;

  // ── Compte, préférences ────────────────────────────────────────────────
  static const IconData email = Icons.email_outlined;
  static const IconData password = Icons.lock_reset;
  static const IconData passkey = Icons.fingerprint;
  static const IconData device = Icons.smartphone;
  static const IconData devices = Icons.devices;
  static const IconData notifications = Icons.notifications_none;
  static const IconData notificationsOff = Icons.notifications_off_outlined;
  static const IconData language = Icons.language;
  static const IconData theme = Icons.brightness_6_outlined;
  static const IconData units = Icons.straighten;
  static const IconData privacy = Icons.policy_outlined;
  static const IconData price = Icons.euro_symbol;
  static const IconData camera = Icons.photo_camera_outlined;
}
