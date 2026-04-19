package com.aio_downloader.alphared26

import android.app.Activity
import android.content.Intent
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.provider.DocumentsContract
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import android.graphics.Bitmap

class MainActivity : FlutterActivity() {
    private val THUMBNAIL_CHANNEL = "com.aio_downloader/thumbnail"
    private val SAF_CHANNEL = "com.aio_downloader/saf"
    
    private var safResult: MethodChannel.Result? = null
    private val SAF_REQUEST_CODE = 42

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // --- Thumbnail Channel ---
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, THUMBNAIL_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getVideoThumbnail") {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("INVALID_PATH", "Path is null", null)
                        return@setMethodCallHandler
                    }
                    
                    Thread {
                        try {
                            val retriever = MediaMetadataRetriever()
                            retriever.setDataSource(path)
                            val bitmap = retriever.getFrameAtTime(
                                1000000,
                                MediaMetadataRetriever.OPTION_CLOSEST_SYNC
                            )
                            retriever.release()

                            if (bitmap != null) {
                                val stream = ByteArrayOutputStream()
                                bitmap.compress(Bitmap.CompressFormat.JPEG, 75, stream)
                                val bytes = stream.toByteArray()
                                runOnUiThread { result.success(bytes) }
                            } else {
                                runOnUiThread { result.success(null) }
                            }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("THUMBNAIL_ERROR", e.message, null) }
                        }
                    }.start()
                } else {
                    result.notImplemented()
                }
            }

        // --- SAF Channel ---
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SAF_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openDocumentTree" -> {
                        safResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                            // Suggest starting at the WhatsApp Media directory
                            val initialUri = Uri.parse("content://com.android.externalstorage.documents/document/primary%3AAndroid%2Fmedia%2Fcom.whatsapp%2FWhatsApp%2FMedia")
                            putExtra(DocumentsContract.EXTRA_INITIAL_URI, initialUri)
                        }
                        startActivityForResult(intent, SAF_REQUEST_CODE)
                    }
                    "getPersistedPermissions" -> {
                        val uris = contentResolver.persistedUriPermissions.map { it.uri.toString() }
                        result.success(uris)
                    }
                    "listFiles" -> {
                        val uriStr = call.argument<String>("uri")
                        if (uriStr == null) {
                            result.error("INVALID_URI", "URI is null", null)
                            return@setMethodCallHandler
                        }
                        Thread {
                            try {
                                val treeUri = Uri.parse(uriStr)
                                val docFile = DocumentFile.fromTreeUri(this, treeUri)
                                val files = mutableListOf<Map<String, Any?>>()

                                // First check if there's a .Statuses subfolder
                                var statusDir = docFile?.findFile(".Statuses")
                                val targetDir = statusDir ?: docFile

                                targetDir?.listFiles()?.forEach { file ->
                                    val name = file.name ?: return@forEach
                                    if (name.startsWith(".")) return@forEach
                                    
                                    val isImage = name.endsWith(".jpg") || name.endsWith(".jpeg") || name.endsWith(".png")
                                    val isVideo = name.endsWith(".mp4")
                                    
                                    if (isImage || isVideo) {
                                        val fileUri = file.getUri().toString()
                                        val fileSize = file.length()
                                        val fileMod = file.lastModified()
                                        val fileType = if (isImage) "image" else "video"
                                        
                                        val entry = HashMap<String, Any?>()
                                        entry["name"] = name
                                        entry["uri"] = fileUri
                                        entry["type"] = fileType
                                        entry["size"] = fileSize
                                        entry["lastModified"] = fileMod
                                        files.add(entry)
                                    }
                                }
                                
                                // Sort by lastModified desc
                                files.sortByDescending { it["lastModified"] as Long }
                                
                                runOnUiThread { result.success(files) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("LIST_ERROR", e.message, null) }
                            }
                        }.start()
                    }
                    "readFile" -> {
                        val uriStr = call.argument<String>("uri")
                        if (uriStr == null) {
                            result.error("INVALID_URI", "URI is null", null)
                            return@setMethodCallHandler
                        }
                        Thread {
                            try {
                                val uri = Uri.parse(uriStr)
                                val inputStream = contentResolver.openInputStream(uri)
                                val bytes = inputStream?.readBytes()
                                inputStream?.close()
                                runOnUiThread { result.success(bytes) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("READ_ERROR", e.message, null) }
                            }
                        }.start()
                    }
                    "getVideoThumbnailFromUri" -> {
                        val uriStr = call.argument<String>("uri")
                        if (uriStr == null) {
                            result.error("INVALID_URI", "URI is null", null)
                            return@setMethodCallHandler
                        }
                        Thread {
                            try {
                                val uri = Uri.parse(uriStr)
                                val retriever = MediaMetadataRetriever()
                                retriever.setDataSource(this, uri)
                                val bitmap = retriever.getFrameAtTime(
                                    1000000,
                                    MediaMetadataRetriever.OPTION_CLOSEST_SYNC
                                )
                                retriever.release()

                                if (bitmap != null) {
                                    val stream = ByteArrayOutputStream()
                                    bitmap.compress(Bitmap.CompressFormat.JPEG, 75, stream)
                                    val bytes = stream.toByteArray()
                                    runOnUiThread { result.success(bytes) }
                                } else {
                                    runOnUiThread { result.success(null) }
                                }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("THUMBNAIL_ERROR", e.message, null) }
                            }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == SAF_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                val treeUri = data.data!!
                // Persist the permission
                contentResolver.takePersistableUriPermission(
                    treeUri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                )
                safResult?.success(treeUri.toString())
            } else {
                safResult?.success(null)
            }
            safResult = null
        }
    }
}
