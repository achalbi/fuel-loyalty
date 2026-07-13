package com.acefuel.loyalty.ui.scanner

import android.Manifest
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.provider.Settings
import android.util.Base64
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.FlashOff
import androidx.compose.material.icons.filled.FlashOn
import androidx.compose.material.icons.filled.NoPhotography
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.acefuel.loyalty.core.di.LocalContainer
import com.acefuel.loyalty.ui.designsystem.EmptyState
import com.acefuel.loyalty.ui.designsystem.ErrorState
import com.acefuel.loyalty.ui.designsystem.FormField
import com.acefuel.loyalty.ui.designsystem.NayaraSnackbarHost
import com.acefuel.loyalty.ui.designsystem.NayaraTopBar
import com.acefuel.loyalty.ui.designsystem.PlateChip
import com.acefuel.loyalty.ui.designsystem.rememberHaptics
import com.acefuel.loyalty.ui.designsystem.showError
import com.acefuel.loyalty.ui.designsystem.showInfo
import com.acefuel.loyalty.ui.theme.NayaraButton
import com.acefuel.loyalty.ui.theme.NayaraMotion
import com.acefuel.loyalty.ui.theme.NayaraOutlinedButton
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import com.acefuel.loyalty.ui.theme.nayara
import com.google.accompanist.permissions.ExperimentalPermissionsApi
import com.google.accompanist.permissions.isGranted
import com.google.accompanist.permissions.rememberPermissionState
import com.google.accompanist.permissions.shouldShowRationale
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

private enum class ScanBranch { Permission, Camera, Result, Error }

