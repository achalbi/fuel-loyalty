// Daily Settlement — client-side live totals for FSM feedback only. The server
// (Settlement::Calculator) recomputes every derived ₹ on submit and is the sole
// source of truth; this only mirrors the arithmetic so the form feels live.
(() => {
  const num = (el) => {
    if (!el) return 0;
    const raw = el.dataset ? el.value : el.textContent;
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

    const phonepe = num(form.querySelector("[data-phonepe-pos]")) + num(form.querySelector("[data-phonepe-scanner]"));

    let countedCash = 0;
    form.querySelectorAll("[data-denom-row]").forEach((row) => {
      const denom = num(row.querySelector("[data-denom]"));
      const qty = num(row.querySelector("[data-denom-qty]"));
      const amount = denom * qty;
      row.querySelector("[data-denom-amount]").textContent = qty ? money(amount) : "—";
      countedCash += amount;
    });

    const final = totalFuel + totalLube - (totalDiscount + totalCredit + phonepe);
    const shortage = final - countedCash;

    const set = (selector, text) => {
      const el = form.querySelector(selector);
      if (el) el.textContent = text;
    };
    set("[data-total-fuel]", money(totalFuel));
    set("[data-total-lube]", money(totalLube));
    set("[data-total-discount]", money(totalDiscount));
    set("[data-total-credit]", money(totalCredit));
    set("[data-total-phonepe]", money(phonepe));
    set("[data-final]", money(final));
    set("[data-counted-cash]", money(countedCash));
    set("[data-shortage]", money(shortage));
  };

  const init = () => {
    document.querySelectorAll("[data-settlement-form]").forEach((form) => {
      form.addEventListener("input", () => recompute(form));
      form.addEventListener("change", () => recompute(form));
      recompute(form);
    });
  };

  document.addEventListener("DOMContentLoaded", init);
  document.addEventListener("turbo:load", init);
})();
