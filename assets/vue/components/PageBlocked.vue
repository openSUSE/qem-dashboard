<template>
  <div v-if="incidents">
    <div class="form-row align-items-center">
      <div class="col-auto my-1">
        <div class="form-check">
          <input class="form-check-input" type="checkbox" id="checkbox" v-model="groupFlavors" />
          <label class="form-check-label" for="checkbox"> Group Flavors </label>
        </div>
      </div>
      <div class="col-sm-3 my-1">
        <label class="sr-only" for="inlineFormInputName">Name</label>
        <input
          v-model="matchText"
          type="text"
          class="form-control"
          id="inlineSearch"
          placeholder="Search for Incident/Package"
        />
      </div>
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
import Refresh from '../mixins/refresh.js';
import BlockedIncident from './BlockedIncident.vue';

export default {
  name: 'PageBlocked',
  mixins: [Refresh],
  components: {BlockedIncident},
  data() {
    return {
      incidents: null,
      groupFlavors: true,
      matchText: '',
      refreshUrl: '/app/api/blocked'
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
  methods: {
    refreshData(data) {
      this.incidents = data.blocked;
    }
  }
};
</script>
