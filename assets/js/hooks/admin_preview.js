const AdminPreview = {
  mounted() {
    this.disposed = false;
    this.handleEvent('pause_preview', () => { this.current = null; clearTimeout(this.sample); this.player?.pauseVideo?.(); this.status('Select Preview on a video to listen here.'); });
    this.status = text => { this.el.querySelector('[data-preview-status]').textContent = text; };
    this.handleEvent('preview_video', video => {
      this.current = video;
      clearTimeout(this.sample);
      this.status('Loading preview…');
      if (this.ready) this.load();
      else if (window.YT?.Player && !this.player) this.init();
    });
    this.apiReady = () => { if (!this.disposed && this.current && !this.player) this.init(); };
    if (!window.YT?.Player) {
      window.onYouTubeIframeAPIReady = this.apiReady;
      if (!document.getElementById('youtube-iframe-api')) {
        const script = document.createElement('script');
        script.id = 'youtube-iframe-api';
        script.src = 'https://www.youtube.com/iframe_api';
        document.head.appendChild(script);
      }
    }
  },
  init() {
    this.player = new window.YT.Player('admin-player', {
      width: '100%', height: 300,
      playerVars: { origin: window.location.origin, playsinline: 1 },
      events: {
        onReady: () => { this.ready = true; this.load(); },
        onAutoplayBlocked: () => this.status('Press play in the preview to start.'),
        onError: event => { clearTimeout(this.sample); this.status(`YouTube error ${event.data}: this embed did not play.`); },
        onStateChange: event => {
          if (event.data !== 1 || !this.current) return;
          clearTimeout(this.sample);
          const current = this.current;
          const before = this.player.getCurrentTime();
          this.sample = setTimeout(() => {
            const data = this.player.getVideoData();
            if (this.disposed || current !== this.current || data.video_id !== current.video_id || this.player.getCurrentTime() <= before) return;
            this.status('Verified: the video is playing and advancing.');
            this.pushEvent('player_verified', {
              video_id: data.video_id, title: data.title || '', live: data.isLive === true,
              duration_seconds: data.isLive ? 0 : Math.floor(this.player.getDuration()),
            });
          }, 2000);
        },
      },
    });
  },
  load() { if (this.current) this.player.loadVideoById({ videoId: this.current.video_id, startSeconds: this.current.start_seconds }); },
  destroyed() {
    this.disposed = true;
    clearTimeout(this.sample);
    if (window.onYouTubeIframeAPIReady === this.apiReady) window.onYouTubeIframeAPIReady = undefined;
    this.player?.destroy();
  },
};
export default AdminPreview;
