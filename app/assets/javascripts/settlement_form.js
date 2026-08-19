// Daily Settlement — client-side live totals for FSM feedback only. The server
// (Settlement::Calculator) recomputes every derived ₹ on submit and is the sole
// source of truth; this only mirrors the arithmetic so the form feels live.
(() => {
  const num = (el) => {
    if (!el) return 0;
    const raw = el.matches("input, select, textarea") ? el.value : el.textContent;
    const value = parseFloat(raw);
    return Number.isFinite(value) ? value : 0;
  };

  const money = (value) => `₹${value.toLocaleString("en-IN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
  const litres = (value) => value.toLocaleString("en-IN", { maximumFractionDigits: 3 });

  const recompute = (form) => {
    let totalFuel = 0;
    form.querySelectorAll("[data-nozzle-row]").forEach((row) => {
      const opening = num(row.querySelector("[data-opening]"));
      const closing = num(row.querySelector("[data-closing]"));
      const testing = num(row.querySelector("[data-testing]"));
      const rollover = row.querySelector("[data-rollover]")?.checked;
      const price = num(row.querySelector("[data-unit-price]"));
      let net = rollover ? closing - testing : closing - opening - testing;
      if (!closing || net < 0) net = net < 0 ? net : 0;
      const amount = net > 0 ? net * price : 0;
      row.querySelector("[data-net]").textContent = closing ? litres(net) : "—";
      row.querySelector("[data-amount]").textContent = closing ? money(amount) : "—";
      if (net > 0) totalFuel += amount;
    });

    let totalLube = 0;
    form.querySelectorAll("[data-lube-row]").forEach((row) => {
      const qty = num(row.querySelector("[data-qty]"));
      const price = num(row.querySelector("[data-unit-price]"));
      const amount = qty * price;
      row.querySelector("[data-amount]").textContent = qty ? money(amount) : "—";
      totalLube += amount;
    });

    let totalDiscount = 0;
    form.querySelectorAll("[data-discount]").forEach((el) => { totalDiscount += num(el); });

    let totalCredit = 0;
    form.querySelectorAll("[data-credit]").forEach((el) => { totalCredit += num(el); });

    let totalReceipts = 0;
    form.querySelectorAll("[data-receipt]").forEach((el) => { totalReceipts += num(el); });

    let totalExpenses = 0;
    form.querySelectorAll("[data-expense]").forEach((el) => { totalExpenses += num(el); });

    let countedCash = 0;
    form.querySelectorAll("[data-denom-row]").forEach((row) => {
      const denom = num(row.querySelector("[data-denom]"));
      const qty = num(row.querySelector("[data-denom-qty]"));
      const amount = denom * qty;
      row.querySelector("[data-denom-amount]").textContent = qty ? money(amount) : "—";
      countedCash += amount;
    });

    const final = totalFuel + totalLube - (totalDiscount + totalCredit + totalReceipts + totalExpenses);
    const shortage = final - countedCash;

    const set = (selector, text) => {
      const el = form.querySelector(selector);
      if (el) el.textContent = text;
    };
    set("[data-total-fuel]", money(totalFuel));
    set("[data-total-lube]", money(totalLube));
    set("[data-total-discount]", money(totalDiscount));
    set("[data-total-credit]", money(totalCredit));
    set("[data-total-receipts]", money(totalReceipts));
    set("[data-total-expenses]", money(totalExpenses));
    set("[data-final]", money(final));
    set("[data-counted-cash]", money(countedCash));
    set("[data-shortage]", money(shortage));
  };

  // Rows the FSM can add on the spot: a discount missed at capture (item 11), a
  // digital means we don't seed (item 10), cash taken out (item 12). Each
  // section carries a <template> whose inputs are named here, so the nested
  // attribute index is assigned at the moment the row is added and never
  // collides with a server-rendered one.
  const REPEATABLE_SECTIONS = [
    { section: "[data-settlement-discounts]", trigger: "[data-add-discount]", template: "[data-discount-row-template]", attribute: "discount_lines" },
    { section: "[data-settlement-receipts]", trigger: "[data-add-receipt]", template: "[data-receipt-row-template]", attribute: "digital_receipts" },
    { section: "[data-settlement-expenses]", trigger: "[data-add-expense]", template: "[data-expense-row-template]", attribute: "expense_lines" }
  ];

  // One past the highest index already on the page, so added rows never reuse
  // an index the server rendered.
  const nextRowIndex = (form, attribute) => {
    const pattern = new RegExp(`\\[${attribute}_attributes\\]\\[(\\d+)\\]`);
    const used = Array.from(form.querySelectorAll(`[name*="${attribute}_attributes"]`))
      .map((input) => Number.parseInt(input.name.match(pattern)?.[1] ?? "", 10))
      .filter(Number.isInteger);
    return used.length ? Math.max(...used) + 1 : 0;
  };

  const addRow = (form, { section, template, attribute }) => {
    const host = form.querySelector(section);
    const rowTemplate = host?.querySelector(template);
    const body = host?.querySelector("tbody");
    if (!host || !rowTemplate || !body) return;

    const row = rowTemplate.content.firstElementChild.cloneNode(true);
    const index = nextRowIndex(form, attribute);
    row.querySelectorAll("[data-template-name]").forEach((input) => {
      input.name = `settlement[${attribute}_attributes][${index}][${input.dataset.templateName}]`;
      input.removeAttribute("data-template-name");
    });
    body.appendChild(row);

    // The discounts section starts collapsed when nothing was pulled.
    host.querySelector("[data-discount-table]")?.classList.remove("d-none");
    host.querySelector("[data-discount-empty]")?.classList.add("d-none");

    row.querySelector("input")?.focus();
    recompute(form);
  };

  const init = () => {
    document.querySelectorAll("[data-settlement-form]").forEach((form) => {
      form.addEventListener("input", () => recompute(form));
      form.addEventListener("change", () => recompute(form));
      REPEATABLE_SECTIONS.forEach((config) => {
        form.querySelector(config.trigger)?.addEventListener("click", () => addRow(form, config));
      });
      recompute(form);
    });
  };

  document.addEventListener("DOMContentLoaded", init);
  document.addEventListener("turbo:load", init);
})();
