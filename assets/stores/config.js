import {defineStore} from 'pinia';

export const useConfigStore = defineStore('config', {
  state: () => ({
    bootId: '',
    openqaUrl: '',
    openqaNotGroupGlob: '',
    obsUrl: '',
    smeltUrl: '',
    defaultPriority: 0,
    isLoaded: false
  }),
  actions: {
    async fetchConfig() {
      const config = await fetch('/app-config').then(res => res.json());
      this.bootId = config.bootId;
      this.openqaUrl = config.openqaUrl;
      this.openqaNotGroupGlob = config.openqaNotGroupGlob;
      this.obsUrl = config.obsUrl;
      this.smeltUrl = config.smeltUrl;
      this.defaultPriority = config.defaultPriority;
      this.isLoaded = true;
    }
  }
});
