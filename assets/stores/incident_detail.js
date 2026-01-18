import {defineStore} from 'pinia';

export const useIncidentDetailStore = defineStore('incidentDetail', {
  state: () => ({
    exists: null,
    incident: null,
    summary: null,
    jobs: [],
    isLoading: false
  }),
  actions: {
    async fetchIncident(id) {
      this.isLoading = true;
      try {
        const data = await fetch(`/app/api/incident/${id}`).then(res => res.json());
        const {details} = data;
        if (details.incident === null) {
          this.exists = false;
        } else {
          this.exists = true;
          this.incident = details.incident;
          this.incident.buildNr = details.build_nr;
          this.summary = details.incident_summary;
          this.jobs = details.jobs;
        }
      } finally {
        this.isLoading = false;
      }
    }
  }
});
