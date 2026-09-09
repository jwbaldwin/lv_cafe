const playbackKeys = { ' ': 'toggle', m: 'mute', ArrowUp: 'louder', ArrowDown: 'quieter' };

const YouTubePlayer = {
  mounted() {
    this.currentVideoId = this.el.dataset.videoId;
    this.startSeconds = Number(this.el.dataset.startSeconds || 0);
    this.volume = 50;
    this.muted = false;
    this.wantsToPlay = true;
    this.isPlaying = false;
    this.isReady = false;
    this.loading = true;
    this.disposed = false;

    // Handle playback in the user gesture, before a server round trip can lose it.
    this.onClick = (event) => {
      const control = event.target.closest('[data-player-action]');
      if (!control) return;
      event.preventDefault();
      this.act(control.dataset.playerAction, Number(control.dataset.volume));
    };
    this.onKeyDown = (event) => {
      if (event.target.closest('input, textarea, select, [contenteditable="true"]')) return;
      if (event.metaKey || event.ctrlKey || event.altKey) return;
      const action = playbackKeys[event.key];
      if (!action) return;
      event.preventDefault();
      if (!event.repeat || action === 'louder' || action === 'quieter') this.act(action);
    };
    document.addEventListener('click', this.onClick);
    document.addEventListener('keydown', this.onKeyDown);

    this.handleEvent('changeVideo', ({ video_id, start_seconds = 0, volume }) => {
      this.currentVideoId = video_id;
      this.startSeconds = start_seconds;
      this.volume = volume;
      this.failed = false;
      this.isPlaying = false;
      this.loading = this.wantsToPlay;
      if (this.isReady) this.loadVideo();
    });
    this.handleEvent('playerUnavailable', () => {
      clearTimeout(this.loadTimeout);
      this.loading = false;
      this.isPlaying = false;
      this.failed = true;
      this.reportState();
    });

    this.apiReady = () => { if (!this.disposed && !this.player) this.initPlayer(); };
    if (window.YT?.Player) this.apiReady();
    else {
      window.onYouTubeIframeAPIReady = this.apiReady;
      if (!document.getElementById('youtube-iframe-api')) {
        const script = document.createElement('script');
        script.id = 'youtube-iframe-api';
        script.src = 'https://www.youtube.com/iframe_api';
        script.async = true;
        document.head.appendChild(script);
      }
    }
    this.watchLoading();
  },

  initPlayer() {
    this.player = new window.YT.Player('youtube-player', {
      width: '100%', height: '100%', videoId: this.currentVideoId,
      playerVars: { start: this.startSeconds, autoplay: 1, mute: 0, controls: 0, playsinline: 1, rel: 0, disablekb: 1, origin: window.location.origin },
      events: {
        onReady: () => {
          this.isReady = true;
          this.statePoll = setInterval(() => this.syncPlayback(), 500);
          if (this.player.getVideoData().video_id !== this.currentVideoId) this.loadVideo();
          else {
            this.applyAudio();
            if (this.wantsToPlay) this.player.playVideo();
            else this.player.pauseVideo();
          }
        },
        onStateChange: () => this.syncPlayback(),
        onAutoplayBlocked: () => {
          if (!this.wantsToPlay || this.disposed) return;
          if (!this.muted) {
            this.muted = true;
            this.player.mute();
            this.player.playVideo();
          } else {
            clearTimeout(this.loadTimeout);
            this.loading = false;
            this.isPlaying = false;
            this.status('press play to start');
          }
          this.reportState();
        },
        onError: ({ data }) => {
          if (this.disposed || this.failed) return;
          clearTimeout(this.loadTimeout);
          this.loading = false;
          this.isPlaying = false;
          this.failed = true;
          this.reportState();
          if ([2, 5, 100, 101, 150].includes(data)) {
            this.pushEvent('player_error', { video_id: this.currentVideoId, code: data });
          } else {
            this.status('player unavailable — reload to retry');
          }
        },
      },
    });
  },

  syncPlayback() {
    if (!this.isReady || this.disposed) return;
    const data = this.player.getVideoData();
    if (data.video_id !== this.currentVideoId) return;
    const state = this.player.getPlayerState();
    const key = `${data.video_id}:${state}`;
    if (key === this.lastState) return;
    this.lastState = key;
    if (state === 1) {
      clearTimeout(this.loadTimeout);
      this.loading = false;
      this.failed = false;
      this.isPlaying = true;
      this.muted = this.player.isMuted();
      this.pushEvent('player_ready', { video_id: this.currentVideoId, title: data.title || '' });
      this.reportState();
    } else if (state === 2 || state === 0) {
      this.isPlaying = false;
      this.reportState();
      if (state === 0 && this.wantsToPlay) this.pushEvent('player_ended', { video_id: this.currentVideoId });
    }
  },

  act(action, volume) {
    if (action === 'toggle') {
      this.wantsToPlay = !this.isPlaying;
      this.loading = this.wantsToPlay;
      if (this.wantsToPlay) {
        if (this.failed && this.isReady) this.loadVideo();
        else if (this.isReady) this.player.playVideo();
        this.watchLoading();
      } else {
        clearTimeout(this.loadTimeout);
        this.isPlaying = false;
        if (this.isReady) this.player.pauseVideo();
      }
    } else {
      if (action === 'mute') this.muted = !this.muted;
      else {
        const next = action === 'volume' ? volume : this.volume + (action === 'louder' ? 10 : -10);
        this.volume = Math.max(0, Math.min(100, next));
        this.muted = false;
      }
      if (this.isReady) {
        this.applyAudio();
        if (this.wantsToPlay && !this.isPlaying) this.player.playVideo();
      }
    }
    this.reportState();
  },

  loadVideo() {
    this.failed = false;
    this.lastState = null;
    this.applyAudio();
    if (this.wantsToPlay) {
      this.loading = true;
      this.player.loadVideoById({ videoId: this.currentVideoId, startSeconds: this.startSeconds });
      this.watchLoading();
    } else {
      clearTimeout(this.loadTimeout);
      this.loading = false;
      this.player.cueVideoById({ videoId: this.currentVideoId, startSeconds: this.startSeconds });
    }
    this.reportState();
  },

  applyAudio() {
    this.player.setVolume(this.volume);
    if (this.muted) this.player.mute();
    else this.player.unMute();
  },

  watchLoading() {
    clearTimeout(this.loadTimeout);
    this.loadTimeout = setTimeout(() => {
      if (this.isPlaying || !this.wantsToPlay) return;
      this.loading = false;
      this.failed = true;
      this.reportState();
      this.status('could not start video — press play to retry');
    }, 15000);
  },

  status(message) { this.pushEvent('player_status', { video_id: this.currentVideoId, message }); },
  reportState() { this.pushEvent('player_state', { playing: this.isPlaying, muted: this.muted, volume: this.volume }); },

  destroyed() {
    this.disposed = true;
    clearInterval(this.statePoll);
    clearTimeout(this.loadTimeout);
    document.removeEventListener('click', this.onClick);
    document.removeEventListener('keydown', this.onKeyDown);
    if (window.onYouTubeIframeAPIReady === this.apiReady) window.onYouTubeIframeAPIReady = undefined;
    this.player?.destroy();
  },
};

export default YouTubePlayer;
