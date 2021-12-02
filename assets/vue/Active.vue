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
        <td><incident-link :incident="incident" /></td>
        <td>
          <a :href="'/blocked#' + incident.number">
            <span class="badge badge-primary">testing</span>
          </a>
        </td>
      </tr>
      <tr v-for="incident in stagedIncidents" :key="incident.number">
        <td><incident-link :incident="incident" /></td>
        <td><span class="badge badge-secondary">staged</span></td>
      </tr>
      <tr v-for="incident in approvedIncidents" :key="incident.number">
        <td><incident-link :incident="incident" /></td>
        <td><span class="badge badge-success">approved</span></td>
      </tr>
    </tbody>
  </table>
  <div v-else>Loading incidents...</div>
</template>

<script>
import IncidentLinkComponent from './IncidentLink.vue';
import axios from 'axios';

export default {
  name: 'ActiveComponent',
  data() {
    return {
      incidents: null
    };
  },
  components: {'incident-link': IncidentLinkComponent},
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
  created() {
    this.loadData();
  },
  methods: {
    loadData() {
      axios.get('/secret/api/list').then(response => (this.incidents = response.data));
    }
  }
};
</script>
