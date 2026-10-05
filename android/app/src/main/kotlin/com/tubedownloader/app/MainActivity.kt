package com.tubedownloader.app

import android.content.ContentValues
import android.content.Intent
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

class MainActivity : FlutterActivity() {
    private var shareChannel: MethodChannel? = null

    /// Text shared before Dart was listening (the app opened by a share).
    private var pendingShare: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // Share sheet: "initialText" -> the text that opened the app (once);
        // later shares arrive as "shared" calls to Dart.
        pendingShare = sharedText(intent)
        shareChannel = MethodChannel(messenger, "com.tubedownloader.app/share").apply {
            setMethodCallHandler { call, result ->
                if (call.method != "initialText") return@setMethodCallHandler result.notImplemented()
                result.success(pendingShare)
                pendingShare = null
            }
        }

        // "space" {path} -> {free, total} bytes of the volume holding path,
        // or null when it can't be read.
        MethodChannel(messenger, "com.tubedownloader.app/storage").setMethodCallHandler { call, result ->
            if (call.method != "space") return@setMethodCallHandler result.notImplemented()
            val path = call.argument<String>("path")
                ?: return@setMethodCallHandler result.error("args", "path missing", null)
            try {
                val stat = StatFs(path)
                result.success(mapOf("free" to stat.availableBytes, "total" to stat.totalBytes))
            } catch (e: IllegalArgumentException) {
                result.success(null)
            }
        }

        // "publish" {source, name, mime, audio, subDir?} -> the published
        // file's path. Moves a finished download where the user's apps see it.
        MethodChannel(messenger, "com.tubedownloader.app/mediastore").setMethodCallHandler { call, result ->
            if (call.method != "publish") return@setMethodCallHandler result.notImplemented()
            val source = call.argument<String>("source")
            val name = call.argument<String>("name")
            val mime = call.argument<String>("mime")
            if (source == null || name == null || mime == null) {
                return@setMethodCallHandler result.error("args", "source, name and mime are required", null)
            }
            val audio = call.argument<Boolean>("audio") ?: false
            val subDir = call.argument<String>("subDir")
            // Copying hundreds of MB: never on the UI thread.
            Thread {
                try {
                    val path = publish(File(source), name, mime, audio, subDir)
                    runOnUiThread { result.success(path) }
                } catch (e: Exception) {
                    runOnUiThread { result.error("publish", e.message, null) }
                }
            }.start()
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val text = sharedText(intent) ?: return
        shareChannel?.invokeMethod("shared", text)
    }

    private fun sharedText(intent: Intent?): String? =
        if (intent?.action == Intent.ACTION_SEND && intent.type?.startsWith("text/") == true) {
            intent.getStringExtra(Intent.EXTRA_TEXT)
        } else {
            null
        }

    /// Android 10+: MediaStore, into Movies|Music/Tube Downloader[/subDir] —
    /// public, no permission needed, written as "pending" so the Gallery never
    /// shows half a file. Android 7–9: the app's own external Movies|Music
    /// folder (no permission prompt), then announced to the media scanner.
    private fun publish(source: File, name: String, mime: String, audio: Boolean, subDir: String?): String {
        val base = if (audio) Environment.DIRECTORY_MUSIC else Environment.DIRECTORY_MOVIES
        val folders = listOfNotNull(APP_FOLDER, subDir)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val collection = if (audio) {
                MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            } else {
                MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            }
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                put(MediaStore.MediaColumns.MIME_TYPE, mime)
                put(MediaStore.MediaColumns.RELATIVE_PATH, (listOf(base) + folders).joinToString("/"))
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val uri = contentResolver.insert(collection, values) ?: throw IOException("MediaStore insert failed")
            try {
                val out = contentResolver.openOutputStream(uri) ?: throw IOException("no output stream")
                out.use { o -> source.inputStream().use { it.copyTo(o) } }
                values.clear()
                values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                contentResolver.update(uri, values, null, null)
            } catch (e: Exception) {
                contentResolver.delete(uri, null, null)
                throw e
            }
            source.delete()
            // Its path, for the library: apps read the media they created by path.
            @Suppress("DEPRECATION")
            contentResolver.query(uri, arrayOf(MediaStore.MediaColumns.DATA), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) return cursor.getString(0)
            }
            throw IOException("published, but no path for $uri")
        }
        val dir = File(getExternalFilesDir(base), folders.joinToString("/")).apply { mkdirs() }
        var target = File(dir, name)
        var n = 2
        while (target.exists()) {
            target = File(dir, "${name.substringBeforeLast('.')} ($n).${name.substringAfterLast('.')}")
            n++
        }
        source.copyTo(target)
        source.delete()
        MediaScannerConnection.scanFile(this, arrayOf(target.path), arrayOf(mime), null)
        return target.path
    }

    companion object {
        private const val APP_FOLDER = "Tube Downloader"
    }
}
