import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { runInNewContext } from 'node:vm';

const app = await readFile(new URL('../../assets/js/app.js', import.meta.url), 'utf8');
const source = await readFile(new URL('../../assets/js/hooks/station_selection.js', import.meta.url), 'utf8');
const {default: StationSelection} = await import('data:text/javascript;base64,' + Buffer.from(source).toString('base64'));

test('reconnecting uses the latest station saved by the selection hook', () => {
  const storage = new Map([['station_id', '1']]);
  globalThis.localStorage = {
    getItem: key => storage.get(key) ?? null,
    setItem: (key, value) => storage.set(key, value),
  };
  const window = {addEventListener() {}};
  const handlers = new Map();
  StationSelection.mounted.call({handleEvent: (event, callback) => handlers.set(event, callback)});
  runInNewContext(app.replace(/^import .*;$/gm, ''), {
    window, localStorage,
    document: {querySelector: () => ({getAttribute: () => 'csrf'}), addEventListener() {}},
    LiveSocket: class {constructor(_url, _socket, options) {this.options = options;} connect() {}},
    Socket: {}, topbar: {config() {}},
    StationSelection, StationPicker: {}, YouTubePlayer: {}, AdminPreview: {}, FeedbackWidget: {},
  });
  assert.equal(window.liveSocket.options.params().station_id, '1');
  handlers.get('store_station')({station_id: '42'});
  assert.equal(window.liveSocket.options.params().station_id, '42');
  assert.equal(window.liveSocket.options.params()._csrf_token, 'csrf');
  delete globalThis.localStorage;
});
