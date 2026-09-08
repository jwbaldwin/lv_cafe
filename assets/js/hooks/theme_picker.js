export function nextGridIndex(index, key, columns, count) {
  const row = Math.floor(index / columns);
  if (key === 'h') return index % columns > 0 ? index - 1 : index;
  if (key === 'l') return index % columns < columns - 1 ? Math.min(index + 1, count - 1) : index;
  if (key === 'k') return row > 0 ? index - columns : index;
  if (key === 'j') return (row + 1) * columns < count ? Math.min(index + columns, count - 1) : index;
  return index;
}

const ThemePicker = {
  mounted() {
    this.picker = this.el.querySelector('[data-theme-picker]');
    this.toggle = this.el.querySelector('[data-theme-picker-toggle]');
    const isOpen = () => getComputedStyle(this.picker).display !== 'none';
    const choices = () => [...this.picker.querySelectorAll('[data-theme-key]')];
    const selected = () => this.picker.querySelector('[data-theme-selected="true"]') || choices()[0];
    const focus = (choice) => {
      choice.focus({ preventScroll: true });
      choice.scrollIntoView({ block: 'nearest', inline: 'nearest' });
    };
    this.onShow = () => focus(selected());
    this.onHide = () => this.toggle.focus({ preventScroll: true });
    this.picker.addEventListener('phx:show-end', this.onShow);
    this.picker.addEventListener('phx:hide-end', this.onHide);

    // Capture selection before the document's global Space-to-play handler.
    this.onKeyDown = (event) => {
      if (!isOpen() || event.metaKey || event.ctrlKey || event.altKey) return;
      if (event.target.closest('input, textarea, select, [contenteditable="true"]')) return;
      if (!['h', 'j', 'k', 'l', 'Enter', ' '].includes(event.key)) return;
      event.preventDefault();
      event.stopImmediatePropagation();
      const tiles = choices();
      const current = tiles.includes(document.activeElement) ? document.activeElement : selected();
      if (event.key === 'Enter' || event.key === ' ') {
        if (!event.repeat) current.click();
        return;
      }
      const columns = tiles.filter(tile => tile.offsetTop === tiles[0].offsetTop).length;
      focus(tiles[nextGridIndex(tiles.indexOf(current), event.key, columns, tiles.length)]);
    };
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
    window.addEventListener('keydown', this.onKeyDown, true);
    window.addEventListener('keyup', this.onKeyUp);
  },
  destroyed() {
    this.picker.removeEventListener('phx:show-end', this.onShow);
    this.picker.removeEventListener('phx:hide-end', this.onHide);
    window.removeEventListener('keydown', this.onKeyDown, true);
    window.removeEventListener('keyup', this.onKeyUp);
  },
};
export default ThemePicker;
