<script setup>
import {ref, computed, watch} from 'vue';
import {useRoute} from 'vue-router';
import BlockedSubmission from './BlockedSubmission.vue';
import * as filtering from '../helpers/filtering.js';
import {useBlockedStore} from '@/stores/blocked';
import {useConfigStore} from '@/stores/config';
import {usePolling} from '../composables/polling';

const route = useRoute();
const blockedStore = useBlockedStore();
const configStore = useConfigStore();

const groupFlavors = ref(route.query.group_flavors !== '0');
const matchText = ref(route.query.submission || route.query.incident || '');
const groupNames = ref(route.query.group_names || '');
const selectedStates = ref(route.query.states ? route.query.states.split(',') : ['failed', 'stopped', 'waiting']);

usePolling(() => blockedStore.fetchBlocked());

const matchedSubmissions = computed(() => {
  const url = new URL(location);
  const searchParams = url.searchParams;
  let results = blockedStore.submissions;

  if (matchText.value) {
    searchParams.set('submission', matchText.value);
    results = results.filter(submission => {
      if (String(submission.incident.number).includes(matchText.value)) return true;
      for (const pack of submission.incident.packages) {
        if (pack.includes(matchText.value)) return true;
      }
      return false;
    });
  } else {
    searchParams.delete('submission');
    searchParams.delete('incident');
  }

  if (groupNames.value) {
    url.searchParams.set('group_names', groupNames.value);
    const filters = filtering.makeGroupNamesFilters(groupNames.value);
    results = results.filter(
      submission =>
        filtering.checkResults(submission.update_results, filters) ||
        filtering.checkResults(submission.incident_results, filters)
    );
  } else {
    searchParams.delete('group_names');
  }

  if (groupFlavors.value) {
    searchParams.delete('group_flavors');
  } else {
    searchParams.set('group_flavors', '0');
  }

  if (
    selectedStates.value.length > 0 &&
    !(
      selectedStates.value.length === 3 &&
      selectedStates.value.includes('failed') &&
      selectedStates.value.includes('stopped') &&
      selectedStates.value.includes('waiting')
    )
  ) {
    searchParams.set('states', selectedStates.value.join(','));
  } else {
    searchParams.delete('states');
  }

  history.pushState({}, '', url);

  const getPriority = incident => {
    if (incident.priority !== null) return incident.priority;
    if (incident.type === 'git') return configStore.giteaFallbackPriority;
    return 0;
  };

  return results.sort((a, b) => getPriority(b.incident) - getPriority(a.incident));
});

const smelt = computed(() => configStore.smeltUrl);

watch(groupFlavors, enabled => {
  const url = new URL(location);
  const params = url.searchParams;
  enabled ? params.delete('group_flavors') : params.set('group_flavors', '0');
  history.pushState({}, '', url);
});
</script>

<template>
  <div v-if="blockedStore.isLoading && blockedStore.submissions.length === 0">
    <i class="fas fa-sync fa-spin"></i> Loading submissions...
  </div>
  <div v-else-if="blockedStore.submissions.length > 0">
    <div class="row align-items-center">
      <div class="col-auto my-1">
        <div class="form-check">
          <label class="form-check-label" for="checkbox">
            <input class="form-check-input" type="checkbox" id="checkbox" v-model="groupFlavors" />
            Group Flavors
          </label>
        </div>
      </div>
      <div class="col-auto my-1 border-start">
        <div
          v-for="state in ['failed', 'passed', 'stopped', 'waiting']"
          :key="state"
          class="form-check form-check-inline ms-2"
        >
          <label class="form-check-label text-capitalize" :for="state">
            <input class="form-check-input" type="checkbox" :id="state" :value="state" v-model="selectedStates" />
            {{ state }}
          </label>
        </div>
      </div>
    </div>
    <table class="table table-fixed">
      <thead>
        <tr>
          <th class="col-submission">
            <label for="inlineSearchSubmissions">
              Submission
              <input
                v-model="matchText"
                type="text"
                class="form-control"
                id="inlineSearchSubmissions"
                title="Partial submission# or package name are matched"
                placeholder="Search for submission/package"
              />
            </label>
          </th>
          <th class="col-groups">
            <label for="inlineSearchGroups">
              Groups
              <input
                v-model="groupNames"
                type="text"
                class="form-control"
                id="inlineSearchGroups"
                title="Comma separated, job group names are matched, supports regex syntax"
                placeholder="Search for group names"
              />
            </label>
          </th>
        </tr>
      </thead>
      <tbody>
        <BlockedSubmission
          v-for="submission in matchedSubmissions"
          :key="submission.incident.number"
          :submission="submission.incident"
          :submission-results="submission.incident_results"
          :update-results="submission.update_results"
          :group-flavors="groupFlavors"
          :group-names="groupNames"
          :selected-states="selectedStates"
        />
      </tbody>
    </table>
  </div>
  <div v-else>No active submissions, maybe take a look at <a :href="smelt">Smelt</a>.</div>
</template>

<script>
export default {
  name: 'PageBlockedSubmissions'
};
</script>

<style scoped>
.table-fixed {
  table-layout: fixed;
  width: 100%;
}
.col-submission {
  width: 250px;
}
.col-groups {
  width: auto;
}
th label {
  display: block;
  width: 100%;
}
</style>
