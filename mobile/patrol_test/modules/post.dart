import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'module.dart';

/// A post's page, and its comment thread.
final class Post extends Module {
  Post(super.$);

  Future<void> waitUntilShown() async {
    await $(keys.post.title).waitUntilVisible();
  }

  String? get title =>
      $(keys.post.title).exists ? $(keys.post.title).text : null;

  bool get isShownNow => isShown(keys.post.title);

  Future<void> waitUntilClosed() => waitUntilGone(keys.post.title);

  Future<void> openMoreMenu() async {
    await $(keys.post.moreButton).tap();
  }

  /// Waits for the comment of [commentId], scrolled into view.
  ///
  /// Through its ⋯ button: the comment's own row is hit-testable only where a child is — a short
  /// comment leaves the row's centre empty, and `scrollTo` would never call it visible.
  Future<void> waitUntilCommentIsShown(String commentId) async {
    await scrolledTo(keys.comments.moreButton(commentId));
  }

  bool showsComment(String commentId) =>
      isShown(keys.comments.comment(commentId));

  Future<void> waitUntilCommentIsGone(String commentId) =>
      waitUntilGone(keys.comments.comment(commentId));

  Future<void> openCommentMenu(String commentId) async {
    await (await scrolledTo(keys.comments.moreButton(commentId))).tap();
  }

  // ── The composer ────────────────────────────────────────────────────────

  /// Types [text] in the thread's composer and sends it; returns once the composer is empty
  /// again — the app clears it only when the API accepted the comment.
  Future<void> sendComment(String text) async {
    await (await scrolledTo(keys.comments.composerField)).enterText(text);
    await (await scrolledTo(keys.comments.sendButton)).tap();
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (composerText.isNotEmpty) {
      if (DateTime.now().isAfter(deadline)) {
        throw TestFailure('the composer still reads "$composerText"');
      }
      await $.pump(const Duration(milliseconds: 200));
    }
  }

  /// What the composer holds right now.
  String get composerText =>
      $.tester
          .widget<TextField>(find.byKey(keys.comments.composerField))
          .controller
          ?.text ??
      '';

  // ── Replies ─────────────────────────────────────────────────────────────

  bool offersReplyTo(String commentId) =>
      isShown(keys.comments.replyButton(commentId));

  /// « Répondre » under [commentId]: the composer now answers it.
  Future<void> startReplyTo(String commentId) async {
    await (await scrolledTo(keys.comments.replyButton(commentId))).tap();
    await $(keys.comments.replyingToBanner).waitUntilVisible();
  }

  /// Whether the composer's « En réponse à … » line is up and names [name].
  bool replyingToShows(String name) =>
      shows(keys.comments.replyingToBanner, name);

  bool get isReplying => isShown(keys.comments.replyingToBanner);

  /// Whether [replyId] is rendered inside [parentId]'s thread, under it.
  bool showsReplyUnder(String parentId, String replyId) =>
      $(keys.comments.thread(parentId))
          .$(keys.comments.comment(replyId))
          .exists;

  // ── The `⋯` menu ────────────────────────────────────────────────────────

  /// From the open `⋯` menu of one's own comment: « Supprimer » — no confirmation.
  Future<void> deleteFromOpenMenu() async {
    await $(keys.moderation.deleteAction).tap();
    await waitUntilGone(keys.moderation.deleteAction);
  }
}
