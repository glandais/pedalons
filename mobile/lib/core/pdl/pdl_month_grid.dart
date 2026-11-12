import '../material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_tokens.dart';
import '../theme/pdl_typography.dart';

/// Une case de la grille : une date, et si elle appartient au mois affiché.
@immutable
class PdlMonthCell {
  const PdlMonthCell({required this.date, required this.inMonth});

  final DateTime date;

  /// Faux pour les jours de débordement — fin du mois précédent, début du
  /// suivant. Ils sont rendus en `textPlaceholder` et **ne portent aucun
  /// point** : un événement d'un autre mois sur une grille de juillet est un
  /// piège.
  final bool inMonth;
}

/// B26 — Grille de mois, 7 colonnes.
///
/// **La semaine va du lundi au dimanche, et elle est calculée.** Jamais
/// `MaterialLocalizations.firstDayOfWeekIndex`, jamais le réglage système : un
/// appareil configuré en `en_US` afficherait une grille commençant le
/// dimanche, décalée d'un jour par rapport à tous les autres écrans de l'app et
/// par rapport au web. [composeMonth] fait le calcul, et se teste sans widget.
///
/// **« Aujourd'hui » et « inscrit » sont cumulables** — la maquette les rend
/// exclusifs, à tort : on est le plus souvent inscrit à quelque chose
/// aujourd'hui. Le cumul est un fond plein `primary` **plus** un anneau
/// intérieur de 2 px en `onPrimary`.
class PdlMonthGrid extends StatelessWidget {
  const PdlMonthGrid({
    super.key,
    required this.year,
    required this.month,
    required this.weekdayLabels,
    this.dotsOf,
    this.isRegistered,
    this.today,
    this.selectedDay,
    this.onDayTap,
    this.daySemanticLabel,
    this.gap = 2,
    this.cellHeight = 52,
  }) : assert(
         weekdayLabels.length == 7,
         'sept libellés, du lundi au dimanche, fournis par l\'écran',
       );

  final int year;
  final int month;

  /// Les sept en-têtes de colonne, **du lundi au dimanche**, traduits par
  /// l'écran : `core/pdl` ne traduit rien.
  final List<String> weekdayLabels;

  /// Zéro à deux points de 5 px sous le numéro. Au-delà de deux, la case
  /// devient illisible ; l'appelant tronque.
  final List<Color> Function(DateTime day)? dotsOf;

  /// Vrai quand l'utilisateur est inscrit à quelque chose ce jour-là.
  final bool Function(DateTime day)? isRegistered;

  /// Jour courant. Nul, aucune case n'est « aujourd'hui » — utile en test.
  final DateTime? today;

  final DateTime? selectedDay;
  final ValueChanged<DateTime>? onDayTap;

  /// Ce qu'un lecteur d'écran annonce pour une case — « mercredi 22 juillet,
  /// 2 événements, inscrit ».
  ///
  /// Sans lui, une cellule ne dit que son numéro : les points et l'anneau sont
  /// **purement visuels**, et toute l'information de la grille disparaît pour
  /// qui ne la voit pas. L'écran le fournit, `core/pdl` ne traduit rien.
  final String Function(DateTime day)? daySemanticLabel;

  final double gap;
  final double cellHeight;

