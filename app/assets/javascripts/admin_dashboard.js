(() => {
  const chartRegistry = new Map();

  const formatNumber = (value) => new Intl.NumberFormat("en-IN", { maximumFractionDigits: 1 }).format(value || 0);
  const formatCurrency = (value) => new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    maximumFractionDigits: Math.abs(value) >= 100 ? 0 : 2
  }).format(value || 0);
  const formatPercent = (value) => `${Number(value || 0).toFixed(1).replace(/\.0$/, "")}%`;
  const formatDateTime = (value) => {
    if (!value) return "";

    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return value;

    return new Intl.DateTimeFormat("en-IN", {
      dateStyle: "medium",
      timeStyle: "short"
    }).format(date);
  };

  const palette = () => {
    const css = getComputedStyle(document.documentElement);

    return {
      primary: css.getPropertyValue("--fl-primary").trim() || "#43b05c",
      primarySoft: css.getPropertyValue("--fl-primary-soft").trim() || "rgba(67, 176, 92, 0.14)",
      success: css.getPropertyValue("--fl-success").trim() || "#2f9e44",
      info: css.getPropertyValue("--fl-info").trim() || "#2d8b73",
      warning: css.getPropertyValue("--fl-warning").trim() || "#d4a017",
      danger: css.getPropertyValue("--fl-danger").trim() || "#e36b6b",
      border: css.getPropertyValue("--fl-gray-200").trim() || "#e4d7bb",
      muted: css.getPropertyValue("--fl-gray-500").trim() || "#7a6c57",
      text: css.getPropertyValue("--fl-gray-800").trim() || "#251d12"
    };
  };

  const buildDataset = (dataset, index, key) => {
    const colors = palette();
    const colorMap = {
      transactions_trend: colors.primary,
      revenue_trend: colors.info,
      active_users_trend: colors.success,
      issued: colors.primary,
      redeemed: colors.warning
    };

    const defaultColor = [colors.primary, colors.info, colors.warning, colors.success][index] || colors.primary;
    const lineColor = colorMap[dataset.label?.toLowerCase()] || colorMap[key] || defaultColor;

    return {
      label: dataset.label || "",
      data: dataset.data,
      borderColor: lineColor,
      backgroundColor: `${lineColor}22`,
      fill: false,
      tension: 0.32,
      pointRadius: 0,
      pointHoverRadius: 4,
      borderWidth: 2.4
    };
  };

  const destroyCharts = () => {
    chartRegistry.forEach((chart) => chart.destroy());
    chartRegistry.clear();
  };

  const refreshChartsForPrint = () => {
    chartRegistry.forEach((chart) => {
      try {
        chart.resize();
        chart.update("none");
      } catch (error) {
        console.error("Failed to refresh dashboard chart for print", error);
      }
    });
  };

  const destroyChart = (canvas) => {
    const existing = chartRegistry.get(canvas);
    if (!existing) return;

    existing.destroy();
    chartRegistry.delete(canvas);
  };

  const withChart = (canvas, config) => {
    if (typeof Chart === "undefined") {
      throw new Error("Chart.js failed to load");
    }

    const existing = chartRegistry.get(canvas);
    if (existing) existing.destroy();

    const chart = new Chart(canvas, config);
    chartRegistry.set(canvas, chart);
  };

  const baseChartOptions = (valueType, horizontal = false) => {
    const colors = palette();

    return {
      responsive: true,
      maintainAspectRatio: false,
      animation: { duration: 320 },
      interaction: { intersect: false, mode: "index" },
      plugins: {
        legend: {
          display: true,
          align: "start",
          labels: {
            color: colors.text,
            boxWidth: 10,
            boxHeight: 10,
            usePointStyle: true,
            pointStyle: "circle",
            padding: 16,
            font: { family: "Poppins", size: 11, weight: "600" }
          }
        },
        tooltip: {
          backgroundColor: "rgba(20, 24, 20, 0.92)",
          titleFont: { family: "Poppins", size: 12, weight: "600" },
          bodyFont: { family: "Poppins", size: 11 },
          padding: 10,
          callbacks: {
            label(context) {
              const rawValue = context.parsed?.y ?? context.parsed?.x ?? context.raw ?? 0;

              if (valueType === "currency") {
                return `${context.dataset.label || "Value"} ${formatCurrency(rawValue)}`;
              }

              if (valueType === "percentage") {
                return `${context.dataset.label || "Value"} ${formatPercent(rawValue)}`;
              }

              return `${context.dataset.label || "Value"} ${formatNumber(rawValue)}`;
            }
          }
        }
      },
      scales: horizontal ? {
        x: {
          beginAtZero: true,
          grid: { color: `${colors.border}88`, drawBorder: false },
          ticks: {
            color: colors.muted,
            font: { family: "Poppins", size: 11 },
            callback(value) {
              return valueType === "currency" ? formatCurrency(value) : formatNumber(value);
            }
          }
        },
        y: {
          grid: { display: false, drawBorder: false },
          ticks: {
            color: colors.muted,
            font: { family: "Poppins", size: 11 }
          }
        }
      } : {
        x: {
          grid: { display: false, drawBorder: false },
          ticks: {
            color: colors.muted,
            maxRotation: 0,
            autoSkip: true,
            font: { family: "Poppins", size: 11 }
          }
        },
        y: {
          beginAtZero: true,
          grid: { color: `${colors.border}88`, drawBorder: false },
          ticks: {
            color: colors.muted,
            font: { family: "Poppins", size: 11 },
            callback(value) {
              return valueType === "currency" ? formatCurrency(value) : formatNumber(value);
            }
          }
        }
      }
    };
  };

  const toggleChartEmptyState = (canvas, empty) => {
    const card = canvas.closest("[data-chart-card]");
    const emptyState = card?.querySelector("[data-chart-empty]");

    if (!emptyState) return;

    emptyState.classList.toggle("d-none", !empty);
    canvas.classList.toggle("d-none", empty);
  };

  const renderLineChart = (canvas, key, payload) => {
    const datasets = payload.datasets || [];
    const hasData = datasets.some((dataset) => (dataset.data || []).some((value) => Number(value || 0) > 0));
    toggleChartEmptyState(canvas, !hasData);
    if (!hasData) return;

    const firstDataset = datasets[0] || {};

    withChart(canvas, {
      type: "line",
      data: {
        labels: payload.labels,
        datasets: datasets.map((dataset, index) => buildDataset(dataset, index, key))
      },
      options: baseChartOptions(firstDataset.value_type || "number")
    });
  };

  const renderBarChart = (canvas, key, payload, { horizontal = false } = {}) => {
    const colors = palette();
    const values = payload.values || [];
    const valueType = payload.value_type || "number";
    const hasData = values.some((value) => Number(value || 0) > 0);
    toggleChartEmptyState(canvas, !hasData);
    if (!hasData) return;

    const barColor = {
      repeat_vs_new: [colors.primary, colors.info],
      visits_distribution: [colors.primary, colors.warning, colors.success],
      top_customers_by_transactions: [colors.primary, colors.info, colors.warning, colors.success, colors.danger],
      top_customers_by_revenue: [colors.info, colors.primary, colors.warning, colors.success, colors.danger],
      top_rewards_redeemed: [colors.primary, colors.info, colors.warning, colors.success, colors.danger],
      transactions_by_hour: Array(values.length).fill(colors.primary),
      transactions_by_day: Array(values.length).fill(colors.info)
    }[key] || Array(values.length).fill(colors.primary);

    withChart(canvas, {
      type: "bar",
      data: {
        labels: payload.labels,
        datasets: [
          {
            label: "",
            data: values,
            backgroundColor: barColor,
            borderRadius: 8,
            borderSkipped: false,
            maxBarThickness: horizontal ? 18 : 28
          }
        ]
      },
      options: {
        ...baseChartOptions(valueType, horizontal),
        indexAxis: horizontal ? "y" : "x",
        plugins: {
          ...baseChartOptions(valueType, horizontal).plugins,
          legend: { display: false }
        }
      }
    });
  };

  const applyTrendBadge = (badge, comparison = null) => {
    if (!badge) return;

    if (!comparison || !comparison.label) {
      badge.textContent = "";
      badge.className = "badge rounded-pill border dashboard-chart-card__badge d-none";
      return;
    }

    const direction = comparison.direction || "neutral";
    badge.textContent = comparison.label;
    badge.className = `badge rounded-pill border dashboard-chart-card__badge is-${direction}`;
  };

  const renderChartBadge = (card, payload = {}) => {
    applyTrendBadge(card?.querySelector("[data-chart-badge]"), payload.comparison || null);
  };

  const renderSparkline = (canvas, values, direction) => {
    if (!canvas || !Array.isArray(values) || values.length === 0) return;

    const colors = palette();
    const lineColor = {
      up: colors.success,
      down: colors.danger,
      neutral: colors.muted
    }[direction] || colors.primary;

    withChart(canvas, {
      type: "line",
      data: {
        labels: values.map((_value, index) => index + 1),
        datasets: [
          {
            data: values,
            borderColor: lineColor,
            backgroundColor: `${lineColor}18`,
            tension: 0.35,
            pointRadius: 0,
            pointHoverRadius: 0,
            borderWidth: 2,
            fill: false
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: { duration: 240 },
        plugins: {
          legend: { display: false },
          tooltip: { enabled: false }
        },
        scales: {
          x: { display: false },
          y: { display: false }
        },
        elements: {
          line: { capBezierPoints: true }
        }
      }
    });
  };

  const renderLeaderboards = (root, charts) => {
    ["top_customers_by_transactions", "top_customers_by_revenue"].forEach((key) => {
      const card = root.querySelector(`[data-dashboard-leaderboard="${key}"]`);
      if (!card) return;

      const payload = charts?.[key] || {};
      const list = card.querySelector("[data-leaderboard-list]");
      const emptyState = card.querySelector("[data-leaderboard-empty]");
      const badge = card.querySelector("[data-leaderboard-badge]");
      const items = Array.isArray(payload.items) ? payload.items : [];

      applyTrendBadge(badge, payload.comparison || null);

      if (list) {
        list.querySelectorAll("[data-leaderboard-sparkline]").forEach((canvas) => destroyChart(canvas));
        list.innerHTML = "";
      }

      if (!list || items.length === 0) {
        if (emptyState) emptyState.classList.toggle("d-none", items.length > 0);
        return;
      }

      if (emptyState) emptyState.classList.add("d-none");

      items.forEach((item) => {
        const row = document.createElement("div");
        row.className = "dashboard-leaderboard-row";
        row.setAttribute("data-leaderboard-item", "");

        const identity = document.createElement("div");
        identity.className = "dashboard-leaderboard-row__identity";

        const rank = document.createElement("span");
        rank.className = "dashboard-leaderboard-row__rank";
        rank.textContent = `#${item.rank || ""}`;

        const copy = document.createElement("div");
        copy.className = "dashboard-leaderboard-row__copy";

        const name = document.createElement("strong");
        name.className = "dashboard-leaderboard-row__name";
        name.textContent = item.label || "";

        const value = document.createElement("span");
        value.className = "dashboard-leaderboard-row__value";
        value.textContent = item.display_value || "";

        copy.append(name, value);
        identity.append(rank, copy);

        const trend = document.createElement("div");
        trend.className = "dashboard-leaderboard-row__trend";

        const change = document.createElement("span");
        change.className = `dashboard-leaderboard-row__change is-${item.direction || "neutral"}`;
        change.textContent = item.change_label || "";

        const sparkline = document.createElement("canvas");
        sparkline.height = 42;
        sparkline.setAttribute("data-leaderboard-sparkline", "");

        trend.append(sparkline, change);
        row.append(identity, trend);
        list.appendChild(row);

        renderSparkline(sparkline, item.trend_values || [], item.direction || "neutral");
      });
    });
  };

  const renderRewardsCard = (root, rewards) => {
    const value = root.querySelector("[data-redemption-rate-value]");
    const bar = root.querySelector("[data-redemption-rate-bar]");
    const issued = root.querySelector("[data-redemption-issued]");
    const redeemed = root.querySelector("[data-redemption-redeemed]");
    const note = root.querySelector("[data-redemption-note]");

    if (!value || !bar || !issued || !redeemed || !note) return;

    const rate = Number(rewards.redemption_rate || 0);

    value.textContent = formatPercent(rate);
    bar.style.width = `${Math.min(rate, 100)}%`;
    issued.textContent = formatNumber(rewards.issued_points || 0);
    redeemed.textContent = formatNumber(rewards.redeemed_points || 0);
    note.textContent = rewards.note || "";
  };

  const renderKpis = (root, summary) => {
    (summary || []).forEach((metric) => {
      const card = root.querySelector(`[data-kpi-card="${metric.key}"]`);
      if (!card) return;

      const value = card.querySelector("[data-kpi-value]");
      const change = card.querySelector("[data-kpi-change]");
      const breakdown = card.querySelector("[data-kpi-breakdown]");

      if (value) value.textContent = metric.display_value;

      if (breakdown) {
        const items = Array.isArray(metric.breakdown) ? metric.breakdown : [];
        breakdown.innerHTML = "";
        breakdown.classList.toggle("d-none", items.length === 0);

        items.forEach((item) => {
          const row = document.createElement("div");
          row.className = "dashboard-kpi-card__breakdown-item";
          row.setAttribute("data-kpi-breakdown-item", "");

          const label = document.createElement("span");
          label.className = "dashboard-kpi-card__breakdown-label";
          label.textContent = item.label || "";

          const amount = document.createElement("strong");
          amount.className = "dashboard-kpi-card__breakdown-value";
          amount.textContent = item.display_value || formatCurrency(item.value || 0);

          row.append(label, amount);
          breakdown.appendChild(row);
        });
      }

      if (!change) return;

      if (metric.change_pct === null || metric.change_pct === undefined) {
        change.textContent = "New baseline";
        change.className = "dashboard-kpi-card__change is-neutral";
        return;
      }

      const sign = metric.change_pct > 0 ? "+" : "";
      change.textContent = `${sign}${metric.change_pct}% vs previous period`;
      const changeClass = metric.direction === "up" ? "is-positive" : (metric.direction === "down" ? "is-negative" : "is-neutral");
      change.className = `dashboard-kpi-card__change ${changeClass}`;
    });
  };

  const renderMeta = (root, meta) => {
    const rangeLabel = root.querySelector("[data-dashboard-range-label]");
    const segmentLabel = root.querySelector("[data-dashboard-segment-label]");
    const fuelTypeLabel = root.querySelector("[data-dashboard-fuel-type-label]");

    if (rangeLabel) rangeLabel.textContent = meta.range_label;
    if (segmentLabel) segmentLabel.textContent = meta.segment_label;
    if (fuelTypeLabel) fuelTypeLabel.textContent = `Fuel type: ${meta.fuel_type_label || "Total"}`;
  };

  const presetLabelForFilters = (filters = {}) => {
    const presets = Array.isArray(filters.presets) ? filters.presets : [];
    const match = presets.find((preset) => preset.value === filters.preset);

    return match?.label || "Custom range";
  };

  const renderExportSummary = (root, payload = {}) => {
    const meta = payload.meta || {};
    const filters = payload.filters || {};

    const range = root.querySelector("[data-dashboard-export-range]");
    const preset = root.querySelector("[data-dashboard-export-preset]");
    const segment = root.querySelector("[data-dashboard-export-segment]");
    const fuelType = root.querySelector("[data-dashboard-export-fuel-type]");
    const generatedAt = root.querySelector("[data-dashboard-export-generated-at]");

    if (range) range.textContent = meta.range_label || "";
    if (preset) preset.textContent = presetLabelForFilters(filters);
    if (segment) segment.textContent = meta.segment_label || "";
    if (fuelType) fuelType.textContent = meta.fuel_type_label || "Total";
    if (generatedAt) generatedAt.textContent = formatDateTime(meta.generated_at || new Date().toISOString());
  };

  const renderCharts = (root, charts) => {
    Object.entries(charts || {}).forEach(([key, payload]) => {
      const canvas = root.querySelector(`[data-dashboard-chart="${key}"]`);
      if (!canvas) return;
      const card = canvas.closest("[data-chart-card]");

      renderChartBadge(card, payload);

      try {
        if (["transactions_trend", "revenue_trend", "points_trend", "active_users_trend"].includes(key)) {
          renderLineChart(canvas, key, payload);
          return;
        }

        renderBarChart(canvas, key, payload, { horizontal: canvas.dataset.chartHorizontal === "true" });
      } catch (error) {
        toggleChartEmptyState(canvas, true);
        console.error(`Failed to render dashboard chart: ${key}`, error);
      }
    });
  };

  const setLoadingState = (root, loading) => {
    root.classList.toggle("is-loading", loading);

    const downloadButton = root.querySelector("[data-dashboard-download]");
    if (downloadButton) downloadButton.disabled = loading;
  };

  const buildDashboardParams = (form) => {
    const params = new URLSearchParams(new FormData(form));

    Array.from(params.keys()).forEach((key) => {
      const value = params.get(key);
      if (value === null || value === undefined || value === "") params.delete(key);
    });

    return params;
  };

  const syncDashboardFilterButtons = (form) => {
    if (!form) return;

    const presetValue = form.querySelector("[data-dashboard-preset-input]")?.value || "";
    const fuelTypeValue = form.querySelector("[data-dashboard-fuel-type-input]")?.value || "all";

    form.querySelectorAll("[data-dashboard-preset-button]").forEach((button) => {
      const active = button.dataset.dashboardPresetButton === presetValue;
      button.classList.toggle("is-active", active);
      button.setAttribute("aria-pressed", active ? "true" : "false");
    });

    form.querySelectorAll("[data-dashboard-fuel-button]").forEach((button) => {
      const active = button.dataset.dashboardFuelButton === fuelTypeValue;
      button.classList.toggle("is-active", active);
      button.setAttribute("aria-pressed", active ? "true" : "false");
    });
  };

  const syncDashboardFilters = (form, filters = {}) => {
    if (!form) return;

    const startDate = form.querySelector("[name='start_date']");
    const endDate = form.querySelector("[name='end_date']");
    const segment = form.querySelector("[name='segment']");
    const preset = form.querySelector("[data-dashboard-preset-input]");
    const fuelType = form.querySelector("[data-dashboard-fuel-type-input]");

    if (startDate && filters.start_date) startDate.value = filters.start_date;
    if (endDate && filters.end_date) endDate.value = filters.end_date;
    if (segment && filters.segment) segment.value = filters.segment;
    if (preset) preset.value = filters.preset || "";
    if (fuelType) fuelType.value = filters.fuel_type || "all";

    syncDashboardFilterButtons(form);
  };

  const updateHistory = (params) => {
    const query = params.toString();
    const nextUrl = query.length > 0 ? `${window.location.pathname}?${query}` : window.location.pathname;
    window.history.replaceState({}, "", nextUrl);
  };

  const renderDashboard = (root, payload) => {
    try {
      renderExportSummary(root, payload);
      renderMeta(root, payload.meta || {});
      renderKpis(root, payload.summary || []);
      renderCharts(root, payload.charts || {});
      renderLeaderboards(root, payload.charts || {});
      renderRewardsCard(root, payload.rewards || {});
    } catch (error) {
      console.error("Failed to render dashboard", error);
    } finally {
      setLoadingState(root, false);
    }
  };

  const fetchPayload = async (root, params) => {
    setLoadingState(root, true);

    try {
      const query = params.toString();
      const endpoint = query.length > 0 ? `${root.dataset.dashboardEndpoint}?${query}` : root.dataset.dashboardEndpoint;
      const response = await fetch(endpoint, {
        headers: { Accept: "application/json" },
        credentials: "same-origin"
      });

      if (!response.ok) {
        setLoadingState(root, false);
        return;
      }

      const payload = await response.json();
      renderDashboard(root, payload);
      const form = root.querySelector("[data-dashboard-filters]");
      syncDashboardFilters(form, payload.filters || {});
      updateHistory(params);
      if (form) root.dataset.dashboardLastQuery = buildDashboardParams(form).toString();
    } catch (error) {
      console.error("Failed to fetch dashboard data", error);
      setLoadingState(root, false);
    }
  };

  const triggerDashboardPdfDownload = (root) => {
    if (!root || root.classList.contains("is-loading")) return;

    const generatedAt = root.querySelector("[data-dashboard-export-generated-at]");
    if (generatedAt) generatedAt.textContent = formatDateTime(new Date().toISOString());

    refreshChartsForPrint();

    const previousTitle = document.title;
    const dateStamp = new Date().toISOString().slice(0, 10);
    document.title = `fuel-loyalty-dashboard-${dateStamp}`;
    root.classList.add("is-exporting");

    const restore = () => {
      document.title = previousTitle;
      root.classList.remove("is-exporting");
      refreshChartsForPrint();
    };

    const restoreAfterPrint = () => {
      restore();
      window.removeEventListener("afterprint", restoreAfterPrint);
    };

    window.addEventListener("afterprint", restoreAfterPrint);
    window.setTimeout(() => window.print(), 60);
    window.setTimeout(() => {
      if (root.classList.contains("is-exporting")) {
        restore();
        window.removeEventListener("afterprint", restoreAfterPrint);
      }
    }, 1500);
  };

  const initializeDashboard = () => {
    const root = document.querySelector("[data-dashboard-root]");
    if (!root) return;
    if (root.dataset.dashboardBound === "true") return;

    root.dataset.dashboardBound = "true";

    const payloadScript = root.querySelector("[data-dashboard-payload]");
    const initialPayload = payloadScript ? JSON.parse(payloadScript.textContent) : null;
    if (initialPayload) renderDashboard(root, initialPayload);

    const downloadButton = root.querySelector("[data-dashboard-download]");
    if (downloadButton) {
      downloadButton.addEventListener("click", () => triggerDashboardPdfDownload(root));
    }

    const form = root.querySelector("[data-dashboard-filters]");
    if (!form) return;

    syncDashboardFilters(form, initialPayload?.filters || {});
    root.dataset.dashboardLastQuery = buildDashboardParams(form).toString();

    const submitFilters = () => {
      const params = buildDashboardParams(form);
      if (params.toString() === (root.dataset.dashboardLastQuery || "")) return;

      fetchPayload(root, params);
    };

    form.addEventListener("submit", (event) => {
      event.preventDefault();
      submitFilters();
    });

    const presetInput = form.querySelector("[data-dashboard-preset-input]");
    const fuelTypeInput = form.querySelector("[data-dashboard-fuel-type-input]");
    const dateInputs = form.querySelectorAll("[data-dashboard-date-filter]");

    form.querySelectorAll("[data-dashboard-select-filter]").forEach((input) => {
      input.addEventListener("change", submitFilters);
    });

    const clearPresetSelection = () => {
      if (!presetInput || presetInput.value === "") return;
      presetInput.value = "";
      syncDashboardFilterButtons(form);
    };

    dateInputs.forEach((input) => {
      input.addEventListener("change", () => {
        clearPresetSelection();
        submitFilters();
      });

      input.addEventListener("blur", () => {
        const startDate = form.querySelector("[name='start_date']")?.value;
        const endDate = form.querySelector("[name='end_date']")?.value;
        if (!startDate || !endDate) return;

        clearPresetSelection();
        submitFilters();
      });
    });

    form.querySelectorAll("[data-dashboard-preset-button]").forEach((button) => {
      button.addEventListener("click", () => {
        const startDate = form.querySelector("[name='start_date']");
        const endDate = form.querySelector("[name='end_date']");

        if (startDate) startDate.value = button.dataset.rangeStart || "";
        if (endDate) endDate.value = button.dataset.rangeEnd || "";
        if (presetInput) presetInput.value = button.dataset.dashboardPresetButton || "";

        syncDashboardFilterButtons(form);
        submitFilters();
      });
    });

    form.querySelectorAll("[data-dashboard-fuel-button]").forEach((button) => {
      button.addEventListener("click", () => {
        if (fuelTypeInput) fuelTypeInput.value = button.dataset.dashboardFuelButton || "all";

        syncDashboardFilterButtons(form);
        submitFilters();
      });
    });
  };

  document.addEventListener("turbo:load", initializeDashboard);
  document.addEventListener("DOMContentLoaded", initializeDashboard);
  window.addEventListener("beforeprint", refreshChartsForPrint);
  window.addEventListener("afterprint", refreshChartsForPrint);
  document.addEventListener("turbo:before-cache", destroyCharts);
})();
