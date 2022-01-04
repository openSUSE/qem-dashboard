<template>
  <li :data-group-id="groupId">
    <ResultSummary :result="result" />
  </li>
</template>

<script>
import ResultSummary from './ResultSummary.vue';

export default {
  name: 'BlockedIncidentIncResult',
  components: {ResultSummary},
  props: {result: {type: Object, required: true}, groupId: {type: String, required: true}}
};
</script>
