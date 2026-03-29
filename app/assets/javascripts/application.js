(() => {
  const ANALYTICS_ENDPOINT = "/analytics/events";
  const THEME_STORAGE_KEY = "fuel-loyalty-theme";
  const MOBILE_SIDEBAR_RAIL_STORAGE_KEY = "fuel-loyalty-mobile-sidebar-rail";
  const MOBILE_SIDEBAR_RAIL_DOCUMENT_CLASS = "mobile-sidebar-rail-enabled";
  const PUSH_TOKEN_STORAGE_KEY = "fuel-loyalty-fcm-token";
  const PUSH_OPT_OUT_STORAGE_KEY = "fuel-loyalty-push-opt-out";
  const PWA_INSTALL_EVENT_NAMES = new Set([
    "pwa_install_cta_viewed",
    "pwa_install_prompt_available",
    "pwa_install_cta_clicked",
    "pwa_install_manual_instructions_shown",
    "pwa_install_prompt_shown",
    "pwa_install_prompt_accepted",
    "pwa_install_prompt_dismissed",
    "pwa_install_completed",
    "pwa_install_prompt_error"
  ]);

  const installPromptState = {
    deferredPrompt: null
  };

  const pushOptInState = {
    syncing: null
  };

  const currentPagePath = () => window.location.pathname;
  const mobileSidebarRailEnabled = () => localStorage.getItem(MOBILE_SIDEBAR_RAIL_STORAGE_KEY) === "true";
  const syncSidebarRailDocumentClass = (enabled = mobileSidebarRailEnabled()) => {
    document.documentElement.classList.toggle(MOBILE_SIDEBAR_RAIL_DOCUMENT_CLASS, enabled);
  };
  const persistMobileSidebarRailEnabled = (enabled) => {
    if (enabled) {
      localStorage.setItem(MOBILE_SIDEBAR_RAIL_STORAGE_KEY, "true");
      syncSidebarRailDocumentClass(true);
      return;
    }

    localStorage.removeItem(MOBILE_SIDEBAR_RAIL_STORAGE_KEY);
    syncSidebarRailDocumentClass(false);
  };
  const desktopSidebarEnabled = () => window.innerWidth >= 992;
  const applySidebarShellState = (scope = document, { railEnabled = mobileSidebarRailEnabled() } = {}) => {
    const sidebar = scope.querySelector?.("#sidebar");
    const content = scope.querySelector?.("#content");
    const topbar = scope.querySelector?.("#topbar");
    const overlay = scope.querySelector?.("#overlay");
    if (!sidebar || !content || !topbar) return;

    const shouldShowRail = !desktopSidebarEnabled() && railEnabled;
    sidebar.classList.toggle("mobile-rail", shouldShowRail);
    sidebar.classList.toggle("mobile-show", shouldShowRail);
    sidebar.classList.toggle("collapsed", shouldShowRail);
    content.classList.remove("full");
    topbar.classList.remove("full");
    content.classList.toggle("mobile-rail", shouldShowRail);
    topbar.classList.toggle("mobile-rail", shouldShowRail);

    if (shouldShowRail) {
      overlay?.classList.remove("show");
    }

    scope.querySelectorAll?.("[data-sidebar-mode-switch]").forEach((input) => {
      input.checked = railEnabled;
    });
  };

  const isStandaloneMode = () => window.matchMedia("(display-mode: standalone)").matches || window.navigator.standalone === true;

  syncSidebarRailDocumentClass();

  const installInstructionsForDevice = () => {
    const userAgent = window.navigator.userAgent.toLowerCase();

    if (/iphone|ipad|ipod/.test(userAgent)) {
      return "Open Safari's Share menu, then tap Add to Home Screen.";
    }

    if (/android/.test(userAgent)) {
      return "Open your browser menu, then choose Install app or Add to Home Screen.";
    }

    return "Use the install option in your browser menu or address bar to add Ace Fuel Loyalty.";
  };

  const dispatchAnalyticsIntegrations = (name, properties) => {
    if (typeof window.gtag === "function") {
      window.gtag("event", name, properties);
    }

    if (Array.isArray(window.dataLayer)) {
      window.dataLayer.push({ event: name, ...properties });
    }

    if (typeof window.plausible === "function") {
      window.plausible(name, { props: properties });
    }
  };

  const trackAnalyticsEvent = (name, properties = {}) => {
    if (!PWA_INSTALL_EVENT_NAMES.has(name)) return;

    const payload = {
      name,
      page_path: currentPagePath(),
      properties: {
        ...properties,
        standalone: isStandaloneMode()
      }
    };

    dispatchAnalyticsIntegrations(name, payload.properties);

    fetch(ANALYTICS_ENDPOINT, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || ""
      },
      credentials: "same-origin",
      keepalive: true,
      body: JSON.stringify(payload)
    }).catch(() => {});
  };

  const registerServiceWorker = () => {
    if (!("serviceWorker" in navigator)) return Promise.resolve(null);
    if (window.__fuelLoyaltyServiceWorkerRegistrationPromise) {
      return window.__fuelLoyaltyServiceWorkerRegistrationPromise;
    }

    window.__fuelLoyaltyServiceWorkerRegistrationPromise = (async () => {
      try {
        const registration = await navigator.serviceWorker.register("/service-worker.js", { scope: "/" });

        const notifyUpdate = () => {
          window.dispatchEvent(new CustomEvent("pwa:update-available", { detail: { registration } }));
        };

        if (registration.waiting && navigator.serviceWorker.controller) {
          notifyUpdate();
        }

        registration.addEventListener("updatefound", () => {
          const candidate = registration.installing;
          if (!candidate) return;

          candidate.addEventListener("statechange", () => {
            if (candidate.state === "installed" && navigator.serviceWorker.controller) {
              notifyUpdate();
            }
          });
        });

        return registration;
      } catch (error) {
        console.error("Service worker registration failed", error);
        return null;
      }
    })();

    return window.__fuelLoyaltyServiceWorkerRegistrationPromise;
  };

  const pushSettings = () => window.fuelLoyaltyPushSettings || null;

  const firebaseSdkReady = async () => {
    const readyPromise = window.__fuelLoyaltyFirebaseReady;

    if (readyPromise && typeof readyPromise.then === "function") {
      try {
        return await Promise.race([
          readyPromise,
          new Promise((resolve) => setTimeout(() => resolve(window.fuelLoyaltyFirebase || null), 1500))
        ]);
      } catch (_error) {
        return window.fuelLoyaltyFirebase || null;
      }
    }

    return window.fuelLoyaltyFirebase || null;
  };

  const pushNotificationsSupported = () => {
    const settings = pushSettings();

    return Boolean(settings?.firebaseConfig)
      && Boolean(settings?.vapidKey)
      && "Notification" in window
      && "serviceWorker" in navigator;
  };

  const initializeFirebaseMessaging = async () => {
    if (!pushNotificationsSupported()) return null;

    const firebaseSdk = await firebaseSdkReady();
    if (!firebaseSdk || typeof firebaseSdk.getToken !== "function") return null;

    return firebaseSdk;
  };

  const detectPushPlatform = () => {
    const userAgent = window.navigator.userAgent.toLowerCase();

    if (/android/.test(userAgent)) return "android";
    if (/iphone|ipad|ipod/.test(userAgent)) return "ios";
    if (/macintosh|windows|linux/.test(userAgent)) return "desktop";

    return "web";
  };

  const pushPermissionState = () => {
    if (!("Notification" in window)) return "unsupported";

    return window.Notification.permission;
  };

  const pushOptOutEnabled = () => localStorage.getItem(PUSH_OPT_OUT_STORAGE_KEY) === "true";

  const setPushOptOutEnabled = (value) => {
    if (value) {
      localStorage.setItem(PUSH_OPT_OUT_STORAGE_KEY, "true");
      return;
    }

    localStorage.removeItem(PUSH_OPT_OUT_STORAGE_KEY);
  };

  const deactivatePushSubscriptionToken = async (token, { clearStoredToken = false } = {}) => {
    const settings = pushSettings();
    if (!settings?.subscriptionEndpoint || !token) return;

    try {
      await fetch(settings.subscriptionEndpoint, {
        method: "DELETE",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || ""
        },
        credentials: "same-origin",
        body: JSON.stringify({ token })
      });
    } catch (_error) {
      // Best effort cleanup only.
    } finally {
      if (clearStoredToken && localStorage.getItem(PUSH_TOKEN_STORAGE_KEY) === token) {
        localStorage.removeItem(PUSH_TOKEN_STORAGE_KEY);
      }
    }
  };

  const savePushSubscription = async (token) => {
    const settings = pushSettings();
    if (!settings?.subscriptionEndpoint) throw new Error("Push subscription endpoint is not configured.");

    const previousToken = localStorage.getItem(PUSH_TOKEN_STORAGE_KEY);
    const response = await fetch(settings.subscriptionEndpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || ""
      },
      credentials: "same-origin",
      body: JSON.stringify({
        token,
        platform: detectPushPlatform()
      })
    });

    if (!response.ok) {
      throw new Error(`Failed to register notifications (${response.status})`);
    }

    localStorage.setItem(PUSH_TOKEN_STORAGE_KEY, token);
    if (previousToken && previousToken !== token) {
      await deactivatePushSubscriptionToken(previousToken);
    }
  };

  const deactivateStoredPushSubscription = async () => {
    const storedToken = localStorage.getItem(PUSH_TOKEN_STORAGE_KEY);
    if (!storedToken) return;

    await deactivatePushSubscriptionToken(storedToken, { clearStoredToken: true });
  };

  const disablePushNotificationsInApp = async () => {
    setPushOptOutEnabled(true);
    await deactivateStoredPushSubscription();
    return { ok: true };
  };

  const syncPushSubscription = async ({ requestPermission = false } = {}) => {
    if (!pushNotificationsSupported()) {
      return { ok: false, reason: "unsupported" };
    }

    if (pushOptOutEnabled() && !requestPermission) {
      return { ok: false, reason: "disabled_in_app" };
    }

    if (pushOptInState.syncing) return pushOptInState.syncing;

    pushOptInState.syncing = (async () => {
      if (requestPermission && pushPermissionState() === "default") {
        const permission = await Notification.requestPermission();
        if (permission !== "granted") {
          if (permission === "denied") await deactivateStoredPushSubscription();
          return { ok: false, permission };
        }
      }

      if (pushPermissionState() !== "granted") {
        if (pushPermissionState() === "denied") {
          await deactivateStoredPushSubscription();
        }

        return { ok: false, permission: pushPermissionState() };
      }

      const registration = await registerServiceWorker();
      if (!registration) {
        return { ok: false, reason: "service_worker_registration_failed" };
      }

      const firebaseSdk = await initializeFirebaseMessaging();
      if (!firebaseSdk) {
        return { ok: false, reason: "messaging_unavailable" };
      }

      const token = await firebaseSdk.getToken({
        vapidKey: pushSettings().vapidKey,
        serviceWorkerRegistration: registration
      });

      if (!token) {
        return { ok: false, reason: "token_unavailable" };
      }

      await savePushSubscription(token);
      setPushOptOutEnabled(false);
      return { ok: true, token };
    })();

    try {
      return await pushOptInState.syncing;
    } finally {
      pushOptInState.syncing = null;
    }
  };

  const setPushPanelState = (panel, state = {}) => {
    const button = panel.querySelector("[data-push-button]");
    const disableButton = panel.querySelector("[data-push-disable-button]");
    const status = panel.querySelector("[data-push-status]");
    const help = panel.querySelector("[data-push-help]");
    if (!button || !disableButton || !status || !help) return;

    if (!pushNotificationsSupported()) {
      panel.classList.add("d-none");
      return;
    }

    panel.classList.remove("d-none");
    button.disabled = state.busy === true;
    disableButton.disabled = state.busy === true;

    if (pushPermissionState() === "granted" && pushOptOutEnabled()) {
      disableButton.classList.add("d-none");
      button.classList.remove("btn-primary", "btn-outline-secondary");
      button.classList.add("btn-outline-primary");
      button.querySelector("span").textContent = "Enable Notifications";
      status.textContent = state.message || "Notifications are turned off for this device in the app.";
      help.textContent = state.helpText || "Tap Enable Notifications to subscribe this device again.";
      help.classList.remove("d-none");
      return;
    }

    if (pushPermissionState() === "granted") {
      disableButton.classList.remove("d-none");
      button.classList.remove("btn-outline-primary");
      button.classList.add("btn-primary");
      button.querySelector("span").textContent = "Notifications Enabled";
      status.textContent = state.message || "Push notifications are enabled on this device.";
      help.classList.add("d-none");
      help.textContent = "";
      return;
    }

    if (pushPermissionState() === "denied") {
      disableButton.classList.add("d-none");
      button.classList.remove("btn-primary");
      button.classList.add("btn-outline-secondary");
      button.querySelector("span").textContent = "Notifications Off";
      status.textContent = "Notifications are currently turned off for this browser profile.";
      help.textContent = "Turn notifications on in your browser or device settings, then reload this page.";
      help.classList.remove("d-none");
      return;
    }

    disableButton.classList.add("d-none");
    button.classList.remove("btn-primary", "btn-outline-secondary");
    button.classList.add("btn-outline-primary");
    button.querySelector("span").textContent = "Enable Notifications";
    status.textContent = state.message || status.dataset.defaultMessage || status.textContent;

    if (state.helpText) {
      help.textContent = state.helpText;
      help.classList.remove("d-none");
      return;
    }

    help.classList.add("d-none");
    help.textContent = "";
  };

  const refreshPushPanels = (state = {}) => {
    document.querySelectorAll("[data-push-opt-in-panel]").forEach((panel) => {
      const status = panel.querySelector("[data-push-status]");
      if (status && !status.dataset.defaultMessage) {
        status.dataset.defaultMessage = status.textContent;
      }

      setPushPanelState(panel, state);
    });
  };

  const initializePushOptIn = () => {
    const panels = document.querySelectorAll("[data-push-opt-in-panel]");
    if (panels.length === 0) return;

    panels.forEach((panel) => {
      const button = panel.querySelector("[data-push-button]");
      const disableButton = panel.querySelector("[data-push-disable-button]");
      if (!button || !disableButton) return;

      if (panel.dataset.pushBound === "true") {
        setPushPanelState(panel);
        return;
      }

      panel.dataset.pushBound = "true";

      button.addEventListener("click", async () => {
        setPushPanelState(panel, { busy: true });

        try {
          const result = await syncPushSubscription({ requestPermission: true });

          if (!result.ok && result.permission === "denied") {
            refreshPushPanels();
            return;
          }

          if (!result.ok && result.permission === "default") {
            refreshPushPanels({
              message: "Notifications are not enabled on this device yet.",
              helpText: "Tap Enable Notifications whenever you're ready to allow alerts."
            });
            return;
          }

          if (!result.ok) {
            refreshPushPanels({
              helpText: "We could not complete push registration on this device. Please try again."
            });
            return;
          }

          refreshPushPanels({
            message: "Push notifications are enabled on this device."
          });
        } catch (_error) {
          refreshPushPanels({
            helpText: "We could not complete push registration on this device. Please try again."
          });
        } finally {
          setPushPanelState(panel, { busy: false });
        }
      });

      disableButton.addEventListener("click", async () => {
        setPushPanelState(panel, { busy: true });

        try {
          await disablePushNotificationsInApp();
          refreshPushPanels({
            message: "Notifications are turned off for this device in the app.",
            helpText: "Tap Enable Notifications to subscribe this device again."
          });
        } catch (_error) {
          refreshPushPanels({
            helpText: "We could not turn off notifications on this device right now. Please try again."
          });
        } finally {
          setPushPanelState(panel, { busy: false });
        }
      });

      setPushPanelState(panel);
    });

    if (pushPermissionState() === "granted") {
      if (pushOptOutEnabled()) {
        refreshPushPanels({
          message: "Notifications are turned off for this device in the app.",
          helpText: "Tap Enable Notifications to subscribe this device again."
        });
      } else {
        syncPushSubscription().then((result) => {
          if (result.ok) {
            refreshPushPanels({
              message: "Push notifications are enabled on this device."
            });
          }
        }).catch(() => {});
      }
    } else if (pushPermissionState() === "denied") {
      deactivateStoredPushSubscription().catch(() => {});
    }
  };

  const syncNotificationScheduleFormVisibility = (form) => {
    const frequencyInput = form.querySelector("[data-schedule-frequency]");
    if (!frequencyInput) return;

    const frequency = frequencyInput.value;

    form.querySelectorAll("[data-schedule-field]").forEach((field) => {
      const shouldShow = field.dataset.scheduleField === frequency;
      field.classList.toggle("d-none", !shouldShow);
      field.querySelectorAll("input, select").forEach((input) => {
        input.disabled = !shouldShow;
      });
    });
  };

  const initializeNotificationScheduleForms = () => {
    document.querySelectorAll("[data-notification-schedule-form]").forEach((form) => {
      if (form.dataset.scheduleFormBound === "true") {
        syncNotificationScheduleFormVisibility(form);
        return;
      }

      form.dataset.scheduleFormBound = "true";
      const frequencyInput = form.querySelector("[data-schedule-frequency]");
      if (!frequencyInput) return;

      frequencyInput.addEventListener("change", () => {
        syncNotificationScheduleFormVisibility(form);
      });

      syncNotificationScheduleFormVisibility(form);
    });
  };

  const parseDateTimeLocal = (value) => {
    if (!value) return null;

    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? null : date;
  };

  const formatDateTimeLocal = (date) => {
    if (!(date instanceof Date) || Number.isNaN(date.getTime())) return "";

    const pad = (value) => value.toString().padStart(2, "0");
    return [
      date.getFullYear(),
      pad(date.getMonth() + 1),
      pad(date.getDate())
    ].join("-") + `T${pad(date.getHours())}:${pad(date.getMinutes())}`;
  };

  const syncAttendancePlannerStart = (form, { force = false } = {}) => {
    const shiftInput = form.querySelector("[data-attendance-shift-input]");
    const startInput = form.querySelector("[data-attendance-start-input]");
    if (!shiftInput || !startInput) return;

    const selectedOption = shiftInput.options[shiftInput.selectedIndex];
    const startTime = selectedOption?.dataset?.startTime || "";
    if (!startTime) return;
    if (!force && startInput.value) return;

    const existingStart = parseDateTimeLocal(startInput.value);
    const nextStart = existingStart || new Date();
    const [hours, minutes] = startTime.split(":").map((value) => Number.parseInt(value, 10));
    if (!Number.isFinite(hours) || !Number.isFinite(minutes)) return;

    nextStart.setSeconds(0, 0);
    nextStart.setHours(hours, minutes, 0, 0);
    startInput.value = formatDateTimeLocal(nextStart);
  };

  const syncAttendancePlannerEnd = (form) => {
    const shiftInput = form.querySelector("[data-attendance-shift-input]");
    const startInput = form.querySelector("[data-attendance-start-input]");
    const endInput = form.querySelector("[data-attendance-end-input]");
    if (!shiftInput || !startInput || !endInput) return;

    const selectedOption = shiftInput.options[shiftInput.selectedIndex];
    const durationMinutes = Number.parseInt(selectedOption?.dataset?.durationMinutes || "", 10);
    const startDate = parseDateTimeLocal(startInput.value);

    if (!startDate || !Number.isFinite(durationMinutes)) {
      endInput.value = "";
      return;
    }

    endInput.value = formatDateTimeLocal(new Date(startDate.getTime() + (durationMinutes * 60 * 1000)));
  };

  const syncAttendanceReplacementVisibility = (row) => {
    const statusInput = row.querySelector("[data-attendance-status-select]");
    if (!statusInput) return;

    const absent = statusInput.value === "absent";
    row.querySelectorAll("[data-attendance-replacement-fields]").forEach((field) => {
      field.classList.toggle("d-none", !absent);
    });
  };

  const markAttendanceRowPresent = (row) => {
    const statusInput = row.querySelector("[data-attendance-status-select]");
    const actualUserInput = row.querySelector("select[name*='[actual_user_id]']");
    const replacementInput = row.querySelector("[data-attendance-replacement-select]");
    const externalReplacementInput = row.querySelector("input[name*='[external_replacement_name]']");
    const scheduledUserId = row.dataset.scheduledUserId;

    if (statusInput) statusInput.value = "present";
    if (actualUserInput && scheduledUserId) actualUserInput.value = scheduledUserId;
    if (replacementInput) replacementInput.value = "";
    if (externalReplacementInput) externalReplacementInput.value = "";
    syncAttendanceReplacementVisibility(row);
  };

  const initializeAttendancePlanner = () => {
    document.querySelectorAll("[data-attendance-planner-form]").forEach((form) => {
      if (form.dataset.bound === "true") {
        syncAttendancePlannerStart(form);
        syncAttendancePlannerEnd(form);
        return;
      }

      form.dataset.bound = "true";
      const shiftInput = form.querySelector("[data-attendance-shift-input]");
      const startInput = form.querySelector("[data-attendance-start-input]");

      const syncAndMaybeSubmit = () => {
        syncAttendancePlannerEnd(form);
        if (shiftInput?.value && startInput?.value) {
          form.requestSubmit();
        }
      };

      shiftInput?.addEventListener("change", () => {
        syncAttendancePlannerStart(form, { force: true });
        syncAndMaybeSubmit();
      });
      startInput?.addEventListener("change", syncAndMaybeSubmit);

      syncAttendancePlannerStart(form);
      syncAttendancePlannerEnd(form);
    });

    document.querySelectorAll("[data-attendance-entry-row]").forEach((row) => {
      if (row.dataset.bound === "true") {
        syncAttendanceReplacementVisibility(row);
        return;
      }

      row.dataset.bound = "true";
      const statusInput = row.querySelector("[data-attendance-status-select]");
      const replacementInput = row.querySelector("[data-attendance-replacement-select]");
      const actualUserInput = row.querySelector("select[name*='[actual_user_id]']");

      statusInput?.addEventListener("change", () => {
        syncAttendanceReplacementVisibility(row);
      });

      replacementInput?.addEventListener("change", () => {
        if (actualUserInput && replacementInput.value) {
          actualUserInput.value = replacementInput.value;
        }
      });

      syncAttendanceReplacementVisibility(row);
    });

    document.querySelectorAll("[data-attendance-mark-all-present]").forEach((button) => {
      if (button.dataset.bound === "true") return;

      button.dataset.bound = "true";
      button.addEventListener("click", () => {
        document.querySelectorAll("[data-attendance-entry-row]").forEach((row) => {
          markAttendanceRowPresent(row);
        });
      });
    });
  };

  const syncShiftAssignmentTime = (container, { force = false } = {}) => {
    const shiftInput = container.querySelector("[data-shift-assignment-template-input]");
    const timeInput = container.querySelector("[data-shift-assignment-effective-time]");
    if (!shiftInput || !timeInput) return;

    let startTimes = {};
    try {
      startTimes = JSON.parse(shiftInput.dataset.shiftAssignmentStartTimes || "{}");
    } catch (_error) {
      startTimes = {};
    }

    const startTime = startTimes[shiftInput.value] || "";

    if (!startTime) return;
    if (!force && timeInput.value) return;

    timeInput.value = startTime;
    timeInput.setAttribute("value", startTime);
  };

  const initializeShiftAssignmentForms = () => {
    document.querySelectorAll("[data-shift-assignment-form]").forEach((container) => {
      if (container.dataset.bound === "true") {
        syncShiftAssignmentTime(container);
        return;
      }

      container.dataset.bound = "true";
      const shiftInput = container.querySelector("[data-shift-assignment-template-input]");

      shiftInput?.addEventListener("change", () => {
        syncShiftAssignmentTime(container, { force: true });
      });

      syncShiftAssignmentTime(container);
    });
  };

  const syncShiftCycleAddButtons = (form) => {
    const addButton = form.querySelector("[data-shift-cycle-add-step]");
    if (!addButton) return;

    const hiddenField = form.querySelector("[data-shift-cycle-step-field].d-none");
    addButton.classList.toggle("d-none", !hiddenField);
  };

  const initializeShiftCycleForms = () => {
    document.querySelectorAll("[data-shift-cycle-form]").forEach((form) => {
      if (form.dataset.shiftCycleBound === "true") {
        syncShiftCycleAddButtons(form);
        return;
      }

      form.dataset.shiftCycleBound = "true";
      const addButton = form.querySelector("[data-shift-cycle-add-step]");

      addButton?.addEventListener("click", () => {
        const nextHiddenField = form.querySelector("[data-shift-cycle-step-field].d-none");
        if (!nextHiddenField) {
          syncShiftCycleAddButtons(form);
          return;
        }

        nextHiddenField.classList.remove("d-none");
        nextHiddenField.querySelector("select")?.focus();
        syncShiftCycleAddButtons(form);
      });

      syncShiftCycleAddButtons(form);
    });
  };

  const preferredTheme = () => {
    if (document.documentElement.dataset.theme) return document.documentElement.dataset.theme;

    return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
  };

  const applyTheme = (theme) => {
    document.documentElement.dataset.theme = theme;
    document.documentElement.style.colorScheme = theme;

    document.querySelectorAll("[data-theme-switch]").forEach((input) => {
      input.checked = theme === "dark";
    });

    document.querySelectorAll("[data-theme-label]").forEach((label) => {
      label.textContent = theme === "dark" ? "Dark" : "Light";
    });
  };

  const initializeTheme = () => {
    applyTheme(preferredTheme());

    document.querySelectorAll("[data-theme-switch]").forEach((input) => {
      if (input.dataset.bound === "true") return;

      input.dataset.bound = "true";
      input.addEventListener("change", (event) => {
        const nextTheme = event.target.checked ? "dark" : "light";

        localStorage.setItem(THEME_STORAGE_KEY, nextTheme);
        applyTheme(nextTheme);
      });
    });
  };

  const initializeSidebar = () => {
    const sidebar = document.getElementById("sidebar");
    const content = document.getElementById("content");
    const topbar = document.getElementById("topbar");
    const sidebarModeSwitch = document.querySelector("[data-sidebar-mode-switch]");
    const mobileBtn = document.getElementById("mobileBtn");
    const overlay = document.getElementById("overlay");
    const closeMobileSidebar = () => {
      sidebar.classList.remove("mobile-show");
      overlay?.classList.remove("show");
    };

    if (!sidebar || !content || !topbar) return;
    if (sidebar.__bound === true) return;

    sidebar.__bound = true;

    applySidebarShellState();

    sidebarModeSwitch?.addEventListener("change", (event) => {
      const enabled = event.target.checked;
      persistMobileSidebarRailEnabled(enabled);
      applySidebarShellState(document, { railEnabled: enabled });
    });

    mobileBtn?.addEventListener("click", () => {
      if (mobileSidebarRailEnabled()) return;

      sidebar.classList.add("mobile-show");
      overlay?.classList.add("show");
    });

    overlay?.addEventListener("click", () => {
      closeMobileSidebar();
    });

    sidebar.querySelectorAll("a").forEach((link) => {
      link.addEventListener("click", () => {
        if (window.innerWidth < 992 && !mobileSidebarRailEnabled()) closeMobileSidebar();
      });
    });

    document.addEventListener("keydown", (event) => {
      if (event.key === "Escape") closeMobileSidebar();
    });

    window.addEventListener("resize", () => {
      if (window.innerWidth >= 992) closeMobileSidebar();
      applySidebarShellState();
    });
  };

  const initializeConfirmModal = () => {
    const modalElement = document.getElementById("confirmDeleteModal");
    const messageTarget = modalElement?.querySelector("[data-confirm-modal-message]");
    const confirmButton = modalElement?.querySelector("[data-confirm-modal-submit]");

    if (!modalElement || !messageTarget || !confirmButton || modalElement.dataset.bound === "true") return;

    modalElement.dataset.bound = "true";

    let pendingForm = null;
    let pendingSubmitter = null;
    const modal = new bootstrap.Modal(modalElement);

    document.addEventListener("submit", (event) => {
      const form = event.target;
      if (!(form instanceof HTMLFormElement)) return;
      if (form.dataset.confirmModal !== "true") return;
      if (form.dataset.confirmed === "true") {
        delete form.dataset.confirmed;
        return;
      }

      event.preventDefault();
      pendingForm = form;
      pendingSubmitter = event.submitter || form.querySelector("[type='submit']");
      messageTarget.textContent = form.dataset.confirmMessage || "Are you sure you want to delete this item?";
      modal.show();
    });

    confirmButton.addEventListener("click", () => {
      if (!pendingForm) return;

      pendingForm.dataset.confirmed = "true";
      modal.hide();
      pendingForm.requestSubmit(pendingSubmitter);
    });

    modalElement.addEventListener("hidden.bs.modal", () => {
      pendingForm = null;
      pendingSubmitter = null;
    });
  };

  const initializeAutoOpenModals = () => {
    document.querySelectorAll("[data-auto-open-modal='true']").forEach((modalElement) => {
      if (modalElement.dataset.autoOpenModalHandled === "true") return;

      modalElement.dataset.autoOpenModalHandled = "true";
      bootstrap.Modal.getOrCreateInstance(modalElement).show();
    });

    document.querySelectorAll("[data-reset-on-close='reload']").forEach((modalElement) => {
      if (modalElement.dataset.resetOnCloseHandled === "true") return;

      modalElement.dataset.resetOnCloseHandled = "true";
      modalElement.addEventListener("hidden.bs.modal", () => {
        if (modalElement.dataset.autoOpenModal !== "true") return;

        const resetUrl = modalElement.dataset.resetOnCloseUrl || `${window.location.pathname}${window.location.search}`;
        window.location.replace(resetUrl);
      });
    });
  };

  const initializeLazyPointsLedger = () => {
    const renderLedgerErrorState = (panel) => {
      panel.innerHTML = `
        <div class="customer-details-ledger-state is-error">
          <span>Couldn't load the points ledger right now.</span>
          <button type="button" class="btn btn-outline-secondary btn-sm" data-points-ledger-retry>Try again</button>
        </div>
      `;
    };

    const loadLedgerPage = async (panel, url) => {
      if (!panel || !url || panel.dataset.pointsLedgerLoading === "true") return;

      panel.dataset.pointsLedgerLoading = "true";

      if (panel.dataset.pointsLedgerLoaded !== "true") {
        panel.innerHTML = `
          <div class="customer-details-ledger-state is-loading" data-points-ledger-status>
            <span class="spinner-border spinner-border-sm" aria-hidden="true"></span>
            <span>Loading points ledger...</span>
          </div>
        `;
      }

      try {
        const response = await fetch(url, {
          method: "GET",
          headers: {
            "Accept": "text/html",
            "X-Requested-With": "XMLHttpRequest"
          },
          credentials: "same-origin"
        });

        if (!response.ok) throw new Error(`Failed with status ${response.status}`);

        panel.innerHTML = await response.text();
        panel.dataset.pointsLedgerLoaded = "true";
        panel.dataset.pointsLedgerUrl = url;
      } catch (error) {
        renderLedgerErrorState(panel);
      } finally {
        panel.dataset.pointsLedgerLoading = "false";
      }
    };

    document.querySelectorAll("[data-points-ledger-panel]").forEach((panel) => {
      if (panel.dataset.pointsLedgerBound === "true") return;

      panel.dataset.pointsLedgerBound = "true";
      const modalElement = panel.closest(".modal");
      const initialUrl = panel.dataset.pointsLedgerUrl;
      if (!modalElement || !initialUrl) return;

      modalElement.addEventListener("shown.bs.modal", () => {
        loadLedgerPage(panel, panel.dataset.pointsLedgerUrl || initialUrl);
      });
    });

    if (window.__fuelLoyaltyPointsLedgerClickBound) return;

    window.__fuelLoyaltyPointsLedgerClickBound = true;

    document.addEventListener("click", (event) => {
      const trigger = event.target.closest("[data-points-ledger-page-link], [data-points-ledger-retry]");
      if (!trigger) return;

      const panel = trigger.closest("[data-points-ledger-panel]");
      if (!panel) return;

      event.preventDefault();

      if (trigger.hasAttribute("disabled")) return;

      const nextUrl = trigger.dataset.pointsLedgerPageLink || panel.dataset.pointsLedgerUrl;
      loadLedgerPage(panel, nextUrl);
    });
  };

  const initializeLazyTransactionHistory = () => {
    const renderTransactionHistoryErrorState = (panel) => {
      panel.innerHTML = `
        <div class="customer-details-ledger-state is-error">
          <span>Couldn't load more transactions right now.</span>
          <button type="button" class="btn btn-outline-secondary btn-sm" data-transaction-history-retry>Try again</button>
        </div>
      `;
    };

    const loadTransactionHistoryPage = async (panel, url) => {
      if (!panel || !url || panel.dataset.transactionHistoryLoading === "true") return;

      panel.dataset.transactionHistoryLoading = "true";

      if (panel.dataset.transactionHistoryLoaded !== "true") {
        panel.innerHTML = `
          <div class="customer-details-ledger-state is-loading" data-transaction-history-status>
            <span class="spinner-border spinner-border-sm" aria-hidden="true"></span>
            <span>Loading more transactions...</span>
          </div>
        `;
      }

      try {
        const response = await fetch(url, {
          method: "GET",
          headers: {
            "Accept": "text/html",
            "X-Requested-With": "XMLHttpRequest"
          },
          credentials: "same-origin"
        });

        if (!response.ok) throw new Error(`Failed with status ${response.status}`);

        panel.innerHTML = await response.text();
        panel.dataset.transactionHistoryLoaded = "true";
        panel.dataset.transactionHistoryUrl = url;
      } catch (error) {
        renderTransactionHistoryErrorState(panel);
      } finally {
        panel.dataset.transactionHistoryLoading = "false";
      }
    };

    document.querySelectorAll("[data-transaction-history-panel]").forEach((panel) => {
      if (panel.dataset.transactionHistoryBound === "true") return;

      panel.dataset.transactionHistoryBound = "true";
      const modalElement = panel.closest(".modal");
      const initialUrl = panel.dataset.transactionHistoryUrl;
      if (!modalElement || !initialUrl) return;

      modalElement.addEventListener("shown.bs.modal", () => {
        loadTransactionHistoryPage(panel, panel.dataset.transactionHistoryUrl || initialUrl);
      });
    });

    if (window.__fuelLoyaltyTransactionHistoryClickBound) return;

    window.__fuelLoyaltyTransactionHistoryClickBound = true;

    document.addEventListener("click", (event) => {
      const trigger = event.target.closest("[data-transaction-history-page-link], [data-transaction-history-retry]");
      if (!trigger) return;

      const panel = trigger.closest("[data-transaction-history-panel]");
      if (!panel) return;

      event.preventDefault();

      if (trigger.hasAttribute("disabled")) return;

      const nextUrl = trigger.dataset.transactionHistoryPageLink || panel.dataset.transactionHistoryUrl;
      loadTransactionHistoryPage(panel, nextUrl);
    });
  };

  const normalizePhoneNumberInput = (value) => value.replace(/\D/g, "").slice(0, 10);

  const syncPhoneNumberValidity = (input) => {
    if (input.value === "" || input.value.length === 10) {
      input.setCustomValidity("");
      return;
    }

    input.setCustomValidity("Enter a 10 digit phone number.");
  };

  const initializePhoneNumberFields = () => {
    document.querySelectorAll("[data-phone-number-field]").forEach((input) => {
      if (input.dataset.phoneNumberBound === "true") {
        syncPhoneNumberValidity(input);
        return;
      }

      input.dataset.phoneNumberBound = "true";
      input.value = normalizePhoneNumberInput(input.value);
      syncPhoneNumberValidity(input);

      input.addEventListener("input", () => {
        input.value = normalizePhoneNumberInput(input.value);
        syncPhoneNumberValidity(input);
      });

      input.addEventListener("blur", () => {
        syncPhoneNumberValidity(input);
      });

      input.addEventListener("invalid", () => {
        syncPhoneNumberValidity(input);
      });
    });
  };

  const initializeLoyaltyPointsHero = () => {
    const prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

    document.querySelectorAll("[data-loyalty-points-hero]").forEach((hero) => {
      const confettiLayer = hero.querySelector("[data-loyalty-confetti]");
      const pointsValue = hero.querySelector("[data-loyalty-points-value]");
      if (!confettiLayer) return;

      const targetPoints = Number(pointsValue?.dataset.loyaltyPointsTarget || 0);
      const renderPointsValue = (value) => {
        if (!pointsValue) return;

        pointsValue.textContent = `${value}`;
      };

      window.clearTimeout(hero.__loyaltyPointsResetTimer);
      window.clearTimeout(hero.__loyaltyPointsBounceTimer);
      window.clearTimeout(hero.__loyaltyPointsCleanupTimer);
      window.cancelAnimationFrame(hero.__loyaltyPointsCountFrame);
      confettiLayer.classList.remove("is-fading");
      confettiLayer.replaceChildren();
      hero.classList.remove("is-celebrating");
      hero.classList.remove("is-points-bouncing");
      renderPointsValue(0);

      if (prefersReducedMotion) {
        renderPointsValue(targetPoints);
        return;
      }

      const countDuration = 1100;
      const startTime = performance.now();
      const countUp = (timestamp) => {
        const progress = Math.min((timestamp - startTime) / countDuration, 1);
        const easedProgress = 1 - ((1 - progress) ** 3);
        const currentValue = Math.round(targetPoints * easedProgress);

        renderPointsValue(currentValue);

        if (progress < 1) {
          hero.__loyaltyPointsCountFrame = window.requestAnimationFrame(countUp);
        }
      };

      hero.__loyaltyPointsCountFrame = window.requestAnimationFrame(countUp);

      const css = getComputedStyle(document.documentElement);
      const colors = [
        css.getPropertyValue("--fl-primary").trim() || "#43b150",
        "#7dd3fc",
        "#fbbf24",
        "#fb7185",
        "#f97316",
        "#a3e635",
        css.getPropertyValue("--fl-success").trim() || "#198754"
      ];
      const pointsBlock = hero.querySelector(".loyalty-result-hero__points");
      const heroRect = hero.getBoundingClientRect();
      const pointsRect = pointsBlock?.getBoundingClientRect();
      const centerX = pointsRect
        ? ((pointsRect.left + pointsRect.width / 2 - heroRect.left) / heroRect.width) * 100
        : 50;
      const centerY = pointsRect
        ? ((pointsRect.top + pointsRect.height / 2 - heroRect.top) / heroRect.height) * 100
        : 34;
      const leftAnchor = Math.max(14, centerX - 24);
      const leftInnerAnchor = Math.max(26, centerX - 12);
      const rightInnerAnchor = Math.min(74, centerX + 12);
      const rightAnchor = Math.min(86, centerX + 24);
      const bottomLaunchY = Math.min(128, Math.max(116, centerY + 86));

      const appendConfettiBurst = ({ originX, originY, count, direction, delayBase, centerSpread = 214, verticalLift = null }) => {
        Array.from({ length: count }).forEach((_, index) => {
          const piece = document.createElement("span");
          const horizontalBias = direction === "left" ? -1 : direction === "right" ? 1 : 0;
          const horizontalSpread = 48 + Math.random() * 152;
          const horizontalDrift = horizontalBias === 0
            ? (Math.random() - 0.5) * centerSpread
            : horizontalBias * horizontalSpread + (Math.random() - 0.5) * 34;
          const upwardLift = verticalLift === null
            ? -72 - Math.random() * 156
            : verticalLift.min + Math.random() * (verticalLift.max - verticalLift.min);

          piece.className = "loyalty-result-confetti__piece";
          piece.style.setProperty("--confetti-origin-x", `${originX}%`);
          piece.style.setProperty("--confetti-origin-y", `${originY}%`);
          piece.style.setProperty("--confetti-color", colors[(index + Math.round(originX)) % colors.length]);
          piece.style.setProperty("--confetti-size", `${(9 + Math.random() * 10).toFixed(2)}px`);
          piece.style.setProperty("--confetti-delay", `${(delayBase + Math.random() * 0.26).toFixed(2)}s`);
          piece.style.setProperty("--confetti-duration", `${(2.2 + Math.random() * 0.85).toFixed(2)}s`);
          piece.style.setProperty("--confetti-rotate", `${Math.round(Math.random() * 360 - 180)}deg`);
          piece.style.setProperty("--confetti-x", `${horizontalDrift.toFixed(2)}px`);
          piece.style.setProperty("--confetti-y", `${upwardLift.toFixed(2)}px`);
          confettiLayer.appendChild(piece);
        });
      };

      const appendFirework = ({ x, y, angle, delay, color }) => {
        const firework = document.createElement("span");
        const trail = document.createElement("span");
        const burst = document.createElement("span");
        const spark = document.createElement("span");

        firework.className = "loyalty-result-firework";
        trail.className = "loyalty-result-firework__trail";
        burst.className = "loyalty-result-firework__burst";
        spark.className = "loyalty-result-firework__spark";

        firework.style.setProperty("--firework-x", `${x}%`);
        firework.style.setProperty("--firework-y", `${y}%`);
        firework.style.setProperty("--firework-angle", `${angle}deg`);
        firework.style.setProperty("--firework-delay", `${delay.toFixed(2)}s`);
        firework.style.setProperty("--firework-duration", `${(1.5 + Math.random() * 0.35).toFixed(2)}s`);
        firework.style.setProperty("--firework-trail-length", `${(5.6 + Math.random() * 1.8).toFixed(2)}rem`);
        firework.style.setProperty("--firework-burst-size", `${(2.8 + Math.random() * 0.7).toFixed(2)}rem`);
        firework.style.setProperty("--firework-color", color);

        firework.appendChild(trail);
        firework.appendChild(burst);
        firework.appendChild(spark);
        confettiLayer.appendChild(firework);
      };

      [
        { x: leftAnchor, y: centerY - 8, angle: -28, delay: 0.02, color: "#fbbf24" },
        { x: centerX, y: centerY - 12, angle: 0, delay: 0.12, color: "#fde047" },
        { x: leftInnerAnchor, y: centerY - 10, angle: -18, delay: 0.18, color: "#7dd3fc" },
        { x: rightAnchor, y: centerY - 8, angle: 28, delay: 0.08, color: css.getPropertyValue("--fl-primary").trim() || "#43b150" },
        { x: rightInnerAnchor, y: centerY - 10, angle: 18, delay: 0.26, color: "#fb7185" }
      ].forEach(appendFirework);

      appendConfettiBurst({
        originX: leftAnchor,
        originY: bottomLaunchY - 3,
        count: 24,
        direction: "left",
        delayBase: 0.48,
        verticalLift: { min: -168, max: -292 }
      });
      appendConfettiBurst({
        originX: leftInnerAnchor,
        originY: bottomLaunchY - 6,
        count: 14,
        direction: "center",
        delayBase: 0.62,
        centerSpread: 150,
        verticalLift: { min: -154, max: -276 }
      });
      appendConfettiBurst({
        originX: centerX,
        originY: bottomLaunchY - 8,
        count: 28,
        direction: "center",
        delayBase: 0.36,
        centerSpread: 104,
        verticalLift: { min: -208, max: -334 }
      });
      appendConfettiBurst({
        originX: rightInnerAnchor,
        originY: bottomLaunchY - 6,
        count: 14,
        direction: "center",
        delayBase: 0.68,
        centerSpread: 150,
        verticalLift: { min: -154, max: -276 }
      });
      appendConfettiBurst({
        originX: rightAnchor,
        originY: bottomLaunchY - 3,
        count: 24,
        direction: "right",
        delayBase: 0.54,
        verticalLift: { min: -168, max: -292 }
      });
      appendConfettiBurst({
        originX: Math.max(10, centerX - 32),
        originY: bottomLaunchY,
        count: 10,
        direction: "right",
        delayBase: 0.74,
        centerSpread: 118,
        verticalLift: { min: -132, max: -248 }
      });
      appendConfettiBurst({
        originX: Math.min(90, centerX + 32),
        originY: bottomLaunchY,
        count: 10,
        direction: "left",
        delayBase: 0.78,
        centerSpread: 118,
        verticalLift: { min: -132, max: -248 }
      });
      appendConfettiBurst({
        originX: centerX,
        originY: bottomLaunchY + 2,
        count: 12,
        direction: "center",
        delayBase: 0.86,
        centerSpread: 126,
        verticalLift: { min: -144, max: -262 }
      });

      requestAnimationFrame(() => {
        hero.classList.add("is-celebrating");
      });

      hero.__loyaltyPointsResetTimer = window.setTimeout(() => {
        hero.classList.remove("is-celebrating");
        confettiLayer.classList.add("is-fading");
      }, 1400);

      hero.__loyaltyPointsBounceTimer = window.setTimeout(() => {
        hero.classList.add("is-points-bouncing");
      }, 1100);

      hero.__loyaltyPointsCleanupTimer = window.setTimeout(() => {
        hero.classList.remove("is-points-bouncing");
        confettiLayer.replaceChildren();
      }, 2100);
    });
  };

  const setInstallPanelState = (panel, state = {}) => {
    const button = panel.querySelector("[data-pwa-install-button]");
    const status = panel.querySelector("[data-pwa-install-status]");
    const help = panel.querySelector("[data-pwa-install-help]");

    if (!button || !status || !help) return;

    if (isStandaloneMode()) {
      panel.classList.add("d-none");
      return;
    }

    panel.classList.remove("d-none");
    button.disabled = state.busy === true;

    if (installPromptState.deferredPrompt) {
      button.classList.remove("btn-outline-primary");
      button.classList.add("btn-primary");
      status.textContent = "Install Ace Fuel Loyalty now for one-tap staff access from your home screen.";
      help.classList.add("d-none");
      help.textContent = "";
      return;
    }

    button.classList.remove("btn-primary");
    button.classList.add("btn-outline-primary");
    status.textContent = "Install Ace Fuel Loyalty app to this device";

    if (state.showManualInstructions) {
      help.textContent = installInstructionsForDevice();
      help.classList.remove("d-none");
      return;
    }

    help.classList.add("d-none");
    help.textContent = "";
  };

  const refreshInstallPanels = (state = {}) => {
    document.querySelectorAll("[data-pwa-install-panel]").forEach((panel) => {
      setInstallPanelState(panel, state);
    });
  };

  const bindInstallPromptEvents = () => {
    if (window.__fuelLoyaltyInstallPromptBound) return;

    window.__fuelLoyaltyInstallPromptBound = true;

    window.addEventListener("beforeinstallprompt", (event) => {
      event.preventDefault();
      installPromptState.deferredPrompt = event;
      trackAnalyticsEvent("pwa_install_prompt_available", {
        prompt_supported: true,
        platforms: Array.isArray(event.platforms) ? event.platforms : []
      });
      refreshInstallPanels();
    });

    window.addEventListener("appinstalled", () => {
      installPromptState.deferredPrompt = null;
      trackAnalyticsEvent("pwa_install_completed", {
        source: "browser_install_event"
      });
      refreshInstallPanels();
    });
  };

  const initializeInstallPrompt = () => {
    const panels = document.querySelectorAll("[data-pwa-install-panel]");
    if (panels.length === 0) return;

    panels.forEach((panel) => {
      const button = panel.querySelector("[data-pwa-install-button]");
      if (!button) return;

      if (panel.dataset.installViewed !== "true" && !isStandaloneMode()) {
        panel.dataset.installViewed = "true";
        trackAnalyticsEvent("pwa_install_cta_viewed", {
          source: panel.dataset.installSource || "unknown"
        });
      }

      if (panel.dataset.bound === "true") {
        setInstallPanelState(panel);
        return;
      }

      panel.dataset.bound = "true";

      button.addEventListener("click", async () => {
        const source = panel.dataset.installSource || "unknown";
        const prompt = installPromptState.deferredPrompt;

        trackAnalyticsEvent("pwa_install_cta_clicked", {
          source,
          prompt_available: Boolean(prompt)
        });

        if (!prompt) {
          setInstallPanelState(panel, { showManualInstructions: true });
          trackAnalyticsEvent("pwa_install_manual_instructions_shown", {
            source,
            reason: "prompt_unavailable"
          });
          return;
        }

        try {
          setInstallPanelState(panel, { busy: true });
          trackAnalyticsEvent("pwa_install_prompt_shown", { source });
          await prompt.prompt();
          const choice = await prompt.userChoice;

          trackAnalyticsEvent(
            choice.outcome === "accepted" ? "pwa_install_prompt_accepted" : "pwa_install_prompt_dismissed",
            {
              source,
              outcome: choice.outcome
            }
          );
        } catch (error) {
          trackAnalyticsEvent("pwa_install_prompt_error", {
            source,
            message: error.message
          });
        } finally {
          installPromptState.deferredPrompt = null;
          setInstallPanelState(panel, { busy: false });
          refreshInstallPanels();
        }
      });

      setInstallPanelState(panel);
    });
  };

  const normalizeVehicleTypeIconText = (value) => {
    return String(value || "")
      .toLowerCase()
      .trim()
      .replace(/[^a-z0-9]+/g, "_")
      .replace(/^_+|_+$/g, "");
  };

  const suggestedVehicleTypeIconName = (values = []) => {
    const normalizedText = values
      .map((value) => normalizeVehicleTypeIconText(value))
      .filter(Boolean)
      .join("_");

    if (!normalizedText) return "ti-car";
    if (/ambulance/.test(normalizedText)) return "ti-ambulance";
    if (/firetruck|fire_truck|fire_engine/.test(normalizedText)) return "ti-firetruck";
    if (/tractor/.test(normalizedText)) return "ti-tractor";
    if (/bus|coach/.test(normalizedText)) return "ti-bus";
    if (/caravan|camper|motorhome|rv/.test(normalizedText)) return "ti-caravan";
    if (/forklift/.test(normalizedText)) return "ti-forklift";
    if (/three_wheeler|three_wheel|rickshaw|auto|trike/.test(normalizedText)) return "ti-moped";
    if (/pickup|delivery|cargo|goods|lorry|truck|hcv|mcv|lcv/.test(normalizedText)) return "ti-truck";
    if (/suv|jeep|4wd|four_wheel_drive/.test(normalizedText)) return "ti-car-suv";
    if (/motorbike|motor_cycle|motorcycle/.test(normalizedText)) return "ti-motorbike";
    if (/moped/.test(normalizedText)) return "ti-moped";
    if (/scooter|electric|ev/.test(normalizedText)) return "ti-scooter-electric";
    if (/bike|bicycle|cycle|two_wheeler|two_wheel/.test(normalizedText)) return "ti-bike";

    return "ti-car";
  };

  const initializeVehicleTypeIconPickers = () => {
    document.querySelectorAll("[data-vehicle-type-icon-picker]").forEach((picker) => {
      if (picker.dataset.bound === "true") return;
      picker.dataset.bound = "true";

      let manualSelection = picker.dataset.vehicleTypeIconAutoSuggest !== "true";
      const sourceFields = Array.from(picker.querySelectorAll("[data-vehicle-type-icon-source]"));
      const iconFields = Array.from(picker.querySelectorAll("[data-vehicle-type-icon-option]"));

      if (iconFields.length === 0) return;

      const applySuggestion = () => {
        if (manualSelection) return;

        const suggestedValue = suggestedVehicleTypeIconName(sourceFields.map((field) => field.value));
        const suggestedField = iconFields.find((field) => field.value === suggestedValue);

        if (suggestedField) {
          suggestedField.checked = true;
        }
      };

      iconFields.forEach((field) => {
        field.addEventListener("change", () => {
          manualSelection = true;
        });
      });

      sourceFields.forEach((field) => {
        field.addEventListener("input", applySuggestion);
        field.addEventListener("change", applySuggestion);
      });

      applySuggestion();
    });
  };

  document.addEventListener("turbo:load", initializeTheme);
  document.addEventListener("DOMContentLoaded", initializeTheme);
  document.addEventListener("turbo:before-render", (event) => applySidebarShellState(event.detail.newBody));
  document.addEventListener("turbo:load", initializeSidebar);
  document.addEventListener("DOMContentLoaded", initializeSidebar);
  document.addEventListener("turbo:load", initializeConfirmModal);
  document.addEventListener("DOMContentLoaded", initializeConfirmModal);
  document.addEventListener("turbo:load", initializeAutoOpenModals);
  document.addEventListener("DOMContentLoaded", initializeAutoOpenModals);
  document.addEventListener("turbo:load", initializeLazyPointsLedger);
  document.addEventListener("DOMContentLoaded", initializeLazyPointsLedger);
  document.addEventListener("turbo:load", initializeLazyTransactionHistory);
  document.addEventListener("DOMContentLoaded", initializeLazyTransactionHistory);
  document.addEventListener("turbo:load", initializePhoneNumberFields);
  document.addEventListener("DOMContentLoaded", initializePhoneNumberFields);
  document.addEventListener("turbo:load", initializeLoyaltyPointsHero);
  document.addEventListener("DOMContentLoaded", initializeLoyaltyPointsHero);
  document.addEventListener("turbo:load", initializeInstallPrompt);
  document.addEventListener("DOMContentLoaded", initializeInstallPrompt);
  document.addEventListener("turbo:load", initializePushOptIn);
  document.addEventListener("DOMContentLoaded", initializePushOptIn);
  document.addEventListener("turbo:load", initializeNotificationScheduleForms);
  document.addEventListener("DOMContentLoaded", initializeNotificationScheduleForms);
  document.addEventListener("turbo:load", initializeAttendancePlanner);
  document.addEventListener("DOMContentLoaded", initializeAttendancePlanner);
  document.addEventListener("turbo:load", initializeShiftAssignmentForms);
  document.addEventListener("DOMContentLoaded", initializeShiftAssignmentForms);
  document.addEventListener("turbo:load", initializeShiftCycleForms);
  document.addEventListener("DOMContentLoaded", initializeShiftCycleForms);
  document.addEventListener("turbo:load", initializeVehicleTypeIconPickers);
  document.addEventListener("DOMContentLoaded", initializeVehicleTypeIconPickers);
  bindInstallPromptEvents();
  registerServiceWorker();
})();
