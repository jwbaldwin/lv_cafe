export default {
  mounted() {
    this.toggle = this.el.querySelector("#feedback-toggle");
    this.onKey = event => {
      // Keep player and timer window shortcuts out of the text composer.
      event.stopPropagation();
      if (event.type === "keydown" && event.key === "Escape") {
        const close = this.el.querySelector("[data-feedback-close]");
        if (close) { event.preventDefault(); close.click(); this.toggle.focus(); }
      }
    };
    this.onShortcut = event => {
      if (event.key !== "f" || event.repeat || event.isComposing || event.metaKey || event.ctrlKey || event.altKey) return;
      if (event.target.closest('input, textarea, select, [contenteditable]')) return;
      const picker = document.querySelector('[data-theme-picker]');
      if (picker && getComputedStyle(picker).display !== 'none') return;
      event.preventDefault();
      this.toggle.click();
    };
    this.onInput = () => {
      const input = this.el.querySelector("textarea");
      const count = this.el.querySelector("output");
      if (input && count) count.textContent = input.value.length + "/255";
    };
    this.el.addEventListener("keydown", this.onKey);
    this.el.addEventListener("keyup", this.onKey);
    this.el.addEventListener("input", this.onInput);
    window.addEventListener("keydown", this.onShortcut);
    this.updated();
  },
  updated() {
    const input = this.el.querySelector("textarea");
    if (input && !this.input) input.focus();
    this.input = input;
    this.onInput();
  },
  destroyed() {
    this.el.removeEventListener("keydown", this.onKey);
    this.el.removeEventListener("keyup", this.onKey);
    this.el.removeEventListener("input", this.onInput);
    window.removeEventListener("keydown", this.onShortcut);
  }
};
