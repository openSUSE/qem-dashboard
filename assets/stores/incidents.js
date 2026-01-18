import {defineStore} from 'pinia';

export const useIncidentStore = defineStore('incidents', {
  state: () => ({
    incidents: [],
    lastUpdated: null,
    isLoading: false
  }),
  actions: {
    async fetchIncidents() {
      this.isLoading = true;
      try {
        const data = await fetch('/app/api/list').then(res => res.json());
        this.incidents = data.incidents;
        this.lastUpdated = data.last_updated;
      } finally {
        this.isLoading = false;
      }
    },
    updateIncidents(data) {
      this.incidents = data.incidents;
      this.lastUpdated = data.last_updated;
    }
  }
});
