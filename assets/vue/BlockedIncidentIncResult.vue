<template>
  <li :data-group-id="groupId">
    <result-summary :result="result" />
  </li>
</template>

<script>
import ResultSummaryComponent from './ResultSummary.vue';
export default {
  name: 'BlockedIncidentIncResultComponent',
  components: {'result-summary': ResultSummaryComponent},
  props: {result: {type: Object, required: true}, groupId: {type: String, required: true}}
};
</script>
