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
      try {
        const params = new URLSearchParams();
        for (const name of ['project', 'type']) {
          // An empty type is meaningful (the smelt default), so only skip absent values.
          if (query[name] !== undefined && query[name] !== null) params.set(name, query[name]);
        }
        const search = params.toString();
        const url = `/app/api/submission/${id}${search ? `?${search}` : ''}`;
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
