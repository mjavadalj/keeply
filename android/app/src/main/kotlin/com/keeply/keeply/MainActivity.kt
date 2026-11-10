package com.keeply.keeply

import android.Manifest
import android.app.Activity
import android.content.ContentResolver
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import android.provider.Settings
import android.util.Size
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "keeply/media_store"
    private val permissionRequestCode = 7001
    private val mediaManagementRequestCode = 7002
    private val mediaMutationRequestCode = 7003
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingMediaManagementResult: MethodChannel.Result? = null
    private var pendingMediaMutationResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "hasPermission" -> result.success(hasMediaPermission())
                    "requestPermission" -> requestMediaPermission(result)
                    "ensureMediaManagement" -> ensureMediaManagement(result)
                    "queryMedia" -> result.success(queryMedia(call.argument<String>("sourceKind") ?: "all", call.argument<String>("bucketId"), call.argument<Int>("offset") ?: 0, call.argument<Int>("limit") ?: 24, call.argument<Boolean>("trashed") == true))
                    "discoverSources" -> result.success(discoverSources())
                    "thumbnail" -> result.success(loadThumbnail(Uri.parse(call.argument<String>("uri")!!), call.argument<Int>("size") ?: 640))
                    "trash" -> updateMediaTrash(Uri.parse(call.argument<String>("uri")!!), true, result)
                    "restore" -> updateMediaTrash(Uri.parse(call.argument<String>("uri")!!), false, result)
                    "deletePermanently" -> permanentlyDelete(call.argument<List<String>>("uris") ?: emptyList(), result)
                    "deletePermanentlyAutomatically" -> permanentlyDelete(call.argument<List<String>>("uris") ?: emptyList(), result, requireConfirmation = false)
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("MEDIA_STORE_ERROR", error.message, null)
            }
        }
    }

    private fun hasMediaPermission(): Boolean {
        val permissions = if (Build.VERSION.SDK_INT >= 33) {
            arrayOf(Manifest.permission.READ_MEDIA_IMAGES, Manifest.permission.READ_MEDIA_VIDEO)
        } else arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
        return permissions.all { checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED }
    }

    private fun requestMediaPermission(result: MethodChannel.Result) {
        if (hasMediaPermission()) { result.success(true); return }
        pendingPermissionResult = result
        val permissions = if (Build.VERSION.SDK_INT >= 33) {
            arrayOf(Manifest.permission.READ_MEDIA_IMAGES, Manifest.permission.READ_MEDIA_VIDEO)
        } else arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
        requestPermissions(permissions, permissionRequestCode)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == permissionRequestCode) {
            pendingPermissionResult?.success(hasMediaPermission())
            pendingPermissionResult = null
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == mediaManagementRequestCode) {
            val result = pendingMediaManagementResult
            pendingMediaManagementResult = null
            result?.success(hasMediaManagement())
        } else if (requestCode == mediaMutationRequestCode) {
            val result = pendingMediaMutationResult
            pendingMediaMutationResult = null
            if (result == null) return
            if (resultCode == Activity.RESULT_OK) {
                result.success(null)
            } else {
                result.error("MEDIA_STORE_NOT_AUTHORIZED", "Media change was not authorized", null)
            }
        }
    }

    private fun collections(): List<Pair<String, Uri>> = listOf(
        "image" to MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
        "video" to MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
    )

    private fun queryMedia(sourceKind: String, bucketId: String?, offset: Int, limit: Int, trashed: Boolean): List<Map<String, Any?>> {
        val kinds = when (sourceKind) {
            "photos" -> listOf("image")
            "videos" -> listOf("video")
            else -> collections().map { it.first }
        }
        val window = offset + limit
        return kinds.flatMap { kind -> queryCollection(kind, collections().first { it.first == kind }.second, bucketId, 0, window, trashed) }
            .sortedByDescending { (it["dateAddedSeconds"] as Long?) ?: 0L }
            .drop(offset)
            .take(limit)
    }

    private fun queryCollection(kind: String, collection: Uri, bucketId: String?, offset: Int, limit: Int, trashed: Boolean): List<Map<String, Any?>> {
        val projection = arrayOf(MediaStore.MediaColumns._ID, MediaStore.MediaColumns.DISPLAY_NAME, MediaStore.MediaColumns.MIME_TYPE, MediaStore.MediaColumns.DATE_ADDED, MediaStore.MediaColumns.BUCKET_ID, MediaStore.MediaColumns.BUCKET_DISPLAY_NAME, MediaStore.MediaColumns.RELATIVE_PATH, MediaStore.MediaColumns.DURATION, MediaStore.MediaColumns.IS_TRASHED)
        val selectionParts = mutableListOf<String>()
        val selectionArgs = mutableListOf<String>()
        if (bucketId != null) { selectionParts += "${MediaStore.MediaColumns.BUCKET_ID} = ?"; selectionArgs += bucketId }
        if (trashed) selectionParts += "${MediaStore.MediaColumns.IS_TRASHED} = 1" else selectionParts += "${MediaStore.MediaColumns.IS_TRASHED} = 0"
        val args = Bundle().apply {
            putString(ContentResolver.QUERY_ARG_SQL_SELECTION, selectionParts.joinToString(" AND "))
            putStringArray(ContentResolver.QUERY_ARG_SQL_SELECTION_ARGS, selectionArgs.toTypedArray())
            putString(ContentResolver.QUERY_ARG_SQL_SORT_ORDER, "${MediaStore.MediaColumns.DATE_ADDED} DESC")
            putInt("android:query-arg-offset", offset)
            putInt("android:query-arg-limit", limit)
            if (trashed) putInt(MediaStore.QUERY_ARG_MATCH_TRASHED, 1)
        }
        val result = mutableListOf<Map<String, Any?>>()
        contentResolver.query(collection, projection, args, null)?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
            while (cursor.moveToNext()) {
                val id = cursor.getLong(idColumn)
                result += mapOf(
                    "id" to "$kind:$id",
                    "uri" to Uri.withAppendedPath(collection, id.toString()).toString(),
                    "kind" to if (kind == "video") "video" else "image",
                    "dateAddedSeconds" to cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATE_ADDED)),
                    "bucketId" to cursor.stringOrNull(MediaStore.MediaColumns.BUCKET_ID),
                    "bucketName" to cursor.stringOrNull(MediaStore.MediaColumns.BUCKET_DISPLAY_NAME),
                    "relativePath" to cursor.stringOrNull(MediaStore.MediaColumns.RELATIVE_PATH),
                    "displayName" to cursor.stringOrNull(MediaStore.MediaColumns.DISPLAY_NAME),
                    "durationMs" to cursor.longOrNull(MediaStore.MediaColumns.DURATION),
                    "isTrashed" to (cursor.intOrNull(MediaStore.MediaColumns.IS_TRASHED) == 1),
                )
            }
        }
        return result
    }

    private fun discoverSources(): List<Map<String, Any?>> {
        val sources = linkedMapOf<String, Map<String, Any?>>(
            "all" to mapOf("id" to "all", "label" to "All media", "kind" to "all"),
            "photos" to mapOf("id" to "photos", "label" to "Photos", "kind" to "photos"),
            "videos" to mapOf("id" to "videos", "label" to "Videos", "kind" to "videos"),
        )
        collections().forEach { (_, uri) ->
            val projection = arrayOf(MediaStore.MediaColumns.BUCKET_ID, MediaStore.MediaColumns.BUCKET_DISPLAY_NAME)
            contentResolver.query(uri, projection, "${MediaStore.MediaColumns.IS_TRASHED} = 0", null, "${MediaStore.MediaColumns.BUCKET_DISPLAY_NAME} ASC")?.use { cursor ->
                val idColumn = cursor.getColumnIndex(MediaStore.MediaColumns.BUCKET_ID)
                val nameColumn = cursor.getColumnIndex(MediaStore.MediaColumns.BUCKET_DISPLAY_NAME)
                while (cursor.moveToNext()) {
                    val id = cursor.getString(idColumn) ?: continue
                    val name = cursor.getString(nameColumn) ?: id
                    sources["bucket:$id"] = mapOf("id" to "bucket:$id", "label" to name, "kind" to "bucket", "bucketId" to id)
                }
            }
        }
        return sources.values.toList()
    }

    private fun loadThumbnail(uri: Uri, size: Int): ByteArray? {
        val bitmap = if (Build.VERSION.SDK_INT >= 29) contentResolver.loadThumbnail(uri, Size(size, size), null) else BitmapFactory.decodeStream(contentResolver.openInputStream(uri))
        return bitmap?.let {
            val stream = ByteArrayOutputStream()
            it.compress(Bitmap.CompressFormat.JPEG, 86, stream)
            it.recycle()
            stream.toByteArray()
        }
    }

    private fun hasMediaManagement(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.S || MediaStore.canManageMedia(this)
    }

    private fun ensureMediaManagement(result: MethodChannel.Result) {
        if (hasMediaManagement()) {
            result.success(true)
            return
        }
        if (pendingMediaManagementResult != null) {
            result.error("MEDIA_STORE_BUSY", "Media management access is already being requested", null)
            return
        }
        pendingMediaManagementResult = result
        try {
            startActivityForResult(Intent(Settings.ACTION_REQUEST_MANAGE_MEDIA).apply {
                data = Uri.parse("package:$packageName")
            }, mediaManagementRequestCode)
        } catch (error: Exception) {
            pendingMediaManagementResult = null
            result.error("MEDIA_MANAGEMENT_UNAVAILABLE", error.message, null)
        }
    }

    private fun updateMediaTrash(uri: Uri, trash: Boolean, result: MethodChannel.Result) {
        if (!hasMediaManagement()) {
            result.error("MEDIA_MANAGEMENT_REQUIRED", "Media management access is required", null)
            return
        }
        if (pendingMediaMutationResult != null) {
            result.error("MEDIA_STORE_BUSY", "Another media change is already in progress", null)
            return
        }
        try {
            val request = MediaStore.createTrashRequest(contentResolver, listOf(uri), trash)
            pendingMediaMutationResult = result
            startIntentSenderForResult(request.intentSender, mediaMutationRequestCode, null, 0, 0, 0)
        } catch (error: Exception) {
            pendingMediaMutationResult = null
            result.error("MEDIA_STORE_ERROR", error.message, null)
        }
    }

    private fun permanentlyDelete(uriStrings: List<String>, result: MethodChannel.Result, requireConfirmation: Boolean = true) {
        if (uriStrings.isEmpty()) {
            result.success(null)
            return
        }
        if (!hasMediaManagement()) {
            result.error("MEDIA_MANAGEMENT_REQUIRED", "Media management access is required", null)
            return
        }
        if (pendingMediaMutationResult != null) {
            result.error("MEDIA_STORE_BUSY", "Another media change is already in progress", null)
            return
        }
        try {
            if (!requireConfirmation) {
                uriStrings.forEach {
                    contentResolver.delete(
                        Uri.parse(it),
                        "${MediaStore.MediaColumns.IS_TRASHED} = 1",
                        null,
                    )
                }
                result.success(null)
                return
            }
            val request = MediaStore.createDeleteRequest(
                contentResolver,
                uriStrings.map { Uri.parse(it) },
            )
            pendingMediaMutationResult = result
            startIntentSenderForResult(request.intentSender, mediaMutationRequestCode, null, 0, 0, 0)
        } catch (error: Exception) {
            pendingMediaMutationResult = null
            result.error("MEDIA_STORE_ERROR", error.message, null)
        }
    }

    private fun android.database.Cursor.stringOrNull(column: String): String? = getColumnIndex(column).takeIf { it >= 0 && !isNull(it) }?.let { getString(it) }
    private fun android.database.Cursor.longOrNull(column: String): Long? = getColumnIndex(column).takeIf { it >= 0 && !isNull(it) }?.let { getLong(it) }
    private fun android.database.Cursor.intOrNull(column: String): Int? = getColumnIndex(column).takeIf { it >= 0 && !isNull(it) }?.let { getInt(it) }
}
