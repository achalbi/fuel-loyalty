(() => {
  const ANALYTICS_ENDPOINT = "/analytics/events";
  const THEME_STORAGE_KEY = "fuel-loyalty-theme";
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

  const currentPagePath = () => `${window.location.pathname}${window.location.search}`;

  const isStandaloneMode = () => window.matchMedia("(display-mode: standalone)").matches || window.navigator.standalone === true;

  const installInstructionsForDevice = () => {
    const userAgent = window.navigator.userAgent.toLowerCase();

    if (/iphone|ipad|ipod/.test(userAgent)) {
      return "Open Safari's Share menu, then tap Add to Home Screen.";
    }

    if (/android/.test(userAgent)) {
      return "Open your browser menu, then choose Install app or Add to Home Screen.";
    }

    return "Use the install option in your browser menu or address bar to add Fuel Loyalty.";
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
    if (!("serviceWorker" in navigator)) return;
    if (window.__fuelLoyaltyServiceWorkerRegistered) return;

    window.__fuelLoyaltyServiceWorkerRegistered = true;

    const register = async () => {
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
      } catch (error) {
        console.error("Service worker registration failed", error);
      }
    };

    register();
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
    const toggleBtn = document.getElementById("toggleBtn");
    const mobileBtn = document.getElementById("mobileBtn");
    const overlay = document.getElementById("overlay");
    const closeMobileSidebar = () => {
      sidebar.classList.remove("mobile-show");
      overlay?.classList.remove("show");
    };

    if (!sidebar || !content || !topbar) return;
    if (sidebar.dataset.bound === "true") return;

    sidebar.dataset.bound = "true";

    toggleBtn?.addEventListener("click", () => {
      sidebar.classList.toggle("collapsed");
      content.classList.toggle("full");
      topbar.classList.toggle("full");
    });

    mobileBtn?.addEventListener("click", () => {
      sidebar.classList.add("mobile-show");
      overlay?.classList.add("show");
    });

    overlay?.addEventListener("click", () => {
      closeMobileSidebar();
    });

    sidebar.querySelectorAll("a").forEach((link) => {
      link.addEventListener("click", () => {
        if (window.innerWidth < 992) closeMobileSidebar();
      });
    });

    document.addEventListener("keydown", (event) => {
      if (event.key === "Escape") closeMobileSidebar();
    });

    window.addEventListener("resize", () => {
      if (window.innerWidth >= 992) closeMobileSidebar();
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
      status.textContent = "Install Fuel Loyalty now for one-tap staff access from your home screen.";
      help.classList.add("d-none");
      help.textContent = "";
      return;
    }

    button.classList.remove("btn-primary");
    button.classList.add("btn-outline-primary");
    status.textContent = "Install Fuel Loyalty app to this device";

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

  document.addEventListener("turbo:load", initializeTheme);
  document.addEventListener("DOMContentLoaded", initializeTheme);
  document.addEventListener("turbo:load", initializeSidebar);
  document.addEventListener("DOMContentLoaded", initializeSidebar);
  document.addEventListener("turbo:load", initializeConfirmModal);
  document.addEventListener("DOMContentLoaded", initializeConfirmModal);
  document.addEventListener("turbo:load", initializePhoneNumberFields);
  document.addEventListener("DOMContentLoaded", initializePhoneNumberFields);
  document.addEventListener("turbo:load", initializeInstallPrompt);
  document.addEventListener("DOMContentLoaded", initializeInstallPrompt);
  bindInstallPromptEvents();
  registerServiceWorker();
})();
