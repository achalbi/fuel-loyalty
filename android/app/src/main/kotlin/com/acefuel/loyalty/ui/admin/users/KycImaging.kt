package com.acefuel.loyalty.ui.admin.users

import android.content.ContentResolver
import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import com.acefuel.loyalty.BuildConfig
import java.io.File

/**
 * An image the operator picked for upload, resolved to what a multipart part
 * needs: the content [uri], its [mime] type (validated server-side against
 * JPEG/PNG/WEBP) and a [filename]. Held transiently in the form state; picking
 * one marks the form dirty so the discard guard fires.
 */
data class PickedImage(
    val uri: Uri,
    val mime: String,
    val filename: String,
)

/** Resolve a content Uri into a [PickedImage], falling back to sane defaults. */
fun ContentResolver.toPickedImage(uri: Uri): PickedImage {
    val mime = getType(uri) ?: "image/jpeg"
    val name = query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
        if (c.moveToFirst()) {
            val idx = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (idx >= 0) c.getString(idx) else null
        } else {
            null
        }
    }
    val filename = name?.takeIf { it.isNotBlank() } ?: "upload.${mime.substringAfterLast('/', "jpg")}"
    return PickedImage(uri = uri, mime = mime, filename = filename)
}

/**
 * A fresh cache-backed [Uri] (via the app's FileProvider) the camera app can
 * write a full-resolution capture into. Matches `res/xml/file_paths.xml` and the
 * `${applicationId}.fileprovider` authority declared in the manifest.
 */
fun Context.newKycCaptureUri(): Uri {
    val dir = File(cacheDir, "kyc_captures").apply { mkdirs() }
    val file = File.createTempFile("capture_", ".jpg", dir)
    return FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
}

/**
 * The API returns image URLs as host-relative paths (`only_path: true`), e.g.
 * `/rails/active_storage/blobs/redirect/…`. Prefix the configured API host so
 * Coil / an external viewer can resolve them; absolute URLs are passed through.
 */
fun absoluteApiUrl(path: String?): String? {
    if (path.isNullOrBlank()) return null
    if (path.startsWith("http://") || path.startsWith("https://")) return path
    return BuildConfig.API_BASE_URL.trimEnd('/') + "/" + path.trimStart('/')
}
