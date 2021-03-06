import axios from 'axios';

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
    doApiRefresh() {
      axios.get(this.refreshUrl).then(response => {
        const {data} = response;
        this.$emit('last-updated', data.last_updated);
        this.refreshData(data);
      });
    },
    cancelApiRefresh() {
      clearInterval(this.refreshTimer);
    }
  }
};
