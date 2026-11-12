import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';

import '../../../../core/adaptive/adaptive.dart';
import '../../../../core/material.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../keys.dart';

enum LegalPageType { privacy, terms }

class LegalPage extends StatefulWidget {
  final LegalPageType type;

  const LegalPage({super.key, required this.type});

  @override
  State<LegalPage> createState() => _LegalPageState();
}

class _LegalPageState extends State<LegalPage> {
  String? _markdown;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadMarkdown();
  }

  Future<void> _loadMarkdown() async {
    final lang = context.locale.languageCode == 'fr' ? 'fr' : 'en';
    final fileName = widget.type == LegalPageType.privacy
        ? 'privacy-policy'
        : 'terms-of-service';
    final content = await rootBundle.loadString('privacy/$fileName.$lang.md');
    if (mounted) {
      setState(() => _markdown = content);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.type == LegalPageType.privacy
        ? 'profile.privacy'.tr()
        : 'profile.terms'.tr();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: BackOrHomeButton(key: keys.legal.backButton),
      ),
      // The page owns the scroll view so it attaches to the route's
      // PrimaryScrollController — that is what makes the iOS status bar tap
      // scroll back to the top.
      body: _markdown == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: ContentWidthConstraint(
                padding: const EdgeInsets.all(16),
                child: MarkdownContent(
                  key: keys.legal.content,
                  data: _markdown!,
                ),
              ),
            ),
    );
  }
}
