const Preferences = {
  mounted() {
    // Listen for preference updates from LiveView
    this.handleEvent("store_preferences", ({ preferences }) => {
      localStorage.setItem("preferences", JSON.stringify(preferences));
    });
  },
};

export default Preferences;
