<template>
  <div v-if="incidents === null"><i class="fas fa-sync fa-spin"></i> Loading incidents...</div>
  <div v-else-if="incidents.length > 0">
    <div class="row align-items-center">
      <div class="col-auto my-1">
        <div class="form-check">
          <input class="form-check-input" type="checkbox" id="checkbox" v-model="groupFlavors" />
          <label class="form-check-label" for="checkbox"> Group Flavors </label>
        </div>
      </div>
    </div>
    <table class="table">
      <thead>
        <tr>
          <th>
            Incident
            <input
              v-model="matchText"
              type="text"
              class="form-control"
              id="inlineSearchIncidents"
              title="Partial incident# or package name are matched"
              placeholder="Search for incident/package"
            />
          </th>
          <th>
            Groups
            <input
              v-model="groupNames"
              type="text"
              class="form-control"
              id="inlineSearchGroups"
              title="Only exact, comma separated, job group names are matched"
              placeholder="Search for group names"
            />
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
      groupNames: '',
      refreshUrl: '/app/api/blocked'
    };
  },
  computed: {
    matchedIncidents() {
      let results = this.incidents;
      if (this.matchText) {
        results = this.incidents.filter(incident => {
          if (String(incident.incident.number).includes(this.matchText)) return true;
          for (const pack of incident.incident.packages) {
            if (pack.includes(this.matchText)) return true;
          }
          return false;
        });
      }
      if (this.groupNames) {
        const groupNamesList = this.groupNames.toLowerCase().split(',');
        return results.filter(incident => {
          for (const key of Object.keys(incident.update_results)) {
            for (const groupName of Object.values(groupNamesList)) {
              if (groupName === incident.update_results[key].name.toLowerCase()) return true;
            }
          }
          for (const key of Object.keys(incident.incident_results)) {
            for (const groupName of Object.values(groupNamesList)) {
              if (groupName === incident.incident_results[key].name.toLowerCase()) return true;
            }
          }
          return false;
        });
      }
      return results;
    },
    smelt() {
      return this.appConfig.smeltUrl;
    }
  },
  methods: {
    refreshData(data) {
      this.incidents = data.blocked;
    }
  }
};
</script>