  /// Compose les cases d'un mois, **semaine lundi → dimanche**.
  ///
  /// La grille commence au lundi de la semaine du 1ᵉʳ et finit au dimanche de
  /// la semaine du dernier jour : 28, 35 ou 42 cases selon le mois. Février
  /// 2024, bissextile et commençant un jeudi, en produit 35.
  static List<PdlMonthCell> composeMonth(int year, int month) {
    final DateTime first = DateTime(year, month);
    // `DateTime.weekday` vaut 1 le lundi et 7 le dimanche : le décalage est
    // donc `weekday - 1`, sans table ni dépendance à la locale.
    final DateTime start = first.subtract(
      Duration(days: first.weekday - DateTime.monday),
    );
    final DateTime last = DateTime(year, month + 1, 0);
    final DateTime end = last.add(
      Duration(days: DateTime.sunday - last.weekday),
    );

    final List<PdlMonthCell> cells = <PdlMonthCell>[];
    DateTime cursor = start;
    while (!cursor.isAfter(end)) {
      cells.add(PdlMonthCell(date: cursor, inMonth: cursor.month == month));
      // `add(Duration(days: 1))` sur un `DateTime` local traverse correctement
      // les changements d'heure : la date reste à minuit local.
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }
    return cells;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final List<PdlMonthCell> cells = composeMonth(year, month);

    Widget cell(Widget child) => Expanded(
      child: SizedBox(height: cellHeight, child: child),
    );

    final List<Widget> rows = <Widget>[
      Row(
        children: <Widget>[
          for (int i = 0; i < 7; i++) ...<Widget>[
            if (i > 0) SizedBox(width: gap),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  weekdayLabels[i],
                  textAlign: TextAlign.center,
                  style: t.xs.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    ];

    for (int week = 0; week * 7 < cells.length; week++) {
      rows.add(SizedBox(height: gap));
      rows.add(
        Row(
          children: <Widget>[
            for (int i = 0; i < 7; i++) ...<Widget>[
              if (i > 0) SizedBox(width: gap),
              cell(
                _Day(
                  cell: cells[week * 7 + i],
                  today: today,
                  selected:
                      selectedDay != null &&
                      _sameDay(cells[week * 7 + i].date, selectedDay!),
                  registered:
                      cells[week * 7 + i].inMonth &&
                      (isRegistered?.call(cells[week * 7 + i].date) ?? false),
                  dots: cells[week * 7 + i].inMonth
                      ? (dotsOf?.call(cells[week * 7 + i].date) ??
                            const <Color>[])
                      : const <Color>[],
                  onTap: onDayTap,
                  semanticLabel: daySemanticLabel?.call(
                    cells[week * 7 + i].date,
                  ),
                  colors: c,
                  text: t,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

class _Day extends StatelessWidget {
  const _Day({
    required this.cell,
    required this.today,
    required this.selected,
    required this.registered,
    required this.dots,
    required this.onTap,
    required this.semanticLabel,
    required this.colors,
    required this.text,
  });

  final PdlMonthCell cell;
  final DateTime? today;
  final bool selected;
  final bool registered;
  final List<Color> dots;
  final ValueChanged<DateTime>? onTap;
  final String? semanticLabel;
  final PdlColors colors;
  final PdlTypography text;

  @override
  Widget build(BuildContext context) {
    final bool isToday =
        today != null && PdlMonthGrid._sameDay(cell.date, today!);
    final bool weekend =
        cell.date.weekday == DateTime.saturday ||
        cell.date.weekday == DateTime.sunday;

    // Le numéro : plein indigo aujourd'hui, anneau intérieur si inscrit. Les
    // deux se cumulent — l'anneau passe alors en `onPrimary` pour rester
    // visible sur l'aplat.
    final BoxDecoration numberDecoration = BoxDecoration(
      shape: BoxShape.circle,
      color: isToday ? colors.primary : null,
      border: registered
          ? Border.all(
              color: isToday ? colors.onPrimary : colors.primary,
              width: 2,
            )
          : null,
    );

    final TextStyle numberStyle = text.sub.copyWith(
      fontWeight: isToday || registered ? FontWeight.w700 : FontWeight.w500,
      color: !cell.inMonth
          ? colors.textPlaceholder
          : (isToday ? colors.onPrimary : colors.text),
    );

    final Widget content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: numberDecoration,
          child: Text(
            '${cell.date.day}',
            // Un disque de 26 px ne suit pas l'agrandissement typographique.
            textScaler: TextScaler.noScaling,
            style: numberStyle,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 5,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (int i = 0; i < dots.length && i < 2; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: 4),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: dots[i],
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    final Widget box = DecoratedBox(
      decoration: BoxDecoration(
        color: selected
            ? colors.primarySoft
            : (weekend ? colors.surfaceAlt : null),
        borderRadius: PdlRadii.mdAll,
      ),
      child: SizedBox.expand(child: content),
    );

    if (onTap == null) {
      return semanticLabel == null
          ? box
          : Semantics(
              label: semanticLabel,
              child: ExcludeSemantics(child: box),
            );
    }
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => onTap!(cell.date),
          borderRadius: PdlRadii.mdAll,
          // Le libellé fourni **remplace** le numéro plutôt que de s'y
          // ajouter : « mercredi 22 juillet, 2 événements » puis « 22 » se lit
          // comme deux cases.
          child: semanticLabel == null ? box : ExcludeSemantics(child: box),
        ),
      ),
    );
  }
}

/// L'en-tête de jour de l'agenda (`.dhd`) — « mer. 22 juillet ».
///
/// 14/700, marge haute 16 et basse 8. Le libellé est **déjà formaté** par
/// l'écran.
class PdlDayHeader extends StatelessWidget {
  const PdlDayHeader({
    super.key,
    required this.label,
    this.trailing,
    this.padding = const EdgeInsets.only(top: 16, bottom: 8),
  });

  final String label;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final PdlTypography t = context.pdlText;

    return Padding(
      padding: padding,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.sub.copyWith(
                fontWeight: FontWeight.w700,
                color: context.pdl.text,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
