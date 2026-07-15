import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
const source = await readFile(new URL('../../assets/js/hooks/youtube_player.js', import.meta.url), 'utf8');
const { default: hook } = await import('data:text/javascript;base64,' + Buffer.from(source).toString('base64'));

function setup() {
  const calls = [], events = [], handlers = {};
  let config;
  const player = {
    getVideoData: () => ({ video_id: instance.currentVideoId, title: 'Test video' }),
    getPlayerState: () => player.state,
    isMuted: () => instance.muted,
    setVolume: v => calls.push(['volume',v]), mute: () => calls.push(['mute']), unMute: () => calls.push(['unmute']),
    loadVideoById: id => calls.push(['load',id]), cueVideoById: id => calls.push(['cue',id]),
    playVideo: () => calls.push(['play']), pauseVideo: () => calls.push(['pause']), destroy() {},
  };
  globalThis.document = { addEventListener() {}, removeEventListener() {} };
  globalThis.window = { location: {origin:'http://localhost'}, YT: { Player: function(id, options) {config=options;return player;} } };
  const instance = {...hook, el:{dataset:{videoId:'abcdefghijk'}}, pushEvent:(name,data)=>events.push([name,data]), handleEvent:(name,handler)=>handlers[name]=handler};
  instance.mounted();
  const ready = () => config.events.onReady();
  const state = data => {player.state=data;config.events.onStateChange({data,target:player});};
  return {instance,calls,events,handlers,ready,state,config,player};
}

test('queues the latest station until the iframe is ready', () => {
  const t=setup();
  try {
    t.handlers.changeVideo({video_id:'newvideo123',volume:20});
    assert.equal(t.calls.length,0);
    t.player.getVideoData=()=>({video_id:'abcdefghijk'});
    t.ready();
    assert.ok(t.calls.some(c=>c[0]==='load'&&c[1]==='newvideo123'));
  } finally {t.instance.destroyed();}
});
test('blocked audible autoplay falls back to muted playback once', () => {
  const t=setup();
  try {
    t.ready();t.config.events.onAutoplayBlocked();
    assert.equal(t.instance.muted,true);
    assert.deepEqual(t.calls.slice(-2),[['mute'],['play']]);
    t.config.events.onAutoplayBlocked();
    assert.equal(t.instance.loading,false);
    assert.equal(t.events.at(-1)[1].playing,false);
    t.instance.act('toggle');
    assert.deepEqual(t.calls.at(-1),['play']);
  } finally {t.instance.destroyed();}
});
test('a paused video resumes with one click and paused station changes stay paused', () => {
  const t=setup();
  try {
    t.ready();t.state(1);t.instance.act('toggle');
    assert.deepEqual(t.calls.at(-1),['pause']);
    t.handlers.changeVideo({video_id:'newvideo123',volume:50});
    assert.deepEqual(t.calls.at(-1),['cue','newvideo123']);
    t.instance.act('toggle');
    assert.deepEqual(t.calls.at(-1),['play']);
  } finally {t.instance.destroyed();}
});
test('volume and mute act immediately and survive station changes', () => {
  const t=setup();
  try {
    t.ready();t.instance.act('volume',30);t.instance.act('mute');
    t.handlers.changeVideo({video_id:'newvideo123',volume:30});
    assert.equal(t.instance.volume,30);assert.equal(t.instance.muted,true);
    assert.ok(t.calls.some(c=>c[0]==='volume'&&c[1]===30));
  } finally {t.instance.destroyed();}
});
test('private videos report once, including when YouTube retains old metadata', () => {
  const t=setup();
  try {
    t.ready();t.config.events.onError({data:100,target:t.player});
    t.config.events.onError({data:100,target:t.player});
    assert.equal(t.events.filter(e=>e[0]==='player_error').length,1);
    t.handlers.changeVideo({video_id:'newvideo123',volume:50});
    t.player.getVideoData=()=>({video_id:'abcdefghijk'});
    t.config.events.onError({data:100,target:t.player});
    assert.equal(t.events.filter(e=>e[0]==='player_error').length,2);
    assert.equal(t.events.at(-1)[1].video_id,'newvideo123');
  } finally {t.instance.destroyed();}
});
test('actual playback events update the icon and advance ended videos', () => {
  const t=setup();
  try {
    t.ready();t.state(1);assert.equal(t.events.at(-1)[1].playing,true);
    t.state(2);assert.equal(t.events.at(-1)[1].playing,false);
    t.state(0);assert.equal(t.events.at(-1)[0],'player_ended');
  } finally {t.instance.destroyed();}
});
test('pressing play during initial loading does not accidentally pause', () => {
  const t=setup();
  try {t.ready();t.instance.act('toggle');assert.deepEqual(t.calls.at(-1),['play']);}
  finally {t.instance.destroyed();}
});
test('metadata arriving after a playing event is reconciled', () => {
  const t=setup();
  try {
    t.ready();t.player.getVideoData=()=>({video_id:'oldvideo123',title:'Old'});t.state(1);
    assert.equal(t.instance.isPlaying,false);
    t.player.getVideoData=()=>({video_id:t.instance.currentVideoId,title:'Current'});
    t.instance.syncPlayback();
    assert.equal(t.instance.isPlaying,true);
    assert.equal(t.events.find(e=>e[0]==='player_ready')[1].title,'Current');
  } finally {t.instance.destroyed();}
});
