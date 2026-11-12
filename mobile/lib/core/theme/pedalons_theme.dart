import '../material.dart';

import 'pdl_colors.dart';
import 'pdl_tokens.dart';
import 'pdl_typography.dart';

abstract final class PedalonsTheme {
  /// Construit le thème de l'application à partir des jetons de la charte.
  ///
  /// **Aucun `ColorScheme.fromSeed` ici.** Material 3 dérive du germe une
  /// palette tonale : `#4c6ef5` en ressortait indigo tonal, `#ffffff` blanc
  /// lavande et `onSurface` gris-violet — toute la charte était invisible.
  /// Le schéma est donc posé jeton par jeton, et les valeurs qui n'ont pas
  /// d'équivalent Material vivent dans les extensions [PdlColors] et
  /// [PdlTypography], enregistrées ci-dessous.
  static ThemeData build(Brightness brightness) {
    final PdlColors c = PdlColors.of(brightness);
    const TextStyle interBase = TextStyle(fontFamily: PdlTypography.family);
    final PdlTypography type = PdlTypography.of(brightness, base: interBase);

    final ColorScheme colorScheme = ColorScheme(
      brightness: brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primarySoft,
      onPrimaryContainer: c.primaryOnSoft,
      secondary: c.accentBlue,
      onSecondary: c.onPrimary,
      secondaryContainer: c.blueSoft,
      onSecondaryContainer: c.blueOnSoft,
      tertiary: c.accentTeal,
      onTertiary: c.onPrimary,
      tertiaryContainer: c.tealSoft,
      onTertiaryContainer: c.tealOnSoft,
      error: c.danger,
      onError: c.onPrimary,
      errorContainer: c.dangerSoft,
      onErrorContainer: c.dangerOnSoft,
      surface: c.surface,
      onSurface: c.text,
      surfaceContainerLowest: c.surface,
      surfaceContainerLow: c.surfaceAlt,
      surfaceContainer: c.surfaceAlt,
      surfaceContainerHigh: c.surfaceRaised,
      surfaceContainerHighest: c.surfaceRaised,
      onSurfaceVariant: c.textDimmed,
      outline: c.border,
      outlineVariant: c.borderSubtle,
      scrim: c.scrim,
      shadow: const Color(0xFF000000),
      inverseSurface: brightness == Brightness.light
          ? c.neutralOnSoft
          : c.neutralSoft,
      onInverseSurface: brightness == Brightness.light
          ? c.neutralSoft
          : c.neutralOnSoft,
      inversePrimary: c.primarySoft,
    );

    final TextTheme textTheme = ThemeData(brightness: brightness).textTheme
        .apply(
          fontFamily: PdlTypography.family,
          bodyColor: c.text,
          displayColor: c.textBright,
        );

    // Rayon 8 et hauteur 44 : la maquette réserve le rayon 12 aux cartes, et
    // le brief §5 impose 44 px de cible tactile à toute action.
    final RoundedRectangleBorder controlShape = const RoundedRectangleBorder(
      borderRadius: PdlRadii.mdAll,
    );
    const Size controlMinSize = Size(0, PdlMetrics.tapTarget);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.surface,
      dividerColor: c.borderSubtle,
      splashFactory: InkSparkle.splashFactory,
      extensions: <ThemeExtension<dynamic>>[c, type],
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        titleSpacing: PdlSpacing.section,
        toolbarHeight: PdlMetrics.appBar,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: c.surface,
        foregroundColor: c.text,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: type.barTitle,
        shape: Border(bottom: BorderSide(color: c.borderSubtle)),
      ),
      // `.card` est plate : une bordure sépare, pas une ombre — et en sombre
      // l'ombre ne porterait de toute façon pas.
      cardTheme: CardThemeData(
        elevation: 0,
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: PdlRadii.cardAll,
          side: BorderSide(color: c.borderSubtle),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: c.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceAlt,
        hintStyle: type.body.copyWith(color: c.textPlaceholder),
        constraints: const BoxConstraints(minHeight: PdlMetrics.tapTarget),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: PdlSpacing.cardTight,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: PdlRadii.mdAll,
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: PdlRadii.mdAll,
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: PdlRadii.mdAll,
          borderSide: BorderSide(color: c.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: PdlRadii.mdAll,
          borderSide: BorderSide(color: c.danger),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: PdlRadii.mdAll,
          borderSide: BorderSide(color: c.disabledBorder),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: controlShape,
          minimumSize: controlMinSize,
          textStyle: type.button,
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          disabledBackgroundColor: c.disabledBg,
          disabledForegroundColor: c.disabledText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: controlShape,
          minimumSize: controlMinSize,
          textStyle: type.button,
          foregroundColor: c.text,
          side: BorderSide(color: c.border),
          disabledForegroundColor: c.disabledText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: controlShape,
          minimumSize: controlMinSize,
          textStyle: type.textButton,
          foregroundColor: c.link,
          disabledForegroundColor: c.disabledText,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(PdlMetrics.tapTarget),
          foregroundColor: c.text,
        ),
      ),
      iconTheme: IconThemeData(color: c.text, size: 20),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: c.surfaceRaised,
        modalBarrierColor: c.sheetBarrier,
        elevation: 0,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(borderRadius: PdlRadii.sheetTop),
      ),
      // `chipTheme` est volontairement absent : `PdlChip` est maison. Un
      // `Chip` Material mesure 48 px de haut et impose sa propre forme, là où
      // la charte demande une pastille de 34 px dans une cible de 44.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: brightness == Brightness.light
            ? c.neutralOnSoft
            : c.surfaceRaised,
        contentTextStyle: type.body.copyWith(
          color: brightness == Brightness.light ? c.surface : c.text,
        ),
        behavior: SnackBarBehavior.floating,
        shape: controlShape,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> s) => c.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> s) =>
              s.contains(WidgetState.selected) ? c.primary : c.border,
        ),
      ),
    );
  }
}
