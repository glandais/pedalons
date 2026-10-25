import 'package:flutter/widgets.dart';

class _AppsPageKey extends ValueKey<String> {
  const _AppsPageKey(String value) : super('appsPage_$value');
}

/// La page Applications.
class AppsPageKeys {
  final karooShareButton = const _AppsPageKey('karooShareButton');
}
