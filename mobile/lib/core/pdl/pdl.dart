/// La bibliothèque de composants Pédalons.
///
/// Point d'entrée unique : `import 'package:pedalons/core/pdl/pdl.dart';`.
/// Le contrat du module — jetons obligatoires, cible tactile 44 px, deux modes,
/// aucun littéral de couleur, aucune importation du client d'API généré — est
/// énoncé dans `README.md`, à côté de ce fichier, avec les deux `grep` de revue
/// qui le rendent vérifiable.
library;

// ── Vague A — primitives ────────────────────────────────────────────────────
export 'pdl_avatar.dart';
export 'pdl_badge.dart';
export 'pdl_blur_surface.dart';
export 'pdl_button.dart';
export 'pdl_card.dart';
export 'pdl_chip.dart';
export 'pdl_color_track.dart';
export 'pdl_filter_button.dart';
export 'pdl_info_line.dart';
export 'pdl_number_pill.dart';
export 'pdl_progress_bar.dart';
export 'pdl_scrim.dart';
export 'pdl_search_field.dart';
export 'pdl_section_header.dart';
export 'pdl_segmented.dart';
export 'pdl_setting_row.dart';
export 'pdl_skeleton.dart';
export 'pdl_stat.dart';
export 'pdl_stat_row.dart';
export 'pdl_switch.dart';
export 'pdl_tag.dart';

// ── Vague B — composés ──────────────────────────────────────────────────────
export 'pdl_attachment_row.dart';
export 'pdl_avatar_editor.dart';
export 'pdl_avatar_stack.dart';
export 'pdl_badge_stack.dart';
export 'pdl_banner.dart';
export 'pdl_card_media.dart';
export 'pdl_chip_row.dart';
export 'pdl_climb_row.dart';
export 'pdl_danger_zone.dart';
export 'pdl_dead_end_empty.dart';
export 'pdl_empty_state.dart';
export 'pdl_gallery_dots.dart';
export 'pdl_image_viewer.dart';
export 'pdl_legend_row.dart';
export 'pdl_markdown_body.dart';
export 'pdl_month_grid.dart';
export 'pdl_paged_list_footer.dart';
export 'pdl_person_row.dart';
export 'pdl_place_row.dart';
export 'pdl_price_block.dart';
export 'pdl_range_filter.dart';
export 'pdl_refresh.dart';
export 'pdl_scope_selector.dart';
export 'pdl_segment_bar.dart';
export 'pdl_skeleton_card.dart';
export 'pdl_stat_cell_row.dart';
export 'pdl_team_line.dart';
export 'pdl_thumb.dart';
export 'pdl_wind_arrow.dart';

// ── Vague C — coquilles d'écran ─────────────────────────────────────────────
export 'pdl_action_bar.dart';
export 'pdl_app_bar.dart';
export 'pdl_bottom_tabs.dart';
export 'pdl_detent_sheet.dart';
export 'pdl_full_sheet.dart';
export 'pdl_pinned_toolbar.dart';
export 'pdl_prev_next_nav.dart';
export 'pdl_screen_scaffold.dart';
export 'pdl_sheet.dart';
export 'pdl_stage_rail.dart';

// ── Briques techniques ──────────────────────────────────────────────────────
export 'elevation/elevation_area_painter.dart';
export 'elevation/elevation_cursor_painter.dart';
export 'elevation/elevation_samples.dart';
export 'elevation/pdl_elevation_profile.dart';
export 'map/pdl_map.dart';
export 'map/pdl_map_attribution.dart';
export 'map/pdl_map_buttons.dart';
export 'map/pdl_map_camera.dart';
export 'map/pdl_map_controller.dart';
export 'map/pdl_map_hero.dart';
export 'map/pdl_map_marker.dart';
export 'map/pdl_mass_layer.dart';
export 'map/pdl_waypoint_mark.dart';
export 'pdl_waypoint_row.dart';
export 'elevation/elevation_markers_painter.dart';
