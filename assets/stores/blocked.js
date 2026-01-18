import {defineStore} from 'pinia';

export const useBlockedStore = defineStore('blocked', {
  state: () => ({
    submissions: [],
    lastUpdated: null,
    isLoading: false
  }),
  actions: {
    async fetchBlocked() {
      this.isLoading = true;
      try {
        const data = await fetch('/app/api/blocked').then(res => res.json());
        this.submissions = data.blocked;
        this.lastUpdated = data.last_updated;
      } finally {
        this.isLoading = false;
      }
    }
  }
});
