<template>
  <div v-if="incidents">
    <div class="float-right">
      <input type="checkbox" id="checkbox" v-model="groupFlavors" />
      <label for="checkbox">Group Flavors</label>
    </div>
    <table class="table">
      <thead>
        <tr>
          <th>Incident</th>
          <th>Groups</th>
        </tr>
      </thead>
      <tbody>
        <tr
          is="blocked-incident"
          v-for="incident in incidents"
          :key="incident.incident.number"
          :incident="incident.incident"
          :incident-results="incident.incident_results"
          :update-results="incident.update_results"
          :group-flavors="groupFlavors"
        />
      </tbody>
    </table>
  </div>
  <div v-else>Loading incidents...</div>
</template>

<script>
import BlockedIncidentComponent from './BlockedIncident.vue';
import axios from 'axios';

export default {
  name: 'BlockedComponent',
  components: {'blocked-incident': BlockedIncidentComponent},
  data() {
    return {
      incidents: null,
      groupFlavors: true
    };
  },
  created() {
    this.loadData();
  },
  watch: {
    $route: 'loadData'
  },
  methods: {
    loadData() {
      axios.get('/secret/api/blocked').then(response => (this.incidents = response.data));
    }
  }
};
</script>