@OptIn(ExperimentalPermissionsApi::class, ExperimentalMaterial3Api::class)
@Composable
fun PlateScannerScreen(onBack: () -> Unit, onResult: (String) -> Unit) {
    val container = LocalContainer.current
    val repo = remember { PlateScanRepository.from(container.plateRetrofit, container.json) }
    val viewModel: PlateScannerViewModel = viewModel(
        factory = viewModelFactory { initializer { PlateScannerViewModel(repo) } },
    )
    val state by viewModel.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val snackbar = remember { SnackbarHostState() }
    val haptics = rememberHaptics()

    // Track whether a request has completed so "denied without rationale" can be
    // told apart from "never asked" (both look identical in PermissionStatus).
    var permissionRequested by rememberSaveable { mutableStateOf(false) }
    val cameraPermission = rememberPermissionState(Manifest.permission.CAMERA) {
        permissionRequested = true
    }

    var capturing by remember { mutableStateOf(false) }
    var shutterFlash by remember { mutableStateOf(false) }
    var torchOn by rememberSaveable { mutableStateOf(false) }
    val imageCapture = remember {
        ImageCapture.Builder().setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY).build()
    }

    LaunchedEffect(state.plate) { if (state.plate != null) haptics.confirm() }
    LaunchedEffect(state.error) { if (state.error != null) haptics.reject() }
    LaunchedEffect(state.infoMessage) {
        val message = state.infoMessage ?: return@LaunchedEffect
        // Show first, consume after: consuming nulls this effect's key and
        // would cancel the still-suspended showInfo.
        snackbar.showInfo(message)
        viewModel.consumeInfoMessage()
    }

    fun capture() {
        haptics.tick()
        scope.launch {
            shutterFlash = true
            delay(NayaraMotion.Instant * 2L)
            shutterFlash = false
        }
        scope.launch {
            capturing = true
            try {
                val frame = captureFrame(imageCapture, context)
                val (dataUrl, bitmap) = encodeForUpload(frame)
                val ocr = recognizeOnDevice(bitmap)
                viewModel.recognize(dataUrl, ocr, bitmap)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                // ImageCaptureException or a decode failure — back to the preview.
                // Launch the snackbar on a separate scope so awaiting it doesn't
                // hold the touch-blocking "Capturing…" scrim up for its duration.
                haptics.reject()
                scope.launch { snackbar.showError("Capture failed — try again") }
            } finally {
                capturing = false
            }
        }
    }

    Scaffold(
        topBar = { NayaraTopBar(title = "Scan Plate", onBack = onBack) },
        snackbarHost = { NayaraSnackbarHost(snackbar) },
    ) { pad ->
        val branch = when {
            !cameraPermission.status.isGranted -> ScanBranch.Permission
            state.plate != null -> ScanBranch.Result
            state.error != null -> ScanBranch.Error
            else -> ScanBranch.Camera
        }
        AnimatedContent(
            targetState = branch,
            transitionSpec = {
                fadeIn(tween(NayaraMotion.Base, easing = NayaraMotion.Enter)) togetherWith
                    fadeOut(tween(NayaraMotion.Base, easing = NayaraMotion.Exit))
            },
            label = "scannerBranch",
            modifier = Modifier.fillMaxSize().padding(pad),
        ) { target ->
            when (target) {
                ScanBranch.Permission -> PermissionBranch(
                    shouldShowRationale = cameraPermission.status.shouldShowRationale,
                    requestedOnce = permissionRequested,
                    onRequest = { cameraPermission.launchPermissionRequest() },
                    onOpenSettings = {
                        context.startActivity(
                            Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.fromParts("package", context.packageName, null),
                            ),
                        )
                    },
                )

                ScanBranch.Result -> {
                    val plate = state.plate
                    if (plate != null) {
                        Column(
                            Modifier
                                .fillMaxSize()
                                .verticalScroll(rememberScrollState())
                                .padding(NayaraSpacing.Xl),
                        ) {
                            ResultCard(
                                plate = plate,
                                confidence = state.confidence,
                                valid = state.valid,
                                provider = state.provider,
                                thumbnail = state.capturedFrame,
                                onUse = onResult,
                                onRetake = viewModel::reset,
                            )
                        }
                    }
                }

                ScanBranch.Error -> {
                    val error = state.error
                    if (error != null) {
                        Column(
                            Modifier.fillMaxSize().padding(NayaraSpacing.Xl),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.Center,
                        ) {
                            ErrorState(
                                message = error,
                                title = "Recognition failed",
                                onRetry = viewModel::retry,
                            )
                            NayaraOutlinedButton(onClick = viewModel::reset) { Text("Retake") }
                        }
                    }
                }

                ScanBranch.Camera -> CameraBranch(
                    imageCapture = imageCapture,
                    capturing = capturing,
                    recognizing = state.recognizing,
                    shutterFlash = shutterFlash,
                    torchOn = torchOn,
                    onToggleTorch = {
                        haptics.tick()
                        torchOn = !torchOn
                    },
                    onCapture = { capture() },
                )
            }
        }
    }
}

@Composable
private fun PermissionBranch(
    shouldShowRationale: Boolean,
    requestedOnce: Boolean,
    onRequest: () -> Unit,
    onOpenSettings: () -> Unit,
) {
    // After a completed request, denial without rationale means "don't ask again":
    // the system dialog will never reappear, so route the operator to settings.
    val permanentlyDenied = requestedOnce && !shouldShowRationale
    Column(
        Modifier.fillMaxSize().padding(NayaraSpacing.Xl),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        if (permanentlyDenied) {
            EmptyState(
                title = "Camera access denied",
                message = "Enable camera access in app settings to scan vehicle plates.",
                icon = Icons.Filled.NoPhotography,
                actionLabel = "Open settings",
                onAction = onOpenSettings,
            )
        } else {
            EmptyState(
                title = "Camera access needed",
                message = if (shouldShowRationale) {
                    "The camera is only used to read vehicle number plates at the pump."
                } else {
                    "Camera access is needed to scan a vehicle plate."
                },
                icon = Icons.Filled.CameraAlt,
                actionLabel = "Grant camera access",
                onAction = onRequest,
            )
        }
    }
}

