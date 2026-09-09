import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const source = await readFile(new URL('../../assets/js/hooks/feedback_widget.js', import.meta.url), 'utf8');
const {default: hook} = await import('data:text/javascript;base64,' + Buffer.from(source).toString('base64'));

function setup() {
  let clicks = 0, focused = 0, pickerOpen = false, input = null;
  const listeners = new Map();
  const counter = {};
  const toggle = {click() {clicks++;}, focus() {focused++;}};
  globalThis.window = {addEventListener: (key, fn) => listeners.set(key, fn), removeEventListener: key => listeners.delete(key)};
  globalThis.document = {querySelector: () => ({})};
  globalThis.getComputedStyle = () => ({display: pickerOpen ? 'block' : 'none'});
  const instance = {...hook, el: {
    querySelector: selector => selector === 'textarea' ? input : selector === 'output' ? counter : toggle,
    addEventListener() {}, removeEventListener() {},
  }};
  instance.mounted();
  return {instance, counter, listeners, clicks: () => clicks, focused: () => focused,
    openPicker() {pickerOpen = true;},
    openInput() {input = {value: 'coffee', focus() {focused++;}}; instance.updated();},
  };
}

test('f opens feedback but preserves typing, browser shortcuts, and theme picker focus', () => {
  const t = setup();
  const event = {key: 'f', target: {closest: () => null}, preventDefault() {}};
  t.instance.onShortcut(event);
  assert.equal(t.clicks(), 1);
  for (const extra of [{ctrlKey:true}, {metaKey:true}, {altKey:true}, {repeat:true}, {isComposing:true}, {target:{closest:()=>({})}}]) {
    t.instance.onShortcut({...event, ...extra});
  }
  t.openPicker(); t.instance.onShortcut(event);
  assert.equal(t.clicks(), 1);
  t.instance.destroyed(); assert.equal(t.listeners.size, 0);
});

test('opening focuses the composer once, updates its counter, and Escape returns focus', () => {
  const t = setup(); t.openInput(); t.instance.updated();
  assert.equal(t.focused(), 1);
  assert.equal(t.counter.textContent, '6/255');
  let stopped = false;
  t.instance.onKey({type:'keydown', key:'Escape', stopPropagation() {stopped = true;}, preventDefault() {}});
  assert.ok(stopped); assert.equal(t.clicks(), 1); assert.equal(t.focused(), 2);
});
