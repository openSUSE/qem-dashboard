import {defineStore} from 'pinia';

export const useConfigStore = defineStore('config', {
  state: () => ({
    bootId: '',
    openqaUrl: '',
    obsUrl: '',
    smeltUrl: '',
    giteaFallbackPriority: 0,
    isLoaded: false
  }),
  actions: {
    async fetchConfig() {
      const config = await fetch('/app-config').then(res => res.json());
      this.bootId = config.bootId;
      this.openqaUrl = config.openqaUrl;
      this.obsUrl = config.obsUrl;
      this.smeltUrl = config.smeltUrl;
      this.giteaFallbackPriority = config.giteaFallbackPriority;
      this.isLoaded = true;
    }
  }
});
