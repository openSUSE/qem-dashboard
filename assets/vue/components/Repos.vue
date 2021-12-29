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
        <repo-line v-for="(repo, name) in repos" :repo="repo" :name="name" :key="name" />
      </tbody>
    </table>
    <div v-else>Loading repos...</div>
    <repo-incidents-dialog ref="incidentsDialog"></repo-incidents-dialog>
  </div>
</template>

<script>
import RepoIncidentDialogComponent from './RepoIncidentDialog.vue';
import RepoLineComponent from './RepoLine.vue';
import axios from 'axios';

export default {
  name: 'ReposComponent',
  components: {'repo-incidents-dialog': RepoIncidentDialogComponent, 'repo-line': RepoLineComponent},
  created() {
    this.loadData();
  },
  data() {
    return {repos: null};
  },
  methods: {
    loadData() {
      axios.get('/secret/api/repos').then(response => {
        this.repos = response.data;
      });
    }
  }
};
</script>
