import {defineStore} from 'pinia';

export const useRepoStore = defineStore('repos', {
  state: () => ({
    repos: null,
    lastUpdated: null,
    isLoading: false
  }),
  actions: {
    async fetchRepos() {
      this.isLoading = true;
      try {
        const data = await fetch('/app/api/repos').then(res => res.json());
        this.repos = data.repos;
        this.lastUpdated = data.last_updated;
      } finally {
        this.isLoading = false;
      }
    }
  }
});
