const YouTubePlayer = {
  mounted() {
    // Load YouTube IFrame API
    if (!window.YT) {
      const tag = document.createElement("script");
      tag.src = "https://www.youtube.com/iframe_api";
      const firstScriptTag = document.getElementsByTagName("script")[0];
      firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);
    }

    // Initialize player when API is ready
    window.onYouTubeIframeAPIReady = () => {
      this.player = new YT.Player(this.el.id, {
        height: "360",
        width: "640",
        videoId: this.el.dataset.videoId,
        playerVars: {
          playsinline: 1,
          controls: 0,
          modestbranding: 1,
          rel: 0,
        },
        events: {
          onReady: this.onPlayerReady.bind(this),
          onStateChange: this.onPlayerStateChange.bind(this),
        },
      });
    };
  },

  onPlayerReady(event) {
    // Tell LiveView the player is ready
    this.pushEvent("player_ready", {});
  },

  onPlayerStateChange(event) {
    // Push state changes to LiveView
    this.pushEvent("player_state_changed", {
      state: event.data,
    });
  },

  //////
  // Methods that can be called from LiveView
  //////
  playVideo() {
    if (this.player) {
      this.player.playVideo();
    }
  },

  pauseVideo() {
    if (this.player) {
      this.player.pauseVideo();
    }
  },

  changeVolume(volume) {
    if (this.player) {
      this.player.setVolume(volume);
    }
  },

  destroyed() {
    if (this.player) {
      this.player.destroy();
    }
  },
};

export default YouTubePlayer;
