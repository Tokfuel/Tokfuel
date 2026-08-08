/**
 * Sticky chrome helpers: live GitHub star count + inline nav docs search.
 * Expects `sitePath` prefix /Tokfuel on GitHub Pages.
 */
(function () {
  "use strict";

  var SITE_PATH = "/Tokfuel";
  var REPO = "Tokfuel/Tokfuel";
  var STAR_CACHE_KEY = "tf-github-repo-stats-v1";
  var STAR_CACHE_MS = 6 * 60 * 60 * 1000;

  function formatCount(n) {
    if (typeof n !== "number" || !isFinite(n)) return "—";
    if (n < 1000) return String(n);
    if (n < 10000) return (n / 1000).toFixed(1).replace(/\.0$/, "") + "k";
    return Math.round(n / 1000) + "k";
  }

  function applyRepoStats(stars, forks) {
    var starNodes = document.querySelectorAll(".tf-star-count");
    var forkNodes = document.querySelectorAll(".tf-fork-count");
    var starText = formatCount(stars);
    var forkText = formatCount(forks);
    for (var i = 0; i < starNodes.length; i++) starNodes[i].textContent = starText;
    for (var j = 0; j < forkNodes.length; j++) forkNodes[j].textContent = forkText;
  }

  function loadRepoStats() {
    try {
      var cached = JSON.parse(localStorage.getItem(STAR_CACHE_KEY) || "null");
      if (
        cached &&
        typeof cached.stars === "number" &&
        typeof cached.forks === "number" &&
        Date.now() - cached.at < STAR_CACHE_MS
      ) {
        applyRepoStats(cached.stars, cached.forks);
        return;
      }
    } catch (_) {}

    fetch("https://api.github.com/repos/" + REPO, {
      headers: { Accept: "application/vnd.github+json" },
    })
      .then(function (r) {
        if (!r.ok) throw new Error("HTTP " + r.status);
        return r.json();
      })
      .then(function (data) {
        var stars = data.stargazers_count;
        var forks = data.forks_count;
        applyRepoStats(stars, forks);
        try {
          localStorage.setItem(
            STAR_CACHE_KEY,
            JSON.stringify({ stars: stars, forks: forks, at: Date.now() })
          );
        } catch (_) {}
      })
      .catch(function () {
        /* leave em dashes */
      });
  }

  var indexPromise = null;
  function loadIndex() {
    if (!indexPromise) {
      indexPromise = fetch(SITE_PATH + "/js/search-index.json")
        .then(function (r) {
          if (!r.ok) throw new Error("HTTP " + r.status);
          return r.json();
        })
        .catch(function () {
          return [];
        });
    }
    return indexPromise;
  }

  function normalize(s) {
    return String(s || "")
      .toLowerCase()
      .normalize("NFKC");
  }

  function scoreEntry(entry, q) {
    var title = normalize(entry.title);
    var desc = normalize(entry.description);
    var keywords = normalize((entry.keywords || []).join(" "));
    if (title === q) return 100;
    if (title.indexOf(q) === 0) return 80;
    if (title.indexOf(q) !== -1) return 60;
    if (keywords.indexOf(q) !== -1) return 40;
    if (desc.indexOf(q) !== -1) return 20;
    return 0;
  }

  function escapeHtml(s) {
    return String(s)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function showPanel(panel) {
    panel.hidden = false;
    panel.removeAttribute("hidden");
    panel.setAttribute("aria-hidden", "false");
  }

  function hidePanel(panel) {
    panel.hidden = true;
    panel.setAttribute("hidden", "hidden");
    panel.setAttribute("aria-hidden", "true");
  }

  function positionPanel(panel, input) {
    var rect = input.getBoundingClientRect();
    var width = Math.max(280, Math.min(360, window.innerWidth - 24));
    var left = Math.min(rect.left, window.innerWidth - width - 12);
    if (left < 12) left = 12;
    panel.style.top = Math.round(rect.bottom + 8) + "px";
    panel.style.left = Math.round(left) + "px";
    panel.style.width = Math.round(width) + "px";
  }

  function renderResults(panel, entries, q) {
    if (!q) {
      panel.innerHTML =
        '<p class="tf-search-empty">Type to search docs.</p>';
      return;
    }

    var ranked = entries
      .map(function (e) {
        return { entry: e, score: scoreEntry(e, q) };
      })
      .filter(function (x) {
        return x.score > 0;
      })
      .sort(function (a, b) {
        return b.score - a.score;
      })
      .slice(0, 12);

    if (!ranked.length) {
      panel.innerHTML = '<p class="tf-search-empty">No matching documents.</p>';
      return;
    }

    var html = '<ul class="tf-search-list">';
    for (var i = 0; i < ranked.length; i++) {
      var e = ranked[i].entry;
      html +=
        '<li><a href="' +
        SITE_PATH +
        e.path +
        '"><span class="tf-search-title">' +
        escapeHtml(e.title) +
        '</span><span class="tf-search-desc">' +
        escapeHtml(e.description || "") +
        "</span></a></li>";
    }
    html += "</ul>";
    panel.innerHTML = html;
  }

  function currentTheme() {
    return document.documentElement.getAttribute("data-bs-theme") || "tokfuel-light";
  }

  function toggleTheme() {
    if (typeof igniteSwitchTheme !== "function") return;
    var next = currentTheme() === "tokfuel-dark" ? "tokfuel-light" : "tokfuel-dark";
    igniteSwitchTheme(next);
    refreshThemeIcon();
  }

  var ICON_LANGUAGE =
    '<svg class="tf-nav-icon" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="m12.87 15.07-2.54-2.51.03-.03A17.5 17.5 0 0 0 14.07 6H17V4h-7V2H8v2H1v2h11.17C11.5 7.92 10.44 9.75 9 11.35 8.07 10.32 7.3 9.19 6.69 8h-2c.73 1.63 1.73 3.17 2.98 4.56l-5.09 5.02L4 19l5-5 3.11 3.11zM18.5 10h-2L12 22h2l1.12-3h4.75L21 22h2zm-2.62 7 1.62-4.33L19.12 17z"/></svg>';
  var ICON_SUN =
    '<svg class="tf-nav-icon" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M12 7a5 5 0 0 1 5 5 5 5 0 0 1-5 5 5 5 0 0 1-5-5 5 5 0 0 1 5-5m0 2a3 3 0 0 0-3 3 3 3 0 0 0 3 3 3 3 0 0 0 3-3 3 3 0 0 0-3-3m0-7 2.39 3.42C13.65 5.15 12.84 5 12 5s-1.65.15-2.39.42zM3.34 7l4.16-.35A7.2 7.2 0 0 0 5.94 8.5c-.44.74-.69 1.5-.83 2.29zm.02 10 1.76-3.77a7.13 7.13 0 0 0 2.38 4.14zM20.65 7l-1.77 3.79a7.02 7.02 0 0 0-2.38-4.15zm-.01 10-4.14.36c.59-.51 1.12-1.14 1.54-1.86.42-.73.69-1.5.83-2.29zM12 22l-2.41-3.44c.74.27 1.55.44 2.41.44.82 0 1.63-.17 2.37-.44z"/></svg>';
  var ICON_MOON =
    '<svg class="tf-nav-icon" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="m17.75 4.09-2.53 1.94.91 3.06-2.63-1.81-2.63 1.81.91-3.06-2.53-1.94L12.44 4l1.06-3 1.06 3zm3.5 6.91-1.64 1.25.59 1.98-1.7-1.17-1.7 1.17.59-1.98L15.75 11l2.06-.05L18.5 9l.69 1.95zm-2.28 4.95c.83-.08 1.72 1.1 1.19 1.85-.32.45-.66.87-1.08 1.27C15.17 23 8.84 23 4.94 19.07c-3.91-3.9-3.91-10.24 0-14.14.4-.4.82-.76 1.27-1.08.75-.53 1.93.36 1.85 1.19-.27 2.86.69 5.83 2.89 8.02a9.96 9.96 0 0 0 8.02 2.89m-1.64 2.02a12.08 12.08 0 0 1-7.8-3.47c-2.17-2.19-3.33-5-3.49-7.82-2.81 3.14-2.7 7.96.31 10.98 3.02 3.01 7.84 3.12 10.98.31"/></svg>';

  function navLinkByLabel(label) {
    var links = document.querySelectorAll(".tf-chrome .nav-link");
    for (var i = 0; i < links.length; i++) {
      var text = (links[i].textContent || "").replace(/\s+/g, " ").trim();
      if (text === label) return links[i];
    }
    return null;
  }

  function enhanceLanguageIcon() {
    var el = navLinkByLabel("Language");
    if (!el) return;
    var toJa = el.getAttribute("href") || "";
    var switchesToJa = /\/ja(\/|$)/.test(toJa);
    el.innerHTML = ICON_LANGUAGE;
    el.setAttribute("aria-label", switchesToJa ? "Switch to Japanese" : "Switch to English");
    el.setAttribute("title", switchesToJa ? "日本語" : "English");
    el.classList.add("tf-nav-icon-link");
  }

  function refreshThemeIcon() {
    var el = document.querySelector(".tf-chrome .nav-link.tf-theme-toggle");
    if (!el) {
      el = navLinkByLabel("Theme");
      if (!el) return;
      el.classList.add("tf-theme-toggle", "tf-nav-icon-link");
      el.addEventListener("click", function (ev) {
        ev.preventDefault();
        toggleTheme();
      });
    }
    var dark = currentTheme() === "tokfuel-dark";
    el.innerHTML = dark ? ICON_SUN : ICON_MOON;
    el.setAttribute("aria-label", dark ? "Switch to light mode" : "Switch to dark mode");
    el.setAttribute("title", dark ? "Light" : "Dark");
  }

  function wireChromeActions() {
    enhanceLanguageIcon();
    refreshThemeIcon();
  }

  function wireSearch() {
    var input = document.getElementById("tf-search-input");
    var panel = document.getElementById("tf-search-results");
    if (!input || !panel) return;

    var form = input.closest("form");
    if (form) {
      form.classList.add("tf-nav-search");
      form.setAttribute("role", "search");
      form.addEventListener("submit", function (ev) {
        ev.preventDefault();
        var first = panel.querySelector(".tf-search-list a");
        if (first) first.click();
      });
    }

    var entries = [];
    loadIndex().then(function (data) {
      entries = Array.isArray(data) ? data : [];
    });

    function update() {
      var q = normalize(input.value).trim();
      renderResults(panel, entries, q);
      positionPanel(panel, input);
      if (q || document.activeElement === input) {
        showPanel(panel);
      } else {
        hidePanel(panel);
      }
    }

    input.setAttribute("autocomplete", "off");
    input.setAttribute("autocapitalize", "off");
    input.setAttribute("spellcheck", "false");
    input.setAttribute("aria-autocomplete", "list");
    input.setAttribute("aria-controls", "tf-search-results");

    input.addEventListener("focus", update);
    input.addEventListener("input", update);
    input.addEventListener("keydown", function (ev) {
      if (ev.key === "Escape") {
        hidePanel(panel);
        input.blur();
      } else if (ev.key === "Enter") {
        var first = panel.querySelector(".tf-search-list a");
        if (first) {
          ev.preventDefault();
          first.click();
        }
      }
    });

    document.addEventListener("click", function (ev) {
      if (panel.hidden) return;
      if (panel.contains(ev.target) || input.contains(ev.target)) return;
      hidePanel(panel);
    });

    window.addEventListener("resize", function () {
      if (!panel.hidden) positionPanel(panel, input);
    });

    // Slash focuses the nav search field.
    document.addEventListener("keydown", function (ev) {
      if (ev.key !== "/" || ev.metaKey || ev.ctrlKey || ev.altKey) return;
      var t = ev.target;
      var tag = t && t.tagName;
      if (tag === "INPUT" || tag === "TEXTAREA" || (t && t.isContentEditable)) return;
      ev.preventDefault();
      input.focus();
      input.select();
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", function () {
      loadRepoStats();
      wireChromeActions();
      wireSearch();
    });
  } else {
    loadRepoStats();
    wireChromeActions();
    wireSearch();
  }
})();
