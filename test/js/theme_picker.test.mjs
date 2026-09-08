import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
const source = await readFile(new URL('../../assets/js/hooks/theme_picker.js', import.meta.url), 'utf8');
const { default: hook, nextGridIndex } = await import('data:text/javascript;base64,' + Buffer.from(source).toString('base64'));

test('hjkl follows the responsive grid and does not wrap row edges', () => {
  for (const columns of [2, 3, 5]) {
    assert.equal(nextGridIndex(0, 'j', columns, 10), columns);
    assert.equal(nextGridIndex(columns, 'k', columns, 10), 0);
    assert.equal(nextGridIndex(0, 'h', columns, 10), 0);
    assert.equal(nextGridIndex(columns - 1, 'l', columns, 10), columns - 1);
    assert.equal(nextGridIndex(0, 'k', columns, 10), 0);
    assert.equal(nextGridIndex(9, 'j', columns, 10), 9);
    assert.equal(nextGridIndex(9, 'l', columns, 10), 9);
    assert.equal(nextGridIndex(1, 'h', columns, 10), 0);
    assert.equal(nextGridIndex(0, 'l', columns, 10), 1);
  }
  assert.equal(nextGridIndex(8, 'j', 3, 10), 9);
});

function setup() {
  let clicks = 0, open = true;
  const listeners = new Map();
  const tiles = Array.from({ length: 10 }, (_, index) => ({
    offsetTop: Math.floor(index / 5) * 150,
    focus() { document.activeElement = this; },
    scrollIntoView() {}, click() { clicks++; },
  }));
  const picker = {
    querySelectorAll: () => tiles, querySelector: () => tiles[3],
    addEventListener: (event, callback) => listeners.set(event, callback),
    removeEventListener: event => listeners.delete(event),
  };
  const toggle = { focus() { document.activeElement = this; }, click() {open = !open;} };
  globalThis.document = { activeElement: toggle };
  globalThis.window = {
    addEventListener: (event, callback) => listeners.set(event, callback),
    removeEventListener: event => listeners.delete(event),
  };
  globalThis.getComputedStyle = () => ({ display: open ? 'block' : 'none' });
  const instance = {...hook, el: {querySelector: selector => selector === '[data-theme-picker]' ? picker : toggle}};
  instance.mounted();
  const key = (key, extra = {}) => {
    const event = {key, target:{closest:()=>null}, preventDefault(){this.prevented=true;}, stopImmediatePropagation(){this.stopped=true;}, ...extra};
    instance.onKeyDown(event);
    return event;
  };
  return {instance, tiles, toggle, key, listeners, clicks:()=>clicks};
}

test('opening focuses the current vibe; closing returns focus to the toggle', () => {
  const t = setup();t.instance.onShow();assert.equal(document.activeElement, t.tiles[3]);
  t.key('j');assert.equal(document.activeElement, t.tiles[8]);
  t.instance.onHide();assert.equal(document.activeElement, t.toggle);
  t.instance.destroyed();assert.equal(t.listeners.size, 0);
});

test('Space and Enter select once and stop the global playback shortcut', () => {
  const t = setup();t.instance.onShow();
  for (const key of [' ', 'Enter']) {
    const event = t.key(key);assert.ok(event.prevented);assert.ok(event.stopped);
    t.key(key, {repeat:true});
  }
  assert.equal(t.clicks(), 2);
  t.instance.destroyed();
});

test('closed picker and editable fields keep their normal keyboard behavior', () => {
  const t = setup();
  assert.equal(t.key(' ', {target:{closest:()=>({})}}).prevented, undefined);
  assert.equal(t.key('h', {metaKey:true}).prevented, undefined);
  t.toggle.click();assert.equal(t.key(' ').prevented, undefined);
  t.instance.destroyed();
});
