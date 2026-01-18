import {defineStore} from 'pinia';

export const useBlockedStore = defineStore('blocked', {
  state: () => ({
    incidents: [],
    lastUpdated: null,
    isLoading: false
  }),
  actions: {
    async fetchBlocked() {
      this.isLoading = true;
      try {
        const data = await fetch('/app/api/blocked').then(res => res.json());
        this.incidents = data.blocked;
        this.lastUpdated = data.last_updated;
      } finally {
        this.isLoading = false;
      }
    }
  }
});
