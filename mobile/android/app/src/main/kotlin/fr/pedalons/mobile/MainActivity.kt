package fr.pedalons.mobile

import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.InputMethodManager
import android.webkit.WebView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    sharedAsView(intent)
    super.onCreate(savedInstanceState)
  }

  override fun onNewIntent(intent: Intent) {
    sharedAsView(intent)
    super.onNewIntent(intent)
  }

  /**
   * Un GPX **partagé** (`ACTION_SEND`, le fichier dans `EXTRA_STREAM`) devient un `ACTION_VIEW` sur
   * ce fichier : app_links ne lit que la donnée d'un VIEW, et l'écran « Fichier reçu » ne distingue
   * pas ouvrir de partager (docs/LEDGER_*.md MOB-191). Le droit de lecture accordé à l'activité pour
   * le flux reste valable : c'est le même intent.
   */
  private fun sharedAsView(intent: Intent?) {
    if (intent?.action != Intent.ACTION_SEND) return
    @Suppress("DEPRECATION")
    val stream = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM) ?: return
    intent.action = Intent.ACTION_VIEW
    intent.setDataAndType(stream, intent.type)
  }

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
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RECEIVED_FILE_CHANNEL)
        .setMethodCallHandler { call, result ->
          when (call.method) {
            "copy" -> {
              val uri = call.argument<String>("uri")
              // Le flux peut venir du réseau (Drive, une messagerie) : la copie se fait hors du fil
              // principal, la réponse y revient.
              Thread {
                    val copied =
                        try {
                          copyReceivedFile(uri)
                        } catch (e: Exception) {
                          null
                        }
                    Handler(Looper.getMainLooper()).post { result.success(copied) }
                  }
                  .start()
            }
            else -> result.notImplemented()
          }
        }
  }

  /**
   * Copie le fichier reçu ([uriString], `content://` ou `file://`) dans le cache de l'app, où Dart
   * le lit comme un fichier du sélecteur (docs/LEDGER_*.md MOB-191). Rend son chemin, son nom
   * d'origine et sa taille, ou null s'il est illisible.
   *
   * La copie s'arrête juste après la taille maximale d'un GPX : un fichier énorme est refusé
   * (« trop volumineux ») sans remplir le stockage. Un nom sans extension prend `.gpx` quand le type
   * dit GPX — certaines messageries ne donnent qu'un nom générique.
   */
  private fun copyReceivedFile(uriString: String?): Map<String, Any>? {
    val uri = Uri.parse(uriString ?: return null)
    val name = gpxName(uri)
    val dir = File(cacheDir, "received").apply { mkdirs() }
    val target = File(dir, name.replace('/', '_'))
    var copied = 0L
    val input = contentResolver.openInputStream(uri) ?: return null
    input.use { source ->
      target.outputStream().use { sink ->
        val buffer = ByteArray(64 * 1024)
        while (copied <= MAX_RECEIVED_BYTES) {
          val read = source.read(buffer)
          if (read < 0) break
          sink.write(buffer, 0, read)
          copied += read
        }
      }
    }
    return mapOf("path" to target.absolutePath, "name" to name, "size" to copied)
  }

  /**
   * Le nom à montrer et à envoyer, remis en état comme le fait CoMaps : un `.gpx` suivi d'autre
   * chose est rétabli (le navigateur Samsung télécharge `sortie.gpx.xml`, puis `sortie.gpx (1).xml`),
   * et un nom sans extension prend `.gpx` quand le type dit GPX ou que le fichier vient de WhatsApp,
   * qui ne donne ni l'un ni l'autre. Sinon le nom reste tel quel, et Dart refuse un fichier qui n'a
   * pas l'air d'un GPX.
   */
  private fun gpxName(uri: Uri): String {
    val name = displayName(uri) ?: uri.lastPathSegment?.substringAfterLast('/') ?: "fichier"
    val lower = name.lowercase()
    if (lower.endsWith(".gpx")) return name
    val gpxAt = lower.lastIndexOf(".gpx")
    if (gpxAt > 0) return name.substring(0, gpxAt + 4)
    val type = contentResolver.getType(uri)
    if (type?.contains("gpx") == true) return "$name.gpx"
    if (uri.host?.contains("com.whatsapp") == true) return "$name.gpx"
    return name
  }

  private fun displayName(uri: Uri): String? {
    if (uri.scheme != "content") return null
    return try {
      contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
        if (it.moveToFirst()) it.getString(0) else null
      }
    } catch (e: Exception) {
      null
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
    const val RECEIVED_FILE_CHANNEL = "fr.pedalons.mobile/received_file"
    /** `kGpxMaxBytes` côté Dart (`gpx_check.dart`) : 10 Mio. */
    const val MAX_RECEIVED_BYTES = 10L * 1024 * 1024
  }
}
