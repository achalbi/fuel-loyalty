package com.acefuel.loyalty.ui.scanner

import android.Manifest
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Base64
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.Spacer
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.acefuel.loyalty.core.di.LocalContainer
import com.acefuel.loyalty.ui.theme.NayaraButton
import com.acefuel.loyalty.ui.theme.NayaraOutlinedButton
import com.acefuel.loyalty.ui.theme.nayara
import com.google.accompanist.permissions.ExperimentalPermissionsApi
import com.google.accompanist.permissions.isGranted
import com.google.accompanist.permissions.rememberPermissionState
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import androidx.compose.runtime.rememberCoroutineScope
import kotlin.coroutines.resume

@OptIn(ExperimentalPermissionsApi::class, ExperimentalMaterial3Api::class)
@Composable
fun PlateScannerScreen(onBack: () -> Unit, onResult: (String) -> Unit) {
    val container = LocalContainer.current
    val repo = remember { PlateScanRepository.from(container.plateRetrofit, container.json) }
    val viewModel: PlateScannerViewModel = viewModel(
        factory = viewModelFactory { initializer { PlateScannerViewModel(repo) } },
    )
    val state by viewModel.state.collectAsStateWithLifecycle()
    val cameraPermission = rememberPermissionState(Manifest.permission.CAMERA)
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val scope = rememberCoroutineScope()
    var capturing by remember { mutableStateOf(false) }
    val imageCapture = remember {
        ImageCapture.Builder().setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY).build()
    }

    Scaffold(
        topBar = {
            androidx.compose.material3.TopAppBar(
                title = { Text("Scan Plate") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { pad ->
        Column(Modifier.fillMaxSize().padding(pad).padding(20.dp)) {
            when {
                !cameraPermission.status.isGranted -> {
                    Text(
                        "Camera access is needed to scan a vehicle plate.",
                        style = MaterialTheme.typography.bodyLarge,
                    )
                    Spacer(Modifier.height(16.dp))
                    NayaraButton(onClick = { cameraPermission.launchPermissionRequest() }) {
                        Text("Grant camera access")
                    }
                }

                state.plate != null -> ResultCard(
                    plate = state.plate!!,
                    confidence = state.confidence,
                    valid = state.valid,
                    provider = state.provider,
                    onUse = { onResult(state.plate!!) },
                    onRetake = { viewModel.reset() },
                )

                state.error != null -> {
                    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer), modifier = Modifier.fillMaxWidth()) {
                        Text(state.error!!, Modifier.padding(16.dp), color = MaterialTheme.colorScheme.onErrorContainer)
                    }
                    Spacer(Modifier.height(16.dp))
                    NayaraOutlinedButton(onClick = { viewModel.reset() }) { Text("Retake") }
                }

                else -> {
                    Box(Modifier.fillMaxWidth().weight(1f)) {
                        AndroidView(
                            modifier = Modifier.fillMaxSize(),
                            factory = { ctx ->
                                val previewView = PreviewView(ctx)
                                val future = ProcessCameraProvider.getInstance(ctx)
                                future.addListener({
                                    val provider = future.get()
                                    val preview = Preview.Builder().build().also {
                                        it.setSurfaceProvider(previewView.surfaceProvider)
                                    }
                                    provider.unbindAll()
                                    provider.bindToLifecycle(
                                        lifecycleOwner, CameraSelector.DEFAULT_BACK_CAMERA, preview, imageCapture,
                                    )
                                }, ContextCompat.getMainExecutor(ctx))
                                previewView
                            },
                        )
                        if (capturing || state.recognizing) {
                            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                                CircularProgressIndicator()
                            }
                        }
                    }
                    Spacer(Modifier.height(16.dp))
                    Text(
                        "Point at the number plate and capture.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.nayara.textSecondary,
                    )
                    Spacer(Modifier.height(12.dp))
                    NayaraButton(
                        onClick = {
                            scope.launch {
                                capturing = true
                                runCatching {
                                    val (dataUrl, bitmap) = capturePlate(imageCapture, context)
                                    val ocr = recognizeOnDevice(bitmap)
                                    viewModel.recognize(dataUrl, ocr)
                                }
                                capturing = false
                            }
                        },
                        enabled = !capturing && !state.recognizing,
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text("Capture")
                    }
                }
            }
        }
    }
}

