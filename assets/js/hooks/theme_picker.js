const ThemePicker = {
  mounted() {
    this.picker = this.el.querySelector('[data-theme-picker]');
    this.toggle = this.el.querySelector('[data-theme-picker-toggle]');
    const isOpen = () => getComputedStyle(this.picker).display !== 'none';
    this.onKeyUp = (event) => {
      if (event.target.closest('input, textarea, select, [contenteditable="true"]')) return;
      if (event.metaKey || event.ctrlKey || event.altKey) return;
      if (event.key === 't' || (event.key === 'Escape' && isOpen())) {
        this.toggle.click();
        return;
      }
      if (!isOpen()) return;
      const theme = this.el.querySelector(`[data-theme-key="${CSS.escape(event.key)}"]`);
      if (theme) theme.click();
    };
    window.addEventListener('keyup', this.onKeyUp);
  },
  destroyed() {
    window.removeEventListener('keyup', this.onKeyUp);
  },
};
export default ThemePicker;
