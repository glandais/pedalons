import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../theme/pdl_tokens.dart';

/// Fait défiler [controller] pour caler le haut de [anchor] sous [topInset]
/// (une barre épinglée), animé sauf quand le système demande de réduire les
/// animations (`PdlMotion.reducedOf`) — alors d'un saut.
///
/// L'ancre est cherchée telle qu'elle est posée : les slivers d'un
/// `CustomScrollView` hors de l'écran ont leur position même s'ils ne sont
/// pas peints. Sans ancre posée, rien ne bouge.
Future<void> revealInScroll(
  BuildContext context,
  ScrollController controller,
  GlobalKey anchor, {
  double topInset = 0,
}) async {
  if (!controller.hasClients) return;
  final RenderObject? box = anchor.currentContext?.findRenderObject();
  if (box == null || !box.attached) return;
  final double target =
      RenderAbstractViewport.of(box).getOffsetToReveal(box, 0).offset -
      topInset;
  final ScrollPosition position = controller.position;
  final double offset = target.clamp(
    position.minScrollExtent,
    position.maxScrollExtent,
  );
  if (PdlMotion.reducedOf(context)) {
    controller.jumpTo(offset);
    return;
  }
  await controller.animateTo(
    offset,
    duration: PdlMotion.stateChange,
    curve: PdlMotion.stateChangeCurve,
  );
}
