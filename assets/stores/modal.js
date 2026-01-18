import {defineStore} from 'pinia';

export const useModalStore = defineStore('modal', {
  state: () => ({
    title: '',
    incidents: []
  }),
  actions: {
    showIncidents(title, incidents) {
      this.title = title;
      this.incidents = incidents;
    }
  }
});
