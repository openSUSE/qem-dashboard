import {defineStore} from 'pinia';

export const useSubmissionStore = defineStore('submissions', {
  state: () => ({
    submissions: [],
    isLoading: false
  }),
  actions: {
    async fetchSubmissions() {
      this.isLoading = true;
      try {
        const data = await fetch('/app/api/list').then(res => res.json());
        this.submissions = data.incidents;
      } finally {
        this.isLoading = false;
      }
    }
  }
});
