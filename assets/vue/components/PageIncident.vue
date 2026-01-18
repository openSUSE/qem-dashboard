<script setup>
import {computed} from 'vue';
import {useRoute} from 'vue-router';
import {useIncidentDetailStore} from '@/stores/incident_detail';
import {useConfigStore} from '@/stores/config';
import {usePolling} from '../composables/polling';
import IncidentBuildSummary from './IncidentBuildSummary.vue';
import RequestLink from './RequestLink.vue';
import SmeltLink from './SmeltLink.vue';
import IncidentDetailsIcons from './IncidentDetailsIcons.vue';

const route = useRoute();
const incidentDetailStore = useIncidentDetailStore();
const configStore = useConfigStore();

usePolling(() => incidentDetailStore.fetchIncident(route.params.id));

const results = computed(() => {
  if (!incidentDetailStore.summary) return [];
  const parts = [];
  const statusClasses = {
    passed: 'bg-success',
    failed: 'bg-danger',
    stopped: 'bg-secondary',
    waiting: 'bg-primary'
  };
  const statusIcons = {
    passed: 'fa-check-circle',
    failed: 'fa-times-circle',
    stopped: 'fa-stop-circle',
    waiting: 'fa-clock'
  };

  if (incidentDetailStore.summary.passed) {
    parts.push({
      count: incidentDetailStore.summary.passed,
      text: 'passed',
      class: statusClasses.passed,
      icon: statusIcons.passed
    });
  }
  for (const [key, value] of Object.entries(incidentDetailStore.summary)) {
    if (key === 'passed') continue;
    parts.push({
      count: value,
      text: key,
      class: statusClasses[key] || 'bg-dark',
      icon: statusIcons[key] || 'fa-exclamation-triangle'
    });
  }
  return parts;
});

const openqaLink = computed(() => {
  const searchParams = new URLSearchParams({build: incidentDetailStore.incident.buildNr});
  return `${configStore.openqaUrl}?${searchParams.toString()}`;
});

const sortedBuilds = computed(() => {
  return Object.keys(incidentDetailStore.jobs).sort().reverse();
});
</script>

<template>
  <div v-if="incidentDetailStore.exists === false"><p>Incident does not exist.</p></div>
  <div v-else-if="incidentDetailStore.exists === true">
    <div class="d-flex align-items-center justify-content-between mb-3" v-if="incidentDetailStore.incident">
      <IncidentDetailsIcons :incident="incidentDetailStore.incident" class="fs-4" />
    </div>

    <div class="external-links" v-if="incidentDetailStore.incident">
      <div class="packages">
        <h2>Packages</h2>
        <ul>
          <li v-for="pkg in incidentDetailStore.incident.packages" :key="pkg">
            {{ pkg }}
          </li>
        </ul>
      </div>
      <div class="smelt-link" v-if="(incidentDetailStore.incident.type || 'smelt') === 'smelt'">
        <h2>Link to Smelt</h2>
        <p>
          <SmeltLink :incident="incidentDetailStore.incident" />
        </p>
      </div>
      <div class="request-link">
        <h2>Source Link</h2>
        <p>
          <RequestLink :incident="incidentDetailStore.incident" />
        </p>
      </div>
    </div>

    <div class="incident-results" v-if="incidentDetailStore.incident">
      <h2>Per Incident Results</h2>
      <p v-if="!incidentDetailStore.incident.buildNr">No incident build found</p>
      <p v-else>
        <span v-for="part in results" :key="part.text" :class="['badge', part.class, 'me-1']">
          <i :class="['fas', part.icon, 'me-1']" aria-hidden="true"></i>
          {{ part.count }} {{ part.text }}
        </span>
        - see <a :href="openqaLink" target="_blank">openQA</a> for details
      </p>
    </div>

    <div class="incident-aggregates" v-if="!!sortedBuilds.length">
      <h2>Aggregate Runs Including This Incident</h2>
      <IncidentBuildSummary
        v-for="build in sortedBuilds"
        :key="build"
        :build="build"
        :jobs="incidentDetailStore.jobs[build]"
      />
    </div>

    <div class="details" v-if="incidentDetailStore.incident">
      <h2>Further details</h2>
      <table class="table table-sm">
        <tr v-if="incidentDetailStore.incident.url && incidentDetailStore.incident.url.length > 0">
          <th>URL</th>
          <td>
            <a :href="incidentDetailStore.incident.url" target="_blank">{{ incidentDetailStore.incident.url }}</a>
          </td>
        </tr>
        <tr v-if="incidentDetailStore.incident.scminfo">
          <th>SCM Info</th>
          <td>{{ incidentDetailStore.incident.scminfo }}</td>
        </tr>
      </table>
    </div>
  </div>
  <div v-else><i class="fas fa-sync fa-spin"></i> Loading incident...</div>
</template>

<script>
export default {
  name: 'PageIncident'
};
</script>
