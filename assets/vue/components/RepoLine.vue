<template lang="html">
  <tr>
    <td>
      <div>{{ name }}</div>
      <div class="text-left">
        <button type="button" class="btn btn-primary btn-sm" @click="triggerModal">
          <span class="badge badge-primary">
            {{ incidentNumber }}
          </span>
          Incidents
        </button>
      </div>
    </td>
    <td>
      <ul class="summary-list">
        <li v-for="result in repo.summaries" :result="result" :key="result.name">
          <ResultSummary :result="result" />
        </li>
      </ul>
    </td>
  </tr>
</template>

<script>
import ResultSummary from './ResultSummary.vue';
import jQuery from 'jquery';

export default {
  name: 'RepoLine',
  components: {ResultSummary},
  props: {repo: {type: Object, required: true}, name: {type: String, required: true}},
  computed: {
    incidentNumber() {
      return this.repo.incidents.length;
    }
  },
  methods: {
    triggerModal() {
      const dialog = this.$parent.$refs.incidentsDialog;
      dialog.title = this.name;
      dialog.incidents = this.repo.incidents;
      jQuery('#update-incidents').modal('show');
    }
  }
};
</script>
