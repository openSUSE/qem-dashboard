<template>
  <div class="col-md-12">
    <div class="smelt-link">
      <h2>Link to smelt</h2>
      <p>
        <SmeltLink :incident="incident" v-if="incident" />
      </p>
    </div>

    <div class="incident-results" v-if="incident">
      <h2>Per incident results</h2>
      <p v-if="!incident.buildNr">No incident build found</p>
      <p v-else>{{ results }} - see details on <a :href="openqaLink">openqa</a></p>
    </div>

    <h2 class="mb-3 mt-3">Aggregate runs including this incident</h2>
    <div class="container">
      <IncidentBuildSummary v-for="build in sortedBuilds" :key="build" :build="build" :jobs="jobs[build]" />
    </div>
  </div>
</template>

<script>
import IncidentBuildSummary from './IncidentBuildSummary.vue';
import SmeltLink from './SmeltLink.vue';
import axios from 'axios';

export default {
  name: 'PageIncident',
  data() {
    return {
      incident: null,
      summary: null,
      jobs: [],
      timer: null
    };
  },
  components: {SmeltLink, IncidentBuildSummary},
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
  mounted() {
    this.refreshData();
    this.timer = setInterval(this.refreshData, 30000);
  },
  unmounted() {
    this.cancelRefresh();
  },
  methods: {
    refreshData() {
      /*
       * The format is not necessary for mojo, but import for
       * chromium to keep the caches apart
       */
      axios.get(`/secret/api/incident/${this.$route.params.id}`).then(response => {
        const {data} = response;
        const {details} = data;
        this.incident = details.incident;
        this.incident.buildNr = details.build_nr;
        this.summary = details.incident_summary;
        this.jobs = details.jobs;
        this.$emit('last-updated', data.last_updated);
      });
    },
    cancelRefresh() {
      clearInterval(this.timer);
    }
  }
};
</script>
