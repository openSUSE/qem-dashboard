<script setup>
import {ref, computed, watch} from 'vue';
import {useRoute} from 'vue-router';
import BlockedIncident from './BlockedIncident.vue';
import * as filtering from '../helpers/filtering.js';
import {useBlockedStore} from '@/stores/blocked';
import {useConfigStore} from '@/stores/config';
import {usePolling} from '../composables/polling';

const route = useRoute();
const blockedStore = useBlockedStore();
const configStore = useConfigStore();

const groupFlavors = ref(route.query.group_flavors !== '0');
const matchText = ref(route.query.incident || '');
const groupNames = ref(route.query.group_names || '');

usePolling(() => blockedStore.fetchBlocked());

const matchedIncidents = computed(() => {
  const url = new URL(location);
  const searchParams = url.searchParams;
  let results = blockedStore.incidents;

  if (matchText.value) {
    searchParams.set('incident', matchText.value);
    results = results.filter(incident => {
      if (String(incident.incident.number).includes(matchText.value)) return true;
      for (const pack of incident.incident.packages) {
        if (pack.includes(matchText.value)) return true;
      }
      return false;
    });
  } else {
    searchParams.delete('incident');
  }

  if (groupNames.value) {
    url.searchParams.set('group_names', groupNames.value);
    const filters = filtering.makeGroupNamesFilters(groupNames.value);
    results = results.filter(
      incident =>
        filtering.checkResults(incident.update_results, filters) ||
        filtering.checkResults(incident.incident_results, filters)
    );
  } else {
    searchParams.delete('group_names');
  }

  if (groupFlavors.value) {
    searchParams.delete('group_flavors');
  } else {
    searchParams.set('group_flavors', '0');
  }

  history.pushState({}, '', url);
  return results.sort((a, b) => (b.incident.priority || 0) - (a.incident.priority || 0));
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
  <div v-if="blockedStore.isLoading && blockedStore.incidents.length === 0">
    <i class="fas fa-sync fa-spin"></i> Loading incidents...
  </div>
  <div v-else-if="blockedStore.incidents.length > 0">
    <div class="row align-items-center">
      <div class="col-auto my-1">
        <div class="form-check">
          <label class="form-check-label" for="checkbox">
            <input class="form-check-input" type="checkbox" id="checkbox" v-model="groupFlavors" />
            Group Flavors
          </label>
        </div>
      </div>
    </div>
    <table class="table">
      <thead>
        <tr>
          <th>
            <label for="inlineSearchIncidents">
              Incident
              <input
                v-model="matchText"
                type="text"
                class="form-control"
                id="inlineSearchIncidents"
                title="Partial incident# or package name are matched"
                placeholder="Search for incident/package"
              />
            </label>
          </th>
          <th>
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
        <BlockedIncident
          v-for="incident in matchedIncidents"
          :key="incident.incident.number"
          :incident="incident.incident"
          :incident-results="incident.incident_results"
          :update-results="incident.update_results"
          :group-flavors="groupFlavors"
          :group-names="groupNames"
        />
      </tbody>
    </table>
  </div>
  <div v-else>No active incidents, maybe take a look at <a :href="smelt">Smelt</a>.</div>
</template>

<script>
export default {
  name: 'PageBlocked'
};
</script>
