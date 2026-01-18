import {defineStore} from 'pinia';

export const useSubmissionDetailStore = defineStore('submission_detail', {
  state: () => ({
    submission: {},
    jobs: {},
    summary: {},
    exists: null
  }),
  actions: {
    async fetchSubmission(id) {
      try {
        const data = await fetch(`/app/api/incident/${id}`).then(res => res.json());
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
