import {defineStore} from 'pinia';

export const useModalStore = defineStore('modal', {
  state: () => ({
    title: '',
    submissions: []
  }),
  actions: {
    showSubmissions(title, submissions) {
      this.title = title;
      this.submissions = submissions;
    }
  }
});
