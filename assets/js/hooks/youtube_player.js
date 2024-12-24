// assets/js/hooks/youtube_player.js
const YouTubePlayer = {
  mounted() {
    if (!window.YT) {
      const tag = document.createElement("script");
      tag.src = "https://www.youtube.com/iframe_api";
      const firstScriptTag = document.getElementsByTagName("script")[0];
      firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);

      window.onYouTubeIframeAPIReady = () => {
        if (!this.isInitialized) {
          this.initPlayer();
        }
      };
    } else if (!this.isInitialized) {
      this.initPlayer();
    }

    this.handleEvent("changeVideo", ({ video_id }) => {
      this.player.loadVideoById(video_id);
    });

    this.handleEvent("playVideo", () => {
      if (this.player) this.player.playVideo();
    });

    this.handleEvent("pauseVideo", () => {
      if (this.player) this.player.pauseVideo();
    });

    this.handleEvent("incVolume", () => {
      if (this.player) {
        this.player.unMute();
        this.player.setVolume(this.player.getVolume() + 10);
      }
    });

    this.handleEvent("decVolume", () => {
      if (this.player) {
        this.player.unMute();
        this.player.setVolume(this.player.getVolume() - 10);
      }
    });
  },

  initPlayer() {
    this.isInitialized = true;
    this.player = new YT.Player(this.el.id, {
      videoId: this.el.dataset.videoId,
      events: {
        onReady: () => {
          this.player.setVolume(50);
          this.pushEvent("player_ready", { title: this.player.videoTitle });
        },
      },
      playerVars: {
        autoplay: 1,
        mute: 1,
        controls: 0,
        playsinline: 1,
        rel: 0,
      },
    });
  },

  destroyed() {
    if (this.player) {
      this.player.destroy();
      this.isInitialized = false;
    }
  },
};

export default YouTubePlayer;
