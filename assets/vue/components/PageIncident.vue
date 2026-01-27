<template>
  <div v-if="exists === false"><p>Incident does not exist.</p></div>
  <div v-else-if="exists === true">
    <div class="d-flex align-items-center justify-content-between mb-3" v-if="incident">
      <IncidentDetailsIcons :incident="incident" class="fs-4" />
    </div>

    <div class="external-links" v-if="incident">
      <div class="packages">
        <h2>Packages</h2>
        <ul>
          <li v-for="pkg in incident.packages" :key="pkg">
            {{ pkg }}
          </li>
        </ul>
      </div>
      <div class="smelt-link" v-if="(incident.type || 'smelt') === 'smelt'">
        <h2>Link to Smelt</h2>
        <p>
          <SmeltLink :incident="incident" />
        </p>
      </div>
      <div class="request-link">
        <h2>Source Link</h2>
        <p>
          <RequestLink :incident="incident" />
        </p>
      </div>
    </div>

    <div class="incident-results" v-if="incident">
      <h2>Per Incident Results</h2>
      <p v-if="!incident.buildNr">No incident build found</p>
      <p v-else>
        <mark>{{ results }}</mark> - see <a :href="openqaLink" target="_blank">openQA</a> for details
      </p>
    </div>

    <div class="incident-aggregates" v-if="!!sortedBuilds.length">
      <h2>Aggregate Runs Including This Incident</h2>
      <IncidentBuildSummary v-for="build in sortedBuilds" :key="build" :build="build" :jobs="jobs[build]" />
    </div>

    <div class="details">
      <h2>Further details</h2>
      <table class="table table-sm">
        <tr v-if="incident.url.length > 0">
          <th>URL</th>
          <td>
            <a :href="incident.url" target="_blank">{{ incident.url }}</a>
          </td>
        </tr>
        <tr v-if="incident.scminfo">
          <th>SCM Info</th>
          <td>{{ incident.scminfo }}</td>
        </tr>
      </table>
    </div>
  </div>
  <div v-else><i class="fas fa-sync fa-spin"></i> Loading incident...</div>
</template>

<script>
import IncidentBuildSummary from './IncidentBuildSummary.vue';
import RequestLink from './RequestLink.vue';
import SmeltLink from './SmeltLink.vue';
import IncidentDetailsIcons from './IncidentDetailsIcons.vue';
import Refresh from '../mixins/refresh.js';

export default {
  name: 'PageIncident',
  mixins: [Refresh],
  components: {RequestLink, SmeltLink, IncidentBuildSummary, IncidentDetailsIcons},
  data() {
    return {
      exists: null,
      incident: null,
      summary: null,
      jobs: [],
      refreshUrl: `/app/api/incident/${this.$route.params.id}`
    };
  },
  computed: {
    results() {
      let str = '';
      if (this.summary.passed) {
        str = `${this.summary.passed} passed`;
      }
      for (const [key, value] of Object.entries(this.summary)) {
        if (key === 'passed') continue;
        if (str) {
          str += ', ';
        }
        str += `${value} ${key}`;
      }
      return str;
    },
    openqaLink() {
      const searchParams = new URLSearchParams({build: this.incident.buildNr});
      return `${this.appConfig.openqaUrl}?${searchParams.toString()}`;
    },
    sortedBuilds() {
      return Object.keys(this.jobs).sort().reverse();
    }
  },
  methods: {
    refreshData(data) {
      /*
       * The format is not necessary for mojo, but import for
       * chromium to keep the caches apart
       */
      const {details} = data;
      if (details.incident === null) {
        this.exists = false;
      } else {
        this.exists = true;
        this.incident = details.incident;
        this.incident.buildNr = details.build_nr;
        this.summary = details.incident_summary;
        this.jobs = details.jobs;
      }
    },
    renderFieldValue(incident, field) {
      const fieldName = field.toLowerCase();
      const displayTypes = {approved: 'yesno', active: 'yesno', embargoed: 'yesno'};
      const value = incident[fieldName];
      return displayTypes[fieldName] === 'yesno' ? (value ? 'yes' : 'no') : value ? value : 'none';
    }
  }
};
</script>
