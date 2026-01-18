import {defineStore} from 'pinia';

export const useConfigStore = defineStore('config', {
  state: () => ({
    openqaUrl: '',
    obsUrl: '',
    smeltUrl: '',
    isLoaded: false
  }),
  actions: {
    async fetchConfig() {
      const config = await fetch('/app-config').then(res => res.json());
      this.openqaUrl = config.openqaUrl;
      this.obsUrl = config.obsUrl;
      this.smeltUrl = config.smeltUrl;
      this.isLoaded = true;
    }
  }
});
