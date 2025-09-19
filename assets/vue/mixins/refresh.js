export default {
  data() {
    return {
      refreshDelay: 30000,
      refreshTimer: null
    };
  },
  mounted() {
    this.doApiRefresh();
    this.refreshTimer = setInterval(this.doApiRefresh, this.refreshDelay);
  },
  unmounted() {
    this.cancelApiRefresh();
  },
  methods: {
    async doApiRefresh() {
      const data = await fetch(this.refreshUrl).then(res => res.json());
      this.$emit('last-updated', data.last_updated);
      this.refreshData(data);
    },
    cancelApiRefresh() {
      clearInterval(this.refreshTimer);
    }
  }
};
