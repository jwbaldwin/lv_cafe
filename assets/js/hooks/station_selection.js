export default {
  mounted() {
    this.handleEvent("store_station", ({ station_id }) => {
      localStorage.setItem("station_id", station_id);
    });
  },
};
