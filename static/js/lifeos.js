(() => {
  const choices = new Set(["system", "light", "dark"]);
  const root = document.documentElement;

  function storedTheme() {
    try {
      const value = localStorage.getItem("lifeos-theme");
      return choices.has(value) ? value : "system";
    } catch (_) {
      return "system";
    }
  }

  function applyTheme(theme) {
    const selected = choices.has(theme) ? theme : "system";
    if (selected === "system") root.removeAttribute("data-theme");
    else root.setAttribute("data-theme", selected);
    document.querySelectorAll("[data-theme-choice]").forEach((button) => {
      button.setAttribute("aria-pressed", String(button.dataset.themeChoice === selected));
    });
    try {
      localStorage.setItem("lifeos-theme", selected);
    } catch (_) {
      // System preference remains a complete fallback.
    }
  }

  document.querySelectorAll("[data-theme-choice]").forEach((button) => {
    button.addEventListener("click", () => applyTheme(button.dataset.themeChoice));
  });
  applyTheme(storedTheme());

  const errors = document.querySelector(".shift-inspector .error-summary");
  const heading = document.querySelector("#shift-inspector-heading");
  const focusTarget = errors || (location.hash === "#shift-inspector" ? heading : null);
  if (focusTarget) {
    focusTarget.setAttribute("tabindex", "-1");
    focusTarget.focus();
  }
})();
