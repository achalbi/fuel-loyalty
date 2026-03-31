# Vehicle Plate Scanner

This document explains the camera and OCR flow used on the staff transaction screen to capture a vehicle number plate, read the text in the browser, and prefill the vehicle number field.

## Purpose

The feature helps staff start a transaction from a number plate instead of typing the vehicle number manually. It is designed to:

- open directly from the new transaction page or the topbar camera shortcut
- use the device camera when live preview is available
- fall back to the native camera app or gallery upload when browser camera access is unavailable
- run OCR fully in the browser
- normalize noisy OCR output into an Indian vehicle registration format before lookup continues

## Main entry points

The feature is spread across a small set of files:

- `app/views/layouts/application.html.erb`
  - renders the topbar camera shortcut that links to `new_staff_transaction_path(plate_scanner: 1)`
- `app/assets/javascripts/application.js`
  - preflights camera permission from the topbar shortcut before navigating to the scanner screen
- `app/controllers/staff/transactions_controller.rb`
  - sets `@auto_open_plate_scanner` when `plate_scanner=1` is present
- `app/views/staff/transactions/new.html.erb`
  - includes `vehicle_plate_scanner.js`
  - renders the vehicle lookup tab and passes the `auto_open` flag into the scanner partial
- `app/views/staff/transactions/_vehicle_plate_field.html.erb`
  - defines the scanner UI: camera preview, guide overlay, camera-app fallback input, OCR result area, and action buttons
- `app/assets/javascripts/vehicle_plate_scanner.js`
  - owns camera startup, frame capture, OCR loading, preprocessing, text normalization, and field prefilling
- `test/controllers/staff/transactions_controller_test.rb`
  - covers the server-rendered contract for the scanner shell and auto-open flag

## User flows

### 1. Topbar shortcut flow

1. The user taps the topbar camera icon.
2. The app navigates to `/staff/transactions/new?plate_scanner=1`.
3. `Staff::TransactionsController#new` sets `@auto_open_plate_scanner`.
4. The vehicle lookup tab renders with `data-auto-open="true"`.
5. `vehicle_plate_scanner.js` opens the scanner panel automatically and tries to start the rear camera.

### 2. In-form scanner flow

1. The user opens the vehicle tab on the new transaction screen.
2. The user taps `Capture Plate`.
3. The scanner panel opens and requests rear-camera access.
4. The user captures a frame and reviews the preview.
5. The user taps `Use Photo`.
6. The browser runs OCR and fills the vehicle number field.

### 3. Camera-app fallback flow

If live preview is unavailable, the scanner keeps the panel open, shows a warning, and exposes:

- `Open Camera`
- `Use Camera App`
- manual typing in the vehicle number field

The hidden file input uses `accept="image/*"` with `capture="environment"` so the browser can launch the native camera app on supported devices.

## Server-side behavior

The server-side part is intentionally small.

### `Staff::TransactionsController#new`

The controller does three scanner-related things:

- authorizes access to the transaction screen
- decides which lookup tab should be active
- enables scanner auto-open when `params[:plate_scanner]` is present and the active lookup mode is `vehicle`

The OCR itself does not run on the server. No image is uploaded to Rails for recognition.

## View contract

The scanner partial exposes a DOM contract that the JavaScript depends on.

Important data attributes include:

- `data-plate-scanner-root`
- `data-input-id`
- `data-auto-open`
- `data-plate-scanner-open`
- `data-plate-scanner-panel`
- `data-plate-scanner-video`
- `data-plate-scanner-canvas`
- `data-plate-scanner-guide`
- `data-plate-scanner-file-input`
- `data-plate-scanner-capture`
- `data-plate-scanner-use`
- `data-plate-scanner-status`
- `data-plate-scanner-result`

The result panel is hidden by default and becomes visible only after OCR has run.

## Client-side implementation

All scanner behavior is implemented in `app/assets/javascripts/vehicle_plate_scanner.js`.

### Initialization

`initializePlateScanners()` finds every `[data-plate-scanner-root]` and binds it once.

Each scanner instance keeps a small local state:

- `stream`
  - the active camera stream, if any
- `capturedCanvas`
  - the last captured still image
- `autoOpenScheduled`
  - prevents duplicate auto-open scheduling
- `cameraStartInFlight`
  - deduplicates concurrent camera startup attempts

### Camera startup

`startCamera()`:

- checks browser camera support
- requests `getUserMedia`
- prefers the rear camera via `facingMode: { ideal: "environment" }`
- waits for video metadata
- calls `video.play()`
- resets the preview state on success

