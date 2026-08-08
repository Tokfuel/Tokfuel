/* Apply BudouX (budoux-ja) to Japanese doc body copy after the custom element loads. */
(function () {
  function applyBudoux(root) {
    if (!root) {
      return;
    }
    var nodes = root.querySelectorAll("p, li, h1, h2, h3, h4, h5, h6, td, th");
    for (var i = 0; i < nodes.length; i++) {
      var el = nodes[i];
      if (el.closest("pre, code, script, style, budoux-ja")) {
        continue;
      }
      if (el.querySelector("budoux-ja")) {
        continue;
      }
      var text = (el.textContent || "").replace(/\s+/g, "");
      if (!text) {
        continue;
      }
      // Skip nodes that are mostly Latin (code labels, English-only lines).
      var cjk = (text.match(/[\u3000-\u9fff\uff00-\uffef]/g) || []).join("").length;
      if (cjk < 2) {
        continue;
      }
      var wrap = document.createElement("budoux-ja");
      while (el.firstChild) {
        wrap.appendChild(el.firstChild);
      }
      el.appendChild(wrap);
    }
  }

  function run() {
    var root =
      document.querySelector('[data-budoux-root="true"]') ||
      document.querySelector("main") ||
      document.body;
    applyBudoux(root);
  }

  function whenReady(fn) {
    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", fn);
    } else {
      fn();
    }
  }

  whenReady(function () {
    if (window.customElements && customElements.whenDefined) {
      customElements.whenDefined("budoux-ja").then(run);
    } else {
      run();
    }
  });
})();
