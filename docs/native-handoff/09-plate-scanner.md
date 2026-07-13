# 09 — Vehicle Plate Scanner

Camera-based plate capture that fills the vehicle-number field in the transaction wizard. Three layers: camera capture → server recognition (Plate Recognizer API) → on-device OCR fallback (Tesseract.js). A native app should replace layer 3 with on-device ML (e.g. ML Kit / Vision) and keep layer 2's endpoint.

## Entry points

- Topbar camera button: on the transaction screen it toggles the scanner (switching to the vehicle tab first if needed); elsewhere it navigates to `/staff/transactions/new?plate_scanner=1` (vehicle tab + scanner auto-open).
- In-form scanner controls on the vehicle-number field.

## Capture (current web behavior → native camera)

- `getUserMedia` constraints: rear camera (`facingMode ideal environment`), ideal 1920×1080. Buttons: **Live Preview / Capture / Open Camera (native camera app file fallback, `capture="environment"`) / Retake / Use Photo / Close**; a plate-shaped guide overlay; status line.
- Capture draws the full video frame to a canvas at native resolution; encoded as **JPEG quality 0.88 data-URL** (no resizing).
- Camera teardown on navigation/page-hide (native: stop the camera on screen unmount).

## Server recognition

`POST /staff/transactions/recognize_plate` — body `{"plate_scan": {"image_data": "data:image/jpeg;base64,..."}}` (staff auth).

Server (`VehiclePlateRecognizer`) forwards to Plate Recognizer: `POST https://api.platerecognizer.com/v1/plate-reader/` (overridable via `PLATE_RECOGNIZER_API_URL`), `Authorization: Token <PLATE_RECOGNIZER_API_TOKEN>`, multipart `upload` (decoded image) + `regions` (default `in`). Timeouts 5 s open / 20 s read. Each candidate is normalized via the OCR-correction rules (04.6) and scored: valid format > API score > length.

Responses:
- 200 found: `{found: true, plate, raw, confidence (0–100), valid, corrected, provider: "plate_recognizer", candidates: [top 3 {plate, raw, confidence, valid, corrected}]}`
- 422: `{found: false, message: "No clear vehicle number could be recognized. Please retake the photo."}`
- 503: not configured ("Plate recognition service is not configured.") — client knows upfront via a server-rendered availability flag.
- 502: upstream/recognition errors.

## On-device OCR fallback (web) — replace natively

When the server path is unavailable/fails: Tesseract.js v5 from CDN. Preprocessing: crop to guide rect `{x: 0.08, y: 0.34, w: 0.84, h: 0.28}` (fractions of frame), upscale ≥1.8× (target width ≥1200), grayscale, contrast +70, hard threshold 148 → B/W, recognize `eng`, confidence = mean word confidence. Native equivalent: ML Kit text recognition / iOS Vision on the cropped guide region, then apply the same normalization.

## Result handling (client)

Detected text → `normalize_detected` (uppercase, strip non-alphanumerics, safe substitutions capped at 3 — see 04.6) → fill the vehicle-number input and trigger the lookup. Result card shows cleaned plate, raw text, confidence, with warning styling when invalid or confidence < 70: "Vehicle number added from {provider}. Review it and continue." vs "…Please verify the detected number before saving."

Full original doc: `docs/vehicle-plate-scanner.md` in the repo (includes debugging checklist).
