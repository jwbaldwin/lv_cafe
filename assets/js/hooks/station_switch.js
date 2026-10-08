const prefersReducedMotion = () => window.matchMedia('(prefers-reduced-motion: reduce)').matches;
const fadeOut = { transition: ['ease-out duration-100', 'opacity-100', 'opacity-0'], time: 100 };

const StationSwitch = {
  mounted() {
    this.onPick = (event) => this.switchTo(event.target.closest('[data-station-key]'));
    this.el.addEventListener('station:pick', this.onPick);
  },

  switchTo(tile) {
    const thumbnail = tile.querySelector('img');
    const backdrop = document.getElementById('station-backdrop');
    const video = document.getElementById('youtube-player-container');
    const showBackdrop = () => {
      backdrop.setAttribute('src', thumbnail.getAttribute('src'));
      video.classList.remove('video-visible');
    };

    if (!thumbnail || !backdrop || !document.startViewTransition || prefersReducedMotion()) {
      if (thumbnail && backdrop) showBackdrop();
      this.js().hide(this.el, fadeOut);
      return;
    }

    thumbnail.style.viewTransitionName = 'station-backdrop';
    const transition = document.startViewTransition(async () => {
      thumbnail.style.viewTransitionName = '';
      document.documentElement.classList.add('switching-station');
      showBackdrop();
      this.js().hide(this.el);
      this.el.style.display = 'none';
      await backdrop.decode().catch(() => {});
    });
    transition.finished.finally(() => document.documentElement.classList.remove('switching-station'));
  },

  destroyed() {
    this.el.removeEventListener('station:pick', this.onPick);
  },
};

export default StationSwitch;
