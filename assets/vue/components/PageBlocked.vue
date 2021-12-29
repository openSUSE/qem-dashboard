<template>
  <div v-if="incidents">
    <div class="float-right">
      <input type="checkbox" id="checkbox" v-model="groupFlavors" />
      <label for="checkbox">Group Flavors</label>
      <input v-model="matchText" placeholder="Search for Incident/Package" />
    </div>
    <table class="table">
      <thead>
        <tr>
          <th>Incident</th>
          <th>Groups</th>
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
        />
      </tbody>
    </table>
  </div>
  <div v-else>Loading incidents...</div>
</template>

<script>
import BlockedIncident from './BlockedIncident.vue';
import axios from 'axios';

export default {
  name: 'PageBlocked',
  components: {BlockedIncident},
  data() {
    return {
      incidents: null,
      groupFlavors: true,
      matchText: ''
    };
  },
  computed: {
    matchedIncidents() {
      if (this.matchText) {
        return this.incidents.filter(incident => {
          if (String(incident.incident.number).includes(this.matchText)) return true;
          for (const pack of incident.incident.packages) {
            if (pack.includes(this.matchText)) return true;
          }
          return false;
        });
      }
      return this.incidents;
    }
  },
  created() {
    this.loadData();
  },
  methods: {
    loadData() {
      axios.get('/secret/api/blocked').then(response => (this.incidents = response.data));
    }
  }
};
</script>