@Composable
private fun ResultCard(
    plate: String,
    confidence: Double?,
    valid: Boolean,
    provider: String?,
    onUse: () -> Unit,
    onRetake: () -> Unit,
) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(20.dp)) {
            Text("Detected plate", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.nayara.textSecondary)
            Text(plate, style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            val meta = buildString {
                provider?.let { append(if (it == "on_device") "On-device" else "Plate Recognizer") }
                confidence?.let { append(" · ${it.toInt()}%") }
                if (!valid) append(" · verify")
            }
            if (meta.isNotBlank()) {
                Text(meta, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.nayara.textSecondary)
            }
            if (!valid) {
                Spacer(Modifier.height(8.dp))
                Text(
                    "Please verify the detected number before saving.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.error,
                )
            }
        }
    }
    Spacer(Modifier.height(16.dp))
    NayaraButton(onClick = onUse, modifier = Modifier.fillMaxWidth()) { Text("Use $plate") }
    Spacer(Modifier.height(8.dp))
    NayaraOutlinedButton(onClick = onRetake, modifier = Modifier.fillMaxWidth()) { Text("Retake") }
}

/** Longest edge (px) we upload for recognition — plenty for ALPR, keeps the
 *  base64 body small so it uploads well within the request timeout. */
private const val MAX_UPLOAD_EDGE = 1600

/** Capture a JPEG frame; returns (data-URL, bitmap). The full-resolution sensor
 *  JPEG is downscaled and re-compressed before upload — a raw frame base64-encodes
 *  to several MB and times out on mobile networks. */
private suspend fun capturePlate(
    imageCapture: ImageCapture,
    context: android.content.Context,
): Pair<String, Bitmap> = suspendCancellableCoroutine { cont ->
    imageCapture.takePicture(
        ContextCompat.getMainExecutor(context),
        object : ImageCapture.OnImageCapturedCallback() {
            override fun onCaptureSuccess(image: ImageProxy) {
                try {
                    val buffer = image.planes[0].buffer
                    val bytes = ByteArray(buffer.remaining())
                    buffer.get(bytes)
                    val decoded = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                    val oriented = applyRotation(decoded, image.imageInfo.rotationDegrees)
                    val bitmap = downscale(oriented, MAX_UPLOAD_EDGE)
                    val jpeg = java.io.ByteArrayOutputStream().use { out ->
                        bitmap.compress(Bitmap.CompressFormat.JPEG, 80, out)
                        out.toByteArray()
                    }
                    val dataUrl = "data:image/jpeg;base64," + Base64.encodeToString(jpeg, Base64.NO_WRAP)
                    cont.resume(dataUrl to bitmap)
                } finally {
                    image.close()
                }
            }

            override fun onError(exception: ImageCaptureException) {
                if (cont.isActive) cont.resume("" to Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888))
            }
        },
    )
}

/** Rotate the decoded frame upright (BitmapFactory ignores EXIF orientation). */
private fun applyRotation(bitmap: Bitmap, degrees: Int): Bitmap {
    if (degrees == 0) return bitmap
    val matrix = android.graphics.Matrix().apply { postRotate(degrees.toFloat()) }
    return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
}

/** Scale [bitmap] so its longest edge is at most [maxEdge], preserving aspect ratio. */
private fun downscale(bitmap: Bitmap, maxEdge: Int): Bitmap {
    val longest = maxOf(bitmap.width, bitmap.height)
    if (longest <= maxEdge) return bitmap
    val scale = maxEdge.toFloat() / longest
    return Bitmap.createScaledBitmap(
        bitmap, (bitmap.width * scale).toInt(), (bitmap.height * scale).toInt(), true,
    )
}

/** On-device ML Kit text recognition -> best plate-shaped candidate (fallback). */
private suspend fun recognizeOnDevice(bitmap: Bitmap): String? = suspendCancellableCoroutine { cont ->
    val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
    recognizer.process(InputImage.fromBitmap(bitmap, 0))
        .addOnSuccessListener { if (cont.isActive) cont.resume(PlateText.bestCandidate(it.text)) }
        .addOnFailureListener { if (cont.isActive) cont.resume(null) }
}
