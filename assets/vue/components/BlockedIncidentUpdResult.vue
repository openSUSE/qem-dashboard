<template>
  <li :group-id="groupId" data-toggle="tooltip" data-placement="left" :title="title">
    <ResultSummary :result="result" />
  </li>
</template>

<script>
import ResultSummary from './ResultSummary.vue';

export default {
  name: 'BlockedIncidentUpdResult',
  components: {ResultSummary},
  props: {result: {type: Object, required: true}, groupId: {type: String, required: true}, groupFlavors: Boolean},
  computed: {
    title() {
      if (this.groupFlavors) {
        return `Aggregate: ${this.result.linkinfo.version}`;
      }
      return `Aggregate: ${this.result.linkinfo.flavor}-${this.result.linkinfo.version}`;
    }
  }
};
</script>
