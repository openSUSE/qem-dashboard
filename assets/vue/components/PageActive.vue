<script setup>
import {computed} from 'vue';
import {useIncidentStore} from '@/stores/incidents';
import {useConfigStore} from '@/stores/config';
import {usePolling} from '../composables/polling';
import IncidentLink from './IncidentLink.vue';

const incidentStore = useIncidentStore();
const configStore = useConfigStore();

usePolling(() => incidentStore.fetchIncidents());

const testingIncidents = computed(() =>
  incidentStore.incidents.filter(incident => incident.rr_number > 0 && !incident.approved)
);
const stagedIncidents = computed(() =>
  incidentStore.incidents.filter(incident => !incident.rr_number && !incident.approved)
);
const approvedIncidents = computed(() => incidentStore.incidents.filter(incident => incident.approved));
const smelt = computed(() => configStore.smeltUrl);
</script>

<template>
  <div v-if="incidentStore.isLoading && incidentStore.incidents.length === 0" aria-hidden="true">
    <table class="table placeholder-glow">
      <thead>
        <tr>
          <th><span class="placeholder col-4"></span></th>
          <th><span class="placeholder col-2"></span></th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="i in 5" :key="i">
          <td><span class="placeholder col-8"></span></td>
          <td><span class="placeholder col-4"></span></td>
        </tr>
      </tbody>
    </table>
  </div>
  <table class="table" v-else-if="incidentStore.incidents.length > 0">
    <thead>
      <tr>
        <th>Incident</th>
        <th>State</th>
      </tr>
    </thead>
    <tbody>
      <tr v-for="incident in testingIncidents" :key="incident.number">
        <td><IncidentLink :incident="incident" /></td>
        <td>
          <a :href="'/blocked#' + incident.number">
            <span class="badge bg-primary">testing</span>
          </a>
        </td>
      </tr>
      <tr v-for="incident in stagedIncidents" :key="incident.number">
        <td><IncidentLink :incident="incident" /></td>
        <td><span class="badge bg-secondary">staged</span></td>
      </tr>
      <tr v-for="incident in approvedIncidents" :key="incident.number">
        <td><IncidentLink :incident="incident" /></td>
        <td><span class="badge bg-success">approved</span></td>
      </tr>
    </tbody>
  </table>
  <div v-else>No active incidents, maybe take a look at <a :href="smelt">Smelt</a>.</div>
</template>

<script>
export default {
  name: 'PageActive'
};
</script>