@Composable
private fun CameraBranch(
    imageCapture: ImageCapture,
    capturing: Boolean,
    recognizing: Boolean,
    shutterFlash: Boolean,
    torchOn: Boolean,
    onToggleTorch: () -> Unit,
    onCapture: () -> Unit,
) {
    val lifecycleOwner = LocalLifecycleOwner.current
    var camera by remember { mutableStateOf<Camera?>(null) }
    var cameraProvider by remember { mutableStateOf<ProcessCameraProvider?>(null) }
    var cameraError by remember { mutableStateOf<String?>(null) }
    var bindAttempt by remember { mutableStateOf(0) }

    // Re-apply torch whenever the camera (re)binds or the toggle changes.
    LaunchedEffect(camera, torchOn) { camera?.cameraControl?.enableTorch(torchOn) }

    // Leaving the camera branch (e.g. onto the result card) must extinguish the
    // torch and release the camera — it is bound to the still-RESUMED nav entry,
    // so nothing else would unbind it.
    DisposableEffect(Unit) {
        onDispose {
            runCatching { camera?.cameraControl?.enableTorch(false) }
            runCatching { cameraProvider?.unbindAll() }
        }
    }

    Box(Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize().padding(NayaraSpacing.Xl)) {
            val bindError = cameraError
            if (bindError != null) {
                Box(Modifier.fillMaxWidth().weight(1f), contentAlignment = Alignment.Center) {
                    ErrorState(
                        message = bindError,
                        title = "Camera unavailable",
                        onRetry = {
                            cameraError = null
                            bindAttempt++
                        },
                    )
                }
            } else {
                Box(Modifier.fillMaxWidth().weight(1f)) {
                    // key() recreates the PreviewView so retry re-attempts the bind.
                    key(bindAttempt) {
                        AndroidView(
                            modifier = Modifier.fillMaxSize(),
                            factory = { ctx ->
                                val previewView = PreviewView(ctx)
                                val future = ProcessCameraProvider.getInstance(ctx)
                                future.addListener({
                                    try {
                                        val provider = future.get()
                                        cameraProvider = provider
                                        val preview = Preview.Builder().build().also {
                                            it.setSurfaceProvider(previewView.surfaceProvider)
                                        }
                                        provider.unbindAll()
                                        camera = provider.bindToLifecycle(
                                            lifecycleOwner, CameraSelector.DEFAULT_BACK_CAMERA,
                                            preview, imageCapture,
                                        )
                                    } catch (t: Throwable) {
                                        camera = null
                                        cameraError = t.message ?: "The camera could not be started."
                                    }
                                }, ContextCompat.getMainExecutor(ctx))
                                previewView
                            },
                        )
                    }
                    PlateViewfinder(
                        caption = "Point at the number plate and capture.",
                        modifier = Modifier.fillMaxSize(),
                    )
                    if (camera?.cameraInfo?.hasFlashUnit() == true) {
                        IconButton(
                            onClick = onToggleTorch,
                            modifier = Modifier.align(Alignment.TopEnd).padding(NayaraSpacing.Sm),
                        ) {
                            Icon(
                                if (torchOn) Icons.Filled.FlashOn else Icons.Filled.FlashOff,
                                contentDescription = if (torchOn) "Turn torch off" else "Turn torch on",
                                tint = Color.White,
                            )
                        }
                    }
                    androidx.compose.animation.AnimatedVisibility(
                        visible = shutterFlash,
                        enter = fadeIn(tween(NayaraMotion.Instant)),
                        exit = fadeOut(tween(NayaraMotion.Instant)),
                        modifier = Modifier.matchParentSize(),
                    ) {
                        Box(Modifier.fillMaxSize().background(Color.White))
                    }
                }
                Spacer(Modifier.height(NayaraSpacing.Lg))
                NayaraButton(
                    onClick = onCapture,
                    enabled = !capturing && !recognizing && camera != null,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text("Capture")
                }
            }
        }
        AnimatedVisibility(
            visible = capturing || recognizing,
            enter = fadeIn(tween(NayaraMotion.Fast)),
            exit = fadeOut(tween(NayaraMotion.Fast)),
        ) {
            ProcessingScrim(label = if (recognizing) "Recognizing plate…" else "Capturing…")
        }
    }
}

