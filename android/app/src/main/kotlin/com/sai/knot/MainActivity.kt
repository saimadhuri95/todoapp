package com.sai.knot

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.DocumentsContract.Document
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

class MainActivity : FlutterActivity() {
    private var oauthChannel: MethodChannel? = null
    private var shareChannel: MethodChannel? = null
    private var pendingTreeResult: MethodChannel.Result? = null
    // Text shared into the app before Dart is ready to receive it (launch via
    // the share sheet); Dart drains it through getInitialShare (TASKS.md 6.25).
    private var pendingShare: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        oauthChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.sai.knot/oauth_callback"
        )
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.sai.knot/cloud_folder"
        ).setMethodCallHandler { call, result -> handleCloudFolderCall(call, result) }
        shareChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.sai.knot/share"
        ).apply {
            setMethodCallHandler { call, result ->
                if (call.method == "getInitialShare") {
                    val text = pendingShare
                    pendingShare = null
                    result.success(text)
                } else {
                    result.notImplemented()
                }
            }
        }
        pendingShare = extractSharedText(intent)
        forwardOAuthRedirect(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        forwardOAuthRedirect(intent)
        val shared = extractSharedText(intent)
        if (shared != null) {
            // App already running: push straight to Dart.
            if (shareChannel != null) {
                shareChannel?.invokeMethod("shared", shared)
            } else {
                pendingShare = shared
            }
        }
    }

    private fun extractSharedText(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_SEND) return null
        if (intent.type?.startsWith("text/") != true) return null
        val text = intent.getStringExtra(Intent.EXTRA_TEXT)
            ?: intent.getStringExtra(Intent.EXTRA_SUBJECT)
        return text?.takeIf { it.isNotBlank() }
    }

    private fun forwardOAuthRedirect(intent: Intent?) {
        val url = intent?.dataString ?: return
        if (url.startsWith("knot://oauth")) {
            oauthChannel?.invokeMethod("redirect", url)
        }
    }

    @Deprecated("FlutterActivity still routes legacy activity results here")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != openTreeRequestCode) return
        val result = pendingTreeResult ?: return
        pendingTreeResult = null
        if (resultCode != Activity.RESULT_OK) {
            result.success(null)
            return
        }
        val uri = data?.data
        if (uri == null) {
            result.success(null)
            return
        }
        val flags = data.flags and (
            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            )
        try {
            contentResolver.takePersistableUriPermission(uri, flags)
            result.success(uri.toString())
        } catch (e: Exception) {
            result.error("saf_permission", e.message, null)
        }
    }

    private fun handleCloudFolderCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "pickAndroidTree" -> pickAndroidTree(result)
                "createBookmark" -> result.success(call.argument<String>("path"))
                "resolveBookmark" -> resolveBookmark(call, result)
                "listDeviceDirs" -> result.success(listDeviceDirs(call))
                "listFiles" -> result.success(listFiles(call))
                "readFile" -> result.success(readFile(call))
                "writeFile" -> {
                    writeFile(call)
                    result.success(null)
                }
                "deleteFile" -> {
                    deleteFile(call)
                    result.success(null)
                }
                "wipeTree" -> {
                    wipeTree(call)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("cloud_folder", e.message, null)
        }
    }

    private fun pickAndroidTree(result: MethodChannel.Result) {
        if (pendingTreeResult != null) {
            result.error("already_open", "A folder picker is already open.", null)
            return
        }
        pendingTreeResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PREFIX_URI_PERMISSION
            )
        }
        startActivityForResult(intent, openTreeRequestCode)
    }

    private fun resolveBookmark(call: MethodCall, result: MethodChannel.Result) {
        val bookmark = call.argument<String>("bookmark")
        if (bookmark == null) {
            result.success(null)
            return
        }
        val uri = Uri.parse(bookmark)
        val hasGrant = contentResolver.persistedUriPermissions.any {
            it.uri == uri && it.isReadPermission && it.isWritePermission
        }
        result.success(if (hasGrant) bookmark else null)
    }

    private fun listDeviceDirs(call: MethodCall): List<String> {
        val treeUri = call.treeUri()
        val rootId = DocumentsContract.getTreeDocumentId(treeUri)
        return children(treeUri, rootId)
            .filter { it.mimeType == Document.MIME_TYPE_DIR }
            .map { it.name }
    }

    private fun listFiles(call: MethodCall): List<String> {
        val treeUri = call.treeUri()
        val rootId = DocumentsContract.getTreeDocumentId(treeUri)
        val deviceDir = call.requiredString("deviceDir")
        val dirId = findChild(treeUri, rootId, deviceDir, Document.MIME_TYPE_DIR)?.id
            ?: return emptyList()
        return children(treeUri, dirId)
            .filter { it.mimeType != Document.MIME_TYPE_DIR }
            .map { it.name }
    }

    private fun readFile(call: MethodCall): ByteArray? {
        val treeUri = call.treeUri()
        val rootId = DocumentsContract.getTreeDocumentId(treeUri)
        val dirId = findChild(
            treeUri,
            rootId,
            call.requiredString("deviceDir"),
            Document.MIME_TYPE_DIR
        )?.id ?: return null
        val file = findChild(treeUri, dirId, call.requiredString("name"), null) ?: return null
        return contentResolver.openInputStream(docUri(treeUri, file.id))?.use { it.readBytes() }
    }

    private fun writeFile(call: MethodCall) {
        val treeUri = call.treeUri()
        val rootId = DocumentsContract.getTreeDocumentId(treeUri)
        val dirId = ensureDir(treeUri, rootId, call.requiredString("deviceDir"))
        val name = call.requiredString("name")
        val bytes = call.argument<ByteArray>("bytes") ?: ByteArray(0)
        val fileId = findChild(treeUri, dirId, name, null)?.id
            ?: createDoc(treeUri, dirId, "application/octet-stream", name)
        contentResolver.openOutputStream(docUri(treeUri, fileId), "wt")?.use {
            it.write(bytes)
        } ?: throw IOException("Could not open $name for writing")
    }

    private fun deleteFile(call: MethodCall) {
        val treeUri = call.treeUri()
        val rootId = DocumentsContract.getTreeDocumentId(treeUri)
        val dirId = findChild(
            treeUri,
            rootId,
            call.requiredString("deviceDir"),
            Document.MIME_TYPE_DIR
        )?.id ?: return
        val file = findChild(treeUri, dirId, call.requiredString("name"), null) ?: return
        DocumentsContract.deleteDocument(contentResolver, docUri(treeUri, file.id))
    }

    private fun wipeTree(call: MethodCall) {
        val treeUri = call.treeUri()
        val rootId = DocumentsContract.getTreeDocumentId(treeUri)
        for (child in children(treeUri, rootId)) {
            DocumentsContract.deleteDocument(contentResolver, docUri(treeUri, child.id))
        }
    }

    private fun ensureDir(treeUri: Uri, parentId: String, name: String): String {
        return findChild(treeUri, parentId, name, Document.MIME_TYPE_DIR)?.id
            ?: createDoc(treeUri, parentId, Document.MIME_TYPE_DIR, name)
    }

    private fun createDoc(treeUri: Uri, parentId: String, mimeType: String, name: String): String {
        val uri = DocumentsContract.createDocument(
            contentResolver,
            docUri(treeUri, parentId),
            mimeType,
            name
        ) ?: throw IOException("Could not create $name")
        return DocumentsContract.getDocumentId(uri)
    }

    private fun findChild(
        treeUri: Uri,
        parentId: String,
        name: String,
        mimeType: String?
    ): ChildDoc? {
        return children(treeUri, parentId).firstOrNull {
            it.name == name && (mimeType == null || it.mimeType == mimeType)
        }
    }

    private fun children(treeUri: Uri, parentId: String): List<ChildDoc> {
        val uri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, parentId)
        val projection = arrayOf(
            Document.COLUMN_DOCUMENT_ID,
            Document.COLUMN_DISPLAY_NAME,
            Document.COLUMN_MIME_TYPE
        )
        val results = mutableListOf<ChildDoc>()
        contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
            val idIndex = cursor.getColumnIndexOrThrow(Document.COLUMN_DOCUMENT_ID)
            val nameIndex = cursor.getColumnIndexOrThrow(Document.COLUMN_DISPLAY_NAME)
            val mimeIndex = cursor.getColumnIndexOrThrow(Document.COLUMN_MIME_TYPE)
            while (cursor.moveToNext()) {
                results.add(
                    ChildDoc(
                        id = cursor.getString(idIndex),
                        name = cursor.getString(nameIndex),
                        mimeType = cursor.getString(mimeIndex)
                    )
                )
            }
        }
        return results
    }

    private fun docUri(treeUri: Uri, docId: String): Uri =
        DocumentsContract.buildDocumentUriUsingTree(treeUri, docId)

    private fun MethodCall.treeUri(): Uri = Uri.parse(requiredString("treeUri"))

    private fun MethodCall.requiredString(name: String): String =
        argument<String>(name) ?: throw IllegalArgumentException("Missing $name")

    private data class ChildDoc(
        val id: String,
        val name: String,
        val mimeType: String?
    )

    companion object {
        private const val openTreeRequestCode = 4242
    }
}
