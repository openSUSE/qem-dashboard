import {defineStore} from 'pinia';

export const useSubmissionDetailStore = defineStore('submission_detail', {
  state: () => ({
    submission: {},
    jobs: {},
    summary: {},
    exists: null
  }),
  actions: {
    async fetchSubmission(id, query = {}) {
      const params = new URLSearchParams();
      for (const name of ['project', 'type']) {
        if (query[name]) params.set(name, query[name]);
      }
      // A submission is addressed by (number, project, type). Without the full key there is no URL to fetch,
      // so never fall back to an ID-only /app/api/submission/<id> request
      if (params.size !== 2) {
        this.exists = false;
        return;
      }
      try {
        const url = `/app/api/submission/${id}?${params}`;
        const data = await fetch(url).then(res => res.json());
        this.submission = data.details.incident;
        this.submission.buildNr = data.details.build_nr;
        this.jobs = data.details.jobs;
        this.summary = data.details.incident_summary;
        this.exists = true;
      } catch {
        this.exists = false;
      }
    }
  }
});
