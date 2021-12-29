<template>
  <div class="col-md-12">
    <div class="smelt-link">
      <h2>Link to smelt</h2>
      <p>
        <smelt-link :incident="incident" v-if="incident" />
      </p>
    </div>

    <div class="incident-results" v-if="incident">
      <h2>Per incident results</h2>
      <p v-if="!incident.buildNr">No incident build found</p>
      <p v-else>{{ results }} - see details on <a :href="openqaLink">openqa</a></p>
    </div>

    <h2 class="mb-3 mt-3">Aggregate runs including this incident</h2>
    <div class="container">
      <incident-build-summary v-for="build in sortedBuilds" :key="build" :build="build" :jobs="jobs[build]" />
    </div>
  </div>
</template>

<script>
import IncidentBuildSummaryComponent from './IncidentBuildSummary.vue';
import SmeltLinkComponent from './SmeltLink.vue';
import axios from 'axios';

export default {
  name: 'IncidentComponent',
  data() {
    return {
      incident: null,
      summary: null,
      jobs: []
    };
  },
  components: {'smelt-link': SmeltLinkComponent, 'incident-build-summary': IncidentBuildSummaryComponent},
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
  created() {
    this.loadData();
  },
  methods: {
    loadData() {
      /*
       * The format is not necessary for mojo, but import for
       * chromium to keep the caches apart
       */
      axios.get(`/secret/api/incident/${this.$route.params.id}`).then(response => {
        this.incident = response.data.incident;
        this.incident.buildNr = response.data.build_nr;
        this.summary = response.data.incident_summary;
        this.jobs = response.data.jobs;
      });
    }
  }
};
</script>
