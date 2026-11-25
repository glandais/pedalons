package fr.pedalons.mobile

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import java.io.File

/**
 * « Ouvrir avec Pédalons » et « Partager vers Pédalons » d'un .gpx (docs/LEDGER_*.md MOB-191) : un
 * relais sans écran.
 *
 * Les filtres de ces intents ne sont pas sur [MainActivity] : une activité lancée par `VIEW` ou
 * `SEND` s'ouvre dans la tâche de l'app d'origine, et Pédalons y prenait sa place (Mattermost
 * affichait l'aperçu GPX). Ce relais, lui, s'ouvre bien dans cette tâche, mais n'y reste pas : il
 * copie le fichier dans le cache de l'app — c'est lui qui tient le droit de lire l'URI `content://`
 * —, ouvre [MainActivity] dans **sa** tâche (`NEW_TASK` retrouve la tâche existante de l'app, dont
 * elle est la racine) avec l'adresse `file://` de la copie, que app_links remet à Dart, et se
 * termine.
 */
class ReceivedFileActivity : Activity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    val source = receivedUri(intent)
    if (source == null) {
      finish()
      return
    }
    // Le flux peut venir du réseau (Drive, une messagerie) : hors du fil principal.
    Thread {
          val copy =
              try {
                copy(source)
              } catch (e: Exception) {
                null
              }
          runOnUiThread { open(copy) }
        }
        .start()
  }

  private fun receivedUri(intent: Intent?): Uri? =
      when (intent?.action) {
        Intent.ACTION_VIEW -> intent.data
        Intent.ACTION_SEND -> {
          @Suppress("DEPRECATION")
          intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }
        else -> null
      }

  /**
   * Ouvre l'app sur la copie. Une copie manquée ouvre l'app sur une adresse qui ne mène à aucun
   * fichier : Dart dit alors que le fichier n'a pas pu être lu, plutôt que de ne rien dire.
   */
  private fun open(copy: File?) {
    val target = copy ?: File(receivedDir(), "illisible.gpx")
    startActivity(
        Intent(this, MainActivity::class.java)
            .setAction(Intent.ACTION_VIEW)
            .setData(Uri.fromFile(target))
            .addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP))
    finish()
  }

  private fun receivedDir(): File = File(cacheDir, "received").apply { mkdirs() }

  /**
   * Copie [uri] dans `cache/received/`, où Dart le lit comme un fichier du sélecteur. La copie
   * s'arrête juste après la taille maximale d'un GPX : un fichier énorme est refusé (« trop
   * volumineux ») sans remplir le stockage.
   */
  private fun copy(uri: Uri): File? {
    val target = File(receivedDir(), gpxName(uri).replace('/', '_'))
    val input = contentResolver.openInputStream(uri) ?: return null
    var copied = 0L
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
    return target
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

  private companion object {
    /** `kGpxMaxBytes` côté Dart (`gpx_check.dart`) : 10 Mio. */
    const val MAX_RECEIVED_BYTES = 10L * 1024 * 1024
  }
}
