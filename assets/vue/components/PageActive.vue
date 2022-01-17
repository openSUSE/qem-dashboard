<template>
  <table class="table" v-if="incidents">
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
  <div v-else><i class="fas fa-sync fa-spin"></i> Loading incidents...</div>
</template>

<script>
import Refresh from '../mixins/refresh.js';
import IncidentLink from './IncidentLink.vue';

export default {
  name: 'PageActive',
  mixins: [Refresh],
  components: {IncidentLink},
  data() {
    return {
      incidents: null,
      refreshUrl: '/app/api/list'
    };
  },
  computed: {
    testingIncidents() {
      return this.incidents.filter(incident => incident.rr_number > 0 && !incident.approved);
    },
    stagedIncidents() {
      return this.incidents.filter(incident => !incident.rr_number && !incident.approved);
    },
    approvedIncidents() {
      return this.incidents.filter(incident => incident.approved);
    }
  },
  methods: {
    refreshData(data) {
      this.incidents = data.incidents;
    }
  }
};
</script>
