<template>
  <div>
    <table class="table" v-if="repos">
      <thead>
        <tr>
          <th>Group</th>
          <th>Tests</th>
        </tr>
      </thead>
      <tbody>
        <RepoLine v-for="(repo, name) in repos" :repo="repo" :name="name" :key="name" />
      </tbody>
    </table>
    <div v-else>Loading repos...</div>
    <RepoIncidentDialog ref="incidentsDialog"></RepoIncidentDialog>
  </div>
</template>

<script>
import RepoIncidentDialog from './RepoIncidentDialog.vue';
import RepoLine from './RepoLine.vue';
import axios from 'axios';

export default {
  name: 'PageRepos',
  components: {RepoIncidentDialog, RepoLine},
  data() {
    return {repos: null};
  },
  mounted() {
    this.refreshData();
    this.timer = setInterval(this.refreshData, 30000);
  },
  unmounted() {
    this.cancelRefresh();
  },
  methods: {
    refreshData() {
      axios.get('/app/api/repos').then(response => {
        const {data} = response;
        this.repos = data.repos;
        this.$emit('last-updated', data.last_updated);
      });
    },
    cancelRefresh() {
      clearInterval(this.timer);
    }
  }
};
</script>
