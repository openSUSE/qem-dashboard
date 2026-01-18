<script setup>
import {ref} from 'vue';
import {onBeforeRouteLeave} from 'vue-router';
import RepoIncidentDialog from './RepoIncidentDialog.vue';
import RepoLine from './RepoLine.vue';
import {useRepoStore} from '@/stores/repos';
import {usePolling} from '../composables/polling';
import {Modal} from 'bootstrap';

const repoStore = useRepoStore();
const incidentsDialog = ref(null);

usePolling(() => repoStore.fetchRepos());

// Remove the modal backdrop if one was left behind
onBeforeRouteLeave((to, from, next) => {
  const el = document.getElementById('update-incidents');
  if (el !== null) {
    const modal = Modal.getInstance(el);
    if (modal !== null) modal.hide();
  }
  next();
});
</script>

<template>
  <div>
    <table class="table" v-if="repoStore.repos">
      <thead>
        <tr>
          <th>Group</th>
          <th>Tests</th>
        </tr>
      </thead>
      <tbody>
        <RepoLine v-for="(repo, name) in repoStore.repos" :repo="repo" :name="name" :key="name" />
      </tbody>
    </table>
    <div v-else-if="repoStore.isLoading"><i class="fas fa-sync fa-spin"></i> Loading repos...</div>
    <RepoIncidentDialog ref="incidentsDialog"></RepoIncidentDialog>
  </div>
</template>

<script>
export default {
  name: 'PageRepos'
};
</script>
