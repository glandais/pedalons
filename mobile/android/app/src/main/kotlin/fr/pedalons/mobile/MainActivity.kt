package fr.pedalons.mobile

import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.InputMethodManager
import android.webkit.WebView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BROWSER_CHANNEL)
        .setMethodCallHandler { call, result ->
          when (call.method) {
            "open" -> result.success(openInBrowser(call.argument<String>("url")))
            else -> result.notImplemented()
          }
        }
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, EDITOR_CHANNEL)
        .setMethodCallHandler { call, result ->
          when (call.method) {
            "showKeyboard" -> result.success(showEditorKeyboard())
            else -> result.notImplemented()
          }
        }
  }

  /**
   * Rouvre le clavier sur l'éditeur riche des publications (la WebView de
   * `rich_markdown_editor_field.dart`), après l'ajout d'une image : le sélecteur
   * de photos l'a fermé, et un `focus()` en JavaScript, sans geste de la personne,
   * ne le rouvre pas. La WebView reprend le focus Android, puis le clavier est
   * demandé pour elle — le texte, lui, a déjà son curseur, posé par la page.
   * L'éditeur est la seule WebView de l'app.
   */
  private fun showEditorKeyboard(): Boolean {
    val webView = findWebView(window.decorView) ?: return false
    webView.requestFocus()
    val imm = getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager
    return imm.showSoftInput(webView, InputMethodManager.SHOW_IMPLICIT)
  }

  private fun findWebView(view: View): WebView? {
    if (view is WebView) return view
    if (view is ViewGroup) {
      for (i in 0 until view.childCount) findWebView(view.getChildAt(i))?.let { return it }
    }
    return null
  }

  /**
   * Ouvre [url] dans le navigateur de l'appareil, **jamais** dans l'app.
   *
   * Un `ACTION_VIEW` implicite ne suffit pas : le domaine est celui des liens d'app, et les motifs
   * `/equipes/.*` du manifeste captent toute l'équipe — y compris les pages du site sans écran dans
   * l'app (docs/LEDGER_*.md MOB-59). Le système rendrait le lien à l'app elle-même. On nomme donc le
   * navigateur : celui par défaut, sinon le premier navigateur installé qui n'est pas nous.
   */
  private fun openInBrowser(url: String?): Boolean {
    if (url == null) return false
    val browser = browserPackage() ?: return false
    val intent =
        Intent(Intent.ACTION_VIEW, Uri.parse(url))
            .addCategory(Intent.CATEGORY_BROWSABLE)
            .setPackage(browser)
    return try {
      startActivity(intent)
      true
    } catch (e: ActivityNotFoundException) {
      false
    }
  }

  /**
   * Le paquet du navigateur, résolu sur une adresse qu'aucune app ne revendique. Sans navigateur par
   * défaut, `resolveActivity` rend le sélecteur du système (paquet `android`) : on prend alors le
   * premier navigateur listé. Visible grâce au `<queries>` `VIEW https` du manifeste.
   */
  private fun browserPackage(): String? {
    val probe =
        Intent(Intent.ACTION_VIEW, Uri.parse("https://example.com"))
            .addCategory(Intent.CATEGORY_BROWSABLE)
    val default =
        packageManager
            .resolveActivity(probe, PackageManager.MATCH_DEFAULT_ONLY)
            ?.activityInfo
            ?.packageName
    if (default != null && default != "android" && default != packageName) return default
    return packageManager
        .queryIntentActivities(probe, 0)
        .map { it.activityInfo.packageName }
        .firstOrNull { it != packageName }
  }

  private companion object {
    const val BROWSER_CHANNEL = "fr.pedalons.mobile/browser"
    const val EDITOR_CHANNEL = "fr.pedalons.mobile/rich_editor"
  }
}