/** Dimmed scrim with a plate-shaped cutout (~3.5:1), corner guides and caption. */
@Composable
private fun PlateViewfinder(caption: String, modifier: Modifier = Modifier) {
    val scrim = MaterialTheme.nayara.overlayScrim
    BoxWithConstraints(modifier) {
        val cutoutWidth = maxWidth * 0.82f
        val cutoutHeight = cutoutWidth / 3.5f
        Canvas(
            Modifier
                .fillMaxSize()
                // Offscreen compositing so BlendMode.Clear punches a hole in the
                // scrim layer instead of the whole window.
                .graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen },
        ) {
            val cw = cutoutWidth.toPx()
            val ch = cutoutHeight.toPx()
            val left = (size.width - cw) / 2f
            val top = (size.height - ch) / 2f
            drawRect(scrim)
            drawRoundRect(
                color = Color.Black,
                topLeft = Offset(left, top),
                size = Size(cw, ch),
                cornerRadius = CornerRadius(16.dp.toPx()),
                blendMode = BlendMode.Clear,
            )
            val guide = 20.dp.toPx()
            val stroke = 3.dp.toPx()
            fun cornerGuide(x: Float, y: Float, dx: Float, dy: Float) {
                drawLine(Color.White, Offset(x, y), Offset(x + dx * guide, y), stroke, StrokeCap.Round)
                drawLine(Color.White, Offset(x, y), Offset(x, y + dy * guide), stroke, StrokeCap.Round)
            }
            cornerGuide(left, top, 1f, 1f)
            cornerGuide(left + cw, top, -1f, 1f)
            cornerGuide(left, top + ch, 1f, -1f)
            cornerGuide(left + cw, top + ch, -1f, -1f)
        }
        Text(
            caption,
            style = MaterialTheme.typography.bodyMedium,
            color = Color.White,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .align(Alignment.Center)
                .offset(y = cutoutHeight / 2 + NayaraSpacing.Xxl),
        )
    }
}

/** Full-branch scrim with a staged progress label; swallows all touches. */
@Composable
private fun ProcessingScrim(label: String) {
    Box(
        Modifier
            .fillMaxSize()
            .background(MaterialTheme.nayara.overlayScrim)
            .pointerInput(Unit) {
                awaitPointerEventScope {
                    while (true) {
                        awaitPointerEvent().changes.forEach { it.consume() }
                    }
                }
            },
        contentAlignment = Alignment.Center,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            CircularProgressIndicator(color = Color.White)
            Spacer(Modifier.height(NayaraSpacing.Lg))
            Text(label, style = MaterialTheme.typography.bodyMedium, color = Color.White)
        }
    }
}

