const money = (n) =>
  new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    minimumFractionDigits: 2,
  }).format(n);

const fixturesURL = new URL("../fixtures.json", import.meta.url);

async function loadFixtures() {
  const res = await fetch(fixturesURL);
  if (!res.ok) throw new Error(`fixtures.json HTTP ${res.status}`);
  return res.json();
}

function stateFromHash() {
  const h = location.hash.replace(/^#/, "") || "home";
  if (h === "settings" || h === "about" || h === "home") return h;
  return "home";
}

function render(app, data, screen, adviceOpen) {
  app.className = `chrome ${screen}`;
  if (screen === "settings") {
    app.innerHTML = settingsView(data);
    wireNav(app);
    return;
  }
  if (screen === "about") {
    app.innerHTML = aboutView(data);
    wireNav(app);
    return;
  }
  app.innerHTML = homeView(data, adviceOpen);
  wireHome(app, data);
}

function homeView(data, adviceOpen) {
  const maxDay = Math.max(...data.dailyCosts);
  const bars = data.dailyCosts
    .map((cost, i) => {
      const h = Math.max(2, Math.round((cost / maxDay) * 72));
      return `<div class="bar-col"><div class="bar" style="height:${h}px" title="${money(cost)}"></div><span class="bar-label">${data.dayLabels[i]}</span></div>`;
    })
    .join("");

  const models = Object.entries(data.modelCosts);
  const maxModel = Math.max(...models.map(([, c]) => c));
  const modelRows = models
    .sort((a, b) => b[1] - a[1])
    .map(
      ([name, cost]) => `
      <div class="model-row">
        <div class="model-head"><span class="model-name">${escapeHtml(name)}</span><span>${money(cost)}</span></div>
        <div class="meter"><span style="width:${(cost / maxModel) * 100}%"></span></div>
      </div>`
    )
    .join("");

  const dailyFrac = Math.min(1, data.todayCost / data.dailyBudgetLimit);
  const monthFrac = Math.min(1, data.budgetSpend / data.budgetLimit);
  const monthWarn = monthFrac >= 0.8;

  return `
    <div class="scroll">
      <div class="caption">今日</div>
      <div class="hero-amount">${money(data.todayCost)}</div>
      <div class="side-caption">Claude ${money(data.claudeTodayCost)} · Cursor ${money(data.cursorTodayCost)}</div>

      <div class="section">
        <div class="budget-row">
          <div class="budget-head"><span>予算 (今日)</span><span>${money(data.todayCost)} / ${money(data.dailyBudgetLimit)}</span></div>
          <div class="meter"><span style="width:${dailyFrac * 100}%"></span></div>
        </div>
        <div class="budget-row">
          <div class="budget-head"><span>予算 (今月)</span><span>${money(data.budgetSpend)} / ${money(data.budgetLimit)}</span></div>
          <div class="meter ${monthWarn ? "warn" : ""}"><span style="width:${monthFrac * 100}%"></span></div>
        </div>
      </div>

      <div class="section">
        <div class="section-title">推移 · ${escapeHtml(data.periodLabel)}</div>
        <div class="bars">${bars}</div>
      </div>

      <div class="section">
        <div class="section-title">モデル別</div>
        ${modelRows}
      </div>

      <div class="section">
        <button type="button" class="disclosure" id="advice-toggle" aria-expanded="${adviceOpen ? "true" : "false"}">
          <div class="disclosure-head">
            <span>節約のヒント</span>
            <span class="chevron">›</span>
          </div>
        </button>
        <div class="advice-body" id="advice-body" ${adviceOpen ? "" : "hidden"}>
          <div class="advice-title">${escapeHtml(data.advice.title)}</div>
          ${escapeHtml(data.advice.detail)}
        </div>
      </div>
    </div>
    <div class="footer">
      <button type="button" class="btn" data-nav="settings">設定</button>
      <button type="button" class="btn" data-nav="about">About</button>
    </div>`;
}

function settingsView(data) {
  const s = data.settings;
  return `
    <div class="scroll">
      <div class="nav-title">設定</div>
      <p class="caption" style="margin:8px 0 16px">フィクスチャ表示のみ。変更は保存されません。</p>
      <ul class="settings-list">
        <li><span>通貨</span><span class="value">${escapeHtml(s.currency)}</span></li>
        <li><span>コストソース</span><span class="value">${escapeHtml(s.costSourceMode)}</span></li>
        <li><span>日次予算</span><span class="value">${money(s.dailyBudget)}</span></li>
        <li><span>月次予算</span><span class="value">${money(s.monthlyBudget)}</span></li>
        <li><span>外観</span><span class="value">${escapeHtml(s.appearance)}</span></li>
      </ul>
    </div>
    <div class="footer">
      <button type="button" class="btn primary" data-nav="home">戻る</button>
    </div>`;
}

function aboutView(data) {
  const a = data.about;
  const credits = a.credits
    .map((c) => `<li><span>${escapeHtml(c)}</span></li>`)
    .join("");
  return `
    <div class="scroll">
      <div class="about-hero">
        <p class="about-name">${escapeHtml(a.name)}</p>
        <p class="caption">${escapeHtml(a.tagline)}</p>
        <p class="caption">Version ${escapeHtml(a.version)}</p>
      </div>
      <ul class="about-list">${credits}</ul>
    </div>
    <div class="footer">
      <button type="button" class="btn primary" data-nav="home">戻る</button>
    </div>`;
}

function wireNav(app) {
  app.querySelectorAll("[data-nav]").forEach((el) => {
    el.addEventListener("click", () => {
      location.hash = el.getAttribute("data-nav");
    });
  });
}

function wireHome(app, data) {
  wireNav(app);
  const toggle = app.querySelector("#advice-toggle");
  const body = app.querySelector("#advice-body");
  toggle?.addEventListener("click", () => {
    const open = toggle.getAttribute("aria-expanded") !== "true";
    toggle.setAttribute("aria-expanded", open ? "true" : "false");
    body.hidden = !open;
  });
}

function escapeHtml(s) {
  return String(s)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

const app = document.getElementById("app");
let fixtures = null;

loadFixtures()
  .then((data) => {
    fixtures = data;
    const redraw = () => render(app, fixtures, stateFromHash(), false);
    window.addEventListener("hashchange", redraw);
    redraw();
  })
  .catch((err) => {
    app.innerHTML = `<div class="loading">Failed to load fixtures: ${escapeHtml(err.message)}</div>`;
  });
