import 'package:flutter/widgets.dart';

class _AppsPageKey extends ValueKey<String> {
  const _AppsPageKey(String value) : super('appsPage_$value');
}

/// La page Applications et son inscription à la bêta.
class AppsPageKeys {
  final betaEmailField = const _AppsPageKey('betaEmailField');
  final betaSentState = const _AppsPageKey('betaSentState');
  final betaSubmitButton = const _AppsPageKey('betaSubmitButton');
  final karooShareButton = const _AppsPageKey('karooShareButton');
}
