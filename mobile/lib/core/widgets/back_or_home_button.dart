import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';

import '../../config/paths.dart';
import '../material.dart';

/// AppBar leading that pops when there is somewhere to pop to, and otherwise
/// goes back to the app home.
///
/// Standalone pages (legal, device verification) live outside every shell, so
/// they carry no bottom navigation. Opened straight from a deep link they can
/// be the only entry in the navigator stack, where the implicit back arrow
/// never shows up — leaving no way out of the page.
class BackOrHomeButton extends StatelessWidget {
  const BackOrHomeButton({super.key});

  @override
  Widget build(BuildContext context) {
    final canPop = context.canPop();

    return IconButton(
      icon: Icon(canPop ? Icons.arrow_back : Icons.home_outlined),
      tooltip: canPop
          ? MaterialLocalizations.of(context).backButtonTooltip
          : 'nav.home'.tr(),
      onPressed: () => canPop ? context.pop() : context.go(Paths.home()),
    );
  }
}