If camera startup fails, the feature does not leave the page. It shows a warning and exposes the manual fallback buttons.

### Frame capture

When the user taps `Capture`:

- the current video frame is drawn into an in-memory canvas
- the live video is hidden
- the still image preview is shown
- `Retake` and `Use Photo` become visible

No network request is made at capture time.

## OCR pipeline

### 1. Tesseract loading

The OCR engine is loaded lazily from a CDN the first time it is needed.

Primary sources:

- `https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/tesseract.min.js`
- `https://unpkg.com/tesseract.js@5/dist/tesseract.min.js`

The loader:

- reuses `window.Tesseract` if already present
- avoids duplicate script tags
- retries the mirror URL if the first CDN fails

### 2. Image preprocessing

OCR is intentionally run against a cropped, high-contrast version of the captured image.

`preprocessPlateCanvas()`:

- crops only the guide area defined by `GUIDE_RECT`
- scales the crop up to improve recognition
- converts it to grayscale
- increases contrast
- applies a hard threshold to produce a black/white image

This keeps OCR fast while improving plate readability.

### 3. OCR execution

`useCapturedPhoto()`:

1. loads Tesseract
2. preprocesses the captured image
3. runs `tesseract.recognize(processedCanvas, "eng")`
4. reads the raw recognized text
5. calculates an average confidence score
6. normalizes the text into the expected vehicle-number format
7. fills the transaction input
8. updates the UI result panel and status text

## Text normalization

OCR output is noisy, so the feature performs lightweight correction before using the text.

### Normalization steps

- uppercase the OCR result
- strip all non-alphanumeric characters
- accept a valid Indian plate immediately if it already matches
- otherwise attempt safe substitutions such as:
  - `O -> 0`
  - `I -> 1`
  - `S -> 5`
  - `B -> 8`
- support both:
  - standard Indian registrations
  - BH series registrations

### Safety guardrails

The correction logic is intentionally conservative:

- at most `MAX_SAFE_OCR_REPLACEMENTS` substitutions are allowed
- if the corrected value still does not match a known format, the raw normalized text is shown but marked for review

This avoids over-correcting the OCR output into a completely different plate.

## Result handling

After OCR completes:

- the vehicle number field is updated
- `input` and `change` events are dispatched
- the field is focused so the operator can edit it if needed
- the OCR result card shows:
  - cleaned plate text
  - confidence
  - raw OCR text
  - a review note based on validity and confidence

At that point the normal vehicle lookup flow continues using the prefixed value.

## Error handling and fallback behavior

The feature handles several failure modes:

- camera permission denied
- rear camera unavailable
- browser camera support missing
- captured image unreadable
- OCR library failed to load
- OCR returned no useful text

In all of these cases, the operator can still:

- retry the live camera
- use the device camera app
- type the vehicle number manually

## Browser notes

The implementation depends on browser APIs:

- `navigator.mediaDevices.getUserMedia`
- `<video>` live preview with `playsinline`
- `<canvas>` for frame extraction and preprocessing
- dynamically loaded `tesseract.js`

Because OCR is browser-side, server logs are only useful up to page render. Camera startup, still capture, OCR loading, and OCR recognition must be debugged in browser devtools.

## Debugging checklist

If the feature stops working, debug in this order:

1. Confirm the scanner panel opens.
2. Confirm `startCamera()` is being called.
3. Confirm `getUserMedia` resolves and `video.videoWidth` becomes non-zero.
4. Confirm `captureFrame()` creates a non-empty canvas.
5. Confirm `loadTesseract()` succeeds and `window.Tesseract` exists.
6. Confirm `preprocessPlateCanvas()` returns a meaningful crop.
7. Confirm `rawText`, `cleaned`, and `confidence` are sensible.
8. Confirm the input field is actually being filled.
9. If OCR succeeds but the customer is not found, debug the lookup flow separately from the scanner.

## Testing coverage

Current automated coverage is server-rendered and contract-oriented. The integration test verifies:

- the topbar scanner shortcut exists
- the vehicle scanner partial renders
- the required data attributes and controls are present
- `plate_scanner=1` enables the auto-open flag

The OCR recognition itself is not currently covered by automated browser tests.

## Maintenance notes

If the feature needs improvement in the future, the most likely areas are:

- tuning `GUIDE_RECT`
- tuning preprocessing thresholds and contrast
- improving OCR confidence heuristics
- expanding normalization rules for regional plate edge cases
- adding a browser-level test harness or debug mode for processed images