@Composable
private fun ResultCard(
    plate: String,
    confidence: Double?,
    valid: Boolean,
    provider: String?,
    thumbnail: Bitmap?,
    onUse: (String) -> Unit,
    onRetake: () -> Unit,
) {
    var edited by remember(plate) { mutableStateOf(PlateText.normalize(plate)) }
    val detectedNormalized = remember(plate) { PlateText.normalize(plate) }
    val normalized = PlateText.normalize(edited)
    val looksValid = PlateText.isValid(normalized)
    // Low trust: the recognizer flagged the original, or the edit isn't plate-shaped.
    val needsVerify = !looksValid || (normalized == detectedNormalized && !valid)

    Card(modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(NayaraSpacing.Xl)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                if (thumbnail != null) {
                    Image(
                        bitmap = thumbnail.asImageBitmap(),
                        contentDescription = "Captured frame",
                        contentScale = ContentScale.Crop,
                        modifier = Modifier.size(56.dp).clip(MaterialTheme.shapes.small),
                    )
                    Spacer(Modifier.width(NayaraSpacing.Md))
                }
                Column {
                    Text(
                        "Detected plate",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.nayara.textSecondary,
                    )
                    val meta = buildString {
                        provider?.let { append(if (it == "on_device") "On-device" else "Plate Recognizer") }
                        confidence?.let { append(" · ${it.toInt()}%") }
                    }
                    if (meta.isNotBlank()) {
                        Text(meta, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.nayara.textSecondary)
                    }
                }
            }
            Spacer(Modifier.height(NayaraSpacing.Lg))
            FormField(
                value = edited,
                onValueChange = { input ->
                    edited = input.uppercase().filter { it.isLetterOrDigit() }.take(11)
                },
                label = "Vehicle number",
                helper = "Correct the number if the scan misread it.",
                keyboardOptions = KeyboardOptions(
                    capitalization = KeyboardCapitalization.Characters,
                    keyboardType = KeyboardType.Ascii,
                    imeAction = ImeAction.Done,
                ),
            )
            Spacer(Modifier.height(NayaraSpacing.Sm))
            if (normalized.isNotEmpty()) {
                PlateChip(normalized)
            }
            if (needsVerify) {
                Spacer(Modifier.height(NayaraSpacing.Sm))
                Text(
                    "Please verify the detected number before saving.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.error,
                )
            }
        }
    }
    Spacer(Modifier.height(NayaraSpacing.Lg))
    NayaraButton(
        onClick = { onUse(normalized) },
        enabled = normalized.length in 6..11,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Text(if (normalized.isEmpty()) "Use plate" else "Use $normalized")
    }
    Spacer(Modifier.height(NayaraSpacing.Sm))
    NayaraOutlinedButton(onClick = onRetake, modifier = Modifier.fillMaxWidth()) { Text("Retake") }
}

/** Longest edge (px) we upload for recognition — plenty for ALPR, keeps the
 *  base64 body small so it uploads well within the request timeout. */
private const val MAX_UPLOAD_EDGE = 1600

/** Raw JPEG bytes + rotation from a single still capture. */
private class CapturedFrame(val bytes: ByteArray, val rotationDegrees: Int)

/** Take one still frame. Capture failures propagate as [ImageCaptureException]. */
private suspend fun captureFrame(
    imageCapture: ImageCapture,
    context: Context,
): CapturedFrame = suspendCancellableCoroutine { cont ->
    imageCapture.takePicture(
        ContextCompat.getMainExecutor(context),
        object : ImageCapture.OnImageCapturedCallback() {
            override fun onCaptureSuccess(image: ImageProxy) {
                try {
                    val buffer = image.planes[0].buffer
                    val bytes = ByteArray(buffer.remaining())
                    buffer.get(bytes)
                    if (cont.isActive) cont.resume(CapturedFrame(bytes, image.imageInfo.rotationDegrees))
                } finally {
                    image.close()
                }
            }

            override fun onError(exception: ImageCaptureException) {
                if (cont.isActive) cont.resumeWithException(exception)
            }
        },
    )
}

/** Decode/rotate/downscale/base64 off the main thread. The full-resolution sensor
 *  JPEG base64-encodes to several MB and times out on mobile networks. */
private suspend fun encodeForUpload(frame: CapturedFrame): Pair<String, Bitmap> =
    withContext(Dispatchers.Default) {
        val decoded = BitmapFactory.decodeByteArray(frame.bytes, 0, frame.bytes.size)
            ?: error("Could not decode the captured frame")
        val oriented = applyRotation(decoded, frame.rotationDegrees)
        val bitmap = downscale(oriented, MAX_UPLOAD_EDGE)
        val jpeg = java.io.ByteArrayOutputStream().use { out ->
            bitmap.compress(Bitmap.CompressFormat.JPEG, 80, out)
            out.toByteArray()
        }
        "data:image/jpeg;base64," + Base64.encodeToString(jpeg, Base64.NO_WRAP) to bitmap
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
