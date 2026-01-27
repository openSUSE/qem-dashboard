<template>
  <div v-if="incidents === null"><i class="fas fa-sync fa-spin"></i> Loading incidents...</div>
  <div v-else-if="incidents.length > 0">
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
import BlockedIncident from './BlockedIncident.vue';
import * as filtering from '../helpers/filtering.js';
import Refresh from '../mixins/refresh.js';

export default {
  name: 'PageBlocked',
  mixins: [Refresh],
  components: {BlockedIncident},
  data() {
    return {
      incidents: null,
      groupFlavors: this.$route.query.group_flavors !== '0',
      matchText: this.$route.query.incident || '',
      groupNames: this.$route.query.group_names || '',
      refreshUrl: '/app/api/blocked'
    };
  },
  computed: {
    matchedIncidents() {
      const url = new URL(location);
      const searchParams = url.searchParams;
      let results = this.incidents;
      if (this.matchText) {
        searchParams.set('incident', this.matchText);
        results = this.incidents.filter(incident => {
          if (String(incident.incident.number).includes(this.matchText)) return true;
          for (const pack of incident.incident.packages) {
            if (pack.includes(this.matchText)) return true;
          }
          return false;
        });
      } else {
        searchParams.delete('incident');
      }
      if (this.groupNames) {
        url.searchParams.set('group_names', this.groupNames);
        const filters = filtering.makeGroupNamesFilters(this.groupNames);
        results = results.filter(
          incident =>
            filtering.checkResults(incident.update_results, filters) ||
            filtering.checkResults(incident.incident_results, filters)
        );
      } else {
        searchParams.delete('group_names');
      }
      history.pushState({}, '', url);
      return results.sort((a, b) => (b.incident.priority || 0) - (a.incident.priority || 0));
    },
    smelt() {
      return this.appConfig.smeltUrl;
    }
  },
  methods: {
    refreshData(data) {
      this.incidents = data.blocked;
    }
  },
  watch: {
    groupFlavors: function (enabled) {
      const url = new URL(location);
      const params = url.searchParams;
      enabled ? params.delete('group_flavors') : params.set('group_flavors', '0');
      history.pushState({}, '', url);
    }
  }
};
</script>
