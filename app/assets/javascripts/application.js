(() => {
  const THEME_STORAGE_KEY = "fuel-loyalty-theme";

  const registerServiceWorker = () => {
    if (!("serviceWorker" in navigator)) return;
    if (window.__fuelLoyaltyServiceWorkerRegistered) return;

    window.__fuelLoyaltyServiceWorkerRegistered = true;

    window.addEventListener("load", async () => {
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
    }, { once: true });
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

  document.addEventListener("turbo:load", initializeTheme);
  document.addEventListener("DOMContentLoaded", initializeTheme);
  document.addEventListener("turbo:load", initializeSidebar);
  document.addEventListener("DOMContentLoaded", initializeSidebar);
  document.addEventListener("turbo:load", initializeConfirmModal);
  document.addEventListener("DOMContentLoaded", initializeConfirmModal);
  registerServiceWorker();
})();
