(() => {
  const OCR_SCRIPT_URLS = [
    "https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/tesseract.min.js",
    "https://unpkg.com/tesseract.js@5/dist/tesseract.min.js"
  ];
  const GUIDE_RECT = { x: 0.08, y: 0.34, width: 0.84, height: 0.28 };
  const STANDARD_PLATE_PATTERN = /^[A-Z]{2}[0-9]{1,2}[A-Z]{0,3}[0-9]{1,4}$/;
  const BH_PLATE_PATTERN = /^[0-9]{2}BH[0-9]{4}[A-Z]{2}$/;
  const MAX_SAFE_OCR_REPLACEMENTS = 3;
  const LETTER_SUBSTITUTIONS = {
    "0": "O",
    "1": "I",
    "2": "Z",
    "5": "S",
    "6": "G",
    "8": "B"
  };
  const DIGIT_SUBSTITUTIONS = {
    O: "0",
    Q: "0",
    D: "0",
    I: "1",
    L: "1",
    T: "1",
    Z: "2",
    S: "5",
    B: "8",
    G: "6"
  };

  let tesseractPromise = null;

  const normalizePlateText = (value) => value.toUpperCase().replace(/[^A-Z0-9]/g, "");
  const validPlateText = (value) => STANDARD_PLATE_PATTERN.test(value) || BH_PLATE_PATTERN.test(value);
  const replaceCharacters = (value, replacements) => value.split("").map((character) => replacements[character] || character).join("");

  const buildBhCandidate = (value) => {
    if (value.length !== 10) return null;

    const candidate = [
      replaceCharacters(value.slice(0, 2), DIGIT_SUBSTITUTIONS),
      replaceCharacters(value.slice(2, 4), LETTER_SUBSTITUTIONS),
      replaceCharacters(value.slice(4, 8), DIGIT_SUBSTITUTIONS),
      replaceCharacters(value.slice(8, 10), LETTER_SUBSTITUTIONS)
    ].join("");

    const replacements = candidate.split("").filter((character, index) => character !== value[index]).length;

    if (replacements > MAX_SAFE_OCR_REPLACEMENTS) return null;
    return candidate.slice(2, 4) === "BH" && BH_PLATE_PATTERN.test(candidate) ? candidate : null;
  };

  const buildStandardCandidate = (value) => {
    if (value.length < 4 || value.length > 11) return null;

    let bestCandidate = null;

    for (let districtLength = 1; districtLength <= 2; districtLength += 1) {
      for (let seriesLength = 0; seriesLength <= 3; seriesLength += 1) {
        const numberLength = value.length - 2 - districtLength - seriesLength;
        if (numberLength < 1 || numberLength > 4) continue;

        const candidate = [
          replaceCharacters(value.slice(0, 2), LETTER_SUBSTITUTIONS),
          replaceCharacters(value.slice(2, 2 + districtLength), DIGIT_SUBSTITUTIONS),
          replaceCharacters(value.slice(2 + districtLength, 2 + districtLength + seriesLength), LETTER_SUBSTITUTIONS),
          replaceCharacters(value.slice(value.length - numberLength), DIGIT_SUBSTITUTIONS)
        ].join("");

        if (!STANDARD_PLATE_PATTERN.test(candidate)) continue;

        const replacements = candidate.split("").filter((character, index) => character !== value[index]).length;
        if (replacements > MAX_SAFE_OCR_REPLACEMENTS) continue;
        if (!bestCandidate || replacements < bestCandidate.replacements) {
          bestCandidate = { candidate, replacements };
        }
      }
    }

    return bestCandidate?.candidate || null;
  };

  const normalizeDetectedPlate = (value) => {
    const normalized = normalizePlateText(value);
    if (!normalized) {
      return { cleaned: "", raw: "", valid: false, corrected: false };
    }

    if (validPlateText(normalized)) {
      return { cleaned: normalized, raw: normalized, valid: true, corrected: false };
    }

    const candidate = buildStandardCandidate(normalized) || buildBhCandidate(normalized) || normalized;
    return {
      cleaned: candidate,
      raw: normalized,
      valid: validPlateText(candidate),
      corrected: candidate !== normalized
    };
  };

  const loadScript = (source) =>
    new Promise((resolve, reject) => {
      if (window.Tesseract) {
        resolve(window.Tesseract);
        return;
      }

      const existingScript = document.querySelector(`script[data-ocr-script="${source}"]`);
      if (existingScript) {
        if (existingScript.dataset.loaded === "true") {
          resolve(window.Tesseract || null);
          return;
        }

        existingScript.addEventListener("load", () => resolve(window.Tesseract || null), { once: true });
        existingScript.addEventListener("error", () => reject(new Error(`Unable to load ${source}`)), { once: true });
        return;
      }

      const script = document.createElement("script");
      script.src = source;
      script.async = true;
      script.defer = true;
      script.crossOrigin = "anonymous";
      script.dataset.ocrScript = source;
      script.onload = () => {
        script.dataset.loaded = "true";
        resolve(window.Tesseract || null);
      };
      script.onerror = () => reject(new Error(`Unable to load ${source}`));
      document.head.appendChild(script);
    });

  const loadTesseract = async () => {
    if (window.Tesseract) return window.Tesseract;
    if (tesseractPromise) return tesseractPromise;

    tesseractPromise = (async () => {
      for (const source of OCR_SCRIPT_URLS) {
        try {
          const tesseract = await loadScript(source);
          if (tesseract) return tesseract;
        } catch (_error) {
          // Try the next CDN mirror.
        }
      }

      throw new Error("Unable to load OCR engine.");
    })().catch((error) => {
      tesseractPromise = null;
      throw error;
    });

    return tesseractPromise;
  };

  const createPreviewCanvas = (width, height) => {
    const canvas = document.createElement("canvas");
    canvas.width = width;
    canvas.height = height;
    return canvas;
  };

  // Crop the middle guide area and increase contrast before OCR so the browser-side scan
  // stays reasonably fast while still being accurate enough for number plates.
  const preprocessPlateCanvas = (sourceCanvas) => {
    const cropX = Math.round(sourceCanvas.width * GUIDE_RECT.x);
    const cropY = Math.round(sourceCanvas.height * GUIDE_RECT.y);
    const cropWidth = Math.round(sourceCanvas.width * GUIDE_RECT.width);
    const cropHeight = Math.round(sourceCanvas.height * GUIDE_RECT.height);
    const scale = Math.max(1.8, 1200 / Math.max(cropWidth, 1));
    const processedCanvas = createPreviewCanvas(Math.round(cropWidth * scale), Math.round(cropHeight * scale));
    const context = processedCanvas.getContext("2d", { willReadFrequently: true });

    context.drawImage(
      sourceCanvas,
      cropX,
      cropY,
      cropWidth,
      cropHeight,
      0,
      0,
      processedCanvas.width,
      processedCanvas.height
    );

    const imageData = context.getImageData(0, 0, processedCanvas.width, processedCanvas.height);
    const data = imageData.data;
    const contrast = 70;
    const contrastFactor = (259 * (contrast + 255)) / (255 * (259 - contrast));

    for (let index = 0; index < data.length; index += 4) {
      const grayscale = (0.299 * data[index]) + (0.587 * data[index + 1]) + (0.114 * data[index + 2]);
      const contrasted = Math.max(0, Math.min(255, (contrastFactor * (grayscale - 128)) + 128));
      const thresholded = contrasted > 148 ? 255 : 0;

      data[index] = thresholded;
      data[index + 1] = thresholded;
      data[index + 2] = thresholded;
    }

    context.putImageData(imageData, 0, 0);
    return processedCanvas;
  };

  const averageConfidence = (ocrData) => {
    const wordConfidences = (ocrData.words || [])
      .map((word) => Number.parseFloat(word.confidence))
      .filter((confidence) => Number.isFinite(confidence));

    if (wordConfidences.length > 0) {
      const total = wordConfidences.reduce((sum, value) => sum + value, 0);
      return total / wordConfidences.length;
    }

    const fallback = Number.parseFloat(ocrData.confidence);
    return Number.isFinite(fallback) ? fallback : 0;
  };

  const cameraSupported = () => Boolean(navigator.mediaDevices?.getUserMedia);

  const humanizeCameraError = (error) => {
    if (error?.name === "NotAllowedError" || error?.name === "SecurityError") {
      return "Camera permission was denied. Enable camera access, use Camera App, or type the vehicle number manually.";
    }

    if (error?.name === "NotFoundError" || error?.name === "OverconstrainedError") {
      return "A rear camera is not available on this device. Use Camera App or type the vehicle number manually instead.";
    }

    return "Camera preview could not be started right now. Try Camera App or type the vehicle number manually.";
  };

  const prepareVideoPreview = (video) => {
    video.autoplay = true;
    video.muted = true;
    video.playsInline = true;
    video.setAttribute("autoplay", "autoplay");
    video.setAttribute("muted", "muted");
    video.setAttribute("playsinline", "playsinline");
  };

  const waitForVideoReady = (video) =>
    new Promise((resolve) => {
      if (video.readyState >= HTMLMediaElement.HAVE_CURRENT_DATA) {
        resolve();
        return;
      }

      let finished = false;
      const finish = () => {
        if (finished) return;
        finished = true;
        video.removeEventListener("loadedmetadata", finish);
        video.removeEventListener("loadeddata", finish);
        resolve();
      };

      video.addEventListener("loadedmetadata", finish, { once: true });
      video.addEventListener("loadeddata", finish, { once: true });
      window.setTimeout(finish, 800);
    });

  const loadImageFileToCanvas = (file) =>
    new Promise((resolve, reject) => {
      if (!file) {
        reject(new Error("No photo selected."));
        return;
      }

      const objectUrl = URL.createObjectURL(file);
      const image = new Image();

      image.onload = () => {
        const imageCanvas = createPreviewCanvas(image.naturalWidth || image.width, image.naturalHeight || image.height);
        imageCanvas.getContext("2d").drawImage(image, 0, 0, imageCanvas.width, imageCanvas.height);
        URL.revokeObjectURL(objectUrl);
        resolve(imageCanvas);
      };

      image.onerror = () => {
        URL.revokeObjectURL(objectUrl);
        reject(new Error("The selected image could not be read."));
      };

      image.src = objectUrl;
    });

  const initPlateScanner = (root) => {
    if (!root || root.__plateScannerBound === true) return;

    const input = document.getElementById(root.dataset.inputId || "");
    const panel = root.querySelector("[data-plate-scanner-panel]");
    const openButton = root.querySelector("[data-plate-scanner-open]");
    const startButton = root.querySelector("[data-plate-scanner-start]");
    const fileTriggerButton = root.querySelector("[data-plate-scanner-file-trigger]");
    const fileInput = root.querySelector("[data-plate-scanner-file-input]");
    const captureButton = root.querySelector("[data-plate-scanner-capture]");
    const retakeButton = root.querySelector("[data-plate-scanner-retake]");
    const useButton = root.querySelector("[data-plate-scanner-use]");
    const closeButton = root.querySelector("[data-plate-scanner-close]");
    const video = root.querySelector("[data-plate-scanner-video]");
    const canvas = root.querySelector("[data-plate-scanner-canvas]");
    const guide = root.querySelector("[data-plate-scanner-guide]");
    const status = root.querySelector("[data-plate-scanner-status]");
    const result = root.querySelector("[data-plate-scanner-result]");
    const cleanedTarget = root.querySelector("[data-plate-scanner-cleaned]");
    const noteTarget = root.querySelector("[data-plate-scanner-note]");
    const rawTarget = root.querySelector("[data-plate-scanner-raw]");
    const confidenceTarget = root.querySelector("[data-plate-scanner-confidence]");

    const requiredNodes = {
      input,
      panel,
      openButton,
      startButton,
      fileTriggerButton,
      fileInput,
      captureButton,
      retakeButton,
      useButton,
      closeButton,
      video,
      canvas,
      guide,
      status,
      result,
      cleanedTarget,
      noteTarget,
      rawTarget,
      confidenceTarget
    };
    const missingRequiredNodes = Object.entries(requiredNodes)
      .filter(([_name, node]) => !node)
      .map(([name]) => name);

    if (missingRequiredNodes.length > 0) {
      console.warn("[plate-scanner] Missing required elements:", missingRequiredNodes.join(", "));
      return;
    }

    root.__plateScannerBound = true;

    let stream = null;
    let capturedCanvas = null;
    let autoOpenScheduled = false;
    let cameraStartInFlight = null;

    const setStatus = (message, tone = "neutral") => {
      status.textContent = message;
      status.dataset.tone = tone;
    };

    const showLiveVideoShell = () => {
      canvas.hidden = true;
      canvas.width = 0;
      canvas.height = 0;
      video.hidden = false;
      guide.hidden = false;
      capturedCanvas = null;
      retakeButton.hidden = true;
      useButton.hidden = true;
      captureButton.hidden = false;
    };

    const showPlayablePreviewState = () => {
      showLiveVideoShell();
      captureButton.disabled = !stream;
      startButton.hidden = Boolean(stream);
    };

    const showGestureRetryState = (message) => {
      showLiveVideoShell();
      startButton.hidden = false;
      captureButton.disabled = true;
      setStatus(message, "warning");
    };

    const stopStream = () => {
      if (!stream) return;

      stream.getTracks().forEach((track) => track.stop());
      stream = null;
      video.srcObject = null;
    };

    const resetPreview = () => {
      showPlayablePreviewState();
    };

    const setPanelOpen = (open) => {
      panel.hidden = !open;
      openButton.setAttribute("aria-expanded", open ? "true" : "false");
      root.classList.toggle("is-open", open);

      if (!open) {
        stopStream();
        resetPreview();
      }
    };

    const launchCameraAppFallback = ({ message } = {}) => {
      stopStream();
      startButton.hidden = false;
      captureButton.disabled = true;

      setStatus(message, "warning");
    };

    const ensureVideoPlayback = async ({ allowGestureFallback = true } = {}) => {
      try {
        await video.play();
        resetPreview();
        setStatus("Align the vehicle number plate inside the guide, then tap Capture.", "neutral");
        return true;
      } catch (error) {
        console.warn("[plate-scanner] video.play() rejected", error);

        if (!allowGestureFallback) {
          launchCameraAppFallback({
            message: humanizeCameraError(error)
          });
          return false;
        }

        showGestureRetryState("Live preview is ready but needs one more tap. Tap Open Camera to continue, or use Camera App instead.");
        return false;
      }
    };

    const startCamera = async () => {
      if (cameraStartInFlight) return cameraStartInFlight;

      if (stream) {
        prepareVideoPreview(video);
        video.srcObject = stream;
        await waitForVideoReady(video);
        return ensureVideoPlayback({ allowGestureFallback: false });
      }

      if (!cameraSupported()) {
        launchCameraAppFallback({
          message: "Camera-based plate capture is not available in this browser. Use Camera App or type the vehicle number manually."
        });
        return;
      }

      cameraStartInFlight = (async () => {
        setStatus("Starting the rear camera…", "neutral");

        try {
          stopStream();
          prepareVideoPreview(video);
          stream = await navigator.mediaDevices.getUserMedia({
            audio: false,
            video: {
              facingMode: { ideal: "environment" },
              width: { ideal: 1920 },
              height: { ideal: 1080 }
            }
          });

          video.srcObject = stream;
          await waitForVideoReady(video);
          await ensureVideoPlayback();
        } catch (error) {
          launchCameraAppFallback({
            message: humanizeCameraError(error)
          });
        } finally {
          cameraStartInFlight = null;
        }
      })();

      return cameraStartInFlight;
    };

    const drawCapturedCanvas = (sourceCanvas) => {
      const context = canvas.getContext("2d");
      canvas.width = sourceCanvas.width;
      canvas.height = sourceCanvas.height;
      canvas.hidden = false;
      video.hidden = true;
      guide.hidden = true;
      context.drawImage(sourceCanvas, 0, 0);
    };

    const showCapturedPreview = (sourceCanvas, message) => {
      capturedCanvas = sourceCanvas;
      drawCapturedCanvas(sourceCanvas);
      stopStream();
      captureButton.hidden = true;
      retakeButton.hidden = false;
      useButton.hidden = false;
      startButton.hidden = true;
      setStatus(message, "neutral");
    };

    const captureFrame = () => {
      if (!video.videoWidth || !video.videoHeight) {
        setStatus("Camera preview is still warming up. Please try again.", "warning");
        return;
      }

      const frameCanvas = createPreviewCanvas(video.videoWidth, video.videoHeight);
      frameCanvas.getContext("2d").drawImage(video, 0, 0, frameCanvas.width, frameCanvas.height);
      showCapturedPreview(frameCanvas, "Review the photo, then use it for OCR or retake if the plate is not clear.");
    };

    const fillInput = (value) => {
      input.value = value;
      input.dispatchEvent(new Event("input", { bubbles: true }));
      input.dispatchEvent(new Event("change", { bubbles: true }));
      input.focus({ preventScroll: true });
      const cursorPosition = input.value.length;
      if (typeof input.setSelectionRange === "function") {
        input.setSelectionRange(cursorPosition, cursorPosition);
      }
    };

    const renderResult = ({ cleaned, raw, confidence, valid, corrected }) => {
      const confidenceRounded = Number.isFinite(confidence) ? Math.round(confidence) : 0;
      const lowConfidence = confidenceRounded > 0 && confidenceRounded < 70;
      const warning = !valid || lowConfidence;

      result.classList.remove("d-none");
      result.classList.toggle("is-warning", warning);
      result.classList.toggle("is-success", !warning);
      cleanedTarget.textContent = cleaned || "No plate detected";
      confidenceTarget.textContent = confidenceRounded > 0 ? `${confidenceRounded}% confidence` : "Needs review";

      if (!cleaned) {
        noteTarget.textContent = "No clear number plate text was detected. Please retake the photo or type the vehicle number manually.";
      } else if (!valid) {
        noteTarget.textContent = "The detected text does not match a typical Indian registration format. Please verify it before saving.";
      } else if (lowConfidence) {
        noteTarget.textContent = "The number was detected with low confidence. Please verify it before saving.";
      } else if (corrected) {
        noteTarget.textContent = "A few OCR characters were safely normalized to fit an Indian registration format. Please review the result.";
      } else {
        noteTarget.textContent = "Looks like a valid Indian vehicle number. You can still edit it before saving.";
      }

      rawTarget.textContent = raw ? `Raw OCR: ${raw}` : "Raw OCR: unavailable";
    };

    const toggleBusy = (busy) => {
      openButton.disabled = busy;
      startButton.disabled = busy;
      fileTriggerButton.disabled = busy;
      captureButton.disabled = busy || !stream;
      retakeButton.disabled = busy;
      useButton.disabled = busy;
      closeButton.disabled = busy;
    };

    const useCapturedPhoto = async () => {
      if (!capturedCanvas) return;

      toggleBusy(true);
      setStatus("Reading the number plate…", "neutral");

      try {
        const tesseract = await loadTesseract();
        const processedCanvas = preprocessPlateCanvas(capturedCanvas);
        const ocrResult = await tesseract.recognize(processedCanvas, "eng");
        const rawText = (ocrResult?.data?.text || "").trim();
        const normalized = normalizeDetectedPlate(rawText);
        const cleaned = normalized.cleaned || normalized.raw;
        const confidence = averageConfidence(ocrResult?.data || {});

        if (!cleaned) {
          renderResult({ cleaned: "", raw: normalizePlateText(rawText), confidence, valid: false, corrected: false });
          setStatus("The photo was unclear. Please retake the image or type the number manually.", "warning");
          return;
        }

        fillInput(cleaned);
        renderResult({
          cleaned,
          raw: normalizePlateText(rawText),
          confidence,
          valid: normalized.valid,
          corrected: normalized.corrected
        });
        setStatus(
          normalized.valid && confidence >= 70
            ? "Vehicle number added to the field. Review it and continue."
            : "OCR completed. Please verify the detected number before saving.",
          normalized.valid && confidence >= 70 ? "success" : "warning"
        );
      } catch (_error) {
        setStatus("OCR failed on this image. Please retake the photo or type the vehicle number manually.", "warning");
      } finally {
        toggleBusy(false);
      }
    };

    openButton.addEventListener("click", () => {
      setPanelOpen(true);
      startCamera();
    });

    startButton.addEventListener("click", () => {
      startCamera();
    });

    fileTriggerButton.addEventListener("click", () => {
      stopStream();
      fileInput.click();
    });

    captureButton.addEventListener("click", () => {
      captureFrame();
    });

    retakeButton.addEventListener("click", () => {
      setPanelOpen(true);
      startCamera();
    });

    useButton.addEventListener("click", () => {
      useCapturedPhoto();
    });

    fileInput.addEventListener("change", async () => {
      const file = fileInput.files?.[0];
      if (!file) return;

      toggleBusy(true);
      setPanelOpen(true);
      setStatus("Preparing the selected photo…", "neutral");

      try {
        const imageCanvas = await loadImageFileToCanvas(file);
        showCapturedPreview(imageCanvas, "Review the photo, then use it for OCR or choose another photo if needed.");
      } catch (_error) {
        setStatus("The selected photo could not be opened. Please try again or type the vehicle number manually.", "warning");
      } finally {
        fileInput.value = "";
        toggleBusy(false);
      }
    });

    closeButton.addEventListener("click", () => {
      setPanelOpen(false);
      setStatus("Scanner closed. You can still type the vehicle number manually.", "neutral");
    });

    document.addEventListener("turbo:before-cache", stopStream);
    window.addEventListener("pagehide", stopStream);

    const autoOpenScanner = () => {
      if (autoOpenScheduled) return;
      autoOpenScheduled = true;
      setPanelOpen(true);
      window.setTimeout(() => {
        startCamera();
      }, 220);
    };

    if (root.dataset.autoOpen === "true") {
      if (document.readyState === "complete") {
        autoOpenScanner();
      } else {
        window.addEventListener("load", autoOpenScanner, { once: true });
        window.addEventListener("pageshow", autoOpenScanner, { once: true });
      }
    }
  };

  const initializePlateScanners = () => {
    document.querySelectorAll("[data-plate-scanner-root]").forEach(initPlateScanner);
  };

  document.addEventListener("turbo:load", initializePlateScanners);
  document.addEventListener("DOMContentLoaded", initializePlateScanners);
  initializePlateScanners();
})();
